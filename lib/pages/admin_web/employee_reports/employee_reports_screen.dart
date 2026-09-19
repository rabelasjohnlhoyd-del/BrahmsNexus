import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/branch.dart';
import '../../../models/branch_daily_inventory.dart';
import '../../../models/daily_report.dart';
import '../../../services/firestore_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';

/// Admin monitors all submitted daily reports here — filterable by
/// branch, searchable by employee, sortable by date, with submission
/// status (Submitted/Missing/Incomplete) at a glance. Replaces the
/// client's old group-chat-based reporting.
///
/// Also shows today's Inventory Verification status per branch —
/// actual counts submitted by staff vs what was allocated.
///
/// Backed by live real-time Firestore sync.
class EmployeeReportsScreen extends StatefulWidget {
  const EmployeeReportsScreen({super.key});

  @override
  State<EmployeeReportsScreen> createState() => _EmployeeReportsScreenState();
}

class _EmployeeReportsScreenState extends State<EmployeeReportsScreen> {
  static const double _wideBreakpoint = 700;

  int _currentPage = 0;
  static const int _pageSize = 10;
  DateTime? _dateFilter;
  bool _showResolvedReports = false;
  StreamSubscription<List<DailyReport>>? _reportsSub;

  // Inventory verification
  final List<BranchDailyInventory> _verifications = [];
  StreamSubscription<List<BranchDailyInventory>>? _verifSub;

  final List<DailyReport> _reports = [
    DailyReport(
      id: 'r1',
      employeeId: 'emp1',
      employeeName: 'Juan Dela Cruz',
      branchId: 'br1',
      branchName: 'Brgy. Gatid, Sta. Cruz',
      date: DateTime.now(),
      content: 'Kumpleto ang benta ngayong araw, walang isyu sa stock.',
      status: ReportSubmissionStatus.submitted,
    ),
    DailyReport(
      id: 'r2',
      employeeId: 'emp2',
      employeeName: 'Maria Reyes',
      branchId: 'br3',
      branchName: 'Brgy. Sta. Clara Sur, Pila',
      date: DateTime.now(),
      content: 'Kulang ang mayo, humingi na ng dagdag kay Driver.',
      status: ReportSubmissionStatus.incomplete,
    ),
    DailyReport(
      id: 'r3',
      employeeId: 'emp3',
      employeeName: 'Pedro Santos',
      branchId: 'br2',
      branchName: 'Brgy. Labuin, Pila',
      date: DateTime.now().subtract(const Duration(days: 1)),
      content: '',
      status: ReportSubmissionStatus.missing,
    ),
    DailyReport(
      id: 'r4',
      employeeId: 'emp1',
      employeeName: 'Juan Dela Cruz',
      branchId: 'br1',
      branchName: 'Brgy. Gatid, Sta. Cruz',
      date: DateTime.now().subtract(const Duration(days: 1)),
      content: 'Normal na araw, walang partikular na isyu.',
      status: ReportSubmissionStatus.submitted,
    ),
  ];

  String _searchQuery = '';
  String? _branchFilter;
  bool _newestFirst = true;

