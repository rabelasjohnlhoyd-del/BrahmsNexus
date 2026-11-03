import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'rate_limiter.dart';
import 'supabase_service.dart';

/// Centralized service for handling Email OTP verifications.
/// Phone SMS OTP has been removed/bypassed to prevent quota exhaustion and SMS gateway costs.
class OtpService {
  const OtpService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // In-memory cache of recent email OTPs for instant validation & dev fallback
  static final Map<String, _EmailOtpEntry> _recentEmailOtps = {};

  /// Universal test bypass — **only active in debug builds**.
  /// Automatically disabled in release/profile mode via [kDebugMode].
  static String? get devUniversalCode => kDebugMode ? '123456' : null;

  // ===========================================================================
  // 1. EMAIL OTP VERIFICATION
  // ===========================================================================

  /// Generates and sends a real 6-digit OTP to the user's email address.
  /// Valid for 5 minutes (Industry Standard).
  static Future<String> sendEmailOtp(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    
    // Generate secure 6-digit code (e.g. 842109)
    final code = (100000 + Random().nextInt(900000)).toString();
    final expiresAt = DateTime.now().add(const Duration(minutes: 5));

    // Store in local memory for fast lookup
    _recentEmailOtps[cleanEmail] = _EmailOtpEntry(code: code, expiresAt: expiresAt);

    // Store in Firestore `email_otps`
    try {
      await _db.collection('email_otps').doc(cleanEmail).set({
        'email': cleanEmail,
        'code': code,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'attempts': 0,
      });
    } catch (e) {
      debugPrint('OtpService.sendEmailOtp Firestore error: $e');
    }

    // Send real email with 6-digit OTP code to the user's actual email inbox via Supabase
    try {
      final client = SupabaseService.client;
      if (client != null) {
        await client.auth.signInWithOtp(
          email: cleanEmail,
          shouldCreateUser: true,
        );
        debugPrint('OtpService: Sent real Email OTP to $cleanEmail via Supabase Mailer');
      }
    } catch (e) {
      debugPrint('OtpService.sendEmailOtp Supabase mailer error: $e');
    }

    debugPrint('OtpService: Generated Email OTP for $cleanEmail -> $code (Valid for 5 mins)');
    return code;
  }

  /// Verifies the entered 6-digit OTP for the given email address.
  /// Enforces auto-clicker protection, 5-minute TTL, max 5 attempts, and auto-burn.
  static Future<bool> verifyEmailOtp(String email, String enteredCode) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = enteredCode.trim();

    // Check persistent lockout first (survives app restarts)
    final lockout = await RateLimiter.otpLockoutRemaining(cleanEmail);
    if (lockout > Duration.zero) {
      debugPrint('OtpService.verifyEmailOtp: $cleanEmail is locked out for ${lockout.inSeconds}s.');
      return false;
    }

    bool isValid = false;

    // 1. Dev test bypass (only allowed in debug builds)
    if (kDebugMode && devUniversalCode != null && cleanCode == devUniversalCode) {
      isValid = true;
    }

    // 2. Try verifying via Supabase Auth OTP (real email token)
    if (!isValid) {
      try {
        final client = SupabaseService.client;
        if (client != null) {
          final res = await client.auth.verifyOTP(
            email: cleanEmail,
            token: cleanCode,
            type: OtpType.email,
          );
          if (res.user != null || res.session != null) {
            isValid = true;
          }
        }
      } catch (e) {
        debugPrint('OtpService.verifyEmailOtp Supabase check error: $e');
      }
    }

    // 3. Check in-memory store
    if (!isValid) {
      final memEntry = _recentEmailOtps[cleanEmail];
      if (memEntry != null) {
        if (DateTime.now().isBefore(memEntry.expiresAt) && memEntry.code == cleanCode) {
          isValid = true;
        }
      }
    }

    // 4. Check Firestore
    if (!isValid) {
      try {
        final doc = await _db.collection('email_otps').doc(cleanEmail).get();
        if (doc.exists) {
          final data = doc.data()!;
          final storedCode = data['code'] as String? ?? '';
          final expiresAtTs = data['expiresAt'] as Timestamp?;
          final expiresAt = expiresAtTs?.toDate() ?? DateTime.now();

          if (DateTime.now().isBefore(expiresAt) && storedCode == cleanCode) {
            isValid = true;
          }
        }
      } catch (e) {
        debugPrint('OtpService.verifyEmailOtp error: $e');
      }
    }

