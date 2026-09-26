import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../../models/bilao_order.dart';
import '../../models/branch.dart';
import '../../services/assignment_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_top_actions.dart';

/// Screen for Branch Staff to monitor Bilao Orders assigned to or waiting
/// at their specific branch location.
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
  int _tabIndex = 0; // 0: All, 1: Active/Waiting, 2: Completed

  String _currentBranchId = 'br1';
  String _currentBranchName = 'Brgy. Gatid, Sta. Cruz';

  @override
  void initState() {
    super.initState();
    _setupBranchAndStream();
    AssignmentService.changeNotifier.addListener(_onAssignmentChanged);
  }

  void _onAssignmentChanged() {
    if (mounted) {
      _setupBranchAndStream();
    }
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

  List<BilaoOrder> get _filteredOrders {
    var list = _orders.where((o) {
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          o.customerName.toLowerCase().contains(q) ||
          o.contactNumber.toLowerCase().contains(q) ||
          (o.notes != null && o.notes!.toLowerCase().contains(q));

      bool matchesTab = true;
      if (_tabIndex == 1) {
        // Active / Waiting
        matchesTab = o.deliveryStatus != DeliveryStatus.completed;
      } else if (_tabIndex == 2) {
        // Completed
        matchesTab = o.deliveryStatus == DeliveryStatus.completed;
      }

      return matchesSearch && matchesTab;
    }).toList();

    list.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));
    return list;
  }

  Color _prepColor(PreparationStatus s) {
    switch (s) {
      case PreparationStatus.pending:
        return AppColors.warning;
      case PreparationStatus.preparing:
        return AppColors.accent;
      case PreparationStatus.ready:
        return AppColors.success;
    }
  }

  Color _deliveryColor(DeliveryStatus s) {
    switch (s) {
      case DeliveryStatus.forDelivery:
        return const Color(0xFF1976D2);
      case DeliveryStatus.delivered:
        return AppColors.accent;
      case DeliveryStatus.completed:
        return AppColors.success;
    }
  }

  String _prepDescription(PreparationStatus s) {
    switch (s) {
      case PreparationStatus.pending:
        return 'Naka-pending sa kusina';
      case PreparationStatus.preparing:
        return 'Inihahanda / Niluluto';
      case PreparationStatus.ready:
        return 'Ready sa bahay ni Owner';
    }
  }

  String _deliveryDescription(DeliveryStatus s) {
    switch (s) {
      case DeliveryStatus.forDelivery:
        return 'Paparating na si Driver';
      case DeliveryStatus.delivered:
        return 'Nasa branch na';
      case DeliveryStatus.completed:
        return 'Nakuha na ng customer';
    }
  }

  Future<void> _markAsClaimed(BilaoOrder order) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('I-confirm ang Pagkuha'),
        content: Text(
          'Nakuha na ba ni ${order.customerName} ang kanyang order na ${order.size.label} Bilao (₱${order.totalAmount.toStringAsFixed(0)})?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oo, Nakuha Na'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirestoreService.updateBilaoStatus(
      orderId: order.id,
      deliveryStatus: DeliveryStatus.completed,
    );

    if (mounted) {
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Matagumpay!'),
          content: Text('Na-mark na bilang Completed ang order ni ${order.customerName}.'),
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

  void _showOrderDetails(BilaoOrder order) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(order.customerName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Contact: ${order.contactNumber}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Text(
              'Package: ${order.size.label} Bilao (${order.size.pax} Pax) × ${order.quantity}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Text('Total: ₱${order.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.accent)),
            const SizedBox(height: 8),
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              Text('Notes: ${order.notes}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
            ],
            Text(
              'Oras: ${order.scheduledDateTime.month}/${order.scheduledDateTime.day} at ${order.scheduledDateTime.hour.toString().padLeft(2, '0')}:${order.scheduledDateTime.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _prepColor(order.preparationStatus).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.circle_fill, size: 10, color: _prepColor(order.preparationStatus)),
                  const SizedBox(width: 6),
                  Text(
                    'Kusina: ${_prepDescription(order.preparationStatus)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _prepColor(order.preparationStatus),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _deliveryColor(order.deliveryStatus).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.circle_fill, size: 10, color: _deliveryColor(order.deliveryStatus)),
                  const SizedBox(width: 6),
                  Text(
                    'Status: ${_deliveryDescription(order.deliveryStatus)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _deliveryColor(order.deliveryStatus),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (order.deliveryStatus != DeliveryStatus.completed)
            CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(ctx);
                _markAsClaimed(order);
              },
              child: const Text('I-abot sa Customer'),
            ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeOrders = _orders.where((o) => o.deliveryStatus != DeliveryStatus.completed).length;

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
            // ── BRANCH INFO HEADER ──────────────────────────────
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
                    child: const Icon(CupertinoIcons.placemark_fill, size: 20, color: AppColors.accent),
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
                          '$activeOrders active / nag-aantay na bilao orders',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.border),


            // ── SEARCH & SEGMENTED TABS ─────────────────────────
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
                        0: Text('Lahat (${_orders.length})', style: const TextStyle(fontSize: 12)),
                        1: Text('Nag-aantay ($activeOrders)', style: const TextStyle(fontSize: 12)),
                        2: Text('Nakuha Na', style: const TextStyle(fontSize: 12)),
                      },
                      onValueChanged: (val) {
                        if (val != null) setState(() => _tabIndex = val);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── ORDERS LIST ─────────────────────────────────────
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
                                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Walang bilao orders para sa branch na ito.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Lalabas dito ang mga customer na nag-order o nag-aantay sa inyong branch.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
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
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            final isCompleted = order.deliveryStatus == DeliveryStatus.completed;

                            return StaffCard(
                              padding: const EdgeInsets.all(14),
                              borderColor: isCompleted ? null : AppColors.accent.withValues(alpha: 0.3),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header Row: Customer Name & Phone
                                  Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isCompleted
                                              ? AppColors.textSecondary.withValues(alpha: 0.15)
                                              : AppColors.accent.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          order.customerName.isNotEmpty ? order.customerName[0].toUpperCase() : 'B',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: isCompleted ? AppColors.textSecondary : AppColors.accent,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              order.customerName,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              order.contactNumber,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isCompleted
                                              ? AppColors.success.withValues(alpha: 0.12)
                                              : AppColors.accent.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '₱${order.totalAmount.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: isCompleted ? AppColors.success : AppColors.accent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Package & Scheduled time
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(CupertinoIcons.bag_fill, size: 14, color: AppColors.accent),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${order.size.label} Bilao (${order.size.pax} Pax) × ${order.quantity}',
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${order.scheduledDateTime.hour.toString().padLeft(2, '0')}:${order.scheduledDateTime.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Waiting Spot / Notes if available
                                  if (order.notes != null && order.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(CupertinoIcons.placemark, size: 12, color: AppColors.accent),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            order.notes!,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: AppColors.textPrimary,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 10),

                                  // Status Badges
                                  Row(
                                    children: [
                                      // Kitchen prep status
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: _prepColor(order.preparationStatus).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                                color: _prepColor(order.preparationStatus).withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(CupertinoIcons.flame_fill,
                                                  size: 12, color: _prepColor(order.preparationStatus)),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  _prepDescription(order.preparationStatus),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: _prepColor(order.preparationStatus),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Delivery status
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: _deliveryColor(order.deliveryStatus).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                                color: _deliveryColor(order.deliveryStatus).withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isCompleted
                                                    ? CupertinoIcons.checkmark_alt_circle_fill
                                                    : CupertinoIcons.car_fill,
                                                size: 12,
                                                color: _deliveryColor(order.deliveryStatus),
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  _deliveryDescription(order.deliveryStatus),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: _deliveryColor(order.deliveryStatus),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Actions row
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      CupertinoButton(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        onPressed: () => _showOrderDetails(order),
                                        child: const Text('Detalye', style: TextStyle(fontSize: 12)),
                                      ),
                                      if (!isCompleted) ...[
                                        const SizedBox(width: 6),
                                        StaffButton(
                                          label: 'Nakuha Na (Claimed)',
                                          icon: CupertinoIcons.checkmark_alt,
                                          color: AppColors.success,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          onPressed: () => _markAsClaimed(order),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
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
