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
import '../admin_web_widgets/admin_pagination_bar.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 4, vsync: this, initialIndex: widget.initialTab.clamp(0, 3));

  StreamSubscription<List<KarneBatch>>? _batchesSub;
  StreamSubscription<List<BranchMeatStock>>? _meatStocksSub;
  StreamSubscription<List<MeatDispatch>>? _dispatchesSub;

  int _batchesPage = 0;
  int _stocksPage = 0;
  int _dispatchesPage = 0;
  static const int _pageSize = 5;

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
          child: Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: (_karneBatches.length - (_batchesPage * _pageSize)).clamp(0, _pageSize),
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final batchIndex = (_batchesPage * _pageSize) + index;
                    final batch = _karneBatches[batchIndex];
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
                                setState(() => _karneBatches[batchIndex] = updated);
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
              AdminPaginationBar(
                currentPage: _batchesPage,
                totalItems: _karneBatches.length,
                pageSize: _pageSize,
                onPageChanged: (p) => setState(() => _batchesPage = p),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBranchStockTab() {
    return Column(
      children: [
        // Informational header banner explaining automated allocation
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminWebColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.autorenew_rounded, color: AdminWebColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AUTOMATED BRANCH ALLOCATION',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AdminWebColors.textPrimary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Base: 250G Reg (20) · 300G Med (10) · B1T1 (10) · Mayo (40) · Styro (40) · Toyo (10). Automatic na nagre-reset tuwing 12:00 AM · Nadaragdagan kapag nag-deliver si Driver.',
                      style: TextStyle(fontSize: 11, color: AdminWebColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: (_branchMeatStocks.length - (_stocksPage * _pageSize)).clamp(0, _pageSize),
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final s = _branchMeatStocks[(_stocksPage * _pageSize) + index];
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
                                          '${s.totalRemainingPcs} / ${s.totalAllocatedPcs} MEAT PCS',
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AdminWebColors.accent.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AdminWebColors.accent.withValues(alpha: 0.2)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bolt_rounded, size: 12, color: AdminWebColors.accent),
                                    SizedBox(width: 4),
                                    Text(
                                      'AUTO-SYNC',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AdminWebColors.accent,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          // Row 1: Meat portions (250g Regular, 300g Medium, 400g B1T1)
                          Row(
                            children: [
                              Expanded(child: _meatVariantChip('250g Regular', '${s.regular250gRemaining} / ${s.regular250gTotal} pcs')),
                              const SizedBox(width: 6),
                              Expanded(child: _meatVariantChip('300g Medium', '${s.medium300gRemaining} / ${s.medium300gTotal} pcs')),
                              const SizedBox(width: 6),
                              Expanded(child: _meatVariantChip('400g B1T1', '${s.b1t1_400gRemaining} / ${s.b1t1_400gTotal} pcs')),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Row 2: Supplies (Mayo, Styro, Toyo)
                          Row(
                            children: [
                              Expanded(child: _meatVariantChip('Mayo', '${s.mayoRemaining} / ${s.mayoTotal} pcs')),
                              const SizedBox(width: 6),
                              Expanded(child: _meatVariantChip('Styro Box', '${s.styroRemaining} / ${s.styroTotal} pcs')),
                              const SizedBox(width: 6),
                              Expanded(child: _meatVariantChip('Toyo', '${s.toyoRemaining} / ${s.toyoTotal} pcs')),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              AdminPaginationBar(
                currentPage: _stocksPage,
                totalItems: _branchMeatStocks.length,
                pageSize: _pageSize,
                onPageChanged: (p) => setState(() => _stocksPage = p),
              ),
            ],
          ),
        ),
      ],
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
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AdminWebColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AdminWebColors.textPrimary,
            ),
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
              : Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: (_meatDispatches.length - (_dispatchesPage * _pageSize)).clamp(0, _pageSize),
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final dispatch = _meatDispatches[(_dispatchesPage * _pageSize) + index];
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
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: AdminWebColors.error, size: 20),
                                  tooltip: 'Delete Dispatch',
                                  onPressed: () => _confirmDeleteDispatch(dispatch),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    AdminPaginationBar(
                      currentPage: _dispatchesPage,
                      totalItems: _meatDispatches.length,
                      pageSize: _pageSize,
                      onPageChanged: (p) => setState(() => _dispatchesPage = p),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteDispatch(MeatDispatch dispatch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AdminWebColors.error),
            SizedBox(width: 8),
            Text('Delete Dispatch Record?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Sigurado ka bang nais mong burahin ang dispatch na ito sa ${dispatch.destinationBranchName} (${dispatch.itemsSummary})?',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: AdminWebColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminWebColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && dispatch.id.isNotEmpty) {
      await FirestoreService.deleteDispatch(dispatch.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nai-delete na ang dispatch record.'),
            backgroundColor: AdminWebColors.error,
          ),
        );
      }
    }
  }
}