    if (isValid) {
      // SUCCESS: Clear failures & instantly burn the used code (Single-use security)
      await RateLimiter.clearOtpFailures(cleanEmail);
      _recentEmailOtps.remove(cleanEmail);
      await _cleanFirestoreEmailOtp(cleanEmail);
      return true;
    } else {
      // FAILED: Record persistent failure
      final remaining = await RateLimiter.recordOtpFailure(cleanEmail);
      if (remaining == null) {
        // 5 FAILED ATTEMPTS: Instantly burn OTP in memory & DB and lock out!
        _recentEmailOtps.remove(cleanEmail);
        await _cleanFirestoreEmailOtp(cleanEmail);
        debugPrint('OtpService: Max failed OTP attempts reached for $cleanEmail. OTP burned and locked out.');
      }
      return false;
    }
  }

  static Future<void> _cleanFirestoreEmailOtp(String email) async {
    try {
      await _db.collection('email_otps').doc(email).delete();
    } catch (_) {}
  }

  // ===========================================================================
  // 1.1 PASSWORD RESET OTP (Supabase Recovery + In-Memory/Firestore Backup)
  // ===========================================================================

  /// Generates and sends a 6-digit Password Reset OTP to the user's email address.
  /// Uses Supabase's native `resetPasswordForEmail` and stores a backup in Firestore & memory.
  /// Valid for 5 minutes (Industry Standard).
  static Future<String> sendPasswordResetOtp(String email) async {
    final cleanEmail = email.trim().toLowerCase();

    // Generate secure 6-digit code
    final code = (100000 + Random().nextInt(900000)).toString();
    final expiresAt = DateTime.now().add(const Duration(minutes: 5));

    // Store in local memory for fast lookup
    _recentEmailOtps[cleanEmail] = _EmailOtpEntry(code: code, expiresAt: expiresAt);

    // Store in Firestore `email_otps`
    try {
      await _db.collection('email_otps').doc(cleanEmail).set({
        'email': cleanEmail,
        'code': code,
        'purpose': 'password_reset',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'attempts': 0,
      });
    } catch (e) {
      debugPrint('OtpService.sendPasswordResetOtp Firestore error: $e');
    }

    // Trigger Supabase Password Reset Email
    try {
      final client = SupabaseService.client;
      if (client != null) {
        await client.auth.resetPasswordForEmail(cleanEmail);
        debugPrint('OtpService: Sent real Password Reset Email to $cleanEmail via Supabase');
      }
    } catch (e) {
      debugPrint('OtpService.sendPasswordResetOtp Supabase error: $e');
    }

    debugPrint('OtpService: Generated Password Reset OTP for $cleanEmail -> $code (Valid for 5 mins)');
    return code;
  }

  /// Verifies the entered 6-digit OTP specifically for password recovery.
  /// Enforces auto-clicker protection, 5-minute TTL, max 5 attempts, and auto-burn.
  static Future<bool> verifyPasswordResetOtp(String email, String enteredCode) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = enteredCode.trim();

    // Check persistent lockout first (survives app restarts)
    final lockout = await RateLimiter.otpLockoutRemaining(cleanEmail);
    if (lockout > Duration.zero) {
      debugPrint('OtpService.verifyPasswordResetOtp: $cleanEmail is locked out for ${lockout.inSeconds}s.');
      return false;
    }

    bool isValid = false;

    // 1. Dev test bypass (only allowed in debug builds)
    if (kDebugMode && devUniversalCode != null && cleanCode == devUniversalCode) {
      isValid = true;
    }

    // 2. Try verifying via Supabase Auth recovery OTP
    if (!isValid) {
      try {
        final client = SupabaseService.client;
        if (client != null) {
          final res = await client.auth.verifyOTP(
            email: cleanEmail,
            token: cleanCode,
            type: OtpType.recovery,
          );
          if (res.user != null || res.session != null) {
            isValid = true;
            debugPrint('OtpService: Verified recovery OTP via Supabase successfully');
          }
        }
      } catch (e) {
        debugPrint('OtpService.verifyPasswordResetOtp Supabase recovery check: $e');
      }
    }

    // 3. Fallback: check in-memory store
    if (!isValid) {
      final memEntry = _recentEmailOtps[cleanEmail];
      if (memEntry != null) {
        if (DateTime.now().isBefore(memEntry.expiresAt) && memEntry.code == cleanCode) {
          isValid = true;
        }
      }
    }

    // 4. Fallback: check Firestore
    if (!isValid) {
      try {
        final doc = await _db.collection('email_otps').doc(cleanEmail).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            final storedCode = data['code'] as String? ?? '';
            final expiresAtTs = data['expiresAt'] as Timestamp?;
            final expiresAt = expiresAtTs?.toDate() ?? DateTime.now();

            if (DateTime.now().isBefore(expiresAt) && storedCode == cleanCode) {
              isValid = true;
            }
          }
        }
      } catch (e) {
        debugPrint('OtpService.verifyPasswordResetOtp Firestore check error: $e');
      }
    }

    if (isValid) {
      // SUCCESS: Clear failures & instantly burn the code
      await RateLimiter.clearOtpFailures(cleanEmail);
      _recentEmailOtps.remove(cleanEmail);
      await _cleanFirestoreEmailOtp(cleanEmail);
      return true;
    } else {
      // FAILED: Record persistent failure
      final remaining = await RateLimiter.recordOtpFailure(cleanEmail);
      if (remaining == null) {
        // 5 FAILED ATTEMPTS: Burn OTP in memory & DB and lock out!
        _recentEmailOtps.remove(cleanEmail);
        await _cleanFirestoreEmailOtp(cleanEmail);
        debugPrint('OtpService: Max failed recovery attempts reached for $cleanEmail. Burned OTP and locked out.');
      }
      return false;
    }
  }

  // ===========================================================================
  // 2. PHONE SMS OTP (Bypassed: Disabled to prevent SMS quota & read consumption)
  // ===========================================================================

  /// Formats any Philippine phone number to international E.164 (+639...).
  /// Example: '09123456789' -> '+639123456789'
  static String formatPhPhoneNumber(String phone) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('63')) {
      return '+$digits';
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return '+63$digits';
  }

  /// Sends a phone SMS verification code (Bypassed: SMS provider disabled).
  static Future<void> sendPhoneSmsOtp({
    required String rawPhoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String errorMessage) onError,
    void Function(PhoneAuthCredential credential)? onAutoVerified,
    int? resendToken,
  }) async {
    debugPrint('OtpService.sendPhoneSmsOtp: SMS verification disabled.');
    onCodeSent('bypassed_verification', null);
  }

  /// Verifies the entered SMS code (Bypassed: Always succeeds).
  static Future<bool> verifyPhoneSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    return true;
  }
}

class _EmailOtpEntry {
  const _EmailOtpEntry({required this.code, required this.expiresAt});
  final String code;
  final DateTime expiresAt;
}
