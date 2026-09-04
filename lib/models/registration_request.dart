import 'user_role.dart';
import 'account_status.dart';

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
    DateTime? dateRequested,
  }) : dateRequested = dateRequested ?? DateTime.now();

  final String id;
  final String fullName;
  final String username;
  final String contactNumber;
  final UserRole role;
  final AccountStatus status;
  final DateTime dateRequested;

  RegistrationRequest copyWith({AccountStatus? status}) {
    return RegistrationRequest(
      id: id,
      fullName: fullName,
      username: username,
      contactNumber: contactNumber,
      role: role,
      status: status ?? this.status,
      dateRequested: dateRequested,
    );
  }
}
