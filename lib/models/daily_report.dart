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
///
/// [reportType] distinguishes the source of the report:
/// - `'branch'` — regular branch staff daily report
/// - `'production_cook'` — Production Cook batch cooking report
/// - `'production_cutter'` — Production Meat Cutter portioning report
/// - `'driver'` — Driver delivery or route report
class DailyReport {
  const DailyReport({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.branchId,
    required this.branchName,
    required this.date,
    required this.content,
    this.reportType = 'branch',
    this.status = ReportSubmissionStatus.submitted,
    this.ownerReply,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String branchId;
  final String branchName;
  final DateTime date;
  final String content;
  /// One of: 'branch', 'production_cook', 'production_cutter', 'driver'
  final String reportType;
  final ReportSubmissionStatus status;
  final String? ownerReply;

  DailyReport copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? branchId,
    String? branchName,
    DateTime? date,
    String? content,
    String? reportType,
    ReportSubmissionStatus? status,
    String? ownerReply,
  }) {
    return DailyReport(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      date: date ?? this.date,
      content: content ?? this.content,
      reportType: reportType ?? this.reportType,
      status: status ?? this.status,
      ownerReply: ownerReply ?? this.ownerReply,
    );
  }
}
