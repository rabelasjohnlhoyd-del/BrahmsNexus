import 'package:flutter/material.dart';
import '../../../models/inventory_item.dart';
import '../../../models/inventory_batch.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import 'record_transfer_screen.dart';
import 'karne_batch_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);

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

              setState(() {
                _karneBatches.insert(0, KarneBatch(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text.toUpperCase(),
                  totalKilos: kilos,
                ));
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
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final batch = _karneBatches[index];
              return GlassCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => KarneBatchDetailScreen(batch: batch))),
                  leading: const CircleAvatar(backgroundColor: AdminWebColors.accent, child: Icon(Icons.inventory_2, color: Colors.white)),
                  title: Text(batch.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Status: ${batch.remainingKilos > 0 ? "Active" : "Finished"}'),
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

  Widget _buildBranchStockTab() { return const Center(child: Text('Branch Allocation Content')); }

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
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
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
