import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized, enterprise-grade rate limiting and cooldown service.
///
/// Supports two modes:
/// - **Session-only** (in-memory): resets when the app is killed.
/// - **Persistent** (SharedPreferences-backed): survives app restarts.
///   Used for security-critical limits like login lockouts.
class RateLimiter {
  const RateLimiter._();

  // ---------------------------------------------------------------------------
  // In-memory session counters  (key → {count, resetAt})
  // ---------------------------------------------------------------------------
  static final Map<String, _SessionEntry> _session = {};

  // ---------------------------------------------------------------------------
  // Cooldown helpers  (last-action timestamp)
  // ---------------------------------------------------------------------------

  /// Anti-AutoClicker Tap Throttle:
  /// Returns `true` ONLY if [cooldown] (default: 1500ms) has passed since the
  /// last recorded tap for [key]. Drops any rapid/robotic clicks instantly.
  static bool tryTap(String key, [Duration cooldown = const Duration(milliseconds: 1500)]) {
    return tryAction(key: 'tap_$key', cooldown: cooldown);
  }

  /// Returns `true` when the action is **allowed** — i.e. the [cooldown]
  /// duration has elapsed since the last recorded action for [key].
  /// Automatically records the current timestamp on each allowed call.
  static bool tryAction({
    required String key,
    required Duration cooldown,
  }) {
    final entry = _session[key];
    final now = DateTime.now();
    if (entry != null && now.isBefore(entry.resetAt)) {
      return false; // still in cooldown
    }
    _session[key] = _SessionEntry(count: 1, resetAt: now.add(cooldown));
    return true;
  }