  @override
  void initState() {
    super.initState();
    _updateShellActions();
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
  void didUpdateWidget(EmployeeReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([]);
  }

  @override
  void dispose() {
    _reportsSub?.cancel();
    _verifSub?.cancel();
    super.dispose();
  }


  Color _statusColor(ReportSubmissionStatus status) {
    switch (status) {
      case ReportSubmissionStatus.submitted:
        return AdminWebColors.success;
      case ReportSubmissionStatus.incomplete:
        return AdminWebColors.warning;
      case ReportSubmissionStatus.missing:
        return AdminWebColors.error;
    }
  }

  List<DailyReport> get _visibleReports {
    var list = _reports.where((r) {
      final hasResponded = r.ownerReply != null && r.ownerReply!.trim().isNotEmpty;
      if (!_showResolvedReports && hasResponded) {
        return false;
      }
      final matchesSearch = _searchQuery.isEmpty ||
          r.employeeName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesBranch =
          _branchFilter == null || r.branchName == _branchFilter;
      final matchesDate = _dateFilter == null ||
          (r.date.year == _dateFilter!.year &&
           r.date.month == _dateFilter!.month &&
           r.date.day == _dateFilter!.day);
      return matchesSearch && matchesBranch && matchesDate;
    }).toList();

    list.sort((a, b) =>
        _newestFirst ? b.date.compareTo(a.date) : a.date.compareTo(b.date));
    return list;
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFilter ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _dateFilter = picked;
        _currentPage = 0;
      });
      _subscribeInventory();
    }
  }

  void _subscribeInventory() {
    _verifSub?.cancel();
    _verifSub = FirestoreService.watchAllBranchDailyInventories(
      branches: kSampleBranches,
      date: _dateFilter ?? DateTime.now(),
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

  int _countByStatus(ReportSubmissionStatus status) =>
      _reports.where((r) => r.status == status).length;

  void _showReportDetail(DailyReport report) {
    String? currentReply = report.ownerReply;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AdminWebColors.accent,
                child: Text(
                  report.employeeName.isNotEmpty ? report.employeeName.substring(0, 1) : 'E',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(report.employeeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(report.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  report.status.label,
                  style: TextStyle(
                    color: _statusColor(report.status),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${report.branchName} · ${_formatDate(report.date)}',
                  style: const TextStyle(color: AdminWebColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 14),
                const Text(
                  'REPORT CONTENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AdminWebColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminWebColors.surfaceTint.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminWebColors.border),
                  ),
                  child: Text(
                    report.content.isEmpty ? 'Wala pang naisusumiteng report.' : report.content,
                    style: const TextStyle(color: AdminWebColors.textPrimary, fontSize: 13.5, height: 1.4),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'OWNER / ADMIN RESPONSE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AdminWebColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                if (report.status == ReportSubmissionStatus.incomplete)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminWebColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminWebColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: AdminWebColors.warning),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Incomplete report — view details only. Awaiting employee completion.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AdminWebColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (currentReply != null && currentReply.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminWebColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminWebColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_rounded, size: 16, color: AdminWebColors.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentReply,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AdminWebColors.textPrimary, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Response submitted & locked (cannot be edited)',
                                style: TextStyle(fontSize: 11, color: AdminWebColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  const Text(
                    'No response recorded yet.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AdminWebColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  const Text('Quick Reply:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _webReplyButton('Noted', report, dialogCtx, setDialogState),
                      const SizedBox(width: 8),
                      _webReplyButton('Linawin natin', report, dialogCtx, setDialogState),
                      const SizedBox(width: 8),
                      _webReplyButton('Approved', report, dialogCtx, setDialogState),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _webReplyButton(
    String label,
    DailyReport report,
    BuildContext dialogCtx,
    StateSetter setDialogState,
  ) {
    return OutlinedButton(
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (confirmCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.help_outline_rounded, color: AdminWebColors.accent),
                SizedBox(width: 8),
                Text('Confirm Quick Reply', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Are you sure you want to send "$label" as your response to ${report.employeeName}? Once submitted, this reply cannot be changed.',
              style: const TextStyle(fontSize: 13.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(confirmCtx).pop(false),
                child: const Text('CANCEL', style: TextStyle(color: AdminWebColors.textSecondary, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminWebColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.of(confirmCtx).pop(true),
                child: const Text('CONFIRM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (confirmed != true) return;

        setDialogState(() {});
        if (report.id.isNotEmpty) {
          await FirestoreService.replyToDailyReport(reportId: report.id, reply: label);
        }
        final idx = _reports.indexWhere((r) => r.id == report.id);
        if (idx != -1) {
          setState(() {
            _reports[idx] = _reports[idx].copyWith(ownerReply: label);
          });
        }
        if (dialogCtx.mounted) {
          Navigator.of(dialogCtx).pop();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Response "$label" sent to ${report.employeeName}. Report completed.'),
            backgroundColor: AdminWebColors.success,
          ),
        );
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: AdminWebColors.accent,
        backgroundColor: Colors.transparent,
        side: const BorderSide(color: AdminWebColors.accent),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.month}/${date.day}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final branches = _reports.map((r) => r.branchName).toSet().toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;

        final statusCards = [
          _statusCard(
            'Submitted',
            _countByStatus(ReportSubmissionStatus.submitted),
            AdminWebColors.success,
            Icons.check_circle_rounded,
          ),
          _statusCard(
            'Incomplete',
            _countByStatus(ReportSubmissionStatus.incomplete),
            AdminWebColors.warning,
            Icons.error_rounded,
          ),
          _statusCard(
            'Missing',
            _countByStatus(ReportSubmissionStatus.missing),
            AdminWebColors.error,
            Icons.cancel_rounded,
          ),
        ];

        return Container(
          color: AdminWebColors.background,
          child: Padding(
            padding: EdgeInsets.all(isWide ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                isWide
                    ? Row(
                        children: [
                          Expanded(child: statusCards[0]),
                          const SizedBox(width: 12),
                          Expanded(child: statusCards[1]),
                          const SizedBox(width: 12),
                          Expanded(child: statusCards[2]),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: statusCards[0]),
                          const SizedBox(width: 8),
                          Expanded(child: statusCards[1]),
                          const SizedBox(width: 8),
                          Expanded(child: statusCards[2]),
                        ],
                      ),
                const SizedBox(height: 20),

                // ── INVENTORY VERIFICATION SECTION ────────────────────────
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 18, color: AdminWebColors.accent),
                    const SizedBox(width: 8),
                    const Text(
                      'INVENTORY VERIFICATION — TODAY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AdminWebColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminWebColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_verifications.length} branch${_verifications.length == 1 ? '' : 'es'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AdminWebColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_verifications.isEmpty)
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 18, color: AdminWebColors.textSecondary.withValues(alpha: 0.6)),
                        const SizedBox(width: 10),
                        const Text(
                          'Walang branch na nag-verify pa ngayong araw.',
                          style: TextStyle(color: AdminWebColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  isWide
                      ? Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _verifications
                              .map((v) => SizedBox(
                                    width: (constraints.maxWidth - 48 - 12) / 2,
                                    child: _buildVerifCard(v),
                                  ))
                              .toList(),
                        )
                      : Column(
                          children: _verifications
                              .map((v) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _buildVerifCard(v),
                                  ))
                              .toList(),
                        ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text(
                        _dateFilter == null
                            ? 'FILTER BY DATE'
                            : '${_dateFilter!.month}/${_dateFilter!.day}/${_dateFilter!.year}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminWebColors.accent,
                        side: const BorderSide(color: AdminWebColors.accent),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    if (_dateFilter != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AdminWebColors.error, size: 20),
                        onPressed: () {
                          setState(() => _dateFilter = null);
                          _subscribeInventory();
                        },
                        tooltip: 'Clear Date Filter',
                      ),
                    ],
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showResolvedReports = !_showResolvedReports;
                          _currentPage = 0;
                        });
                      },
                      icon: Icon(
                        _showResolvedReports
                            ? Icons.hourglass_top_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 16,
                      ),
                      label: Text(
                        _showResolvedReports
                            ? 'SHOW PENDING ONLY'
                            : 'SHOW RESOLVED (${_reports.where((r) => r.ownerReply != null && r.ownerReply!.isNotEmpty).length})',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _showResolvedReports ? AdminWebColors.warning : AdminWebColors.accent,
                        side: BorderSide(color: _showResolvedReports ? AdminWebColors.warning : AdminWebColors.accent),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _newestFirst = !_newestFirst);
                        _updateShellActions();
                      },
                      icon: Icon(
                        _newestFirst ? Icons.sort_rounded : Icons.history_rounded,
                        size: 16,
                      ),
                      label: Text(
                        _newestFirst ? 'NEWEST FIRST' : 'OLDEST FIRST',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminWebColors.accent,
                        side: const BorderSide(color: AdminWebColors.accent),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                isWide
                    ? Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _branchFilter ?? 'All',
                              decoration: const InputDecoration(
                                labelText: 'FILTER BY BRANCH',
                                isDense: true,
                                prefixIcon: Icon(Icons.storefront_rounded, size: 18),
                              ),
                              items: [
                                const DropdownMenuItem(value: 'All', child: Text('ALL BRANCHES')),
                                ...branches.map((b) => DropdownMenuItem(
                                  value: b,
                                  child: Text(b.toUpperCase()),
                                )),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _branchFilter = (v == 'All' ? null : v);
                                  _currentPage = 0;
                                });
                              },
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              hintText: 'Search by employee name...',
                              prefixIcon: Icon(Icons.search_rounded),
                              isDense: true,
                            ),
                            onChanged: (v) => setState(() {
                              _searchQuery = v;
                              _currentPage = 0;
                            }),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _branchFilter ?? 'All',
                            decoration: const InputDecoration(
                              labelText: 'FILTER BY BRANCH',
                              isDense: true,
                              prefixIcon: Icon(Icons.storefront_rounded, size: 18),
                            ),
                            items: [
                              const DropdownMenuItem(value: 'All', child: Text('ALL BRANCHES')),
                              ...branches.map((b) => DropdownMenuItem(
                                value: b,
                                child: Text(b.toUpperCase()),
                              )),
                            ],
                            onChanged: (v) {
                              setState(() {
                                _branchFilter = (v == 'All' ? null : v);
                                _currentPage = 0;
                              });
                            },
                          ),
                        ],
                      ),
                const SizedBox(height: 16),
                Expanded(
                  child: _visibleReports.isEmpty
                      ? const Center(
                          child: Text(
                            'Walang report na tumutugma.',
                            style: TextStyle(color: AdminWebColors.textSecondary),
                          ),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: ListView.separated(
                                itemCount: (_visibleReports.length - (_currentPage * _pageSize)).clamp(0, _pageSize),
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final r = _visibleReports[(_currentPage * _pageSize) + index];
                                  return GlassCard(
                                    padding: EdgeInsets.zero,
                                    child: Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                      clipBehavior: Clip.antiAlias,
                                      child: ListTile(
                                        onTap: () => _showReportDetail(r),
                                        leading: CircleAvatar(
                                          backgroundColor: AdminWebColors.accent,
                                          child: Text(
                                            r.employeeName.substring(0, 1),
                                            style:
                                                const TextStyle(color: Colors.white),
                                          ),
                                        ),
                                        title: Text(r.employeeName),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${r.branchName} · ${_formatDate(r.date)}'),
                                            if (r.ownerReply != null && r.ownerReply!.isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  const Icon(Icons.reply_rounded, size: 13, color: AdminWebColors.accent),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Response: ${r.ownerReply}',
                                                    style: const TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: AdminWebColors.accent,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                        trailing: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _statusColor(r.status)
                                                    .withValues(alpha: 0.15),
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
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildPagination(_visibleReports.length),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _verifColor(InventoryVerificationStatus s) {
    switch (s) {
      case InventoryVerificationStatus.confirmed:
        return AdminWebColors.success;
      case InventoryVerificationStatus.discrepancyReported:
        return AdminWebColors.error;
      case InventoryVerificationStatus.pending:
        return AdminWebColors.warning;
    }
  }

  IconData _verifIcon(InventoryVerificationStatus s) {
    switch (s) {
      case InventoryVerificationStatus.confirmed:
        return Icons.verified_rounded;
      case InventoryVerificationStatus.discrepancyReported:
        return Icons.warning_amber_rounded;
      case InventoryVerificationStatus.pending:
        return Icons.schedule_rounded;
    }
  }

  void _showVerifDetail(BranchDailyInventory v) {
    final ar = v.actualReceived;
    final color = _verifColor(v.status);

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(_verifIcon(v.status), color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(v.branchName, style: const TextStyle(fontSize: 16))),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        v.status.label,
                        style: TextStyle(color: color, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Spacer(),
                    if (v.verifiedAt != null)
                      Text(
                        'Verified at ${_formatTime(v.verifiedAt!)}',
                        style: const TextStyle(fontSize: 11, color: AdminWebColors.textSecondary),
                      ),
                  ],
                ),
                if (v.verifiedBy != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'by ${v.verifiedBy}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AdminWebColors.textSecondary),
                  ),
                ],
                if (v.discrepancyNote != null && v.discrepancyNote!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('DISCREPANCY NOTE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                          letterSpacing: 0.5, color: AdminWebColors.textSecondary)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AdminWebColors.error.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AdminWebColors.error.withValues(alpha: 0.2)),
                    ),
                    child: Text('"${v.discrepancyNote}"',
                        style: const TextStyle(color: AdminWebColors.error, fontSize: 13, fontStyle: FontStyle.italic)),
                  ),
                ],
                const SizedBox(height: 16),
                // Table header
                Row(
                  children: const [
                    Expanded(child: Text('ITEM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminWebColors.textSecondary))),
                    SizedBox(width: 8),
                    SizedBox(width: 60, child: Text('ALLOC.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminWebColors.textSecondary))),
                    SizedBox(width: 60, child: Text('ACTUAL', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminWebColors.textSecondary))),
                  ],
                ),
                const Divider(),
                _verifDetailRow('Karne (Total Pcs)', v.allocated.karne, ar != null ? (ar.regular + ar.medium + ar.b1t1) : null, color),
                _verifDetailRow('Mayo',    v.allocated.mayo,  ar?.mayo,    color),
                _verifDetailRow('Toyo',    v.allocated.toyo,  ar?.toyo,    color),
                _verifDetailRow('Styro',   v.allocated.styro, ar?.styro,   color),
                if (ar != null) ...[
                  const Divider(),
                  const Text('BREAKDOWN OF ACTUAL MEAT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AdminWebColors.textSecondary)),
                  const SizedBox(height: 4),
                  _verifDetailRow('Regular', null, ar.regular, color),
                  _verifDetailRow('Medium',  null, ar.medium,  color),
                  _verifDetailRow('B1T1',    null, ar.b1t1,    color),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      ),
    );
  }



  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  Widget _verifDetailRow(String label, int? allocated, int? actual, Color color) {
    final mismatch = allocated != null && actual != null && allocated != actual;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              allocated != null ? '$allocated' : '—',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AdminWebColors.textSecondary, fontSize: 13),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              actual != null ? '$actual' : '—',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: mismatch ? AdminWebColors.error : color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifCard(BranchDailyInventory v) {
    final color = _verifColor(v.status);
    final icon = _verifIcon(v.status);
    final ar = v.actualReceived;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showVerifDetail(v),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
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
                          color: AdminWebColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (ar != null)
                        Text(
                          'Reg ${ar.regular}  Med ${ar.medium}  B1T1 ${ar.b1t1}  Mayo ${ar.mayo}  Styro ${ar.styro}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: AdminWebColors.textSecondary),
                        )
                      else
                        const Text(
                          'Hindi pa nag-verify',
                          style: TextStyle(fontSize: 11.5, color: AdminWebColors.textSecondary,
                              fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
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
                      const SizedBox(height: 4),
                      const Text('Click for detail',
                          style: TextStyle(fontSize: 10, color: AdminWebColors.textSecondary)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPagination(int totalItems) {
    final totalPages = (totalItems / _pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
        ),
        Text(
          'Page ${_currentPage + 1} of $totalPages',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AdminWebColors.textSecondary),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
        ),
      ],
    );
  }

  Widget _statusCard(String label, int count, Color color, IconData icon) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AdminWebColors.textSecondary,
                    ),
                  ),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
      ),
    );
  }
}

