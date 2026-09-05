import 'package:flutter/cupertino.dart';
import '../../models/bilao_order.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_top_actions.dart';
import 'bilao_delivery_detail_screen.dart';

/// Bilao Deliveries — listahan ng mga order na kailangang i-deliver.
/// Pag pinindot, makikita ang buong impormasyon (address, contact,
/// size, quantity), tapos parehong take-a-picture flow para i-confirm
/// na successful ang delivery.
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
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Bilao Deliveries'),
        trailing: DriverTopActions(initials: 'RS'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pending.isEmpty && done.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'Walang delivery ngayong araw.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ...pending.map((order) => _orderTile(order, isDone: false)),
            if (done.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Naideliver Na',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
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
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
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
