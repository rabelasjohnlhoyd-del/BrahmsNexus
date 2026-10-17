import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../models/branch.dart';
import '../../../models/branch_assignment.dart';
import '../../../models/branch_meat_inventory.dart';
import '../../../models/bilao_order.dart';
import '../../../models/sales_record.dart';
import '../../../models/inventory_batch.dart';
import '../../../models/meat_dispatch.dart';
import '../../../models/supply_request.dart';
import '../../../services/assignment_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/system_busy_coordinator.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import 'record_transfer_screen.dart';
import 'karne_batch_detail_screen.dart';
import 'monthly_financials_screen.dart';
import '../admin_web_widgets/admin_pagination_bar.dart';
import 'inventory_export_dialog.dart';

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
  StreamSubscription<List<SupplyRequest>>? _supplyRequestsSub;
  StreamSubscription<List<BilaoOrder>>? _bilaoOrdersSub;

  int _batchesPage = 0;
  int _stocksPage = 0;
  static const int _pageSize = 5;

  List<SupplyRequest> _supplyRequests = [];
  final List<KarneBatch> _karneBatches = [];
  List<BilaoOrder> _bilaoOrders = [];
  List<SalesRecord> _monthlySales = [];

  List<BranchMeatStock> _branchMeatStocks = kSampleBranches
      .map((b) => BranchMeatStock.defaultForBranch(b))
      .toList();

  List<MeatDispatch> _meatDispatches = [];
  bool _isProcessing = false;

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

    _bilaoOrdersSub = FirestoreService.watchAllBilaoOrders().listen((orders) {
      if (mounted) setState(() => _bilaoOrders = orders);
    });

    _loadMonthlySales();
  }

  Future<void> _loadMonthlySales() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final sales = await FirestoreService.getRecentSales(startDate: startOfMonth, limit: 500);
      if (mounted) setState(() => _monthlySales = sales);
    } catch (_) {}
  }

  @override
  void dispose() {
    _batchesSub?.cancel();
    _meatStocksSub?.cancel();
    _dispatchesSub?.cancel();
    _supplyRequestsSub?.cancel();
    _bilaoOrdersSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([]);
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
                    // Max 50 characters; allow letters, digits, spaces, dashes, and dots
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(50),
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s\-\.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'BATCH NAME (MONTHLY BATCH)',
                      hintText: 'e.g. KARNE BATCH - OCTOBER 2026',
                      helperText: 'Max 50 characters.',
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
                    // Allow digits and a single decimal point only
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
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
                        final messenger = ScaffoldMessenger.of(context);
                        // ── Validation with user-visible error messages ──
                        final nameText = nameCtrl.text.trim();
                        if (nameText.isEmpty) {
                          messenger.showSnackBar(const SnackBar(
                            content: Text('Batch name cannot be empty.'),
                            backgroundColor: AdminWebColors.error,
                          ));
                          return;
                        }
                        if (nameText.length < 3) {
                          messenger.showSnackBar(const SnackBar(
                            content: Text('Batch name must be at least 3 characters.'),
                            backgroundColor: AdminWebColors.error,
                          ));
                          return;
                        }
                        final kilosText = kilosCtrl.text.trim();
                        if (kilosText.isEmpty) {
                          messenger.showSnackBar(const SnackBar(
                            content: Text('Please enter the total raw meat in kilos.'),
                            backgroundColor: AdminWebColors.error,
                          ));
                          return;
                        }
                        final double? kilos = double.tryParse(kilosText);
                        if (kilos == null || kilos <= 0) {
                          messenger.showSnackBar(const SnackBar(
                            content: Text('Total raw meat must be a valid positive number (e.g. 1000.0).'),
                            backgroundColor: AdminWebColors.error,
                          ));
                          return;
                        }

                        final batchId = 'kb_${selectedMonth.year}_${selectedMonth.month.toString().padLeft(2, '0')}';
                        final newBatch = KarneBatch(
                          id: batchId,
                          name: nameText.toUpperCase(),
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
    final result = await showDialog<MeatDispatch>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const RecordTransferDialog(),
    );

    if (result != null && mounted) {
      // The real-time stream will pick up the change from Firestore automatically.
      // This local insert is just for immediate UI feedback.
      setState(() {
        _meatDispatches.insert(0, result);
      });
    }
  }

  void _showSetAllocationDialog(BranchMeatStock stock) {
    final regCtrl = TextEditingController(text: stock.regular250gTotal.toString());
    final medCtrl = TextEditingController(text: stock.medium300gTotal.toString());
    final b1t1Ctrl = TextEditingController(text: stock.b1t1_400gTotal.toString());
    final mayoCtrl = TextEditingController(text: stock.mayoTotal.toString());
    final styroCtrl = TextEditingController(text: stock.styroTotal.toString());
    final toyoCtrl = TextEditingController(text: stock.toyoTotal.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: AdminWebColors.accent, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Set Branch Daily Allocation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(stock.branchName, style: const TextStyle(fontSize: 12, color: AdminWebColors.textSecondary, fontWeight: FontWeight.normal)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminWebColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminWebColors.accent.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AdminWebColors.accent, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pwedeng i-set sa 0 ang lahat kung sarado o walang karne ang branch na ito para mailipat ang stock sa malalakas na branch.',
                          style: TextStyle(fontSize: 12, color: AdminWebColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('MEAT ALLOCATION (PCS)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AdminWebColors.accent)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: regCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: '250g Regular',
                          labelStyle: const TextStyle(fontSize: 12),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: medCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: '300g Medium',
                          labelStyle: const TextStyle(fontSize: 12),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: b1t1Ctrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: '400g B1T1',
                          labelStyle: const TextStyle(fontSize: 12),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('SUPPLIES ALLOCATION (PCS)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AdminWebColors.accent)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: mayoCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Mayo',
                          labelStyle: const TextStyle(fontSize: 12),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: styroCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Styro Box',
                          labelStyle: const TextStyle(fontSize: 12),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: toyoCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Toyo',
                          labelStyle: const TextStyle(fontSize: 12),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminWebColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final newReg = int.tryParse(regCtrl.text.trim()) ?? 0;
              final newMed = int.tryParse(medCtrl.text.trim()) ?? 0;
              final newB1t1 = int.tryParse(b1t1Ctrl.text.trim()) ?? 0;
              final newMayo = int.tryParse(mayoCtrl.text.trim()) ?? 0;
              final newStyro = int.tryParse(styroCtrl.text.trim()) ?? 0;
              final newToyo = int.tryParse(toyoCtrl.text.trim()) ?? 0;

              final updated = stock.copyWith(
                regular250gTotal: newReg,
                regular250gRemaining: newReg,
                medium300gTotal: newMed,
                medium300gRemaining: newMed,
                b1t1_400gTotal: newB1t1,
                b1t1_400gRemaining: newB1t1,
                mayoTotal: newMayo,
                mayoRemaining: newMayo,
                styroTotal: newStyro,
                styroRemaining: newStyro,
                toyoTotal: newToyo,
                toyoRemaining: newToyo,
                baseRegular250g: newReg,
                baseMedium300g: newMed,
                baseB1t1_400g: newB1t1,
                baseMayo: newMayo,
                baseStyro: newStyro,
                baseToyo: newToyo,
                date: DateTime.now(),
              );

              Navigator.pop(ctx);
              final success = await FirestoreService.saveBranchMeatStock(updated);
              if (mounted) {
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Na-update na ang daily allocation para sa ${stock.branchName}!'
                        : 'Notice: Na-save locally ang allocation.'),
                    backgroundColor: success ? AdminWebColors.success : null,
                  ),
                );
              }
            },
            child: const Text('SAVE ALLOCATION'),
          ),
        ],
      ),
    );
  }

  void _showSetAllocationForAllDialog() {
    final regCtrl = TextEditingController(text: '20');
    final medCtrl = TextEditingController(text: '10');
    final b1t1Ctrl = TextEditingController(text: '10');
    final mayoCtrl = TextEditingController(text: '40');
    final styroCtrl = TextEditingController(text: '40');
    final toyoCtrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.auto_fix_high_rounded, color: AdminWebColors.accent, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set Allocation for All Branches', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('I-a-apply ang stock allocation na ito sa lahat ng 6 branches', style: TextStyle(fontSize: 12, color: AdminWebColors.textSecondary, fontWeight: FontWeight.normal)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MEAT ALLOCATION PER BRANCH (PCS)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AdminWebColors.accent)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: regCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: '250g Regular',
                          labelStyle: const TextStyle(fontSize: 12),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: medCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: '300g Medium',
                          labelStyle: const TextStyle(fontSize: 12),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: b1t1Ctrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: '400g B1T1',
                          labelStyle: const TextStyle(fontSize: 12),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('SUPPLIES ALLOCATION PER BRANCH (PCS)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AdminWebColors.accent)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: mayoCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Mayo',
                          labelStyle: const TextStyle(fontSize: 12),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: styroCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Styro Box',
                          labelStyle: const TextStyle(fontSize: 12),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: toyoCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Toyo',
                          labelStyle: const TextStyle(fontSize: 12),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminWebColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final newReg = int.tryParse(regCtrl.text.trim()) ?? 0;
              final newMed = int.tryParse(medCtrl.text.trim()) ?? 0;
              final newB1t1 = int.tryParse(b1t1Ctrl.text.trim()) ?? 0;
              final newMayo = int.tryParse(mayoCtrl.text.trim()) ?? 0;
              final newStyro = int.tryParse(styroCtrl.text.trim()) ?? 0;
              final newToyo = int.tryParse(toyoCtrl.text.trim()) ?? 0;

              Navigator.pop(ctx);
              setState(() => _isProcessing = true);
              SystemBusyCoordinator.setBusy(true);

              try {
                for (final s in _branchMeatStocks) {
                  final updated = s.copyWith(
                    baseRegular250g: newReg,
                    baseMedium300g: newMed,
                    baseB1t1_400g: newB1t1,
                    baseMayo: newMayo,
                    baseStyro: newStyro,
                    baseToyo: newToyo,
                    regular250gTotal: s.isClosed ? 0 : newReg,
                    regular250gRemaining: s.isClosed ? 0 : newReg,
                    medium300gTotal: s.isClosed ? 0 : newMed,
                    medium300gRemaining: s.isClosed ? 0 : newMed,
                    b1t1_400gTotal: s.isClosed ? 0 : newB1t1,
                    b1t1_400gRemaining: s.isClosed ? 0 : newB1t1,
                    mayoTotal: s.isClosed ? 0 : newMayo,
                    mayoRemaining: s.isClosed ? 0 : newMayo,
                    styroTotal: s.isClosed ? 0 : newStyro,
                    styroRemaining: s.isClosed ? 0 : newStyro,
                    toyoTotal: s.isClosed ? 0 : newToyo,
                    toyoRemaining: s.isClosed ? 0 : newToyo,
                    date: DateTime.now(),
                  );
                  await FirestoreService.saveBranchMeatStock(updated);
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Na-apply na ang bagong allocation sa lahat ng 6 branches!',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AdminWebColors.success,
                    ),
                  );
                }
              } finally {
                SystemBusyCoordinator.setBusy(false);
                if (mounted) setState(() => _isProcessing = false);
              }
            },
            child: const Text('APPLY TO ALL BRANCHES'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAllBranches() async {
    if (_isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.storefront_rounded, color: Color(0xFF059669), size: 24),
            SizedBox(width: 10),
            Text('Open All Branches?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Are you sure you want to OPEN all 6 branches?\n\nEach branch will be restored to its configured daily stock allocation.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('YES, OPEN ALL'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    SystemBusyCoordinator.setBusy(true);

    try {
      int count = 0;
      for (final s in _branchMeatStocks) {
        final updated = s.toOpen();
        await FirestoreService.saveBranchMeatStock(updated);
        count++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All $count branches are now OPEN with their configured stock allocations!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } finally {
      SystemBusyCoordinator.setBusy(false);
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _closeAllBranches() async {
    if (_isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.do_not_disturb_on_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 10),
            Text('Close All Branches?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Are you sure you want to CLOSE all branches?\n\nAll stock allocations will be set to 0 pcs. Their configured normal stock will remain saved and will be restored when branches are opened again.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('YES, CLOSE ALL'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    SystemBusyCoordinator.setBusy(true);

    try {
      int count = 0;
      for (final s in _branchMeatStocks) {
        final updated = s.toClosed();
        await FirestoreService.saveBranchMeatStock(updated);
        count++;
      }

      // Auto-set all on-duty cooks across all closed branches to Rest Day in one pass
      try {
        final allStaff = SupabaseService.getAllStaff();
        final branchCooks = allStaff.where((s) {
          if (s.isArchived) return false;
          final pos = s.position.toLowerCase();
          if (pos.startsWith('production')) return false;
          return pos.contains('cook');
        }).toList();

        for (final cook in branchCooks) {
          final currentStatus = AssignmentService.getWorkStatus(
            cook.username,
            fallback: AssignmentService.getWorkStatus(cook.id, fallback: WorkStatus.onDuty),
          );
          if (currentStatus == WorkStatus.onDuty) {
            await AssignmentService.setAssignment(
              username: cook.username,
              employeeId: cook.id,
              employeeName: cook.fullName,
              branchId: '',
              branchName: cook.branch,
              status: WorkStatus.restDay,
            );
          }
        }
      } catch (_) {
        // Silent best-effort
      }

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All $count branches are now CLOSED with 0 allocation.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      SystemBusyCoordinator.setBusy(false);
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _toggleBranchOpenStatus(BranchMeatStock stock, {required bool shouldOpen}) async {
    if (_isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(
              shouldOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
              color: shouldOpen ? const Color(0xFF059669) : const Color(0xFFDC2626),
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              shouldOpen ? 'Open Branch?' : 'Close Branch?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          shouldOpen
              ? 'Are you sure you want to OPEN ${stock.branchName}?\n\nThis will restore the branch\'s configured stock allocation and allow active operations.'
              : 'Are you sure you want to CLOSE ${stock.branchName}?\n\nAll stock allocations will temporarily be set to 0 pcs. Configured baseline stock is safely preserved.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: shouldOpen ? const Color(0xFF059669) : const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(shouldOpen ? 'YES, OPEN BRANCH' : 'YES, CLOSE BRANCH'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    SystemBusyCoordinator.setBusy(true);

    try {
      final updated = shouldOpen ? stock.toOpen() : stock.toClosed();
      await FirestoreService.saveBranchMeatStock(updated);

    // When closing a branch, automatically set all on-duty cooks at that branch to Rest Day
    if (!shouldOpen) {
      try {
        final allStaff = SupabaseService.getAllStaff();
        final branchCooks = allStaff.where((s) {
          if (s.isArchived) return false;
          final pos = s.position.toLowerCase();
          if (pos.startsWith('production')) return false;
          if (!pos.contains('cook')) return false;
          final sName = s.branch.trim().toLowerCase();
          final tName = stock.branchName.trim().toLowerCase();
          return sName == tName || sName.contains(tName) || tName.contains(sName);
        }).toList();
        for (final cook in branchCooks) {
          final currentStatus = AssignmentService.getWorkStatus(
            cook.username,
            fallback: AssignmentService.getWorkStatus(cook.id, fallback: WorkStatus.onDuty),
          );
          if (currentStatus == WorkStatus.onDuty) {
            await AssignmentService.setAssignment(
              username: cook.username,
              employeeId: cook.id,
              employeeName: cook.fullName,
              branchId: stock.branchId,
              branchName: stock.branchName,
              status: WorkStatus.restDay,
            );
          }
        }
      } catch (_) {
        // Silent: assignment update is best-effort; branch close still succeeds
      }
    }

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  shouldOpen ? Icons.check_circle_rounded : Icons.lock_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    shouldOpen
                        ? '${stock.branchName} is now OPEN. Configured allocation restored!'
                        : '${stock.branchName} is now CLOSED. Allocation set to 0 pcs.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: shouldOpen ? const Color(0xFF059669) : const Color(0xFFDC2626),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      SystemBusyCoordinator.setBusy(false);
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingRequestsCount = _supplyRequests.where((r) => r.isPending).length;

    return AbsorbPointer(
      absorbing: _isProcessing,
      child: Stack(
        children: [
          Container(
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
                      _KeepAliveTab(child: _buildWarehouseTab()),
                      _KeepAliveTab(child: _buildBranchStockTab()),
                      _KeepAliveTab(child: _buildSupplyRequestsTab()),
                      _KeepAliveTab(child: MonthlyFinancialsScreen(karneBatches: _karneBatches)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.15),
                child: Center(
                  child: Card(
                    color: Colors.white,
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: AdminWebColors.accent),
                          ),
                          SizedBox(width: 14),
                          Text(
                            'Processing... Please wait...',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminWebColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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

            final exportInventoryBtn = ElevatedButton.icon(
              onPressed: () => InventoryExportDialog.show(
                context,
                batches: _karneBatches,
                branchStocks: _branchMeatStocks,
                dispatches: _meatDispatches,
                supplyRequests: _supplyRequests,
              ),
              icon: const Icon(Icons.table_view_rounded, size: 16, color: Colors.white),
              label: const Text(
                'EXPORT INVENTORY (.XLSX)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );

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
                  Row(
                    children: [
                      exportInventoryBtn,
                      const SizedBox(width: 12),
                      addBtn,
                    ],
                  ),
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
                exportInventoryBtn,
                const SizedBox(height: 10),
                addBtn,
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _buildMeatConsumptionSummary(),
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

  Widget _buildMeatConsumptionSummary() {
    final now = DateTime.now();
    // 1. Total meat pieces produced by Production this month
    int totalProducedPcs = 0;
    for (final b in _karneBatches) {
      if (b.date.year == now.year && b.date.month == now.month) {
        totalProducedPcs += b.totalProducedMeatPcs;
      }
    }

    // 2. Meat pieces consumed by POS sales today and this month
    int posUsedToday = 0;
    int posUsedMonth = 0;
    for (final s in _monthlySales) {
      final orders = s.displayTotalOrders;
      if (s.date.year == now.year && s.date.month == now.month) {
        posUsedMonth += orders;
        if (s.date.day == now.day) {
          posUsedToday += orders;
        }
      }
    }

    // 3. Meat pieces consumed by Bilao Orders (5 reg for Small, 7 for Med, 10 for Large)
    int bilaoUsedToday = 0;
    int bilaoUsedMonth = 0;
    for (final order in _bilaoOrders) {
      final orderMeat = order.size.regularOrderEquivalent * order.quantity;
      if (order.scheduledDateTime.year == now.year && order.scheduledDateTime.month == now.month) {
        bilaoUsedMonth += orderMeat;
        if (order.scheduledDateTime.day == now.day) {
          bilaoUsedToday += orderMeat;
        }
      }
    }

    final int totalConsumedToday = posUsedToday + bilaoUsedToday;
    final int totalConsumedMonth = posUsedMonth + bilaoUsedMonth;
    final int remainingInventoryPcs = (totalProducedPcs - totalConsumedMonth).clamp(0, 999999);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminWebColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics_rounded, color: AdminWebColors.accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY MEAT CONSUMPTION & RUNNING MONTHLY INVENTORY (${DateFormat('MMMM yyyy').format(now).toUpperCase()})',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AdminWebColors.textPrimary, letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Awtomatikong binabawas ang benta sa branch + bilao orders (Small: 5 pcs, Med: 7 pcs, Large: 10 pcs) sa ginawang karne ng Production.',
                      style: TextStyle(fontSize: 11, color: AdminWebColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              final kpis = [
                _buildKpiSummaryBox(
                  title: 'TODAY CONSUMED',
                  value: '$totalConsumedToday PCS',
                  subtitle: 'Branch: $posUsedToday · Bilao: $bilaoUsedToday pcs',
                  color: AdminWebColors.accent,
                  icon: Icons.today_rounded,
                ),
                _buildKpiSummaryBox(
                  title: 'MONTHLY ACCUMULATED',
                  value: '$totalConsumedMonth PCS',
                  subtitle: 'Branch: $posUsedMonth · Bilao: $bilaoUsedMonth pcs',
                  color: const Color(0xFFD97706),
                  icon: Icons.trending_up_rounded,
                ),
                _buildKpiSummaryBox(
                  title: 'TOTAL PRODUCTION CUT',
                  value: '$totalProducedPcs PCS',
                  subtitle: 'Gawa ng Production Warehouse',
                  color: const Color(0xFF2563EB),
                  icon: Icons.inventory_2_rounded,
                ),
                _buildKpiSummaryBox(
                  title: 'REMAINING INVENTORY',
                  value: '$remainingInventoryPcs PCS',
                  subtitle: 'Natitirang karne sa warehouse',
                  color: remainingInventoryPcs > 0 ? const Color(0xFF059669) : AdminWebColors.error,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ];

              if (isWide) {
                return Row(
                  children: kpis.map((kpi) => Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: kpi,
                  ))).toList(),
                );
              }

              return Column(
                children: kpis.map((kpi) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: kpi,
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryBox({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: AdminWebColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
                            'BRANCH DAILY ALLOCATION & STOCK MANAGEMENT',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AdminWebColors.textPrimary),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'I-manage ang daily meat at supply allocations ng bawat branch. Gamitin ang OPEN ALL o CLOSED ALL para sa pangkalahatang operasyon, o i-open/close at i-set ang allocation ng bawat branch.',
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _showSetAllocationForAllDialog,
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                  label: const Text('SET ALLOCATION FOR ALL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminWebColors.accent,
                    side: const BorderSide(color: AdminWebColors.accent),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _openAllBranches,
                  icon: const Icon(Icons.storefront_rounded, size: 16),
                  label: const Text('OPEN ALL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _closeAllBranches,
                  icon: const Icon(Icons.do_not_disturb_on_rounded, size: 16),
                  label: const Text('CLOSED ALL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _navigateToRecordTransfer,
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                  label: const Text('RESTOCK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminWebColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
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
                                backgroundColor: s.isClosed
                                    ? const Color(0xFFE2E8F0)
                                    : (s.isRunningLow
                                            ? AdminWebColors.error
                                            : AdminWebColors.accent)
                                        .withValues(alpha: 0.1),
                                child: Icon(
                                  Icons.store_rounded,
                                  color: s.isClosed
                                      ? const Color(0xFF94A3B8)
                                      : (s.isRunningLow
                                          ? AdminWebColors.error
                                          : AdminWebColors.accent),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          s.branchName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: s.isClosed ? const Color(0xFF64748B) : AdminWebColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (s.isClosed ? const Color(0xFFDC2626) : const Color(0xFF059669)).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: (s.isClosed ? const Color(0xFFDC2626) : const Color(0xFF059669)).withValues(alpha: 0.25)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                s.isClosed ? Icons.lock_rounded : Icons.storefront_rounded,
                                                size: 10,
                                                color: s.isClosed ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                s.isClosed ? 'CLOSED (0 STOCK)' : 'OPEN',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: s.isClosed ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 2,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          s.isClosed
                                              ? '0 / 0 MEAT PCS'
                                              : '${s.totalRemainingPcs} / ${s.totalAllocatedPcs} MEAT PCS',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: s.isClosed ? const Color(0xFF94A3B8) : AdminWebColors.accent,
                                          ),
                                        ),
                                        Text(
                                          s.isClosed ? '(Closed / 0 Allocation)' : '(Natitira / Total)',
                                          style: const TextStyle(fontSize: 11, color: AdminWebColors.textSecondary),
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Open / Closed button per branch
                                  if (s.isClosed)
                                    ElevatedButton.icon(
                                      onPressed: () => _toggleBranchOpenStatus(s, shouldOpen: true),
                                      icon: const Icon(Icons.lock_open_rounded, size: 14),
                                      label: const Text('OPEN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF059669),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        elevation: 0,
                                      ),
                                    )
                                  else
                                    OutlinedButton.icon(
                                      onPressed: () => _toggleBranchOpenStatus(s, shouldOpen: false),
                                      icon: const Icon(Icons.lock_rounded, size: 14),
                                      label: const Text('CLOSE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFDC2626),
                                        side: const BorderSide(color: Color(0xFFDC2626)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  Tooltip(
                                    message: s.isClosed ? 'Hindi pwedeng baguhin ang allocation habang CLOSED ang branch. I-open muna ito.' : 'I-set ang allocation ng branch na ito',
                                    child: OutlinedButton.icon(
                                      onPressed: s.isClosed ? null : () => _showSetAllocationDialog(s),
                                      icon: const Icon(Icons.tune_rounded, size: 14),
                                      label: const Text('SET ALLOCATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AdminWebColors.accent,
                                        disabledForegroundColor: const Color(0xFF94A3B8),
                                        side: BorderSide(color: s.isClosed ? const Color(0xFFCBD5E1) : AdminWebColors.accent),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          // Row 1: Meat portions (250g Regular, 300g Medium, 400g B1T1)
                          Row(
                            children: [
                              Expanded(child: _meatVariantChip('250g Regular', '${s.regular250gRemaining} / ${s.regular250gTotal} pcs', isClosed: s.isClosed)),
                              const SizedBox(width: 6),
                              Expanded(child: _meatVariantChip('300g Medium', '${s.medium300gRemaining} / ${s.medium300gTotal} pcs', isClosed: s.isClosed)),
                              const SizedBox(width: 6),
                              Expanded(child: _meatVariantChip('400g B1T1', '${s.b1t1_400gRemaining} / ${s.b1t1_400gTotal} pcs', isClosed: s.isClosed)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Row 2: Supplies (Mayo, Styro, Toyo)
                          Row(
                            children: [
                              Expanded(child: _meatVariantChip('Mayo', '${s.mayoRemaining} / ${s.mayoTotal} pcs', isClosed: s.isClosed)),
                              const SizedBox(width: 6),
                              Expanded(child: _meatVariantChip('Styro Box', '${s.styroRemaining} / ${s.styroTotal} pcs', isClosed: s.isClosed)),
                              const SizedBox(width: 6),
                              Expanded(child: _meatVariantChip('Toyo', '${s.toyoRemaining} / ${s.toyoTotal} pcs', isClosed: s.isClosed)),
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

  Widget _meatVariantChip(String label, String value, {bool isClosed = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isClosed ? const Color(0xFFF1F5F9) : AdminWebColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isClosed ? const Color(0xFFE2E8F0) : AdminWebColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isClosed ? const Color(0xFF94A3B8) : AdminWebColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isClosed ? '0 / 0 pcs' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isClosed ? const Color(0xFF94A3B8) : AdminWebColors.textPrimary,
            ),
          ),
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

                          final replyBtn = isPending
                              ? ElevatedButton.icon(
                                  onPressed: () => _replyToSupplyRequest(req),
                                  icon: const Icon(Icons.reply_rounded, size: 16),
                                  label: const Text('REPLY / TUGON'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AdminWebColors.accent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                )
                              : null;

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
                                if (replyBtn != null) ...[
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: replyBtn,
                                  ),
                                ],
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
                              if (replyBtn != null) ...[
                                const SizedBox(width: 12),
                                replyBtn,
                              ],
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

class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({required this.child});
  final Widget child;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

