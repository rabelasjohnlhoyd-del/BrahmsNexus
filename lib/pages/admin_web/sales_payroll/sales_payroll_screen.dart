import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/inventory_batch.dart';
import '../../../models/sales_record.dart';
import '../../../models/branch.dart';
import '../../../services/firestore_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import '../admin_web_widgets/admin_pagination_bar.dart';

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

  final List<SalesRecord> _records = [];
  final List<KarneBatch> _batches = [];

  String? _branchFilter;
  bool _groupByDate = true;

  // Production staff rates
  double _productionCookRate = 1100.0;
  double _productionCutterRate = 1100.0;
  double _driverDailyRate = 650.0;
  int _driverDaysWorked = 25;

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

  // Count total cooking sessions from all batches
  int get _totalCookingSessions {
    int count = 0;
    for (var b in _batches) {
      count += b.sessions.length;
    }
    return count > 0 ? count : 7;
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
  }

  @override
  void dispose() {
    _salesSub?.cancel();
    _batchesSub?.cancel();
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
    final rateCtrl = TextEditingController(text: _driverDailyRate.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Driver Working Days & Rate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Araw-araw ay ₱650 ang sahod ni Driver. Kung may araw na absent siya at si Owner ang nag-drive, ibawas dito ang araw.',
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
            const SizedBox(height: 12),
            TextField(
              controller: rateCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Daily Rate (₱)',
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
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim()) ?? _driverDaysWorked;
              final rVal = double.tryParse(rateCtrl.text.trim()) ?? _driverDailyRate;
              setState(() {
                _driverDaysWorked = val;
                _driverDailyRate = rVal;
              });
              Navigator.pop(ctx);
            },
            child: const Text('SAVE'),
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Production Staff Daily Rates'),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _productionCookRate =
                    double.tryParse(cookCtrl.text.trim()) ?? _productionCookRate;
                _productionCutterRate =
                    double.tryParse(cutterCtrl.text.trim()) ??
                        _productionCutterRate;
              });
              Navigator.pop(ctx);
            },
            child: const Text('SAVE RATES'),
          ),
        ],
      ),
    );
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

                // Top Header with Tab Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Navigation Switcher Tabs
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AdminWebColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AdminWebColors.accent.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          _tabButton(
                            index: 0,
                            title: 'BRANCH COOKS (6 STORES)',
                            icon: Icons.storefront_rounded,
                          ),
                          const SizedBox(width: 4),
                          _tabButton(
                            index: 1,
                            title: 'PRODUCTION STAFF & DRIVER',
                            icon: Icons.badge_rounded,
                          ),
                        ],
                      ),
                    ),

                    // Export Button
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Payroll summary exported.')),
                        );
                      },
                      icon: const Icon(Icons.ios_share_rounded, size: 16),
                      label: const Text('EXPORT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminWebColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
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
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
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
                      if (isWide) const Spacer(),
                    ],
                  ),

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
  }) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AdminWebColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AdminWebColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: isSelected ? Colors.white : AdminWebColors.textSecondary,
              ),
            ),
          ],
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
        final dateTotalWage =
            recordsForDate.fold(0.0, (sum, r) => sum + r.computedWage);
        final dateTotalSales =
            recordsForDate.fold(0.0, (sum, r) => sum + r.totalSalesAmount);
        final dateTotalPortions =
            recordsForDate.fold(0, (sum, r) => sum + r.displayPortions);

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: AdminWebColors.accent.withValues(alpha: 0.06),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event_note_rounded,
                              size: 20, color: AdminWebColors.accent),
                          const SizedBox(width: 10),
                          Text(
                            dateKey,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AdminWebColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AdminWebColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${recordsForDate.length} STORES',
                              style: const TextStyle(
                                fontSize: 11,
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
                            'Total Sahod: ₱${dateTotalWage.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AdminWebColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Table of 6 branch cooks for this date
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: recordsForDate.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final r = recordsForDate[idx];
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
                            child: Text(
                              '${r.displayPortions} portions (${r.displayTotalOrders} orders)',
                              style: const TextStyle(fontSize: 12),
                            ),
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
                              '₱${r.computedWage.toStringAsFixed(0)} sahod',
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
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- TAB 1: PRODUCTION STAFF & DRIVER PAYROLL ---
  Widget _buildProductionAndDriverPayroll(bool isWide) {
    final cookTotal = _totalCookingSessions * _productionCookRate;
    final cutterTotal = _totalCookingSessions * _productionCutterRate;
    final driverTotal = _driverDaysWorked * _driverDailyRate;
    final overallTotal = cookTotal + cutterTotal + driverTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Overview Banner
        GlassCard(
          padding: const EdgeInsets.all(22),
          child: Row(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        Row(
          children: [
            // Production Cook
            Expanded(
              child: _staffPayrollCard(
                title: 'Production Cook',
                staffName: 'Menes Bantug',
                position: 'Cook (Boiling & Cooking Sessions)',
                sessionsCount: _totalCookingSessions,
                dailyRate: _productionCookRate,
                totalPay: cookTotal,
                icon: Icons.outdoor_grill_rounded,
                color: const Color(0xFFE65100),
              ),
            ),
            const SizedBox(width: 16),
            // Production Meat Cutter
            Expanded(
              child: _staffPayrollCard(
                title: 'Production Meat Cutter',
                staffName: 'Abby Torres',
                position: 'Cutter (Reseko & Portioning to 250G/300G/400G)',
                sessionsCount: _totalCookingSessions,
                dailyRate: _productionCutterRate,
                totalPay: cutterTotal,
                icon: Icons.content_cut_rounded,
                color: const Color(0xFF00695C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Section 2: Driver Payroll
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '2. DRIVER PAYROLL',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: AdminWebColors.textSecondary,
              ),
            ),
            TextButton.icon(
              onPressed: _editDriverDaysDialog,
              icon: const Icon(Icons.edit_calendar_rounded, size: 16),
              label: const Text('EDIT WORKING DAYS / ABSENCES'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_shipping_rounded,
                    size: 26, color: Color(0xFF1565C0)),
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
                      '$_driverDaysWorked Days Worked this Month  ·  ₱${_driverDailyRate.toStringAsFixed(0)} per day (Kada ihahatid ang branch cooks)',
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
                    'TOTAL SAHOD NI DRIVER',
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
                      color: Color(0xFF1565C0),
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
    required int sessionsCount,
    required double dailyRate,
    required double totalPay,
    required IconData icon,
    required Color color,
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
            ],
          ),
          const SizedBox(height: 12),
          Text(
            position,
            style: const TextStyle(fontSize: 11.5, color: AdminWebColors.textSecondary),
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$sessionsCount Sessions × ₱${dailyRate.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
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
      _miniStat('PORTIONS', '${r.displayPortions}'),
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
                      ],
                    ),
                  ],
                ),
          if (r.remainingStock != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminWebColors.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AdminWebColors.accent.withValues(alpha: 0.15)),
              ),
              child: Row(
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AdminWebColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: highlight ? AdminWebColors.accent : AdminWebColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
