import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../../models/bilao_order.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_button.dart';
import '../../widgets/driver_card.dart';
import '../../widgets/driver_nav_bar.dart';
import '../../widgets/driver_top_actions.dart';
import 'bilao_delivery_detail_screen.dart';

/// Bilao Deliveries for Driver:
/// - 4 Filter Tabs: Active (Ready/Out for Delivery), Preparing (In Kitchen), Completed, All.
/// - Unlocks "Out For Delivery" when order is Ready at Commissary/Owner's house.
/// - Unlocks "Complete with Photo" once in Out For Delivery status.
/// - Submits photo proof and automatically updates across Driver, Staff, and Owner apps.
class BilaoDeliveriesScreen extends StatefulWidget {
  const BilaoDeliveriesScreen({super.key});

  @override
  State<BilaoDeliveriesScreen> createState() => _BilaoDeliveriesScreenState();
}

class _BilaoDeliveriesScreenState extends State<BilaoDeliveriesScreen> {
  StreamSubscription<List<BilaoOrder>>? _ordersSub;
  final List<BilaoOrder> _orders = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _tabIndex = 0; // 0: Active, 1: Preparing, 2: Completed, 3: All

  @override
  void initState() {
    super.initState();
    _ordersSub = FirestoreService.watchAllBilaoOrders(limit: 100).listen((orders) {
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
    _ordersSub?.cancel();
    super.dispose();
  }

  bool _isOrderCompleted(BilaoOrder o) {
    return o.deliveryStatus == DeliveryStatus.completed ||
        o.deliveryStatus == DeliveryStatus.delivered;
  }

  bool _isOrderActive(BilaoOrder o) {
    if (_isOrderCompleted(o)) return false;
    return o.deliveryStatus == DeliveryStatus.outForDelivery ||
        o.preparationStatus == PreparationStatus.ready;
  }

  bool _isOrderPreparing(BilaoOrder o) {
    if (_isOrderCompleted(o)) return false;
    if (_isOrderActive(o)) return false;
    return o.preparationStatus == PreparationStatus.pending ||
        o.preparationStatus == PreparationStatus.preparing;
  }

  List<BilaoOrder> get _filteredOrders {
    var list = _orders.where((o) {
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          o.customerName.toLowerCase().contains(q) ||
          o.contactNumber.toLowerCase().contains(q) ||
          (o.pickupBranchName != null && o.pickupBranchName!.toLowerCase().contains(q)) ||
          o.deliveryAddress.toLowerCase().contains(q) ||
          (o.notes != null && o.notes!.toLowerCase().contains(q));

      bool matchesTab = true;
      if (_tabIndex == 0) {
        // Active: Ready to pick up or on the road
        matchesTab = _isOrderActive(o);
      } else if (_tabIndex == 1) {
        // Preparing: In the kitchen, upcoming for driver
        matchesTab = _isOrderPreparing(o);
      } else if (_tabIndex == 2) {
        // Completed
        matchesTab = _isOrderCompleted(o);
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

  String _cardStatusLabel(BilaoOrder o) {
    if (_isOrderCompleted(o)) {
      return 'COMPLETED';
    }
    if (o.deliveryStatus == DeliveryStatus.outForDelivery) {
      return 'OUT FOR DELIVERY';
    }
    if (o.preparationStatus == PreparationStatus.ready) {
      return 'READY FOR PICKUP';
    }
    switch (o.preparationStatus) {
      case PreparationStatus.pending:
        return 'PENDING ORDER';
      case PreparationStatus.preparing:
        return 'PREPARING';
      case PreparationStatus.ready:
        return 'READY FOR PICKUP';
    }
  }

  Color _cardStatusColor(BilaoOrder o) {
    if (_isOrderCompleted(o)) {
      return AppColors.success;
    }
    if (o.deliveryStatus == DeliveryStatus.outForDelivery) {
      return const Color(0xFF1976D2);
    }
    if (o.preparationStatus == PreparationStatus.ready) {
      return const Color(0xFFE65100); // Amber-Orange for Ready
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

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _startDelivery(BilaoOrder order) async {
    final destinationText = order.isBranchPickup
        ? 'to the branch (${order.pickupBranchName ?? "Branch"})'
        : 'to the customer address (${order.deliveryAddress})';

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Start Delivery?'),
        content: Text(
          'Pick up the bilao order for ${order.customerName} and mark as Out For Delivery $destinationText?\n\n'
          'This will notify the Owner${order.isBranchPickup ? " and the branch staff" : ""}.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Out For Delivery'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final driverName = AuthService.currentAppUser?.fullName ?? 'Driver';
    final success = await FirestoreService.startBilaoDelivery(
      order: order,
      driverName: driverName,
    );

    if (!mounted) return;

    if (success) {
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Out For Delivery'),
          content: Text(
            order.isBranchPickup
                ? 'Status updated to Out For Delivery! The Owner and staff of ${order.pickupBranchName ?? "the branch"} have been notified that you are on the way.'
                : 'Status updated to Out For Delivery! The Owner has been notified.',
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

  Future<void> _completeDelivery(BilaoOrder order) async {
    final proofUrl = await Navigator.of(context).push<String?>(
      CupertinoPageRoute(
        builder: (_) => BilaoDeliveryDetailScreen(order: order),
      ),
    );

    // proofUrl is non-null when driver submitted (could be Supabase URL or base64 fallback)
    if (proofUrl != null) {
      final driverName = AuthService.currentAppUser?.fullName ?? 'Driver';
      await FirestoreService.completeBilaoDelivery(
        order: order,
        driverName: driverName,
        deliveryProofUrl: proofUrl,
      );

      if (!mounted) return;
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Delivery Completed'),
          content: Text(
            'Delivery for ${order.customerName} has been recorded successfully. The report has been saved and marked completed across Owner and Staff apps.',
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

  // ── Details Dialog ──────────────────────────────────────────────────────────

  void _showOrderDetails(BilaoOrder order) {
    final statusLabel = _cardStatusLabel(order);
    final statusColor = _cardStatusColor(order);
    final isCompleted = _isOrderCompleted(order);
    final isOutForDelivery = order.deliveryStatus == DeliveryStatus.outForDelivery;
    final isReady = order.preparationStatus == PreparationStatus.ready && !isCompleted;

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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Text(
              'Total: \u20b1${order.totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              order.isBranchPickup
                  ? 'Fulfillment: Branch Pickup (${order.pickupBranchName ?? "Branch"})'
                  : 'Fulfillment: Direct Delivery (${order.deliveryAddress})',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Note: ${order.notes}',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Schedule: ${order.scheduledDateTime.month}/${order.scheduledDateTime.day} at '
              '${order.scheduledDateTime.hour.toString().padLeft(2, '0')}:'
              '${order.scheduledDateTime.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
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
                  Icon(CupertinoIcons.circle_fill, size: 9, color: statusColor),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (isReady && !isOutForDelivery && !isCompleted)
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                _startDelivery(order);
              },
              child: const Text('Start Delivery'),
            ),
          if (isOutForDelivery && !isCompleted)
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                _completeDelivery(order);
              },
              child: const Text('Complete with Photo'),
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
    final activeCount = _orders.where(_isOrderActive).length;
    final prepCount = _orders.where(_isOrderPreparing).length;
    final completedCount = _orders.where(_isOrderCompleted).length;
    final allCount = _orders.length;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const DriverNavBar(
        title: 'Bilao Deliveries',
        trailing: DriverTopActions(),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── SEARCH & 4 DISTINCT TABS ─────────────────────────────────────
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
                            'Active ($activeCount)',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        1: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Text(
                            'Prep ($prepCount)',
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
                                Container(
                                  width: 64,
                                  height: 64,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.pastelBrown.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.bag_fill,
                                    size: 28,
                                    color: AppColors.accent,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _emptyStateTitle(_tabIndex),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _emptyStateSubtitle(_tabIndex),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12.5,
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
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            return _DriverOrderBox(
                              order: order,
                              statusLabel: _cardStatusLabel(order),
                              statusColor: _cardStatusColor(order),
                              onTap: () => _showOrderDetails(order),
                              onStartDelivery: () => _startDelivery(order),
                              onCompleteDelivery: () => _completeDelivery(order),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _emptyStateTitle(int tab) {
    switch (tab) {
      case 0:
        return 'No Active Deliveries';
      case 1:
        return 'No Orders in Preparation';
      case 2:
        return 'No Completed Deliveries';
      default:
        return 'No Bilao Orders';
    }
  }

  String _emptyStateSubtitle(int tab) {
    switch (tab) {
      case 0:
        return 'Orders will appear here once marked Ready for Delivery from the kitchen.';
      case 1:
        return 'Upcoming orders currently being prepared in the kitchen will appear here.';
      case 2:
        return 'Successfully delivered bilao orders will appear here.';
      default:
        return 'No bilao orders found in records.';
    }
  }
}

// ── Driver Order Box ─────────────────────────────────────────────────────────

class _DriverOrderBox extends StatelessWidget {
  const _DriverOrderBox({
    required this.order,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
    required this.onStartDelivery,
    required this.onCompleteDelivery,
  });

  final BilaoOrder order;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;
  final VoidCallback onStartDelivery;
  final VoidCallback onCompleteDelivery;

  @override
  Widget build(BuildContext context) {
    final isCompleted = order.deliveryStatus == DeliveryStatus.completed ||
        order.deliveryStatus == DeliveryStatus.delivered;
    final isOutForDelivery = order.deliveryStatus == DeliveryStatus.outForDelivery;
    final isReady = order.preparationStatus == PreparationStatus.ready && !isCompleted;
    final isPendingOrPreparing = !isReady && !isOutForDelivery && !isCompleted;

    IconData leadIcon;
    Color leadColor;
    if (isCompleted) {
      leadIcon = CupertinoIcons.checkmark_seal_fill;
      leadColor = AppColors.success;
    } else if (isOutForDelivery) {
      leadIcon = CupertinoIcons.car_fill;
      leadColor = const Color(0xFF1976D2);
    } else if (isReady) {
      leadIcon = CupertinoIcons.house_fill;
      leadColor = const Color(0xFFE65100);
    } else if (order.preparationStatus == PreparationStatus.preparing) {
      leadIcon = CupertinoIcons.flame_fill;
      leadColor = AppColors.accent;
    } else {
      leadIcon = CupertinoIcons.clock_fill;
      leadColor = AppColors.warning;
    }

    return GestureDetector(
      onTap: onTap,
      child: DriverCard(
        padding: const EdgeInsets.all(14),
        borderColor: isCompleted
            ? AppColors.success.withValues(alpha: 0.3)
            : isOutForDelivery
                ? const Color(0xFF1976D2).withValues(alpha: 0.35)
                : isReady
                    ? const Color(0xFFE65100).withValues(alpha: 0.4)
                    : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Lead Icon, Name, Contact, Status Pill
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: leadColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(leadIcon, size: 20, color: leadColor),
                ),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 2),
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
                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.35)),
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
              ],
            ),
            const SizedBox(height: 10),

            // Destination Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    order.isBranchPickup
                        ? CupertinoIcons.location_solid
                        : CupertinoIcons.map_pin_ellipse,
                    size: 13,
                    color: order.isBranchPickup
                        ? const Color(0xFF6366F1)
                        : AppColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.destinationDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: order.isBranchPickup
                            ? const Color(0xFF6366F1)
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Package & Scheduled Time
            Row(
              children: [
                Text(
                  '${order.size.label} (${order.size.pax} Pax) × ${order.quantity} · \u20b1${order.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${order.scheduledDateTime.month}/${order.scheduledDateTime.day} '
                  '${order.scheduledDateTime.hour.toString().padLeft(2, '0')}:'
                  '${order.scheduledDateTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),

            // Action Buttons
            if (isReady && !isOutForDelivery && !isCompleted) ...[
              const SizedBox(height: 12),
              DriverButton(
                label: 'Out For Delivery',
                icon: CupertinoIcons.car_fill,
                color: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 11),
                onPressed: onStartDelivery,
              ),
            ] else if (isOutForDelivery && !isCompleted) ...[
              const SizedBox(height: 12),
              DriverButton(
                label: 'Complete the delivery with a photo',
                icon: CupertinoIcons.camera_fill,
                color: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 11),
                onPressed: onCompleteDelivery,
              ),
            ] else if (isPendingOrPreparing) ...[
              const SizedBox(height: 8),
              const Text(
                'Currently being prepared in the kitchen. You will be notified once ready for pickup.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
