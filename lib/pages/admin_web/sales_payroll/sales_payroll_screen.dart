import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/inventory_batch.dart';
import '../../../models/sales_record.dart';
import '../../../models/branch.dart';
import '../../../models/financial_period.dart';
import '../../../services/firestore_service.dart';
import '../../../services/attendance_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import '../admin_web_widgets/admin_pagination_bar.dart';
import 'sales_payroll_export_dialog.dart';

/// Admin monitors daily sales and payroll here.
/// Separated into 2 main sections:
/// 1. Branch Cooks (6 Stores) - Grouped by Date or Branch
/// 2. Production Staff & Driver Payroll - Dedicated view for Cook, Cutter, and Driver
class SalesPayrollScreen extends StatefulWidget {
  const SalesPayrollScreen({super.key});

  @override
  State<SalesPayrollScreen> createState() => _SalesPayrollScreenState();
}

class _SalesPayrollScreenState extends State<SalesPayrollScreen> {
  static const double _wideBreakpoint = 700;

  int _selectedTab = 0; // 0 = Branch Cooks, 1 = Production & Driver
  int _currentPage = 0;
  static const int _pageSize = 5;

  StreamSubscription<List<SalesRecord>>? _salesSub;
  StreamSubscription<List<KarneBatch>>? _batchesSub;
  StreamSubscription<FinancialPeriod?>? _periodSub;
  StreamSubscription<List<Map<String, dynamic>>>? _attendanceSub;

  final List<SalesRecord> _records = [];
  final List<KarneBatch> _batches = [];

  String? _branchFilter;
  bool _groupByDate = true;

  // Production staff rates
  double _productionCookRate = 1000.0;
  double _productionCutterRate = 1100.0;
  double _driverDailyRate = 650.0;
  int _driverDaysWorked = 25;
  final Set<String> _expandedDates = {};

  // RFID-based attendance days worked (loaded from Supabase attendance_logs)
  int _cookRfidDaysWorked = 0;
  int _cutterRfidDaysWorked = 0;
  int _driverRfidDaysWorked = 0;
  bool _rfidLoading = true;

  String get _currentPeriodId =>
      '${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}';

  List<SalesRecord> get _visibleRecords {
    if (_branchFilter == null || _branchFilter == 'All') return _records;
    return _records.where((r) => r.branchName == _branchFilter).toList();
  }

  double get _totalSales =>
      _visibleRecords.fold(0, (sum, r) => sum + r.totalSalesAmount);
  double get _totalWages =>
      _visibleRecords.fold(0, (sum, r) => sum + r.computedWage);
  double get _totalRemittance =>
      _visibleRecords.fold(0, (sum, r) => sum + r.expectedCashRemittance);

