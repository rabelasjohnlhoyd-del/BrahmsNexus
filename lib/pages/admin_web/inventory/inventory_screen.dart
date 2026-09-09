import 'package:flutter/material.dart';
import '../../../models/branch.dart';
import '../../../models/inventory_item.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import 'update_stock_screen.dart';
import 'adjust_allocation_screen.dart';
import 'record_transfer_screen.dart';

/// Admin manages inventory here: main warehouse total stock, daily
/// per-branch allocation, remaining stock per branch, and inter-branch
/// transfer logs (maps to the Inventory Management flowchart).
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
  void initState() {
    super.initState();
    _tabController.addListener(_handleTabSelection);
    _updateShellActions();
  }

  @override
  void didUpdateWidget(InventoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      _updateShellActions();
    }
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setTitle(null);
    if (_tabController.index == 0) {
      shell?.setActions([
        ElevatedButton.icon(
          onPressed: _navigateToUpdateStock,
          icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
          label: const Text('UPDATE TOTAL STOCK'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            elevation: 0,
          ),
        ),
      ]);
    } else if (_tabController.index == 2) {
      shell?.setActions([
        ElevatedButton.icon(
          onPressed: _navigateToRecordTransfer,
          icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
          label: const Text('RECORD TRANSFER'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            elevation: 0,
          ),
        ),
      ]);
    } else {
      shell?.setActions([]);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToUpdateStock() async {
    final result = await Navigator.of(context).push<double>(
      MaterialPageRoute(
        builder: (context) => UpdateStockScreen(currentStock: _warehouse.totalKg),
      ),
    );

    if (result != null) {
      setState(() {
        _warehouse = WarehouseStock(
          date: _warehouse.date,
          totalKg: result,
          allocatedKg: _warehouse.allocatedKg,
        );
      });
      _updateShellActions();
    }
  }

  void _navigateToAdjustAllocation(BranchStock stock) async {
    final result = await Navigator.of(context).push<double>(
      MaterialPageRoute(
        builder: (context) => AdjustAllocationScreen(branchStock: stock),
      ),
    );

    if (result != null) {
      setState(() {
        final index = _branchStocks.indexWhere((b) => b.branchId == stock.branchId);
        final oldAllocated = _branchStocks[index].allocatedKg;
        _branchStocks[index] = BranchStock(
          branchId: stock.branchId,
          branchName: stock.branchName,
          date: stock.date,
          allocatedKg: result,
          remainingKg: stock.remainingKg,
        );
        _warehouse = WarehouseStock(
          date: _warehouse.date,
          totalKg: _warehouse.totalKg,
          allocatedKg: _warehouse.allocatedKg - oldAllocated + result,
        );
      });
      _updateShellActions();
    }
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
      _updateShellActions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminWebColors.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Main Warehouse'),
                Tab(text: 'Branch Allocation'),
                Tab(text: 'Transfer Logs'),
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
      ),
    );
  }

  Widget _buildWarehouseTab() {
    return SingleChildScrollView(
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stock Summary',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: AdminWebColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 20),
            _statRow('Total Inventory Stock',
                '${_warehouse.totalKg.toStringAsFixed(0)} kg'),
            _statRow('Currently Allocated',
                '${_warehouse.allocatedKg.toStringAsFixed(0)} kg'),
            _statRow('Remaining Unallocated',
                '${_warehouse.unallocatedKg.toStringAsFixed(0)} kg'),
          ],
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
          Text(label,
              style: const TextStyle(color: AdminWebColors.textSecondary)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AdminWebColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchStockTab() {
    return ListView.separated(
      itemCount: _branchStocks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final stock = _branchStocks[index];
        final ratio = stock.allocatedKg == 0
            ? 0.0
            : (stock.remainingKg / stock.allocatedKg).clamp(0, 1);

        return GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      stock.branchName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AdminWebColors.textPrimary,
                      ),
                    ),
                  ),
                  if (stock.isRunningLow)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AdminWebColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AdminWebColors.error.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 14, color: AdminWebColors.error),
                          SizedBox(width: 4),
                          Text(
                            'LOW STOCK',
                            style: TextStyle(
                              color: AdminWebColors.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio.toDouble(),
                  minHeight: 10,
                  backgroundColor: AdminWebColors.border.withValues(alpha: 0.5),
                  color: stock.isRunningLow
                      ? AdminWebColors.error
                      : AdminWebColors.accent,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${stock.remainingKg.toStringAsFixed(1)} kg remaining / ${stock.allocatedKg.toStringAsFixed(1)} kg total',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AdminWebColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _navigateToAdjustAllocation(stock),
                    icon: const Icon(Icons.add_chart_rounded, size: 16),
                    label: const Text('ADJUST ALLOCATION'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
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

  Widget _buildTransferLogsTab() {
    if (_transferLogs.isEmpty) {
      return const Center(
        child: Text(
          'No inter-branch transfers recorded yet.',
          style: TextStyle(color: AdminWebColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
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
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: AdminWebColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${log.sourceBranchName} → ${log.destinationBranchName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AdminWebColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${log.dateTime.month}/${log.dateTime.day}/${log.dateTime.year} at ${log.dateTime.hour.toString().padLeft(2, '0')}:${log.dateTime.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminWebColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${log.quantityKg.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AdminWebColors.accent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
