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
    this.rfidTag = '',
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
  final String rfidTag;
  final bool isActive;
  final bool isArchived;
  final DateTime dateAdded;

  /// Whether employee is on Rest Day (stored in Supabase rfid_tag column)
  bool get isRestDay => rfidTag.toUpperCase().startsWith('REST_DAY');

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
    String? rfidTag,
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
      rfidTag: rfidTag ?? this.rfidTag,
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'username': username,
      'branch_name': branch,
      'position': position,
      'email': email,
      'phone': phone,
      'address': address,
      'age': age,
      'rfid_tag': rfidTag,
      'is_active': isActive,
      'is_archived': isArchived,
      'date_added': dateAdded.toIso8601String(),
    };
  }

  factory StaffMember.fromMap(Map<String, dynamic> map) {
    DateTime? parsedDate;
    if (map['date_added'] != null) {
      parsedDate = DateTime.tryParse(map['date_added'].toString());
    }
    return StaffMember(
      id: map['id']?.toString() ?? '',
      firstName: map['first_name']?.toString() ?? '',
      middleName: map['middle_name']?.toString() ?? '',
      lastName: map['last_name']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      branch: map['branch_name']?.toString() ?? map['branch']?.toString() ?? 'N/A',
      position: map['position']?.toString() ?? '',
      email: map['email']?.toString(),
      phone: map['phone']?.toString(),
      address: map['address']?.toString() ?? '',
      age: map['age']?.toString() ?? '',
      rfidTag: map['rfid_tag']?.toString() ?? '',
      isActive: map['is_active'] as bool? ?? true,
      isArchived: map['is_archived'] as bool? ?? false,
      dateAdded: parsedDate,
    );
  }
}

final List<String> kBranchOptions = [
  ...kSampleBranches.map((b) => b.fullName),
  'Floating / Any Branch',
  'N/A',
];

final List<String> kPositionOptions = [
  'Branch Cook',
  'Floating Cook',
  'Production Cook',
  'Production Meat Cutter',
  'Driver',
];

/// Shared official staff directory with client's actual personnel
final List<StaffMember> kSampleStaff = [
  StaffMember(
    id: 'emp1',
    firstName: 'Leany',
    middleName: 'Hernandez',
    lastName: 'Malla',
    username: 'leany_malla',
    branch: 'Brgy. Dayap, Calauan',
    position: 'Branch Cook',
    phone: '09917063234',
    address: 'San Francisco, Victoria, Laguna',
  ),
  StaffMember(
    id: 'emp2',
    firstName: 'Jobelle',
    middleName: 'T',
    lastName: 'Fuentes',
    username: 'jobelle_fuentes',
    branch: 'Brgy. Labuin, Pila',
    position: 'Branch Cook',
    phone: '09260715146',
    address: 'Linga, Pila, Laguna',
  ),
  StaffMember(
    id: 'emp3',
    firstName: 'Virgenita',
    lastName: 'Espiritu',
    username: 'virgenita_espiritu',
    branch: 'Brgy. Nanhaya, Victoria',
    position: 'Branch Cook',
    phone: '09853652758',
    address: 'San Roque, Victoria, Laguna',
  ),
  StaffMember(
    id: 'emp4',
    firstName: 'Jovelle',
    middleName: 'P',
    lastName: 'Camila',
    username: 'jovelle_camila',
    branch: 'Brgy. Gatid, Sta. Cruz',
    position: 'Branch Cook',
    phone: '09655818582',
    address: 'Gatid, Sta. Cruz, Laguna',
  ),
  StaffMember(
    id: 'emp5',
    firstName: 'Patricia Mharie',
    middleName: 'M',
    lastName: 'Espiritu',
    username: 'patricia_espiritu',
    branch: 'Brgy. Sta. Clara Sur, Pila',
    position: 'Branch Cook',
    phone: '09152319790',
    address: 'San Francisco, Victoria, Laguna',
  ),
  StaffMember(
    id: 'emp6',
    firstName: 'Alma',
    middleName: 'D',
    lastName: 'Agonos',
    username: 'alma_agonos',
    branch: 'Brgy. San Francisco, Victoria',
    position: 'Branch Cook',
    phone: '09949178538',
    address: 'San Roque, Victoria, Laguna',
  ),
  StaffMember(
    id: 'emp7',
    firstName: 'Menes',
    lastName: 'Bantug',
    username: 'menes_cook',
    branch: 'N/A',
    position: 'Production Cook',
    phone: 'Pending Info',
    address: 'Production Area',
  ),
  StaffMember(
    id: 'emp8',
    firstName: 'Abby',
    lastName: 'Torres',
    username: 'abby_cutter',
    branch: 'N/A',
    position: 'Production Meat Cutter',
    phone: 'Pending Info',
    address: 'Production Area',
  ),
  StaffMember(
    id: 'emp9',
    firstName: 'Danilo',
    lastName: 'Ramos',
    username: 'danilo_driver',
    branch: 'N/A',
    position: 'Driver',
    phone: 'Pending Info',
    address: 'Logistics / Delivery',
  ),
  StaffMember(
    id: 'emp10',
    firstName: 'Extra Cook 1',
    lastName: '(Floating)',
    username: 'floating_cook_1',
    branch: 'Floating / Any Branch',
    position: 'Floating Cook',
    phone: 'Pending Info',
    address: 'Laguna',
  ),
  StaffMember(
    id: 'emp11',
    firstName: 'Extra Cook 2',
    lastName: '(Floating)',
    username: 'floating_cook_2',
    branch: 'Floating / Any Branch',
    position: 'Floating Cook',
    phone: 'Pending Info',
    address: 'Laguna',
  ),
  StaffMember(
    id: 'emp12',
    firstName: 'Extra Cook 3',
    lastName: '(Floating)',
    username: 'floating_cook_3',
    branch: 'Floating / Any Branch',
    position: 'Floating Cook',
    phone: 'Pending Info',
    address: 'Laguna',
  ),
];