  /// Returns the remaining cooldown in seconds for [key], or 0 if not cooling.
  static int remainingCooldownSeconds(String key) {
    final entry = _session[key];
    if (entry == null) return 0;
    final diff = entry.resetAt.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  // ---------------------------------------------------------------------------
  // Session-based attempt counters
  // ---------------------------------------------------------------------------

  /// Increments the attempt counter for [key] and returns the new count.
  static int incrementAttempts(String key) {
    final entry = _session[key];
    final now = DateTime.now();
    if (entry == null || now.isAfter(entry.resetAt)) {
      _session[key] = _SessionEntry(count: 1, resetAt: DateTime(9999));
      return 1;
    }
    final next = _SessionEntry(count: entry.count + 1, resetAt: entry.resetAt);
    _session[key] = next;
    return next.count;
  }

  /// Current attempt count for [key] (0 if none recorded).
  static int attempts(String key) => _session[key]?.count ?? 0;

  /// Locks [key] for [duration] — subsequent [tryAction] calls return false.
  static void lockFor(String key, Duration duration) {
    _session[key] = _SessionEntry(
      count: _session[key]?.count ?? 0,
      resetAt: DateTime.now().add(duration),
    );
  }

  /// Clears all state for [key] (unlock + reset counter).
  static void reset(String key) => _session.remove(key);

  // ---------------------------------------------------------------------------
  // Persistent login-lockout (SharedPreferences) — survives app restarts
  // ---------------------------------------------------------------------------

  static const _kFailKey    = 'rl_login_fail_count';
  static const _kLockUntil  = 'rl_login_lock_until_ms';
  static const int _maxLoginAttempts  = 5;
  static const int _lockoutMinutes    = 30;

  /// Records a failed login attempt.
  /// Returns `null` if the account is now locked, otherwise returns the number
  /// of remaining attempts before lockout.
  static Future<int?> recordLoginFailure() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockUntil = prefs.getInt(_kLockUntil) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Already locked — reject immediately
      if (lockUntil > now) return null;

      final fails = (prefs.getInt(_kFailKey) ?? 0) + 1;
      await prefs.setInt(_kFailKey, fails);

      if (fails >= _maxLoginAttempts) {
        final until = now + Duration(minutes: _lockoutMinutes).inMilliseconds;
        await prefs.setInt(_kLockUntil, until);
        await prefs.setInt(_kFailKey, 0);
        return null; // now locked
      }
      return _maxLoginAttempts - fails; // remaining tries
    } catch (e) {
      debugPrint('RateLimiter.recordLoginFailure error: $e');
      return 5;
    }
  }

  /// Returns the remaining lockout duration, or [Duration.zero] if not locked.
  static Future<Duration> loginLockoutRemaining() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockUntil = prefs.getInt(_kLockUntil) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (lockUntil <= now) return Duration.zero;
      return Duration(milliseconds: lockUntil - now);
    } catch (e) {
      debugPrint('RateLimiter.loginLockoutRemaining error: $e');
      return Duration.zero;
    }
  }

  /// Clears login failure history (called on successful login).
  static Future<void> clearLoginFailures() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kFailKey);
      await prefs.remove(_kLockUntil);
    } catch (e) {
      debugPrint('RateLimiter.clearLoginFailures error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Persistent OTP Lockout (Anti-Brute Force / Anti-AutoClicker)
  // Survives app restarts via SharedPreferences
  // ---------------------------------------------------------------------------

  static const int maxOtpAttempts = 5;
  static const int otpLockoutMinutes = 15;

  static String _otpFailKey(String email) => 'rl_otp_fail_${email.trim().toLowerCase()}';
  static String _otpLockKey(String email) => 'rl_otp_lock_${email.trim().toLowerCase()}';

  /// Records a failed OTP attempt for the given [email].
  /// Returns `null` if maximum attempts (5) have been reached and the account is now locked.
  /// Otherwise returns the number of remaining attempts before lockout.
  static Future<int?> recordOtpFailure(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return maxOtpAttempts;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lockKey = _otpLockKey(cleanEmail);
      final failKey = _otpFailKey(cleanEmail);

      final lockUntil = prefs.getInt(lockKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (lockUntil > now) return null; // Already locked

      final currentFails = (prefs.getInt(failKey) ?? 0) + 1;
      await prefs.setInt(failKey, currentFails);

      if (currentFails >= maxOtpAttempts) {
        final lockTime = now + const Duration(minutes: otpLockoutMinutes).inMilliseconds;
        await prefs.setInt(lockKey, lockTime);
        await prefs.remove(failKey);
        return null; // Locked out now
      }

      return maxOtpAttempts - currentFails;
    } catch (e) {
      debugPrint('RateLimiter.recordOtpFailure error: $e');
      return maxOtpAttempts - 1;
    }
  }

  /// Returns remaining OTP lockout duration for [email], or [Duration.zero] if not locked.
  static Future<Duration> otpLockoutRemaining(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return Duration.zero;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lockUntil = prefs.getInt(_otpLockKey(cleanEmail)) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (lockUntil <= now) return Duration.zero;
      return Duration(milliseconds: lockUntil - now);
    } catch (e) {
      debugPrint('RateLimiter.otpLockoutRemaining error: $e');
      return Duration.zero;
    }
  }

  /// Gets the current failed OTP attempt count for [email].
  static Future<int> getOtpFailCount(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_otpFailKey(cleanEmail)) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Clears OTP failure counters and lockouts for [email] (called on successful verification).
  static Future<void> clearOtpFailures(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_otpFailKey(cleanEmail));
      await prefs.remove(_otpLockKey(cleanEmail));
    } catch (e) {
      debugPrint('RateLimiter.clearOtpFailures error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Debug helpers — no-ops in release mode
  // ---------------------------------------------------------------------------
  static void debugDump() {
    if (kDebugMode) {
      debugPrint('[RateLimiter] session keys: ${_session.keys.join(', ')}');
    }
  }
}

// ---------------------------------------------------------------------------
// Private data classes
// ---------------------------------------------------------------------------
class _SessionEntry {
  const _SessionEntry({required this.count, required this.resetAt});
  final int count;
  final DateTime resetAt;
}
