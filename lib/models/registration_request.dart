import 'user_role.dart';
import 'account_status.dart';
import 'app_user.dart';

/// Represents a Staff/Driver self-registration awaiting the Owner's
/// decision on the Admin Web "Account Approvals" page.
///
/// NOTE: Front-end-only mock model for now. Once Supabase/Firebase are
/// wired up, this will be populated from the real accounts table.
class RegistrationRequest {
  RegistrationRequest({
    required this.id,
    required this.fullName,
    required this.username,
    required this.contactNumber,
    required this.role,
    this.status = AccountStatus.pending,
    this.position = '',
    DateTime? dateRequested,
  }) : dateRequested = dateRequested ?? DateTime.now();

  final String id;
  final String fullName;
  final String username;
  final String contactNumber;
  final UserRole role;
  final AccountStatus status;
  final String position;
  final DateTime dateRequested;

  String get displayRole => position.isNotEmpty ? position : role.label;

  /// Bridges a real Firestore-backed [AppUser] into this screen-side
  /// view model, so Admin Web's and the Owner App's existing
  /// Account Approvals UI (built against [RegistrationRequest]) can
  /// keep working unchanged once the data source switches from a
  /// hardcoded mock list to [AuthService.watchAllUsers].
  factory RegistrationRequest.fromAppUser(AppUser user) {
    return RegistrationRequest(
      id: user.uid,
      fullName: user.fullName,
      username: user.username,
      contactNumber: user.contactNumber,
      role: user.role,
      status: user.status,
      position: user.position,
      dateRequested: user.createdAt,
    );
  }

  RegistrationRequest copyWith({
    AccountStatus? status,
    String? position,
  }) {
    return RegistrationRequest(
      id: id,
      fullName: fullName,
      username: username,
      contactNumber: contactNumber,
      role: role,
      status: status ?? this.status,
      position: position ?? this.position,
      dateRequested: dateRequested,
    );
  }
}
