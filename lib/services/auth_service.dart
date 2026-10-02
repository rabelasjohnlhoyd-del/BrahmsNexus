import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, UserAttributes;
import '../models/app_user.dart';
import '../models/user_role.dart';
import '../models/account_status.dart';
import '../models/staff_member.dart';
import 'assignment_service.dart';
import 'firestore_cache.dart';
import 'notification_service.dart';
import 'otp_service.dart';
import 'supabase_service.dart';

/// Central place for every Firebase Auth + the `users` Firestore
/// collection interaction. Nothing outside this file should call
/// FirebaseAuth.instance or FirebaseFirestore.instance directly for
/// account sign-up / sign-in / role lookups — keeping it in one spot
/// means the "username -> fake email" trick below only has to be
/// right in one place.
class AuthService {
  const AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static AppUser? currentAppUser;
  static AppUser? get currentUser => currentAppUser;
  static User? get currentFirebaseUser => _auth.currentUser;
  static UserRole get currentRole => currentAppUser?.role ?? UserRole.owner;
  static String get currentUserId => currentAppUser?.uid ?? 'guest';
  static String get currentPosition => currentAppUser?.position ?? '';

  /// Returns the notification audience identifier based on role and position.
  static String get currentNotificationRole {
    if (currentAppUser == null) return 'owner';
    if (currentAppUser!.role == UserRole.owner) return 'owner';
    final pos = currentAppUser!.position.toLowerCase();
    if (pos.contains('driver')) return 'driver';
    if (pos.contains('production') || pos.contains('cutter')) return 'production';
    return 'staff';
  }

  /// Returns the registered username of the currently logged-in account,
  /// falling back to role title if not set.
  static String get currentUsername {
    final u = currentAppUser?.username.trim();
    if (u != null && u.isNotEmpty) return u;
    final fn = currentAppUser?.fullName.trim();
    if (fn != null && fn.isNotEmpty) return fn;
    if (currentRole == UserRole.owner) return 'Owner';
    return 'Staff';
  }

  /// The app's login form asks for a "username" (matching the existing
  /// UI/UX and the old `mock_accounts.dart`), but Firebase Auth's
  /// Email/Password provider requires an actual email address. Rather
  /// than add a new field to every form, every username is
  /// deterministically mapped to a fake address in a domain nobody
  /// can actually receive mail at. This also means Firebase Auth
  /// itself enforces "username already taken" for free, via its own
  /// email-uniqueness check.
  static String _usernameToEmail(String username) {
    return '${username.trim().toLowerCase()}@brahmsnexus.internal';
  }

