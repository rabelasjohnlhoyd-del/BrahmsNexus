import 'package:shared_preferences/shared_preferences.dart';
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
      TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));

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
    final now = DateTime.now();
    final currentMonthDate = DateTime(now.year, now.month, 1);
    final nextMonthDate = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);

    DateTime selectedMonth = currentMonthDate;
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

          // Bawal nang bumalik sa mga nakaraang buwan; tanging kasalukuyan at kasunod na buwan lang ang pwede
          final bool isCurrentMonth = selectedMonth.year == currentMonthDate.year &&
              selectedMonth.month == currentMonthDate.month;
          final bool canGoBack = !isCurrentMonth;
          final bool canGoForward = isCurrentMonth;

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
                          tooltip: canGoBack ? 'Kasalukuyang Buwan' : 'Bawal nang pumili ng nakaraang buwan',
                          onPressed: canGoBack
                              ? () {
                                  setDlgState(() {
                                    selectedMonth = currentMonthDate;
                                    nameCtrl.text = formatBatchName(selectedMonth);
                                  });
                                }
                              : null,
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
                          tooltip: canGoForward ? 'Kasunod na Buwan' : 'Lalabas lang ang susunod kapag tapos na ang kasalukuyang buwan',
                          onPressed: canGoForward
                              ? () {
                                  setDlgState(() {
                                    selectedMonth = nextMonthDate;
                                    nameCtrl.text = formatBatchName(selectedMonth);
                                  });
                                }
                              : null,
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
                    decoration: const InputDecoration(
                      labelText: 'TOTAL RAW MEAT (KILOS) - GOOD FOR 1 MONTH',
                      hintText: '1 - 3000 KG',
                      suffixText: 'KG',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.scale_rounded, size: 18),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        final t = newValue.text;
                        if (t.isEmpty) return newValue;
                        // Forbid starting with 0 (e.g. 0, 00, 000, 0000)
                        if (t.startsWith('0')) return oldValue;
                        final val = int.tryParse(t);
                        // Maximum allowed is 3000 KG
                        if (val != null && val > 3000) return oldValue;
                        return newValue;
                      }),
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
                        final int? kilosVal = int.tryParse(kilosText);
                        if (kilosText.isEmpty || kilosVal == null || kilosVal <= 0) {
                          messenger.showSnackBar(const SnackBar(
                            content: Text('Invalid weight. Total raw meat must be between 1 and 3,000 KG (0 is not allowed).'),
                            backgroundColor: AdminWebColors.error,
                          ));
                          return;
                        }
                        if (kilosVal > 3000) {
                          messenger.showSnackBar(const SnackBar(
                            content: Text('Maximum raw meat allowed is 3,000 KG.'),
                            backgroundColor: AdminWebColors.error,
                          ));
                          return;
                        }
                        final double kilos = kilosVal.toDouble();

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
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
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
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
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

    // Check if assignments have been saved today
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString('assignment_saved_date') ?? '';
    final todayStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    final bool assignmentsSavedToday = savedDate == todayStr;

    if (assignmentsSavedToday) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 24),
              SizedBox(width: 10),
              Text('Bawal I-open ang Lahat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: const Text(
            'Hindi maaaring i-open ang lahat ng branch dahil nai-save na ang deployment assignments ngayong araw. Bawal baguhin ang estado ng mga branch upang maiwasan ang pagkagulo ng inventory at deployment data.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminWebColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('NAINTINDIHAN'),
            ),
          ],
        ),
      );
      return;
    }

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

    // Check if assignments have been saved today
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString('assignment_saved_date') ?? '';
    final todayStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    final bool assignmentsSavedToday = savedDate == todayStr;

    if (assignmentsSavedToday) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 24),
              SizedBox(width: 10),
              Text('Bawal I-close ang Lahat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: const Text(
            'Hindi maaaring i-close ang lahat ng branch dahil nai-save na ang deployment assignments para sa mga cook ngayong araw. Bawal isara ang mga branch na may nakatalagang cook.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminWebColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('NAINTINDIHAN'),
            ),
          ],
        ),
      );
      return;
    }

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

    // Check if assignments have been saved today
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString('assignment_saved_date') ?? '';
    final todayStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    final bool assignmentsSavedToday = savedDate == todayStr;

    if (assignmentsSavedToday) {
      if (!shouldOpen) {
        final assignedCooks = SupabaseService.getAllStaff().where((s) {
          if (s.isArchived) return false;
          final status = AssignmentService.getWorkStatus(
            s.username,
            fallback: AssignmentService.getWorkStatus(s.id, fallback: WorkStatus.onDuty),
          );
          final branch = AssignmentService.getAssignedBranch(
            s.username,
            fallback: AssignmentService.getAssignedBranch(s.id, fallback: s.branch),
          );
          final sBranchLower = branch.toLowerCase().trim();
          final stockBranchLower = stock.branchName.toLowerCase().trim();
          return status == WorkStatus.onDuty &&
              (sBranchLower == stockBranchLower ||
               sBranchLower.contains(stockBranchLower) ||
               stockBranchLower.contains(sBranchLower));
        }).toList();

        if (assignedCooks.isNotEmpty) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: const Row(
                children: [
                  Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 24),
                  SizedBox(width: 10),
                  Text('Bawal I-close ang Branch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Text(
                'Hindi maaaring i-close ang ${stock.branchName} dahil nai-save na ang deployment assignments ngayong araw para kay/kina:\n\n• ${assignedCooks.map((c) => c.fullName).join("\n• ")}\n\nBawal i-close ang branch upang maiwasan ang pagkasira o pagkagulo ng inventory at deployment data.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminWebColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('NAINTINDIHAN'),
                ),
              ],
            ),
          );
          return;
        }
      } else {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Row(
              children: [
                Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 24),
                SizedBox(width: 10),
                Text('Bawal I-open ang Branch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Text(
              'Hindi maaaring i-open ang ${stock.branchName} dahil nai-save na ang deployment assignments para sa araw na ito. Bawal baguhin ang estado ng branch upang maiwasan ang pagkagulo ng inventory at deployment data.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminWebColors.accent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('NAINTINDIHAN'),
              ),
            ],
          ),
        );
        return;
      }
    }

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
            padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 600 ? 12 : 24),
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
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _KeepAliveTab(child: _buildWarehouseTab()),
                      _KeepAliveTab(child: _buildSupplyRequestsTab()),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
          if (_karneBatches.length > _pageSize) ...[
            const SizedBox(height: 16),
            AdminPaginationBar(
              currentPage: _batchesPage,
              totalItems: _karneBatches.length,
              pageSize: _pageSize,
              onPageChanged: (p) => setState(() => _batchesPage = p),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMeatConsumptionSummary() {
    final now = DateTime.now();

    // 1. Meat pieces cut/produced by Production this month for each portion type:
    int produced250g = 0;
    int produced300g = 0;
    int produced400g = 0;

    // OPTION A: Determine the start date of meat production/cutting for the active batch this month.
    // Only sales and bilao orders on or after this batch was cut deplete its warehouse stock!
    DateTime? batchCutStartDate;

    for (final b in _karneBatches) {
      if (b.date.year == now.year && b.date.month == now.month) {
        if (b.sessions.isNotEmpty) {
          for (final s in b.sessions) {
            if (s.actual250g != null || s.actual300g != null || s.actual400g != null) {
              produced250g += (s.actual250g ?? 0);
              produced300g += (s.actual300g ?? 0);
              produced400g += (s.actual400g ?? 0);
            } else if (s.nagawa > 0) {
              // Proportional fallback based on Brahms 20/10/10 ratio (50% 250g, 25% 300g, 25% 400g)
              final p250 = (s.nagawa * 0.5).round();
              final p300 = (s.nagawa * 0.25).round();
              final p400 = s.nagawa - p250 - p300;
              produced250g += p250;
              produced300g += p300;
              produced400g += p400;
            }

            final d = s.cutterReportedAt ?? s.cookedAt ?? s.date;
            if (batchCutStartDate == null || d.isBefore(batchCutStartDate)) {
              batchCutStartDate = d;
            }
          }
        } else {
          if (b.actual250g != null || b.actual300g != null || b.actual400g != null) {
            produced250g += (b.actual250g ?? 0);
            produced300g += (b.actual300g ?? 0);
            produced400g += (b.actual400g ?? 0);
          } else if (b.totalProducedMeatPcs > 0) {
            final p250 = (b.totalProducedMeatPcs * 0.5).round();
            final p300 = (b.totalProducedMeatPcs * 0.25).round();
            final p400 = b.totalProducedMeatPcs - p250 - p300;
            produced250g += p250;
            produced300g += p300;
            produced400g += p400;
          }

          final d = b.cutterReportedAt ?? b.cookedAt ?? b.targetsSetAt;
          if (d != null && (batchCutStartDate == null || d.isBefore(batchCutStartDate))) {
            batchCutStartDate = d;
          }
        }
      }
    }

    // Default cutoff to start of day of batch cut, or today if no explicit cut date
    final DateTime batchCutDay = batchCutStartDate != null
        ? DateTime(batchCutStartDate.year, batchCutStartDate.month, batchCutStartDate.day)
        : DateTime(now.year, now.month, now.day);

    // 2. Meat pieces consumed by POS sales today, since batch cut, and this month:
    int posUsedToday250g = 0;
    int posUsedToday300g = 0;
    int posUsedToday400g = 0;

    int posUsedBatch250g = 0;
    int posUsedBatch300g = 0;
    int posUsedBatch400g = 0;

    int posUsedMonth250g = 0;
    int posUsedMonth300g = 0;
    int posUsedMonth400g = 0;

    for (final s in _monthlySales) {
      if (s.date.year == now.year && s.date.month == now.month) {
        int reg = s.regularSold ?? 0;
        int med = s.mediumSold ?? 0;
        int b1t1 = s.b1t1OrdersSold ?? 0;

        if (reg == 0 && med == 0 && b1t1 == 0 && s.displayTotalOrders > 0) {
          reg = (s.displayTotalOrders * 0.5).round();
          med = (s.displayTotalOrders * 0.25).round();
          b1t1 = s.displayTotalOrders - reg - med;
        }

        posUsedMonth250g += reg;
        posUsedMonth300g += med;
        posUsedMonth400g += b1t1;

        // Sales on or after batch cut date deplete the active batch:
        final sDay = DateTime(s.date.year, s.date.month, s.date.day);
        if (!sDay.isBefore(batchCutDay)) {
          posUsedBatch250g += reg;
          posUsedBatch300g += med;
          posUsedBatch400g += b1t1;
        }

        if (s.date.day == now.day) {
          posUsedToday250g += reg;
          posUsedToday300g += med;
          posUsedToday400g += b1t1;
        }
      }
    }

    // 3. Meat pieces consumed by Bilao Orders (Consumes 250g Regular Meat portions):
    // - Small: 5 pcs of 250g
    // - Medium: 7 pcs of 250g
    // - Large: 10 pcs of 250g
    int bilaoUsedToday250g = 0;
    int bilaoUsedBatch250g = 0;
    int bilaoUsedMonth250g = 0;

    for (final order in _bilaoOrders) {
      if (order.isCancelled) continue;
      final orderMeat = order.size.regularOrderEquivalent * (order.quantity > 0 ? order.quantity : 1);
      if (order.scheduledDateTime.year == now.year && order.scheduledDateTime.month == now.month) {
        bilaoUsedMonth250g += orderMeat;

        final oDay = DateTime(order.scheduledDateTime.year, order.scheduledDateTime.month, order.scheduledDateTime.day);
        if (!oDay.isBefore(batchCutDay)) {
          bilaoUsedBatch250g += orderMeat;
        }

        if (order.scheduledDateTime.day == now.day) {
          bilaoUsedToday250g += orderMeat;
        }
      }
    }

    // Itemized calculations for the 3 meat sizes:
    final int totalConsumedToday250g = posUsedToday250g + bilaoUsedToday250g;
    final int totalConsumedBatch250g = posUsedBatch250g + bilaoUsedBatch250g;
    final int totalConsumedMonth250g = posUsedMonth250g + bilaoUsedMonth250g;
    final int remaining250g = (produced250g - totalConsumedBatch250g).clamp(0, 999999);

    final int totalConsumedToday300g = posUsedToday300g;
    final int totalConsumedBatch300g = posUsedBatch300g;
    final int totalConsumedMonth300g = posUsedMonth300g;
    final int remaining300g = (produced300g - totalConsumedBatch300g).clamp(0, 999999);

    final int totalConsumedToday400g = posUsedToday400g;
    final int totalConsumedBatch400g = posUsedBatch400g;
    final int totalConsumedMonth400g = posUsedMonth400g;
    final int remaining400g = (produced400g - totalConsumedBatch400g).clamp(0, 999999);

    // Consolidated grand totals:
    final int grandProduced = produced250g + produced300g + produced400g;
    final int grandConsumedToday = totalConsumedToday250g + totalConsumedToday300g + totalConsumedToday400g;
    final int grandConsumedBatch = totalConsumedBatch250g + totalConsumedBatch300g + totalConsumedBatch400g;
    final int grandConsumedMonth = totalConsumedMonth250g + totalConsumedMonth300g + totalConsumedMonth400g;
    final int grandRemaining = remaining250g + remaining300g + remaining400g;

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
                  color: AdminWebColors.accent.withValues(alpha: 0.12),
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 PORTION CARDS (250g, 300g, 400g)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              final card250g = _buildPortionInventoryCard(
                portionLabel: 'Regular Karne',
                gramLabel: '250 Grams / Pack',
                srpLabel: '₱130 Single · Bilao Base',
                remainingPcs: remaining250g,
                producedPcs: produced250g,
                consumedToday: totalConsumedToday250g,
                consumedBatch: totalConsumedBatch250g,
                consumedMonth: totalConsumedMonth250g,
                accentColor: AdminWebColors.accent,
                extraDetail: 'Branch: $posUsedToday250g pcs · Bilao: $bilaoUsedToday250g pcs',
              );

              final card300g = _buildPortionInventoryCard(
                portionLabel: 'Medium Karne',
                gramLabel: '300 Grams / Pack',
                srpLabel: '₱160 Medium Solo',
                remainingPcs: remaining300g,
                producedPcs: produced300g,
                consumedToday: totalConsumedToday300g,
                consumedBatch: totalConsumedBatch300g,
                consumedMonth: totalConsumedMonth300g,
                accentColor: AdminWebColors.accent,
                extraDetail: 'Store Sales: $posUsedToday300g pcs today',
              );

              final card400g = _buildPortionInventoryCard(
                portionLabel: 'Buy 1 Take 1 (B1T1)',
                gramLabel: '400 Grams Jumbo Pack',
                srpLabel: '₱210 B1T1 Jumbo',
                remainingPcs: remaining400g,
                producedPcs: produced400g,
                consumedToday: totalConsumedToday400g,
                consumedBatch: totalConsumedBatch400g,
                consumedMonth: totalConsumedMonth400g,
                accentColor: AdminWebColors.accent,
                extraDetail: 'Store Sales: $posUsedToday400g pcs today',
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: card250g),
                    const SizedBox(width: 12),
                    Expanded(child: card300g),
                    const SizedBox(width: 12),
                    Expanded(child: card400g),
                  ],
                );
              }

              return Column(
                children: [
                  card250g,
                  const SizedBox(height: 12),
                  card300g,
                  const SizedBox(height: 12),
                  card400g,
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // CONSOLIDATED GRAND TOTAL BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AdminWebColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminWebColors.border),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.summarize_rounded, size: 16, color: AdminWebColors.accent),
                    SizedBox(width: 6),
                    Text(
                      'CONSOLIDATED TOTAL (LAHAT NG SUKAT):',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AdminWebColors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                _grandStatPill('Cut: $grandProduced PCS', AdminWebColors.accent),
                _grandStatPill('Today: $grandConsumedToday PCS', AdminWebColors.accent),
                _grandStatPill('Batch Consumed: $grandConsumedBatch PCS', AdminWebColors.accentDark),
                _grandStatPill('Month-to-Date: $grandConsumedMonth PCS', AdminWebColors.textSecondary),
                _grandStatPill('Total Remaining: $grandRemaining PCS', AdminWebColors.accent, isHighlight: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortionInventoryCard({
    required String portionLabel,
    required String gramLabel,
    required String srpLabel,
    required int remainingPcs,
    required int producedPcs,
    required int consumedToday,
    required int consumedBatch,
    required int consumedMonth,
    required Color accentColor,
    String? extraDetail,
  }) {
    final bool isLowStock = remainingPcs <= 20;
    final bool isOutOfStock = remainingPcs == 0;

    final Color statusColor = isOutOfStock
        ? AdminWebColors.error
        : (isLowStock ? AdminWebColors.warning : AdminWebColors.accent);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.kebab_dining_rounded, color: accentColor, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        portionLabel.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: AdminWebColors.textPrimary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        gramLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AdminWebColors.surfaceTint,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AdminWebColors.border),
                ),
                child: Text(
                  srpLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AdminWebColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Hero Remaining Stock Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REMAINING IN WAREHOUSE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$remainingPcs PCS',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isOutOfStock ? 'OUT OF STOCK' : (isLowStock ? 'LOW STOCK' : 'AVAILABLE'),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Detail rows
          _portionStatRow('Total Cut (Gawa ng Warehouse):', '$producedPcs pcs', isBold: true),
          const SizedBox(height: 4),
          _portionStatRow('Consumed Today (Araw na Ito):', '$consumedToday pcs', color: AdminWebColors.accent),
          if (extraDetail != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                extraDetail,
                style: const TextStyle(fontSize: 10, color: AdminWebColors.textSecondary, fontStyle: FontStyle.italic),
              ),
            ),
          ],
          const SizedBox(height: 4),
          _portionStatRow('Consumed (Simula ng Batch):', '$consumedBatch pcs', color: AdminWebColors.accentDark),
          const SizedBox(height: 4),
          _portionStatRow('Total Monthly Sales (Buong Buwan):', '$consumedMonth pcs', color: AdminWebColors.textSecondary),
        ],
      ),
    );
  }

  Widget _portionStatRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: AdminWebColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: color ?? AdminWebColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _grandStatPill(String text, Color color, {bool isHighlight = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isHighlight ? 10 : 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlight ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: isHighlight ? 1.0 : 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: isHighlight ? Colors.white : color,
        ),
      ),
    );
  }

  Widget _buildBranchStockTab() {
    return Column(
      children: [
        // Informational header banner explaining automated allocation + RESTOCK button
        LayoutBuilder(
          builder: (context, headerConstraints) {
            final actionButtons = Wrap(
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
            );

            return Align(
              alignment: Alignment.centerRight,
              child: actionButtons,
            );
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 76),
                  itemCount: (_branchMeatStocks.length - (_stocksPage * _pageSize)).clamp(0, _pageSize),
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final s = _branchMeatStocks[(_stocksPage * _pageSize) + index];
                    return GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: LayoutBuilder(
                        builder: (context, cardConstraints) {
                          final isWideCard = cardConstraints.maxWidth >= 720;

                          final avatarWidget = CircleAvatar(
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
                          );

                          final nameAndStatusRow = Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.branchName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: s.isClosed ? const Color(0xFF64748B) : AdminWebColors.textPrimary,
                                  ),
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
                          );

                          final metricsWrap = Wrap(
                            spacing: 6,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                s.isClosed
                                    ? '0 / 0 MEAT PCS'
                                    : ' /  MEAT PCS',
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
                          );

                          final actionButtons = [
                            if (s.isClosed)
                              ElevatedButton.icon(
                                onPressed: () => _toggleBranchOpenStatus(s, shouldOpen: true),
                                icon: const Icon(Icons.lock_open_rounded, size: 14),
                                label: const Text('OPEN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                          ];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isWideCard)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    avatarWidget,
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          nameAndStatusRow,
                                          const SizedBox(height: 4),
                                          metricsWrap,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        actionButtons[0],
                                        const SizedBox(width: 8),
                                        actionButtons[1],
                                        const SizedBox(width: 8),
                                        actionButtons[2],
                                      ],
                                    ),
                                  ],
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        avatarWidget,
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              nameAndStatusRow,
                                              const SizedBox(height: 4),
                                              metricsWrap,
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: actionButtons,
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              // Row 1: Meat portions (250g Regular, 300g Medium, 400g B1T1)
                              Row(
                                children: [
                                  Expanded(child: _meatVariantChip('250g Regular', ' /  pcs', isClosed: s.isClosed)),
                                  const SizedBox(width: 6),
                                  Expanded(child: _meatVariantChip('300g Medium', ' /  pcs', isClosed: s.isClosed)),
                                  const SizedBox(width: 6),
                                  Expanded(child: _meatVariantChip('400g B1T1', ' /  pcs', isClosed: s.isClosed)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Row 2: Supplies (Mayo, Styro, Toyo)
                              Row(
                                children: [
                                  Expanded(child: _meatVariantChip('Mayo', ' /  pcs', isClosed: s.isClosed)),
                                  const SizedBox(width: 6),
                                  Expanded(child: _meatVariantChip('Styro Box', ' /  pcs', isClosed: s.isClosed)),
                                  const SizedBox(width: 6),
                                  Expanded(child: _meatVariantChip('Toyo', ' /  pcs', isClosed: s.isClosed)),
                                ],
                              ),
                            ],
                          );
                        },
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
        const Text(
          'Packaging & Supply Requests',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminWebColors.textPrimary),
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

