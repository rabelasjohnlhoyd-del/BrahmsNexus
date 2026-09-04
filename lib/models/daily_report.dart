enum ReportSubmissionStatus {
  submitted,
  missing,
  incomplete;

  String get label {
    switch (this) {
      case ReportSubmissionStatus.submitted:
        return 'Submitted';
      case ReportSubmissionStatus.missing:
        return 'Missing';
      case ReportSubmissionStatus.incomplete:
        return 'Incomplete';
    }
  }
}

/// An employee's daily operational report — replaces the client's old
/// group-chat-based reporting. The Owner monitors these by employee,
/// branch, and date (Employee Reports / Reports Monitor screens).
class DailyReport {
  const DailyReport({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.branchId,
    required this.branchName,
    required this.date,
    required this.content,
    this.status = ReportSubmissionStatus.submitted,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String branchId;
  final String branchName;
  final DateTime date;
  final String content;
  final ReportSubmissionStatus status;
}
