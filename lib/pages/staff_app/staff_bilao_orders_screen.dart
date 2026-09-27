import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../data/philippine_address_data.dart';
import '../../models/bilao_order.dart';
import '../../models/branch.dart';
import '../../services/assignment_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_top_actions.dart';

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

  final String? branchId;
  final String? branchName;
  final bool isRootTab;

  @override
  State<StaffBilaoOrdersScreen> createState() => _StaffBilaoOrdersScreenState();
}

class _StaffBilaoOrdersScreenState extends State<StaffBilaoOrdersScreen> {
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
      return 'Paparating sa Branch';
    }
    if (o.preparationStatus == PreparationStatus.ready) {
      return 'Handa na para sa Pickup';
    }
    switch (o.preparationStatus) {
      case PreparationStatus.pending:
        return 'Pending Order';
      case PreparationStatus.preparing:
        return 'Inihahanda sa Kusina';
      case PreparationStatus.ready:
        return 'Handa na para sa Pickup';
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

  // ── Release to Customer Action ─────────────────────────────────────────────

  Future<void> _completeBranchPickup(BilaoOrder order) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('I-release sa Customer?'),
        content: Text(
          'Kinuha na ba ni ${order.customerName} ang kanyang ${order.size.label} Bilao Order at natanggap na ang bayad (\u20b1${order.totalAmount.toStringAsFixed(0)})?\n\n'
          'Ito ay mamarkahan bilang Completed at aabisuhan si Owner sa system.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Oo, Nakuha Na'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final staffName = AuthService.currentAppUser?.fullName ?? 'Branch Staff';
    final success = await FirestoreService.completeBranchBilaoPickup(
      order: order,
      staffName: staffName,
    );

    if (!mounted) return;
    if (success) {
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Order Completed!'),
          content: Text(
            'Matagumpay na nai-release ang bilao order kay ${order.customerName}. Naka-record na ito sa system at notified na si Owner.',
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
  }

  // ── Add Order Sheet ─────────────────────────────────────────────────────────

  void _showAddOrderSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBilaoOrderSheet(
        branchId: _currentBranchId,
        branchName: _currentBranchName,
      ),
    );
  }

  // ── Details Dialog ──────────────────────────────────────────────────────────

  void _showOrderDetails(BilaoOrder order) {
    final statusLabel = _cardStatusLabel(order);
    final statusColor = _cardStatusColor(order);
    final isCompleted = _isCompleted(order);
    final canRelease = !isCompleted &&
        (order.preparationStatus == PreparationStatus.ready ||
            order.deliveryStatus == DeliveryStatus.outForDelivery);

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
          if (canRelease)
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                _completeBranchPickup(order);
              },
              child: const Text('I-release sa Customer'),
            ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
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
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredOrders.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            final canRelease = !_isCompleted(order) &&
                                (order.preparationStatus == PreparationStatus.ready ||
                                    order.deliveryStatus == DeliveryStatus.outForDelivery);

                            return _OrderCard(
                              order: order,
                              statusLabel: _cardStatusLabel(order),
                              statusColor: _cardStatusColor(order),
                              canRelease: canRelease,
                              onTap: () => _showOrderDetails(order),
                              onRelease: () => _completeBranchPickup(order),
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
        return 'Walang Bilao para sa Pickup';
      case 1:
        return 'Walang Inihahanda sa Kusina';
      case 2:
        return 'Walang Completed Orders';
      default:
        return 'Walang Bilao Orders';
    }
  }

  String _staffEmptySubtitle(int tab) {
    switch (tab) {
      case 0:
        return 'Lalabas dito ang mga bilao na handa nang kunin ng customer o paparating mula sa driver.';
      case 1:
        return 'Lalabas dito ang mga darating na order na inihahanda pa sa kusina ni Owner.';
      case 2:
        return 'Makikita rito ang mga nai-release at nabayaran nang bilao orders.';
      default:
        return 'I-tap ang + button sa itaas para magdagdag ng bagong walk-in o tawag na bilao order.';
    }
  }
}

