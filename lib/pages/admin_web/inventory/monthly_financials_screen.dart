import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/financial_period.dart';
import '../../../models/inventory_batch.dart';
import '../../../models/procurement_list.dart';
import '../../../models/sales_record.dart';
import '../../../services/firestore_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_widgets/glass_card.dart';

class MonthlyFinancialsScreen extends StatefulWidget {
  const MonthlyFinancialsScreen({super.key, this.karneBatches = const []});

  final List<KarneBatch> karneBatches;

  @override
  State<MonthlyFinancialsScreen> createState() => _MonthlyFinancialsScreenState();
}

class _MonthlyFinancialsScreenState extends State<MonthlyFinancialsScreen> {
  late FinancialPeriod _period;
  StreamSubscription<FinancialPeriod?>? _periodSub;
  StreamSubscription<List<SalesRecord>>? _salesSub;

  final String _currentPeriodId =
      '${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}';

  double _actualBranchCookWages = 0.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeDefaultPeriod();
    _subscribeToLivePeriod();
    _subscribeToLiveSales();
  }

  void _initializeDefaultPeriod() {
    final now = DateTime.now();
    final counts = _extractMeatCounts();

    _period = FinancialPeriod(
      id: _currentPeriodId,
      monthName: _getMonthName(now.month),
      year: now.year,
      notes:
          'KUNG MAKUKUHA NG 20 DAYS 150 SALES PER DAY MAY SAVE PA AKONG LABOR.',
      roiInvestment: 165000.0,
      regular250gCount: counts.count250g,
      medium300gCount: counts.count300g,
      b1t1400gCount: counts.count400g,
      productionCookingSessions: counts.sessionsCount > 0 ? counts.sessionsCount : 7,
      productionCookDailyRate: 1100.0,
      productionCutterDailyRate: 1100.0,
      driverWorkingDays: 25,
      driverDailyWage: 650.0,
      branchCookLaborTotal: 0.0,
      procurementGroups: FirestoreService.defaultProcurementGroups,
    );
  }

  void _subscribeToLivePeriod() {
    _periodSub = FirestoreService.watchMonthlyFinancialPeriod(_currentPeriodId)
        .listen((remotePeriod) {
      if (!mounted) return;
      if (remotePeriod != null) {
        final counts = _extractMeatCounts();
        setState(() {
          _period = remotePeriod.copyWith(
            regular250gCount: counts.count250g > 0
                ? counts.count250g
                : remotePeriod.regular250gCount,
            medium300gCount: counts.count300g > 0
                ? counts.count300g
                : remotePeriod.medium300gCount,
            b1t1400gCount: counts.count400g > 0
                ? counts.count400g
                : remotePeriod.b1t1400gCount,
            productionCookingSessions: counts.sessionsCount > 0
                ? counts.sessionsCount
                : remotePeriod.productionCookingSessions,
            branchCookLaborTotal: _actualBranchCookWages > 0
                ? _actualBranchCookWages
                : remotePeriod.branchCookLaborTotal,
          );
        });
      } else {
        // Document does not exist yet in Firestore, save initial seed
        _persistPeriod();
      }
    });
  }

  void _subscribeToLiveSales() {
    _salesSub = FirestoreService.watchRecentSales(limit: 200).listen((records) {
      if (!mounted) return;
      // Sum wages for the current month
      final now = DateTime.now();
      final monthRecords = records.where((r) =>
          r.date.year == now.year && r.date.month == now.month);
      final totalWages =
          monthRecords.fold(0.0, (sum, r) => sum + r.computedWage);

      if (totalWages > 0) {
        setState(() {
          _actualBranchCookWages = totalWages;
          _period = _period.copyWith(branchCookLaborTotal: totalWages);
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant MonthlyFinancialsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final counts = _extractMeatCounts();
    setState(() {
      _period = _period.copyWith(
        regular250gCount: counts.count250g,
        medium300gCount: counts.count300g,
        b1t1400gCount: counts.count400g,
        productionCookingSessions: counts.sessionsCount > 0
            ? counts.sessionsCount
            : _period.productionCookingSessions,
      );
    });
    _persistPeriod();
  }

  @override
  void dispose() {
    _periodSub?.cancel();
    _salesSub?.cancel();
    super.dispose();
  }

  _MeatCountResult _extractMeatCounts() {
    int c250 = 0;
    int c300 = 0;
    int c400 = 0;
    int sessions = 0;

    for (var b in widget.karneBatches) {
      if (b.sessions.isNotEmpty) {
        for (var s in b.sessions) {
          sessions++;
          c250 += s.actual250g ?? 0;
          c300 += s.actual300g ?? 0;
          c400 += s.actual400g ?? 0;
        }
      } else {
        // Fallback to batch-level output if sessions array is empty
        c250 += b.actual250g ?? 0;
        c300 += b.actual300g ?? 0;
        c400 += b.actual400g ?? 0;
      }
    }

    return _MeatCountResult(
      count250g: c250,
      count300g: c300,
      count400g: c400,
      sessionsCount: sessions,
    );
  }

  String _getMonthName(int month) {
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

  Future<void> _persistPeriod() async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      await FirestoreService.saveMonthlyFinancialPeriod(_period);
    } finally {
      _isSaving = false;
    }
  }

  // --- EDIT DIALOGS ---

  void _editNotes() {
    final ctrl = TextEditingController(text: _period.notes);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Notes ni Sir Mav'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Ilagay ang target, reminders o notes para sa buwan...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _period = _period.copyWith(notes: ctrl.text.trim());
              });
              Navigator.pop(ctx);
              _persistPeriod();
            },
            child: const Text('SAVE NOTE'),
          ),
        ],
      ),
    );
  }

  void _editRoiInvestment() {
    final ctrl =
        TextEditingController(text: _period.roiInvestment.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Capital / Ininvest Ngayong Buwan (R.O.I)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Magkano ang kabuuang kapital o investment na inilaan para sa buwang ito? Gagamitin ito upang malaman kung nabawi na ang puhunan.',
              style: TextStyle(fontSize: 12.5, color: AdminWebColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target Capital / Investment (₱)',
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
              final val = double.tryParse(ctrl.text.replaceAll(',', '').trim()) ??
                  165000.0;
              setState(() {
                _period = _period.copyWith(roiInvestment: val);
              });
              Navigator.pop(ctx);
              _persistPeriod();
            },
            child: const Text('SAVE R.O.I'),
          ),
        ],
      ),
    );
  }

  void _editItem(ProcurementGroup group, ProcurementItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    final priceCtrl = TextEditingController(text: item.price.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Item Name / Description',
                hintText: 'Hal. Labuin (2x naubos)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(
                labelText: 'Price / Gastos (₱)',
                prefixText: '₱ ',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Delete item
              setState(() {
                group.items.removeWhere((i) => i.id == item.id);
              });
              Navigator.pop(ctx);
              _persistPeriod();
            },
            child: const Text('DELETE', style: TextStyle(color: AdminWebColors.error)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                item.name = nameCtrl.text.trim();
                item.price = double.tryParse(priceCtrl.text) ?? 0.0;
              });
              Navigator.pop(ctx);
              _persistPeriod();
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _addNewProcurementItem(ProcurementGroup group) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Item sa ${group.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                hintText: 'Hal. Labuin Extra LPG',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(
                labelText: 'Price (₱)',
                prefixText: '₱ ',
              ),
              keyboardType: TextInputType.number,
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
              if (nameCtrl.text.trim().isEmpty) return;
              final newItem = ProcurementItem(
                id: 'item_${DateTime.now().millisecondsSinceEpoch}',
                name: nameCtrl.text.trim(),
                price: double.tryParse(priceCtrl.text) ?? 0.0,
                isPaid: true,
              );
              setState(() {
                group.items.add(newItem);
              });
              Navigator.pop(ctx);
              _persistPeriod();
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    );
  }

  void _addNewCategoryDialog() {
    final titleCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Magdagdag ng Bagong Procurement Category / Section'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Halimbawa: TUBIG & WATER EXPENSES, CLEANING SUPPLIES, O IBA PANG GASTOS.',
              style: TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Pangalan ng Kategorya',
                hintText: 'Hal. TUBIG & WATER EXPENSES',
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
              final title = titleCtrl.text.trim();
              if (title.isEmpty) return;
              final newGroup = ProcurementGroup(
                id: 'pg_${DateTime.now().millisecondsSinceEpoch}',
                title: title.toUpperCase(),
                items: [],
              );
              setState(() {
                _period.procurementGroups.add(newGroup);
              });
              Navigator.pop(ctx);
              _persistPeriod();
            },
            child: const Text('ADD CATEGORY'),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(ProcurementGroup group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${group.title}?'),
        content: Text(
          'Sigurado ka bang nais mong burahin ang kategoryang "${group.title}" kasama ang lahat ng items nito?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _period.procurementGroups.removeWhere((g) => g.id == group.id);
              });
              Navigator.pop(ctx);
              _persistPeriod();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminWebColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _editProductionLaborSettings() {
    final sessionsCtrl =
        TextEditingController(text: _period.productionCookingSessions.toString());
    final cookRateCtrl =
        TextEditingController(text: _period.productionCookDailyRate.toStringAsFixed(0));
    final cutterRateCtrl =
        TextEditingController(text: _period.productionCutterDailyRate.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Production Staff Labor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sessionsCtrl,
              decoration: const InputDecoration(
                labelText: 'Total Cooking Sessions',
                helperText: 'Kukunin din sa Warehouse cooking sessions',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cookRateCtrl,
              decoration: const InputDecoration(
                labelText: 'Production Cook Daily Rate (₱)',
                prefixText: '₱ ',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cutterRateCtrl,
              decoration: const InputDecoration(
                labelText: 'Production Cutter Daily Rate (₱)',
                prefixText: '₱ ',
              ),
              keyboardType: TextInputType.number,
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
                _period = _period.copyWith(
                  productionCookingSessions:
                      int.tryParse(sessionsCtrl.text) ?? _period.productionCookingSessions,
                  productionCookDailyRate:
                      double.tryParse(cookRateCtrl.text) ?? _period.productionCookDailyRate,
                  productionCutterDailyRate:
                      double.tryParse(cutterRateCtrl.text) ?? _period.productionCutterDailyRate,
                );
              });
              Navigator.pop(ctx);
              _persistPeriod();
            },
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  void _editDriverLaborSettings() {
    final daysCtrl =
        TextEditingController(text: _period.driverWorkingDays.toString());
    final rateCtrl =
        TextEditingController(text: _period.driverDailyWage.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Driver Labor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Araw-araw ay ₱650 ang sahod ni Driver. Kung may araw na umabsent siya at si Owner ang nag-drive, ibawas dito ang bilang ng araw.',
              style: TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: daysCtrl,
              decoration: const InputDecoration(
                labelText: 'Driver Working Days',
                helperText: 'Default 25 days (or actual days on duty)',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rateCtrl,
              decoration: const InputDecoration(
                labelText: 'Daily Rate (₱)',
                prefixText: '₱ ',
              ),
              keyboardType: TextInputType.number,
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
                _period = _period.copyWith(
                  driverWorkingDays:
                      int.tryParse(daysCtrl.text) ?? _period.driverWorkingDays,
                  driverDailyWage:
                      double.tryParse(rateCtrl.text) ?? _period.driverDailyWage,
                );
              });
              Navigator.pop(ctx);
              _persistPeriod();
            },
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  // --- BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminWebColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. NOTES BANNER (Top-most as requested)
            _buildNotesBanner(),
            const SizedBox(height: 20),

            // 2. R.O.I / CAPITAL TRACKER
            _buildRoiCard(),
            const SizedBox(height: 24),

            // 3. FINANCIAL OVERVIEW TILES (KPIs)
            _buildFinancialOverview(),
            const SizedBox(height: 28),

            // 4. KARNE PRODUCTION BREAKDOWN (Regular, Medium, B1T1)
            _buildKarneProductionBreakdown(),
            const SizedBox(height: 28),

            // 5. PROCUREMENT & INGREDIENTS
            _buildProcurementSections(),
            const SizedBox(height: 28),

            // 6. LABOR & STORE OVERHEADS
            _buildLaborAndOverheadSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildNotesBanner() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderColor: AdminWebColors.accent.withValues(alpha: 0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AdminWebColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.sticky_note_2_rounded,
                color: AdminWebColors.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NOTES NI SIR MAV',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AdminWebColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _period.notes.isNotEmpty
                      ? _period.notes
                      : 'Walang nakalagay na notes. I-click ang edit para maglagay ng paalala para sa buwang ito.',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AdminWebColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _editNotes,
            icon: const Icon(Icons.edit_note_rounded,
                color: AdminWebColors.accent, size: 22),
            tooltip: 'Edit Notes',
          ),
        ],
      ),
    );
  }

  Widget _buildRoiCard() {
    final roiDiff = _period.roiDifference;
    final isAchieved = _period.isRoiAchieved;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isAchieved ? AdminWebColors.success : AdminWebColors.warning)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isAchieved
                  ? Icons.check_circle_rounded
                  : Icons.hourglass_top_rounded,
              size: 26,
              color: isAchieved ? AdminWebColors.success : AdminWebColors.warning,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'CAPITAL / R.O.I (RETURN ON INVESTMENT)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AdminWebColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAchieved
                            ? AdminWebColors.success.withValues(alpha: 0.15)
                            : AdminWebColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isAchieved ? 'NABAWING PUHUNAN' : 'IN PROGRESS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isAchieved
                              ? AdminWebColors.success
                              : AdminWebColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Ininvest: ₱${_period.roiInvestment.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AdminWebColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      isAchieved
                          ? 'Sobra sa Puhunan: +₱${roiDiff.toStringAsFixed(0)}'
                          : 'Kulang pa bago makabawi: ₱${(-roiDiff).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isAchieved
                            ? AdminWebColors.success
                            : AdminWebColors.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _editRoiInvestment,
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('SET R.O.I'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminWebColors.accent.withValues(alpha: 0.1),
              foregroundColor: AdminWebColors.accent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialOverview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        final isAchieved = _period.isRoiAchieved;
        final tiles = [
          _kpiTile(
            'Gross Revenue (Karne)',
            '₱${_period.grossRevenue.toStringAsFixed(0)}',
            '${_period.totalProductionPcs} PCS NAGAWANG KARNE',
            Icons.payments_rounded,
            color: AdminWebColors.success,
          ),
          _kpiTile(
            'Total Expenses',
            '₱${_period.totalExpenses.toStringAsFixed(0)}',
            'INGREDIENTS + ALL PAYROLL + OVERHEADS',
            Icons.shopping_cart_rounded,
            color: AdminWebColors.error,
          ),
          _kpiTile(
            'NET MAV (KITA NI SIR MAV)',
            '₱${_period.netMav.toStringAsFixed(0)}',
            isAchieved
                ? 'NABAWING PUHUNAN: +₱${_period.netMav.toStringAsFixed(0)} TUBONG KITA'
                : 'BAWI PUHUNAN: KULANG PA NG ₱${_period.capitalRemainingToRecover.toStringAsFixed(0)}',
            Icons.account_balance_wallet_rounded,
            color: isAchieved ? AdminWebColors.accent : AdminWebColors.warning,
            isMain: true,
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FINANCIAL DASHBOARD',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: AdminWebColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            if (isWide)
              Row(
                children: [
                  Expanded(child: tiles[0]),
                  const SizedBox(width: 14),
                  Expanded(child: tiles[1]),
                  const SizedBox(width: 14),
                  Expanded(child: tiles[2]),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tiles[0],
                  const SizedBox(height: 12),
                  tiles[1],
                  const SizedBox(height: 12),
                  tiles[2],
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _kpiTile(
    String label,
    String val,
    String sub,
    IconData icon, {
    Color? color,
    bool isMain = false,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: color ?? AdminWebColors.accent),
          const SizedBox(height: 14),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AdminWebColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: TextStyle(
              fontSize: isMain ? 30 : 24,
              fontWeight: FontWeight.w900,
              color: color ?? AdminWebColors.textPrimary,
            ),
          ),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AdminWebColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKarneProductionBreakdown() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL KARNE PRODUCTION (MAIN WAREHOUSE)',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AdminWebColors.accent,
                      letterSpacing: 0.5,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Kusang kinalkula mula sa mga cooking session sa Main Warehouse',
                    style: TextStyle(
                      fontSize: 11,
                      color: AdminWebColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminWebColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_period.totalProductionPcs} TOTAL PCS',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AdminWebColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                child: _meatPortionBox(
                  sizeLabel: 'Regular (250G)',
                  pcs: _period.regular250gCount,
                  rate: 130.0,
                  totalAmount: _period.regular250gRevenue,
                  color: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _meatPortionBox(
                  sizeLabel: 'Medium (300G)',
                  pcs: _period.medium300gCount,
                  rate: 160.0,
                  totalAmount: _period.medium300gRevenue,
                  color: const Color(0xFF1565C0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _meatPortionBox(
                  sizeLabel: 'B1T1 (400G)',
                  pcs: _period.b1t1400gCount,
                  rate: 210.0,
                  totalAmount: _period.b1t1400gRevenue,
                  color: const Color(0xFFC62828),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meatPortionBox({
    required String sizeLabel,
    required int pcs,
    required double rate,
    required double totalAmount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sizeLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$pcs pcs',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AdminWebColors.textPrimary,
            ),
          ),
          Text(
            '× ₱${rate.toStringAsFixed(0)} bawat isa',
            style: const TextStyle(fontSize: 11, color: AdminWebColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            '₱${totalAmount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcurementSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'PROCUREMENT & INGREDIENTS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: AdminWebColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 14),
                ElevatedButton.icon(
                  onPressed: _addNewCategoryDialog,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('ADD CATEGORY'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        AdminWebColors.accent.withValues(alpha: 0.12),
                    foregroundColor: AdminWebColors.accent,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            Text(
              'TOTAL INGREDIENTS: ₱${_period.totalProcurementCost.toStringAsFixed(1)}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: AdminWebColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (var group in _period.procurementGroups) ...[
          _buildGroupCard(group),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildGroupCard(ProcurementGroup group) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AdminWebColors.accent.withValues(alpha: 0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  group.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AdminWebColors.accent,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'TOTAL: ₱${group.total.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 14),
                    IconButton(
                      onPressed: () => _addNewProcurementItem(group),
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          size: 20, color: AdminWebColors.accent),
                      tooltip: 'Add item sa ${group.title}',
                    ),
                    IconButton(
                      onPressed: () => _deleteCategory(group),
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 19, color: AdminWebColors.error),
                      tooltip: 'Delete ${group.title}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          ...group.items.map((item) => _buildItemRow(group, item)),
        ],
      ),
    );
  }

  Widget _buildItemRow(ProcurementGroup group, ProcurementItem item) {
    return InkWell(
      onTap: () => _editItem(group, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Checkbox(
              value: item.isPaid,
              onChanged: (v) {
                setState(() => item.isPaid = v ?? false);
                _persistPeriod();
              },
              activeColor: AdminWebColors.success,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const Text(
                    'I-tap para baguhin ang pangalan o presyo',
                    style: TextStyle(
                      fontSize: 10,
                      color: AdminWebColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '₱${item.price.toStringAsFixed(1)}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: item.isPaid
                    ? AdminWebColors.success.withValues(alpha: 0.1)
                    : AdminWebColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.isPaid ? 'PAID' : 'NOT PAID',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: item.isPaid
                      ? AdminWebColors.success
                      : AdminWebColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLaborAndOverheadSection() {
    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LABOR & STORE OVERHEADS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AdminWebColors.accent,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'KABUUANG LABOR: ₱${(_period.totalProductionLaborCost + _period.totalDriverLaborCost + _period.effectiveBranchCookLabor + _period.totalDailyFixedOverheads).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: AdminWebColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 1. Production Labor
          _overheadRowWithAction(
            label: 'Production Labor (Cook & Meat Cutter)',
            val: '₱${_period.totalProductionLaborCost.toStringAsFixed(0)}',
            sub:
                '${_period.productionCookingSessions} Cooking Sessions × (₱${_period.productionCookDailyRate.toStringAsFixed(0)} Cook + ₱${_period.productionCutterDailyRate.toStringAsFixed(0)} Cutter)',
            onEdit: _editProductionLaborSettings,
          ),
          const Divider(height: 28),

          // 2. Branch Cook Labor (Automated from Sales & Payroll)
          _overheadRow(
            'Branch Cooks Labor (6 Stores)',
            '₱${_period.effectiveBranchCookLabor.toStringAsFixed(0)}',
            sub: 'Kusang kinukuha sa Sales & Payroll ng mga Branch Cook',
          ),
          const Divider(height: 28),

          // 3. Driver Labor
          _overheadRowWithAction(
            label: 'Driver Labor (Sahod ng Driver)',
            val: '₱${_period.totalDriverLaborCost.toStringAsFixed(0)}',
            sub:
                '${_period.driverWorkingDays} Araw × ₱${_period.driverDailyWage.toStringAsFixed(0)} araw-araw (I-edit kung may absent)',
            onEdit: _editDriverLaborSettings,
          ),
          const Divider(height: 28),

          // 4. Fixed Store Overheads
          const Text(
            'Fixed Store Overheads (Araw-araw kada may pasok ang mga Branch Cook):',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AdminWebColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _overheadRow(
            'Total Rent & Butaw',
            '₱${(_period.driverWorkingDays * _period.dailyButawRate).toStringAsFixed(0)}',
            sub: '${_period.driverWorkingDays} days × ₱${_period.dailyButawRate.toStringAsFixed(0)}',
          ),
          _overheadRow(
            "Total Daddy's Net",
            '₱${(_period.driverWorkingDays * _period.dailyDaddyNetRate).toStringAsFixed(0)}',
            sub: '${_period.driverWorkingDays} days × ₱${_period.dailyDaddyNetRate.toStringAsFixed(0)}',
          ),
          _overheadRow(
            'Total Trike Gas',
            '₱${(_period.driverWorkingDays * _period.dailyTrikeGasRate).toStringAsFixed(0)}',
            sub: '${_period.driverWorkingDays} days × ₱${_period.dailyTrikeGasRate.toStringAsFixed(0)}',
          ),

          const Divider(height: 36, thickness: 1.5),
          _overheadRow(
            'KABUUANG GASTOS SA LABOR & OVERHEADS',
            '₱${(_period.totalProductionLaborCost + _period.totalDriverLaborCost + _period.effectiveBranchCookLabor + _period.totalDailyFixedOverheads).toStringAsFixed(0)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _overheadRow(String label, String val,
      {String? sub, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
                  fontSize: isTotal ? 15 : 13,
                  color: isTotal
                      ? AdminWebColors.textPrimary
                      : AdminWebColors.textSecondary,
                ),
              ),
              if (sub != null)
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AdminWebColors.textSecondary,
                  ),
                ),
            ],
          ),
          Text(
            val,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: isTotal ? 19 : 14,
              color: isTotal ? AdminWebColors.accent : AdminWebColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overheadRowWithAction({
    required String label,
    required String val,
    required String sub,
    required VoidCallback onEdit,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 11,
                  color: AdminWebColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Text(
              val,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: AdminWebColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded,
                  size: 18, color: AdminWebColors.accent),
              tooltip: 'Edit',
            ),
          ],
        ),
      ],
    );
  }
}

class _MeatCountResult {
  _MeatCountResult({
    required this.count250g,
    required this.count300g,
    required this.count400g,
    required this.sessionsCount,
  });

  final int count250g;
  final int count300g;
  final int count400g;
  final int sessionsCount;
}