  // Group records by Date (YYYY-MM-DD)
  Map<String, List<SalesRecord>> get _groupedByDateRecords {
    final map = <String, List<SalesRecord>>{};
    for (var r in _visibleRecords) {
      final key =
          '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}-${r.date.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  // Count total cooking sessions for the current month
  int get _totalCookingSessions {
    final now = DateTime.now();
    int count = 0;
    for (var b in _batches) {
      if (b.date.year == now.year && b.date.month == now.month) {
        count += b.sessions.length;
      }
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    _updateShellActions();

    _salesSub = FirestoreService.watchRecentSales(limit: 100).listen((records) {
      if (mounted) {
        setState(() {
          _records
            ..clear()
            ..addAll(records);
        });
      }
    });

    _batchesSub = FirestoreService.watchProductionBatches().listen((batches) {
      if (mounted) {
        setState(() {
          _batches
            ..clear()
            ..addAll(batches);
        });
      }
    });

    _periodSub = FirestoreService.watchMonthlyFinancialPeriod(_currentPeriodId).listen((period) {
      if (mounted && period != null) {
        setState(() {
          _productionCookRate = period.productionCookDailyRate;
          _productionCutterRate = period.productionCutterDailyRate;
          _driverDailyRate = period.driverDailyWage;
          _driverDaysWorked = period.driverWorkingDays;
        });
      }
    });

    // Load RFID-based attendance days worked for production staff & driver
    _loadRfidAttendance();

    // Listen to real-time RFID attendance updates so timeouts record automatically without manual refresh
    _attendanceSub = AttendanceService.watchTodayAttendance().listen((_) {
      if (!mounted) return;
      _loadRfidAttendance();
    });
  }

  /// Loads RFID-based completed shift counts from Supabase attendance_logs
  /// for the current month. A day is counted only when BOTH time_in and time_out exist.
  Future<void> _loadRfidAttendance() async {
    if (!mounted) return;
    setState(() => _rfidLoading = true);
    try {
      final results = await Future.wait([
        AttendanceService.getRfidDaysWorkedForMonth(
          positionKeywords: ['Production Cook'],
        ),
        AttendanceService.getRfidDaysWorkedForMonth(
          positionKeywords: ['Meat Cutter', 'Production Meat'],
        ),
        AttendanceService.getRfidDaysWorkedForMonth(
          positionKeywords: ['Driver'],
        ),
      ]);
      if (mounted) {
        setState(() {
          _cookRfidDaysWorked = results[0];
          _cutterRfidDaysWorked = results[1];
          _driverRfidDaysWorked = results[2];
          _rfidLoading = false;
        });
      }
    } catch (e) {
      debugPrint('_loadRfidAttendance error: $e');
      if (mounted) setState(() => _rfidLoading = false);
    }
  }

  @override
  void dispose() {
    _salesSub?.cancel();
    _batchesSub?.cancel();
    _periodSub?.cancel();
    _attendanceSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(SalesPayrollScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([]);
  }

  void _editDriverDaysDialog() {
    final ctrl = TextEditingController(text: _driverDaysWorked.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Driver Working Days & Absences'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The driver daily rate is ₱650. If the driver was absent and the owner drove instead, deduct those days here.',
              style: TextStyle(fontSize: 12.5, color: AdminWebColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Days Worked this Month',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = int.tryParse(ctrl.text.trim()) ?? _driverDaysWorked;
              setState(() => _driverDaysWorked = val);
              Navigator.pop(ctx);
              final ok = await _syncPayrollToMonthlyFinancials();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ok
                                ? 'Driver working days saved and synced successfully!'
                                : 'Failed to save driver days to database.',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: ok
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                  ),
                );
              }
            },
            child: const Text('SAVE DAYS'),
          ),
        ],
      ),
    );
  }

  void _editProductionRatesDialog() {
    final cookCtrl =
        TextEditingController(text: _productionCookRate.toStringAsFixed(0));
    final cutterCtrl =
        TextEditingController(text: _productionCutterRate.toStringAsFixed(0));
    final driverCtrl =
        TextEditingController(text: _driverDailyRate.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Staff Daily Rates'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cookCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Production Cook Daily Rate (₱)',
                prefixText: '₱ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: cutterCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Meat Cutter Daily Rate (₱)',
                prefixText: '₱ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: driverCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Delivery Driver Daily Rate (₱)',
                prefixText: '₱ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final cRate =
                  double.tryParse(cookCtrl.text.trim()) ?? _productionCookRate;
              final cutRate =
                  double.tryParse(cutterCtrl.text.trim()) ?? _productionCutterRate;
              final dRate =
                  double.tryParse(driverCtrl.text.trim()) ?? _driverDailyRate;
              setState(() {
                _productionCookRate = cRate;
                _productionCutterRate = cutRate;
                _driverDailyRate = dRate;
              });
              Navigator.pop(ctx);
              final ok = await _syncPayrollToMonthlyFinancials();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ok
                                ? 'Staff daily rates saved and synced successfully!'
                                : 'Failed to save rates to database.',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: ok
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                  ),
                );
              }
            },
            child: const Text('SAVE RATES'),
          ),
        ],
      ),
    );
  }

  static String _getMonthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return names[(month - 1).clamp(0, 11)];
  }

  Future<bool> _syncPayrollToMonthlyFinancials() async {
    try {
      final existing =
          await FirestoreService.watchMonthlyFinancialPeriod(_currentPeriodId)
              .first;
      final updated = existing != null
          ? existing.copyWith(
              productionCookDailyRate: _productionCookRate,
              productionCutterDailyRate: _productionCutterRate,
              driverDailyWage: _driverDailyRate,
              driverWorkingDays: _driverDaysWorked,
              productionCookingSessions: _totalCookingSessions,
            )
          : FinancialPeriod(
              id: _currentPeriodId,
              monthName: _getMonthName(DateTime.now().month),
              year: DateTime.now().year,
              productionCookDailyRate: _productionCookRate,
              productionCutterDailyRate: _productionCutterRate,
              driverDailyWage: _driverDailyRate,
              driverWorkingDays: _driverDaysWorked,
              productionCookingSessions: _totalCookingSessions,
            );
      return await FirestoreService.saveMonthlyFinancialPeriod(updated);
    } catch (e) {
      debugPrint('Error syncing payroll to monthly financials: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminWebColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideBreakpoint;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // Top Header with Tab Buttons (Responsive Wrap)
                isWide
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Navigation Switcher Tabs
                          Row(
                            children: [
                              _tabButton(
                                index: 0,
                                title: 'BRANCH COOKS (6 STORES)',
                                icon: Icons.storefront_rounded,
                              ),
                              const SizedBox(width: 10),
                              _tabButton(
                                index: 1,
                                title: 'PRODUCTION STAFF & DRIVER',
                                icon: Icons.badge_rounded,
                              ),
                            ],
                          ),

                          // Export Button
                          ElevatedButton.icon(
                            onPressed: () {
                              SalesPayrollExportDialog.show(
                                context,
                                records: _records,
                                cookRate: _productionCookRate,
                                cutterRate: _productionCutterRate,
                                driverRate: _driverDailyRate,
                                driverDays: _driverDaysWorked,
                                cookingSessions: _totalCookingSessions,
                              );
                            },
                            icon: const Icon(Icons.table_view_rounded, size: 16),
                            label: const Text('EXPORT SALES & PAYROLL (.XLSX)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32), // Excel Dark Green
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _tabButton(
                                  index: 0,
                                  title: 'BRANCH COOKS',
                                  icon: Icons.storefront_rounded,
                                  isCompact: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _tabButton(
                                  index: 1,
                                  title: 'PRODUCTION & DRIVER',
                                  icon: Icons.badge_rounded,
                                  isCompact: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () {
                              SalesPayrollExportDialog.show(
                                context,
                                records: _records,
                                cookRate: _productionCookRate,
                                cutterRate: _productionCutterRate,
                                driverRate: _driverDailyRate,
                                driverDays: _driverDaysWorked,
                                cookingSessions: _totalCookingSessions,
                              );
                            },
                            icon: const Icon(Icons.table_view_rounded, size: 16),
                            label: const Text('EXPORT SALES & PAYROLL (.XLSX)',
                                style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 24),

                // KPI Overview Cards
                if (_selectedTab == 0) ...[
                  isWide
                      ? Row(
                          children: [
                            Expanded(
                              child: _summaryCard(
                                'Total Gross Sales',
                                '₱${_totalSales.toStringAsFixed(0)}',
                                Icons.payments_rounded,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _summaryCard(
                                'Branch Cooks Payroll',
                                '₱${_totalWages.toStringAsFixed(0)}',
                                Icons.badge_rounded,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _summaryCard(
                                'Expected Remittance',
                                '₱${_totalRemittance.toStringAsFixed(0)}',
                                Icons.account_balance_wallet_rounded,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _summaryCard(
                              'Total Gross Sales',
                              '₱${_totalSales.toStringAsFixed(0)}',
                              Icons.payments_rounded,
                            ),
                            const SizedBox(height: 12),
                            _summaryCard(
                              'Branch Cooks Payroll',
                              '₱${_totalWages.toStringAsFixed(0)}',
                              Icons.badge_rounded,
                            ),
                            const SizedBox(height: 12),
                            _summaryCard(
                              'Expected Remittance',
                              '₱${_totalRemittance.toStringAsFixed(0)}',
                              Icons.account_balance_wallet_rounded,
                            ),
                          ],
                        ),
                  const SizedBox(height: 28),

                  // View Toggle & Filter
                  if (isWide) ...[
                    // Desktop: side-by-side Row
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _branchFilter ?? 'All',
                            decoration: const InputDecoration(
                              labelText: 'FILTER BY BRANCH',
                              isDense: true,
                              prefixIcon: Icon(Icons.storefront_rounded, size: 18),
                            ),
                            items: [
                              const DropdownMenuItem(
                                  value: 'All', child: Text('ALL 6 BRANCHES')),
                              ...kSampleBranches.map((b) => DropdownMenuItem(
                                    value: b.fullName,
                                    child: Text(b.fullName.toUpperCase()),
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
                        const SizedBox(width: 16),
                        // Group by Date Toggle
                        InkWell(
                          onTap: () => setState(() => _groupByDate = !_groupByDate),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: _groupByDate
                                  ? AdminWebColors.accent.withValues(alpha: 0.1)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _groupByDate
                                    ? AdminWebColors.accent
                                    : AdminWebColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _groupByDate
                                      ? Icons.calendar_today_rounded
                                      : Icons.list_alt_rounded,
                                  size: 18,
                                  color: _groupByDate
                                      ? AdminWebColors.accent
                                      : AdminWebColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _groupByDate
                                      ? 'GROUPED BY DATE (BOXED)'
                                      : 'INDIVIDUAL CARDS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: _groupByDate
                                        ? AdminWebColors.accent
                                        : AdminWebColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ] else ...[
                    // Mobile: stacked Column
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _branchFilter ?? 'All',
                      decoration: const InputDecoration(
                        labelText: 'FILTER BY BRANCH',
                        isDense: true,
                        prefixIcon: Icon(Icons.storefront_rounded, size: 18),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: 'All', child: Text('ALL 6 BRANCHES')),
                        ...kSampleBranches.map((b) => DropdownMenuItem(
                              value: b.fullName,
                              child: Text(
                                b.fullName.toUpperCase(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _branchFilter = (v == 'All' ? null : v);
                          _currentPage = 0;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    // Group by Date Toggle — full width on mobile
                    InkWell(
                      onTap: () => setState(() => _groupByDate = !_groupByDate),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _groupByDate
                              ? AdminWebColors.accent.withValues(alpha: 0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _groupByDate
                                ? AdminWebColors.accent
                                : AdminWebColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _groupByDate
                                  ? Icons.calendar_today_rounded
                                  : Icons.list_alt_rounded,
                              size: 18,
                              color: _groupByDate
                                  ? AdminWebColors.accent
                                  : AdminWebColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _groupByDate
                                  ? 'VIEW: GROUPED BY DATE'
                                  : 'VIEW: INDIVIDUAL CARDS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _groupByDate
                                    ? AdminWebColors.accent
                                    : AdminWebColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Content: Date Grouped or Flat List
                  if (_visibleRecords.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'No sales records found for the selected filter.',
                          style: TextStyle(color: AdminWebColors.textSecondary),
                        ),
                      ),
                    )
                  else if (_groupByDate)
                    _buildDateGroupedRecords(isWide)
                  else ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: (_visibleRecords.length -
                              (_currentPage * _pageSize))
                          .clamp(0, _pageSize),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final record = _visibleRecords[
                            (_currentPage * _pageSize) + index];
                        return _SalesRecordCard(
                          record: record,
                          isWide: isWide,
                        );
                      },
                    ),
                    AdminPaginationBar(
                      currentPage: _currentPage,
                      totalItems: _visibleRecords.length,
                      pageSize: _pageSize,
                      onPageChanged: (p) => setState(() => _currentPage = p),
                    ),
                  ],
                ] else ...[
                  // TAB 1: PRODUCTION STAFF & DRIVER PAYROLL
                  _buildProductionAndDriverPayroll(isWide),
                ],

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tabButton({
    required int index,
    required String title,
    required IconData icon,
    bool isCompact = false,
  }) {
    final isSelected = _selectedTab == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 6 : 18,
            vertical: isCompact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AdminWebColors.accent : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AdminWebColors.accent : AdminWebColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: isCompact ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isCompact ? 15 : 16,
                color: isSelected ? Colors.white : AdminWebColors.textSecondary,
              ),
              SizedBox(width: isCompact ? 5 : 8),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 10.5 : 12,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AdminWebColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- DATE GROUPED VIEW (User requested clean box per date!) ---
  Widget _buildDateGroupedRecords(bool isWide) {
    final grouped = _groupedByDateRecords;
    final dates = grouped.keys.toList();

    return Column(
      children: dates.map((dateKey) {
        final recordsForDate = grouped[dateKey]!;
        final isExpanded = _expandedDates.contains(dateKey);
        final dateTotalWage =
            recordsForDate.fold(0.0, (sum, r) => sum + r.computedWage);
        final dateTotalSales =
            recordsForDate.fold(0.0, (sum, r) => sum + r.totalSalesAmount);
        final dateTotalPortions =
            recordsForDate.fold(0, (sum, r) => sum + r.displayPortions);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Header (Clickable Accordion)
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedDates.remove(dateKey);
                      } else {
                        _expandedDates.add(dateKey);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isExpanded
                          ? AdminWebColors.accent.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: isExpanded
                          ? const BorderRadius.vertical(top: Radius.circular(16))
                          : BorderRadius.circular(16),
                    ),
                    child: isWide
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_month_rounded,
                                    size: 22,
                                    color: isExpanded
                                        ? AdminWebColors.accent
                                        : AdminWebColors.textSecondary,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    dateKey,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: isExpanded
                                          ? AdminWebColors.accent
                                          : AdminWebColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AdminWebColors.accent
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${recordsForDate.length} STORES',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: AdminWebColors.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    'Portions: $dateTotalPortions  |  Sales: ₱${dateTotalSales.toStringAsFixed(0)}  |  ',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AdminWebColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '6 Cooks Total Wages: ₱${dateTotalWage.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: AdminWebColors.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: AdminWebColors.accent,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_month_rounded,
                                    size: 18,
                                    color: isExpanded
                                        ? AdminWebColors.accent
                                        : AdminWebColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    dateKey,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      color: isExpanded
                                          ? AdminWebColors.accent
                                          : AdminWebColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AdminWebColors.accent
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      '${recordsForDate.length} STORES',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: AdminWebColors.accent,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: AdminWebColors.accent,
                                    size: 20,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Portions: $dateTotalPortions',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AdminWebColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    'Total Wages: ₱${dateTotalWage.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      color: AdminWebColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),

                // Table of 6 branch cooks for this date (Only shown when expanded!)
                if (isExpanded) ...[
                  const Divider(height: 1),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: recordsForDate.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final r = recordsForDate[idx];
                      if (!isWide) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.branchName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: AdminWebColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Cook: ${r.employeeName}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AdminWebColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AdminWebColors.success.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Remittance: ₱${r.expectedCashRemittance.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AdminWebColors.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 14,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _buildPortionsHoverCell(context, r),
                                  Text(
                                    '₱${r.totalSalesAmount.toStringAsFixed(0)} sales',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AdminWebColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '₱${r.computedWage.toStringAsFixed(0)} wage',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: AdminWebColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.branchName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  Text(
                                    'Cook: ${r.employeeName}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AdminWebColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: _buildPortionsHoverCell(context, r),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '₱${r.totalSalesAmount.toStringAsFixed(0)} sales',
                                style: const TextStyle(
                                    fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '₱${r.computedWage.toStringAsFixed(0)} wage',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AdminWebColors.accent,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Remittance: ₱${r.expectedCashRemittance.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AdminWebColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- TAB 1: PRODUCTION STAFF & DRIVER PAYROLL ---
  Widget _buildProductionAndDriverPayroll(bool isWide) {
    // RFID-based days worked: counted from attendance_logs where both time_in & time_out exist
    final cookTotal = _cookRfidDaysWorked * _productionCookRate;
    final cutterTotal = _cutterRfidDaysWorked * _productionCutterRate;
    final driverTotal = _driverRfidDaysWorked * _driverDailyRate;
    final overallTotal = cookTotal + cutterTotal + driverTotal;

    final cookCard = _staffPayrollCard(
      title: 'Production Cook',
      staffName: 'Menes Bantug',
      position: '',
      daysWorked: _cookRfidDaysWorked,
      dailyRate: _productionCookRate,
      totalPay: cookTotal,
      icon: Icons.outdoor_grill_rounded,
      color: AdminWebColors.accent,
      isLoading: _rfidLoading,
    );

    final cutterCard = _staffPayrollCard(
      title: 'Production Meat Cutter',
      staffName: 'Abby Torres',
      position: '',
      daysWorked: _cutterRfidDaysWorked,
      dailyRate: _productionCutterRate,
      totalPay: cutterTotal,
      icon: Icons.content_cut_rounded,
      color: AdminWebColors.accentDark,
      isLoading: _rfidLoading,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Overview Banner
        GlassCard(
          padding: EdgeInsets.all(isWide ? 22 : 16),
          child: isWide
              ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminWebColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded,
                          size: 28, color: AdminWebColors.accent),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL PRODUCTION & DRIVER PAYROLL (CURRENT MONTH)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: AdminWebColors.textSecondary,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱${overallTotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AdminWebColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _editProductionRatesDialog,
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('EDIT RATES'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminWebColors.accent.withValues(alpha: 0.1),
                        foregroundColor: AdminWebColors.accent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: AdminWebColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminWebColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AdminWebColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'LIVE RFID SYNCED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AdminWebColors.success,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AdminWebColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded,
                              size: 24, color: AdminWebColors.accent),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOTAL PRODUCTION & DRIVER PAYROLL',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: AdminWebColors.textSecondary,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₱${overallTotal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: AdminWebColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _editProductionRatesDialog,
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('EDIT RATES'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminWebColors.accent.withValues(alpha: 0.1),
                          foregroundColor: AdminWebColors.accent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 24),

        // Section 1: Production Staff (Cook & Meat Cutter)
        const Text(
          '1. PRODUCTION STAFF (MAIN WAREHOUSE)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: AdminWebColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        if (isWide)
          Row(
            children: [
              Expanded(child: cookCard),
              const SizedBox(width: 16),
              Expanded(child: cutterCard),
            ],
          )
        else
          Column(
            children: [
              cookCard,
              const SizedBox(height: 12),
              cutterCard,
            ],
          ),
        const SizedBox(height: 28),

        // Section 2: Driver Payroll (RFID-based)
        const Text(
          '2. DRIVER PAYROLL',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: AdminWebColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.all(isWide ? 20 : 16),
          child: isWide
              ? Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AdminWebColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.local_shipping_rounded,
                          size: 26, color: AdminWebColors.accent),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Delivery Driver',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AdminWebColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_driverRfidDaysWorked Days Worked (RFID-Verified)  ·  ₱${_driverDailyRate.toStringAsFixed(0)} per day (Every day branch cooks are transported)',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AdminWebColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'TOTAL DRIVER WAGES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AdminWebColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₱${driverTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AdminWebColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AdminWebColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.local_shipping_rounded,
                              size: 22, color: AdminWebColors.accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Delivery Driver',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AdminWebColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$_driverRfidDaysWorked Days Worked (RFID)  ·  ₱${_driverDailyRate.toStringAsFixed(0)}/day',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AdminWebColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL DRIVER WAGES',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: AdminWebColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          '₱${driverTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AdminWebColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _staffPayrollCard({
    required String title,
    required String staffName,
    required String position,
    required int daysWorked,
    required double dailyRate,
    required double totalPay,
    required IconData icon,
    required Color color,
    bool isLoading = false,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: color,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      staffName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AdminWebColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              // RFID badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminWebColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AdminWebColors.success.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.nfc_rounded,
                        size: 12, color: AdminWebColors.success),
                    const SizedBox(width: 4),
                    const Text(
                      'RFID',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AdminWebColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (position.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              position,
              style: const TextStyle(
                  fontSize: 11.5, color: AdminWebColors.textSecondary),
            ),
          ],
          const Divider(height: 24),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$daysWorked days worked this month',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '₱${dailyRate.toStringAsFixed(0)}/day (RFID-verified)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AdminWebColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₱${totalPay.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
  Widget _summaryCard(String label, String value, IconData icon) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminWebColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AdminWebColors.accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AdminWebColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AdminWebColors.textPrimary,
                    letterSpacing: -0.5,
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

class _SalesRecordCard extends StatelessWidget {
  const _SalesRecordCard({required this.record, required this.isWide});

  final SalesRecord record;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final r = record;

    final avatarAndName = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AdminWebColors.accent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: AdminWebColors.accent.withValues(alpha: 0.2),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            r.employeeName.substring(0, 1),
            style: const TextStyle(
              color: AdminWebColors.accent,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.employeeName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AdminWebColors.textPrimary,
                ),
              ),
              Text(
                '${r.branchName} · ${r.date.month}/${r.date.day}/${r.date.year}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AdminWebColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final stats = [
      _miniStat('TOTAL ORDERS', '${r.displayTotalOrders}'),
      InkWell(
        onTap: () {
          int reg = r.regularSold ?? 0;
          int med = r.mediumSold ?? 0;
          int b1t1 = r.b1t1OrdersSold ?? 0;
          bool isEstimated = false;
          if (reg == 0 && med == 0 && b1t1 == 0 && r.displayTotalOrders > 0) {
            reg = (r.displayTotalOrders * 0.5).round();
            med = (r.displayTotalOrders * 0.25).round();
            b1t1 = r.displayTotalOrders - reg - med;
            isEstimated = true;
          }
          _showSalesBreakdownDialog(context, r, reg, med, b1t1, isEstimated);
        },
        borderRadius: BorderRadius.circular(4),
        child: _miniStat('PORTIONS', '${r.displayPortions} ℹ️'),
      ),
      _miniStat('TOTAL SALES', '₱${r.totalSalesAmount.toStringAsFixed(0)}'),
      _miniStat('WAGE', '₱${r.computedWage.toStringAsFixed(0)}'),
      _miniStat(
        'REMITTANCE',
        '₱${r.expectedCashRemittance.toStringAsFixed(0)}',
        highlight: true,
      ),
    ];

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          isWide
              ? Row(
                  children: [
                    Expanded(flex: 3, child: avatarAndName),
                    ...stats.map((s) => Expanded(flex: 2, child: s)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    avatarAndName,
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: stats[0]),
                        Expanded(child: stats[1]),
                        Expanded(child: stats[2]),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: stats[3]),
                        Expanded(child: stats[4]),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ],
                ),
          if (r.remainingStock != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: EdgeInsets.all(isWide ? 10 : 12),
              decoration: BoxDecoration(
                color: AdminWebColors.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AdminWebColors.accent.withValues(alpha: 0.15)),
              ),
              child: isWide
                  ? Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 16, color: AdminWebColors.accent),
                        const SizedBox(width: 8),
                        const Text(
                          'REMAINING STOCK: ',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AdminWebColors.textSecondary),
                        ),
                        Expanded(
                          child: Text(
                            'Regular: ${r.remainingStock!.regular}  |  Medium: ${r.remainingStock!.medium}  |  B1T1: ${r.remainingStock!.b1t1}  |  '
                            'Mayo: ${r.remainingStock!.mayo}  |  Styro: ${r.remainingStock!.styro}  |  Toyo: ${r.remainingStock!.toyo}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AdminWebColors.textPrimary),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 15, color: AdminWebColors.accent),
                            SizedBox(width: 6),
                            Text(
                              'REMAINING STOCK',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: AdminWebColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text('Regular: ${r.remainingStock!.regular}',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AdminWebColors.textPrimary)),
                            Text('Medium: ${r.remainingStock!.medium}',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AdminWebColors.textPrimary)),
                            Text('B1T1: ${r.remainingStock!.b1t1}',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AdminWebColors.textPrimary)),
                            Text('Mayo: ${r.remainingStock!.mayo}',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AdminWebColors.textPrimary)),
                            Text('Styro: ${r.remainingStock!.styro}',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AdminWebColors.textPrimary)),
                            Text('Toyo: ${r.remainingStock!.toyo}',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AdminWebColors.textPrimary)),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AdminWebColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: highlight ? AdminWebColors.accent : AdminWebColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

Widget _buildPortionsHoverCell(BuildContext context, SalesRecord r) {
    int reg = r.regularSold ?? 0;
    int med = r.mediumSold ?? 0;
    int b1t1 = r.b1t1OrdersSold ?? 0;
    bool isEstimated = false;

    if (reg == 0 && med == 0 && b1t1 == 0 && r.displayTotalOrders > 0) {
      reg = (r.displayTotalOrders * 0.5).round();
      med = (r.displayTotalOrders * 0.25).round();
      b1t1 = r.displayTotalOrders - reg - med;
      isEstimated = true;
    }

    final int regPcs = reg;
    final int medPcs = med;
    final int b1t1Pcs = b1t1 * 2;
    final richTooltip = TextSpan(
      style: const TextStyle(
        color: AdminWebColors.textPrimary,
        fontSize: 12,
        height: 1.5,
      ),
      children: [
        TextSpan(
          text: '${r.branchName} — Break-down ng Benta\n',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            color: AdminWebColors.accent,
          ),
        ),
        TextSpan(
          text: 'Cook: ${r.employeeName} · ${DateFormat('MMM dd, yyyy').format(r.date)}\n\n',
          style: TextStyle(
            fontSize: 11,
            color: AdminWebColors.textPrimary.withValues(alpha: 0.65),
            fontWeight: FontWeight.w500,
          ),
        ),
        const TextSpan(
          text: '• Regular (250g): ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AdminWebColors.textPrimary,
          ),
        ),
        TextSpan(
          text: '$reg orders ($regPcs pcs karne)\n',
          style: const TextStyle(
            color: AdminWebColors.accentDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        const TextSpan(
          text: '• Medium (300g): ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AdminWebColors.textPrimary,
          ),
        ),
        TextSpan(
          text: '$med orders ($medPcs pcs karne)\n',
          style: const TextStyle(
            color: AdminWebColors.accentDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        const TextSpan(
          text: '• B1T1 Jumbo (400g): ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AdminWebColors.textPrimary,
          ),
        ),
        TextSpan(
          text: '$b1t1 orders ($b1t1Pcs pcs karne)\n\n',
          style: const TextStyle(
            color: AdminWebColors.accentDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(
          text: 'Total Customer Orders: ${r.displayTotalOrders} orders',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AdminWebColors.textPrimary,
          ),
        ),
        if (isEstimated)
          TextSpan(
            text: '\n(Estimated distribution)',
            style: TextStyle(
              fontSize: 10,
              color: AdminWebColors.textPrimary.withValues(alpha: 0.45),
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );

    return Tooltip(
      richMessage: richTooltip,
      waitDuration: const Duration(milliseconds: 60),
      showDuration: const Duration(seconds: 8),
      verticalOffset: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9), // Warm Ivory Card
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AdminWebColors.border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AdminWebColors.textPrimary.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () => _showSalesBreakdownDialog(context, r, reg, med, b1t1, isEstimated),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              '${r.displayPortions} portions',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor: AdminWebColors.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSalesBreakdownDialog(BuildContext context, SalesRecord r, int reg, int med, int b1t1, bool isEstimated) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AdminWebColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AdminWebColors.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.branchName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Cook: ${r.employeeName} · ${DateFormat('MMMM dd, yyyy').format(r.date)}',
                    style: const TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 20),
              const Text(
                'ITEMIZED MEAT PORTIONS & ORDERS SOLD:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AdminWebColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              _breakdownRow('Regular Karne (250g)', '$reg orders', '$reg pcs meat', AdminWebColors.accent),
              const SizedBox(height: 6),
              _breakdownRow('Medium Karne (300g)', '$med orders', '$med pcs meat', AdminWebColors.accentDark),
              const SizedBox(height: 6),
              _breakdownRow('Buy 1 Take 1 (400g Jumbo)', '$b1t1 orders', '${b1t1 * 2} pcs meat', AdminWebColors.accent),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Customer Orders:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('${r.displayTotalOrders} orders', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Karne Portions:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AdminWebColors.accent)),
                  Text('${r.displayPortions} portions (pcs)', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AdminWebColors.accent)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Sales Amount:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('₱${NumberFormat('#,##0').format(r.totalSalesAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminWebColors.accent)),
                ],
              ),
              if (r.remainingStock != null) ...[
                const Divider(height: 20),
                const Text(
                  'REPORTED REMAINING STOCK (EOD):',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AdminWebColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminWebColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AdminWebColors.border),
                  ),
                  child: Text(
                    'Regular: ${r.remainingStock!.regular} pcs  |  Medium: ${r.remainingStock!.medium} pcs  |  B1T1: ${r.remainingStock!.b1t1} pcs\n'
                    'Mayo: ${r.remainingStock!.mayo}  |  Styro: ${r.remainingStock!.styro}  |  Toyo: ${r.remainingStock!.toyo}',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AdminWebColors.textPrimary, height: 1.4),
                  ),
                ),
              ],
              if (r.discrepancyNote != null && r.discrepancyNote!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Note: ${r.discrepancyNote!}',
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AdminWebColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ISARA (CLOSE)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String title, String orders, String pcs, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
            ),
          ),
          Text(
            orders,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              pcs,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
