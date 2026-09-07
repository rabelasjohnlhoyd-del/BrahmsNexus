import 'branch.dart';

/// Represents a staff/employee account managed by the Administrator.
///
/// NOTE: This is a front-end-only model for now. Credentials (password)
/// are NOT stored here — once Firebase Auth is wired up, account creation
/// will call Firebase Auth directly and this model will only hold the
/// profile/record data that lives in Firestore.
class StaffMember {
  StaffMember({
    required this.id,
    required this.fullName,
    required this.username,
    required this.branch,
    required this.position,
    this.email,
    this.phone,
    this.isActive = true,
    DateTime? dateAdded,
  }) : dateAdded = dateAdded ?? DateTime.now();

  final String id;
  final String fullName;
  final String username;
  final String branch;
  final String position;
  final String? email;
  final String? phone;
  final bool isActive;
  final DateTime dateAdded;

  StaffMember copyWith({
    String? fullName,
    String? username,
    String? branch,
    String? position,
    String? email,
    String? phone,
    bool? isActive,
  }) {
    return StaffMember(
      id: id,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      branch: branch ?? this.branch,
      position: position ?? this.position,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      dateAdded: dateAdded,
    );
  }

  /// Two-letter initials used for the avatar bubble in the staff list.
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

/// Branch names for pickers/dropdowns — derived from [kSampleBranches]
/// (see models/branch.dart), which is also what the Driver app's Route
/// tab and the Owner app's Assignments tab read. Previously this was a
/// second, separately hardcoded list that could (and did) drift out of
/// sync with the branch list used elsewhere.
final List<String> kBranchOptions =
    kSampleBranches.map((b) => b.fullName).toList();

/// Shared mock staff directory — the single source of truth for staff
/// accounts, used by both Staff Management (admin_web) and the Owner
/// app's Assignments tab. Previously each screen had its own separate
/// hardcoded employee list with names that didn't match.
final List<StaffMember> kSampleStaff = [
  StaffMember(
    id: 'sample-1',
    fullName: 'Maria Santos',
    username: 'maria.santos',
    branch: kBranchOptions[0],
    position: 'Branch Cook',
    email: 'maria.santos@example.com',
  ),
  StaffMember(
    id: 'sample-2',
    fullName: 'Juan Dela Cruz',
    username: 'juan.delacruz',
    branch: kBranchOptions[1],
    position: 'Branch Cook',
    isActive: false,
  ),
  StaffMember(
    id: 'sample-driver',
    fullName: 'Robert Tan',
    username: 'robert.tan',
    branch: 'N/A',
    position: 'Driver',
  ),
  StaffMember(
    id: 'sample-menes',
    fullName: 'Menes',
    username: 'menes.cook',
    branch: 'Central Production Kitchen',
    position: 'Production Area Cook',
  ),
  StaffMember(
    id: 'sample-abby',
    fullName: 'Abby',
    username: 'abby.cutter',
    branch: 'Central Production Kitchen',
    position: 'Production Area Meat Cutter',
  ),
];
