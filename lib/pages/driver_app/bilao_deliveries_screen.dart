import 'package:flutter/cupertino.dart';
import '../../models/bilao_order.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_card.dart';
import '../../widgets/driver_nav_bar.dart';
import '../../widgets/driver_section_header.dart';
import '../../widgets/driver_top_actions.dart';
import 'bilao_delivery_detail_screen.dart';

/// Bilao Deliveries — list of orders that need to be delivered.
/// Tapping one shows the full details (address, contact, size,
/// quantity), then the same take-a-picture flow to confirm the
/// delivery was successful.
class BilaoDeliveriesScreen extends StatefulWidget {
  const BilaoDeliveriesScreen({super.key});

  @override
  State<BilaoDeliveriesScreen> createState() => _BilaoDeliveriesScreenState();
}

class _BilaoDeliveriesScreenState extends State<BilaoDeliveriesScreen> {
  final List<BilaoOrder> _orders = [
    BilaoOrder(
      id: 'ord1',
      customerName: 'Ana Lopez',
      contactNumber: '0917 555 1234',
      size: BilaoSize.large,
      quantity: 2,
      scheduledDateTime: DateTime.now(),
      deliveryAddress: 'Purok 3, Brgy. Gatid, Sta. Cruz, Laguna',
    ),
    BilaoOrder(
      id: 'ord2',
      customerName: 'Mark Villanueva',
      contactNumber: '0917 555 5678',
      size: BilaoSize.medium,
      quantity: 1,
      scheduledDateTime: DateTime.now(),
      deliveryAddress: 'Blk 5 Lot 2, Brgy. Labuin, Pila, Laguna',
    ),
  ];

  void _markDelivered(String id) {
    setState(() {
      final index = _orders.indexWhere((o) => o.id == id);
      if (index != -1) {
        _orders[index] = _orders[index]
            .copyWith(deliveryStatus: DeliveryStatus.delivered);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pending = _orders
        .where((o) => o.deliveryStatus == DeliveryStatus.forDelivery)
        .toList();
    final done = _orders
        .where((o) => o.deliveryStatus != DeliveryStatus.forDelivery)
        .toList();

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const DriverNavBar(
        title: 'Bilao Deliveries',
        trailing: DriverTopActions(initials: 'RS'),
      ),
      child: SafeArea(
        child: pending.isEmpty && done.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.pastelBrown.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.bag_fill,
                          size: 28, color: AppColors.accent),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No deliveries scheduled for today.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (pending.isNotEmpty) ...[
                    const DriverSectionHeader(
                      label: 'For Delivery',
                      icon: CupertinoIcons.bag_fill,
                    ),
                    const SizedBox(height: 10),
                  ],
                  ...pending.map((order) => _orderTile(order, isDone: false)),
                  if (done.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const DriverSectionHeader(
                      label: 'Delivered',
                      icon: CupertinoIcons.check_mark_circled_solid,
                    ),
                    const SizedBox(height: 10),
                    ...done.map((order) => _orderTile(order, isDone: true)),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _orderTile(BilaoOrder order, {required bool isDone}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: isDone
            ? null
            : () async {
                final result = await Navigator.of(context).push<bool>(
                  CupertinoPageRoute(
                    builder: (_) => BilaoDeliveryDetailScreen(order: order),
                  ),
                );
                if (result == true) {
                  _markDelivered(order.id);
                }
              },
        child: DriverCard(
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.pastelBrown.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(CupertinoIcons.bag_fill,
                    color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${order.size.label} × ${order.quantity}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isDone)
                const Icon(CupertinoIcons.check_mark_circled_solid,
                    color: AppColors.success)
              else
                const Icon(CupertinoIcons.chevron_right,
                    size: 18, color: AppColors.pastelBrown),
            ],
          ),
        ),
      ),
    );
  }
}
