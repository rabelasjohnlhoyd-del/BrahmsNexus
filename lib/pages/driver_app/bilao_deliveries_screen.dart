import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../../models/bilao_order.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_pagination_bar.dart';
import '../../widgets/driver_button.dart';
import '../../widgets/driver_card.dart';
import '../../widgets/driver_nav_bar.dart';
import '../../widgets/driver_top_actions.dart';
import 'bilao_delivery_detail_screen.dart';

/// Bilao Deliveries for Driver:
/// 1. Awareness of pending/preparing orders currently in kitchen.
/// 2. Notification when order reaches "Ready" at Owner's house.
/// 3. "For Delivery" button to mark pickup from Owner's house:
///    - If going to branch -> alerts branch staff that driver is on the way!
///    - If direct delivery -> reflects to owner as "For Delivery".
/// 4. "Complete Delivery" with photo proof -> marks delivered, records report
///    in Employee Reports, and alerts Owner.
class BilaoDeliveriesScreen extends StatefulWidget {
  const BilaoDeliveriesScreen({super.key});

  @override
  State<BilaoDeliveriesScreen> createState() => _BilaoDeliveriesScreenState();
}

class _BilaoDeliveriesScreenState extends State<BilaoDeliveriesScreen> {
  StreamSubscription<List<BilaoOrder>>? _ordersSub;
  final List<BilaoOrder> _orders = [];
  bool _isLoading = true;

  int _selectedTab = 0; // 0: Active / Ready, 1: Niluluto Pa (Upcoming), 2: Delivered
  int _activePage = 0;
  int _upcomingPage = 0;
  int _deliveredPage = 0;
  static const int _pageSize = 5;

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

  List<BilaoOrder> get _activeOrders {
    return _orders.where((o) {
      final isDeliveredOrDone =
          o.deliveryStatus == DeliveryStatus.delivered || o.deliveryStatus == DeliveryStatus.completed;
      if (isDeliveredOrDone) return false;
      // Active if ready at owner's house OR already for delivery
      return o.preparationStatus == PreparationStatus.ready ||
          o.deliveryStatus == DeliveryStatus.forDelivery;
    }).toList();
  }

  List<BilaoOrder> get _upcomingOrders {
    return _orders.where((o) {
      final isDeliveredOrDone =
          o.deliveryStatus == DeliveryStatus.delivered || o.deliveryStatus == DeliveryStatus.completed;
      if (isDeliveredOrDone) return false;
      return o.preparationStatus == PreparationStatus.pending ||
          o.preparationStatus == PreparationStatus.preparing;
    }).toList();
  }

  List<BilaoOrder> get _deliveredOrders {
    return _orders.where((o) {
      return o.deliveryStatus == DeliveryStatus.delivered ||
          o.deliveryStatus == DeliveryStatus.completed;
    }).toList();
  }

