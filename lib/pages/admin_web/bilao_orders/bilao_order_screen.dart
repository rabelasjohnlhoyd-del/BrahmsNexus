import 'package:flutter/material.dart';
import '../../../models/bilao_order.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/primary_button.dart';

/// Admin records confirmed advance/special bilao orders here (received
/// via Messenger/phone — customers never order directly in-app), then
/// tracks their Preparation and Delivery status through to completion.
///
/// NOTE: Mock data for now — once Supabase is wired up, this reads/
/// writes the real `bilao_orders` table.
class BilaoOrderScreen extends StatefulWidget {
  const BilaoOrderScreen({super.key});

  @override
  State<BilaoOrderScreen> createState() => _BilaoOrderScreenState();
}

class _BilaoOrderScreenState extends State<BilaoOrderScreen> {
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
    var list = _orders.where((o) {
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

  Future<void> _showAddOrderDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    BilaoSize selectedSize = BilaoSize.medium;
    DateTime scheduledDateTime = DateTime.now().add(const Duration(hours: 2));

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Record New Bilao Order'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration:
                          const InputDecoration(labelText: 'Customer Name'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: contactController,
                      keyboardType: TextInputType.phone,
                      decoration:
                          const InputDecoration(labelText: 'Contact Number'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<BilaoSize>(
                      value: selectedSize,
                      decoration: const InputDecoration(
                        labelText: 'Bilao Size',
                      ),
                      items: BilaoSize.values
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  '${s.label} (₱${s.price.toStringAsFixed(0)})',
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedSize = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (int.tryParse(v) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Scheduled Date & Time'),
                      subtitle: Text(
                        '${scheduledDateTime.month}/${scheduledDateTime.day}/'
                        '${scheduledDateTime.year} · '
                        '${scheduledDateTime.hour.toString().padLeft(2, '0')}:'
                        '${scheduledDateTime.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.edit_calendar_rounded),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: dialogContext,
                          initialDate: scheduledDateTime,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 60)),
                        );
                        if (date == null) return;
                        if (!dialogContext.mounted) return;
                        final time = await showTimePicker(
                          context: dialogContext,
                          initialTime:
                              TimeOfDay.fromDateTime(scheduledDateTime),
                        );
                        if (time == null) return;
                        setDialogState(() {
                          scheduledDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                setState(() {
                  _orders.add(
                    BilaoOrder(
                      id: 'ord${_orders.length + 1}',
                      customerName: nameController.text.trim(),
                      contactNumber: contactController.text.trim(),
                      size: selectedSize,
                      quantity: int.parse(quantityController.text),
                      scheduledDateTime: scheduledDateTime,
                    ),
                  );
                });
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save Order'),
            ),
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        return Padding(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isWide
                  ? Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Bilao Orders',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        PrimaryButton(
                          label: 'RECORD NEW ORDER',
                          icon: Icons.add_rounded,
                          onPressed: _showAddOrderDialog,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bilao Orders',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        PrimaryButton(
                          label: 'RECORD NEW ORDER',
                          icon: Icons.add_rounded,
                          onPressed: _showAddOrderDialog,
                        ),
                      ],
                    ),
              const SizedBox(height: 16),
              isWide
                  ? Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Search by customer name...',
                              prefixIcon: Icon(Icons.search_rounded),
                              isDense: true,
                            ),
                            onChanged: (v) =>
                                setState(() => _searchQuery = v),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _statusFilter,
                            decoration: const InputDecoration(
                              labelText: 'Filter by status',
                              isDense: true,
                            ),
                            items: _statusFilters
                                .map((s) => DropdownMenuItem(
                                    value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _statusFilter = v);
                              }
                            },
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search by customer name...',
                            prefixIcon: Icon(Icons.search_rounded),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _statusFilter,
                          decoration: const InputDecoration(
                            labelText: 'Filter by status',
                            isDense: true,
                          ),
                          items: _statusFilters
                              .map((s) =>
                                  DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _statusFilter = v);
                          },
                        ),
                      ],
                    ),
              const SizedBox(height: 16),
              Expanded(
                child: _visibleOrders.isEmpty
                    ? const Center(
                        child: Text(
                          'Walang order na tumutugma.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _visibleOrders.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _OrderCard(
                            order: _visibleOrders[index],
                            isWide: isWide,
                            prepColor: _prepColor,
                            deliveryColor: _deliveryColor,
                            onPreparationChanged: (s) =>
                                _updatePreparation(_visibleOrders[index].id, s),
                            onDeliveryChanged: (s) =>
                                _updateDelivery(_visibleOrders[index].id, s),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.isWide,
    required this.prepColor,
    required this.deliveryColor,
    required this.onPreparationChanged,
    required this.onDeliveryChanged,
  });

  final BilaoOrder order;
  final bool isWide;
  final Color Function(PreparationStatus) prepColor;
  final Color Function(DeliveryStatus) deliveryColor;
  final ValueChanged<PreparationStatus> onPreparationChanged;
  final ValueChanged<DeliveryStatus> onDeliveryChanged;

  @override
  Widget build(BuildContext context) {
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          order.customerName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          order.contactNumber,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          '${order.size.label} × ${order.quantity} '
          '· ₱${order.totalAmount.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
        ),
        Text(
          '${order.scheduledDateTime.month}/'
          '${order.scheduledDateTime.day}/'
          '${order.scheduledDateTime.year} · '
          '${order.scheduledDateTime.hour.toString().padLeft(2, '0')}:'
          '${order.scheduledDateTime.minute.toString().padLeft(2, '0')}',
          style:
              const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
      ],
    );

    final preparationDropdown = DropdownButtonFormField<PreparationStatus>(
      value: order.preparationStatus,
      decoration: InputDecoration(
        labelText: 'Preparation',
        isDense: true,
        labelStyle: TextStyle(color: prepColor(order.preparationStatus)),
      ),
      items: PreparationStatus.values
          .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
          .toList(),
      onChanged: (s) {
        if (s != null) onPreparationChanged(s);
      },
    );

    final deliveryDropdown = DropdownButtonFormField<DeliveryStatus>(
      value: order.deliveryStatus,
      decoration: InputDecoration(
        labelText: 'Delivery',
        isDense: true,
        labelStyle: TextStyle(color: deliveryColor(order.deliveryStatus)),
      ),
      items: DeliveryStatus.values
          .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
          .toList(),
      onChanged: (s) {
        if (s != null) onDeliveryChanged(s);
      },
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isWide
            ? Row(
                children: [
                  Expanded(flex: 2, child: info),
                  Expanded(child: preparationDropdown),
                  const SizedBox(width: 12),
                  Expanded(child: deliveryDropdown),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  info,
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: preparationDropdown),
                      const SizedBox(width: 10),
                      Expanded(child: deliveryDropdown),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
