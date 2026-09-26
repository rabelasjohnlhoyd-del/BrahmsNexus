import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/bilao_order.dart';
import '../../../services/firestore_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import '../admin_web_widgets/admin_pagination_bar.dart';
import 'add_bilao_order_screen.dart';

/// Admin records confirmed advance/special bilao orders here (received
/// via Messenger/phone — customers never order directly in-app), then
/// tracks their Preparation and Delivery status through to completion.
///
/// Backed by live real-time Firestore sync.
class BilaoOrderScreen extends StatefulWidget {
  const BilaoOrderScreen({super.key});

  @override
  State<BilaoOrderScreen> createState() => _BilaoOrderScreenState();
}

class _BilaoOrderScreenState extends State<BilaoOrderScreen> {
  static const double _wideBreakpoint = 700;

  int _currentPage = 0;
  static const int _pageSize = 6;
  StreamSubscription<List<BilaoOrder>>? _ordersSub;

  final List<BilaoOrder> _orders = [
    BilaoOrder(
      id: 'ord1',
      customerName: 'Ana Lopez',
      contactNumber: '0917 555 1234',
      size: BilaoSize.large,
      quantity: 2,
      scheduledDateTime: DateTime.now().add(const Duration(hours: 5)),
      fulfillmentType: BilaoFulfillmentType.branchPickup,
      pickupBranchId: 'br1',
      pickupBranchName: 'Brgy. Gatid, Sta. Cruz',
      notes: 'Customer nag-aantay sa Table 2',
      preparationStatus: PreparationStatus.preparing,
      deliveryStatus: DeliveryStatus.forDelivery,
    ),
    BilaoOrder(
      id: 'ord2',
      customerName: 'Mark Villanueva',
      contactNumber: '0917 555 5678',
      size: BilaoSize.medium,
      quantity: 1,
      scheduledDateTime: DateTime.now().add(const Duration(days: 1)),
      fulfillmentType: BilaoFulfillmentType.directDelivery,
      deliveryAddress: 'Blk 5 Lot 2, Brgy. Labuin, Pila, Laguna',
      notes: 'Katabi ng kapilya, tawagan bago pumunta',
      preparationStatus: PreparationStatus.pending,
      deliveryStatus: DeliveryStatus.forDelivery,
    ),
    BilaoOrder(
      id: 'ord3',
      customerName: 'Liza Gomez',
      contactNumber: '0917 555 9012',
      size: BilaoSize.small,
      quantity: 3,
      scheduledDateTime: DateTime.now().subtract(const Duration(days: 2)),
      fulfillmentType: BilaoFulfillmentType.branchPickup,
      pickupBranchId: 'br2',
      pickupBranchName: 'Brgy. Labuin, Pila',
      preparationStatus: PreparationStatus.ready,
      deliveryStatus: DeliveryStatus.completed,
    ),
  ];

  String _searchQuery = '';
  String _statusFilter = 'All';
  String _fulfillmentFilter = 'All';

  static const _statusFilters = [
    'All',
    'Pending',
    'Preparing',
    'Ready',
    'For Delivery',
    'Delivered',
    'Completed',
  ];

  static const _fulfillmentFilters = [
    'All',
    'Branch Pickup',
    'Direct Delivery',
  ];

