import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider;
import '../../models/branch.dart';
import '../../models/branch_daily_inventory.dart';
import '../../models/branch_meat_inventory.dart';
import '../../models/financial_period.dart';
import '../../models/inventory_batch.dart';
import '../../models/meat_dispatch.dart';
import '../../models/procurement_list.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_top_actions.dart';

/// Owner-app Inventory screen.
///
/// Production Batch logging (Warehouse tab) now shares the exact same
/// [KarneBatch]/[KarneSession] model used by the Admin Web Inventory
/// screen (see admin_web/inventory/karne_batch_detail_screen.dart),
/// instead of a separate locally-defined copy with slightly different
/// field names. Same reason the Financials tab exists here now too:
/// both surfaces should show the same numbers computed the same way,
/// backed by live Firestore sync.
class OwnerInventoryScreen extends StatefulWidget {
  const OwnerInventoryScreen({super.key});

  @override
  State<OwnerInventoryScreen> createState() => _OwnerInventoryScreenState();
}

class _OwnerInventoryScreenState extends State<OwnerInventoryScreen> {
  int _section = 0; // 0 = Warehouse, 1 = Branches, 2 = Dispatch, 3 = Finance

  StreamSubscription<List<KarneBatch>>? _batchesSub;
  StreamSubscription<List<BranchMeatStock>>? _meatStocksSub;
  StreamSubscription<List<MeatDispatch>>? _dispatchesSub;

  final List<KarneBatch> _batches = [
    KarneBatch(
      id: 'kb1',
      name: 'Batch Danish Crown - July',
      totalKilos: 1000,
    ),
  ];

  List<BranchMeatStock> _branchMeatStocks = kSampleBranches
      .map((b) => BranchMeatStock.defaultForBranch(b))
      .toList();

  List<MeatDispatch> _meatDispatches = [];

  late FinancialPeriod _period;

  @override
  void initState() {
    super.initState();
    _initializeFinancials();
    // Start listening to real-time Firestore updates IMMEDIATELY.
    FirestoreService.seedDefaultBatchesIfEmpty();
    FirestoreService.seedDefaultBranchMeatStocksIfEmpty();

    _batchesSub = FirestoreService.watchProductionBatches().listen((batches) {
      if (mounted) {
        setState(() {
          _batches
            ..clear()
            ..addAll(batches);
        });
        _refreshFinancialsFromBatches();
      }
    });

    _meatStocksSub = FirestoreService.watchBranchMeatStocks().listen((stocks) {
      if (mounted) {
        setState(() {
          _branchMeatStocks = stocks;
        });
      }
    });

    _dispatchesSub = FirestoreService.watchMeatDispatches().listen((dispatches) {
      if (mounted) {
        setState(() {
          _meatDispatches = dispatches;
        });
      }
    });
  }

  @override
  void dispose() {
    _batchesSub?.cancel();
    _meatStocksSub?.cancel();
    _dispatchesSub?.cancel();
    super.dispose();
  }

  // --- FINANCIALS SETUP -----------------------------------------------

