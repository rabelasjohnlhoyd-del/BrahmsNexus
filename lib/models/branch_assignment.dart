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

  BranchAssignment copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? branchId,
    String? branchName,
    DateTime? date,
    WorkStatus? workStatus,
  }) {
    return BranchAssignment(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      date: date ?? this.date,
      workStatus: workStatus ?? this.workStatus,
    );
  }
}