// ── Minimal Order Card ───────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.statusLabel,
    required this.statusColor,
    required this.canRelease,
    required this.onTap,
    required this.onRelease,
  });

  final BilaoOrder order;
  final String statusLabel;
  final Color statusColor;
  final bool canRelease;
  final VoidCallback onTap;
  final VoidCallback onRelease;

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
        child: Column(
          children: [
            Row(
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
            if (canRelease) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: StaffButton(
                  label: 'I-release sa Customer',
                  icon: CupertinoIcons.checkmark_seal_fill,
                  color: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  onPressed: onRelease,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Add Bilao Order Sheet (Cupertino) ────────────────────────────────────────

class _AddBilaoOrderSheet extends StatefulWidget {
  const _AddBilaoOrderSheet({
    required this.branchId,
    required this.branchName,
  });

  final String branchId;
  final String branchName;

  @override
  State<_AddBilaoOrderSheet> createState() => _AddBilaoOrderSheetState();
}

class _AddBilaoOrderSheetState extends State<_AddBilaoOrderSheet> {
  final _nameCtrl    = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _notesCtrl   = TextEditingController();
  final _streetCtrl  = TextEditingController();

  // Address dropdowns
  String  _province  = 'Laguna';
  String? _city;
  String? _barangay;

  BilaoSize _size              = BilaoSize.medium;
  int       _quantity          = 1;
  bool      _isDirectDelivery  = false;
  bool      _isSaving          = false;
  DateTime  _scheduledDateTime = DateTime.now().add(const Duration(hours: 2));

  // ── Shared compact field styles ──────────────────────────────────────────

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
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B584C),
          decoration: TextDecoration.none,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
          decoration: TextDecoration.none,
        ),
        hintStyle: _hintStyle,
        prefixIcon: icon != null
            ? Icon(icon, size: 17, color: const Color(0xFF8B4513))
            : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFFDCCFC3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      );

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _notesCtrl.dispose();
    _streetCtrl.dispose();
    super.dispose();
  }

  // ── Computed ─────────────────────────────────────────────────────────────────

  double get _total => _size.price * _quantity;

  String get _formattedDateOnly {
    final dt = _scheduledDateTime;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String get _formattedTimeOnly {
    final dt = _scheduledDateTime;
    final hour   = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm   = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $ampm';
  }

  String get _deliveryAddress {
    if (_city == null || _barangay == null) return '';
    final street = _streetCtrl.text.trim();
    if (street.isEmpty) return 'Brgy. $_barangay, $_city, $_province';
    return '$street, Brgy. $_barangay, $_city, $_province';
  }

  // ── Date and Time Pickers (Material themed dialogs) ──────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.accent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF24140B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _scheduledDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _scheduledDateTime.hour,
        _scheduledDateTime.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledDateTime),
      builder: (context, child) {
        return Theme(
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
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _scheduledDateTime = DateTime(
        _scheduledDateTime.year,
        _scheduledDateTime.month,
        _scheduledDateTime.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  // ── Save ─────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final name    = _nameCtrl.text.trim();
    final contact = _contactCtrl.text.trim();

    if (name.isEmpty || contact.isEmpty) {
      _showError('Punan ang pangalan at contact number ng customer.');
      return;
    }
    if (_isDirectDelivery && (_city == null || _barangay == null)) {
      _showError('Pumili ng City at Barangay para sa delivery address.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final orderId = 'bilao_${DateTime.now().millisecondsSinceEpoch}';
      final order = BilaoOrder(
        id: orderId,
        customerName: name,
        contactNumber: contact,
        size: _size,
        quantity: _quantity,
        scheduledDateTime: _scheduledDateTime,
        fulfillmentType: _isDirectDelivery
            ? BilaoFulfillmentType.directDelivery
            : BilaoFulfillmentType.branchPickup,
        pickupBranchId:   _isDirectDelivery ? null : widget.branchId,
        pickupBranchName: _isDirectDelivery ? null : widget.branchName,
        deliveryAddress:  _isDirectDelivery ? _deliveryAddress : '',
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        preparationStatus: PreparationStatus.pending,
        deliveryStatus:    DeliveryStatus.forDelivery,
      );
      await FirestoreService.createBilaoOrder(order);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) _showError('Hindi nai-save ang order: $e');
    }
  }

  void _showError(String msg) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Kulang ang info'),
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

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cities   = PhilippineAddressData.getCities(_province);
    final barangays = _city != null
        ? PhilippineAddressData.getBarangays(_city!)
        : <String>[];

    return Material(
      color: Colors.transparent,
      child: DefaultTextStyle(
        style: const TextStyle(
          decoration: TextDecoration.none,
          color: Color(0xFF24140B),
          fontFamily: '.SF Pro Text',
        ),
        child: Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Color(0x20000000),
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Pull handle ──────────────────────────────────────────
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCCFC3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ── Header ───────────────────────────────────────────────
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Bagong Bilao Order',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF24140B),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 20, color: Color(0xFF9E8B7E)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    widget.branchName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A6556),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Customer Name ─────────────────────────────────────────
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: _fieldTextStyle,
                    decoration: _dec(
                      label: 'Pangalan ng Customer',
                      hint: 'Hal. Juan Dela Cruz',
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Contact Number ────────────────────────────────────────
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
                  const SizedBox(height: 12),

                  // ── Bilao Size ────────────────────────────────────────────
                  const Text(
                    'Bilao Size',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B584C),
                      letterSpacing: 0.2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: BilaoSize.values.map((s) {
                      final selected = _size == s;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _size = s),
                          child: Container(
                            margin: EdgeInsets.only(
                                right: s != BilaoSize.large ? 6 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.accent
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? AppColors.accent
                                    : const Color(0xFFDCCFC3),
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  s.name[0].toUpperCase() +
                                      s.name.substring(1),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFF24140B),
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                Text(
                                  '\u20b1${s.price.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: selected
                                        ? Colors.white70
                                        : const Color(0xFF9E8B7E),
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

                  // ── Quantity ──────────────────────────────────────────────
                  const Text(
                    'Quantity',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B584C),
                      letterSpacing: 0.2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDCCFC3)),
                    ),
                    child: Row(
                      children: [
                        // Minus
                        GestureDetector(
                          onTap: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _quantity > 1
                                  ? const Color(0xFFF5EDE6)
                                  : const Color(0xFFF0EBE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.remove_rounded,
                              size: 16,
                              color: _quantity > 1
                                  ? AppColors.accent
                                  : const Color(0xFFCCC0B4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$_quantity',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF24140B),
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Plus
                        GestureDetector(
                          onTap: () => setState(() => _quantity++),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.add_rounded,
                                size: 16, color: Colors.white),
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF9E8B7E),
                                decoration: TextDecoration.none,
                              ),
                            ),
                            Text(
                              '\u20b1${_total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Schedule ──────────────────────────────────────────────
                  const Text(
                    'Schedule',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B584C),
                      letterSpacing: 0.2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Date Selector
                      Expanded(
                        flex: 3,
                        child: GestureDetector(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: const Color(0xFFDCCFC3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_outlined,
                                    size: 16, color: Color(0xFF8B4513)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Petsa',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF9E8B7E),
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                      Text(
                                        _formattedDateOnly,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF24140B),
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down_rounded,
                                    size: 16, color: Color(0xFF9E8B7E)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Time Selector
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: _pickTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: const Color(0xFFDCCFC3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded,
                                    size: 16, color: Color(0xFF8B4513)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Oras',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF9E8B7E),
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                      Text(
                                        _formattedTimeOnly,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF24140B),
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down_rounded,
                                    size: 16, color: Color(0xFF9E8B7E)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Uri ng Order ──────────────────────────────────────────
                  const Text(
                    'Uri ng Order',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B584C),
                      letterSpacing: 0.2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _typeChip(
                          'Branch Pickup',
                          Icons.storefront_outlined,
                          !_isDirectDelivery,
                          () => setState(() => _isDirectDelivery = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _typeChip(
                          'Direct Delivery',
                          Icons.local_shipping_outlined,
                          _isDirectDelivery,
                          () => setState(() => _isDirectDelivery = true),
                        ),
                      ),
                    ],
                  ),

                  // ── Delivery Address (dropdown) ───────────────────────────
                  if (_isDirectDelivery) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Delivery Address',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B584C),
                        letterSpacing: 0.2,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Province
                    DropdownButtonFormField<String>(
                      initialValue: _province,
                      isExpanded: true,
                      style: _fieldTextStyle,
                      decoration: _dec(
                        label: 'Province',
                        icon: Icons.map_outlined,
                      ),
                      items: PhilippineAddressData.provinces
                          .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p, style: _fieldTextStyle)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _province  = v;
                          _city      = null;
                          _barangay  = null;
                        });
                      },
                    ),
                    const SizedBox(height: 8),

                    // City / Municipality
                    DropdownButtonFormField<String>(
                      initialValue: _city != null && cities.contains(_city)
                          ? _city
                          : null,
                      isExpanded: true,
                      style: _fieldTextStyle,
                      decoration: _dec(
                        label: 'City / Municipality',
                        icon: Icons.location_city_outlined,
                      ),
                      hint: const Text('Pumili ng lungsod',
                          style: _hintStyle),
                      items: cities
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c, style: _fieldTextStyle)))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _city     = v;
                        _barangay = null;
                      }),
                    ),
                    const SizedBox(height: 8),

                    // Barangay
                    DropdownButtonFormField<String>(
                      initialValue:
                          _barangay != null && barangays.contains(_barangay)
                              ? _barangay
                              : null,
                      isExpanded: true,
                      style: _fieldTextStyle,
                      decoration: _dec(
                        label: 'Barangay',
                        icon: Icons.holiday_village_outlined,
                      ),
                      hint: const Text('Pumili ng barangay',
                          style: _hintStyle),
                      items: barangays
                          .map((b) => DropdownMenuItem(
                              value: b,
                              child: Text(b, style: _fieldTextStyle)))
                          .toList(),
                      onChanged: _city == null
                          ? null
                          : (v) => setState(() => _barangay = v),
                    ),
                    const SizedBox(height: 8),

                    // Street / House no.
                    TextFormField(
                      controller: _streetCtrl,
                      style: _fieldTextStyle,
                      decoration: _dec(
                        label: 'House No. / Street (optional)',
                        hint: 'Hal. Blk 5 Lot 2, Rizal St.',
                        icon: Icons.home_outlined,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // ── Notes ─────────────────────────────────────────────────
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    style: _fieldTextStyle,
                    decoration: _dec(
                      label: 'Notes (optional)',
                      hint: 'Hal. Table 2, katabi ng kapilya...',
                      icon: Icons.notes_rounded,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Save Button ───────────────────────────────────────────
                  if (_isSaving)
                    const SizedBox(
                      height: 44,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      ),
                    )
                  else
                    StaffButton(
                      label: 'I-save ang Order',
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      onPressed: _save,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : const Color(0xFF8B4513),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      selected ? Colors.white : const Color(0xFF24140B),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

