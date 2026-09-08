import 'package:flutter/material.dart';
import '../../../models/bilao_order.dart';
import '../admin_web_colors.dart';
import '../admin_web_widgets/glass_card.dart';
import '../../../widgets/admin_page_header.dart';
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
  static const double _wideBreakpoint = 700;

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
                      decoration: const InputDecoration(
                        labelText: 'CUSTOMER NAME',
                        isDense: true,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: contactController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'CONTACT NUMBER',
                        isDense: true,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<BilaoSize>(
                      initialValue: selectedSize,
                      decoration: const InputDecoration(
                        labelText: 'BILAO SIZE',
                        isDense: true,
                      ),
                      items: BilaoSize.values
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  '${s.label.toUpperCase()} (₱${s.price.toStringAsFixed(0)})',
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
                      decoration: const InputDecoration(
                        labelText: 'QUANTITY',
                        isDense: true,
                      ),
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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;

        return Container(
          color: AdminWebColors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 24 : 16,
                  isWide ? 24 : 16,
                  isWide ? 24 : 16,
                  0,
                ),
                child: AdminPageHeader(
                  title: 'Bilao Orders',
                  subtitle: 'Track preparation and delivery for special advance orders.',
                  actions: [
                    PrimaryButton(
                      label: 'RECORD NEW ORDER',
                      icon: Icons.add_rounded,
                      onPressed: _showAddOrderDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
                child: isWide
                    ? Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Search by customer name...',
                                prefixIcon: Icon(Icons.search_rounded, size: 20),
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
                                labelText: 'FILTER BY STATUS',
                                isDense: true,
                                prefixIcon: Icon(Icons.filter_list_rounded, size: 18),
                              ),
                              items: _statusFilters
                                  .map((s) =>
                                      DropdownMenuItem(value: s, child: Text(s.toUpperCase())))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _statusFilter = v);
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
                              hintText: 'Search by customer name...',
                              prefixIcon: Icon(Icons.search_rounded, size: 20),
                              isDense: true,
                            ),
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _statusFilter,
                            decoration: const InputDecoration(
                              labelText: 'FILTER BY STATUS',
                              isDense: true,
                              prefixIcon: Icon(Icons.filter_list_rounded, size: 18),
                            ),
                            items: _statusFilters
                                .map((s) =>
                                    DropdownMenuItem(value: s, child: Text(s.toUpperCase())))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _statusFilter = v);
                            },
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _visibleOrders.isEmpty
                    ? const Center(
                        child: Text(
                          'Walang order na tumutugma.',
                          style: TextStyle(color: AdminWebColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          isWide ? 24 : 16,
                          0,
                          isWide ? 24 : 16,
                          24,
                        ),
                        itemCount: _visibleOrders.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = _visibleOrders[index];
                          return _OrderCard(
                            order: order,
                            isWide: isWide,
                            prepColor: _prepColor(order.preparationStatus),
                            deliveryColor:
                                _deliveryColor(order.deliveryStatus),
                            onPreparationChanged: (s) =>
                                _updatePreparation(order.id, s),
                            onDeliveryChanged: (s) =>
                                _updateDelivery(order.id, s),
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

/// A single order row — Row (3-across: info / Preparation / Delivery)
/// on a wide screen; Column (info on top, then the two status
/// dropdowns side by side underneath) on a narrow/phone-browser
/// screen, so the dropdowns always have enough width for their label
/// and value text instead of being squeezed into a sliver and
/// overflowing.
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
  final Color prepColor;
  final Color deliveryColor;
  final ValueChanged<PreparationStatus> onPreparationChanged;
  final ValueChanged<DeliveryStatus> onDeliveryChanged;

  @override
  Widget build(BuildContext context) {
    final customerInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                order.customerName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AdminWebColors.textPrimary,
                ),
              ),
            ),
            Text(
              '#${order.id.toUpperCase()}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AdminWebColors.accent.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            const Icon(Icons.phone_outlined, size: 12, color: AdminWebColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              order.contactNumber,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AdminWebColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AdminWebColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminWebColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shopping_basket_outlined, size: 14, color: AdminWebColors.accent),
              const SizedBox(width: 6),
              Text(
                '${order.size.label} × ${order.quantity}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AdminWebColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              const Text('·', style: TextStyle(color: AdminWebColors.border, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text(
                '₱${order.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AdminWebColors.accent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.event_available_rounded, size: 13, color: AdminWebColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              '${order.scheduledDateTime.month}/${order.scheduledDateTime.day}/'
              '${order.scheduledDateTime.year} at '
              '${order.scheduledDateTime.hour.toString().padLeft(2, '0')}:'
              '${order.scheduledDateTime.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AdminWebColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );

    final preparationDropdown = DropdownButtonFormField<PreparationStatus>(
      initialValue: order.preparationStatus,
      decoration: InputDecoration(
        labelText: 'PREPARATION',
        isDense: true,
        labelStyle: TextStyle(
          color: prepColor,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
        prefixIcon: Icon(Icons.restaurant_rounded, size: 16, color: prepColor),
      ),
      items: PreparationStatus.values
          .map((s) => DropdownMenuItem(
                value: s,
                child: Text(
                  s.label.toUpperCase(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ))
          .toList(),
      onChanged: (s) {
        if (s != null) onPreparationChanged(s);
      },
    );

    final deliveryDropdown = DropdownButtonFormField<DeliveryStatus>(
      initialValue: order.deliveryStatus,
      decoration: InputDecoration(
        labelText: 'DELIVERY',
        isDense: true,
        labelStyle: TextStyle(
          color: deliveryColor,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
        prefixIcon: Icon(Icons.moped_rounded, size: 16, color: deliveryColor),
      ),
      items: DeliveryStatus.values
          .map((s) => DropdownMenuItem(
                value: s,
                child: Text(
                  s.label.toUpperCase(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ))
          .toList(),
      onChanged: (s) {
        if (s != null) onDeliveryChanged(s);
      },
    );

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 2, child: customerInfo),
                const SizedBox(width: 20),
                Expanded(child: preparationDropdown),
                const SizedBox(width: 12),
                Expanded(child: deliveryDropdown),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                customerInfo,
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: preparationDropdown),
                    const SizedBox(width: 12),
                    Expanded(child: deliveryDropdown),
                  ],
                ),
              ],
            ),
    );
  }
}
