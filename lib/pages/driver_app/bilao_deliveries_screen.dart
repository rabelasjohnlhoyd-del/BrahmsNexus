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
/// - 2 Tabs: All and Completed.
/// - Simple order box with customer name, number, package, and destination.
/// - Tap the box to view full order details.
/// - When Ready at Owner's house: shows "FOR DELIVERY" badge and "Out For Delivery" button.
/// - Clicking "Out For Delivery": updates status to Out For Delivery (alerts Owner & Staff),
///   and unlocks the "Complete the delivery with a photo" button.
/// - Completing with photo: automatically marks the order as Completed across Driver, Staff, and Owner.
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
  int _tabIndex = 0; // 0: All, 1: Completed

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
      if (_tabIndex == 1) {
        matchesTab = o.deliveryStatus == DeliveryStatus.completed ||
            o.deliveryStatus == DeliveryStatus.delivered;
      }

      return matchesSearch && matchesTab;
    }).toList();

    list.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));
    return list;
  }

  // ── Status helpers ──────────────────────────────────────────────────────────

  String _cardStatusLabel(BilaoOrder o) {
    if (o.deliveryStatus == DeliveryStatus.completed ||
        o.deliveryStatus == DeliveryStatus.delivered) {
      return 'COMPLETED';
    }
    if (o.deliveryStatus == DeliveryStatus.outForDelivery) {
      return 'OUT FOR DELIVERY';
    }
    if (o.preparationStatus == PreparationStatus.ready) {
      return 'FOR DELIVERY';
    }
    switch (o.preparationStatus) {
      case PreparationStatus.pending:
        return 'PENDING';
      case PreparationStatus.preparing:
        return 'PREPARING';
      case PreparationStatus.ready:
        return 'FOR DELIVERY';
    }
  }

  Color _cardStatusColor(BilaoOrder o) {
    if (o.deliveryStatus == DeliveryStatus.completed ||
        o.deliveryStatus == DeliveryStatus.delivered) {
      return AppColors.success;
    }
    if (o.deliveryStatus == DeliveryStatus.outForDelivery) {
      return const Color(0xFF1976D2);
    }
    if (o.preparationStatus == PreparationStatus.ready) {
      return AppColors.warning;
    }
    switch (o.preparationStatus) {
      case PreparationStatus.pending:
        return AppColors.warning;
      case PreparationStatus.preparing:
        return AppColors.accent;
      case PreparationStatus.ready:
        return AppColors.warning;
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _startDelivery(BilaoOrder order) async {
    final destinationText = order.isBranchPickup
        ? 'sa branch (${order.pickupBranchName ?? "Branch"})'
        : 'sa customer address (${order.deliveryAddress})';

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Out For Delivery?'),
        content: Text(
          'Kukunin mo na ba ang bilao order para kay ${order.customerName} sa bahay ni Owner at ilalagay sa Out For Delivery $destinationText?\n\n'
          'Magpapadala ito ng abiso kay Owner${order.isBranchPickup ? " at sa staff ng nasabing branch" : ""}.',
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
                ? 'Naka-set na sa Out For Delivery! Naka-notif na si Owner at ang staff ng ${order.pickupBranchName ?? "branch"} na paparating ka na.'
                : 'Naka-set na sa Out For Delivery! Naka-notif na si Owner sa system.',
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
    final result = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => BilaoDeliveryDetailScreen(order: order),
      ),
    );

    if (result == true) {
      final driverName = AuthService.currentAppUser?.fullName ?? 'Driver';
      await FirestoreService.completeBilaoDelivery(
        order: order,
        driverName: driverName,
      );

      if (!mounted) return;
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Delivery Completed'),
          content: Text(
            'Matagumpay na nai-record ang delivery para kay ${order.customerName}. Nai-post na ito sa Employee Reports at automated completed na sa Owner at Staff apps.',
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
    final isCompleted = order.deliveryStatus == DeliveryStatus.completed ||
        order.deliveryStatus == DeliveryStatus.delivered;
    final isOutForDelivery = order.deliveryStatus == DeliveryStatus.outForDelivery;
    final isReady = order.preparationStatus == PreparationStatus.ready;

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
                  ? 'Pickup: ${order.pickupBranchName ?? "Branch"}'
                  : 'Delivery: ${order.deliveryAddress}',
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
              child: const Text('Out For Delivery'),
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

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final completedCount = _orders
        .where((o) =>
            o.deliveryStatus == DeliveryStatus.completed ||
            o.deliveryStatus == DeliveryStatus.delivered)
        .length;
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
            // ── SEARCH & TABS ───────────────────────────────────────────────
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Text(
                            'All ($allCount)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        1: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Text(
                            'Completed ($completedCount)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
                                  width: 72,
                                  height: 72,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.pastelBrown.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.bag_fill,
                                    size: 30,
                                    color: AppColors.accent,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _tabIndex == 1
                                      ? 'Walang Completed Orders'
                                      : 'Walang Bilao Deliveries',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _tabIndex == 1
                                      ? 'Wala pang bilao orders na naihatid at nakumpleto.'
                                      : 'Lalabas dito ang mga bilao orders na nakatakdang i-deliver.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
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
    final isReady = order.preparationStatus == PreparationStatus.ready;
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
      leadColor = AppColors.warning;
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
                    ? AppColors.warning.withValues(alpha: 0.4)
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
                'Inihahanda pa sa kusina. Aabisuhan ka kapag Ready na sa bahay ni Owner.',
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
