import 'package:flutter/cupertino.dart';
import '../../models/bilao_order.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';

/// Bilao Orders — Owner records confirmed advance/special orders
/// (received via Messenger/phone; customers never order directly
/// in-app) and tracks Preparation and Delivery status through to
/// completion.
///
/// Migrated from the old `admin_web/bilao_orders` screen — same
/// model and filtering logic, rebuilt with Cupertino widgets
/// (action sheets instead of dropdowns, a date/time wheel picker
/// instead of Material date+time dialogs) to match the rest of the
/// Owner app.
///
/// NOTE: Mock data for now — once Supabase is wired up, this reads/
/// writes the real `bilao_orders` table.
class OwnerBilaoOrdersScreen extends StatefulWidget {
  const OwnerBilaoOrdersScreen({super.key});

  @override
  State<OwnerBilaoOrdersScreen> createState() =>
      _OwnerBilaoOrdersScreenState();
}

class _OwnerBilaoOrdersScreenState extends State<OwnerBilaoOrdersScreen> {
  final List<BilaoOrder> _orders = [
    BilaoOrder(
      id: 'ord1',
      customerName: 'Ana Lopez',
      contactNumber: '0917 555 1234',
      size: BilaoSize.large,
      quantity: 2,
      scheduledDateTime: DateTime.now().add(const Duration(hours: 5)),
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
      preparationStatus: PreparationStatus.ready,
      deliveryStatus: DeliveryStatus.completed,
    ),
  ];

  String _searchQuery = '';
  String _statusFilter = 'All';

  static const _statusFilters = [
    'All',
    'Pending',
    'Preparing',
    'Ready',
    'For Delivery',
    'Delivered',
    'Completed',
  ];