  Future<void> _startDelivery(BilaoOrder order) async {
    final destinationText = order.isBranchPickup
        ? 'sa branch (${order.pickupBranchName ?? "Branch"})'
        : 'sa customer address (${order.deliveryAddress})';

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Kunin sa Bahay ni Owner?'),
        content: Text(
          'Kukunin mo na ba ang bilao order para kay ${order.customerName} sa bahay ni Owner para i-deliver $destinationText?'
          '${order.isBranchPickup ? "\n\nMagpapadala ng abiso sa staff ng nasabing branch na paparating ka na." : ""}',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Simulan ang Delivery'),
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
          title: const Text('Delivery Started'),
          content: Text(
            order.isBranchPickup
                ? 'Naka-set na sa For Delivery! Naka-notif na ang staff ng ${order.pickupBranchName ?? "branch"} na paparating ka na.'
                : 'Naka-set na sa For Delivery! Makikita na ito ni Owner sa system.',
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
            'Matagumpay na nai-record ang delivery para kay ${order.customerName}. Nai-post na ito sa Employee Reports at may notification na si Owner.',
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

  @override
  Widget build(BuildContext context) {
    final active = _activeOrders;
    final upcoming = _upcomingOrders;
    final delivered = _deliveredOrders;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const DriverNavBar(
        title: 'Bilao Deliveries',
        trailing: DriverTopActions(),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Segmented Tab Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _selectedTab,
                  children: {
                    0: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: Text(
                        'Ready / En Route (${active.length})',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    1: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: Text(
                        'Niluluto Pa (${upcoming.length})',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    2: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: Text(
                        'Naihatid Na (${delivered.length})',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  },
                  onValueChanged: (val) {
                    if (val != null) setState(() => _selectedTab = val);
                  },
                ),
              ),
            ),

            // Tab Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _buildSelectedTabContent(active: active, upcoming: upcoming, delivered: delivered),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent({
    required List<BilaoOrder> active,
    required List<BilaoOrder> upcoming,
    required List<BilaoOrder> delivered,
  }) {
    if (_selectedTab == 0) {
      if (active.isEmpty) {
        return _emptyState(
          title: 'Walang Active Delivery',
          subtitle: 'Walang order na Ready sa bahay ni Owner o kasalukuyang For Delivery ngayon.',
        );
      }
      return _pagedOrderList(
        orders: active,
        page: _activePage,
        onPageChanged: (p) => setState(() => _activePage = p),
        itemBuilder: (order) => _buildActiveOrderCard(order),
      );
    } else if (_selectedTab == 1) {
      if (upcoming.isEmpty) {
        return _emptyState(
          title: 'Walang Niluluto Pa',
          subtitle: 'Walang pending o preparing na bilao order sa kusina sa ngayon.',
        );
      }
      return _pagedOrderList(
        orders: upcoming,
        page: _upcomingPage,
        onPageChanged: (p) => setState(() => _upcomingPage = p),
        itemBuilder: (order) => _buildUpcomingOrderCard(order),
      );
    } else {
      if (delivered.isEmpty) {
        return _emptyState(
          title: 'Walang Naihatid Na',
          subtitle: 'Wala pang bilao delivery na natapos para sa araw na ito.',
        );
      }
      return _pagedOrderList(
        orders: delivered,
        page: _deliveredPage,
        onPageChanged: (p) => setState(() => _deliveredPage = p),
        itemBuilder: (order) => _buildDeliveredOrderCard(order),
      );
    }
  }

  Widget _pagedOrderList({
    required List<BilaoOrder> orders,
    required int page,
    required ValueChanged<int> onPageChanged,
    required Widget Function(BilaoOrder order) itemBuilder,
  }) {
    final total = orders.length;
    final totalPages = (total / _pageSize).ceil();
    final effectivePage = totalPages == 0 ? 0 : page.clamp(0, totalPages - 1);
    final paged = orders.skip(effectivePage * _pageSize).take(_pageSize).toList();

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: paged.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => itemBuilder(paged[index]),
          ),
        ),
        if (total > _pageSize)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AppPaginationBar(
              currentPage: effectivePage,
              totalItems: total,
              pageSize: _pageSize,
              onPageChanged: onPageChanged,
            ),
          ),
      ],
    );
  }

  Widget _buildActiveOrderCard(BilaoOrder order) {
    final isForDelivery = order.deliveryStatus == DeliveryStatus.forDelivery;

    return DriverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isForDelivery
                      ? AppColors.warning.withValues(alpha: 0.15)
                      : AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isForDelivery ? CupertinoIcons.car_fill : CupertinoIcons.house_fill,
                  size: 20,
                  color: isForDelivery ? AppColors.warning : AppColors.success,
                ),
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
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isForDelivery
                      ? AppColors.warning.withValues(alpha: 0.12)
                      : AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isForDelivery
                        ? AppColors.warning.withValues(alpha: 0.35)
                        : AppColors.success.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  isForDelivery ? 'FOR DELIVERY' : 'READY SA OWNER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isForDelivery ? AppColors.warning : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Destination
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
                  order.isBranchPickup ? CupertinoIcons.location_solid : CupertinoIcons.map_pin_ellipse,
                  size: 13,
                  color: order.isBranchPickup ? const Color(0xFF6366F1) : AppColors.accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.destinationDisplay,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: order.isBranchPickup ? const Color(0xFF6366F1) : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Note: ${order.notes}',
              style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 8),

          // Package & Scheduled time
          Row(
            children: [
              Text(
                '${order.size.label} (${order.size.pax}pax) × ${order.quantity}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const Spacer(),
              Text(
                '${order.scheduledDateTime.month}/${order.scheduledDateTime.day} ${order.scheduledDateTime.hour.toString().padLeft(2, '0')}:${order.scheduledDateTime.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Actions
          if (!isForDelivery)
            DriverButton(
              label: 'Kunin sa Bahay ni Owner & For Delivery',
              icon: CupertinoIcons.arrow_right_circle_fill,
              color: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 11),
              onPressed: () => _startDelivery(order),
            )
          else
            DriverButton(
              label: 'I-deliver (Complete Delivery with Photo)',
              icon: CupertinoIcons.checkmark_seal_fill,
              color: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 11),
              onPressed: () => _completeDelivery(order),
            ),
        ],
      ),
    );
  }

  Widget _buildUpcomingOrderCard(BilaoOrder order) {
    final isPreparing = order.preparationStatus == PreparationStatus.preparing;

    return DriverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isPreparing
                      ? AppColors.accent.withValues(alpha: 0.15)
                      : AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPreparing ? CupertinoIcons.flame_fill : CupertinoIcons.clock_fill,
                  size: 18,
                  color: isPreparing ? AppColors.accent : AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      order.destinationDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPreparing
                      ? AppColors.accent.withValues(alpha: 0.12)
                      : AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPreparing ? 'PREPARING' : 'PENDING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isPreparing ? AppColors.accent : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Package: ${order.size.label} (${order.size.pax}pax) × ${order.quantity}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Kasalukuyang inihahanda sa kusina. Aabisuhan ka kapag Ready na para puntahan sa bahay ni Owner.',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveredOrderCard(BilaoOrder order) {
    return DriverCard(
      highlighted: true,
      borderColor: AppColors.success.withValues(alpha: 0.4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(CupertinoIcons.checkmark_seal_fill, size: 20, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  order.destinationDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.size.label} × ${order.quantity} · ₱${order.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'DELIVERED',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.success),
              ),
              SizedBox(height: 2),
              Icon(CupertinoIcons.check_mark_circled_solid, size: 16, color: AppColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState({required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
              child: const Icon(CupertinoIcons.bag_fill, size: 30, color: AppColors.accent),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
