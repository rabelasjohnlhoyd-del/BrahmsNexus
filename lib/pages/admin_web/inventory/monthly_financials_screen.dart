import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/financial_period.dart';
import '../../../models/inventory_batch.dart';
import '../../../models/procurement_list.dart';
import '../../../models/sales_record.dart';
import '../../../services/firestore_service.dart';
import '../../../services/excel_export_service.dart';
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
  String? _selectedBatchId;
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
          'IF 150 SALES PER DAY CAN BE ACHIEVED FOR 20 DAYS, LABOR COSTS WILL BE REDUCED.',
      roiInvestment: 165000.0,
      regular250gCount: counts.count250g,
      medium300gCount: counts.count300g,
      b1t1400gCount: counts.count400g,
      productionCookingSessions: counts.sessionsCount > 0 ? counts.sessionsCount : 7,
      productionCookDailyRate: 1000.0,
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

    final batchesToUse = _selectedBatchId == null
        ? widget.karneBatches
        : widget.karneBatches.where((b) => b.id == _selectedBatchId).toList();

    for (var b in batchesToUse) {
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
        title: const Text('Edit Owner Monthly Notes'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter targets, reminders, or notes for the month...',
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
        title: const Text('Set Monthly Capital / Investment (R.O.I)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How much total capital or investment was allocated for this month? This is used to determine return on investment (R.O.I).',
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
        title: Text('Add Item to ${group.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                hintText: 'e.g. Labuin Extra LPG',
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
        title: const Text('Add New Procurement Category / Section'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Example: WATER & UTILITIES, CLEANING SUPPLIES, OR OTHER EXPENSES.',
              style: TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g. WATER & UTILITIES',
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
          'Are you sure you want to delete the category "${group.title}" and all its items?',
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
                helperText: 'Also pulled from Warehouse cooking sessions',
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
              'The driver daily rate is ₱650. If the driver was absent and the owner drove instead, deduct those days here.',
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

  void _editBranchCookLaborSettings() {
    final laborCtrl = TextEditingController(
      text: _period.effectiveBranchCookLabor.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Branch Cook Labor Total'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total Branch Cook labor across all 6 stores. Automatically calculated from sales, but you can override or adjust this amount manually.',
              style: TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: laborCtrl,
              decoration: const InputDecoration(
                labelText: 'Branch Cook Labor Total (₱)',
                prefixText: '₱ ',
                helperText: 'Total wages across all stores for this batch / month',
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
              final newWage = double.tryParse(laborCtrl.text);
              if (newWage != null) {
                setState(() {
                  _actualBranchCookWages = newWage;
                  _period = _period.copyWith(branchCookLaborTotal: newWage);
                });
                Navigator.pop(ctx);
                _persistPeriod();
              }
            },
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  void _editDaddyNetSettings() {
    final daysCtrl =
        TextEditingController(text: _period.daddyNetDays.toString());
    final rateCtrl =
        TextEditingController(text: _period.dailyDaddyNetRate.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Daddy's Net"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Daddy's Net daily rate is ₱700 by default. Adjust days and daily rate as needed.",
              style: TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: daysCtrl,
              decoration: const InputDecoration(
                labelText: 'Operating Days',
                helperText: 'Number of operating days for Daddy’s Net',
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
                  daddyNetDays: int.tryParse(daysCtrl.text) ?? _period.daddyNetDays,
                  dailyDaddyNetRate:
                      double.tryParse(rateCtrl.text) ?? _period.dailyDaddyNetRate,
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

  void _editTrikeGasSettings() {
    final daysCtrl =
        TextEditingController(text: _period.trikeGasDays.toString());
    final rateCtrl =
        TextEditingController(text: _period.dailyTrikeGasRate.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Trike Gas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trike Gas daily allowance is ₱150 by default. Adjust days and daily rate as needed.',
              style: TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: daysCtrl,
              decoration: const InputDecoration(
                labelText: 'Trike Gas Days',
                helperText: 'Number of delivery days needing trike gas',
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
                  trikeGasDays: int.tryParse(daysCtrl.text) ?? _period.trikeGasDays,
                  dailyTrikeGasRate:
                      double.tryParse(rateCtrl.text) ?? _period.dailyTrikeGasRate,
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

  Future<void> _exportFinancialsExcel() async {
    try {
      await ExcelExportService.exportMonthlyFinancialsReport(period: _period);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  '${_period.monthName} ${_period.year} Financial Statement exported to Excel!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AdminWebColors.error,
            content: Text('Failed to export Excel: $e'),
          ),
        );
      }
    }
  }

  Widget _buildTopActionBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 650;
        final titleContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              children: [
                Text(
                  '${_period.monthName.toUpperCase()} ${_period.year} FINANCIAL STATEMENT',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AdminWebColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (_period.isRoiAchieved ? AdminWebColors.success : AdminWebColors.warning)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (_period.isRoiAchieved ? AdminWebColors.success : AdminWebColors.warning)
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _period.isRoiAchieved ? 'ROI ACHIEVED' : 'ROI IN PROGRESS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _period.isRoiAchieved ? AdminWebColors.success : AdminWebColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Consolidated Profit & Loss (P&L), Commissary Production, Procurement & Payroll',
              style: TextStyle(
                fontSize: 12.5,
                color: AdminWebColors.textSecondary,
              ),
            ),
          ],
        );

        final exportBtn = ElevatedButton.icon(
          onPressed: _exportFinancialsExcel,
          icon: const Icon(Icons.table_view_rounded, size: 16, color: Colors.white),
          label: const Text(
            'EXPORT P&L (.XLSX)',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleContent),
              const SizedBox(width: 16),
              exportBtn,
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleContent,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: exportBtn),
            ],
          );
        }
      },
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
            // 0. TOP ACTION HEADER & EXCEL EXPORT
            _buildTopActionBar(),
            const SizedBox(height: 20),

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
                  'OWNER NOTES',
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
                      : 'No notes added yet. Click edit to add reminders for this month.',
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
                        isAchieved ? 'ROI ACHIEVED' : 'IN PROGRESS',
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
                      'Invested: ₱${_period.roiInvestment.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AdminWebColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      isAchieved
                          ? 'Net Return above Investment: +₱${roiDiff.toStringAsFixed(0)}'
                          : 'Remaining to Break Even: ₱${(-roiDiff).toStringAsFixed(0)}',
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
                    'Automatically calculated from cooking sessions in Main Warehouse',
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
          if (widget.karneBatches.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminWebColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 16, color: AdminWebColors.accent),
                  const SizedBox(width: 8),
                  const Text(
                    'Select Karne Batch: ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AdminWebColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String?>(
                    value: _selectedBatchId,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'All Monthly Batches (Combined)',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...widget.karneBatches.map((b) => DropdownMenuItem<String?>(
                            value: b.id,
                            child: Text(
                              '${b.name} (${b.totalKilos.toStringAsFixed(1)} kg)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          )),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedBatchId = val;
                        final counts = _extractMeatCounts();
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
                    },
                  ),
                ],
              ),
            ),
          ],
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
    final allPaid =
        group.items.isNotEmpty && group.items.every((it) => it.isPaid);

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
                Row(
                  children: [
                    Text(
                      group.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AdminWebColors.accent,
                      ),
                    ),
                    if (group.items.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          setState(() {
                            final target = !allPaid;
                            for (var item in group.items) {
                              item.isPaid = target;
                            }
                          });
                          _persistPeriod();
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (allPaid
                                    ? AdminWebColors.success
                                    : AdminWebColors.accent)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (allPaid
                                      ? AdminWebColors.success
                                      : AdminWebColors.accent)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                allPaid
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                size: 14,
                                color: allPaid
                                    ? AdminWebColors.success
                                    : AdminWebColors.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                allPaid ? 'UNCHECK ALL' : 'CHECK ALL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: allPaid
                                      ? AdminWebColors.success
                                      : AdminWebColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
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
                      tooltip: 'Add item to ${group.title}',
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
                    'Tap to edit name or price',
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
                'TOTAL LABOR: ₱${(_period.totalProductionLaborCost + _period.totalDriverLaborCost + _period.effectiveBranchCookLabor + _period.totalDailyFixedOverheads).toStringAsFixed(0)}',
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

          // 2. Branch Cook Labor (Automated from Sales & Payroll, with manual override)
          _overheadRowWithAction(
            label: 'Branch Cooks Labor (6 Stores)',
            val: '₱${_period.effectiveBranchCookLabor.toStringAsFixed(0)}',
            sub:
                'Synced from Branch Cook sales or warehouse batch. Tap pencil to override.',
            onEdit: _editBranchCookLaborSettings,
          ),
          const Divider(height: 28),

          // 3. Driver Labor
          _overheadRowWithAction(
            label: 'Driver Labor (Driver Wages)',
            val: '₱${_period.totalDriverLaborCost.toStringAsFixed(0)}',
            sub:
                '${_period.driverWorkingDays} Days × ₱${_period.driverDailyWage.toStringAsFixed(0)} daily rate (Edit if absent)',
            onEdit: _editDriverLaborSettings,
          ),
          const Divider(height: 28),

          // 4. Fixed Store Overheads
          const Text(
            'Fixed Store Overheads (Daily whenever branch cooks are on duty):',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AdminWebColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _overheadRowWithAction(
            label: "Total Daddy's Net",
            val: '₱${_period.totalDaddyNetCost.toStringAsFixed(0)}',
            sub:
                '${_period.daddyNetDays} days × ₱${_period.dailyDaddyNetRate.toStringAsFixed(0)} daily rate',
            onEdit: _editDaddyNetSettings,
          ),
          const Divider(height: 20),
          _overheadRowWithAction(
            label: 'Total Trike Gas',
            val: '₱${_period.totalTrikeGasCost.toStringAsFixed(0)}',
            sub:
                '${_period.trikeGasDays} days × ₱${_period.dailyTrikeGasRate.toStringAsFixed(0)} daily rate',
            onEdit: _editTrikeGasSettings,
          ),

          const Divider(height: 36, thickness: 1.5),
          _overheadRow(
            'TOTAL LABOR & OVERHEAD EXPENSES',
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