  List<BilaoOrder> get _visibleOrders {
    final list = _orders.where((o) {
      final matchesSearch = _searchQuery.isEmpty ||
          o.customerName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesFilter = _statusFilter == 'All' ||
          o.preparationStatus.label == _statusFilter ||
          o.deliveryStatus.label == _statusFilter;
      return matchesSearch && matchesFilter;
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
        return AppColors.warning;
      case DeliveryStatus.delivered:
        return AppColors.accent;
      case DeliveryStatus.completed:
        return AppColors.success;
    }
  }

  void _updatePreparation(String id, PreparationStatus status) {
    setState(() {
      final index = _orders.indexWhere((o) => o.id == id);
      _orders[index] = _orders[index].copyWith(preparationStatus: status);
    });
  }

  void _updateDelivery(String id, DeliveryStatus status) {
    setState(() {
      final index = _orders.indexWhere((o) => o.id == id);
      _orders[index] = _orders[index].copyWith(deliveryStatus: status);
    });
  }

  Future<void> _pickPreparation(BilaoOrder order) async {
    final result = await showCupertinoModalPopup<PreparationStatus>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Preparation Status'),
        actions: PreparationStatus.values
            .map(
              (s) => CupertinoActionSheetAction(
                onPressed: () => Navigator.of(sheetContext).pop(s),
                child: Text(s.label),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (result != null) _updatePreparation(order.id, result);
  }

  Future<void> _pickDelivery(BilaoOrder order) async {
    final result = await showCupertinoModalPopup<DeliveryStatus>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Delivery Status'),
        actions: DeliveryStatus.values
            .map(
              (s) => CupertinoActionSheetAction(
                onPressed: () => Navigator.of(sheetContext).pop(s),
                child: Text(s.label),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (result != null) _updateDelivery(order.id, result);
  }

  Future<void> _showAddOrderDialog() async {
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    var selectedSize = BilaoSize.medium;
    var scheduledDateTime = DateTime.now().add(const Duration(hours: 2));

    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => CupertinoAlertDialog(
          title: const Text('Record New Bilao Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: nameController,
                placeholder: 'Customer Name',
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: contactController,
                placeholder: 'Contact Number',
                keyboardType: TextInputType.phone,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  final picked = await showCupertinoModalPopup<BilaoSize>(
                    context: dialogContext,
                    builder: (sheetContext) => CupertinoActionSheet(
                      title: const Text('Bilao Size'),
                      actions: BilaoSize.values
                          .map(
                            (s) => CupertinoActionSheetAction(
                              onPressed: () =>
                                  Navigator.of(sheetContext).pop(s),
                              child: Text(
                                '${s.label} (\u20b1${s.price.toStringAsFixed(0)})',
                              ),
                            ),
                          )
                          .toList(),
                      cancelButton: CupertinoActionSheetAction(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedSize = picked);
                  }
                },
                child: Text(
                  'Size: ${selectedSize.label} '
                  '(\u20b1${selectedSize.price.toStringAsFixed(0)})',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 4),
              CupertinoTextField(
                controller: quantityController,
                placeholder: 'Quantity',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  var tempDateTime = scheduledDateTime;
                  await showCupertinoModalPopup<void>(
                    context: dialogContext,
                    builder: (popupContext) => Container(
                      height: 260,
                      color: CupertinoColors.white,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CupertinoButton(
                                onPressed: () =>
                                    Navigator.of(popupContext).pop(),
                                child: const Text('Cancel'),
                              ),
                              CupertinoButton(
                                onPressed: () {
                                  setDialogState(
                                      () => scheduledDateTime = tempDateTime);
                                  Navigator.of(popupContext).pop();
                                },
                                child: const Text('Done'),
                              ),
                            ],
                          ),
                          Expanded(
                            child: CupertinoDatePicker(
                              mode: CupertinoDatePickerMode.dateAndTime,
                              initialDateTime: scheduledDateTime,
                              minimumDate: DateTime.now()
                                  .subtract(const Duration(days: 60)),
                              maximumDate:
                                  DateTime.now().add(const Duration(days: 60)),
                              onDateTimeChanged: (value) =>
                                  tempDateTime = value,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Text(
                  'Scheduled: ${scheduledDateTime.month}/'
                  '${scheduledDateTime.day}/${scheduledDateTime.year} \u00b7 '
                  '${scheduledDateTime.hour.toString().padLeft(2, '0')}:'
                  '${scheduledDateTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                final name = nameController.text.trim();
                final contact = contactController.text.trim();
                final quantity = int.tryParse(quantityController.text);
                if (name.isEmpty || contact.isEmpty || quantity == null) {
                  return;
                }
                setState(() {
                  _orders.add(
                    BilaoOrder(
                      id: 'ord${_orders.length + 1}',
                      customerName: name,
                      contactNumber: contact,
                      size: selectedSize,
                      quantity: quantity,
                      scheduledDateTime: scheduledDateTime,
                    ),
                  );
                });
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Bilao Orders',
        showBackButton: true,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: StaffButton(
                label: 'Record New Order',
                icon: CupertinoIcons.add,
                onPressed: _showAddOrderDialog,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: CupertinoSearchTextField(
                placeholder: 'Search by customer name',
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            SizedBox(
              height: 34,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final status in _statusFilters) ...[
                    _filterChip(
                      label: status,
                      selected: _statusFilter == status,
                      onTap: () => setState(() => _statusFilter = status),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _visibleOrders.isEmpty
                  ? const Center(
                      child: Text(
                        'Walang order na tumutugma.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _visibleOrders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _buildOrderCard(_visibleOrders[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : CupertinoColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? CupertinoColors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _statusPill(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(width: 2),
            Icon(CupertinoIcons.chevron_down, size: 11, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(BilaoOrder order) {
    return StaffCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.customerName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            order.contactNumber,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            '${order.size.label} \u00d7 ${order.quantity} '
            '\u00b7 \u20b1${order.totalAmount.toStringAsFixed(0)}',
            style:
                const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
          ),
          Text(
            '${order.scheduledDateTime.month}/'
            '${order.scheduledDateTime.day}/'
            '${order.scheduledDateTime.year} \u00b7 '
            '${order.scheduledDateTime.hour.toString().padLeft(2, '0')}:'
            '${order.scheduledDateTime.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(
                fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statusPill(
                order.preparationStatus.label,
                _prepColor(order.preparationStatus),
                () => _pickPreparation(order),
              ),
              const SizedBox(width: 8),
              _statusPill(
                order.deliveryStatus.label,
                _deliveryColor(order.deliveryStatus),
                () => _pickDelivery(order),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
