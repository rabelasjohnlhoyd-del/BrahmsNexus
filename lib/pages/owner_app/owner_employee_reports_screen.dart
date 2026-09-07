import 'package:flutter/cupertino.dart';
import '../../models/branch.dart';
import '../../models/daily_report.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';

/// Employee Reports — Owner monitors all submitted daily reports here,
/// filterable by branch, searchable by employee, with submission
/// status (Submitted/Missing/Incomplete) at a glance. Replaces the
/// client's old group-chat-based reporting.
///
/// Migrated from the old `admin_web/employee_reports` screen. That
/// screen filtered by `branchName` string; here it filters by
/// `branchId` and resolves the display name through [kSampleBranches],
/// same duplicate-data fix already applied to Inventory and Sales &
/// Payroll.
///
/// NOTE: Mock data for now — once Supabase is wired up, this reads
/// the real `daily_reports` table (with pagination once the dataset
/// grows past what's comfortable to load at once).
class OwnerEmployeeReportsScreen extends StatefulWidget {
  const OwnerEmployeeReportsScreen({super.key});

  @override
  State<OwnerEmployeeReportsScreen> createState() =>
      _OwnerEmployeeReportsScreenState();
}

class _OwnerEmployeeReportsScreenState
    extends State<OwnerEmployeeReportsScreen> {
  static String _branchName(String id) =>
      kSampleBranches.firstWhere((b) => b.id == id).fullName;

  final List<DailyReport> _reports = [
    DailyReport(
      id: 'r1',
      employeeId: 'emp1',
      employeeName: 'Juan Dela Cruz',
      branchId: 'br1',
      branchName: _branchName('br1'),
      date: DateTime.now(),
      content: 'Kumpleto ang benta ngayong araw, walang isyu sa stock.',
      status: ReportSubmissionStatus.submitted,
    ),
    DailyReport(
      id: 'r2',
      employeeId: 'emp2',
      employeeName: 'Maria Reyes',
      branchId: 'br3',
      branchName: _branchName('br3'),
      date: DateTime.now(),
      content: 'Kulang ang mayo, humingi na ng dagdag kay Driver.',
      status: ReportSubmissionStatus.incomplete,
    ),
    DailyReport(
      id: 'r3',
      employeeId: 'emp3',
      employeeName: 'Pedro Santos',
      branchId: 'br2',
      branchName: _branchName('br2'),
      date: DateTime.now().subtract(const Duration(days: 1)),
      content: '',
      status: ReportSubmissionStatus.missing,
    ),
    DailyReport(
      id: 'r4',
      employeeId: 'emp1',
      employeeName: 'Juan Dela Cruz',
      branchId: 'br1',
      branchName: _branchName('br1'),
      date: DateTime.now().subtract(const Duration(days: 1)),
      content: 'Normal na araw, walang partikular na isyu.',
      status: ReportSubmissionStatus.submitted,
    ),
  ];

  String _searchQuery = '';
  String? _branchFilter; // branch id, null = all
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
    final list = _reports.where((r) {
      final matchesSearch = _searchQuery.isEmpty ||
          r.employeeName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesBranch =
          _branchFilter == null || r.branchId == _branchFilter;
      return matchesSearch && matchesBranch;
    }).toList();
    list.sort((a, b) =>
        _newestFirst ? b.date.compareTo(a.date) : a.date.compareTo(b.date));
    return list;
  }

  int _countByStatus(ReportSubmissionStatus status) =>
      _reports.where((r) => r.status == status).length;

  String _formatDate(DateTime date) =>
      '${date.month}/${date.day}/${date.year}';

  void _showReportDetail(DailyReport report) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(report.employeeName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              '${report.branchName} \u00b7 ${_formatDate(report.date)}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Text(
              report.content.isEmpty
                  ? 'Wala pang naisusumiteng report.'
                  : report.content,
              style: const TextStyle(fontSize: 13.5),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Employee Reports',
        showBackButton: true,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _statusCountCard(
                      'Submitted',
                      _countByStatus(ReportSubmissionStatus.submitted),
                      AppColors.success,
                      CupertinoIcons.checkmark_circle_fill,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statusCountCard(
                      'Incomplete',
                      _countByStatus(ReportSubmissionStatus.incomplete),
                      AppColors.warning,
                      CupertinoIcons.exclamationmark_circle_fill,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statusCountCard(
                      'Missing',
                      _countByStatus(ReportSubmissionStatus.missing),
                      AppColors.error,
                      CupertinoIcons.xmark_circle_fill,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: CupertinoSearchTextField(
                placeholder: 'Search by employee name',
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            SizedBox(
              height: 34,
              child: Row(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      children: [
                        _filterChip(
                          label: 'All Branches',
                          selected: _branchFilter == null,
                          onTap: () => setState(() => _branchFilter = null),
                        ),
                        const SizedBox(width: 8),
                        for (final b in kSampleBranches) ...[
                          _filterChip(
                            label: b.fullName,
                            selected: _branchFilter == b.id,
                            onTap: () =>
                                setState(() => _branchFilter = b.id),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.only(right: 16),
                    onPressed: () =>
                        setState(() => _newestFirst = !_newestFirst),
                    child: Icon(
                      _newestFirst
                          ? CupertinoIcons.arrow_down
                          : CupertinoIcons.arrow_up,
                      size: 18,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _visibleReports.isEmpty
                  ? const Center(
                      child: Text(
                        'Walang report na tumutugma.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _visibleReports.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _buildReportRow(_visibleReports[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCountCard(
      String label, int count, Color color, IconData icon) {
    return StaffCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : CupertinoColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? CupertinoColors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildReportRow(DailyReport r) {
    return GestureDetector(
      onTap: () => _showReportDetail(r),
      child: StaffCard(
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.accentDark,
                shape: BoxShape.circle,
              ),
              child: Text(
                r.employeeName.substring(0, 1),
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.employeeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${r.branchName} \u00b7 ${_formatDate(r.date)}',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(r.status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                r.status.label,
                style: TextStyle(
                  color: _statusColor(r.status),
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
