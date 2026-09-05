import 'package:flutter/material.dart';
import '../../../models/branch.dart';
import '../../../models/inventory_item.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/primary_button.dart';

/// Admin manages inventory here: main warehouse total stock, daily
/// per-branch allocation, remaining stock per branch, and inter-branch
/// transfer logs (maps to the Inventory Management flowchart).
///
/// NOTE: Mock data for now — once Supabase/Firebase are wired up,
/// warehouse totals and allocations (rarely-changing structure) fit
/// Supabase, while daily remaining-stock submissions (frequently
/// changing) fit Firebase.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);

  WarehouseStock _warehouse = WarehouseStock(
    date: DateTime.now(),
    totalKg: 1000,
    allocatedKg: 78,
  );

  final List<BranchStock> _branchStocks = [
    BranchStock(
      branchId: 'br6',
      branchName: 'Brgy. Dayap, Calauan',
      date: DateTime.now(),
      allocatedKg: 20,
      remainingKg: 14,
    ),
    BranchStock(
      branchId: 'br1',
      branchName: 'Brgy. Gatid, Sta. Cruz',
      date: DateTime.now(),
      allocatedKg: 25,
      remainingKg: 3,
    ),
    BranchStock(
      branchId: 'br3',
      branchName: 'Brgy. Sta. Clara Sur, Pila',
      date: DateTime.now(),
      allocatedKg: 18,
      remainingKg: 18,
    ),
    BranchStock(
      branchId: 'br2',
      branchName: 'Brgy. Labuin, Pila',
      date: DateTime.now(),
      allocatedKg: 15,
      remainingKg: 1,
    ),
  ];

  final List<StockTransferLog> _transferLogs = [
    StockTransferLog(
      id: 'tl1',
      sourceBranchId: 'br1',
      sourceBranchName: 'Brgy. Gatid, Sta. Cruz',
      destinationBranchId: 'br2',
      destinationBranchName: 'Brgy. Labuin, Pila',
      quantityKg: 5,
      dateTime: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showSetTotalStockDialog() async {
    final controller =
        TextEditingController(text: _warehouse.totalKg.toStringAsFixed(0));
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set Main Warehouse Total Stock'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Total Stock (kg)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null) {
                setState(() {
                  _warehouse = WarehouseStock(
                    date: _warehouse.date,
                    totalKg: value,
                    allocatedKg: _warehouse.allocatedKg,
                  );
                });
              }
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAllocateDialog(BranchStock stock) async {
    final controller =
        TextEditingController(text: stock.allocatedKg.toStringAsFixed(0));
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Allocate Stock — ${stock.branchName}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Allocated (kg)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null) {
                setState(() {
                  final index = _branchStocks
                      .indexWhere((b) => b.branchId == stock.branchId);
                  final oldAllocated = _branchStocks[index].allocatedKg;
                  _branchStocks[index] = BranchStock(
                    branchId: stock.branchId,
                    branchName: stock.branchName,
                    date: stock.date,
                    allocatedKg: value,
                    remainingKg: stock.remainingKg,
                  );
                  _warehouse = WarehouseStock(
                    date: _warehouse.date,
                    totalKg: _warehouse.totalKg,
                    allocatedKg:
                        _warehouse.allocatedKg - oldAllocated + value,
                  );
                });
              }
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTransferDialog() async {
    String sourceId = kSampleBranches.first.id;
    String destId = kSampleBranches[1].id;
    final qtyController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Record Inter-Branch Transfer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: sourceId,
                decoration: const InputDecoration(labelText: 'From Branch'),
                items: kSampleBranches
                    .map((b) =>
                        DropdownMenuItem(value: b.id, child: Text(b.fullName)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => sourceId = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: destId,
                decoration: const InputDecoration(labelText: 'To Branch'),
                items: kSampleBranches
                    .map((b) =>
                        DropdownMenuItem(value: b.id, child: Text(b.fullName)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => destId = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity (kg)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(qtyController.text);
                if (qty == null || sourceId == destId) return;
                final source =
                    kSampleBranches.firstWhere((b) => b.id == sourceId);
                final dest =
                    kSampleBranches.firstWhere((b) => b.id == destId);
                setState(() {
                  _transferLogs.insert(
                    0,
                    StockTransferLog(
                      id: 'tl${_transferLogs.length + 1}',
                      sourceBranchId: source.id,
                      sourceBranchName: source.fullName,
                      destinationBranchId: dest.id,
                      destinationBranchName: dest.fullName,
                      quantityKg: qty,
                      dateTime: DateTime.now(),
                    ),
                  );
                });
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save Transfer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inventory',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.accent,
            tabs: const [
              Tab(text: 'Warehouse'),
              Tab(text: 'Branch Stock'),
              Tab(text: 'Transfer Logs'),
            ],
          ),
          const SizedBox(height: 16),
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
    return SingleChildScrollView(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Main Warehouse Stock',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _statRow('Total Stock', '${_warehouse.totalKg.toStringAsFixed(0)} kg'),
              _statRow(
                  'Allocated to Branches',
                  '${_warehouse.allocatedKg.toStringAsFixed(0)} kg'),
              _statRow(
                  'Unallocated',
                  '${_warehouse.unallocatedKg.toStringAsFixed(0)} kg'),
              const SizedBox(height: 20),
              SizedBox(
                width: 240,
                child: PrimaryButton(
                  label: 'SET TOTAL STOCK',
                  icon: Icons.edit_rounded,
                  onPressed: _showSetTotalStockDialog,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchStockTab() {
    return ListView.separated(
      itemCount: _branchStocks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final stock = _branchStocks[index];
        final ratio = stock.allocatedKg == 0
            ? 0.0
            : (stock.remainingKg / stock.allocatedKg).clamp(0, 1);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        stock.branchName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (stock.isRunningLow)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Running Low',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () => _showAllocateDialog(stock),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Allocate'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio.toDouble(),
                    minHeight: 8,
                    backgroundColor: AppColors.pastelBrown.withValues(alpha: 0.25),
                    color: stock.isRunningLow
                        ? AppColors.error
                        : AppColors.accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${stock.remainingKg.toStringAsFixed(1)} kg left of '
                  '${stock.allocatedKg.toStringAsFixed(1)} kg allocated',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransferLogsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _showAddTransferDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Record Transfer'),
          ),
        ),
        Expanded(
          child: _transferLogs.isEmpty
              ? const Center(
                  child: Text(
                    'Wala pang inter-branch transfer.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  itemCount: _transferLogs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final log = _transferLogs[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.local_shipping_outlined,
                            color: AppColors.accent),
                        title: Text(
                          '${log.sourceBranchName} → '
                          '${log.destinationBranchName}',
                        ),
                        subtitle: Text(
                          '${log.dateTime.month}/${log.dateTime.day}/'
                          '${log.dateTime.year} · '
                          '${log.dateTime.hour.toString().padLeft(2, '0')}:'
                          '${log.dateTime.minute.toString().padLeft(2, '0')}',
                        ),
                        trailing: Text(
                          '${log.quantityKg.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
