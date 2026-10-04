import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/branch.dart';
import '../../../models/branch_meat_inventory.dart';
import '../../../models/inventory_batch.dart';
import '../../../models/meat_dispatch.dart';
import '../../../models/supply_request.dart';
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
      TabController(length: 5, vsync: this, initialIndex: widget.initialTab.clamp(0, 4));

  StreamSubscription<List<KarneBatch>>? _batchesSub;
  StreamSubscription<List<BranchMeatStock>>? _meatStocksSub;
  StreamSubscription<List<MeatDispatch>>? _dispatchesSub;
  StreamSubscription<List<SupplyRequest>>? _supplyRequestsSub;

  int _batchesPage = 0;
  int _stocksPage = 0;
  int _dispatchesPage = 0;
  static const int _pageSize = 5;

  List<SupplyRequest> _supplyRequests = [];

  final List<KarneBatch> _karneBatches = [];

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

    _supplyRequestsSub = FirestoreService.watchSupplyRequests().listen((reqs) {
      if (mounted) setState(() => _supplyRequests = reqs);
    });
  }

  @override
  void dispose() {
    _batchesSub?.cancel();
    _meatStocksSub?.cancel();
    _dispatchesSub?.cancel();
    _supplyRequestsSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([
      ElevatedButton.icon(
        onPressed: _showDispatchLogsDialog,
        icon: const Icon(Icons.local_shipping_rounded, size: 16),
        label: const Text('DISPATCH LOGS'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminWebColors.accent.withValues(alpha: 0.1),
          foregroundColor: AdminWebColors.accent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ]);
  }

  void _addNewBatch() {
    DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    String formatBatchName(DateTime d) => 'KARNE BATCH - ${DateFormat('MMMM yyyy').format(d).toUpperCase()}';
    final nameCtrl = TextEditingController(text: formatBatchName(selectedMonth));
    final kilosCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final existingBatchForMonth = _karneBatches.where(
            (b) => b.date.year == selectedMonth.year && b.date.month == selectedMonth.month,
          ).firstOrNull;
          final bool monthAlreadyHasBatch = existingBatchForMonth != null;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.calendar_month_rounded, color: AdminWebColors.accent),
                SizedBox(width: 10),
                Text('Start New Monthly Batch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assign a monthly meat stock (good for 1 month). Cooking will be divided across sessions throughout the month:',
                    style: TextStyle(fontSize: 13, color: AdminWebColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AdminWebColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminWebColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range_rounded, size: 18, color: AdminWebColors.accent),
                        const SizedBox(width: 8),
                        const Text('MONTH:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, size: 20),
                          tooltip: 'Previous Month',
                          onPressed: () {
                            setDlgState(() {
                              selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
                              nameCtrl.text = formatBatchName(selectedMonth);
                            });
                          },
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AdminWebColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            DateFormat('MMMM yyyy').format(selectedMonth),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AdminWebColors.accent),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, size: 20),
                          tooltip: 'Next Month',
                          onPressed: () {
                            setDlgState(() {
                              selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
                              nameCtrl.text = formatBatchName(selectedMonth);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  if (monthAlreadyHasBatch) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminWebColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminWebColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AdminWebColors.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'A batch already exists for ${DateFormat('MMMM yyyy').format(selectedMonth)}!',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AdminWebColors.error),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Existing batch: "${existingBatchForMonth.name}". Only one batch is allowed per month as each batch covers 1 month.',
                                  style: const TextStyle(fontSize: 11, color: AdminWebColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'BATCH NAME (MONTHLY BATCH)',
                      hintText: 'e.g. KARNE BATCH - OCTOBER 2026',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: kilosCtrl,
                    decoration: InputDecoration(
                      labelText: 'TOTAL RAW MEAT (KILOS) - GOOD FOR 1 MONTH',
                      hintText: 'e.g. 1000.0',
                      suffixText: 'KG',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.scale_rounded, size: 18),
                      helperText: 'Total delivered meat kilos for the month of ${DateFormat('MMMM yyyy').format(selectedMonth)}.',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: monthAlreadyHasBatch ? Colors.grey : AdminWebColors.accent,
                  foregroundColor: Colors.white,
                ),
                onPressed: monthAlreadyHasBatch
                    ? null
                    : () async {
                        final double? kilos = double.tryParse(kilosCtrl.text.trim());
                        if (nameCtrl.text.trim().isEmpty || kilos == null || kilos <= 0) return;

                        final messenger = ScaffoldMessenger.of(context);
                        final batchId = 'kb_${selectedMonth.year}_${selectedMonth.month.toString().padLeft(2, '0')}';
                        final newBatch = KarneBatch(
                          id: batchId,
                          name: nameCtrl.text.trim().toUpperCase(),
                          date: selectedMonth,
                          totalKilos: kilos,
                          cookingStatus: 'pending',
                        );
                        Navigator.pop(ctx);
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
                                    ? 'Monthly batch "${newBatch.name}" ($kilos KG, good for 1 month) has been saved!'
                                    : 'Notice: Batch "${newBatch.name}" was saved locally.',
                              ),
                              backgroundColor: success ? AdminWebColors.success : null,
                            ),
                          );
                        }
                      },
                child: const Text('CREATE MONTHLY BATCH'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteBatch(KarneBatch batch) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AdminWebColors.error),
            SizedBox(width: 8),
            Text('Delete Batch?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the batch "${batch.name}"?\n\n'
          'This batch and all associated cooking sessions will be permanently deleted from the database.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminWebColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final success = await FirestoreService.deleteProductionBatch(batch.id);
              if (mounted) {
                setState(() {
                  _karneBatches.removeWhere((b) => b.id == batch.id);
                });
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Batch "${batch.name}" successfully deleted.'
                        : 'Error deleting batch.'),
                    backgroundColor: success ? AdminWebColors.success : AdminWebColors.error,
                  ),
                );
              }
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _clearAllOldBatches() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: AdminWebColors.error),
            SizedBox(width: 8),
            Text('Clear All Old Batches?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ALL old batches (${_karneBatches.length} batches) from the database?\n\n'
          'This will remove previous test batches and reset to the monthly batch system.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminWebColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final count = await FirestoreService.clearAllProductionBatches();
              if (mounted) {
                setState(() {
                  _karneBatches.clear();
                  _batchesPage = 0;
                });
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Successfully deleted $count old batches from the database.'),
                    backgroundColor: AdminWebColors.success,
                  ),
                );
              }
            },
            child: const Text('DELETE ALL OLD'),
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
    final pendingRequestsCount = _supplyRequests.where((r) => r.isPending).length;

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
            tabs: [
              const Tab(text: 'Main Warehouse'),
              const Tab(text: 'Branch Allocation'),
              const Tab(text: 'Transfer Logs'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Supply Requests'),
                    if (pendingRequestsCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AdminWebColors.warning,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$pendingRequestsCount',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'Monthly Financials'),
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
                _buildSupplyRequestsTab(),
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

        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 650;

            final clearBtn = _karneBatches.isNotEmpty
                ? OutlinedButton.icon(
                    onPressed: _clearAllOldBatches,
                    icon: const Icon(Icons.delete_sweep_rounded,
                        size: 18, color: AdminWebColors.error),
                    label: const Text(
                      'CLEAR ALL OLD BATCHES',
                      style: TextStyle(
                        color: AdminWebColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AdminWebColors.error),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  )
                : null;

            final addBtn = ElevatedButton.icon(
              onPressed: _addNewBatch,
              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
              label: const Text(
                'START NEW MONTHLY BATCH',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminWebColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );

            if (isWide) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (clearBtn != null) clearBtn else const SizedBox.shrink(),
                  addBtn,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (clearBtn != null) ...[
                  clearBtn,
                  const SizedBox(height: 10),
                ],
                addBtn,
              ],
            );
          },
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
                    final double totalCookedHilaw = batch.sessions.fold(0.0, (sum, s) => sum + s.hilawKilos);
                    final double remainingHilaw = (batch.totalKilos - totalCookedHilaw).clamp(0.0, double.infinity);
                    final int sessionCount = batch.sessions.length;

                    return GlassCard(
                      padding: EdgeInsets.zero,
                      child: LayoutBuilder(
                        builder: (context, cardConstraints) {
                          final isWideCard = cardConstraints.maxWidth >= 600;

                          if (!isWideCard) {
                            return InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => KarneBatchDetailScreen(
                                    batch: batch,
                                    onBatchChanged: (updated) {
                                      if (mounted) {
                                        setState(() => _karneBatches[batchIndex] = updated);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: remainingHilaw <= 0 && sessionCount > 0
                                              ? AdminWebColors.success
                                              : (sessionCount > 0 ? AdminWebColors.accent : AdminWebColors.warning),
                                          child: Icon(
                                            remainingHilaw <= 0 && sessionCount > 0
                                                ? Icons.check_circle_rounded
                                                : (sessionCount > 0 ? Icons.soup_kitchen_rounded : Icons.calendar_month_rounded),
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                batch.name,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                DateFormat('MMMM yyyy').format(batch.date).toUpperCase(),
                                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AdminWebColors.accent),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${batch.totalKilos.toStringAsFixed(1)} KG',
                                              style: const TextStyle(fontWeight: FontWeight.w900, color: AdminWebColors.accent, fontSize: 14),
                                            ),
                                            const Text('Good for 1 Month', style: TextStyle(fontSize: 10, color: AdminWebColors.textSecondary)),
                                          ],
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: AdminWebColors.error, size: 18),
                                          tooltip: 'Delete Batch',
                                          onPressed: () => _confirmDeleteBatch(batch),
                                          padding: const EdgeInsets.only(left: 6),
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        if (sessionCount == 0) ...[
                                          _statusChip('OPEN BATCH (1 MONTH)', AdminWebColors.warning, icon: Icons.schedule_rounded),
                                          Text('Total Stock: ${batch.totalKilos.toStringAsFixed(1)} KG', style: const TextStyle(fontSize: 11, color: AdminWebColors.textSecondary)),
                                        ] else if (remainingHilaw <= 0) ...[
                                          _statusChip('COMPLETED', AdminWebColors.success, icon: Icons.check_circle_rounded),
                                          Text('Cooked: ${totalCookedHilaw.toStringAsFixed(1)} KG', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        ] else ...[
                                          _statusChip('$sessionCount SESSIONS ACTIVE', AdminWebColors.accent, icon: Icons.soup_kitchen_rounded),
                                          Text('Cooked: ${totalCookedHilaw.toStringAsFixed(1)} KG · Remaining: ${remainingHilaw.toStringAsFixed(1)} KG', style: const TextStyle(fontSize: 11, color: AdminWebColors.textSecondary)),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return ListTile(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => KarneBatchDetailScreen(
                                  batch: batch,
                                  onBatchChanged: (updated) {
                                    if (mounted) {
                                      setState(() => _karneBatches[batchIndex] = updated);
                                    }
                                  },
                                ),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            leading: CircleAvatar(
                              backgroundColor: remainingHilaw <= 0 && sessionCount > 0
                                  ? AdminWebColors.success
                                  : (sessionCount > 0 ? AdminWebColors.accent : AdminWebColors.warning),
                              child: Icon(
                                remainingHilaw <= 0 && sessionCount > 0
                                    ? Icons.check_circle_rounded
                                    : (sessionCount > 0 ? Icons.soup_kitchen_rounded : Icons.calendar_month_rounded),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(batch.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AdminWebColors.accent.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    DateFormat('MMMM yyyy').format(batch.date),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AdminWebColors.accent),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'GOOD FOR 1 MONTH',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blueGrey),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (sessionCount == 0) ...[
                                    _statusChip('OPEN BATCH (1 MONTH)', AdminWebColors.warning, icon: Icons.schedule_rounded),
                                    Text('Total Stock: ${batch.totalKilos.toStringAsFixed(1)} KG | No cooking sessions yet', style: const TextStyle(fontSize: 12)),
                                  ] else if (remainingHilaw <= 0) ...[
                                    _statusChip('COMPLETED', AdminWebColors.success, icon: Icons.check_circle_rounded),
                                    Text('Cooked: ${totalCookedHilaw.toStringAsFixed(1)} KG ($sessionCount Sessions) | Monthly stock fully consumed', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ] else ...[
                                    _statusChip('$sessionCount SESSIONS ACTIVE', AdminWebColors.accent, icon: Icons.soup_kitchen_rounded),
                                    Text('Cooked: ${totalCookedHilaw.toStringAsFixed(1)} KG | Remaining: ${remainingHilaw.toStringAsFixed(1)} KG', style: const TextStyle(fontSize: 12)),
                                  ],
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: AdminWebColors.error, size: 20),
                                  tooltip: 'Delete Batch',
                                  onPressed: () => _confirmDeleteBatch(batch),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${batch.totalKilos.toStringAsFixed(1)} KG', style: const TextStyle(fontWeight: FontWeight.w900, color: AdminWebColors.accent)),
                                    const Text('Good for 1 Month', style: TextStyle(fontSize: 11, color: AdminWebColors.textSecondary)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
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
        // Informational header banner explaining automated allocation + RESTOCK button
        Row(
          children: [
            Expanded(
              child: GlassCard(
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
                            'AUTOMATED BRANCH ALLOCATION & RESTOCK',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AdminWebColors.textPrimary),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Base: 250G Reg (20) · 300G Med (10) · B1T1 (10) · Mayo (40) · Styro (40) · Toyo (10). Automatic na nagre-reset tuwing 12:00 AM.',
                            style: TextStyle(fontSize: 11, color: AdminWebColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _navigateToRecordTransfer,
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
              label: const Text('RESTOCK'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminWebColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
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
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 2,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          '${s.totalRemainingPcs} / ${s.totalAllocatedPcs} MEAT PCS',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: AdminWebColors.accent,
                                          ),
                                        ),
                                        const Text(
                                          '(Natitira / Total)',
                                          style: TextStyle(fontSize: 11, color: AdminWebColors.textSecondary),
                                        ),
                                        if (s.isRunningLow)
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
          'Are you sure you want to delete this dispatch record to ${dispatch.destinationBranchName} (${dispatch.itemsSummary})?',
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
            content: Text('Dispatch record deleted.'),
            backgroundColor: AdminWebColors.error,
          ),
        );
      }
    }
  }


  void _showDispatchLogsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.local_shipping_rounded, color: AdminWebColors.accent),
            SizedBox(width: 10),
            Text('Stock Dispatch Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 700,
          height: 500,
          child: _meatDispatches.isEmpty
              ? const Center(child: Text('No stock dispatches recorded yet.'))
              : ListView.separated(
                  itemCount: _meatDispatches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final dispatch = _meatDispatches[index];
                    final isDelivered = dispatch.isDelivered;
                    return GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.warehouse_rounded, color: isDelivered ? AdminWebColors.success : AdminWebColors.accent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Warehouse → ${dispatch.destinationBranchName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(dispatch.itemsSummary, style: const TextStyle(fontSize: 12)),
                                Text('${dispatch.createdAt.month}/${dispatch.createdAt.day} · ${dispatch.createdAt.hour.toString().padLeft(2, '0')}:${dispatch.createdAt.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 11, color: AdminWebColors.textSecondary)),
                              ],
                            ),
                          ),
                          Text('${dispatch.totalPcs} pcs', style: const TextStyle(fontWeight: FontWeight.bold, color: AdminWebColors.accent)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isDelivered ? AdminWebColors.success : AdminWebColors.warning).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(isDelivered ? 'DELIVERED' : 'PENDING', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDelivered ? AdminWebColors.success : AdminWebColors.warning)),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AdminWebColors.error, size: 18),
                            onPressed: () => _confirmDeleteDispatch(dispatch),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE')),
        ],
      ),
    );
  }

  Widget _buildSupplyRequestsTab() {
    final pendingCount = _supplyRequests.where((r) => r.isPending).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Packaging & Supply Requests',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminWebColors.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              'Supply requests from Meat Cutter / Central Kitchen ($pendingCount pending)',
              style: const TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _supplyRequests.isEmpty
              ? const Center(
                  child: Text(
                    'No supply requests at this time.',
                    style: TextStyle(color: AdminWebColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  itemCount: _supplyRequests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final req = _supplyRequests[index];
                    final isPending = req.isPending;

                    return GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: LayoutBuilder(
                        builder: (context, cardConstraints) {
                          final isWideCard = cardConstraints.maxWidth >= 550;

                          final replyBtn = ElevatedButton.icon(
                            onPressed: () => _replyToSupplyRequest(req),
                            icon: const Icon(Icons.reply_rounded, size: 16),
                            label: Text(isPending ? 'REPLY / TUGON' : 'UPDATE REPLY'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPending ? AdminWebColors.accent : AdminWebColors.surfaceTint,
                              foregroundColor: isPending ? Colors.white : AdminWebColors.textPrimary,
                              elevation: 0,
                              side: isPending ? null : const BorderSide(color: AdminWebColors.border),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          );

                          if (!isWideCard) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: (isPending ? AdminWebColors.warning : AdminWebColors.success).withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isPending ? Icons.pending_actions_rounded : Icons.check_circle_rounded,
                                        color: isPending ? AdminWebColors.warning : AdminWebColors.success,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                req.itemName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AdminWebColors.textPrimary),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: (isPending ? AdminWebColors.warning : AdminWebColors.success).withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  req.status.label.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                    color: isPending ? AdminWebColors.warning : AdminWebColors.success,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Hiningi ni: ${req.requestedBy} · ${_formatDate(req.createdAt)}',
                                            style: const TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (req.ownerReply != null && req.ownerReply!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AdminWebColors.accent.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Tugon mo: "${req.ownerReply}"',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AdminWebColors.accent),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: replyBtn,
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (isPending ? AdminWebColors.warning : AdminWebColors.success).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isPending ? Icons.pending_actions_rounded : Icons.check_circle_rounded,
                                  color: isPending ? AdminWebColors.warning : AdminWebColors.success,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          req.itemName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AdminWebColors.textPrimary),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (isPending ? AdminWebColors.warning : AdminWebColors.success).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            req.status.label.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              color: isPending ? AdminWebColors.warning : AdminWebColors.success,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Hiningi ni: ${req.requestedBy} · ${_formatDate(req.createdAt)}',
                                      style: const TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
                                    ),
                                    if (req.ownerReply != null && req.ownerReply!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: AdminWebColors.accent.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Tugon mo: "${req.ownerReply}"',
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AdminWebColors.accent),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              replyBtn,
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _replyToSupplyRequest(SupplyRequest request) {
    final replyCtrl = TextEditingController(text: request.ownerReply ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.reply_rounded, color: AdminWebColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Reply to: ${request.itemName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Requested by ${request.requestedBy}.', style: const TextStyle(fontSize: 13, color: AdminWebColors.textSecondary)),
              const SizedBox(height: 14),
              const Text('Quick Responses:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _quickReplyChip('Delivering right now', replyCtrl),
                  _quickReplyChip('Driver is on the way with delivery', replyCtrl),
                  _quickReplyChip('Noted, preparing stock now', replyCtrl),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: replyCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Type your message / response',
                  hintText: 'e.g. Driver will deliver at 3 PM...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminWebColors.accent, foregroundColor: Colors.white),
            onPressed: () async {
              final text = replyCtrl.text.trim();
              if (text.isEmpty) return;

              final ok = await FirestoreService.replyToSupplyRequest(
                requestId: request.id,
                reply: text,
                itemName: request.itemName,
                requestedById: request.requestedById,
              );

              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Response sent to ${request.requestedBy}!' : 'Error sending response.'),
                    backgroundColor: ok ? AdminWebColors.success : AdminWebColors.error,
                  ),
                );
              }
            },
            child: const Text('SEND RESPONSE'),
          ),
        ],
      ),
    );
  }


  Widget _statusChip(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _quickReplyChip(String text, TextEditingController ctrl) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        ctrl.text = text;
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
