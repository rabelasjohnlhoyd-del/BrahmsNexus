import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/financial_period.dart';
import '../../../models/inventory_batch.dart';
import '../../../models/procurement_list.dart';
import '../../../models/sales_record.dart';
import '../../../services/firestore_service.dart';
import '../../../services/attendance_service.dart';
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
  StreamSubscription<List<KarneBatch>>? _internalBatchesSub;
  StreamSubscription<List<FinancialPeriod>>? _allPeriodsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _attendanceSub;
  List<KarneBatch> _internalBatches = [];
  List<String> _availablePeriodIds = [];

  final String _currentPeriodId =
      '${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}';
  late String _activePeriodId;

  double _actualBranchCookWages = 0.0;
  String? _selectedBatchId;
  bool _isSaving = false;

  int _getMonthNumber(String periodId) {
    try {
      final parts = periodId.split('_');
      return int.parse(parts[1]);
    } catch (_) {
      return DateTime.now().month;
    }
  }

  int _getYearNumber(String periodId) {
    try {
      final parts = periodId.split('_');
      return int.parse(parts[0]);
    } catch (_) {
      return DateTime.now().year;
    }
  }

  @override
  void initState() {
    super.initState();
    _activePeriodId = _currentPeriodId;
    _availablePeriodIds = [_currentPeriodId];
    _initializeDefaultPeriod(_activePeriodId);
    _subscribeToAllPeriods();
    _subscribeToLivePeriod();
    _subscribeToLiveSales();
    _loadRfidAttendance();
    _attendanceSub = AttendanceService.watchTodayAttendance().listen((_) {
      if (!mounted) return;
      _loadRfidAttendance();
    });
    if (widget.karneBatches.isEmpty) {
      _internalBatchesSub = FirestoreService.watchProductionBatches().listen((batches) {
        if (!mounted) return;
        setState(() {
          _internalBatches = batches;
          final counts = _extractMeatCounts();
          _period = _period.copyWith(
            regular250gCount: counts.count250g,
            medium300gCount: counts.count300g,
            b1t1400gCount: counts.count400g,
            productionCookingSessions: counts.sessionsCount,
          );
        });
      });
    }
  }

  void _subscribeToAllPeriods() {
    _allPeriodsSub = FirestoreService.watchAllFinancialPeriods().listen((periods) {
      if (!mounted) return;
      final currentYear = DateTime.now().year;

      // Filter out any periods before current year (bawal ang 2025).
      // Ang pinaka-oldest na pwedeng balikan ay kung ano ang pinaka-unang recorded period sa database para sa taong ito.
      final validPeriods = periods
          .where((p) => _getYearNumber(p.id) >= currentYear)
          .map((p) => p.id)
          .toSet();

      validPeriods.add(_currentPeriodId);
      validPeriods.add(_activePeriodId);

      final sorted = validPeriods.toList()..sort((a, b) => b.compareTo(a));
      setState(() {
        _availablePeriodIds = sorted;
      });
    });
  }

  void _initializeDefaultPeriod([String? periodId]) {
    final pid = periodId ?? _activePeriodId;
    final targetMonth = _getMonthNumber(pid);
    final targetYear = _getYearNumber(pid);
    final counts = _extractMeatCounts(targetYear, targetMonth);

    // Uncheck all procurement items by default for a fresh period
    final cleanGroups = FirestoreService.defaultProcurementGroups.map((group) {
      return group.copyWith(
        items: group.items.map((item) => item.copyWith(isPaid: false)).toList(),
      );
    }).toList();

    _period = FinancialPeriod(
      id: pid,
      monthName: _getMonthName(targetMonth),
      year: targetYear,
      notes: '',
      roiInvestment: 0.0,
      regular250gCount: counts.count250g,
      medium300gCount: counts.count300g,
      b1t1400gCount: counts.count400g,
      productionCookingSessions: counts.sessionsCount,
      productionCookDailyRate: 1000.0,
      productionCutterDailyRate: 1100.0,
      driverWorkingDays: 0,
      driverDailyWage: 650.0,
      branchCookLaborTotal: 0.0,
      daddyNetDays: 0,
      trikeGasDays: 0,
      procurementGroups: cleanGroups,
    );
  }

  void _subscribeToLivePeriod() {
    _periodSub?.cancel();
    final targetMonth = _getMonthNumber(_activePeriodId);
    final targetYear = _getYearNumber(_activePeriodId);

    _periodSub = FirestoreService.watchMonthlyFinancialPeriod(_activePeriodId)
        .listen((remotePeriod) {
      if (!mounted) return;
      if (remotePeriod != null) {
        final counts = _extractMeatCounts(targetYear, targetMonth);
        setState(() {
          _period = remotePeriod.copyWith(
            regular250gCount: counts.count250g,
            medium300gCount: counts.count300g,
            b1t1400gCount: counts.count400g,
            productionCookingSessions: counts.sessionsCount,
            cookRfidDays: _period.cookRfidDays,
            cutterRfidDays: _period.cutterRfidDays,
            driverWorkingDays: _period.driverWorkingDays,
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
    _salesSub?.cancel();
    final targetMonth = _getMonthNumber(_activePeriodId);
    final targetYear = _getYearNumber(_activePeriodId);

    _salesSub = FirestoreService.watchRecentSales(limit: 300).listen((records) {
      if (!mounted) return;
      // Sum wages strictly for the active month and year
      final monthRecords = records.where((r) =>
          r.date.year == targetYear && r.date.month == targetMonth);
      final totalWages =
          monthRecords.fold(0.0, (sum, r) => sum + r.computedWage);

      if (totalWages > 0 || _actualBranchCookWages > 0) {
        setState(() {
          _actualBranchCookWages = totalWages;
          _period = _period.copyWith(branchCookLaborTotal: totalWages);
        });
      }
    });
  }

  void _selectPeriod(String newPeriodId) {
    if (newPeriodId == _activePeriodId) return;
    setState(() {
      _activePeriodId = newPeriodId;
      _selectedBatchId = null;
      _actualBranchCookWages = 0.0;
      _initializeDefaultPeriod(newPeriodId);
    });
    _subscribeToLivePeriod();
    _subscribeToLiveSales();
    _loadRfidAttendance();
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
    _internalBatchesSub?.cancel();
    _allPeriodsSub?.cancel();
    _attendanceSub?.cancel();
    super.dispose();
  }

  Future<void> _loadRfidAttendance() async {
    final targetMonth = _getMonthNumber(_activePeriodId);
    final targetYear = _getYearNumber(_activePeriodId);

    try {
      final results = await Future.wait([
        AttendanceService.getRfidDaysWorkedForMonth(
          positionKeywords: ['Production Cook'],
          year: targetYear,
          month: targetMonth,
        ),
        AttendanceService.getRfidDaysWorkedForMonth(
          positionKeywords: ['Meat Cutter', 'Production Meat'],
          year: targetYear,
          month: targetMonth,
        ),
        AttendanceService.getRfidDaysWorkedForMonth(
          positionKeywords: ['Driver'],
          year: targetYear,
          month: targetMonth,
        ),
      ]);

      if (!mounted) return;
      final cookDays = results[0];
      final cutterDays = results[1];
      final driverDays = results[2];

      setState(() {
        _period = _period.copyWith(
          cookRfidDays: cookDays,
          cutterRfidDays: cutterDays,
          driverWorkingDays: driverDays,
        );
      });
    } catch (e) {
      debugPrint('_loadRfidAttendance error in MonthlyFinancials: $e');
    }
  }

  _MeatCountResult _extractMeatCounts([int? year, int? month]) {
    int c250 = 0;
    int c300 = 0;
    int c400 = 0;
    int sessions = 0;

    final targetMonth = month ?? _getMonthNumber(_activePeriodId);
    final targetYear = year ?? _getYearNumber(_activePeriodId);

    final availableBatches = widget.karneBatches.isNotEmpty
        ? widget.karneBatches
        : _internalBatches;

    // Filter strictly by the active month and year to avoid cross-month bleeding
    final monthBatches = availableBatches.where((b) {
      return b.date.year == targetYear && b.date.month == targetMonth;
    }).toList();

    final batchesToUse = _selectedBatchId == null
        ? monthBatches
        : monthBatches.where((b) => b.id == _selectedBatchId).toList();

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
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (confirmCtx) => AlertDialog(
                  title: Text('Delete ${item.name}?'),
                  content: Text(
                    'Are you sure you want to remove "${item.name}" from ${group.title}?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmCtx, false),
                      child: const Text('CANCEL'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(confirmCtx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminWebColors.error,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('DELETE'),
                    ),
                  ],
                ),
              );

              if (confirm == true && mounted) {
                setState(() {
                  group.items.removeWhere((i) => i.id == item.id);
                });
                Navigator.pop(ctx);
                _persistPeriod();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Item "${item.name}" deleted.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('DELETE', style: TextStyle(color: AdminWebColors.error)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newPrice = double.tryParse(priceCtrl.text) ?? 0.0;

              final confirm = await showDialog<bool>(
                context: context,
                builder: (confirmCtx) => AlertDialog(
                  title: const Text('Save Changes?'),
                  content: Text(
                    'Are you sure you want to update item to "$newName" with price ₱${newPrice.toStringAsFixed(2)}?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmCtx, false),
                      child: const Text('CANCEL'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(confirmCtx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminWebColors.accent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('SAVE'),
                    ),
                  ],
                ),
              );

              if (confirm == true && mounted) {
                setState(() {
                  item.name = newName;
                  item.price = newPrice;
                });
                Navigator.pop(ctx);
                _persistPeriod();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Item "$newName" saved successfully.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
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

  void _uncheckAllProcurementDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset All Checkboxes?'),
        content: const Text(
          'This will uncheck all procurement ingredients for the current month so you can track this month\'s purchases fresh.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                for (var group in _period.procurementGroups) {
                  for (var item in group.items) {
                    item.isPaid = false;
                  }
                }
              });
              _persistPeriod();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF2E7D32),
                  content: Text('All ingredient checkboxes have been reset to unpaid.'),
                ),
              );
            },
            child: const Text('RESET ALL'),
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

  void _showStartNewMonthDialog() {
    final now = DateTime.now();
    final currentMonthDate = DateTime(now.year, now.month, 1);
    final nextMonthDate = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);

    // Default to next month if current month period already exists, else current month
    final currentPid = 'fp_${currentMonthDate.year}_${currentMonthDate.month.toString().padLeft(2, '0')}';
    DateTime selectedMonthDate = _availablePeriodIds.contains(currentPid)
        ? nextMonthDate
        : currentMonthDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final bool isCurrentMonth = selectedMonthDate.year == currentMonthDate.year &&
              selectedMonthDate.month == currentMonthDate.month;
          final bool canGoBack = !isCurrentMonth;
          final bool canGoForward = isCurrentMonth;

          final periodId = 'fp_${selectedMonthDate.year}_${selectedMonthDate.month.toString().padLeft(2, '0')}';
          final bool alreadyExists = _availablePeriodIds.contains(periodId);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.calendar_month_rounded, color: AdminWebColors.accent),
                SizedBox(width: 10),
                Text('Start New Monthly Period', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pumili ng buwan gamit ang arrow. Ang pinaka-pwede lang simulan ay ang kasalukuyang buwan at ang kasunod na buwan. Bawal nang balikan ang mga nakaraang buwan.',
                    style: TextStyle(fontSize: 13, color: AdminWebColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AdminWebColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminWebColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range_rounded, size: 18, color: AdminWebColors.accent),
                        const SizedBox(width: 8),
                        const Text('BUWAN:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, size: 20),
                          tooltip: canGoBack ? 'Kasalukuyang Buwan' : 'Bawal nang pumili ng nakaraang buwan',
                          onPressed: canGoBack
                              ? () {
                                  setDialogState(() {
                                    selectedMonthDate = currentMonthDate;
                                  });
                                }
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AdminWebColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_getMonthName(selectedMonthDate.month).toUpperCase()} ${selectedMonthDate.year}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AdminWebColors.accent),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, size: 20),
                          tooltip: canGoForward ? 'Kasunod na Buwan' : 'Lalabas lang ang susunod kapag tapos na ang kasalukuyang buwan',
                          onPressed: canGoForward
                              ? () {
                                  setDialogState(() {
                                    selectedMonthDate = nextMonthDate;
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                  if (alreadyExists) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AdminWebColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminWebColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18, color: AdminWebColors.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'May record na para sa ${_getMonthName(selectedMonthDate.month)} ${selectedMonthDate.year}. Pindutin ang Switch para lumipat dito.',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminWebColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminWebColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _startNewMonthPeriod(selectedMonthDate.year, selectedMonthDate.month);
                },
                child: Text(alreadyExists ? 'SWITCH TO MONTH' : 'CREATE MONTH'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showResetCurrentMonthDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.restart_alt_rounded, color: AdminWebColors.error),
            const SizedBox(width: 8),
            Text('Reset ${_period.monthName} ${_period.year}?'),
          ],
        ),
        content: Text(
          'Gusto mo bang i-reset ang data para sa ${_period.monthName} ${_period.year}?\n\n'
          '• Magiging 0 pcs ang karne (Regular, Medium, B1T1) dahil wala pang naluluto para sa buwang ito.\n'
          '• Magiging UNCHECKED ang lahat ng ingredients sa checklist para masimulan ang pag-track ng gastusin ngayong buwan.\n'
          '• Magiging ₱0 ang puhunan / ROI at mawawala ang lumang notes mula sa nakaraang buwan.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminWebColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('YES, RESET MONTH'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final targetMonth = _getMonthNumber(_activePeriodId);
    final targetYear = _getYearNumber(_activePeriodId);
    final counts = _extractMeatCounts(targetYear, targetMonth);

    final cleanGroups = FirestoreService.defaultProcurementGroups.map((g) {
      return g.copyWith(items: g.items.map((i) => i.copyWith(isPaid: false)).toList());
    }).toList();

    final resetPeriod = FinancialPeriod(
      id: _activePeriodId,
      monthName: _getMonthName(targetMonth),
      year: targetYear,
      notes: '',
      roiInvestment: 0.0,
      regular250gCount: counts.count250g,
      medium300gCount: counts.count300g,
      b1t1400gCount: counts.count400g,
      productionCookingSessions: counts.sessionsCount,
      productionCookDailyRate: 1000.0,
      productionCutterDailyRate: 1100.0,
      driverWorkingDays: 0,
      driverDailyWage: 650.0,
      branchCookLaborTotal: 0.0,
      daddyNetDays: 0,
      trikeGasDays: 0,
      procurementGroups: cleanGroups,
    );

    await FirestoreService.saveMonthlyFinancialPeriod(resetPeriod);
    setState(() {
      _period = resetPeriod;
      _actualBranchCookWages = 0.0;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2E7D32),
          content: Text('${_period.monthName} ${_period.year} data successfully reset to fresh start!'),
        ),
      );
    }
  }

  Future<void> _startNewMonthPeriod(int year, int month) async {
    final newPid = '${year}_${month.toString().padLeft(2, '0')}';

    if (_availablePeriodIds.contains(newPid)) {
      _selectPeriod(newPid);
      return;
    }

    // Carry over current procurement ingredients with all checkboxes UNCHECKED (isPaid = false)
    final resetProcurement = _period.procurementGroups.map((g) {
      return g.copyWith(
        items: g.items.map((i) => i.copyWith(isPaid: false)).toList(),
      );
    }).toList();

    final counts = _extractMeatCounts(year, month);

    final newPeriod = FinancialPeriod(
      id: newPid,
      monthName: _getMonthName(month),
      year: year,
      notes: 'FINANCIAL TARGETS AND EXPENSES FOR ${_getMonthName(month).toUpperCase()} $year.',
      roiInvestment: 0.0,
      regular250gCount: counts.count250g,
      medium300gCount: counts.count300g,
      b1t1400gCount: counts.count400g,
      productionCookingSessions: counts.sessionsCount,
      productionCookDailyRate: 1000.0,
      productionCutterDailyRate: 1100.0,
      driverWorkingDays: 0,
      driverDailyWage: 650.0,
      branchCookLaborTotal: 0.0,
      procurementGroups: resetProcurement.isNotEmpty
          ? resetProcurement
          : FirestoreService.defaultProcurementGroups.map((g) {
              return g.copyWith(items: g.items.map((i) => i.copyWith(isPaid: false)).toList());
            }).toList(),
    );

    await FirestoreService.saveMonthlyFinancialPeriod(newPeriod);
    _selectPeriod(newPid);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2E7D32),
          content: Text('Started new financial period for ${_getMonthName(month)} $year! Checklists unchecked and reset.'),
        ),
      );
    }
  }

  Widget _buildTopActionBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final titleContent = Text(
          '${_period.monthName.toUpperCase()} ${_period.year} FINANCIAL STATEMENT',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AdminWebColors.textPrimary,
            letterSpacing: 0.5,
          ),
        );

        final periodSelector = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AdminWebColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_rounded, size: 16, color: AdminWebColors.accent),
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _availablePeriodIds.contains(_activePeriodId)
                      ? _activePeriodId
                      : null,
                  hint: Text(
                    '${_period.monthName} ${_period.year}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AdminWebColors.textPrimary),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AdminWebColors.accent),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AdminWebColors.textPrimary),
                  items: _availablePeriodIds.map((pid) {
                    final m = _getMonthNumber(pid);
                    final y = _getYearNumber(pid);
                    final isCurrent = pid == _currentPeriodId;
                    return DropdownMenuItem<String>(
                      value: pid,
                      child: Text(
                        '${_getMonthName(m)} $y ${isCurrent ? "(Current)" : ""}',
                        style: TextStyle(
                          fontWeight: pid == _activePeriodId ? FontWeight.w900 : FontWeight.w600,
                          color: pid == _activePeriodId ? AdminWebColors.accent : AdminWebColors.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (newId) {
                    if (newId != null) {
                      _selectPeriod(newId);
                    }
                  },
                ),
              ),
            ],
          ),
        );

        final newMonthBtn = ElevatedButton.icon(
          onPressed: _showStartNewMonthDialog,
          icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Colors.white),
          label: const Text(
            'START NEW MONTH',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminWebColors.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        final exportBtn = ElevatedButton.icon(
          onPressed: _exportFinancialsExcel,
          icon: const Icon(Icons.table_view_rounded, size: 16, color: Colors.white),
          label: const Text(
            'EXPORT P&L (.XLSX)',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        final resetMonthBtn = OutlinedButton.icon(
          onPressed: _showResetCurrentMonthDialog,
          icon: const Icon(Icons.restart_alt_rounded, size: 16, color: AdminWebColors.error),
          label: const Text(
            'RESET MONTH DATA',
            style: TextStyle(
              color: AdminWebColors.error,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AdminWebColors.error),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleContent),
              const SizedBox(width: 12),
              periodSelector,
              const SizedBox(width: 10),
              resetMonthBtn,
              const SizedBox(width: 10),
              newMonthBtn,
              const SizedBox(width: 10),
              exportBtn,
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleContent,
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  periodSelector,
                  resetMonthBtn,
                  newMonthBtn,
                  exportBtn,
                ],
              ),
            ],
          );
        }
      },
    );
  }

  // --- BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      color: AdminWebColors.background,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 16),
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
            color: AdminWebColors.accent,
          ),
          _kpiTile(
            'Total Expenses',
            '₱${_period.totalExpenses.toStringAsFixed(0)}',
            'INGREDIENTS + ALL PAYROLL + OVERHEADS',
            Icons.shopping_cart_rounded,
            color: AdminWebColors.accentDark,
          ),
          _kpiTile(
            'NET MAV (KITA NI SIR MAV)',
            '₱${_period.netMav.toStringAsFixed(0)}',
            isAchieved
                ? 'NABAWING PUHUNAN: +₱${_period.netMav.toStringAsFixed(0)} TUBONG KITA'
                : 'BAWI PUHUNAN: KULANG PA NG ₱${_period.capitalRemainingToRecover.toStringAsFixed(0)}',
            Icons.account_balance_wallet_rounded,
            color: AdminWebColors.accent,
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
              const Expanded(
                child: Text(
                  'TOTAL KARNE PRODUCTION (MAIN WAREHOUSE)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AdminWebColors.accent,
                    letterSpacing: 0.5,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                  Expanded(
                    child: DropdownButton<String?>(
                      value: _selectedBatchId,
                      isDense: true,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'All Monthly Batches (Combined)',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...widget.karneBatches.map((b) => DropdownMenuItem<String?>(
                              value: b.id,
                              child: Text(
                                '${b.name} (${b.totalKilos.toStringAsFixed(1)} kg)',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
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
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              final boxes = [
                _meatPortionBox(
                  sizeLabel: 'Regular (250G)',
                  pcs: _period.regular250gCount,
                  rate: 130.0,
                  totalAmount: _period.regular250gRevenue,
                  color: AdminWebColors.accent,
                ),
                _meatPortionBox(
                  sizeLabel: 'Medium (300G)',
                  pcs: _period.medium300gCount,
                  rate: 160.0,
                  totalAmount: _period.medium300gRevenue,
                  color: AdminWebColors.accentDark,
                ),
                _meatPortionBox(
                  sizeLabel: 'B1T1 (400G)',
                  pcs: _period.b1t1400gCount,
                  rate: 210.0,
                  totalAmount: _period.b1t1400gRevenue,
                  color: AdminWebColors.accent,
                ),
              ];

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: boxes[0]),
                    const SizedBox(width: 12),
                    Expanded(child: boxes[1]),
                    const SizedBox(width: 12),
                    Expanded(child: boxes[2]),
                  ],
                );
              }
              return Column(
                children: [
                  boxes[0],
                  const SizedBox(height: 10),
                  boxes[1],
                  const SizedBox(height: 10),
                  boxes[2],
                ],
              );
            },
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
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _uncheckAllProcurementDialog,
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: const Text('RESET CHECKBOXES'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminWebColors.textSecondary,
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
          _overheadRowNoAction(
            label: 'Production Labor (Cook & Meat Cutter)',
            val: '₱${_period.totalProductionLaborCost.toStringAsFixed(0)}',
            sub: (_period.cookRfidDays != null || _period.cutterRfidDays != null)
                ? '${_period.cookRfidDays ?? 0} Days Cook (₱${_period.productionCookDailyRate.toStringAsFixed(0)}) + ${_period.cutterRfidDays ?? 0} Days Cutter (₱${_period.productionCutterDailyRate.toStringAsFixed(0)}) [RFID-verified]'
                : '${_period.productionCookingSessions} Cooking Sessions × (₱${_period.productionCookDailyRate.toStringAsFixed(0)} Cook + ₱${_period.productionCutterDailyRate.toStringAsFixed(0)} Cutter)',
          ),
          const Divider(height: 28),

          // 2. Branch Cook Labor (Automated from Sales & Payroll)
          _overheadRowNoAction(
            label: 'Branch Cooks Labor (6 Stores)',
            val: '₱${_period.effectiveBranchCookLabor.toStringAsFixed(0)}',
            sub:
                'Synced automatically from Branch Cook attendance & sales (No wage when absent).',
          ),
          const Divider(height: 28),

          // 3. Driver Labor
          _overheadRowNoAction(
            label: 'Driver Labor (Driver Wages)',
            val: '₱${_period.totalDriverLaborCost.toStringAsFixed(0)}',
            sub:
                '${_period.driverWorkingDays} Days × ₱${_period.driverDailyWage.toStringAsFixed(0)} daily rate (RFID-verified)',
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

  Widget _overheadRowNoAction({
    required String label,
    required String val,
    required String sub,
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
        Text(
          val,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: AdminWebColors.textPrimary,
          ),
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
