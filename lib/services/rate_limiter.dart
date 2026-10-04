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
  }

  /// Returns the remaining lockout duration, or [Duration.zero] if not locked.
  static Future<Duration> loginLockoutRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final lockUntil = prefs.getInt(_kLockUntil) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lockUntil <= now) return Duration.zero;
    return Duration(milliseconds: lockUntil - now);
  }

  /// Clears login failure history (called on successful login).
  static Future<void> clearLoginFailures() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFailKey);
    await prefs.remove(_kLockUntil);
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