  void _initializeFinancials() {
    final groups = [
      ProcurementGroup(id: 'pg1', title: 'LPG 6 STORE', items: [
        ProcurementItem(id: 'i1', name: 'Labuin', price: 1065, isPaid: true),
        ProcurementItem(id: 'i2', name: 'Nanhaya', price: 1065, isPaid: true),
        ProcurementItem(id: 'i3', name: 'San Francisco', price: 1065, isPaid: true),
        ProcurementItem(id: 'i4', name: 'Dayap', price: 1065, isPaid: true),
        ProcurementItem(id: 'i5', name: 'Gatid', price: 1065, isPaid: true),
        ProcurementItem(id: 'i6', name: 'Pila', price: 1065, isPaid: true),
      ]),
      ProcurementGroup(id: 'pg2', title: 'INHOUSE INGREDIENTS', items: [
        ProcurementItem(id: 'i7', name: 'Styro 30 bundle', price: 3900, isPaid: true),
        ProcurementItem(id: 'i8', name: 'Sili budget', price: 1220, isPaid: true),
        ProcurementItem(id: 'i9', name: 'Sibuyas budget', price: 5040, isPaid: true),
        ProcurementItem(id: 'i10', name: '9 box mayo', price: 10822.5, isPaid: true),
        ProcurementItem(id: 'i11', name: 'Suka 2pcs', price: 38, isPaid: true),
        ProcurementItem(id: 'i12', name: 'Ellies Toyo 2pcs', price: 204, isPaid: true),
        ProcurementItem(id: 'i13', name: 'Knorr shopee 3pcs', price: 1494, isPaid: true),
        ProcurementItem(id: 'i14', name: 'Sando bag 6000pcs', price: 600, isPaid: true),
      ]),
      ProcurementGroup(id: 'pg3', title: 'PRODUCTION INGREDIENTS & LPG BIG', items: [
        ProcurementItem(id: 'p1', name: 'Asin 380', price: 380, isPaid: true),
        ProcurementItem(id: 'p2', name: 'Laurel 200', price: 200, isPaid: true),
        ProcurementItem(id: 'p3', name: 'Datu puti 210', price: 210, isPaid: true),
        ProcurementItem(id: 'p4', name: 'Paminta online 541', price: 541, isPaid: true),
        ProcurementItem(id: 'p5', name: 'Vetsin shopee online 245', price: 245, isPaid: true),
        ProcurementItem(id: 'p6', name: 'Gasul 4650 2 set', price: 4650, isPaid: true),
      ]),
      ProcurementGroup(id: 'pg4', title: 'SECRET INGREDIENTS FOR MAYO', items: [
        ProcurementItem(id: 's1', name: 'Knorr oyster sauce 646', price: 646, isPaid: true),
        ProcurementItem(id: 's2', name: 'Paminta pino 411', price: 411, isPaid: true),
        ProcurementItem(id: 's3', name: 'Garlic powder 315', price: 315, isPaid: true),
        ProcurementItem(id: 's4', name: 'Original vetsin shopee 193.5', price: 193.5, isPaid: true),
        ProcurementItem(id: 's5', name: 'Liver spread 19pcs', price: 408.5, isPaid: true),
      ]),
    ];

    final overheads = List.generate(25, (i) => DailyOverheadEntry(
      date: DateTime.now().subtract(Duration(days: i)),
      totalStaffWages: 2210, // 3160 - 950
    ));

    _period = FinancialPeriod(
      id: 'p1',
      monthName: 'July - August',
      year: 2026,
      productionPcs: _totalPcsFromBatches(),
      productionLaborDays: 7,
      dailyOverheads: overheads,
      procurementGroups: groups,
    );
  }

  /// Same idea as Admin Web's fix: productionPcs is derived from the
  /// real batches instead of being a separate hardcoded number, so
  /// this tab and the Warehouse tab can't drift out of sync with
  /// each other.
  int _totalPcsFromBatches() =>
      _batches.fold(0, (sum, b) => sum + b.totalPcsNagawa);

  void _refreshFinancialsFromBatches() {
    setState(() {
      _period = FinancialPeriod(
        id: _period.id,
        monthName: _period.monthName,
        year: _period.year,
        productionPcs: _totalPcsFromBatches(),
        productionLaborDays: _period.productionLaborDays,
        dailyOverheads: _period.dailyOverheads,
        procurementGroups: _period.procurementGroups,
      );
    });
  }

