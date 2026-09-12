import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_role.dart';
import 'account_status.dart';

/// The Firestore-backed record for a signed-up account, stored at
/// `users/{uid}` — one document per Firebase Auth user.
///
/// This is the real-data counterpart to [RegistrationRequest]/
/// [StaffMember]: those two remain the Admin Web-side view models for
/// "an application to review" and "an employee on file", while
/// [AppUser] is specifically the record [AuthService] reads right
/// after sign-in to decide `role`/`status`/`position` for
/// [RoleRouter] — the three fields RoleRouter has always needed,
/// previously sourced from `mock_accounts.dart`.
class AppUser {
  const AppUser({
    required this.uid,
    required this.username,
    required this.fullName,
    required this.contactNumber,
    required this.role,
    required this.status,
    this.position = '',
    this.createdAt,
  });

  final String uid;
  final String username;
  final String fullName;
  final String contactNumber;
  final UserRole role;
  final AccountStatus status;
  final String position;

  /// When the account was created. Written by [AuthService.register]
  /// via `FieldValue.serverTimestamp()` (not expressible as a plain
  /// Dart value, so it's set separately from [toMap] — see that
  /// method's comment). Null only in the brief window before the
  /// server timestamp round-trips back down.
  final DateTime? createdAt;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      username: map['username'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      contactNumber: map['contactNumber'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.staff,
      ),
      status: AccountStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => AccountStatus.pending,
      ),
      position: map['position'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Fields written on registration. `createdAt` is deliberately NOT
  /// included here — [AuthService.register] merges in
  /// `FieldValue.serverTimestamp()` alongside this map, since a
  /// sentinel like that can't be represented as a plain value on an
  /// immutable model.
  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'fullName': fullName,
      'contactNumber': contactNumber,
      'role': role.name,
      'status': status.name,
      'position': position,
    };
  }
}
