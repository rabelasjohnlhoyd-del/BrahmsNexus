import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/user_role.dart';
import '../models/account_status.dart';
import '../models/staff_member.dart';
import 'notification_service.dart';
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
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: _usernameToEmail(username),
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
      );

      // Lightweight auth record in Firestore
      await _db.collection('users').doc(uid).set({
        ...user.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Split static profile info directly into Supabase (saving Firestore costs)
      final names = fullName.trim().split(' ');
      final firstName = names.isNotEmpty ? names.first : fullName;
      final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';
      final staffProfile = StaffMember(
        id: uid,
        firstName: firstName,
        lastName: lastName,
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
      return _friendlyAuthError(e);
    } catch (_) {
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
      final credential = await _auth.signInWithEmailAndPassword(
        email: _usernameToEmail(username),
        password: password,
      );

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

  /// Signs in or automatically seeds the Owner account into Firebase Auth +
  /// Firestore if it does not exist yet.
  static Future<AppUser?> signInOrSeedOwner({
    required String username,
    required String password,
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
    } catch (_) {
      return null;
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
      if (!doc.exists) {
        await _db.collection('users').doc(uid).set({
          'username': username,
          'fullName': fullName,
          'contactNumber': contactNumber,
          'role': role.label.toLowerCase(),
          'status': 'approved',
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
        status: AccountStatus.approved,
        position: position,
      );
      currentAppUser = user;
      return user;
    } catch (_) {
      return null;
    }
  }

  static Future<void> signOut() {
    currentAppUser = null;
    return _auth.signOut();
  }

  /// Real-time list of every registered account (all statuses) — the
  /// single source both Admin Web's and the Owner App's Account
  /// Approvals screens read from, replacing the hardcoded
  /// [RegistrationRequest] lists that used to live in each screen.
  static Stream<List<AppUser>> watchAllUsers() {
    return _db.collection('users').snapshots().map((snapshot) {
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
      // If approved, notify staff/driver that they are approved
      if (status == AccountStatus.approved) {
        try {
          final doc = await _db.collection('users').doc(uid).get();
          final name = doc.data()?['fullName'] as String? ?? 'Staff';
          NotificationService.notifyStaffOfAccountApproved(
            userId: uid,
            fullName: name,
          );
        } catch (_) {}
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Permanently deactivates (freezes) a staff account.
  /// Persists `status: 'deactivated'` AND `is_active: false` to Firestore
  /// so the login screen can check it on the next sign-in attempt, even
  /// after an app restart. Also updates Supabase in-memory state.
  static Future<bool> deactivateStaffAccount(String uid, String staffId) async {
    try {
      // 1) Persist to Firestore users collection (survives restarts)
      await _db.collection('users').doc(uid).update({
        'status': AccountStatus.deactivated.name,
        'is_active': false,
      });
      // 2) Also update Supabase static profile (for Branch Assignments display)
      await SupabaseService.toggleStaffActive(staffId, false);
      return true;
    } catch (e) {
      // Even if Firestore UID lookup fails (e.g. staff not yet in Firestore),
      // fall back to just Supabase in-memory toggle so UI still reflects it.
      await SupabaseService.toggleStaffActive(staffId, false);
      return false;
    }
  }

  /// Re-activates a previously frozen staff account.
  /// Restores `status: 'approved'` and `is_active: true` in Firestore.
  static Future<bool> reactivateStaffAccount(String uid, String staffId) async {
    try {
      await _db.collection('users').doc(uid).update({
        'status': AccountStatus.approved.name,
        'is_active': true,
      });
      await SupabaseService.toggleStaffActive(staffId, true);
      return true;
    } catch (e) {
      await SupabaseService.toggleStaffActive(staffId, true);
      return false;
    }
  }

  /// Looks up a staff account in Firestore by username to find their UID.
  /// Returns null if not found (e.g. staff never signed in).
  static Future<String?> findUidByUsername(String username) async {
    try {
      final snapshot = await _db
          .collection('users')
          .where('username', isEqualTo: username.trim().toLowerCase())
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.id;
    } catch (_) {
      return null;
    }
  }

  /// Checks Firestore if a staff account is deactivated by username.
  /// Returns true if the account is deactivated/frozen, false otherwise.
  /// Falls back to false (allow) if the user has no Firestore record yet.
  static Future<bool> isAccountDeactivated(String username) async {
    try {
      final snapshot = await _db
          .collection('users')
          .where('username', isEqualTo: username.trim().toLowerCase())
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        // No Firestore record → check Supabase in-memory
        return !SupabaseService.isStaffActive(username: username);
      }
      final data = snapshot.docs.first.data();
      final status = data['status'] as String? ?? 'approved';
      final isActive = data['is_active'] as bool? ?? true;
      return status == 'deactivated' || !isActive;
    } catch (_) {
      // On network error, fall back to Supabase in-memory check
      return !SupabaseService.isStaffActive(username: username);
    }
  }

  /// Real-time stream of the current user's profile document from Firestore.
  static Stream<AppUser?> watchCurrentUser() {
    final uid = currentAppUser?.uid ?? _auth.currentUser?.uid;
    if (uid == null) return Stream.value(currentAppUser);
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return currentAppUser;
      final user = AppUser.fromMap(doc.id, doc.data()!);
      currentAppUser = user;
      return user;
    }).handleError((_) => currentAppUser);
  }

  /// Updates the current user's profile fields in Firestore and local state.
  static Future<bool> updateProfile({
    String? username,
    String? contactNumber,
    String? fullName,
    String? email,
    String? age,
    String? address,
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
        driverLicenseNumber: driverLicenseNumber?.trim() ?? currentAppUser!.driverLicenseNumber,
      );
    }

    try {
      await _db.collection('users').doc(uid).update(updates);
      return true;
    } catch (_) {
      return true; // Local state updated
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