  List<BilaoOrder> get _visibleOrders {
    var list = _orders.where((o) {
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          o.customerName.toLowerCase().contains(q) ||
          o.contactNumber.toLowerCase().contains(q) ||
          o.id.toLowerCase().contains(q) ||
          (o.pickupBranchName != null && o.pickupBranchName!.toLowerCase().contains(q)) ||
          o.deliveryAddress.toLowerCase().contains(q);

      final matchesStatus = _statusFilter == 'All' ||
          o.preparationStatus.label == _statusFilter ||
          o.deliveryStatus.label == _statusFilter;

      final matchesFulfillment = _fulfillmentFilter == 'All' ||
          (_fulfillmentFilter == 'Branch Pickup' && o.isBranchPickup) ||
          (_fulfillmentFilter == 'Direct Delivery' && !o.isBranchPickup);

      return matchesSearch && matchesStatus && matchesFulfillment;
    }).toList();

    list.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));
    return list;
  }


  Future<void> _deleteOrder(BilaoOrder order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AdminWebColors.error),
            SizedBox(width: 10),
            Text('Delete Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'Sigurado ka bang nais mong tanggalin ang order para kay "${order.customerName}"? Hindi na ito maibabalik.',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminWebColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirestoreService.deleteBilaoOrder(order.id);
    setState(() {
      _orders.removeWhere((o) => o.id == order.id);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order para kay ${order.customerName} ay natanggal na.')),
      );
    }
  }

  void _showOrderDetails(BilaoOrder initialOrder) {
    var currentOrder = initialOrder;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final prepColor = _prepColor(currentOrder.preparationStatus);
          final deliveryColor = _deliveryColor(currentOrder.deliveryStatus);

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AdminWebColors.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: AdminWebColors.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currentOrder.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('#${currentOrder.id.toUpperCase()}',
                          style: const TextStyle(fontSize: 11, color: AdminWebColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _detailTile(
                      icon: Icons.phone_outlined,
                      label: 'CONTACT NUMBER',
                      value: currentOrder.contactNumber,
                    ),
                    const SizedBox(height: 12),
                    _detailTile(
                      icon: currentOrder.isBranchPickup ? Icons.storefront_rounded : Icons.local_shipping_outlined,
                      label: currentOrder.isBranchPickup ? 'BRANCH PICKUP (NAG-AANTAY SA BRANCH)' : 'DELIVERY ADDRESS',
                      value: currentOrder.destinationDisplay,
                      valueColor: currentOrder.isBranchPickup ? AdminWebColors.accent : AdminWebColors.textPrimary,
                    ),
                    if (currentOrder.notes != null && currentOrder.notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _detailTile(
                        icon: Icons.edit_note_rounded,
                        label: 'NOTES / REMARKS',
                        value: currentOrder.notes!,
                      ),
                    ],
                    const Divider(height: 24),
                    _detailTile(
                      icon: Icons.shopping_basket_outlined,
                      label: 'PACKAGE & QUANTITY',
                      value: '${currentOrder.size.label} Bilao (${currentOrder.size.pax} Pax · ${currentOrder.size.weightLabel}) × ${currentOrder.quantity}',
                    ),
                    const SizedBox(height: 12),
                    _detailTile(
                      icon: Icons.payments_outlined,
                      label: 'TOTAL AMOUNT',
                      value: '₱${currentOrder.totalAmount.toStringAsFixed(0)} (₱${currentOrder.effectiveUnitPrice.toStringAsFixed(0)} bawat isa)',
                      valueColor: AdminWebColors.accent,
                    ),
                    const Divider(height: 24),
                    _detailTile(
                      icon: Icons.schedule_rounded,
                      label: 'SCHEDULED DATE & TIME',
                      value: '${currentOrder.scheduledDateTime.month}/${currentOrder.scheduledDateTime.day}/${currentOrder.scheduledDateTime.year} at ${currentOrder.scheduledDateTime.hour.toString().padLeft(2, '0')}:${currentOrder.scheduledDateTime.minute.toString().padLeft(2, '0')}',
                    ),
                    const Divider(height: 24),

                    // ── STEP-BY-STEP PREPARATION WORKFLOW ─────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AdminWebColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: prepColor.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.restaurant_rounded, size: 16, color: prepColor),
                              const SizedBox(width: 8),
                              const Text(
                                'STEP-BY-STEP PREPARATION PROGRESS',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: AdminWebColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Step 1: Pending
                          _buildDetailStepItem(
                            stepNumber: 1,
                            title: 'Pending',
                            subtitle: 'Nakapila ang order para lutuin',
                            isDone: currentOrder.preparationStatus == PreparationStatus.preparing || currentOrder.preparationStatus == PreparationStatus.ready,
                            isCurrent: currentOrder.preparationStatus == PreparationStatus.pending,
                          ),
                          const SizedBox(height: 10),

                          // Step 2: Preparing
                          _buildDetailStepItem(
                            stepNumber: 2,
                            title: 'Preparing',
                            subtitle: 'Kasalukuyang inihahanda at niluluto sa kusina',
                            isDone: currentOrder.preparationStatus == PreparationStatus.ready,
                            isCurrent: currentOrder.preparationStatus == PreparationStatus.preparing,
                          ),
                          const SizedBox(height: 10),

                          // Step 3: Ready
                          _buildDetailStepItem(
                            stepNumber: 3,
                            title: 'Ready',
                            subtitle: 'Luto na sa bahay ni Owner, handa nang kunin ni Driver',
                            isDone: currentOrder.preparationStatus == PreparationStatus.ready,
                            isCurrent: currentOrder.preparationStatus == PreparationStatus.ready,
                          ),
                          const SizedBox(height: 14),

                          // Action button or completed badge (forward-only, non-reversible)
                          if (currentOrder.preparationStatus == PreparationStatus.pending)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final next = await FirestoreService.advanceBilaoPreparation(currentOrder);
                                  if (next != null) {
                                    setDialogState(() {
                                      currentOrder = currentOrder.copyWith(preparationStatus: next);
                                    });
                                    setState(() {
                                      final idx = _orders.indexWhere((o) => o.id == currentOrder.id);
                                      if (idx >= 0) _orders[idx] = currentOrder;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                label: const Text('Start Preparing'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AdminWebColors.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            )
                          else if (currentOrder.preparationStatus == PreparationStatus.preparing)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final next = await FirestoreService.advanceBilaoPreparation(currentOrder);
                                  if (next != null) {
                                    setDialogState(() {
                                      currentOrder = currentOrder.copyWith(preparationStatus: next);
                                    });
                                    setState(() {
                                      final idx = _orders.indexWhere((o) => o.id == currentOrder.id);
                                      if (idx >= 0) _orders[idx] = currentOrder;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                label: const Text('Ready'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AdminWebColors.success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: AdminWebColors.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AdminWebColors.success.withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 16, color: AdminWebColors.success),
                                  SizedBox(width: 8),
                                  Text(
                                    'HANDA NA SA BAHAY NI OWNER (READY FOR DRIVER PICKUP)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AdminWebColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 6),
                          const Text(
                            'Paalala: Bawal umatras sa nakaraang hakbang kapag nakapag-proceed na.',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                              color: AdminWebColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Delivery status tile
                    _detailTile(
                      icon: Icons.moped_rounded,
                      label: 'DELIVERY STATUS',
                      value: currentOrder.deliveryStatus.label.toUpperCase(),
                      valueColor: deliveryColor,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _buildDetailStepItem({
    required int stepNumber,
    required String title,
    required String subtitle,
    required bool isDone,
    required bool isCurrent,
  }) {
    final Color badgeColor = isDone
        ? AdminWebColors.success
        : (isCurrent ? AdminWebColors.accent : AdminWebColors.border);
    final Color textColor = isDone
        ? AdminWebColors.success
        : (isCurrent ? AdminWebColors.textPrimary : AdminWebColors.textSecondary);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDone
                ? AdminWebColors.success
                : (isCurrent ? AdminWebColors.accent.withValues(alpha: 0.15) : AdminWebColors.background),
            shape: BoxShape.circle,
            border: Border.all(color: badgeColor, width: 2),
          ),
          child: isDone
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '$stepNumber',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isCurrent ? AdminWebColors.accent : AdminWebColors.textSecondary,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isCurrent || isDone ? FontWeight.w800 : FontWeight.w600,
                  color: textColor,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10.5, color: AdminWebColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AdminWebColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: AdminWebColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? AdminWebColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openAddOrder() async {
    final result = await Navigator.of(context).push<BilaoOrder>(
      MaterialPageRoute(builder: (context) => const AddBilaoOrderScreen()),
    );

    if (!mounted) return;
    _updateShellActions();

    if (result == null) return;

    setState(() {
      final existingIdx = _orders.indexWhere((o) => o.id == result.id);
      if (existingIdx >= 0) {
        _orders[existingIdx] = result;
      } else {
        _orders.insert(0, result);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order para kay ${result.customerName} ay matagumpay na naitala.')),
    );
  }

  Color _prepColor(PreparationStatus s) {
    switch (s) {
      case PreparationStatus.pending:
        return AdminWebColors.warning;
      case PreparationStatus.preparing:
        return AdminWebColors.accent;
      case PreparationStatus.ready:
        return AdminWebColors.success;
    }
  }

  Color _deliveryColor(DeliveryStatus s) {
    switch (s) {
      case DeliveryStatus.forDelivery:
        return AdminWebColors.warning;
      case DeliveryStatus.delivered:
        return AdminWebColors.accent;
      case DeliveryStatus.completed:
        return AdminWebColors.success;
    }
  }

  @override
  void initState() {
    super.initState();
    _updateShellActions();
    _ordersSub = FirestoreService.watchAllBilaoOrders().listen((orders) {
      if (mounted) {
        setState(() {
          _orders
            ..clear()
            ..addAll(orders);
        });
      }
    });
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(BilaoOrderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
  }

  final Map<BilaoSize, double> _prices = {
    BilaoSize.small: 750.0,
    BilaoSize.medium: 950.0,
    BilaoSize.large: 1300.0,
  };

  void _showPricingDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.sell_rounded, color: AdminWebColors.accent),
                SizedBox(width: 10),
                Text('Bilao Pricing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: BilaoSize.values.map((size) {
                  final price = _prices[size] ?? size.price;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AdminWebColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminWebColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${size.label.toUpperCase()} (${size.pax} PAX)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: AdminWebColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Current: ₱${price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AdminWebColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 20, color: AdminWebColors.accent),
                            onPressed: () {
                              final ctrl = TextEditingController(text: price.toStringAsFixed(0));
                              showDialog<void>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: Text('Edit Price: ${size.label}'),
                                  content: TextField(
                                    controller: ctrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'PRICE (₱)',
                                      prefixText: '₱ ',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c),
                                      child: const Text('CANCEL'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        final val = double.tryParse(ctrl.text);
                                        if (val != null) {
                                          setState(() => _prices[size] = val);
                                          setDialogState(() {});
                                        }
                                        Navigator.pop(c);
                                      },
                                      child: const Text('SAVE'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('DONE'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([]);
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AdminWebColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalOrders = _orders.length;
    final pendingCount = _orders.where((o) => o.preparationStatus == PreparationStatus.pending).length;
    final inPrepCount = _orders.where((o) => o.preparationStatus == PreparationStatus.preparing || o.preparationStatus == PreparationStatus.ready).length;
    final forDeliveryCount = _orders.where((o) => o.deliveryStatus == DeliveryStatus.forDelivery).length;
    final completedCount = _orders.where((o) => o.deliveryStatus == DeliveryStatus.completed || o.deliveryStatus == DeliveryStatus.delivered).length;
    final totalSales = _orders.fold<double>(0, (sum, o) => sum + o.totalAmount);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;

        return Container(
          color: AdminWebColors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // ── KPI SUMMARY CARDS ──────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
                child: isWide
                    ? Row(
                        children: [
                          Expanded(child: _statCard('Total Orders', '$totalOrders', AdminWebColors.textPrimary, Icons.inventory_2_outlined)),
                          const SizedBox(width: 10),
                          Expanded(child: _statCard('Pending Prep', '$pendingCount', AdminWebColors.warning, Icons.hourglass_top_rounded)),
                          const SizedBox(width: 10),
                          Expanded(child: _statCard('In Kitchen', '$inPrepCount', AdminWebColors.accent, Icons.restaurant_rounded)),
                          const SizedBox(width: 10),
                          Expanded(child: _statCard('For Delivery', '$forDeliveryCount', AdminWebColors.warning, Icons.moped_rounded)),
                          const SizedBox(width: 10),
                          Expanded(child: _statCard('Completed', '$completedCount', AdminWebColors.success, Icons.check_circle_outline_rounded)),
                          const SizedBox(width: 10),
                          Expanded(child: _statCard('Total Sales', '₱${totalSales.toStringAsFixed(0)}', AdminWebColors.accent, Icons.payments_outlined)),
                        ],
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(width: (constraints.maxWidth - 40) / 2, child: _statCard('Total Orders', '$totalOrders', AdminWebColors.textPrimary, Icons.inventory_2_outlined)),
                          SizedBox(width: (constraints.maxWidth - 40) / 2, child: _statCard('Pending Prep', '$pendingCount', AdminWebColors.warning, Icons.hourglass_top_rounded)),
                          SizedBox(width: (constraints.maxWidth - 40) / 2, child: _statCard('For Delivery', '$forDeliveryCount', AdminWebColors.warning, Icons.moped_rounded)),
                          SizedBox(width: (constraints.maxWidth - 40) / 2, child: _statCard('Completed', '$completedCount', AdminWebColors.success, Icons.check_circle_outline_rounded)),
                        ],
                      ),
              ),
              const SizedBox(height: 16),

              // ── TOP CONTROLS & FILTERS ──────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showPricingDialog,
                          icon: const Icon(Icons.sell_outlined,
                              size: 16, color: AdminWebColors.accent),
                          label: const Text(
                            'PRICING',
                            style: TextStyle(
                              color: AdminWebColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AdminWebColors.border),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _openAddOrder,
                          icon: const Icon(Icons.add_rounded,
                              size: 18, color: Colors.white),
                          label: const Text('NEW ORDER'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminWebColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    isWide
                        ? Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  decoration: const InputDecoration(
                                    hintText: 'Search by customer, phone, branch, or order ID...',
                                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                                    isDense: true,
                                  ),
                                  onChanged: (v) =>
                                      setState(() => _searchQuery = v),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  // ignore: deprecated_member_use
                                  value: _statusFilter,
                                  decoration: const InputDecoration(
                                    labelText: 'FILTER BY STATUS',
                                    isDense: true,
                                    prefixIcon:
                                        Icon(Icons.filter_list_rounded, size: 18),
                                  ),
                                  items: _statusFilters
                                      .map((s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s.toUpperCase())))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _statusFilter = v);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  // ignore: deprecated_member_use
                                  value: _fulfillmentFilter,
                                  decoration: const InputDecoration(
                                    labelText: 'FULFILLMENT TYPE',
                                    isDense: true,
                                    prefixIcon:
                                        Icon(Icons.place_outlined, size: 18),
                                  ),
                                  items: _fulfillmentFilters
                                      .map((s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s.toUpperCase())))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _fulfillmentFilter = v);
                                  },
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                decoration: const InputDecoration(
                                  hintText: 'Search by customer, phone, or branch...',
                                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                                  isDense: true,
                                ),
                                onChanged: (v) => setState(() => _searchQuery = v),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      // ignore: deprecated_member_use
                                      value: _statusFilter,
                                      decoration: const InputDecoration(
                                        labelText: 'STATUS',
                                        isDense: true,
                                      ),
                                      items: _statusFilters
                                          .map((s) => DropdownMenuItem(
                                              value: s, child: Text(s.toUpperCase(), style: const TextStyle(fontSize: 12))))
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) setState(() => _statusFilter = v);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      // ignore: deprecated_member_use
                                      value: _fulfillmentFilter,
                                      decoration: const InputDecoration(
                                        labelText: 'TYPE',
                                        isDense: true,
                                      ),
                                      items: _fulfillmentFilters
                                          .map((s) => DropdownMenuItem(
                                              value: s, child: Text(s.toUpperCase(), style: const TextStyle(fontSize: 12))))
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) setState(() => _fulfillmentFilter = v);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── ORDER CARDS LIST ───────────────────────────────────
              Expanded(
                child: _visibleOrders.isEmpty
                    ? const Center(
                        child: Text(
                          'Walang bilao order na tumutugma sa filter.',
                          style: TextStyle(color: AdminWebColors.textSecondary),
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.separated(
                              padding: EdgeInsets.fromLTRB(
                                isWide ? 24 : 16,
                                0,
                                isWide ? 24 : 16,
                                12,
                              ),
                              itemCount: (_visibleOrders.length - (_currentPage * _pageSize)).clamp(0, _pageSize),
                              separatorBuilder: (_, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final order = _visibleOrders[(_currentPage * _pageSize) + index];
                                return _OrderCard(
                                  order: order,
                                  isWide: isWide,
                                  onViewDetails: () => _showOrderDetails(order),
                                  onDelete: () => _deleteOrder(order),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          AdminPaginationBar(
                            currentPage: _currentPage,
                            totalItems: _visibleOrders.length,
                            pageSize: _pageSize,
                            onPageChanged: (p) => setState(() => _currentPage = p),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Simple order card — shows customer info, status badge, and a DETAILS
/// button. All preparation advancement (Start Prep → Ready → notif Driver)
/// is done inside the Details dialog. Delivery is fully automated by the
/// Driver app, so there is no delivery dropdown here.
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.isWide,
    required this.onViewDetails,
    required this.onDelete,
  });

  final BilaoOrder order;
  final bool isWide;
  final VoidCallback onViewDetails;
  final VoidCallback onDelete;

  static Color _prepColor(PreparationStatus s) {
    switch (s) {
      case PreparationStatus.pending:
        return AdminWebColors.warning;
      case PreparationStatus.preparing:
        return AdminWebColors.accent;
      case PreparationStatus.ready:
        return AdminWebColors.success;
    }
  }

  static Color _deliveryColor(DeliveryStatus s) {
    switch (s) {
      case DeliveryStatus.forDelivery:
        return AdminWebColors.warning;
      case DeliveryStatus.delivered:
        return AdminWebColors.accent;
      case DeliveryStatus.completed:
        return AdminWebColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prepColor = _prepColor(order.preparationStatus);
    final delivColor = _deliveryColor(order.deliveryStatus);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onViewDetails,
        borderRadius: BorderRadius.circular(16),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── LEFT: Plain Customer Information ─────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name
                    Row(
                      children: [
                        Text(
                          order.customerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                            color: AdminWebColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AdminWebColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#${order.id.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AdminWebColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Contact
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 13, color: AdminWebColors.textSecondary),
                        const SizedBox(width: 5),
                        Text(
                          order.contactNumber,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AdminWebColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Location / fulfillment badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: order.isBranchPickup
                            ? AdminWebColors.accent.withValues(alpha: 0.08)
                            : const Color(0xFF0F9D58).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: order.isBranchPickup
                              ? AdminWebColors.accent.withValues(alpha: 0.3)
                              : const Color(0xFF0F9D58).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            order.isBranchPickup ? Icons.storefront_rounded : Icons.local_shipping_outlined,
                            size: 13,
                            color: order.isBranchPickup ? AdminWebColors.accent : const Color(0xFF0F9D58),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              order.isBranchPickup
                                  ? 'BRANCH: ${order.pickupBranchName ?? order.deliveryAddress}'
                                  : 'DELIVERY: ${order.deliveryAddress}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: order.isBranchPickup ? AdminWebColors.accent : const Color(0xFF0F9D58),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Package + amount + scheduled time
                    Row(
                      children: [
                        const Icon(Icons.shopping_basket_outlined, size: 12, color: AdminWebColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${order.size.label} (${order.size.pax}pax) × ${order.quantity}  ·  ₱${order.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AdminWebColors.textPrimary),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.event_available_rounded, size: 12, color: AdminWebColors.textSecondary.withValues(alpha: 0.7)),
                        const SizedBox(width: 3),
                        Text(
                          '${order.scheduledDateTime.month}/${order.scheduledDateTime.day} '
                          '${order.scheduledDateTime.hour.toString().padLeft(2, '0')}:${order.scheduledDateTime.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 11, color: AdminWebColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // ── Status Badges ─────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: prepColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: prepColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restaurant_rounded, size: 11, color: prepColor),
                        const SizedBox(width: 4),
                        Text(
                          order.preparationStatus.label.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: prepColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: delivColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: delivColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.moped_rounded, size: 11, color: delivColor),
                        const SizedBox(width: 4),
                        Text(
                          order.deliveryStatus.label.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: delivColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // ── Delete Button sa gilid ───────────────────────────
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AdminWebColors.error),
                tooltip: 'Delete Order',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

}
