import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../../models/branch.dart';
import '../../models/branch_daily_inventory.dart';
import '../../models/branch_meat_inventory.dart';
import '../../models/sales_record.dart';
import '../../services/assignment_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_stat_tile.dart';
import '../../widgets/staff_top_actions.dart';

/// Sales tab — no need to re-enter the allocated inventory (that came
/// from Homepage already); this just needs the remaining stock at the
/// end of the day. Orders sold, Sales, Wage (Owner's tiered rate), and
/// Net Total are all computed automatically. There's also a
/// cross-check against Styro usage to catch discrepancies early —
/// this directly addresses Owner's old problem of mismatches being
/// hard to track down.
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // Default fallback allocation
  static const _defaultAllocated =
      InventoryCounts(karne: 40, mayo: 40, styro: 40, toyo: 10);

  InventoryCounts _allocated = _defaultAllocated;
  BranchMeatStock? _branchMeatStock;
  String _currentBranchId = 'br1';
  String _currentBranchName = 'Brgy. Gatid, Sta. Cruz';
  StreamSubscription<BranchDailyInventory?>? _inventorySub;
  StreamSubscription<List<BranchMeatStock>>? _meatStocksSub;

  // Default price base for regular Sisig portion
  static const double _pricePerOrder = 130;

  final _karneController = TextEditingController(); // Regular 250g
  final _mayoController = TextEditingController();
  final _styroController = TextEditingController();
  final _toyoController = TextEditingController();
  final _mediumController = TextEditingController(); // Medium 300g
  final _b1t1Controller = TextEditingController(); // B1T1 400g

  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _setupBranchAndStreams();
    AssignmentService.changeNotifier.addListener(_onAssignmentChanged);
  }

  void _onAssignmentChanged() {
    if (mounted) {
      _setupBranchAndStreams();
    }
  }

  void _setupBranchAndStreams() {
    final assignedBranchName = AssignmentService.getAssignedBranch(AuthService.currentUsername);
    Branch? matchedBranch;
    if (assignedBranchName.isNotEmpty) {
      for (final b in kSampleBranches) {
        if (b.fullName.toLowerCase().contains(assignedBranchName.toLowerCase()) ||
            b.name.toLowerCase().contains(assignedBranchName.toLowerCase()) ||
            assignedBranchName.toLowerCase().contains(b.name.toLowerCase())) {
          matchedBranch = b;
          break;
        }
      }
    }
    matchedBranch ??= kSampleBranches.first;
    _currentBranchId = matchedBranch.id;
    _currentBranchName = matchedBranch.fullName;

    _inventorySub?.cancel();
    _inventorySub = FirestoreService.watchTodayBranchInventory(
      branchId: matchedBranch.id,
      branchName: matchedBranch.fullName,
      date: DateTime.now(),
    ).listen((inv) {
      if (mounted && inv != null) {
        setState(() {
          _allocated = inv.allocated;
        });
      }
    });

    _meatStocksSub?.cancel();
    _meatStocksSub = FirestoreService.watchBranchMeatStocks().listen((stocks) {
      if (mounted) {
        final match = stocks.firstWhere(
          (s) => s.branchId == _currentBranchId,
          orElse: () => BranchMeatStock.defaultForBranch(matchedBranch!),
        );
        setState(() {
          _branchMeatStock = match;
        });
      }
    });
  }

  @override
  void dispose() {
    AssignmentService.changeNotifier.removeListener(_onAssignmentChanged);
    _inventorySub?.cancel();
    _meatStocksSub?.cancel();
    _karneController.dispose();
    _mayoController.dispose();
    _styroController.dispose();
    _toyoController.dispose();
    _mediumController.dispose();
    _b1t1Controller.dispose();
    super.dispose();
  }

  // Treat empty text as 0 so staff can submit even when remaining is 0
  int _parseOrZero(TextEditingController c) =>
      int.tryParse(c.text.trim()) ?? 0;

  // Computation always available (empty fields = 0 remaining)
  DailySalesComputation get _computation {
    final regular = _parseOrZero(_karneController);
    final medium = _parseOrZero(_mediumController);
    final b1t1 = _parseOrZero(_b1t1Controller);
    final totalKarne = regular + medium + b1t1;
    return DailySalesComputation(
      allocated: _allocated,
      remaining: InventoryCounts(
        karne: totalKarne,
        mayo: _parseOrZero(_mayoController),
        styro: _parseOrZero(_styroController),
        toyo: _parseOrZero(_toyoController),
      ),
      pricePerOrder: _pricePerOrder,
    );
  }

  // Show the computation card only once at least one field is non-empty
  bool get _hasAnyInput =>
      _karneController.text.isNotEmpty ||
      _mayoController.text.isNotEmpty ||
      _styroController.text.isNotEmpty ||
      _toyoController.text.isNotEmpty ||
      _mediumController.text.isNotEmpty ||
      _b1t1Controller.text.isNotEmpty;

  /// Confirms before actually submitting — sales figures feed directly
  /// into payroll, so a single accidental tap on "Submit Sales"
  /// shouldn't be enough to lock them in.
  Future<void> _confirmSubmit() async {
    final computation = _computation;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Submit Sales?'),
        content: Text(
          computation.hasDiscrepancy
              ? 'A discrepancy was found between Karne and Styro usage. '
                  'The Owner will be notified. Submit anyway?'
              : 'Orders Sold: ${computation.ordersSold} · Net Total: '
                  '\u20b1${computation.netTotal.toStringAsFixed(0)}. This '
                  "can't be edited once submitted.",
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            isDestructiveAction: computation.hasDiscrepancy,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    _submit();
  }

  Future<void> _submit() async {
    final computation = _computation;

    setState(() => _submitted = true);

    // Save to Firestore daily_sales collection
    final record = SalesRecord(
      id: '',
      branchId: _currentBranchId,
      branchName: _currentBranchName,
      employeeId: AuthService.currentUsername,
      employeeName: AuthService.currentUsername,
      date: DateTime.now(),
      portionsSold: computation.ordersSold,
      commissionRatePerPortion: 5.0,
      totalSalesAmount: computation.salesAmount,
      remainingStock: ActualReceivedCounts(
        mayo: int.tryParse(_mayoController.text) ?? 0,
        toyo: int.tryParse(_toyoController.text) ?? 0,
        styro: int.tryParse(_styroController.text) ?? 0,
        regular: int.tryParse(_karneController.text) ?? 0,
        medium: int.tryParse(_mediumController.text) ?? 0,
        b1t1: int.tryParse(_b1t1Controller.text) ?? 0,
      ),
    );
    await FirestoreService.submitDailySales(record);

    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(
          computation.hasDiscrepancy
              ? 'Submitted, but a discrepancy was flagged — the Owner '
                  'will be notified.'
              : 'Sales submitted successfully!',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final computation = _computation;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Sales',
        trailing: StaffTopActions(),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const StaffSectionHeader(
              label: "Today's Inventory",
              icon: CupertinoIcons.cube_box_fill,
              subtitle: 'Reference only — confirmed back on Home',
              large: true,
            ),
            const SizedBox(height: 14),
            // Horizontally swipeable inventory grid
            // Row 1: Mayo → Toyo → Medium (300g)
            // Row 2: Styro → Regular (250g) → B1T1 (400g)
            LayoutBuilder(
              builder: (ctx, constraints) {
                final cardW = (constraints.maxWidth - 12) / 2;
                Widget tile(String label, String value, {bool dark = false}) {
                  return SizedBox(
                    width: cardW,
                    child: StaffDisplayTile(label: label, value: value, dark: dark),
                  );
                }

                final reg = _branchMeatStock?.regular250gRemaining ?? 20;
                final med = _branchMeatStock?.medium300gRemaining ?? 10;
                final b1t1 = _branchMeatStock?.b1t1_400gRemaining ?? 10;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const PageScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Mayo → Toyo → Medium
                      Row(
                        children: [
                          tile('Mayo', '${_allocated.mayo}', dark: true),
                          const SizedBox(width: 12),
                          tile('Toyo', '${_allocated.toyo}', dark: true),
                          const SizedBox(width: 12),
                          tile('Medium', '$med pcs'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Bottom row: Styro → Regular → B1T1
                      Row(
                        children: [
                          tile('Styro', '${_allocated.styro}'),
                          const SizedBox(width: 12),
                          tile('Regular', '$reg pcs'),
                          const SizedBox(width: 12),
                          tile('B1T1', '$b1t1 pcs'),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 26),
            const StaffSectionHeader(
              label: 'Remaining Stock',
              icon: CupertinoIcons.archivebox_fill,
              subtitle: 'What\'s left at the end of the day',
              large: true,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (ctx, constraints) {
                final cardW = (constraints.maxWidth - 12) / 2;
                Widget itile(String label, TextEditingController ctrl) => SizedBox(
                  width: cardW,
                  child: StaffInputTile(label: label, controller: ctrl, onChanged: () => setState(() {})),
                );
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const PageScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        itile('Mayo', _mayoController),
                        const SizedBox(width: 12),
                        itile('Toyo', _toyoController),
                        const SizedBox(width: 12),
                        itile('Medium', _mediumController),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        itile('Styro', _styroController),
                        const SizedBox(width: 12),
                        itile('Regular', _karneController),
                        const SizedBox(width: 12),
                        itile('B1T1', _b1t1Controller),
                      ]),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            if (_hasAnyInput) ...[ 
              if (computation.hasDiscrepancy)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Discrepancy found: Karne usage '
                          '(${computation.karneUsed}) does not match '
                          'Styro usage (${computation.styroUsed}). '
                          'The Owner will be notified.',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const StaffSectionHeader(
                label: 'Computation',
                icon: CupertinoIcons.money_dollar_circle_fill,
              ),
              const SizedBox(height: 10),
              StaffCard(
                child: Column(
                  children: [
                    _computedRow('Orders Sold', '${computation.ordersSold}'),
                    _computedRow(
                      'Gross Sales',
                      '₱${computation.salesAmount.toStringAsFixed(0)}',
                      subtitle: '${computation.ordersSold} × ₱${_pricePerOrder.toStringAsFixed(0)}',
                    ),
                    _computedRow(
                      'Daily Wage',
                      '- ₱${computation.wage.toStringAsFixed(0)}',
                      isNegative: true,
                    ),
                    const _CupertinoDivider(),
                    _computedRow(
                      'EXPECTED CASH',
                      '₱${computation.netTotal.toStringAsFixed(0)}',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (_submitted)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.check_mark_circled_solid, color: AppColors.success, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Sales Submitted Successfully',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              )
            else
              StaffButton(
                label: 'Submit Sales',
                icon: CupertinoIcons.cloud_upload_fill,
                onPressed: _confirmSubmit,
              ),
            if (!_hasAnyInput)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.pastelBrown.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.info_circle_fill,
                          color: AppColors.accent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Fill in remaining stock counts above to see '
                          'the computation.',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _computedRow(String label, String value, {bool isTotal = false, bool isNegative = false, String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isTotal ? 15 : 14,
                  color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: isTotal ? 20 : 15,
              color: isNegative 
                  ? AppColors.error 
                  : (isTotal ? AppColors.accent : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple divider — Cupertino has no built-in Divider widget.
class _CupertinoDivider extends StatelessWidget {
  const _CupertinoDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      height: 1,
      color: AppColors.border,
    );
  }
}
