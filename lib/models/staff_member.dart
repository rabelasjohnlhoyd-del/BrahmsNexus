import 'branch.dart';

/// Represents a staff/employee account managed by the Administrator.
class StaffMember {
  StaffMember({
    required this.id,
    required this.firstName,
    this.middleName = '',
    required this.lastName,
    required this.username,
    required this.branch,
    required this.position,
    this.email,
    this.phone,
    this.address = '',
    this.age = '',
    this.isActive = true,
    this.isArchived = false,
    DateTime? dateAdded,
  }) : dateAdded = dateAdded ?? DateTime.now();

  final String id;
  final String firstName;
  final String middleName;
  final String lastName;
  final String username;
  final String branch;
  final String position;
  final String? email;
  final String? phone;
  final String address;
  final String age;
  final bool isActive;
  final bool isArchived;
  final DateTime dateAdded;

  String get fullName => '$firstName ${middleName.isNotEmpty ? '$middleName ' : ''}$lastName';

  StaffMember copyWith({
    String? firstName,
    String? middleName,
    String? lastName,
    String? username,
    String? branch,
    String? position,
    String? email,
    String? phone,
    String? address,
    String? age,
    bool? isActive,
    bool? isArchived,
  }) {
    return StaffMember(
      id: id,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      branch: branch ?? this.branch,
      position: position ?? this.position,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      age: age ?? this.age,
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      dateAdded: dateAdded,
    );
  }

  /// Two-letter initials used for the avatar bubble in the staff list.
  String get initials {
    if (firstName.isEmpty || lastName.isEmpty) return '?';
    return (firstName.substring(0, 1) + lastName.substring(0, 1)).toUpperCase();
  }
}

final List<String> kBranchOptions = kSampleBranches.map((b) => b.fullName).toList();

final List<String> kPositionOptions = [
  'Production Cook',
  'Production Meat Cutter',
  'Branch Cook',
  'Driver',
];

/// Shared mock staff directory
final List<StaffMember> kSampleStaff = [
  StaffMember(
    id: 'sample-1',
    firstName: 'Maria',
    lastName: 'Santos',
    username: 'maria.santos',
    branch: kBranchOptions[0],
    position: 'Branch Cook',
    email: 'maria.santos@example.com',
    address: 'Brgy. Gatid, Sta. Cruz',
    age: '24',
  ),
  StaffMember(
    id: 'sample-2',
    firstName: 'Juan',
    lastName: 'Dela Cruz',
    username: 'juan.delacruz',
    branch: kBranchOptions[1],
    position: 'Branch Cook',
    isActive: false,
    address: 'Brgy. Labuin, Pila',
    age: '29',
  ),
  StaffMember(
    id: 'sample-driver',
    firstName: 'Robert',
    lastName: 'Tan',
    username: 'robert.tan',
    branch: 'N/A',
    position: 'Driver',
    address: 'Brgy. Dayap, Calauan',
    age: '35',
  ),
];
