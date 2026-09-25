import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../../models/branch.dart';
import '../../models/branch_daily_inventory.dart';
import '../../models/daily_report.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/app_pagination_bar.dart';

/// Employee Reports — Owner monitors all submitted daily reports here,
/// filterable by branch, searchable by employee, with submission
/// status (Submitted/Missing/Incomplete) at a glance. Replaces the
/// client's old group-chat-based reporting.
///
/// Also shows today's Inventory Verification status for all branches —
/// which staff confirmed, who reported discrepancies, and the exact
/// actual counts they submitted vs what was allocated.
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

  int _currentPage = 0;
  static const int _pageSize = 5;

  // Store replies in memory during the session
  final Map<String, String> _ownerReplies = {};
  StreamSubscription<List<DailyReport>>? _reportsSub;

  // Inventory verification stream
  final List<BranchDailyInventory> _verifications = [];
  StreamSubscription<List<BranchDailyInventory>>? _verifSub;

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

    _verifSub = FirestoreService.watchAllBranchDailyInventories(
      branches: kSampleBranches,
      date: DateTime.now(),
    ).listen((list) {
      if (mounted) {
        setState(() {
          _verifications
            ..clear()
            ..addAll(list);
        });
      }
    });
  }

  @override
  void dispose() {
    _reportsSub?.cancel();
    _verifSub?.cancel();
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
      final matchesBranch = _branchFilter == null ||
          r.branchId == _branchFilter ||
          r.reportType == _branchFilter ||
          r.branchName.toLowerCase() == _branchFilter!.toLowerCase();
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

  String _getFilterLabel() {
    if (_branchFilter == null) return 'All';
    if (_branchFilter == 'production_cook') return 'Production Cook';
    if (_branchFilter == 'production_cutter') return 'Production Meat Cutter';
    if (_branchFilter == 'driver') return 'Driver';
    final branch = kSampleBranches.where((b) => b.id == _branchFilter).firstOrNull;
    if (branch != null) return branch.fullName;
    final rep = _reports.where((r) => r.branchId == _branchFilter || r.branchName == _branchFilter).firstOrNull;
    if (rep != null) return rep.branchName;
    return _branchFilter!;
  }

  void _showBranchPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Filter'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() {
                _branchFilter = null;
                _currentPage = 0;
              });
              Navigator.pop(context);
            },
            child: const Text('All'),
          ),
          ...kSampleBranches.map((b) => CupertinoActionSheetAction(
                onPressed: () {
                  setState(() {
                    _branchFilter = b.id;
                    _currentPage = 0;
                  });
                  Navigator.pop(context);
                },
                child: Text(b.fullName),
              )),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() {
                _branchFilter = 'production_cook';
                _currentPage = 0;
              });
              Navigator.pop(context);
            },
            child: const Text('Production Cook'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() {
                _branchFilter = 'production_cutter';
                _currentPage = 0;
              });
              Navigator.pop(context);
            },
            child: const Text('Production Meat Cutter'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() {
                _branchFilter = 'driver';
                _currentPage = 0;
              });
              Navigator.pop(context);
            },
            child: const Text('Driver'),
          ),
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
    final replyCtrl = TextEditingController();
    bool isSending = false;

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final effectiveReply = report.ownerReply ?? _ownerReplies[report.id];
          return CupertinoAlertDialog(
            title: Text(report.employeeName),
            content: SingleChildScrollView(
              child: Column(
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
                  const SizedBox(height: 18),
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
                  if (effectiveReply != null && effectiveReply.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        effectiveReply,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  CupertinoTextField(
                    controller: replyCtrl,
                    placeholder: 'I-type ang tugon kay ${report.employeeName}...',
                    maxLines: 3,
                    padding: const EdgeInsets.all(10),
                    style: const TextStyle(fontSize: 13),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(8),
                      onPressed: isSending
                          ? null
                          : () async {
                              final text = replyCtrl.text.trim();
                              if (text.isEmpty) return;
                              setDialogState(() => isSending = true);

                              final ok = await FirestoreService.replyToDailyReport(
                                reportId: report.id,
                                reply: text,
                                branchName: report.branchName,
                                employeeId: report.employeeId,
                                employeeName: report.employeeName,
                              );

                              if (ok) {
                                setState(() => _ownerReplies[report.id] = text);
                                setDialogState(() => isSending = false);
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
                              } else {
                                setDialogState(() => isSending = false);
                              }
                            },
                      child: Text(
                        isSending ? 'Sending...' : 'Ipadala ang Tugon',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: CupertinoColors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            // ── REPORT SUMMARY CARDS ─────────────────────────────────────
            Row(
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
            const SizedBox(height: 20),

            // ── INVENTORY VERIFICATION SECTION ───────────────────────────
            const StaffSectionHeader(
              label: 'Inventory Verification — Today',
              icon: CupertinoIcons.checkmark_seal_fill,
              subtitle: 'Actual counts submitted by each branch',
              large: true,
            ),
            const SizedBox(height: 12),
            if (_verifications.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.pastelBrown.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(CupertinoIcons.clock, size: 16, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text(
                      'Walang branch na nag-verify pa ngayong araw.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ..._verifications.map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildVerificationRow(v),
                  )),

            const SizedBox(height: 20),

            // ── SEARCH & FILTER ───────────────────────────────────────────
            CupertinoSearchTextField(
              placeholder: 'Search by employee name',
              onChanged: (v) => setState(() {
                _searchQuery = v;
                _currentPage = 0;
              }),
            ),
            const SizedBox(height: 10),
            Row(
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
                            _getFilterLabel(),
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
            const SizedBox(height: 12),

            // ── REPORTS LIST ──────────────────────────────────────────────
            if (_visibleReports.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Walang report na tumutugma.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else ...[
              ..._visibleReports
                  .skip(_currentPage * _pageSize)
                  .take(_pageSize)
                  .map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildReportRow(r),
                      )),
              AppPaginationBar(
                currentPage: _currentPage,
                totalItems: _visibleReports.length,
                pageSize: _pageSize,
                onPageChanged: (p) => setState(() => _currentPage = p),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _verifColor(InventoryVerificationStatus s) {
    switch (s) {
      case InventoryVerificationStatus.confirmed:
        return AppColors.success;
      case InventoryVerificationStatus.discrepancyReported:
        return AppColors.error;
      case InventoryVerificationStatus.pending:
        return AppColors.warning;
    }
  }

  IconData _verifIcon(InventoryVerificationStatus s) {
    switch (s) {
      case InventoryVerificationStatus.confirmed:
        return CupertinoIcons.checkmark_seal_fill;
      case InventoryVerificationStatus.discrepancyReported:
        return CupertinoIcons.exclamationmark_triangle_fill;
      case InventoryVerificationStatus.pending:
        return CupertinoIcons.clock_fill;
    }
  }

  Widget _verifRow(String label, int? allocated, int? actual, Color color) {
    final mismatch = allocated != null && actual != null && allocated != actual;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5))),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              allocated != null ? '$allocated' : '—',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 40,
            child: Text(
              actual != null ? '$actual' : '—',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: mismatch ? AppColors.error : color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVerificationDetail(BranchDailyInventory v) {
    final ar = v.actualReceived;
    final color = _verifColor(v.status);

    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(v.branchName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                v.status.label,
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            if (v.discrepancyNote != null && v.discrepancyNote!.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Discrepancy Note:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text('"${v.discrepancyNote}"',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.error)),
            ],
            const SizedBox(height: 14),
            Row(
              children: const [
                Expanded(child: Text('Item', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary))),
                SizedBox(width: 8),
                Text('Alloc.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                SizedBox(width: 16),
                Text('Actual', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 6),
            _verifRow('Mayo',    v.allocated.mayo,  ar?.mayo,    color),
            _verifRow('Toyo',    v.allocated.toyo,  ar?.toyo,    color),
            _verifRow('Styro',   v.allocated.styro, ar?.styro,   color),
            _verifRow('Regular', v.allocated.karne, ar?.regular, color),
            _verifRow('Medium',  null,              ar?.medium,  color),
            _verifRow('B1T1',    null,              ar?.b1t1,    color),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationRow(BranchDailyInventory v) {
    final color = _verifColor(v.status);
    final icon = _verifIcon(v.status);
    final ar = v.actualReceived;

    return GestureDetector(
      onTap: () => _showVerificationDetail(v),
      child: StaffCard(
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.branchName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (ar != null)
                    Text(
                      'Reg ${ar.regular}  Med ${ar.medium}  B1T1 ${ar.b1t1}  Mayo ${ar.mayo}  Styro ${ar.styro}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    )
                  else
                    const Text(
                      'Hindi pa nag-verify',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    v.status.label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
                if (ar != null) ...[
                  const SizedBox(height: 3),
                  const Text(
                    'Tap para sa detalye',
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ],
              ],
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
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
                if ((r.ownerReply ?? _ownerReplies[r.id]) != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.reply, size: 10, color: AppColors.accent),
                      const SizedBox(width: 3),
                      Text(
                        r.ownerReply ?? _ownerReplies[r.id]!,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
