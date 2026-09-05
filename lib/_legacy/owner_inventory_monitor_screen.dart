import 'package:flutter/material.dart';
import '../models/inventory_item.dart';
import '../theme/app_theme.dart';

/// Owner monitors remaining branch stock here — sorted so the branches
/// running low surface first, since those are the ones that may need
/// a Driver stock-transfer stop.
///
/// NOTE: Mock data for now — once Supabase is wired up, this reads
/// each branch's latest [BranchStock] submission from Staff.
class InventoryMonitorScreen extends StatefulWidget {
  const InventoryMonitorScreen({super.key});

  @override
  State<InventoryMonitorScreen> createState() =>
      _InventoryMonitorScreenState();
}

class _InventoryMonitorScreenState extends State<InventoryMonitorScreen> {
  final List<BranchStock> _stocks = [
    BranchStock(
      branchId: 'br1',
      branchName: 'Dayap, Calauan',
      date: DateTime.now(),
      allocatedKg: 20,
      remainingKg: 14,
    ),
    BranchStock(
      branchId: 'br2',
      branchName: 'Sta. Cruz',
      date: DateTime.now(),
      allocatedKg: 25,
      remainingKg: 3,
    ),
    BranchStock(
      branchId: 'br3',
      branchName: 'Pila',
      date: DateTime.now(),
      allocatedKg: 18,
      remainingKg: 18,
    ),
    BranchStock(
      branchId: 'br4',
      branchName: 'Labuin',
      date: DateTime.now(),
      allocatedKg: 15,
      remainingKg: 1,
    ),
  ];

  bool _lowStockFirst = true;

  List<BranchStock> get _sortedStocks {
    final list = [..._stocks];
    list.sort((a, b) {
      if (_lowStockFirst) {
        final aRatio = a.allocatedKg == 0 ? 0 : a.remainingKg / a.allocatedKg;
        final bRatio = b.allocatedKg == 0 ? 0 : b.remainingKg / b.allocatedKg;
        return aRatio.compareTo(bRatio);
      }
      return a.branchName.compareTo(b.branchName);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Inventory')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Sorted by lowest stock first',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Switch(
                    value: _lowStockFirst,
                    onChanged: (v) => setState(() => _lowStockFirst = v),
                    activeThumbColor: AppColors.accent,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _sortedStocks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final stock = _sortedStocks[index];
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
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.error
                                        .withValues(alpha: 0.15),
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
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: ratio.toDouble(),
                              minHeight: 8,
                              backgroundColor:
                                  AppColors.pastelBrown.withValues(alpha: 0.25),
                              color: stock.isRunningLow
                                  ? AppColors.error
                                  : AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${stock.remainingKg.toStringAsFixed(1)} kg left '
                            'of ${stock.allocatedKg.toStringAsFixed(1)} kg '
                            'allocated',
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
