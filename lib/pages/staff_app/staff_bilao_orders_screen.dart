import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/bilao_order.dart';
import '../../models/branch.dart';
import '../../services/assignment_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/gemini_service.dart';
import '../../services/supabase_service.dart';
import '../../services/tutorial_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/guided_tour_overlay.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_top_actions.dart';
import 'daily_report_screen.dart';
import 'staff_shell.dart';

/// Screen for Branch Staff to monitor Bilao Orders assigned to or waiting
/// at their specific branch location.
///
/// Cards show minimal info (name, contact, package, current status).
/// Tap a card to view full details.
/// The + button on the branch header row opens the add-order form.
/// Orders are auto-completed when the driver submits delivery photo.
class StaffBilaoOrdersScreen extends StatefulWidget {
  const StaffBilaoOrdersScreen({
    super.key,
    this.branchId,
    this.branchName,
    this.isRootTab = true,
  });

  static final GlobalKey<StaffBilaoOrdersScreenState> globalKey = GlobalKey();

  final String? branchId;
  final String? branchName;
  final bool isRootTab;

  @override
  State<StaffBilaoOrdersScreen> createState() => StaffBilaoOrdersScreenState();
}

class StaffBilaoOrdersScreenState extends State<StaffBilaoOrdersScreen> {
  final GlobalKey _plusButtonKey = GlobalKey();
  final GlobalKey _filterTabsKey = GlobalKey();

  void startTour() {
    if (!mounted) return;
    GuidedTourOverlay.show(
      context: context,
      steps: [
        GuidedTourStep(
          targetKey: _filterTabsKey,
          roleBadge: 'BRANCH COOK ONBOARDING',
          title: '9. Bilao Orders Overview & Filters',
          instruction: 'PINDUTIN: I-tap ang "Pickup" o "Kitchen" filter tab.',
          explanation:
              'Dito mo makikita ang mga Bilao Orders para sa iyong branch. Naka-filter ang mga ito bilang Pickup (handa nang kunin), Kitchen (isinaalang-alang sa pagluluto), at Done.',
          tip: 'I-tap ang mga filter para mabilis mahanap ang order ng customer.',
          onTargetTapped: () {
            HapticFeedback.lightImpact();
          },
        ),
        GuidedTourStep(
          targetKey: _plusButtonKey,
          roleBadge: 'BRANCH COOK ONBOARDING',
          title: '10. Pagtatala ng Bagong Bilao Order',
          instruction: 'PINDUTIN: I-tap ang Plus (+) button sa kanang itaas.',
          explanation:
              'Kapag may customer na umorder ng Bilao sa iyong branch, i-tap ang Plus (+) button upang buksan ang Bagong Bilao Order form.',
          tip: 'Pindutin ang Plus (+) button upang buksan ang form at magpatuloy.',
          onTargetTapped: () {
            _showAddOrderSheet(isTourMode: true);
          },
        ),
      ],
      onCompleted: () => TutorialService.markTutorialSeen('bilao_spotlight'),
      onSkipped: () => TutorialService.markTutorialSeen('bilao_spotlight'),
    );
  }
  StreamSubscription<List<BilaoOrder>>? _ordersSub;
  final List<BilaoOrder> _orders = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _tabIndex = 0; // 0: All, 1: Completed

  String _currentBranchId = 'br1';
  String _currentBranchName = 'Brgy. Gatid, Sta. Cruz';

  @override
  void initState() {
    super.initState();
    _setupBranchAndStream();
    AssignmentService.changeNotifier.addListener(_onAssignmentChanged);
  }

  void _onAssignmentChanged() {
    if (mounted) _setupBranchAndStream();
  }

