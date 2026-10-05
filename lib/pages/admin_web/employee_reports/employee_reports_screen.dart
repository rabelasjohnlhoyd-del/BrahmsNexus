import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/branch.dart';
import '../../../models/branch_daily_inventory.dart';
import '../../../models/daily_report.dart';
import '../../../services/firestore_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import '../admin_web_widgets/admin_pagination_bar.dart';

/// Admin monitors all submitted daily reports here — filterable by
/// branch, searchable by employee, sortable by date, with submission
/// status (Submitted/Missing/Incomplete) at a glance.
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

  int _selectedTab = 0; // 0: Daily Reports, 1: Inventory Verification
  int _currentPage = 0;
  static const int _pageSize = 5;
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
      content: 'Sales completed for today, no stock issues.',
      status: ReportSubmissionStatus.submitted,
    ),
    DailyReport(
      id: 'r2',
      employeeId: 'emp2',
      employeeName: 'Maria Reyes',
      branchId: 'br3',
      branchName: 'Brgy. Sta. Clara Sur, Pila',
      date: DateTime.now(),
      content: 'Mayonnaise running low, requested restock from driver.',
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
      content: 'Normal day, no specific issues.',
      status: ReportSubmissionStatus.submitted,
    ),
  ];

  final _searchController = TextEditingController();
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
    shell?.setTitle(_selectedTab == 0 ? 'EMPLOYEE REPORTS' : 'INVENTORY VERIFICATION');
    shell?.setActions([]);
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  int _countVerifByStatus(InventoryVerificationStatus status) =>
      _verifications.where((v) => v.status == status).length;

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'E';
  }

  void _showReportDetail(DailyReport report) {
    String? currentReply = report.ownerReply;
    final replyController = TextEditingController();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5EDE6),
                  shape: BoxShape.circle,
                  border: Border.all(color: AdminWebColors.accent.withValues(alpha: 0.2)),
                ),
                alignment: Alignment.center,
                child: Text(
                  _getInitials(report.employeeName),
                  style: const TextStyle(color: AdminWebColors.accent, fontSize: 13, fontWeight: FontWeight.bold),
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
                    report.content.isEmpty ? 'No report submitted yet.' : report.content,
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
                if (currentReply != null && currentReply!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminWebColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminWebColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 16, color: AdminWebColors.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentReply!,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AdminWebColors.textPrimary, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Response sent to branch cook',
                                style: TextStyle(fontSize: 11, color: AdminWebColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: replyController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Type a response for ${report.employeeName} (e.g. Driver is on the way for delivery)...',
                    hintStyle: const TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AdminWebColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AdminWebColors.accent),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: isSending
                        ? null
                        : () async {
                            final text = replyController.text.trim();
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
                              setDialogState(() {
                                isSending = false;
                                currentReply = text;
                              });
                              final idx = _reports.indexWhere((r) => r.id == report.id);
                              if (idx != -1) {
                                setState(() {
                                  _reports[idx] = _reports[idx].copyWith(ownerReply: text);
                                });
                              }
                              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Response sent to ${report.employeeName}.'),
                                    backgroundColor: AdminWebColors.success,
                                  ),
                                );
                              }
                            } else {
                              setDialogState(() => isSending = false);
                            }
                          },
                    icon: isSending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(isSending ? 'Sending...' : 'SEND RESPONSE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminWebColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
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

  String _formatDate(DateTime date) =>
      '${date.month}/${date.day}/${date.year}';

  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedTab == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = index;
            _currentPage = 0;
          });
          _updateShellActions();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AdminWebColors.accent : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AdminWebColors.accent : AdminWebColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AdminWebColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AdminWebColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filterOptions = <String>{
      ...kSampleBranches.map((b) => b.fullName),
      'Production Cook',
      'Production Meat Cutter',
      'Driver',
      ..._reports.map((r) => r.branchName),
    }.where((b) => b.isNotEmpty).toList();

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

        final verifStatusCards = [
          _statusCard(
            'Confirmed',
            _countVerifByStatus(InventoryVerificationStatus.confirmed),
            AdminWebColors.success,
            Icons.verified_rounded,
          ),
          _statusCard(
            'Pending Input',
            _countVerifByStatus(InventoryVerificationStatus.pending),
            AdminWebColors.warning,
            Icons.schedule_rounded,
          ),
          _statusCard(
            'Discrepancy',
            _countVerifByStatus(InventoryVerificationStatus.discrepancyReported),
            AdminWebColors.error,
            Icons.warning_amber_rounded,
          ),
        ];

        return Container(
          color: AdminWebColors.background,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Top Sub-Tab Switcher
              Row(
                children: [
                  _buildTabButton(
                    index: 0,
                    label: 'STAFF DAILY REPORTS',
                    icon: Icons.fact_check_rounded,
                  ),
                  const SizedBox(width: 10),
                  _buildTabButton(
                    index: 1,
                    label: 'INVENTORY VERIFICATION',
                    icon: Icons.verified_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── TAB 0: STAFF DAILY REPORTS ─────────────────────────────────
              if (_selectedTab == 0) ...[
                Row(
                  children: [
                    Expanded(child: statusCards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: statusCards[1]),
                    const SizedBox(width: 12),
                    Expanded(child: statusCards[2]),
                  ],
                ),
                const SizedBox(height: 20),

                // Sleek Unified Search & Filter Toolbar
                GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, barConstraints) {
                      final isBarWide = barConstraints.maxWidth >= 800;

                      final searchField = SizedBox(
                        width: isBarWide ? 280 : double.infinity,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() {
                            _searchQuery = v;
                            _currentPage = 0;
                          }),
                          decoration: InputDecoration(
                            hintText: 'Search employee name...',
                            hintStyle: const TextStyle(fontSize: 12.5, color: AdminWebColors.textSecondary),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AdminWebColors.accent),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _currentPage = 0;
                                      });
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AdminWebColors.border),
                            ),
                          ),
                        ),
                      );

                      final branchDropdown = SizedBox(
                        width: isBarWide ? 240 : double.infinity,
                        child: DropdownButtonFormField<String>(
                          initialValue: _branchFilter ?? 'All',
                          isExpanded: true,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            prefixIcon: const Icon(Icons.storefront_rounded, size: 18, color: AdminWebColors.accent),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AdminWebColors.border),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(value: 'All', child: Text('ALL BRANCHES / ROLES', style: TextStyle(fontSize: 12))),
                            ...filterOptions.map((b) => DropdownMenuItem(
                              value: b,
                              child: Text(b.toUpperCase(), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            )),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _branchFilter = (v == 'All' ? null : v);
                              _currentPage = 0;
                            });
                          },
                        ),
                      );

                      final dateBtn = OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_rounded, size: 15),
                        label: Text(
                          _dateFilter == null
                              ? 'FILTER DATE'
                              : '${_dateFilter!.month}/${_dateFilter!.day}/${_dateFilter!.year}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminWebColors.accent,
                          side: const BorderSide(color: AdminWebColors.accent),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      );

                      final dateClearBtn = _dateFilter != null
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: AdminWebColors.error, size: 18),
                              onPressed: () {
                                setState(() => _dateFilter = null);
                                _subscribeInventory();
                              },
                              tooltip: 'Clear Date Filter',
                            )
                          : const SizedBox.shrink();

                      final resolvedToggle = OutlinedButton.icon(
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
                          size: 15,
                        ),
                        label: Text(
                          _showResolvedReports
                              ? 'SHOW PENDING'
                              : 'SHOW RESOLVED (${_reports.where((r) => r.ownerReply != null && r.ownerReply!.isNotEmpty).length})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _showResolvedReports ? AdminWebColors.warning : AdminWebColors.accent,
                          side: BorderSide(color: _showResolvedReports ? AdminWebColors.warning : AdminWebColors.accent),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      );

                      final sortBtn = OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _newestFirst = !_newestFirst);
                          _updateShellActions();
                        },
                        icon: Icon(
                          _newestFirst ? Icons.sort_rounded : Icons.history_rounded,
                          size: 15,
                        ),
                        label: Text(
                          _newestFirst ? 'NEWEST FIRST' : 'OLDEST FIRST',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminWebColors.accent,
                          side: const BorderSide(color: AdminWebColors.accent),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      );

                      if (isBarWide) {
                        return Row(
                          children: [
                            searchField,
                            const SizedBox(width: 10),
                            branchDropdown,
                            const SizedBox(width: 10),
                            dateBtn,
                            if (_dateFilter != null) dateClearBtn,
                            const Spacer(),
                            resolvedToggle,
                            const SizedBox(width: 8),
                            sortBtn,
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          searchField,
                          const SizedBox(height: 10),
                          branchDropdown,
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              dateBtn,
                              if (_dateFilter != null) dateClearBtn,
                              resolvedToggle,
                              sortBtn,
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Daily Reports List View
                Expanded(
                  child: _visibleReports.isEmpty
                      ? const Center(
                          child: Text(
                            'No matching reports found.',
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
                                        leading: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF5EDE6),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: AdminWebColors.accent.withValues(alpha: 0.2)),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            _getInitials(r.employeeName),
                                            style: const TextStyle(color: AdminWebColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        title: Text(
                                          r.employeeName,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 2),
                                            Text(
                                              '${r.branchName} · ${_formatDate(r.date)}',
                                              style: const TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
                                            ),
                                            if (r.ownerReply != null && r.ownerReply!.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.reply_rounded, size: 13, color: AdminWebColors.accent),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      'Response: ${r.ownerReply}',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: AdminWebColors.accent,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                        trailing: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _statusColor(r.status).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            r.status.label,
                                            style: TextStyle(
                                              color: _statusColor(r.status),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            AdminPaginationBar(
                              currentPage: _currentPage,
                              totalItems: _visibleReports.length,
                              pageSize: _pageSize,
                              onPageChanged: (p) => setState(() => _currentPage = p),
                            ),
                          ],
                        ),
                ),
              ],

              // ── TAB 1: INVENTORY VERIFICATION ──────────────────────────────
              if (_selectedTab == 1) ...[
                Row(
                  children: [
                    Expanded(child: verifStatusCards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: verifStatusCards[1]),
                    const SizedBox(width: 12),
                    Expanded(child: verifStatusCards[2]),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 20, color: AdminWebColors.accent),
                    const SizedBox(width: 8),
                    const Text(
                      'TODAY\'S INVENTORY VERIFICATION',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AdminWebColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminWebColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_verifications.length} branches',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AdminWebColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: _verifications.isEmpty
                      ? GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.schedule_rounded, size: 40, color: AdminWebColors.border),
                                SizedBox(height: 10),
                                Text(
                                  'No branches have verified inventory yet today.',
                                  style: TextStyle(color: AdminWebColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        )
                      : isWide
                          ? GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 2.1,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                              ),
                              itemCount: _verifications.length,
                              itemBuilder: (ctx, i) => _buildVerifCard(_verifications[i]),
                            )
                          : ListView.separated(
                              itemCount: _verifications.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (ctx, i) => _buildVerifCard(_verifications[i]),
                            ),
                ),
              ],
            ],
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.branchName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AdminWebColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            v.verifiedBy != null && v.verifiedAt != null
                                ? 'Verified by ${v.verifiedBy} · ${_formatTime(v.verifiedAt!)}'
                                : 'Awaiting staff verification',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AdminWebColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        v.status.label,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AdminWebColors.surfaceTint.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AdminWebColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 13, color: AdminWebColors.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ar != null
                              ? 'Actual: ${ar.regular + ar.medium + ar.b1t1} Meat · ${ar.mayo} Mayo · ${ar.styro} Styro'
                              : 'Allocated: ${v.allocated.karne} Meat · ${v.allocated.mayo} Mayo · ${v.allocated.toyo} Toyo · ${v.allocated.styro} Styro',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AdminWebColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
