import 'package:flutter/material.dart';
import '../models/daily_report.dart';
import '../theme/app_theme.dart';

/// Owner monitors submitted daily reports here — replaces the old
/// group-chat-based reporting. Filterable by branch, sortable by date,
/// and flags missing/incomplete submissions at a glance.
///
/// NOTE: Mock data for now — once Supabase is wired up, this reads
/// the real `daily_reports` table (with proper pagination once the
/// dataset grows).
class ReportsMonitorScreen extends StatefulWidget {
  const ReportsMonitorScreen({super.key});

  @override
  State<ReportsMonitorScreen> createState() => _ReportsMonitorScreenState();
}

class _ReportsMonitorScreenState extends State<ReportsMonitorScreen> {
  final List<DailyReport> _reports = [
    DailyReport(
      id: 'r1',
      employeeId: 'emp1',
      employeeName: 'Juan Dela Cruz',
      branchId: 'br2',
      branchName: 'Sta. Cruz',
      date: DateTime.now(),
      content: 'Kumpleto ang benta ngayong araw, walang isyu sa stock.',
      status: ReportSubmissionStatus.submitted,
    ),
    DailyReport(
      id: 'r2',
      employeeId: 'emp2',
      employeeName: 'Maria Reyes',
      branchId: 'br3',
      branchName: 'Pila',
      date: DateTime.now(),
      content: 'Kulang ang mayo, humingi na ng dagdag kay Driver.',
      status: ReportSubmissionStatus.incomplete,
    ),
    DailyReport(
      id: 'r3',
      employeeId: 'emp3',
      employeeName: 'Pedro Santos',
      branchId: 'br4',
      branchName: 'Labuin',
      date: DateTime.now().subtract(const Duration(days: 1)),
      content: '',
      status: ReportSubmissionStatus.missing,
    ),
  ];

  String? _branchFilter;
  bool _newestFirst = true;

  Color _statusColor(ReportSubmissionStatus status) {
    switch (status) {
      case ReportSubmissionStatus.submitted:
        return AppColors.success;
      case ReportSubmissionStatus.incomplete:
        return AppColors.warning;
      case ReportSubmissionStatus.missing:
        return AppColors.error;
    }
  }

  List<DailyReport> get _visibleReports {
    var list = _reports.where((r) {
      if (_branchFilter == null) return true;
      return r.branchName == _branchFilter;
    }).toList();

    list.sort((a, b) => _newestFirst
        ? b.date.compareTo(a.date)
        : a.date.compareTo(b.date));

    return list;
  }

  void _showReportDetail(DailyReport report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.employeeName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${report.branchName} · ${_formatDate(report.date)}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              report.content.isEmpty
                  ? 'Wala pang naisusumiteng report.'
                  : report.content,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.month}/${date.day}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final branches = _reports.map((r) => r.branchName).toSet().toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Employee Reports')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('All Branches'),
                            selected: _branchFilter == null,
                            onSelected: (_) =>
                                setState(() => _branchFilter = null),
                          ),
                          const SizedBox(width: 8),
                          ...branches.map(
                            (b) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(b),
                                selected: _branchFilter == b,
                                onSelected: (_) =>
                                    setState(() => _branchFilter = b),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _newestFirst ? 'Newest first' : 'Oldest first',
                    icon: Icon(
                      _newestFirst
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                    ),
                    onPressed: () =>
                        setState(() => _newestFirst = !_newestFirst),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _visibleReports.isEmpty
                  ? const Center(
                      child: Text(
                        'Walang report na tumutugma.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _visibleReports.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final report = _visibleReports[index];
                        return Card(
                          child: ListTile(
                            onTap: () => _showReportDetail(report),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.pastelBrown,
                              child: Text(
                                report.employeeName.substring(0, 1),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(report.employeeName),
                            subtitle: Text(
                              '${report.branchName} · ${_formatDate(report.date)}',
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(report.status)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                report.status.label,
                                style: TextStyle(
                                  color: _statusColor(report.status),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
