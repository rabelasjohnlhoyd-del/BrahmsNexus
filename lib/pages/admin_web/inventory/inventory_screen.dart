import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/branch.dart';
import '../../../models/branch_meat_inventory.dart';
import '../../../models/inventory_batch.dart';
import '../../../models/meat_dispatch.dart';
import '../../../services/firestore_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import 'record_transfer_screen.dart';
import 'karne_batch_detail_screen.dart';
import 'monthly_financials_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 4, vsync: this);

  StreamSubscription<List<KarneBatch>>? _batchesSub;
  StreamSubscription<List<BranchMeatStock>>? _meatStocksSub;
  StreamSubscription<List<MeatDispatch>>? _dispatchesSub;

  final List<KarneBatch> _karneBatches = [
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

  @override
  void initState() {
    super.initState();
    _updateShellActions();
    // Start listening to real-time Firestore updates IMMEDIATELY.
    FirestoreService.seedDefaultBatchesIfEmpty();
    FirestoreService.seedDefaultBranchMeatStocksIfEmpty();

    _batchesSub = FirestoreService.watchProductionBatches().listen((batches) {
      if (mounted) {
        setState(() {
          _karneBatches
            ..clear()
            ..addAll(batches);
        });
      }
    });

    _meatStocksSub = FirestoreService.watchBranchMeatStocks().listen((stocks) {
      if (mounted) setState(() => _branchMeatStocks = stocks);
    });

    _dispatchesSub = FirestoreService.watchMeatDispatches().listen((dispatches) {
      if (mounted) setState(() => _meatDispatches = dispatches);
    });
  }

  @override
  void dispose() {
    _batchesSub?.cancel();
    _meatStocksSub?.cancel();
    _dispatchesSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([]);
  }

  void _addNewBatch() {
    final nameCtrl = TextEditingController();
    final kilosCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Batch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'BATCH NAME',
                hintText: 'e.g. KARNE SHIPMENT JULY',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: kilosCtrl,
              decoration: const InputDecoration(
                labelText: 'TOTAL KILOS',
                suffixText: 'KG',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              final double? kilos = double.tryParse(kilosCtrl.text);
              if (nameCtrl.text.isEmpty || kilos == null) return;

              final messenger = ScaffoldMessenger.of(context);
              final newBatch = KarneBatch(
                id: 'kb_${DateTime.now().millisecondsSinceEpoch}',
                name: nameCtrl.text.toUpperCase(),
                totalKilos: kilos,
              );
              Navigator.pop(context);
              final success = await FirestoreService.saveProductionBatch(newBatch);
              if (mounted) {
                setState(() {
                  _karneBatches.removeWhere((b) => b.id == newBatch.id);
                  _karneBatches.insert(0, newBatch);
                });
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Batch "${newBatch.name}" was saved and synced!'
                          : 'Notice: Batch "${newBatch.name}" was saved locally.',
                    ),
                  ),
                );
              }
            },
            child: const Text('CREATE BATCH'),
          ),
        ],
      ),
    );
  }

  void _navigateToRecordTransfer() async {
    final result = await Navigator.of(context).push<MeatDispatch>(
      MaterialPageRoute(
        builder: (context) => const RecordTransferScreen(),
      ),
    );

    if (result != null) {
      // The real-time stream will pick up the change from Firestore automatically.
      // This local insert is just for immediate UI feedback.
      setState(() {
        _meatDispatches.insert(0, result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminWebColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Main Warehouse'),
              Tab(text: 'Branch Allocation'),
              Tab(text: 'Dispatch Logs'),
              Tab(text: 'Monthly Financials'),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWarehouseTab(),
                _buildBranchStockTab(),
                _buildTransferLogsTab(),
                MonthlyFinancialsScreen(karneBatches: _karneBatches),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseTab() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _addNewBatch,
            icon: const Icon(Icons.add),
            label: const Text('ADD NEW BATCH / ITEM'),
            style: ElevatedButton.styleFrom(backgroundColor: AdminWebColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.all(20)),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: _karneBatches.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final batch = _karneBatches[index];
              return GlassCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => KarneBatchDetailScreen(
                        batch: batch,
                        onBatchChanged: (updated) {
                          FirestoreService.saveProductionBatch(updated);
                          setState(() => _karneBatches[index] = updated);
                        },
                      ),
                    ),
                  ),
                  leading: const CircleAvatar(backgroundColor: AdminWebColors.accent, child: Icon(Icons.inventory_2, color: Colors.white)),
                  title: Text(batch.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Row(
                    children: [
                      Text('Status: '),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (batch.remainingKilos > 0 ? AdminWebColors.success : AdminWebColors.error).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          batch.remainingKilos > 0 ? "ACTIVE" : "DONE",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: batch.remainingKilos > 0 ? AdminWebColors.success : AdminWebColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${batch.remainingKilos.toStringAsFixed(1)} KG LEFT', style: const TextStyle(fontWeight: FontWeight.w900, color: AdminWebColors.accent)),
                      Text('Total: ${batch.totalKilos} KG', style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBranchStockTab() {
    return ListView.separated(
      itemCount: _branchMeatStocks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final s = _branchMeatStocks[index];
        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: (s.isRunningLow
                            ? AdminWebColors.error
                            : AdminWebColors.accent)
                        .withValues(alpha: 0.1),
                    child: Icon(
                      Icons.store_rounded,
                      color: s.isRunningLow
                          ? AdminWebColors.error
                          : AdminWebColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.branchName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${s.totalRemainingPcs} / ${s.totalAllocatedPcs} PCS',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AdminWebColors.accent,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '(Natitira / Total)',
                              style: TextStyle(fontSize: 11, color: AdminWebColors.textSecondary),
                            ),
                            if (s.isRunningLow) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AdminWebColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'LOW STOCK',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: AdminWebColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _adjustBranchAllocation(index),
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('ADJUST'),
                    style: TextButton.styleFrom(foregroundColor: AdminWebColors.accent),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _meatVariantChip('250g Regular', '${s.regular250gRemaining} / ${s.regular250gTotal} pcs')),
                  const SizedBox(width: 6),
                  Expanded(child: _meatVariantChip('300g Medium', '${s.medium300gRemaining} / ${s.medium300gTotal} pcs')),
                  const SizedBox(width: 6),
                  Expanded(child: _meatVariantChip('400g B1T1', '${s.b1t1_400gRemaining} / ${s.b1t1_400gTotal} pcs')),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AdminWebColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AdminWebColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminWebColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AdminWebColors.textPrimary)),
        ],
      ),
    );
  }

  void _adjustBranchAllocation(int index) {
    final stock = _branchMeatStocks[index];
    final regTotalCtrl = TextEditingController(text: stock.regular250gTotal.toString());
    final regRemCtrl = TextEditingController(text: stock.regular250gRemaining.toString());
    final medTotalCtrl = TextEditingController(text: stock.medium300gTotal.toString());
    final medRemCtrl = TextEditingController(text: stock.medium300gRemaining.toString());
    final b1t1TotalCtrl = TextEditingController(text: stock.b1t1_400gTotal.toString());
    final b1t1RemCtrl = TextEditingController(text: stock.b1t1_400gRemaining.toString());

    void disposeControllers() {
      regTotalCtrl.dispose(); regRemCtrl.dispose();
      medTotalCtrl.dispose(); medRemCtrl.dispose();
      b1t1TotalCtrl.dispose(); b1t1RemCtrl.dispose();
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adjust: ${stock.branchName}', style: const TextStyle(fontSize: 14)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('250g Regular', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: TextField(controller: regTotalCtrl, decoration: const InputDecoration(labelText: 'Total Pcs'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: regRemCtrl, decoration: const InputDecoration(labelText: 'Natitira'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 14),
              const Text('300g Medium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: TextField(controller: medTotalCtrl, decoration: const InputDecoration(labelText: 'Total Pcs'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: medRemCtrl, decoration: const InputDecoration(labelText: 'Natitira'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 14),
              const Text('400g B1T1', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: TextField(controller: b1t1TotalCtrl, decoration: const InputDecoration(labelText: 'Total Pcs'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: b1t1RemCtrl, decoration: const InputDecoration(labelText: 'Natitira'), keyboardType: TextInputType.number)),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () { disposeControllers(); Navigator.pop(ctx); },
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = stock.copyWith(
                regular250gTotal: int.tryParse(regTotalCtrl.text) ?? stock.regular250gTotal,
                regular250gRemaining: int.tryParse(regRemCtrl.text) ?? stock.regular250gRemaining,
                medium300gTotal: int.tryParse(medTotalCtrl.text) ?? stock.medium300gTotal,
                medium300gRemaining: int.tryParse(medRemCtrl.text) ?? stock.medium300gRemaining,
                b1t1_400gTotal: int.tryParse(b1t1TotalCtrl.text) ?? stock.b1t1_400gTotal,
                b1t1_400gRemaining: int.tryParse(b1t1RemCtrl.text) ?? stock.b1t1_400gRemaining,
                date: DateTime.now(),
              );
              await FirestoreService.saveBranchMeatStock(updated);
              disposeControllers();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminWebColors.accent, foregroundColor: Colors.white),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferLogsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _navigateToRecordTransfer,
            icon: const Icon(Icons.local_shipping_rounded),
            label: const Text('RECORD NEW DISPATCH'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminWebColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(20),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _meatDispatches.isEmpty
              ? const Center(
                  child: Text(
                    'No stock dispatches recorded yet.',
                    style: TextStyle(color: AdminWebColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  itemCount: _meatDispatches.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final dispatch = _meatDispatches[index];
                    final isDelivered = dispatch.isDelivered;
                    return GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (isDelivered ? AdminWebColors.success : AdminWebColors.accent).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.warehouse_rounded,
                              color: isDelivered ? AdminWebColors.success : AdminWebColors.accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Warehouse → ${dispatch.destinationBranchName}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AdminWebColors.textPrimary),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  dispatch.itemsSummary,
                                  style: const TextStyle(fontSize: 12, color: AdminWebColors.textPrimary, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${dispatch.createdAt.month}/${dispatch.createdAt.day} · ${dispatch.createdAt.hour.toString().padLeft(2, '0')}:${dispatch.createdAt.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 11, color: AdminWebColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${dispatch.totalPcs} pcs',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AdminWebColors.accent),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (isDelivered ? AdminWebColors.success : AdminWebColors.warning).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isDelivered ? 'DELIVERED' : 'PENDING',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: isDelivered ? AdminWebColors.success : AdminWebColors.warning,
                                  ),
                                ),
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
}