  void _setupBranchAndStream() {
    if (widget.branchId != null && widget.branchName != null) {
      _currentBranchId = widget.branchId!;
      _currentBranchName = widget.branchName!;
    } else {
      final username = AuthService.currentUsername;
      final currentUid = AuthService.currentUserId;
      var assignedBranchName = AssignmentService.getAssignedBranch(username);
      if (assignedBranchName.isEmpty && currentUid.isNotEmpty) {
        assignedBranchName = AssignmentService.getAssignedBranch(currentUid);
      }

      if (assignedBranchName.isNotEmpty) {
        _currentBranchName = assignedBranchName;
        final matchedBranch = kSampleBranches.firstWhere(
          (b) => b.name == assignedBranchName || b.fullName == assignedBranchName,
          orElse: () => kSampleBranches.first,
        );
        _currentBranchId = matchedBranch.id;
      }
    }

    _ordersSub?.cancel();
    _ordersSub = FirestoreService.watchBranchBilaoOrders(
      branchId: _currentBranchId,
      branchName: _currentBranchName,
    ).listen((orders) {
      if (mounted) {
        setState(() {
          _orders
            ..clear()
            ..addAll(orders);
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    AssignmentService.changeNotifier.removeListener(_onAssignmentChanged);
    _ordersSub?.cancel();
    super.dispose();
  }

  bool _isCompleted(BilaoOrder o) {
    return o.deliveryStatus == DeliveryStatus.completed ||
        o.deliveryStatus == DeliveryStatus.delivered;
  }

  bool _isActivePickup(BilaoOrder o) {
    if (_isCompleted(o)) return false;
    return o.preparationStatus == PreparationStatus.ready ||
        o.deliveryStatus == DeliveryStatus.outForDelivery;
  }

  bool _isInKitchen(BilaoOrder o) {
    if (_isCompleted(o) || _isActivePickup(o)) return false;
    return o.preparationStatus == PreparationStatus.pending ||
        o.preparationStatus == PreparationStatus.preparing;
  }

  List<BilaoOrder> get _filteredOrders {
    var list = _orders.where((o) {
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          o.customerName.toLowerCase().contains(q) ||
          o.contactNumber.toLowerCase().contains(q) ||
          (o.notes != null && o.notes!.toLowerCase().contains(q));

      bool matchesTab = true;
      if (_tabIndex == 0) {
        // Active: Ready at branch or arriving via driver
        matchesTab = _isActivePickup(o);
      } else if (_tabIndex == 1) {
        // Kitchen: In the commissary / kitchen
        matchesTab = _isInKitchen(o);
      } else if (_tabIndex == 2) {
        // Completed
        matchesTab = _isCompleted(o);
      } else {
        // All
        matchesTab = true;
      }

      return matchesSearch && matchesTab;
    }).toList();

    list.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));
    return list;
  }

  // ── Status helpers ──────────────────────────────────────────────────────────

  /// Returns the human-readable status label shown on the card.
  String _cardStatusLabel(BilaoOrder o) {
    if (_isCompleted(o)) {
      return 'Completed';
    }
    if (o.deliveryStatus == DeliveryStatus.outForDelivery) {
      return 'In Transit to Branch';
    }
    if (o.preparationStatus == PreparationStatus.ready) {
      return 'Ready for Pickup';
    }
    switch (o.preparationStatus) {
      case PreparationStatus.pending:
        return 'Pending Order';
      case PreparationStatus.preparing:
        return 'Preparing in Kitchen';
      case PreparationStatus.ready:
        return 'Ready for Pickup';
    }
  }

  Color _cardStatusColor(BilaoOrder o) {
    if (_isCompleted(o)) {
      return AppColors.success;
    }
    if (o.deliveryStatus == DeliveryStatus.outForDelivery) {
      return const Color(0xFF1976D2);
    }
    if (o.preparationStatus == PreparationStatus.ready) {
      return const Color(0xFFE65100);
    }
    switch (o.preparationStatus) {
      case PreparationStatus.pending:
        return AppColors.warning;
      case PreparationStatus.preparing:
        return AppColors.accent;
      case PreparationStatus.ready:
        return const Color(0xFFE65100);
    }
  }


  // ── Add Order Sheet ─────────────────────────────────────────────────────────

  void _showAddOrderSheet({bool isTourMode = false}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBilaoOrderSheet(
        branchId: _currentBranchId,
        branchName: _currentBranchName,
        isTourMode: isTourMode,
      ),
    );
  }

  // ── Details Dialog ──────────────────────────────────────────────────────────

  void _showOrderDetails(BilaoOrder order) {
    final statusLabel = _cardStatusLabel(order);
    final statusColor = _cardStatusColor(order);
    final isCompleted = _isCompleted(order);

    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(order.customerName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Contact: ${order.contactNumber}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Text(
              'Package: ${order.size.label} Bilao (${order.size.pax} Pax) × ${order.quantity}',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Text(
              'Total: \u20b1${order.totalAmount.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent),
            ),
            if (order.depositAmount > 0) ...[
              const SizedBox(height: 2),
              Text(
                'Deposit Paid: \u20b1${order.depositAmount.toStringAsFixed(0)} · Remaining COD: \u20b1${order.remainingBalance.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warning),
              ),
            ],
            const SizedBox(height: 8),
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              Text('Notes: ${order.notes}',
                  style: const TextStyle(
                      fontSize: 12, fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
            ],
            Text(
              'Schedule: ${order.scheduledDateTime.month}/${order.scheduledDateTime.day} at '
              '${order.scheduledDateTime.hour.toString().padLeft(2, '0')}:'
              '${order.scheduledDateTime.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            if (order.isBranchPickup) ...[
              const SizedBox(height: 4),
              Text(
                'Branch: ${order.pickupBranchName ?? _currentBranchName}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ] else if (order.deliveryAddress.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Delivery Address: ${order.deliveryAddress}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            if (!isCompleted) ...[
              const SizedBox(height: 6),
              Text(
                'Completion is automatic once the driver delivers.',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
              ),
            ],
            if (order.gcashProofUrl != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _viewProofPhoto(order.gcashProofUrl!, 'GCash Receipt Photo'),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.photo, size: 14, color: AppColors.accent),
                    SizedBox(width: 4),
                    Text('Tingnan ang GCash Proof Photo',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.accent,
                            decoration: TextDecoration.underline)),
                  ],
                ),
              ),
            ],
            if (order.deliveryProofUrl != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _viewProofPhoto(order.deliveryProofUrl!, 'Delivery Proof Photo'),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.checkmark_seal_fill, size: 14, color: AppColors.success),
                    SizedBox(width: 4),
                    Text('Tingnan ang Delivery Proof Photo',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.success,
                            decoration: TextDecoration.underline)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.circle_fill,
                      size: 9, color: statusColor),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _viewProofPhoto(String proofUrl, String title) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: proofUrl.startsWith('data:')
                ? Image.memory(
                    base64Decode(proofUrl.split(',').last),
                    fit: BoxFit.contain,
                  )
                : Image.network(
                    proofUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                        CupertinoIcons.exclamationmark_triangle,
                        size: 32,
                        color: AppColors.warning),
                  ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final activeCount = _orders.where(_isActivePickup).length;
    final kitchenCount = _orders.where(_isInKitchen).length;
    final completedCount = _orders.where(_isCompleted).length;
    final allCount = _orders.length;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: StaffNavBar(
        title: 'Bilao Orders',
        showBackButton: !widget.isRootTab,
        trailing: const StaffTopActions(),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── BRANCH INFO HEADER ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: CupertinoColors.white,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.placemark_fill,
                        size: 20, color: AppColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentBranchName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$allCount bilao order${allCount == 1 ? '' : 's'} · $activeCount active for pickup',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // + Add Order button
                  CupertinoButton(
                    key: _plusButtonKey,
                    padding: EdgeInsets.zero,
                    onPressed: _showAddOrderSheet,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.add,
                          size: 18, color: CupertinoColors.white),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.border),

            // ── SEARCH & 4 TABS ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  CupertinoSearchTextField(
                    placeholder: 'Search customer name o contact...',
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    key: _filterTabsKey,
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<int>(
                      groupValue: _tabIndex,
                      children: {
                        0: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Text(
                            'Pickup ($activeCount)',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        1: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Text(
                            'Kitchen ($kitchenCount)',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        2: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Text(
                            'Done ($completedCount)',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        3: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Text(
                            'All ($allCount)',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      },
                      onValueChanged: (val) {
                        if (val != null) setState(() => _tabIndex = val);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── ORDERS LIST ─────────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _filteredOrders.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.tray_fill,
                                  size: 48,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _staffEmptyTitle(_tabIndex),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _staffEmptySubtitle(_tabIndex),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _filteredOrders.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            return _OrderCard(
                              order: order,
                              statusLabel: _cardStatusLabel(order),
                              statusColor: _cardStatusColor(order),
                              onTap: () => _showOrderDetails(order),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _staffEmptyTitle(int tab) {
    switch (tab) {
      case 0:
        return 'No Bilao for Pickup';
      case 1:
        return 'No Orders in Preparation';
      case 2:
        return 'No Completed Orders';
      default:
        return 'No Bilao Orders';
    }
  }

  String _staffEmptySubtitle(int tab) {
    switch (tab) {
      case 0:
        return 'Orders ready for customer pickup or incoming from driver will appear here.';
      case 1:
        return 'Incoming orders currently being prepared in the kitchen will appear here.';
      case 2:
        return 'Released and paid bilao orders will appear here.';
      default:
        return 'Tap the + button above to add a walk-in or phone bilao order.';
    }
  }
}

// ── Minimal Order Card ───────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
  });

  final BilaoOrder order;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCompleted = order.deliveryStatus == DeliveryStatus.completed ||
        order.deliveryStatus == DeliveryStatus.delivered;

    return GestureDetector(
      onTap: onTap,
      child: StaffCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderColor: isCompleted
            ? AppColors.success.withValues(alpha: 0.2)
            : AppColors.accent.withValues(alpha: 0.25),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.success.withValues(alpha: 0.12)
                    : AppColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                order.customerName.isNotEmpty
                    ? order.customerName[0].toUpperCase()
                    : 'B',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isCompleted ? AppColors.success : AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + contact + package
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerName,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    order.contactNumber,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.size.label} Bilao × ${order.quantity}  ·  \u20b1${order.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: order.hasCookCommission
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.textSecondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      order.hasCookCommission
                          ? 'BRANCH ORDER (+₱${order.commissionAmount.toStringAsFixed(0)} COMMISSION)'
                          : 'DIRECT TO OWNER (NO COMMISSION)',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: order.hasCookCommission
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Status pill (right side)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(CupertinoIcons.chevron_right,
                    size: 13, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Bilao Order Sheet — 3-Step Stepper ───────────────────────────────────

class _AddBilaoOrderSheet extends StatefulWidget {
  const _AddBilaoOrderSheet({
    required this.branchId,
    required this.branchName,
    this.isTourMode = false,
  });

  final String branchId;
  final String branchName;
  final bool isTourMode;

  @override
  State<_AddBilaoOrderSheet> createState() => _AddBilaoOrderSheetState();
}

class _AddBilaoOrderSheetState extends State<_AddBilaoOrderSheet> {
  // ── Tour Keys ─────────────────────────────────────────────────────────────
  final GlobalKey _step0NextKey = GlobalKey();
  final GlobalKey _step1NextKey = GlobalKey();
  final GlobalKey _step2SaveKey = GlobalKey();

  // ── Controllers ──────────────────────────────────────────────────────────
  final _nameCtrl     = TextEditingController();
  final _contactCtrl  = TextEditingController();
  final _notesCtrl    = TextEditingController();
  final _depositCtrl  = TextEditingController();
  final _gcashRefCtrl = TextEditingController();
  final _gcashAmtCtrl = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  int         _step             = 0; // 0,1,2
  BilaoSize   _size             = BilaoSize.medium;
  int         _quantity         = 1;
  bool        _isSaving         = false;
  DateTime    _scheduledDateTime = DateTime.now().add(const Duration(hours: 2));

  // Payment
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  PaymentType   _paymentType   = PaymentType.fullPayment;

  // GCash OCR
  XFile? _gcashPhoto;
  bool   _isOcrLoading = false;
  String _ocrError     = '';

  @override
  void initState() {
    super.initState();
    _depositCtrl.text = _total.toStringAsFixed(0);
    if (widget.isTourMode) {
      _nameCtrl.text = 'Juan Dela Cruz';
      _contactCtrl.text = '09123456789';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _launchSheetTourStep0();
      });
    }
  }

  void _launchSheetTourStep0() {
    if (!mounted) return;
    GuidedTourOverlay.show(
      context: context,
      steps: [
        GuidedTourStep(
          targetKey: _step0NextKey,
          roleBadge: 'BRANCH COOK ONBOARDING',
          title: '11. Impormasyon ng Customer',
          instruction: 'PINDUTIN: I-tap ang "Susunod" button.',
          explanation:
              'Lagyan ng Customer Name at Contact Number ang mga field. Kapag may laman na, mai-unlock ang Susunod button.',
          tip: 'Pindutin ang Susunod button upang lumipat sa susunod na hakbang.',
          onTargetTapped: () async {
            if (_step == 0) {
              setState(() => _step = 1);
            }
            await Future.delayed(const Duration(milliseconds: 350));
            _launchSheetTourStep1();
          },
        ),
      ],
      onCompleted: () {},
      onSkipped: () => TutorialService.markTutorialSeen('bilao_spotlight'),
    );
  }

  void _launchSheetTourStep1() {
    if (!mounted) return;
    GuidedTourOverlay.show(
      context: context,
      steps: [
        GuidedTourStep(
          targetKey: _step1NextKey,
          roleBadge: 'BRANCH COOK ONBOARDING',
          title: '12. Detalye ng Package at Schedule',
          instruction: 'PINDUTIN: I-tap ang "Susunod" button.',
          explanation:
              'Pumili ng Bilao Size (Small, Medium, Large), Quantity, at i-set ang petsa at oras kung kailan ito kukunin ng customer.',
          tip: 'Pindutin ang Susunod button upang magpatuloy sa Payment screen.',
          onTargetTapped: () async {
            if (_step == 1) {
              setState(() => _step = 2);
            }
            await Future.delayed(const Duration(milliseconds: 350));
            _launchSheetTourStep2();
          },
        ),
      ],
      onCompleted: () {},
      onSkipped: () => TutorialService.markTutorialSeen('bilao_spotlight'),
    );
  }

  void _launchSheetTourStep2() {
    if (!mounted) return;
    GuidedTourOverlay.show(
      context: context,
      steps: [
        GuidedTourStep(
          targetKey: _step2SaveKey,
          roleBadge: 'BRANCH COOK ONBOARDING',
          title: '13. Paraan ng Bayad at Pag-save',
          instruction: 'PINDUTIN: I-tap ang "I-save ang Order" button.',
          explanation:
              'Pumili ng Paraan ng Bayad (Cash o GCash) at Uri ng Bayad (Full Payment o Downpayment). I-tap ang button upang i-save ang order at lumipat sa Report tutorial.',
          tip: 'Pindutin ang I-save ang Order button upang tapusin ang Bilao tutorial.',
          onTargetTapped: () async {
            if (mounted) Navigator.of(context).pop();
            StaffShell.tabController.index = 3;
            await Future.delayed(const Duration(milliseconds: 400));
            (DailyReportScreen.globalKey.currentState as dynamic)?.startTour();
          },
        ),
      ],
      onCompleted: () => TutorialService.markTutorialSeen('bilao_spotlight'),
      onSkipped: () => TutorialService.markTutorialSeen('bilao_spotlight'),
    );
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  double get _total => _size.price * _quantity;
  double get _minDeposit => _total * 0.65;

  // ── Styles ────────────────────────────────────────────────────────────────

  static const _fieldTextStyle = TextStyle(
    fontSize: 13,
    color: Color(0xFF24140B),
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.none,
  );

  static const _hintStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFF9E8B7E),
    fontWeight: FontWeight.w400,
    decoration: TextDecoration.none,
  );

  InputDecoration _dec({
    required String label,
    String? hint,
    IconData? icon,
    bool readOnly = false,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: readOnly ? const Color(0xFF9E8B7E) : const Color(0xFF6B584C),
          decoration: TextDecoration.none,
        ),
        floatingLabelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: readOnly ? const Color(0xFF9E8B7E) : AppColors.accent,
          decoration: TextDecoration.none,
        ),
        hintStyle: _hintStyle,
        prefixIcon: icon != null
            ? Icon(icon,
                size: 17,
                color: readOnly
                    ? const Color(0xFFCCC0B4)
                    : const Color(0xFF8B4513))
            : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: readOnly ? const Color(0xFFF7F3F0) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(
              color: readOnly
                  ? const Color(0xFFEDE5DF)
                  : const Color(0xFFDCCFC3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(
              color: readOnly
                  ? const Color(0xFFDCCFC3)
                  : AppColors.accent,
              width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide:
              const BorderSide(color: Color(0xFFEDE5DF)),
        ),
      );

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _notesCtrl.dispose();
    _depositCtrl.dispose();
    _gcashRefCtrl.dispose();
    _gcashAmtCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _nextStep() {
    if (_step == 0) {
      final name    = _nameCtrl.text.trim();
      final contact = _contactCtrl.text.trim();
      if (name.isEmpty) {
        _showError('Pakienter ang pangalan ng customer.');
        return;
      }
      if (name.length < 2) {
        _showError('Ang pangalan ng customer ay dapat hindi bababa sa 2 characters.');
        return;
      }
      if (name.length > 60) {
        _showError('Ang pangalan ng customer ay hindi dapat lumampas sa 60 characters.');
        return;
      }
      if (!RegExp(r"^[a-zA-ZñÑáéíóúÁÉÍÓÚ\s\-'.]+$").hasMatch(name)) {
        _showError('Ang pangalan ay dapat mga letra lamang.');
        return;
      }

      if (contact.isEmpty) {
        _showError('Pakienter ang contact number ng customer.');
        return;
      }
      final digits = contact.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 7 || digits.length > 12) {
        _showError('Maglagay ng tamang contact number (7 hanggang 12 digits, e.g. 0917 123 4567).');
        return;
      }
    }
    if (_step < 2) setState(() => _step++);
  }

  void _prevStep() {
    if (_step > 0) setState(() => _step--);
  }

  // ── Date/Time pickers ─────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.accent,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF24140B),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _scheduledDateTime = DateTime(picked.year, picked.month, picked.day,
          _scheduledDateTime.hour, _scheduledDateTime.minute);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledDateTime),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.accent,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF24140B),
          ),
          timePickerTheme: const TimePickerThemeData(
            dialHandColor: AppColors.accent,
            hourMinuteColor: Color(0xFFF5EDE6),
            hourMinuteTextColor: Color(0xFF24140B),
            dayPeriodColor: Color(0xFFF5EDE6),
            dayPeriodTextColor: Color(0xFF24140B),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _scheduledDateTime = DateTime(_scheduledDateTime.year,
          _scheduledDateTime.month, _scheduledDateTime.day,
          picked.hour, picked.minute);
    });
  }

  String get _formattedDateOnly {
    final dt = _scheduledDateTime;
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String get _formattedTimeOnly {
    final dt  = _scheduledDateTime;
    final h   = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m   = dt.minute.toString().padLeft(2, '0');
    final amp = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $amp';
  }

  // ── Payment helpers ───────────────────────────────────────────────────────

  void _onSelectPaymentType(PaymentType type) {
    setState(() {
      _paymentType = type;
      if (type == PaymentType.fullPayment) {
        _depositCtrl.text = _total.toStringAsFixed(0);
      } else {
        // Down payment — pre-fill minimum 65%
        _depositCtrl.text = _minDeposit.toStringAsFixed(0);
      }
    });
  }

  void _onSelectPaymentMethod(PaymentMethod method) {
    setState(() {
      _paymentMethod = method;
      if (method == PaymentMethod.cash) {
        _clearGcashPhoto();
      }
    });
  }

  // ── GCash OCR ─────────────────────────────────────────────────────────────

  Future<void> _pickGcashPhoto(ImageSource source) async {
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );
      if (photo == null) return;
      setState(() {
        _gcashPhoto   = photo;
        _ocrError     = '';
        _isOcrLoading = true;
      });
      await _runOcr(photo);
    } catch (e) {
      setState(() => _ocrError = 'Hindi ma-access ang camera/gallery: $e');
    }
  }

  Future<void> _runOcr(XFile photo) async {
    try {
      final bytes  = await photo.readAsBytes();
      final result = await GeminiService.extractGcashReceipt(imageBytes: bytes);
      if (!mounted) return;
      setState(() {
        _isOcrLoading = false;
        if (result.success) {
          _gcashRefCtrl.text = result.refNumber;
          if (result.amount > 0) {
            _gcashAmtCtrl.text = result.amount.toStringAsFixed(2);
          }
          _ocrError = '';
        } else {
          _ocrError = result.errorMessage.isNotEmpty
              ? result.errorMessage
              : 'Hindi nakuha ang data. I-edit na lang manually.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isOcrLoading = false;
        _ocrError     = 'OCR error: $e';
      });
    }
  }

  void _clearGcashPhoto() {
    setState(() {
      _gcashPhoto   = null;
      _ocrError     = '';
      _isOcrLoading = false;
      _gcashRefCtrl.clear();
      _gcashAmtCtrl.clear();
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    // Validate deposit amount
    final depositVal = double.tryParse(_depositCtrl.text.trim()) ?? 0.0;
    if (depositVal <= 0) {
      _showError('Maglagay ng tamang halaga ng bayad o paunang bayad.');
      return;
    }

    // Validate payment step
    if (_paymentMethod == PaymentMethod.gcash) {
      if (_gcashPhoto == null) {
        _showError('Pakuha ng photo ng GCash receipt bago mag-submit.');
        return;
      }
      final ref = _gcashRefCtrl.text.trim();
      if (ref.isEmpty) {
        _showError('Pakienter ang GCash Reference Number.');
        return;
      }
      if (ref.length < 6 || ref.length > 30) {
        _showError('Maglagay ng tamang GCash Reference Number (e.g. 1002 9384 1928).');
        return;
      }
    }

    // Validate deposit amount for down payment
    if (_paymentType == PaymentType.downPayment) {
      if (depositVal < _minDeposit - 0.01) {
        _showError(
            'Ang minimum na downpayment ay 65% ng total (₱${_minDeposit.toStringAsFixed(0)}).');
        return;
      }
      if (depositVal > _total) {
        _showError(
            'Ang downpayment ay hindi dapat lumampas sa kabuuang halaga (₱${_total.toStringAsFixed(0)}).');
        return;
      }
    } else {
      if (depositVal < _total - 0.01) {
        _showError(
            'Ang full payment ay dapat katumbas ng buong halaga (₱${_total.toStringAsFixed(0)}).');
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      // Upload GCash proof if needed
      String? gcashProofUrl;
      if (_paymentMethod == PaymentMethod.gcash && _gcashPhoto != null) {
        final bytes  = await _gcashPhoto!.readAsBytes();
        final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
        gcashProofUrl = await SupabaseService.uploadBilaoProofPhoto(
          orderId:   tempId,
          proofType: 'gcash',
          bytes:     bytes,
        );
      }

      final depositAmt = double.tryParse(_depositCtrl.text.trim()) ?? 0.0;
      final orderId    = 'bilao_${DateTime.now().millisecondsSinceEpoch}';

      final order = BilaoOrder(
        id:                orderId,
        customerName:      _nameCtrl.text.trim(),
        contactNumber:     _contactCtrl.text.trim(),
        size:              _size,
        quantity:          _quantity,
        scheduledDateTime: _scheduledDateTime,
        fulfillmentType:   BilaoFulfillmentType.branchPickup,
        orderChannel:      BilaoOrderChannel.branchOrder,
        pickupBranchId:    widget.branchId,
        pickupBranchName:  widget.branchName,
        deliveryAddress:   '',
        notes:             _notesCtrl.text.trim().isEmpty
                               ? null
                               : _notesCtrl.text.trim(),
        depositAmount:     depositAmt,
        preparationStatus: PreparationStatus.pending,
        deliveryStatus:    DeliveryStatus.forDelivery,
        paymentMethod:     _paymentMethod,
        paymentType:       _paymentType,
        gcashRefNumber:    _paymentMethod == PaymentMethod.gcash
                               ? _gcashRefCtrl.text.trim()
                               : null,
        gcashAmount:       _paymentMethod == PaymentMethod.gcash
                               ? double.tryParse(_gcashAmtCtrl.text.trim())
                               : null,
        gcashProofUrl:     gcashProofUrl,
        gcashVerified:     false,
      );
      await FirestoreService.createBilaoOrder(order);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) _showError('Failed to save order: $e');
    }
  }

  void _showError(String msg) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Reusable chip ─────────────────────────────────────────────────────────

  Widget _typeChip(
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.accent : const Color(0xFFDCCFC3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15,
                color: selected ? Colors.white : const Color(0xFF8B4513)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF24140B),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step indicator ────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    const stepLabels = ['Info', 'Details', 'Payment'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(5, (i) {
        if (i.isOdd) {
          // Connector line between dots
          final lineIdx = i ~/ 2;
          final filled = lineIdx < _step;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: filled ? AppColors.accent : const Color(0xFFE2D5CB),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }
        final dotIdx = i ~/ 2;
        final done   = dotIdx < _step;
        final active = dotIdx == _step;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: done
                    ? AppColors.accent
                    : active
                        ? Colors.white
                        : const Color(0xFFF4EDE8),
                shape: BoxShape.circle,
                border: Border.all(
                  color: done || active ? AppColors.accent : const Color(0xFFD5C5BB),
                  width: active ? 2 : 1.5,
                ),
                boxShadow: active
                    ? [BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )]
                    : null,
              ),
              child: done
                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                  : Center(
                      child: Text(
                        '${dotIdx + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: active ? AppColors.accent : const Color(0xFFBBAFA8),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              stepLabels[dotIdx],
              style: TextStyle(
                fontSize: 9,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active
                    ? AppColors.accent
                    : done
                        ? const Color(0xFF7A6556)
                        : const Color(0xFFBBAFA8),
                decoration: TextDecoration.none,
                letterSpacing: 0.1,
              ),
            ),
          ],
        );
      }),
    );
  }

  // ── STEP 1: Customer Info ─────────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Sino ang mag-o-order?',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9E8B7E),
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          style: _fieldTextStyle,
          decoration: _dec(
            label: 'Customer Name',
            hint: 'e.g. Juan Dela Cruz',
            icon: Icons.person_outline_rounded,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _contactCtrl,
          keyboardType: TextInputType.phone,
          style: _fieldTextStyle,
          decoration: _dec(
            label: 'Contact Number',
            hint: '09XX XXX XXXX',
            icon: Icons.phone_outlined,
          ),
        ),
      ],
    );
  }

  // ── STEP 2: Order Details ─────────────────────────────────────────────────

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bilao Size label
        const Text(
          'BILAO SIZE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFF9E8B7E),
            letterSpacing: 0.6,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: BilaoSize.values.map((s) {
            final selected = _size == s;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _size = s;
                  if (_paymentType == PaymentType.fullPayment) {
                    _depositCtrl.text = _total.toStringAsFixed(0);
                  } else {
                    _depositCtrl.text = _minDeposit.toStringAsFixed(0);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(right: s != BilaoSize.large ? 6 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? AppColors.accent : const Color(0xFFDCCFC3),
                      width: selected ? 1.5 : 1,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            blurRadius: 6, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        s.name[0].toUpperCase() + s.name.substring(1),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : const Color(0xFF24140B),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '\u20b1${s.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: selected ? Colors.white70 : const Color(0xFF9E8B7E),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // Quantity
        const Text(
          'QUANTITY',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFF9E8B7E),
            letterSpacing: 0.6,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDCCFC3)),
          ),
          child: Row(
            children: [
              _qtyButton(
                icon: Icons.remove_rounded,
                enabled: _quantity > 1,
                onTap: () => setState(() {
                  _quantity--;
                  if (_paymentType == PaymentType.fullPayment) {
                    _depositCtrl.text = _total.toStringAsFixed(0);
                  } else {
                    _depositCtrl.text = _minDeposit.toStringAsFixed(0);
                  }
                }),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$_quantity',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF24140B),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
              _qtyButton(
                icon: Icons.add_rounded,
                enabled: true,
                onTap: () => setState(() {
                  _quantity++;
                  if (_paymentType == PaymentType.fullPayment) {
                    _depositCtrl.text = _total.toStringAsFixed(0);
                  } else {
                    _depositCtrl.text = _minDeposit.toStringAsFixed(0);
                  }
                }),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '\u20b1${_total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Schedule
        const Text(
          'SCHEDULE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFF9E8B7E),
            letterSpacing: 0.6,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _scheduleBox(
                label: 'Date',
                value: _formattedDateOnly,
                icon: Icons.calendar_month_outlined,
                onTap: _pickDate,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _scheduleBox(
                label: 'Time',
                value: _formattedTimeOnly,
                icon: Icons.access_time_rounded,
                onTap: _pickTime,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Notes
        TextFormField(
          controller: _notesCtrl,
          maxLines: 2,
          style: _fieldTextStyle,
          decoration: _dec(
            label: 'Notes (optional)',
            hint: 'e.g. Special instructions...',
            icon: Icons.notes_rounded,
          ),
        ),
      ],
    );
  }

  Widget _qtyButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled ? AppColors.accent : const Color(0xFFF0EBE7),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 16,
            color: enabled ? Colors.white : const Color(0xFFCCC0B4)),
      ),
    );
  }

  Widget _scheduleBox({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDCCFC3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: AppColors.accent),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9E8B7E),
                          decoration: TextDecoration.none)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF24140B),
                          decoration: TextDecoration.none)),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 14, color: Color(0xFF9E8B7E)),
          ],
        ),
      ),
    );
  }

  // ── STEP 3: Payment ───────────────────────────────────────────────────────

  Widget _buildStep3() {
    final isFull = _paymentType == PaymentType.fullPayment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Method
        const Text(
          'PARAAN NG BAYAD',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFF9E8B7E),
            letterSpacing: 0.6,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _typeChip(
                'Cash',
                Icons.payments_outlined,
                _paymentMethod == PaymentMethod.cash,
                () => _onSelectPaymentMethod(PaymentMethod.cash),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _typeChip(
                'GCash',
                Icons.account_balance_wallet_outlined,
                _paymentMethod == PaymentMethod.gcash,
                () => _onSelectPaymentMethod(PaymentMethod.gcash),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Type
        const Text(
          'URI NG BAYAD',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFF9E8B7E),
            letterSpacing: 0.6,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _typeChip(
                'Full Payment',
                Icons.check_circle_outline_rounded,
                _paymentType == PaymentType.fullPayment,
                () => _onSelectPaymentType(PaymentType.fullPayment),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _typeChip(
                'Down Payment',
                Icons.history_edu_rounded,
                _paymentType == PaymentType.downPayment,
                () => _onSelectPaymentType(PaymentType.downPayment),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Total banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Order Total',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF6B584C),
                      decoration: TextDecoration.none)),
              Text('\u20b1${_total.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                      decoration: TextDecoration.none)),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Amount field
        if (isFull) ...[
          TextFormField(
            controller: _depositCtrl,
            readOnly: true,
            enabled: false,
            style: _fieldTextStyle,
            decoration: _dec(
              label: 'Full Payment — Fixed Amount',
              icon: Icons.payments_outlined,
              readOnly: true,
            ),
          ),
        ] else ...[
          TextFormField(
            controller: _depositCtrl,
            keyboardType: TextInputType.number,
            style: _fieldTextStyle,
            onChanged: (_) => setState(() {}),
            decoration: _dec(
              label: 'Downpayment (min. 65%)',
              hint: _minDeposit.toStringAsFixed(0),
              icon: Icons.payments_outlined,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Minimum: \u20b1${_minDeposit.toStringAsFixed(0)} (65% ng \u20b1${_total.toStringAsFixed(0)})',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.warning,
              decoration: TextDecoration.none,
            ),
          ),
        ],

        // GCash section
        if (_paymentMethod == PaymentMethod.gcash) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 14, color: Color(0xFF2563EB)),
                  SizedBox(width: 6),
                  Text('GCash Receipt',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                          decoration: TextDecoration.none)),
                ]),
                const SizedBox(height: 8),

                // Photo picker / preview
                if (_gcashPhoto == null)
                  Row(children: [
                    Expanded(
                        child: _gcashPhotoBtn(
                            'Camera', Icons.camera_alt_outlined,
                            () => _pickGcashPhoto(ImageSource.camera))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _gcashPhotoBtn(
                            'Gallery', Icons.photo_library_outlined,
                            () => _pickGcashPhoto(ImageSource.gallery))),
                  ])
                else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.file(File(_gcashPhoto!.path),
                        height: 100, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: _clearGcashPhoto,
                    child: const Text('Palitan ang photo',
                        style: TextStyle(
                            fontSize: 10.5, color: Color(0xFF9E8B7E),
                            decoration: TextDecoration.underline)),
                  ),
                ],

                if (_isOcrLoading) ...[
                  const SizedBox(height: 8),
                  const Row(children: [
                    SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF2563EB))),
                    SizedBox(width: 8),
                    Text('Kinukuha ang ref no. at amount...',
                        style: TextStyle(
                            fontSize: 10.5, color: Color(0xFF2563EB),
                            decoration: TextDecoration.none)),
                  ]),
                ],
                if (_ocrError.isNotEmpty && !_isOcrLoading) ...[
                  const SizedBox(height: 4),
                  Text(_ocrError,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.warning,
                          decoration: TextDecoration.none)),
                ],

                const SizedBox(height: 8),
                TextFormField(
                  controller: _gcashRefCtrl,
                  keyboardType: TextInputType.number,
                  style: _fieldTextStyle,
                  decoration: _dec(
                    label: 'Reference Number',
                    hint: '1234567890123',
                    icon: Icons.tag_rounded,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _gcashAmtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  style: _fieldTextStyle,
                  decoration: _dec(
                    label: 'GCash Amount (₱)',
                    hint: '900.00',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline_rounded,
                        size: 12, color: AppColors.warning),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Mag-aantay ng verification ng Owner bago iluto.',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.warning,
                            decoration: TextDecoration.none),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _gcashPhotoBtn(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDCCFC3)),
        ),
        child: Column(children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                  decoration: TextDecoration.none)),
        ]),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Material(
      color: Colors.transparent,
      child: DefaultTextStyle(
        style: const TextStyle(
          decoration: TextDecoration.none,
          color: Color(0xFF24140B),
          fontFamily: '.SF Pro Text',
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                  color: Color(0x28000000),
                  blurRadius: 20,
                  offset: Offset(0, -6)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Pull handle ───────────────────────────────────────────
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCCFC3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ── Header ────────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bagong Bilao Order',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A0D07),
                                decoration: TextDecoration.none,
                              ),
                            ),
                            Text(
                              widget.branchName,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF9E8B7E),
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE5DF),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 16, color: Color(0xFF6B584C)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Step indicator ────────────────────────────────────────
                  _buildStepIndicator(),
                  const SizedBox(height: 16),

                  // ── Divider ───────────────────────────────────────────────
                  Container(height: 1, color: const Color(0xFFEDE5DF)),
                  const SizedBox(height: 14),

                  // ── Step content (AnimatedSwitcher) ───────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: _step == 0
                          ? _buildStep1()
                          : _step == 1
                              ? _buildStep2()
                              : _buildStep3(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Divider ───────────────────────────────────────────────
                  Container(height: 1, color: const Color(0xFFEDE5DF)),
                  const SizedBox(height: 12),

                  // ── Nav buttons ───────────────────────────────────────────
                  if (_isSaving)
                    const SizedBox(
                      height: 46,
                      child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent)),
                    )
                  else
                    Row(
                      children: [
                        if (_step > 0) ...[
                          Expanded(
                            child: GestureDetector(
                              onTap: _prevStep,
                              child: Container(
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE5DF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.arrow_back_ios_new_rounded,
                                        size: 13, color: Color(0xFF6B584C)),
                                    SizedBox(width: 4),
                                    Text('Bumalik',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF6B584C),
                                            decoration: TextDecoration.none)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: _step < 2 ? _nextStep : _save,
                            child: Container(
                              key: _step == 0 ? _step0NextKey : (_step == 1 ? _step1NextKey : _step2SaveKey),
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accent.withValues(
                                        alpha: 0.28),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _step < 2 ? 'Susunod' : 'I-save ang Order',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    _step < 2
                                        ? Icons.arrow_forward_ios_rounded
                                        : Icons.check_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

