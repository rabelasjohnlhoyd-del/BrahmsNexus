/// The user roles supported by Brahms Nexus, based on the flowcharts and
/// merged system requirements:
/// - Owner/Administrator (full control — Web; narrower monitoring app — Mobile)
/// - Branch Employee/Staff (cooks assigned per branch — Mobile)
/// - Driver (route, RFID attendance pickup, inter-branch transfers,
///   bilao deliveries — Mobile)
enum UserRole {
  owner,
  staff,
  driver;

  String get label {
    switch (this) {
      case UserRole.owner:
        return 'Owner / Administrator';
      case UserRole.staff:
        return 'Staff';
      case UserRole.driver:
        return 'Driver';
    }
  }
}
