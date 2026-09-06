import 'package:flutter/material.dart';
import '../../../models/daily_report.dart';
import '../../../theme/app_theme.dart';

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
      final matchesSearch = _searchQuery.isEmpty ||
          r.employeeName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesBranch =
          _branchFilter == null || r.branchName == _branchFilter;
      return matchesSearch && matchesBranch;
    }).toList();

    list.sort((a, b) =>
        _newestFirst ? b.date.compareTo(a.date) : a.date.compareTo(b.date));
    return list;
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
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Text(
                report.content.isEmpty
                    ? 'Wala pang naisusumiteng report.'
                    : report.content,
                style: const TextStyle(color: AppColors.textPrimary),
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
            AppColors.success,
            Icons.check_circle_rounded,
          ),
          _statusCard(
            'Incomplete',
            _countByStatus(ReportSubmissionStatus.incomplete),
            AppColors.warning,
            Icons.error_rounded,
          ),
          _statusCard(
            'Missing',
            _countByStatus(ReportSubmissionStatus.missing),
            AppColors.error,
            Icons.cancel_rounded,
          ),
        ];

        return Padding(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Employee Reports',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
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
              isWide
                  ? Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Search by employee name...',
                              prefixIcon: Icon(Icons.search_rounded),
                              isDense: true,
                            ),
                            onChanged: (v) =>
                                setState(() => _searchQuery = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _branchChips(branches),
                        ),
                        IconButton(
                          tooltip:
                              _newestFirst ? 'Newest first' : 'Oldest first',
                          icon: Icon(
                            _newestFirst
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                          ),
                          onPressed: () =>
                              setState(() => _newestFirst = !_newestFirst),
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
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _branchChips(branches)),
                            IconButton(
                              tooltip: _newestFirst
                                  ? 'Newest first'
                                  : 'Oldest first',
                              icon: Icon(
                                _newestFirst
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                              ),
                              onPressed: () => setState(
                                  () => _newestFirst = !_newestFirst),
                            ),
                          ],
                        ),
                      ],
                    ),
              const SizedBox(height: 16),
              Expanded(
                child: _visibleReports.isEmpty
                    ? const Center(
                        child: Text(
                          'Walang report na tumutugma.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _visibleReports.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final r = _visibleReports[index];
                          return Card(
                            child: ListTile(
                              onTap: () => _showReportDetail(r),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.pastelBrown,
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
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _branchChips(List<String> branches) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All Branches'),
            selected: _branchFilter == null,
            onSelected: (_) => setState(() => _branchFilter = null),
          ),
          const SizedBox(width: 8),
          ...branches.map(
            (b) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(b),
                selected: _branchFilter == b,
                onSelected: (_) => setState(() => _branchFilter = b),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(String label, int count, Color color, IconData icon) {
    return Card(
      child: Padding(
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
                      color: AppColors.textSecondary,
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
      ),
    );
  }
}
