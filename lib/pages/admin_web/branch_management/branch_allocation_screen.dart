import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/branch.dart';
import '../../../models/branch_meat_inventory.dart';
import '../../../models/meat_dispatch.dart';
import '../../../models/branch_assignment.dart';
import '../../../services/assignment_service.dart';
import '../../../services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/supabase_service.dart';
import '../../../services/system_busy_coordinator.dart';
import '../admin_web_colors.dart';
import '../admin_web_widgets/admin_pagination_bar.dart';
import '../admin_web_widgets/glass_card.dart';
import '../inventory/record_transfer_screen.dart';

/// Branch Allocation Screen — Manages meat and supply allocations for each branch.
class BranchAllocationScreen extends StatefulWidget {
  const BranchAllocationScreen({super.key});

  @override
  State<BranchAllocationScreen> createState() => _BranchAllocationScreenState();
}

class _BranchAllocationScreenState extends State<BranchAllocationScreen> {
  StreamSubscription<List<BranchMeatStock>>? _meatStocksSub;

  int _stocksPage = 0;
  static const int _pageSize = 6;

  List<BranchMeatStock> _branchMeatStocks = kSampleBranches
      .map((b) => BranchMeatStock.defaultForBranch(b))
      .toList();

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    FirestoreService.seedDefaultBranchMeatStocksIfEmpty();

    _meatStocksSub = FirestoreService.watchBranchMeatStocks().listen((stocks) {
      if (!mounted) return;
      setState(() {
        _branchMeatStocks = stocks;
      });
    });
  }

  @override
  void dispose() {
    _meatStocksSub?.cancel();
    super.dispose();
  }

  void _navigateToRecordTransfer() async {
    await showDialog<MeatDispatch>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const RecordTransferDialog(),
    );
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
                          style: TextStyle(fontSize: 11.5, color: AdminWebColors.accent, height: 1.3),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('SUPPLIES (PCS)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AdminWebColors.accent)),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
            child: const Text('CANCEL', style: TextStyle(color: AdminWebColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminWebColors.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final r = int.tryParse(regCtrl.text) ?? stock.regular250gTotal;
              final m = int.tryParse(medCtrl.text) ?? stock.medium300gTotal;
              final b = int.tryParse(b1t1Ctrl.text) ?? stock.b1t1_400gTotal;
              final my = int.tryParse(mayoCtrl.text) ?? stock.mayoTotal;
              final st = int.tryParse(styroCtrl.text) ?? stock.styroTotal;
              final ty = int.tryParse(toyoCtrl.text) ?? stock.toyoTotal;

              final updated = stock.copyWith(
                regular250gTotal: r,
                regular250gRemaining: r,
                medium300gTotal: m,
                medium300gRemaining: m,
                b1t1_400gTotal: b,
                b1t1_400gRemaining: b,
                mayoTotal: my,
                mayoRemaining: my,
                styroTotal: st,
                styroRemaining: st,
                toyoTotal: ty,
                toyoRemaining: ty,
                date: DateTime.now(),
              );

              Navigator.pop(ctx);
              await FirestoreService.saveBranchMeatStock(updated);
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('SUPPLIES PER BRANCH (PCS)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AdminWebColors.accent)),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
            child: const Text('CANCEL', style: TextStyle(color: AdminWebColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminWebColors.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final r = int.tryParse(regCtrl.text) ?? 20;
              final m = int.tryParse(medCtrl.text) ?? 10;
              final b = int.tryParse(b1t1Ctrl.text) ?? 10;
              final my = int.tryParse(mayoCtrl.text) ?? 40;
              final st = int.tryParse(styroCtrl.text) ?? 40;
              final ty = int.tryParse(toyoCtrl.text) ?? 10;

              Navigator.pop(ctx);
              setState(() => _isProcessing = true);
              SystemBusyCoordinator.setBusy(true);

              try {
                for (final s in _branchMeatStocks) {
                  final updated = s.copyWith(
                    regular250gTotal: r,
                    regular250gRemaining: r,
                    medium300gTotal: m,
                    medium300gRemaining: m,
                    b1t1_400gTotal: b,
                    b1t1_400gRemaining: b,
                    mayoTotal: my,
                    mayoRemaining: my,
                    styroTotal: st,
                    styroRemaining: st,
                    toyoTotal: ty,
                    toyoRemaining: ty,
                    date: DateTime.now(),
                  );
                  await FirestoreService.saveBranchMeatStock(updated);
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Allocation updated for all branches successfully!'),
                      backgroundColor: AdminWebColors.success,
                    ),
                  );
                }
              } finally {
                SystemBusyCoordinator.setBusy(false);
                if (mounted) setState(() => _isProcessing = false);
              }
            },
            child: const Text('APPLY TO ALL'),
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
      } catch (_) {}

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
              'Hindi maaaring i-open ang ${stock.branchName} dahil nai-save na ang deployment assignments ngayong araw. Bawal baguhin ang estado ng branch upang maiwasan ang pagkagulo ng inventory at deployment data.',
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
              ? 'Are you sure you want to OPEN ${stock.branchName}?\n\nIts configured daily meat stock allocation will be restored.'
              : 'Are you sure you want to CLOSE ${stock.branchName}?\n\nAllocation will be set to 0 pcs.',
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
            child: Text(shouldOpen ? 'YES, OPEN' : 'YES, CLOSE'),
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              shouldOpen
                  ? '${stock.branchName} is now OPEN!'
                  : '${stock.branchName} is now CLOSED (0 pcs allocation).',
            ),
            backgroundColor: shouldOpen ? const Color(0xFF059669) : const Color(0xFFDC2626),
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
    return Container(
      color: AdminWebColors.background,
      padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 600 ? 12 : 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Buttons Bar
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Branches List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 76),
              itemCount: (_branchMeatStocks.length - (_stocksPage * _pageSize)).clamp(0, _pageSize),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final s = _branchMeatStocks[(_stocksPage * _pageSize) + index];
                return GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                : '${s.regular250gRemaining + s.medium300gRemaining + s.b1t1_400gRemaining} / ${s.regular250gTotal + s.medium300gTotal + s.b1t1_400gTotal} MEAT PCS',
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
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
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
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isClosed ? const Color(0xFF94A3B8) : AdminWebColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isClosed ? const Color(0xFF94A3B8) : AdminWebColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
