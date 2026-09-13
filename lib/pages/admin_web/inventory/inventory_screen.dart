import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/inventory_item.dart';
import '../../../models/inventory_batch.dart';
import '../../../services/firestore_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import 'adjust_allocation_screen.dart';
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

  final List<KarneBatch> _karneBatches = [
    KarneBatch(
      id: 'kb1',
      name: 'Batch Danish Crown - July',
      totalKilos: 1000,
    ),
  ];

  final List<BranchStock> _branchStocks = [
    BranchStock(branchId: 'br1', branchName: 'Brgy. Gatid, Sta. Cruz', date: DateTime.now(), allocatedKg: 25, remainingKg: 3),
    BranchStock(branchId: 'br3', branchName: 'Brgy. Sta. Clara Sur, Pila', date: DateTime.now(), allocatedKg: 18, remainingKg: 18),
  ];

  final List<StockTransferLog> _transferLogs = [];

  @override
  void initState() {
    super.initState();
    _updateShellActions();
    _batchesSub = FirestoreService.watchProductionBatches().listen((batches) {
      if (mounted) {
        setState(() {
          _karneBatches
            ..clear()
            ..addAll(batches);
        });
      }
    });
  }

  @override
  void dispose() {
    _batchesSub?.cancel();
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
            onPressed: () {
              final double? kilos = double.tryParse(kilosCtrl.text);
              if (nameCtrl.text.isEmpty || kilos == null) return;

              final newBatch = KarneBatch(
                id: 'kb_${DateTime.now().millisecondsSinceEpoch}',
                name: nameCtrl.text.toUpperCase(),
                totalKilos: kilos,
              );
              FirestoreService.saveProductionBatch(newBatch);
              setState(() {
                _karneBatches.insert(0, newBatch);
              });
              Navigator.pop(context);
            },
            child: const Text('CREATE BATCH'),
          ),
        ],
      ),
    );
  }

  void _navigateToRecordTransfer() async {
    final result = await Navigator.of(context).push<StockTransferLog>(
      MaterialPageRoute(
        builder: (context) => const RecordTransferScreen(),
      ),
    );

    if (result != null) {
      setState(() {
        _transferLogs.insert(0, result);
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
    if (_branchStocks.isEmpty) {
      return const Center(
        child: Text(
          'No branch allocations recorded yet.',
          style: TextStyle(color: AdminWebColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      itemCount: _branchStocks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final stock = _branchStocks[index];
        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: (stock.isRunningLow
                        ? AdminWebColors.error
                        : AdminWebColors.accent)
                    .withValues(alpha: 0.1),
                child: Icon(
                  Icons.store_rounded,
                  color: stock.isRunningLow
                      ? AdminWebColors.error
                      : AdminWebColors.accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.branchName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${stock.remainingKg.toStringAsFixed(1)} / ${stock.allocatedKg.toStringAsFixed(1)} KG remaining',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AdminWebColors.textSecondary,
                          ),
                        ),
                        if (stock.isRunningLow) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
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
                onPressed: () => _adjustAllocation(index),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('ADJUST'),
                style: TextButton.styleFrom(foregroundColor: AdminWebColors.accent),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _adjustAllocation(int index) async {
    final stock = _branchStocks[index];
    final result = await Navigator.of(context).push<double>(
      MaterialPageRoute(
        builder: (context) => AdjustAllocationScreen(branchStock: stock),
      ),
    );

    if (result != null) {
      setState(() {
        _branchStocks[index] = stock.copyWith(allocatedKg: result);
      });
    }
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
          child: _transferLogs.isEmpty
              ? const Center(
                  child: Text(
                    'No stock dispatches recorded yet.',
                    style: TextStyle(color: AdminWebColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  itemCount: _transferLogs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final log = _transferLogs[index];
                    return GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AdminWebColors.accent.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.warehouse_rounded, color: AdminWebColors.accent, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Warehouse → ${log.destinationBranchName}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AdminWebColors.textPrimary),
                                ),
                                Text(
                                  '${log.dateTime.month}/${log.dateTime.day}/${log.dateTime.year} · ${log.dateTime.hour}:${log.dateTime.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${log.quantityKg.toStringAsFixed(1)} KG',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AdminWebColors.accent),
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



