/// Whether an employee is on duty or on a rest day for a given date.
enum WorkStatus {
  onDuty,
  restDay;

  String get label => this == WorkStatus.onDuty ? 'On Duty' : 'Rest Day';
}

/// The Owner assigns each employee to a specific branch for a specific
/// date. This record is what the Staff app reads to show "Today's
/// Assignment", and what the Driver app reads to build the day's route
/// (who to pick up, and at which branch to drop them).
class BranchAssignment {
  const BranchAssignment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.branchId,
    required this.branchName,
    required this.date,
    required this.workStatus,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String branchId;
  final String branchName;
  final DateTime date;
  final WorkStatus workStatus;
}
