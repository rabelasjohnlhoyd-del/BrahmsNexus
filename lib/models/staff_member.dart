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
    bool? isActive,
  }) {
    return StaffMember(
      id: id,
      fullName: fullName,
      username: username,
      branch: branch,
      position: position,
      email: email,
      phone: phone,
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

/// Placeholder branch list — sourced from the Owner's actual branch
/// list (barangay-level). Replace with a Firestore/Supabase-backed
/// list once the backend is wired up (this should eventually read
/// from `Branch` records — see models/branch.dart).
const List<String> kBranchOptions = [
  'Brgy. Gatid, Sta. Cruz',
  'Brgy. Labuin, Pila',
  'Brgy. Sta. Clara Sur, Pila',
  'Brgy. Nanhaya, Victoria',
  'Brgy. San Francisco, Victoria',
  'Brgy. Dayap, Calauan',
];