  /// Creates the Firebase Auth account and its matching
  /// `users/{uid}` Firestore record (status: pending, same as the
  /// old mock flow), and saves the heavy personal profile to Supabase
  /// to save Firestore read and storage quotas. Returns a human-readable
  /// error message on failure, or null on success.
  static Future<String?> register({
    required String username,
    required String password,
    required String fullName,
    required String contactNumber,
    required UserRole role,
    String position = '',
    String email = '',
    String age = '',
    String address = '',
    String driverLicenseNumber = '',
    String driverLicenseExpiry = '',
    bool isLicenseVerified = false,
    bool isEmailVerified = false,
    bool isPhoneVerified = false,
    String? firstName,
    String? middleName,
    String? lastName,
  }) async {
    try {
      final authEmail = email.trim().isNotEmpty
          ? email.trim().toLowerCase()
          : _usernameToEmail(username);
      final credential = await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

      final uid = credential.user!.uid;
      final user = AppUser(
        uid: uid,
        username: username.trim(),
        fullName: fullName,
        contactNumber: contactNumber,
        role: role,
        status: AccountStatus.pending,
        position: position,
        email: email.trim(),
        age: age.trim(),
        address: address.trim(),
        driverLicenseNumber: driverLicenseNumber.trim(),
        driverLicenseExpiry: driverLicenseExpiry.trim(),
        isLicenseVerified: isLicenseVerified,
        isEmailVerified: isEmailVerified,
        isPhoneVerified: isPhoneVerified,
      );

      // Lightweight auth record in Firestore
      await _db.collection('users').doc(uid).set({
        ...user.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Split static profile info directly into Supabase (saving Firestore costs)
      final names = fullName.trim().split(' ');
      final fName = (firstName != null && firstName.trim().isNotEmpty)
          ? firstName.trim()
          : (names.isNotEmpty ? names.first : fullName);
      final mName = middleName?.trim() ?? '';
      final lName = (lastName != null && lastName.trim().isNotEmpty)
          ? lastName.trim()
          : (names.length > 1 ? names.sublist(1).join(' ') : '');
      final staffProfile = StaffMember(
        id: uid,
        firstName: fName,
        middleName: mName,
        lastName: lName,
        username: username.trim(),
        branch: 'N/A',
        position: position.isNotEmpty ? position : role.label,
        phone: contactNumber,
        email: email.trim().isNotEmpty ? email.trim() : null,
        address: address.trim(),
        age: age.trim(),
      );
      await SupabaseService.createStaffProfile(staffProfile);

      // Automatically notify the Owner about this new applicant
      NotificationService.notifyOwnerOfNewRegistration(
        fullName: fullName,
        position: position.isNotEmpty ? position : role.label,
      );

      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService.register FirebaseAuthException: ${e.code} - ${e.message}');
      return _friendlyAuthError(e);
    } catch (e, stackTrace) {
      debugPrint('AuthService.register general exception: $e\n$stackTrace');
      return 'Something went wrong. Please try again.';
    }
  }

  /// Signs in with username + password and returns the matching
  /// [AppUser] record, or null if sign-in failed (with [onError]
  /// called with a human-readable message) — callers don't need
  /// try/catch of their own.
  static Future<AppUser?> signIn({
    required String username,
    required String password,
    required void Function(String message) onError,
  }) async {
    try {
      final cleanInput = username.trim();
      UserCredential? credential;
      FirebaseAuthException? lastAuthError;

      // 1. If input contains '@', try signing in with that email directly
      if (cleanInput.contains('@')) {
        try {
          credential = await _auth.signInWithEmailAndPassword(
            email: cleanInput.toLowerCase(),
            password: password,
          );
        } on FirebaseAuthException catch (e) {
          lastAuthError = e;
        }
      }

      // 2. Try the deterministic internal address: username@brahmsnexus.internal
      if (credential == null) {
        try {
          credential = await _auth.signInWithEmailAndPassword(
            email: _usernameToEmail(cleanInput),
            password: password,
          );
        } on FirebaseAuthException catch (e) {
          lastAuthError = e;
        }
      }

      // 3. Fallback: Lookup real email from Supabase (Costs 0 Firestore reads)
      if (credential == null && !cleanInput.contains('@')) {
        try {
          final profile = await SupabaseService.findStaffProfileByUsernameOrEmail(cleanInput);
          final realEmail = profile?.email?.trim().toLowerCase();
          if (realEmail != null && realEmail.isNotEmpty) {
            try {
              credential = await _auth.signInWithEmailAndPassword(
                email: realEmail,
                password: password,
              );
            } on FirebaseAuthException catch (e) {
              lastAuthError = e;
            }
          }
        } catch (_) {}
      }

      if (credential == null) {
        if (lastAuthError != null) {
          onError(_friendlyAuthError(lastAuthError));
        } else {
          onError('Invalid username or password');
        }
        return null;
      }

      final uid = credential.user!.uid;
      final doc = await _db.collection('users').doc(uid).get();

      if (!doc.exists) {
        onError('Account record not found. Please contact the Owner.');
        return null;
      }

      final user = AppUser.fromMap(uid, doc.data()!);
      currentAppUser = user;
      return user;
    } on FirebaseAuthException catch (e) {
      onError(_friendlyAuthError(e));
      return null;
    } catch (_) {
      onError('Something went wrong. Please try again.');
      return null;
    }
  }

  /// Updates phone verification status in Firestore and in-memory session.
  static Future<bool> markPhoneAsVerified(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'isPhoneVerified': true,
      });
      if (currentAppUser != null && currentAppUser!.uid == uid) {
        currentAppUser = currentAppUser!.copyWith(isPhoneVerified: true);
      }
      return true;
    } catch (e) {
      debugPrint('AuthService.markPhoneAsVerified error: $e');
      return false;
    }
  }

  /// Updates email verification status in Firestore and in-memory session.
  static Future<bool> markEmailAsVerified(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'isEmailVerified': true,
      });
      if (currentAppUser != null && currentAppUser!.uid == uid) {
        currentAppUser = currentAppUser!.copyWith(isEmailVerified: true);
      }
      return true;
    } catch (e) {
      debugPrint('AuthService.markEmailAsVerified error: $e');
      return false;
    }
  }

  /// Signs in or automatically seeds the Owner account into Firebase Auth +
  /// Firestore if it does not exist yet.
  static Future<AppUser?> signInOrSeedOwner({
    required String username,
    required String password,
  }) async {
    try {
      final email = _usernameToEmail(username);
      UserCredential? credential;
      try {
        credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        debugPrint('signInOrSeedOwner FirebaseAuthException: ${e.code} - ${e.message}');
        if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
          try {
            credential = await _auth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
          } catch (e2) {
            debugPrint('signInOrSeedOwner createUser error: $e2');
          }
        }
      } catch (e) {
        debugPrint('signInOrSeedOwner auth error: $e');
      }

      final uid = credential?.user?.uid ?? 'owner_admin_uid';
      try {
        final doc = await _db.collection('users').doc(uid).get();
        if (!doc.exists) {
          await _db.collection('users').doc(uid).set({
            'username': username,
            'fullName': 'Business Owner',
            'contactNumber': '09123456789',
            'role': 'owner',
            'status': 'approved',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint('signInOrSeedOwner firestore doc error: $e');
      }

      final user = AppUser(
        uid: uid,
        username: username,
        fullName: 'Business Owner',
        contactNumber: '09123456789',
        role: UserRole.owner,
        status: AccountStatus.approved,
      );
      currentAppUser = user;
      return user;
    } catch (e, stack) {
      debugPrint('signInOrSeedOwner fallback exception: $e\n$stack');
      final user = AppUser(
        uid: 'owner_admin_uid',
        username: username,
        fullName: 'Business Owner',
        contactNumber: '09123456789',
        role: UserRole.owner,
        status: AccountStatus.approved,
      );
      currentAppUser = user;
      return user;
    }
  }

  /// Signs in or automatically seeds a pre-approved Staff/Driver account into
  /// Firebase Auth + Firestore if it does not exist yet.
  static Future<AppUser?> signInOrSeedStaff({
    required String username,
    required String password,
    required String fullName,
    required String contactNumber,
    required String position,
    UserRole role = UserRole.staff,
  }) async {
    try {
      final email = _usernameToEmail(username);
      UserCredential credential;
      try {
        credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          credential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } else {
          return null;
        }
      }

      final uid = credential.user!.uid;
      final doc = await _db.collection('users').doc(uid).get();

      // Check if account has been deactivated (via Firestore, Supabase, etc.)
      final isDeact = await isAccountDeactivated(username);
      AccountStatus resolvedStatus = isDeact ? AccountStatus.deactivated : AccountStatus.approved;

      if (doc.exists) {
        final existingStatus = doc.data()?['status'] as String? ?? '';
        final isActive = doc.data()?['is_active'] as bool? ?? true;
        if (existingStatus == 'deactivated' || !isActive || isDeact) {
          resolvedStatus = AccountStatus.deactivated;
        }
      } else {
        await _db.collection('users').doc(uid).set({
          'username': username,
          'fullName': fullName,
          'contactNumber': contactNumber,
          'role': role.label.toLowerCase(),
          'status': resolvedStatus.name,
          'is_active': resolvedStatus == AccountStatus.approved,
          'position': position,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final user = AppUser(
        uid: uid,
        username: username,
        fullName: fullName,
        contactNumber: contactNumber,
        role: role,
        status: resolvedStatus,
        position: position,
      );

      if (resolvedStatus == AccountStatus.approved) {
        currentAppUser = user;
      }
      return user;
    } catch (_) {
      return null;
    }
  }

  static Future<void> signOut() async {
    currentAppUser = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', false);
      await prefs.remove('saved_uid');
    } catch (e) {
      debugPrint('AuthService.signOut prefs error: $e');
    }
    await _auth.signOut();
    try {
      if (SupabaseService.isAvailable) {
        await Supabase.instance.client.auth.signOut();
      }
    } catch (_) {}
  }

  // ===========================================================================
  // REMEMBER ME PERSISTENCE & AUTO-LOGIN
  // ===========================================================================

  /// Persists Remember Me preferences locally.
  static Future<void> saveRememberMe({
    required bool rememberMe,
    required String username,
    String? uid,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', rememberMe);
      if (rememberMe) {
        await prefs.setString('saved_username', username.trim());
        if (uid != null && uid.isNotEmpty) {
          await prefs.setString('saved_uid', uid);
        }
      } else {
        await prefs.remove('saved_uid');
      }
    } catch (e) {
      debugPrint('AuthService.saveRememberMe error: $e');
    }
  }

  /// Retrieves saved credentials for login screen prefill.
  static Future<Map<String, dynamic>> getSavedLoginPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'remember_me': prefs.getBool('remember_me') ?? false,
        'saved_username': prefs.getString('saved_username') ?? '',
        'saved_uid': prefs.getString('saved_uid') ?? '',
      };
    } catch (_) {
      return {'remember_me': false, 'saved_username': '', 'saved_uid': ''};
    }
  }

  /// Attempts fast, zero-delay auto login on app start if Remember Me was selected.
  /// Costs exactly 0 Firestore reads if remember_me is false or user is not logged in.
  /// Costs exactly 1 Firestore read when session is active and verified.
  static Future<AppUser?> tryAutoLoginWithRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('remember_me') ?? false;
      if (!rememberMe) return null;

      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return null;

      final doc = await _db.collection('users').doc(firebaseUser.uid).get();
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      final statusStr = data['status'] as String? ?? '';
      final isActive = data['is_active'] as bool? ?? true;
      if (statusStr != AccountStatus.approved.name || !isActive) {
        return null;
      }

      final user = AppUser.fromMap(firebaseUser.uid, data);
      currentAppUser = user;
      return user;
    } catch (e) {
      debugPrint('AuthService.tryAutoLoginWithRememberMe error: $e');
      return null;
    }
  }

  // ===========================================================================
  // PASSWORD RECOVERY / FORGOT PASSWORD
  // ===========================================================================

  /// Searches for account information by Email or Username for password recovery.
  /// Checks Supabase first (0 Firestore reads). Falls back to Firestore only if needed.
  static Future<Map<String, String>?> lookupAccountForPasswordReset(String input) async {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) return null;

    // 1. Supabase lookup (Costs ZERO Firestore reads)
    try {
      final staff = await SupabaseService.findStaffProfileByUsernameOrEmail(cleanInput);
      if (staff != null && staff.email != null && staff.email!.trim().isNotEmpty) {
        return {
          'email': staff.email!.trim().toLowerCase(),
          'username': staff.username.trim(),
          'uid': staff.id,
          'fullName': staff.fullName,
        };
      }
    } catch (_) {}

    // 2. Targeted Firestore lookup with limit 1 (Minimal 1 read)
    try {
      final isEmail = cleanInput.contains('@');
      final query = isEmail
          ? _db.collection('users').where('email', isEqualTo: cleanInput.toLowerCase()).limit(1)
          : _db.collection('users').where('username', isEqualTo: cleanInput).limit(1);

      final snap = await query.get();
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        final data = doc.data();
        final email = (data['email'] as String? ?? '').trim().toLowerCase();
        final username = (data['username'] as String? ?? cleanInput).trim();
        final fullName = (data['fullName'] as String? ?? '').trim();

        if (email.isNotEmpty) {
          return {
            'email': email,
            'username': username,
            'uid': doc.id,
            'fullName': fullName,
          };
        }
      }
    } catch (e) {
      debugPrint('AuthService.lookupAccountForPasswordReset error: $e');
    }

    return null;
  }

  /// Sends both Supabase Mailer 6-digit OTP and Firebase official reset email.
  static Future<bool> sendPasswordResetOtp({required String email}) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      // 1. Send real 6-digit OTP code to email inbox via Supabase Mailer + Firestore
      await OtpService.sendEmailOtp(cleanEmail);

      // 2. Also dispatch Firebase Auth password reset link in background if account exists there
      try {
        await _auth.sendPasswordResetEmail(email: cleanEmail);
      } catch (e) {
        debugPrint('AuthService.sendPasswordResetEmail fallback note: $e');
      }

      return true;
    } catch (e) {
      debugPrint('AuthService.sendPasswordResetOtp error: $e');
      return false;
    }
  }

  /// Verifies the entered 6-digit OTP code.
  static Future<bool> verifyPasswordResetOtp({
    required String email,
    required String enteredOtp,
  }) async {
    return OtpService.verifyEmailOtp(email, enteredOtp);
  }

  /// Completes the password reset after OTP verification.
  /// Updates Firebase Auth, Supabase Auth (if session active), and local cache.
  static Future<bool> completePasswordReset({
    required String email,
    required String username,
    required String newPassword,
    String? oobCode,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    bool updatedInFirebase = false;

    // 1. If an official Firebase oobCode is available, confirm reset natively
    if (oobCode != null && oobCode.isNotEmpty) {
      try {
        await _auth.confirmPasswordReset(code: oobCode, newPassword: newPassword);
        updatedInFirebase = true;
      } catch (e) {
        debugPrint('AuthService.completePasswordReset confirmPasswordReset: $e');
      }
    }

    // 2. If not reset via oobCode, handle Firebase Auth password update
    if (!updatedInFirebase) {
      try {
        // Try creating/linking user with the real email and new password if it was internal
        try {
          final cred = await _auth.createUserWithEmailAndPassword(
            email: cleanEmail,
            password: newPassword,
          );
          if (cred.user != null) {
            updatedInFirebase = true;
          }
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            // Already exists in Firebase Auth: dispatch reset email so user can also use one-click reset
            try {
              await _auth.sendPasswordResetEmail(email: cleanEmail);
            } catch (_) {}
            updatedInFirebase = true;
          }
        }
      } catch (e) {
        debugPrint('AuthService.completePasswordReset firebase auth sync error: $e');
      }
    }

    // 3. Update Supabase Auth user password if authenticated in Supabase
    try {
      if (SupabaseService.isAvailable && Supabase.instance.client.auth.currentSession != null) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: newPassword),
        );
      }
    } catch (e) {
      debugPrint('AuthService.completePasswordReset supabase update error: $e');
    }

    return true;
  }

  /// Real-time list of every registered account (all statuses) — the
  /// single source both Admin Web's and the Owner App's Account
  /// Approvals screens read from, replacing the hardcoded
  /// [RegistrationRequest] lists that used to live in each screen.
  static Stream<List<AppUser>> watchAllUsers() {
    return FirestoreListenCache.query(
      'users',
      _db.collection('users'),
    ).map((snapshot) {
      final list = snapshot.docs
          .map((doc) => AppUser.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  /// Approve or reject a pending registration. `uid` is the Firestore
  /// document id, which is the same value as the Firebase Auth uid —
  /// carried through as [RegistrationRequest.id] via
  /// [RegistrationRequest.fromAppUser].
  static Future<bool> updateAccountStatus(
      String uid, AccountStatus status) async {
    try {
      await _db.collection('users').doc(uid).update({'status': status.name});
      // If approved, notify staff/driver and sync to Supabase staff_profiles
      if (status == AccountStatus.approved) {
        try {
          final doc = await _db.collection('users').doc(uid).get();
          final data = doc.data();
          if (data != null) {
            final appUser = AppUser.fromMap(uid, data);
            NotificationService.notifyStaffOfAccountApproved(
              userId: uid,
              fullName: appUser.fullName,
            );

            // Sync approved user to staff directory so they immediately appear
            // in Staff Management and Branch Assignments
            final nameParts = appUser.fullName.trim().split(' ');
            final firstName = nameParts.isNotEmpty ? nameParts.first : appUser.fullName;
            final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
            final position = appUser.position.isNotEmpty
                ? appUser.position
                : (appUser.position.toLowerCase().contains('driver') ? 'Delivery Driver' : 'Branch Cook');

            final staff = StaffMember(
              id: appUser.uid,
              firstName: firstName,
              lastName: lastName,
              username: appUser.username,
              branch: 'N/A',
              position: position,
              email: appUser.email.isNotEmpty ? appUser.email : null,
              phone: appUser.contactNumber.isNotEmpty ? appUser.contactNumber : null,
              address: appUser.address,
              age: appUser.age,
              isActive: true,
              isArchived: false,
            );
            await SupabaseService.createStaffProfile(staff);
          }
        } catch (_) {}
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool _hasSyncedApprovedUsers = false;

  /// Syncs all approved users in Firestore into Supabase staff_profiles
  /// so that any newly or previously approved staff/drivers immediately
  /// appear in Staff Management and Branch Assignments.
  /// Guarded to run only ONCE per session to strictly eliminate unnecessary Firestore reads.
  static Future<void> syncApprovedUsersToStaffDirectory({bool force = false}) async {
    if (_hasSyncedApprovedUsers && !force) return;
    _hasSyncedApprovedUsers = true;
    try {
      final snap = await _db
          .collection('users')
          .where('status', isEqualTo: AccountStatus.approved.name)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final roleStr = data['role']?.toString();
        if (roleStr == UserRole.owner.name) continue; // Skip owner

        final appUser = AppUser.fromMap(doc.id, data);
        final usernameKey = appUser.username.toLowerCase().trim();

        final exists = SupabaseService.getAllStaff().any((s) =>
            s.id == appUser.uid ||
            (usernameKey.isNotEmpty && s.username.toLowerCase().trim() == usernameKey));

        if (!exists) {
          final nameParts = appUser.fullName.trim().split(' ');
          final firstName = nameParts.isNotEmpty ? nameParts.first : appUser.fullName;
          final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
          final position = appUser.position.isNotEmpty
              ? appUser.position
              : (appUser.position.toLowerCase().contains('driver') ? 'Delivery Driver' : 'Branch Cook');

          final staff = StaffMember(
            id: appUser.uid,
            firstName: firstName,
            lastName: lastName,
            username: appUser.username,
            branch: 'N/A',
            position: position,
            email: appUser.email.isNotEmpty ? appUser.email : null,
            phone: appUser.contactNumber.isNotEmpty ? appUser.contactNumber : null,
            address: appUser.address,
            age: appUser.age,
            isActive: true,
            isArchived: false,
          );

          await SupabaseService.createStaffProfile(staff);
          debugPrint('AuthService: Auto-synced approved user ${appUser.username} to staff directory.');
        }
      }
    } catch (e) {
      debugPrint('AuthService.syncApprovedUsersToStaffDirectory error: $e');
    }
  }

  // ===========================================================================
  // STAFF DEACTIVATION — uses dedicated 'deactivated_staff' Firestore
  // collection keyed by lowercase username. This works even for staff who
  // have never logged in (no Firebase UID / no 'users' doc yet) because the
  // key is the username, not the UID.
  // ===========================================================================

  /// Deactivates (freezes) a staff account.
  /// Writes to BOTH `deactivated_staff/{username}` (always works, no UID needed)
  /// AND `users/{uid}` (if the staff has ever signed in). Also updates
  /// Supabase persistently by both staffId and username.
  static Future<bool> deactivateStaffAccount(String staffId, String username) async {
    final usernameKey = username.trim().toLowerCase();

    // 1) Always write to deactivated_staff collection (username as doc ID).
    //    This persists across restarts even for staff who never logged in.
    try {
      await _db.collection('deactivated_staff').doc(usernameKey).set({
        'username': usernameKey,
        'staffId': staffId,
        'isDeactivated': true,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('AuthService.deactivateStaffAccount deactivated_staff write error: $e');
    }

    // 2) Also update the users collection if they have a Firestore record.
    try {
      final uid = await findUidByUsername(username);
      if (uid != null) {
        await _db.collection('users').doc(uid).update({
          'status': AccountStatus.deactivated.name,
          'is_active': false,
        });
      }
    } catch (_) {}

    // 3) Update Supabase persistently — by staffId if available, AND by username.
    if (staffId.isNotEmpty) {
      await SupabaseService.toggleStaffActive(staffId, false);
    }
    await SupabaseService.toggleStaffActiveByUsername(usernameKey, false);
    return true;
  }

  /// Re-activates a previously frozen staff account.
  static Future<bool> reactivateStaffAccount(String staffId, String username) async {
    final usernameKey = username.trim().toLowerCase();

    // 1) Remove from deactivated_staff collection.
    try {
      await _db.collection('deactivated_staff').doc(usernameKey).delete();
    } catch (e) {
      debugPrint('AuthService.reactivateStaffAccount deactivated_staff delete error: $e');
    }

    // 2) Restore users collection status if record exists.
    try {
      final uid = await findUidByUsername(username);
      if (uid != null) {
        await _db.collection('users').doc(uid).update({
          'status': AccountStatus.approved.name,
          'is_active': true,
        });
      }
    } catch (_) {}

    // 3) Update Supabase persistently — by staffId if available, AND by username.
    if (staffId.isNotEmpty) {
      await SupabaseService.toggleStaffActive(staffId, true);
    }
    await SupabaseService.toggleStaffActiveByUsername(usernameKey, true);
    return true;
  }

  /// Looks up a staff account in Firestore by username to find their UID.
  /// Returns null if not found (e.g. staff never signed in).
  static Future<String?> findUidByUsername(String username) async {
    try {
      final usernameKey = username.trim().toLowerCase();
      // Try exact match first
      final snapshot = await _db
          .collection('users')
          .where('username', isEqualTo: usernameKey)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) return snapshot.docs.first.id;
      // Try original case as fallback
      final snapshot2 = await _db
          .collection('users')
          .where('username', isEqualTo: username.trim())
          .limit(1)
          .get();
      if (snapshot2.docs.isNotEmpty) return snapshot2.docs.first.id;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Checks if a staff account is deactivated/frozen.
  /// Checks `deactivated_staff/{username}` first (fastest, no UID needed),
  /// then falls back to the `users` collection, then Supabase in-memory.
  static Future<bool> isAccountDeactivated(String username) async {
    final usernameKey = username.trim().toLowerCase();
    try {
      // 1) Primary check: deactivated_staff collection (username-keyed)
      // Ito ang pinaka-safe dahil username ang ID ng document.
      final deactivatedDoc = await _db
          .collection('deactivated_staff')
          .doc(usernameKey)
          .get();
      if (deactivatedDoc.exists) {
        return deactivatedDoc.data()?['isDeactivated'] as bool? ?? false;
      }

      // 2) Secondary check: Check current user's own document if applicable
      // Iniiwasan natin ang .where('username') query dahil nagdudulot ito ng PERMISSION_DENIED sa staff.
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final userDoc = await _db.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          // I-verify kung ito nga ang user na tinitignan natin
          final docUsername = (data['username'] as String? ?? '').toLowerCase();
          if (docUsername == usernameKey) {
            final status = data['status'] as String? ?? 'approved';
            final isActive = data['is_active'] as bool? ?? true;
            if (status == 'deactivated' || !isActive) return true;
          }
        }
      }

      // 3) Tertiary check: Supabase (as synchronous/in-memory fallback)
      final staff = await SupabaseService.getStaffByUsernameOrId(usernameKey);
      if (staff != null && (!staff.isActive || staff.isArchived)) return true;

      return false;
    } catch (e) {
      debugPrint('Error in isAccountDeactivated: $e');
      return !SupabaseService.isStaffActive(username: username);
    }
  }

  /// Returns true if the given position belongs to Production Area staff
  /// (Production Area Cook or Production Area Meat Cutter).
  /// Production staff work at the central kitchen — they are never part of
  /// the Branch Assignments system, so rest day checks don't apply to them.
  static bool isProductionPosition(String position) {
    final p = position.trim().toLowerCase();
    // Catches: 'Production Cook', 'Production Area Cook',
    //          'Production Meat Cutter', 'Production Area Meat Cutter'
    return p.startsWith('production');
  }

  /// Checks if a staff account is scheduled on Rest Day today.
  /// When on Rest Day, staff members are barred from logging in until put back on duty.
  ///
  /// IMPORTANT: Production staff (Production Area Cook, Production Area Meat Cutter)
  /// are ALWAYS exempt from the Rest Day check — they work at the central kitchen
  /// and are never assigned to a branch.
  static Future<bool> isAccountOnRestDay(String username) async {
    final usernameKey = username.trim().toLowerCase();

    // 0. If this is a production staff account, skip the rest day check entirely.
    //    Check mock accounts first (fast, no network), then Supabase.
    try {
      // Check mock accounts (covers dev/test accounts like menes_cook)
      final mock = _getMockPosition(usernameKey);
      if (mock != null && isProductionPosition(mock)) return false;

      // Check Supabase position (covers real registered accounts)
      final staff = await SupabaseService.getStaffByUsernameOrId(usernameKey);
      if (staff != null && isProductionPosition(staff.position)) return false;
    } catch (_) {}

    // 1. Check local/memory cache via AssignmentService first (instant, 0 latency)
    try {
      await AssignmentService.ensureInitialized();
      if (AssignmentService.isRestDay(usernameKey)) {
        return true;
      }
    } catch (_) {}

    // 2. Check Supabase staff_profiles (cloud source of truth)
    try {
      final staff = await SupabaseService.getStaffByUsernameOrId(usernameKey);
      if (staff != null && staff.isRestDay) {
        return true;
      }
    } catch (_) {}

    // 3. Check Firestore staff_assignments
    try {
      final doc = await _db.collection('staff_assignments').doc(usernameKey).get();
      if (doc.exists) {
        final data = doc.data();
        final isRestDay = data?['isRestDay'] as bool? ?? false;
        final workStatus = data?['workStatus'] as String? ?? '';
        return isRestDay || workStatus == 'restDay';
      }
      return false;
    } catch (e) {
      debugPrint('AuthService.isAccountOnRestDay error: $e');
      return AssignmentService.isRestDay(usernameKey);
    }
  }

  /// Internal helper — looks up position from mock accounts without importing login_screen.
  static String? _getMockPosition(String username) {
    const productionUsernames = {
      'menes_cook': 'Production Cook',
      'abby_cutter': 'Production Meat Cutter',
    };
    return productionUsernames[username.trim().toLowerCase()];
  }

  /// Real-time stream of the current user's profile document from Firestore.
  static Stream<AppUser?> watchCurrentUser() {
    final uid = currentAppUser?.uid ?? _auth.currentUser?.uid;
    if (uid == null) return Stream.value(currentAppUser);
    return FirestoreListenCache.doc(
      'users:$uid',
      _db.collection('users').doc(uid),
    ).map((doc) {
      if (!doc.exists || doc.data() == null) return currentAppUser;
      final user = AppUser.fromMap(doc.id, doc.data()!);
      currentAppUser = user;
      return user;
    }).handleError((_) => currentAppUser);
  }

  /// Updates the current user's profile fields in Firestore, Supabase, and local state.
  static Future<bool> updateProfile({
    String? username,
    String? contactNumber,
    String? fullName,
    String? email,
    String? age,
    String? address,
    String? photoUrl,
    String? driverLicenseNumber,
  }) async {
    final uid = currentAppUser?.uid ?? _auth.currentUser?.uid;
    if (uid == null) return false;

    final updates = <String, dynamic>{};
    if (username != null && username.trim().isNotEmpty) {
      updates['username'] = username.trim();
    }
    if (contactNumber != null && contactNumber.trim().isNotEmpty) {
      updates['contactNumber'] = contactNumber.trim();
    }
    if (fullName != null && fullName.trim().isNotEmpty) {
      updates['fullName'] = fullName.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      updates['email'] = email.trim();
    }
    if (age != null && age.trim().isNotEmpty) {
      updates['age'] = age.trim();
    }
    if (address != null && address.trim().isNotEmpty) {
      updates['address'] = address.trim();
    }
    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      updates['photoUrl'] = photoUrl.trim();
    }
    if (driverLicenseNumber != null && driverLicenseNumber.trim().isNotEmpty) {
      updates['driverLicenseNumber'] = driverLicenseNumber.trim();
    }

    if (currentAppUser != null) {
      currentAppUser = currentAppUser!.copyWith(
        username: username?.trim() ?? currentAppUser!.username,
        contactNumber: contactNumber?.trim() ?? currentAppUser!.contactNumber,
        fullName: fullName?.trim() ?? currentAppUser!.fullName,
        email: email?.trim() ?? currentAppUser!.email,
        age: age?.trim() ?? currentAppUser!.age,
        address: address?.trim() ?? currentAppUser!.address,
        photoUrl: photoUrl?.trim() ?? currentAppUser!.photoUrl,
        driverLicenseNumber: driverLicenseNumber?.trim() ?? currentAppUser!.driverLicenseNumber,
      );
    }

    // 1. Sync updates to Supabase staff_profiles in real time (0 Firebase reads)
    try {
      await SupabaseService.updateStaffFields(
        id: uid,
        username: username,
        fullName: fullName,
        phone: contactNumber,
        email: email,
        address: address,
        age: age,
        photoUrl: photoUrl,
      );
    } catch (e) {
      debugPrint('AuthService.updateProfile Supabase sync error: $e');
    }

    // 2. Persist to Firestore
    try {
      if (updates.isNotEmpty) {
        await _db.collection('users').doc(uid).update(updates);
      }
      return true;
    } catch (_) {
      return true; // Local and Supabase state updated
    }
  }

  static String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'That username is already taken.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect username or password.';
      case 'invalid-email':
        return "That username contains characters that aren't allowed.";
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}


