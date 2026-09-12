import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider;
import '../../models/branch.dart';
import '../../models/financial_period.dart';
import '../../models/inventory_batch.dart';
import '../../models/inventory_item.dart';
import '../../models/procurement_list.dart';
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
/// even though each still keeps its own in-memory mock data until the
/// backend phase (no shared storage between web and mobile yet).
class OwnerInventoryScreen extends StatefulWidget {
  const OwnerInventoryScreen({super.key});

  @override
  State<OwnerInventoryScreen> createState() => _OwnerInventoryScreenState();
}

class _OwnerInventoryScreenState extends State<OwnerInventoryScreen> {
  int _section = 0; // 0 = Warehouse, 1 = Branches, 2 = Dispatch, 3 = Finance

  final List<KarneBatch> _batches = [
    KarneBatch(
      id: 'kb1',
      name: 'Batch Danish Crown - July',
      totalKilos: 1000,
    ),
  ];

  final List<BranchStock> _branchStocks = [
    BranchStock(
      branchId: 'br1',
      branchName: 'Brgy. Gatid, Sta. Cruz',
      date: DateTime.now(),
      allocatedKg: 25,
      remainingKg: 3,
    ),
    BranchStock(
      branchId: 'br2',
      branchName: 'Brgy. Labuin, Pila',
      date: DateTime.now(),
      allocatedKg: 15,
      remainingKg: 1,
    ),
    BranchStock(
      branchId: 'br3',
      branchName: 'Brgy. Sta. Clara Sur, Pila',
      date: DateTime.now(),
      allocatedKg: 18,
      remainingKg: 18,
    ),
  ];

  final List<StockTransferLog> _transferLogs = [];

  late FinancialPeriod _period;

  @override
  void initState() {
    super.initState();
    _initializeFinancials();
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
                setState(() {
                  _batches.insert(0, KarneBatch(
                    id: 'kb${DateTime.now().millisecondsSinceEpoch}',
                    name: nameController.text,
                    totalKilos: k,
                  ));
                });
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
                setState(() {
                  final idx = _batches.indexWhere((b) => b.id == batch.id);
                  final newSessions = List<KarneSession>.from(_batches[idx].sessions)
                    ..add(KarneSession(
                      date: DateTime.now(),
                      brand: brandCtrl.text,
                      resekoApplied: r,
                      boilingMinutes: m,
                      kilosCooked: k,
                    ));
                  _batches[idx] = _batches[idx].copyWith(sessions: newSessions);
                });
                _refreshFinancialsFromBatches();
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
                setState(() {
                  final bIdx = _batches.indexWhere((b) => b.id == batch.id);
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
                  _batches[bIdx] = _batches[bIdx].copyWith(sessions: newSessions);
                });
                _refreshFinancialsFromBatches();
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
              setState(() {
                final bIdx = _batches.indexWhere((b) => b.id == batch.id);
                final newSessions = List<KarneSession>.from(_batches[bIdx].sessions)
                  ..removeAt(sessionIndex);
                _batches[bIdx] = _batches[bIdx].copyWith(sessions: newSessions);
              });
              _refreshFinancialsFromBatches();
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddDispatchDialog() {
    final qtyCtrl = TextEditingController();
    int destIdx = 0;

    showCupertinoDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => CupertinoAlertDialog(
          title: const Text('Record Dispatch'),
          content: Column(
            children: [
              const SizedBox(height: 12),
              const Text('Source: Main Warehouse', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              CupertinoButton(
                child: Text('To: ${kSampleBranches[destIdx].name}'),
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
              CupertinoTextField(controller: qtyCtrl, placeholder: 'Qty (KG)', keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            CupertinoDialogAction(
              onPressed: () {
                final q = double.tryParse(qtyCtrl.text);
                if (q != null) {
                  setState(() {
                    _transferLogs.insert(0, StockTransferLog(
                      id: 'tl${_transferLogs.length + 1}',
                      sourceBranchId: 'warehouse',
                      sourceBranchName: 'Main Warehouse',
                      destinationBranchId: kSampleBranches[destIdx].id,
                      destinationBranchName: kSampleBranches[destIdx].fullName,
                      quantityKg: q,
                      dateTime: DateTime.now(),
                    ));
                  });
                }
                Navigator.pop(ctx);
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
      itemCount: _branchStocks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final s = _branchStocks[i];
        return StaffCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.branchName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${s.remainingKg} / ${s.allocatedKg} KG',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
              // Explicit labeled button, matching Admin Web's "ADJUST"
              // button — not a whole-card tap, since Cupertino gives no
              // press/ripple feedback and made the old version feel
              // broken even though it worked.
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        );
      },
    );
  }

  /// Same capability as Admin Web's "Adjust Allocation" screen — lets
  /// the Owner update a branch's allocated kilos straight from the
  /// Branches tab instead of it being view-only.
  void _adjustBranchAllocation(int index) {
    final stock = _branchStocks[index];
    final allocationCtrl = TextEditingController(
      text: stock.allocatedKg.toStringAsFixed(0),
    );

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Adjust Allocation'),
        content: Column(
          children: [
            const SizedBox(height: 4),
            Text(stock.branchName, style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: allocationCtrl,
              placeholder: 'Allocated Stock (KG)',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          CupertinoDialogAction(
            onPressed: () {
              final value = double.tryParse(allocationCtrl.text);
              if (value != null) {
                setState(() {
                  _branchStocks[index] = stock.copyWith(allocatedKg: value);
                });
              }
              Navigator.pop(ctx);
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
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _transferLogs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final log = _transferLogs[i];
              return StaffCard(
                child: Text('Warehouse -> ${log.destinationBranchName}: ${log.quantityKg}kg'),
              );
            },
          ),
        ),
      ],
    );
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


