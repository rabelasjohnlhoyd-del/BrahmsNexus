import 'package:flutter/cupertino.dart';
import '../../models/branch.dart';
import '../../models/inventory_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';

/// Inventory tab — Owner monitors and manages main-warehouse stock,
/// per-branch allocation, and inter-branch transfers.
///
/// Migrated from the old `admin_web/inventory` screen. That screen
/// already used [kSampleBranches] as its single branch source (no
/// duplicate-data gap here, unlike Branch Assignments) — the one real
/// gap fixed along the way: the old mock only listed 4 of the 6
/// branches. Every branch name below is now looked up from
/// [kSampleBranches] directly instead of being retyped, so it can't
/// drift out of sync again.
///
/// NOTE: Mock data for now — once Supabase/Firebase are wired up,
/// warehouse totals/allocations (rarely-changing structure) fit
/// Supabase, while daily remaining-stock submissions (frequently
/// changing) fit Firebase.
class OwnerInventoryScreen extends StatefulWidget {
  const OwnerInventoryScreen({super.key});

  @override
  State<OwnerInventoryScreen> createState() => _OwnerInventoryScreenState();
}

class _OwnerInventoryScreenState extends State<OwnerInventoryScreen> {
  int _section = 0; // 0 = Warehouse, 1 = Branches, 2 = Transfers
  int _dateRangeFilter = 0; // 0 = Today, 1 = Yesterday, 2 = This Week

  static String _branchName(String id) =>
      kSampleBranches.firstWhere((b) => b.id == id).fullName;

  WarehouseStock _warehouse = WarehouseStock(
    date: DateTime.now(),
    totalKg: 1000,
    allocatedKg: 108,
  );

  final List<BranchStock> _branchStocks = [
    BranchStock(
      branchId: 'br1',
      branchName: _branchName('br1'),
      date: DateTime.now(),
      allocatedKg: 25,
      remainingKg: 3,
    ),
    BranchStock(
      branchId: 'br2',
      branchName: _branchName('br2'),
      date: DateTime.now(),
      allocatedKg: 15,
      remainingKg: 1,
    ),
    BranchStock(
      branchId: 'br3',
      branchName: _branchName('br3'),
      date: DateTime.now(),
      allocatedKg: 18,
      remainingKg: 18,
    ),
    BranchStock(
      branchId: 'br4',
      branchName: _branchName('br4'),
      date: DateTime.now(),
      allocatedKg: 15,
      remainingKg: 9,
    ),
    BranchStock(
      branchId: 'br5',
      branchName: _branchName('br5'),
      date: DateTime.now(),
      allocatedKg: 15,
      remainingKg: 5,
    ),
    BranchStock(
      branchId: 'br6',
      branchName: _branchName('br6'),
      date: DateTime.now(),
      allocatedKg: 20,
      remainingKg: 14,
    ),
  ];

