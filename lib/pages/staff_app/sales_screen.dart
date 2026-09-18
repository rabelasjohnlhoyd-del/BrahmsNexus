import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../../models/branch.dart';
import '../../models/branch_daily_inventory.dart';
import '../../models/branch_meat_inventory.dart';
import '../../models/sales_record.dart';
import '../../services/assignment_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../auth/mock_accounts.dart';
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
  BranchDailyInventory? _todayInventory;
  BranchMeatStock? _branchMeatStock;
  SalesRecord? _todaySalesRecord;
  String _currentBranchId = 'br1';
  String _currentBranchName = 'Brgy. Gatid, Sta. Cruz';
  StreamSubscription<BranchDailyInventory?>? _inventorySub;
  StreamSubscription<List<BranchMeatStock>>? _meatStocksSub;
  StreamSubscription<SalesRecord?>? _todaySalesSub;

  final _karneController = TextEditingController(); // Regular 250g
  final _mayoController = TextEditingController();
  final _styroController = TextEditingController();
  final _toyoController = TextEditingController();
  final _mediumController = TextEditingController(); // Medium 300g
  final _b1t1Controller = TextEditingController(); // B1T1 400g

  bool _submitted = false;

  int get _allocatedRegular {
    final verified = _todayInventory?.actualReceived?.regular;
    if (verified != null && verified > 0) return verified;
    return _branchMeatStock?.regular250gRemaining ?? 20;
  }

  int get _allocatedMedium {
    final verified = _todayInventory?.actualReceived?.medium;
    if (verified != null && verified > 0) return verified;
    return _branchMeatStock?.medium300gRemaining ?? 10;
  }

  int get _allocatedB1t1 {
    final verified = _todayInventory?.actualReceived?.b1t1;
    if (verified != null && verified > 0) return verified;
    return _branchMeatStock?.b1t1_400gRemaining ?? 10;
  }

  int get _allocatedMayo {
    final verified = _todayInventory?.actualReceived?.mayo;
    if (verified != null && verified > 0) return verified;
    return _allocated.mayo > 0 ? _allocated.mayo : 40;
  }

  int get _allocatedToyo {
    final verified = _todayInventory?.actualReceived?.toyo;
    if (verified != null && verified > 0) return verified;
    return _allocated.toyo > 0 ? _allocated.toyo : 10;
  }

  int get _allocatedStyro {
    final verified = _todayInventory?.actualReceived?.styro;
    if (verified != null && verified > 0) return verified;
    return _allocated.styro > 0 ? _allocated.styro : 40;
  }

  @override
  void initState() {
    super.initState();
    _setupBranchAndStreams();
    AssignmentService.changeNotifier.addListener(_onAssignmentChanged);
    _karneController.addListener(_onFieldChanged);
    _mediumController.addListener(_onFieldChanged);
    _b1t1Controller.addListener(_onFieldChanged);
    _mayoController.addListener(_onFieldChanged);
    _toyoController.addListener(_onFieldChanged);
    _styroController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  void _onAssignmentChanged() {
    if (mounted) {
      _setupBranchAndStreams();
    }
  }

  void _setupBranchAndStreams() {
    String assignedBranchName = AssignmentService.getAssignedBranch(AuthService.currentUsername);
    if (assignedBranchName.isEmpty) {
      final mock = kMockAccounts[AuthService.currentUsername.toLowerCase()];
      if (mock != null && mock.branchName.isNotEmpty) {
        assignedBranchName = mock.branchName;
      }
    }
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
      if (mounted) {
        setState(() {
          _todayInventory = inv;
          if (inv != null) {
            _allocated = inv.allocated;
          }
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

    _todaySalesSub?.cancel();
    _todaySalesSub = FirestoreService.watchTodayBranchSales(
      branchId: matchedBranch.id,
      date: DateTime.now(),
    ).listen((sales) {
      if (mounted) {
        setState(() {
          _todaySalesRecord = sales;
          if (sales != null) {
            _submitted = true;
            // Pre-fill controllers with the submitted remaining stock
            final rs = sales.remainingStock;
            if (rs != null) {
              _karneController.text = rs.regular.toString();
              _mediumController.text = rs.medium.toString();
              _b1t1Controller.text = rs.b1t1.toString();
              _mayoController.text = rs.mayo.toString();
              _toyoController.text = rs.toyo.toString();
              _styroController.text = rs.styro.toString();
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    AssignmentService.changeNotifier.removeListener(_onAssignmentChanged);
    _karneController.removeListener(_onFieldChanged);
    _mediumController.removeListener(_onFieldChanged);
    _b1t1Controller.removeListener(_onFieldChanged);
    _mayoController.removeListener(_onFieldChanged);
    _toyoController.removeListener(_onFieldChanged);
    _styroController.removeListener(_onFieldChanged);
    _inventorySub?.cancel();
    _meatStocksSub?.cancel();
    _todaySalesSub?.cancel();
    _karneController.dispose();
    _mayoController.dispose();
    _styroController.dispose();
    _toyoController.dispose();
    _mediumController.dispose();
    _b1t1Controller.dispose();
    super.dispose();
  }

  // Returns null if text is empty, meaning the cook has not entered this field yet
  int? _parseOrNull(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  // Computation always available with real-time updates
  DailySalesComputation get _computation {
    return DailySalesComputation(
      allocatedRegular: _allocatedRegular,
      allocatedMedium: _allocatedMedium,
      allocatedB1t1: _allocatedB1t1,
      allocatedMayo: _allocatedMayo,
      allocatedToyo: _allocatedToyo,
      allocatedStyro: _allocatedStyro,
      remainingRegular: _parseOrNull(_karneController),
      remainingMedium: _parseOrNull(_mediumController),
      remainingB1t1: _parseOrNull(_b1t1Controller),
      remainingMayo: _parseOrNull(_mayoController),
      remainingToyo: _parseOrNull(_toyoController),
      remainingStyro: _parseOrNull(_styroController),
    );
  }

  bool get _isInventoryVerified =>
      _todayInventory != null &&
      _todayInventory!.status != InventoryVerificationStatus.pending;

  // Show the computation card only once remaining stock has been entered
  bool get _hasAnyInput =>
      _karneController.text.trim().isNotEmpty ||
      _mediumController.text.trim().isNotEmpty ||
      _b1t1Controller.text.trim().isNotEmpty ||
      _mayoController.text.trim().isNotEmpty ||
      _styroController.text.trim().isNotEmpty ||
      _toyoController.text.trim().isNotEmpty;

  /// Confirms before actually submitting — sales figures feed directly
  /// into payroll, so a single accidental tap on "Submit Sales"
  /// shouldn't be enough to lock them in.
  Future<void> _confirmSubmit() async {
    if (!_isInventoryVerified) {
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Inventory Verification Required'),
          content: const Text(
            'Kailangan po munang sagutan ang "Verify: Count What You Actually Received" sa Home tab bago mag-submit ng sales.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final b1t1Rem = _parseOrNull(_b1t1Controller) ?? 0;
    if (b1t1Rem % 2 != 0) {
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Invalid B1T1 Count'),
          content: const Text(
            'Bawal po ang odd number (gaya ng 1, 3, 5) sa B1T1 remaining stock dahil laging pares o tig-2 orders ang B1T1. Paki-check o ayusin po ang bilang.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final computation = _computation;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Submit Sales?'),
        content: Text(
          computation.hasDiscrepancy
              ? 'A discrepancy was found: Meat used (${computation.totalKarneUsed} pcs) '
                  'does not match Styro used (${computation.styroUsed}). '
                  'The Owner will be notified. Submit anyway?'
              : 'Total Orders: ${computation.totalOrders} · '
                  'Gross: \u20b1${computation.totalRevenue} · '
                  'Salary: \u20b1${computation.salary} · '
                  'Cash Remit: \u20b1${computation.cashRemit}. This '
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
      employeeName: AuthService.currentUser?.fullName ?? AuthService.currentUsername,
      date: DateTime.now(),
      portionsSold: computation.totalOrders,
      commissionRatePerPortion: 5.0,
      totalSalesAmount: computation.totalRevenue.toDouble(),
      wage: computation.salary.toDouble(),
      regularSold: computation.regularSold,
      mediumSold: computation.mediumSold,
      b1t1OrdersSold: computation.b1t1OrdersSold,
      remainingStock: ActualReceivedCounts(
        mayo: int.tryParse(_mayoController.text) ?? 0,
        toyo: int.tryParse(_toyoController.text) ?? 0,
        styro: int.tryParse(_styroController.text) ?? 0,
        regular: int.tryParse(_karneController.text) ?? 0,
        medium: int.tryParse(_mediumController.text) ?? 0,
        b1t1: int.tryParse(_b1t1Controller.text) ?? 0,
      ),
    );
    final success = await FirestoreService.submitDailySales(record);

    if (!mounted) return;
    if (!success) {
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error Submitting Sales'),
          content: const Text(
            'Failed to save sales report to Firestore. Please check your internet connection or verify Firestore rules/permissions.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(
          computation.hasDiscrepancy
              ? 'Submitted, but a discrepancy was flagged (meat vs. styro) — the Owner will be notified.'
              : 'Sales submitted successfully! Cash remit: ₱${computation.cashRemit}',
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

                final reg = _allocatedRegular;
                final med = _allocatedMedium;
                final b1t1 = _allocatedB1t1;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const PageScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Mayo → Toyo → Medium
                      Row(
                        children: [
                          tile('Mayo', '$_allocatedMayo', dark: true),
                          const SizedBox(width: 12),
                          tile('Toyo', '$_allocatedToyo', dark: true),
                          const SizedBox(width: 12),
                          tile('Medium', '$med pcs'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Bottom row: Styro → Regular → B1T1
                      Row(
                        children: [
                          tile('Styro', '$_allocatedStyro'),
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
            if (!_isInventoryVerified && !_submitted) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
                ),
                child: const Row(
                  children: [
                    Icon(CupertinoIcons.exclamationmark_shield_fill, color: AppColors.warning, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Naka-lock po muna ang remaining stock. '
                        'Paki-verify po muna ang "Count What You Actually Received" sa Home tab bago mag-input ng natirang paninda.',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (ctx, constraints) {
                final cardW = (constraints.maxWidth - 12) / 2;
                Widget itile(String label, TextEditingController ctrl) => SizedBox(
                  width: cardW,
                  child: StaffInputTile(
                    label: label,
                    controller: ctrl,
                    enabled: !_submitted && _isInventoryVerified,
                    onChanged: () => setState(() {}),
                  ),
                );
                // B1T1 tile enforces even numbers (2 pcs per order)
                final b1t1tile = SizedBox(
                  width: cardW,
                  child: StaffInputTile(
                    label: 'B1T1',
                    controller: _b1t1Controller,
                    enabled: !_submitted && _isInventoryVerified,
                    onChanged: () => setState(() {}),
                    step: 2,
                    evenOnly: true,
                  ),
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
                        b1t1tile,
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
                          'Discrepancy found: Meat usage '
                          '(${computation.totalKarneUsed} pcs) does not match '
                          'Styro usage (${computation.styroUsed}). '
                          'The Owner will be notified upon submission.',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _computedRow(
                      'Total Orders',
                      '${computation.totalOrders}',
                      isHeader: true,
                    ),
                    const _CupertinoDivider(),
                    if (computation.regularSold > 0)
                      _computedRow(
                        'Regular',
                        '₱${computation.regularRevenue.toStringAsFixed(0)}',
                        subtitle: '130 × ${computation.regularSold}',
                      ),
                    if (computation.mediumSold > 0)
                      _computedRow(
                        'Medium',
                        '₱${computation.mediumRevenue.toStringAsFixed(0)}',
                        subtitle: '160 × ${computation.mediumSold}',
                      ),
                    if (computation.b1t1OrdersSold > 0)
                      _computedRow(
                        'B1T1',
                        '₱${computation.b1t1Revenue.toStringAsFixed(0)}',
                        subtitle: '210 × ${computation.b1t1OrdersSold}',
                      ),
                    if (computation.totalOrders == 0)
                      _computedRow(
                        'No Orders Sold',
                        '₱0',
                        subtitle: 'Remaining stock matches allocation',
                      ),
                    const _CupertinoDivider(),
                    _computedRow(
                      'TOTAL',
                      '₱${computation.totalRevenue.toStringAsFixed(0)}',
                      isSubtotal: true,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Deduction',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _computedRow(
                      'Less Salary',
                      '- ₱${computation.salary.toStringAsFixed(0)}',
                      subtitle: '${computation.salary} salary (${computation.weightedOrders} weighted orders)',
                      isNegative: true,
                    ),
                    const _CupertinoDivider(),
                    _computedRow(
                      'TOTAL CASH REMIT',
                      '₱${computation.cashRemit.toStringAsFixed(0)}',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (_submitted)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.checkmark_seal_fill, color: AppColors.success, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Sales Report Locked & Submitted',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_todaySalesRecord != null)
                      Text(
                        'Total Portions Sold: ${_todaySalesRecord!.portionsSold} · Total Remit: ₱${_todaySalesRecord!.expectedCashRemittance.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentDark,
                        ),
                      ),
                    const SizedBox(height: 4),
                    const Text(
                      'Na-record na ang sales para sa araw na ito. '
                      'Kusang mag-re-reset ang form bukas sa panibagong araw ng operasyon.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
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

  Widget _computedRow(
    String label,
    String value, {
    bool isTotal = false,
    bool isSubtotal = false,
    bool isHeader = false,
    bool isNegative = false,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isTotal ? 15 : (isHeader || isSubtotal ? 14.5 : 13.5),
                    color: (isTotal || isHeader || isSubtotal) ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: (isTotal || isHeader || isSubtotal) ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: isTotal ? 20 : (isSubtotal ? 16 : (isHeader ? 15 : 14)),
              color: isNegative
                  ? AppColors.error
                  : (isTotal
                      ? AppColors.accent
                      : (isSubtotal || isHeader ? AppColors.textPrimary : AppColors.textPrimary)),
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