  void _editProcurementItem(ProcurementItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    final priceCtrl = TextEditingController(text: item.price.toString());

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Edit ${item.name}'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(controller: nameCtrl, placeholder: 'Product Name'),
            const SizedBox(height: 8),
            CupertinoTextField(controller: priceCtrl, placeholder: 'Price', keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          CupertinoDialogAction(
            onPressed: () {
              setState(() {
                item.name = nameCtrl.text;
                item.price = double.tryParse(priceCtrl.text) ?? item.price;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // --- WAREHOUSE / PRODUCTION BATCH ------------------------------------

  void _showAddBatchDialog() {
    final nameController = TextEditingController();
    final kilosController = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Start New Batch'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(controller: nameController, placeholder: 'Batch Name'),
            const SizedBox(height: 8),
            CupertinoTextField(controller: kilosController, placeholder: 'Total Kilos', keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          CupertinoDialogAction(
            onPressed: () {
              final k = double.tryParse(kilosController.text);
              if (nameController.text.isNotEmpty && k != null) {
                final newBatch = KarneBatch(
                  id: 'kb_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameController.text,
                  totalKilos: k,
                );
                FirestoreService.saveProductionBatch(newBatch);
                setState(() {
                  _batches.insert(0, newBatch);
                });
                _refreshFinancialsFromBatches();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showNewSessionDialog(KarneBatch batch) {
    final brandCtrl = TextEditingController();
    final resekoCtrl = TextEditingController(text: '28');
    final minutesCtrl = TextEditingController(text: '25');
    final kilosCtrl = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('New Cooking Session'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(controller: brandCtrl, placeholder: 'Brand Name'),
            const SizedBox(height: 8),
            CupertinoTextField(controller: resekoCtrl, placeholder: 'Target Reseko % (Limit)', keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            CupertinoTextField(controller: minutesCtrl, placeholder: 'Minutes Laga', keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            CupertinoTextField(controller: kilosCtrl, placeholder: 'Kilos to Cook', keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          CupertinoDialogAction(
            onPressed: () {
              final r = double.tryParse(resekoCtrl.text);
              final m = int.tryParse(minutesCtrl.text);
              final k = double.tryParse(kilosCtrl.text);
              if (brandCtrl.text.isNotEmpty && r != null && m != null && k != null) {
                final idx = _batches.indexWhere((b) => b.id == batch.id);
                if (idx >= 0) {
                  final newSessions = List<KarneSession>.from(_batches[idx].sessions)
                    ..add(KarneSession(
                      date: DateTime.now(),
                      brand: brandCtrl.text,
                      resekoApplied: r,
                      boilingMinutes: m,
                      kilosCooked: k,
                    ));
                  final updated = _batches[idx].copyWith(sessions: newSessions);
                  FirestoreService.saveProductionBatch(updated);
                  setState(() {
                    _batches[idx] = updated;
                  });
                  _refreshFinancialsFromBatches();
                }
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _enterActualPcs(KarneBatch batch, int sessionIndex) {
    final session = batch.sessions[sessionIndex];
    final actualCtrl = TextEditingController(
      text: session.actualPcs == 0 ? '' : session.actualPcs.toString(),
    );

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Enter Nagawa'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            Text('Ideal Yield: ${session.idealYield.toInt()} pcs'),
            Text('Kota (Limit): ${session.kota} pcs'),
            const SizedBox(height: 12),
            CupertinoTextField(controller: actualCtrl, placeholder: 'Actual Pcs', keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          CupertinoDialogAction(
            onPressed: () {
              final val = int.tryParse(actualCtrl.text);
              if (val != null) {
                final bIdx = _batches.indexWhere((b) => b.id == batch.id);
                if (bIdx >= 0) {
                  final newSessions = List<KarneSession>.from(_batches[bIdx].sessions);
                  final old = newSessions[sessionIndex];
                  newSessions[sessionIndex] = KarneSession(
                    date: old.date,
                    brand: old.brand,
                    resekoApplied: old.resekoApplied,
                    boilingMinutes: old.boilingMinutes,
                    kilosCooked: old.kilosCooked,
                    actualPcs: val,
                  );
                  final updated = _batches[bIdx].copyWith(sessions: newSessions);
                  FirestoreService.saveProductionBatch(updated);
                  setState(() {
                    _batches[bIdx] = updated;
                  });
                  _refreshFinancialsFromBatches();
                }
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteSession(KarneBatch batch, int sessionIndex) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
          'Are you sure you want to delete this cooking session? '
          'This will return the kilos to the batch stock.',
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              final bIdx = _batches.indexWhere((b) => b.id == batch.id);
              if (bIdx >= 0) {
                final newSessions = List<KarneSession>.from(_batches[bIdx].sessions)
                  ..removeAt(sessionIndex);
                final updated = _batches[bIdx].copyWith(sessions: newSessions);
                FirestoreService.saveProductionBatch(updated);
                setState(() {
                  _batches[bIdx] = updated;
                });
                _refreshFinancialsFromBatches();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddDispatchDialog({
    String? defaultBranchId,
    int? defaultReg,
    int? defaultMed,
    int? defaultB1t1,
    int? defaultMayo,
    int? defaultStyro,
    int? defaultToyo,
  }) {
    final regCtrl = TextEditingController(text: defaultReg != null && defaultReg > 0 ? '$defaultReg' : '');
    final medCtrl = TextEditingController(text: defaultMed != null && defaultMed > 0 ? '$defaultMed' : '');
    final b1t1Ctrl = TextEditingController(text: defaultB1t1 != null && defaultB1t1 > 0 ? '$defaultB1t1' : '');
    final mayoCtrl = TextEditingController(text: defaultMayo != null && defaultMayo > 0 ? '$defaultMayo' : '');
    final styroCtrl = TextEditingController(text: defaultStyro != null && defaultStyro > 0 ? '$defaultStyro' : '');
    final toyoCtrl = TextEditingController(text: defaultToyo != null && defaultToyo > 0 ? '$defaultToyo' : '');
    int destIdx = 0;
    if (defaultBranchId != null) {
      final found = kSampleBranches.indexWhere((b) => b.id == defaultBranchId);
      if (found >= 0) destIdx = found;
    }

    showCupertinoDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => CupertinoAlertDialog(
          title: const Text('Record Dispatch (Karne & Supplies)'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Text('Source: Main Warehouse', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('To: ${kSampleBranches[destIdx].fullName}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    showCupertinoModalPopup(
                      context: context,
                      builder: (_) => Container(
                        height: 250,
                        color: CupertinoColors.white,
                        child: CupertinoPicker(
                          itemExtent: 32,
                          onSelectedItemChanged: (i) => setDialogState(() => destIdx = i),
                          children: kSampleBranches.map((b) => Center(child: Text(b.name))).toList(),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                const Text('Karne (Pcs):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent)),
                const SizedBox(height: 6),
                CupertinoTextField(
                  controller: regCtrl,
                  placeholder: '250g - Regular (Pcs)',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 6),
                CupertinoTextField(
                  controller: medCtrl,
                  placeholder: '300g - Medium (Pcs)',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 6),
                CupertinoTextField(
                  controller: b1t1Ctrl,
                  placeholder: '400g - B1T1 (Pcs)',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                const Text('Supplies:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent)),
                const SizedBox(height: 6),
                CupertinoTextField(
                  controller: mayoCtrl,
                  placeholder: 'Mayo (Packets/Pcs)',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 6),
                CupertinoTextField(
                  controller: toyoCtrl,
                  placeholder: 'Toyo (Bottles/Pcs)',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 6),
                CupertinoTextField(
                  controller: styroCtrl,
                  placeholder: 'Styro (Boxes/Pcs)',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            CupertinoDialogAction(
              onPressed: () async {
                final reg = int.tryParse(regCtrl.text) ?? 0;
                final med = int.tryParse(medCtrl.text) ?? 0;
                final b1t1 = int.tryParse(b1t1Ctrl.text) ?? 0;
                final mayo = int.tryParse(mayoCtrl.text) ?? 0;
                final styro = int.tryParse(styroCtrl.text) ?? 0;
                final toyo = int.tryParse(toyoCtrl.text) ?? 0;

                if (reg > 0 || med > 0 || b1t1 > 0 || mayo > 0 || styro > 0 || toyo > 0) {
                  final dest = kSampleBranches[destIdx];
                  final dispatch = MeatDispatch(
                    id: '',
                    destinationBranchId: dest.id,
                    destinationBranchName: dest.fullName,
                    regular250gPcs: reg,
                    medium300gPcs: med,
                    b1t1_400gPcs: b1t1,
                    mayoPcs: mayo,
                    styroPcs: styro,
                    toyoPcs: toyo,
                    status: 'pending',
                    createdAt: DateTime.now(),
                  );
                  await FirestoreService.createMeatDispatch(dispatch);
                  await NotificationService.notifyDriverOfDeliveryTask(
                    branchName: dest.fullName,
                    quantityKg: (reg * 0.25) + (med * 0.30) + (b1t1 * 0.40),
                    itemsSummary: dispatch.itemsSummary,
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(title: 'Inventory', trailing: StaffTopActions()),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _section,
                children: const {
                  0: Text('Warehouse', style: TextStyle(fontSize: 12)),
                  1: Text('Branches', style: TextStyle(fontSize: 12)),
                  2: Text('Dispatch', style: TextStyle(fontSize: 12)),
                  3: Text('Finance', style: TextStyle(fontSize: 12)),
                },
                onValueChanged: (v) => setState(() => _section = v!),
              ),
            ),
            Expanded(
              child: _section == 0
                  ? _buildWarehouseTab()
                  : (_section == 1
                      ? _buildBranchesTab()
                      : (_section == 2 ? _buildDispatchLogsTab() : _buildFinancialsTab())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StaffButton(label: 'Start New Batch', icon: CupertinoIcons.add, onPressed: _showAddBatchDialog),
        const SizedBox(height: 20),
        for (final batch in _batches) ...[
          _buildBatchCard(batch),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildBatchCard(KarneBatch batch) {
    return StaffCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  batch.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text('${batch.remainingKilos.toStringAsFixed(1)} KG LEFT', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 24),
          for (int i = 0; i < batch.sessions.length; i++) ...[
            _buildSessionRow(batch, i),
            const SizedBox(height: 12),
          ],
          if (batch.remainingKilos > 0)
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Text('+ New Luto'),
              onPressed: () => _showNewSessionDialog(batch),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionRow(KarneBatch batch, int sessionIndex) {
    final s = batch.sessions[sessionIndex];
    final bool hasActual = s.actualPcs > 0;
    final String resultLabel = !hasActual
        ? '--'
        : (s.sobra > 0 ? '+${s.sobra}' : (s.short > 0 ? '-${s.short}' : 'OK'));
    final Color? resultColor = !hasActual
        ? null
        : (s.sobra > 0 ? CupertinoColors.activeBlue : (s.short > 0 ? AppColors.error : AppColors.success));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${s.date.month}/${s.date.day} - ${s.brand}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () => _enterActualPcs(batch, sessionIndex),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasActual ? CupertinoIcons.pencil : CupertinoIcons.add_circled,
                        size: 14,
                        color: hasActual ? AppColors.textSecondary : AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasActual ? 'Edit Nagawa' : 'Enter Actual',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: hasActual ? AppColors.textSecondary : AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Matches Admin Web's per-session delete (trash icon) on
                // the Karne Batch Detail screen — previously only
                // available on Web.
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () => _deleteSession(batch, sessionIndex),
                  child: const Icon(CupertinoIcons.delete, size: 16, color: AppColors.error),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sessionMiniStat('KILOS', '${s.kilosCooked}'),
            _sessionMiniStat('IDEAL', '${s.idealYield.toInt()}'),
            _sessionMiniStat('KOTA', '${s.kota}', color: AppColors.accent),
            _sessionMiniStat('NAGAWA', hasActual ? '${s.actualPcs}' : '--'),
            _sessionMiniStat('RESULT', resultLabel, color: resultColor),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: AppColors.border),
      ],
    );
  }

  Widget _sessionMiniStat(String label, String val, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
        Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color ?? AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildBranchesTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _branchMeatStocks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final s = _branchMeatStocks[i];
        return StaffCard(
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
                          s.branchName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${s.totalRemainingPcs} / ${s.totalAllocatedPcs} PCS',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '(Natitirang Dala / Total)',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                            if (s.isRunningLow) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'LOW STOCK',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    onPressed: () => _adjustBranchAllocation(i),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.slider_horizontal_3, size: 16, color: AppColors.accent),
                        SizedBox(width: 6),
                        Text(
                          'Adjust',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 8),
              // Itemized Meat Portions
              Row(
                children: [
                  Expanded(
                    child: _meatVariantChip(
                      '250g Regular',
                      '${s.regular250gRemaining} / ${s.regular250gTotal} pcs',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _meatVariantChip(
                      '300g Medium',
                      '${s.medium300gRemaining} / ${s.medium300gTotal} pcs',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _meatVariantChip(
                      '400g B1T1',
                      '${s.b1t1_400gRemaining} / ${s.b1t1_400gTotal} pcs',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _meatVariantChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  /// Lets the Owner update a branch's allocated and remaining pieces per variant.
  void _adjustBranchAllocation(int index) {
    final stock = _branchMeatStocks[index];
    final regTotalCtrl = TextEditingController(text: stock.regular250gTotal.toString());
    final regRemCtrl = TextEditingController(text: stock.regular250gRemaining.toString());
    final medTotalCtrl = TextEditingController(text: stock.medium300gTotal.toString());
    final medRemCtrl = TextEditingController(text: stock.medium300gRemaining.toString());
    final b1t1TotalCtrl = TextEditingController(text: stock.b1t1_400gTotal.toString());
    final b1t1RemCtrl = TextEditingController(text: stock.b1t1_400gRemaining.toString());

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Adjust Meat Stocks (Pcs)'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 4),
              Text(stock.branchName, style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
              const SizedBox(height: 12),
              const Text('250 grams (Regular):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: CupertinoTextField(controller: regTotalCtrl, placeholder: 'Total Pcs', keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: CupertinoTextField(controller: regRemCtrl, placeholder: 'Natitira', keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 10),
              const Text('300 grams (Medium):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: CupertinoTextField(controller: medTotalCtrl, placeholder: 'Total Pcs', keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: CupertinoTextField(controller: medRemCtrl, placeholder: 'Natitira', keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 10),
              const Text('400 grams (B1T1):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: CupertinoTextField(controller: b1t1TotalCtrl, placeholder: 'Total Pcs', keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: CupertinoTextField(controller: b1t1RemCtrl, placeholder: 'Natitira', keyboardType: TextInputType.number)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          CupertinoDialogAction(
            onPressed: () async {
              final regT = int.tryParse(regTotalCtrl.text) ?? stock.regular250gTotal;
              final regR = int.tryParse(regRemCtrl.text) ?? stock.regular250gRemaining;
              final medT = int.tryParse(medTotalCtrl.text) ?? stock.medium300gTotal;
              final medR = int.tryParse(medRemCtrl.text) ?? stock.medium300gRemaining;
              final b1t1T = int.tryParse(b1t1TotalCtrl.text) ?? stock.b1t1_400gTotal;
              final b1t1R = int.tryParse(b1t1RemCtrl.text) ?? stock.b1t1_400gRemaining;

              final updated = stock.copyWith(
                regular250gTotal: regT,
                regular250gRemaining: regR,
                medium300gTotal: medT,
                medium300gRemaining: medR,
                b1t1_400gTotal: b1t1T,
                b1t1_400gRemaining: b1t1R,
                date: DateTime.now(),
              );

              await FirestoreService.saveBranchMeatStock(updated);

              // Also sync total allocated Karne to today's daily inventory
              final totalMeatPcs = regT + medT + b1t1T;
              await FirestoreService.saveDailyInventory(
                BranchDailyInventory(
                  branchId: stock.branchId,
                  branchName: stock.branchName,
                  date: DateTime.now(),
                  allocated: InventoryCounts(
                    karne: totalMeatPcs,
                    mayo: 40,
                    styro: 40,
                    toyo: 7,
                  ),
                ),
              );

              setState(() {
                _branchMeatStocks[index] = updated;
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchLogsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: StaffButton(label: 'Record Dispatch', icon: CupertinoIcons.bus, onPressed: _showAddDispatchDialog),
        ),
        Expanded(
          child: _meatDispatches.isEmpty
              ? const Center(
                  child: Text(
                    'No meat dispatches recorded yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _meatDispatches.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final dispatch = _meatDispatches[i];
                    final isDelivered = dispatch.isDelivered;

                    return StaffCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  dispatch.destinationBranchName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (isDelivered ? AppColors.success : AppColors.warning).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isDelivered ? 'DELIVERED' : 'PENDING DELIVERY',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isDelivered ? AppColors.success : AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dispatch.itemsSummary,
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total: ${dispatch.totalPcs} pcs \u2022 ${dispatch.createdAt.month}/${dispatch.createdAt.day} ${dispatch.createdAt.hour.toString().padLeft(2, '0')}:${dispatch.createdAt.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                onPressed: () => _confirmDeleteDispatch(dispatch),
                                child: const Icon(CupertinoIcons.delete, size: 16, color: AppColors.error),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteDispatch(MeatDispatch dispatch) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Dispatch?'),
        content: Text('Sigurado ka bang nais mong burahin ang dispatch record na ito sa ${dispatch.destinationBranchName} (${dispatch.itemsSummary})?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && dispatch.id.isNotEmpty) {
      await FirestoreService.deleteDispatch(dispatch.id);
    }
  }

  // --- FINANCIALS TAB ---------------------------------------------------

  Widget _buildFinancialsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFinancialOverview(),
        const SizedBox(height: 20),
        _buildProcurementSections(),
        const SizedBox(height: 20),
        _buildLaborOverheadCard(),
      ],
    );
  }

  Widget _buildFinancialOverview() {
    return Row(
      children: [
        Expanded(child: _financeKpi('Gross Revenue', '\u20b1${_period.grossRevenue.toStringAsFixed(0)}', AppColors.success)),
        const SizedBox(width: 10),
        Expanded(child: _financeKpi('Expenses', '\u20b1${_period.totalExpenses.toStringAsFixed(0)}', AppColors.error)),
        const SizedBox(width: 10),
        Expanded(child: _financeKpi('Net MAV', '\u20b1${_period.netMav.toStringAsFixed(0)}', AppColors.accent)),
      ],
    );
  }

  Widget _financeKpi(String label, String val, Color color) {
    return StaffCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildProcurementSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PROCUREMENT & INGREDIENTS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        for (final group in _period.procurementGroups) ...[
          _buildProcurementGroupCard(group),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildProcurementGroupCard(ProcurementGroup group) {
    return StaffCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(group.title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent, fontSize: 13))),
              Text('\u20b1${group.total.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const Divider(height: 20, color: AppColors.border),
          for (final item in group.items) _buildProcurementItemRow(item),
        ],
      ),
    );
  }

  Widget _buildProcurementItemRow(ProcurementItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => item.isPaid = !item.isPaid),
            child: Icon(
              item.isPaid ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
              size: 20,
              color: item.isPaid ? AppColors.success : AppColors.border,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _editProcurementItem(item),
              child: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
          GestureDetector(
            onTap: () => _editProcurementItem(item),
            child: Text('\u20b1${item.price.toStringAsFixed(1)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildLaborOverheadCard() {
    return StaffCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LABOR & STORE OVERHEAD', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.accent)),
          const SizedBox(height: 14),
          _overheadRow('Production Labor (Abby & Menes)', '\u20b1${_period.totalProductionLaborCost.toStringAsFixed(0)}'),
          _overheadRow('Store Overhead (${_period.workingDaysCount.toInt()} days)', '\u20b1${_period.accumulatedStoreCost.toStringAsFixed(0)}'),
          const Divider(height: 24, color: AppColors.border),
          _overheadRow('OVERALL STORE COST', '\u20b1${_period.accumulatedStoreCost.toStringAsFixed(0)}', isTotal: true),
        ],
      ),
    );
  }

  Widget _overheadRow(String label, String val, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600, fontSize: isTotal ? 14 : 12)),
          ),
          Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: isTotal ? 16 : 13, color: isTotal ? AppColors.accent : AppColors.textPrimary)),
        ],
      ),
    );
  }
}