  final List<StockTransferLog> _transferLogs = [
    StockTransferLog(
      id: 'tl1',
      sourceBranchId: 'br1',
      sourceBranchName: _branchName('br1'),
      destinationBranchId: 'br2',
      destinationBranchName: _branchName('br2'),
      quantityKg: 5,
      dateTime: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];

  /// Shared small numeric-input dialog (Set Total Stock / Allocate),
  /// styled like [StaffDialog] but with an editable field, which
  /// [StaffDialog] doesn't support.
  Future<double?> _showKgInputDialog({
    required String title,
    required String message,
    required String initialValue,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showCupertinoDialog<double>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            Text(message, style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              autofocus: true,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final value = double.tryParse(controller.text);
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSetTotalStockDialog() async {
    final value = await _showKgInputDialog(
      title: 'Total Warehouse Stock',
      message: 'Set the total stock (kg) at the main warehouse.',
      initialValue: _warehouse.totalKg.toStringAsFixed(0),
    );
    if (value == null) return;
    setState(() {
      _warehouse = WarehouseStock(
        date: _warehouse.date,
        totalKg: value,
        allocatedKg: _warehouse.allocatedKg,
      );
    });
  }

  Future<void> _showAllocateDialog(BranchStock stock) async {
    final value = await _showKgInputDialog(
      title: stock.branchName,
      message: 'Set the stock (kg) allocated to this branch today.',
      initialValue: stock.allocatedKg.toStringAsFixed(0),
    );
    if (value == null) return;
    setState(() {
      final index =
          _branchStocks.indexWhere((b) => b.branchId == stock.branchId);
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
        allocatedKg: _warehouse.allocatedKg - oldAllocated + value,
      );
    });
  }

  Future<int> _pickBranchSheet({
    required String title,
    required int initialIndex,
  }) async {
    var tempIndex = initialIndex;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => Container(
        height: 260,
        color: CupertinoColors.white,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(popupContext).pop(),
                  child: const Text('Cancel'),
                ),
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                CupertinoButton(
                  onPressed: () => Navigator.of(popupContext).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 36,
                scrollController:
                    FixedExtentScrollController(initialItem: initialIndex),
                onSelectedItemChanged: (i) => tempIndex = i,
                children: kSampleBranches
                    .map((b) => Center(child: Text(b.fullName)))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
    return tempIndex;
  }

  Future<void> _showAddTransferDialog() async {
    var sourceIndex = 0;
    var destIndex = 1;
    final qtyController = TextEditingController();

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => CupertinoAlertDialog(
          title: const Text('Record Inter-Branch Transfer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  final picked = await _pickBranchSheet(
                    title: 'From Branch',
                    initialIndex: sourceIndex,
                  );
                  setDialogState(() => sourceIndex = picked);
                },
                child: Text(
                  'From: ${kSampleBranches[sourceIndex].fullName}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  final picked = await _pickBranchSheet(
                    title: 'To Branch',
                    initialIndex: destIndex,
                  );
                  setDialogState(() => destIndex = picked);
                },
                child: Text(
                  'To: ${kSampleBranches[destIndex].fullName}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: qtyController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                placeholder: 'Quantity (kg)',
                textAlign: TextAlign.center,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save Transfer'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final qty = double.tryParse(qtyController.text);
    if (qty == null || sourceIndex == destIndex) return;

    final source = kSampleBranches[sourceIndex];
    final dest = kSampleBranches[destIndex];
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
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Inventory',
        trailing: StaffTopActions(),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _section,
                  backgroundColor: AppColors.background,
                  thumbColor: AppColors.accent,
                  children: {
                    0: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Text(
                        'Warehouse',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _section == 0
                              ? CupertinoColors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    1: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Text(
                        'Branches',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _section == 1
                              ? CupertinoColors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    2: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Text(
                        'Transfers',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _section == 2
                              ? CupertinoColors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  },
                  onValueChanged: (value) {
                    if (value != null) setState(() => _section = value);
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _dateRangeFilter,
                  backgroundColor: AppColors.border.withValues(alpha: 0.15),
                  thumbColor: CupertinoColors.white,
                  children: {
                    0: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _dateRangeFilter == 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _dateRangeFilter == 0
                              ? AppColors.accentDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    1: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'Yesterday',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _dateRangeFilter == 1
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _dateRangeFilter == 1
                              ? AppColors.accentDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    2: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'This Week',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _dateRangeFilter == 2
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _dateRangeFilter == 2
                              ? AppColors.accentDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  },
                  onValueChanged: (v) {
                    if (v != null) setState(() => _dateRangeFilter = v);
                  },
                ),
              ),
            ),
            Expanded(
              child: switch (_section) {
                0 => _buildWarehouseTab(),
                1 => _buildBranchesTab(),
                _ => _buildTransfersTab(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        StaffCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StaffSectionHeader(
                label: 'Main Warehouse Stock',
                icon: CupertinoIcons.cube_box_fill,
              ),
              const SizedBox(height: 16),
              _statRow('Total Stock',
                  '${_warehouse.totalKg.toStringAsFixed(0)} kg'),
              _statRow('Allocated to Branches',
                  '${_warehouse.allocatedKg.toStringAsFixed(0)} kg'),
              _statRow('Unallocated',
                  '${_warehouse.unallocatedKg.toStringAsFixed(0)} kg'),
              const SizedBox(height: 16),
              StaffButton(
                label: 'Set Total Stock',
                icon: CupertinoIcons.pencil,
                onPressed: _showSetTotalStockDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchesTab() {
    final surplusBranch = _branchStocks.reduce((a, b) =>
        (a.remainingKg / a.allocatedKg) > (b.remainingKg / b.allocatedKg)
            ? a
            : b);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _branchStocks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final stock = _branchStocks[index];
        final ratio = stock.allocatedKg == 0
            ? 0.0
            : (stock.remainingKg / stock.allocatedKg).clamp(0, 1);

        return Column(
          children: [
            if (stock.isRunningLow && stock.branchId != surplusBranch.branchId)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildTransferSuggestion(stock, surplusBranch),
              ),
            StaffCard(
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
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Running Low',
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 8,
                      color: AppColors.border,
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: ratio.toDouble(),
                        child: Container(
                          color: stock.isRunningLow
                              ? AppColors.error
                              : AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${stock.remainingKg.toStringAsFixed(1)} kg left of '
                          '${stock.allocatedKg.toStringAsFixed(1)} kg',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: () => _showAllocateDialog(stock),
                        child: const Text(
                          'Allocate',
                          style: TextStyle(fontSize: 12.5, color: AppColors.accent),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransferSuggestion(BranchStock low, BranchStock surplus) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.lightbulb_fill,
              color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${surplus.branchName} has surplus — transfer here?',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: AppColors.warning,
            borderRadius: BorderRadius.circular(8),
            onPressed: () => _showAddTransferDialogWithPrefill(low, surplus),
            child: const Text(
              'Review',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: CupertinoColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTransferDialogWithPrefill(
      BranchStock low, BranchStock surplus) async {
    // For MVP, just open the regular dialog; prefills would require
    // refactoring _showAddTransferDialog to take params.
    _showAddTransferDialog();
  }

  Widget _buildTransfersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: StaffButton(
            label: 'Record Transfer',
            icon: CupertinoIcons.arrow_right_arrow_left,
            onPressed: _showAddTransferDialog,
          ),
        ),
        Expanded(
          child: _transferLogs.isEmpty
              ? const Center(
                  child: Text(
                    'No inter-branch transfers yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _transferLogs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final log = _transferLogs[index];
                    return StaffCard(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.arrow_right_arrow_left,
                              size: 16,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${log.sourceBranchName} → '
                                  '${log.destinationBranchName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${log.dateTime.month}/${log.dateTime.day}/'
                                  '${log.dateTime.year} · '
                                  '${log.dateTime.hour.toString().padLeft(2, '0')}:'
                                  '${log.dateTime.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${log.quantityKg.toStringAsFixed(1)} kg',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
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
