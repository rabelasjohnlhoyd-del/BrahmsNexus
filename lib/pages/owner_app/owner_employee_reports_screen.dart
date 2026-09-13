import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../../models/branch.dart';
import '../../models/daily_report.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';

/// Employee Reports — Owner monitors all submitted daily reports here,
/// filterable by branch, searchable by employee, with submission
/// status (Submitted/Missing/Incomplete) at a glance. Replaces the
/// client's old group-chat-based reporting.
///
/// Backed by live real-time Firestore sync.
class OwnerEmployeeReportsScreen extends StatefulWidget {
  const OwnerEmployeeReportsScreen({super.key});

  @override
  State<OwnerEmployeeReportsScreen> createState() =>
      _OwnerEmployeeReportsScreenState();
}

class _OwnerEmployeeReportsScreenState
    extends State<OwnerEmployeeReportsScreen> {
  static String _branchName(String id) =>
      kSampleBranches.firstWhere((b) => b.id == id, orElse: () => kSampleBranches.first).fullName;

  // Store replies in memory during the session
  final Map<String, String> _ownerReplies = {};
  StreamSubscription<List<DailyReport>>? _reportsSub;

  @override
  void initState() {
    super.initState();
    _reportsSub = FirestoreService.watchDailyReports().listen((list) {
      if (mounted) {
        setState(() {
          _reports
            ..clear()
            ..addAll(list);
        });
      }
    });
  }

  @override
  void dispose() {
    _reportsSub?.cancel();
    super.dispose();
  }

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

  void _showBranchPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Filter by Branch'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _branchFilter = null);
              Navigator.pop(context);
            },
            child: const Text('All Branches'),
          ),
          ...kSampleBranches.map((b) => CupertinoActionSheetAction(
                onPressed: () {
                  setState(() => _branchFilter = b.id);
                  Navigator.pop(context);
                },
                child: Text(b.fullName),
              )),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showDatePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: CupertinoColors.white,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const Text('Select Date', style: TextStyle(fontWeight: FontWeight.w600)),
                CupertinoButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: DateTime.now(),
                onDateTimeChanged: (d) {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDetail(DailyReport report) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => CupertinoAlertDialog(
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
              const SizedBox(height: 20),
              const Text(
                'OWNER RESPONSE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              if (_ownerReplies[report.id] != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    _ownerReplies[report.id]!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                )
              else
                const Text(
                  'No response yet.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                ),
              const SizedBox(height: 16),
              const Text('Quick Reply:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _replyChip('Noted', report.id, setDialogState),
                  _replyChip('Linawin natin', report.id, setDialogState),
                ],
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
      ),
    );
  }

  Widget _replyChip(String label, String reportId, StateSetter setDialogState) {
    final isSelected = _ownerReplies[reportId] == label;
    return GestureDetector(
      onTap: () {
        setState(() => _ownerReplies[reportId] = label);
        setDialogState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? CupertinoColors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: StaffNavBar(
        title: 'Employee Reports',
        showBackButton: true,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showDatePicker,
          child: const Icon(CupertinoIcons.calendar, size: 22, color: AppColors.accent),
        ),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _showBranchPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _branchFilter == null
                                  ? 'All Branches'
                                  : kSampleBranches
                                      .firstWhere((b) => b.id == _branchFilter)
                                      .fullName,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600),
                            ),
                            const Icon(CupertinoIcons.chevron_down,
                                size: 14, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => _newestFirst = !_newestFirst),
                    child: Icon(
                      _newestFirst ? CupertinoIcons.arrow_down : CupertinoIcons.arrow_up,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${r.branchName} \u00b7 ${_formatDate(r.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
