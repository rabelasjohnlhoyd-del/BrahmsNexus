import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/user_role.dart';
import '../models/account_status.dart';

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
  /// old mock flow). Returns a human-readable error message on
  /// failure, or null on success.
  static Future<String?> register({
    required String username,
    required String password,
    required String fullName,
    required String contactNumber,
    required UserRole role,
    String position = '',
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
      );

      await _db.collection('users').doc(uid).set({
        ...user.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
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

      return AppUser.fromMap(uid, doc.data()!);
    } on FirebaseAuthException catch (e) {
      onError(_friendlyAuthError(e));
      return null;
    } catch (_) {
      onError('Something went wrong. Please try again.');
      return null;
    }
  }

  static Future<void> signOut() => _auth.signOut();

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
      return true;
    } catch (_) {
      return false;
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
