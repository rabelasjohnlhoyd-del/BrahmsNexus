import 'package:flutter/material.dart';
import '../../../models/daily_report.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';

/// Admin monitors all submitted daily reports here — filterable by
/// branch, searchable by employee, sortable by date, with submission
/// status (Submitted/Missing/Incomplete) at a glance. Replaces the
/// client's old group-chat-based reporting.
///
/// NOTE: Mock data for now — once Supabase is wired up, this reads
/// the real `daily_reports` table (with pagination once the dataset
/// grows past what's comfortable to load at once).
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
    }
  }

  int _countByStatus(ReportSubmissionStatus status) =>
      _reports.where((r) => r.status == status).length;

  void _showReportDetail(DailyReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report.employeeName),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${report.branchName} · ${_formatDate(report.date)}',
                style: const TextStyle(color: AdminWebColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Text(
                report.content.isEmpty
                    ? 'Wala pang naisusumiteng report.'
                    : report.content,
                style: const TextStyle(color: AdminWebColors.textPrimary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
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
                        onPressed: () => setState(() => _dateFilter = null),
                        tooltip: 'Clear Date Filter',
                      ),
                    ],
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
                                        subtitle: Text(
                                          '${r.branchName} · ${_formatDate(r.date)}',
                                        ),
                                        trailing: Container(
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

