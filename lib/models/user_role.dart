/// The two user roles supported by Brahms Nexus, as defined in the
/// project's target user analysis:
/// - Administrator/Owner
/// - Branch Employee/Staff
enum UserRole {
  admin,
  employee;

  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.employee:
        return 'Branch Employee';
    }
  }
}
