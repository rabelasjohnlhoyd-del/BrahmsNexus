import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../../models/bilao_order.dart';
import '../../models/branch.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/app_pagination_bar.dart';

/// Bilao Orders — Owner records confirmed advance/special orders
/// (received via Messenger/phone; customers never order directly
/// in-app) and tracks Preparation and Delivery status through to
/// completion.
///
/// Backed by live real-time Firestore sync.
class OwnerBilaoOrdersScreen extends StatefulWidget {
  const OwnerBilaoOrdersScreen({super.key});

  @override
  State<OwnerBilaoOrdersScreen> createState() =>
      _OwnerBilaoOrdersScreenState();
}

class _OwnerBilaoOrdersScreenState extends State<OwnerBilaoOrdersScreen> {
  StreamSubscription<List<BilaoOrder>>? _ordersSub;

  int _currentPage = 0;
  static const int _pageSize = 5;

  final List<BilaoOrder> _orders = [];

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
          o.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          o.contactNumber.contains(_searchQuery) ||
          o.destinationDisplay.toLowerCase().contains(_searchQuery.toLowerCase());
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



  void _updateDelivery(String id, DeliveryStatus status) {
    FirestoreService.updateBilaoStatus(orderId: id, deliveryStatus: status);
    setState(() {
      final index = _orders.indexWhere((o) => o.id == id);
      if (index >= 0) {
        _orders[index] = _orders[index].copyWith(deliveryStatus: status);
      }
    });
  }

  Future<void> _advancePreparation(BilaoOrder order) async {
    if (order.preparationStatus == PreparationStatus.ready) return;

    final isPending = order.preparationStatus == PreparationStatus.pending;
    final promptTitle = isPending ? 'Simulan ang Pag-prepare?' : 'Gawing Ready ang Order?';
    final promptMsg = isPending
        ? 'Ililipat ang order para kay ${order.customerName} sa Preparing step (bawal nang umatras).'
        : 'Luto na ba? Aabisuhan si Driver na pumunta sa bahay ni Owner para kunin ito (bawal nang umatras).';

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(promptTitle),
        content: Text(promptMsg),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isPending ? 'Simulan (Step 2)' : 'Ready & Notif Driver (Step 3)'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final next = await FirestoreService.advanceBilaoPreparation(order);
    if (next != null && mounted) {
      setState(() {
        final index = _orders.indexWhere((o) => o.id == order.id);
        if (index >= 0) {
          _orders[index] = _orders[index].copyWith(preparationStatus: next);
        }
      });
    }
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
    final addressController = TextEditingController();
    final notesController = TextEditingController();
    var selectedSize = BilaoSize.medium;
    var scheduledDateTime = DateTime.now().add(const Duration(hours: 2));
    var fulfillmentType = BilaoFulfillmentType.directDelivery;
    Branch? selectedBranch;

    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isBranchPickup = fulfillmentType == BilaoFulfillmentType.branchPickup;

          return CupertinoAlertDialog(
            title: const Text('Record New Bilao Order'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: nameController,
                  placeholder: 'Customer Name',
                  textCapitalization: TextCapitalization.words,
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
                const SizedBox(height: 10),

                // Fulfillment type toggle
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() =>
                              fulfillmentType = BilaoFulfillmentType.directDelivery),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: !isBranchPickup
                                  ? AppColors.accent
                                  : CupertinoColors.transparent,
                              borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(7)),
                            ),
                            child: Text(
                              'Delivery',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: !isBranchPickup
                                    ? CupertinoColors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() =>
                              fulfillmentType = BilaoFulfillmentType.branchPickup),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isBranchPickup
                                  ? AppColors.accent
                                  : CupertinoColors.transparent,
                              borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(7)),
                            ),
                            child: Text(
                              'Branch Pickup',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isBranchPickup
                                    ? CupertinoColors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Delivery address OR branch picker
                if (!isBranchPickup)
                  CupertinoTextField(
                    controller: addressController,
                    placeholder: 'Delivery Address',
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  )
                else
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      final picked = await showCupertinoModalPopup<Branch>(
                        context: dialogContext,
                        builder: (sheetContext) => CupertinoActionSheet(
                          title: const Text('Piliin ang Branch'),
                          actions: kSampleBranches
                              .map(
                                (b) => CupertinoActionSheetAction(
                                  onPressed: () =>
                                      Navigator.of(sheetContext).pop(b),
                                  child: Text(b.fullName),
                                ),
                              )
                              .toList(),
                          cancelButton: CupertinoActionSheetAction(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedBranch = picked);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        selectedBranch?.fullName ?? 'Pumili ng Branch...',
                        style: TextStyle(
                          fontSize: 13,
                          color: selectedBranch != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),

                // Notes field
                CupertinoTextField(
                  controller: notesController,
                  placeholder: 'Notes / Waiting Spot (optional)',
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),

                // Size picker
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
                                  '${s.label} — ${s.weightLabel} '
                                  '(\u20b1${s.price.toStringAsFixed(0)})',
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

                // Scheduled date/time picker
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
                  if (name.isEmpty || contact.isEmpty || quantity == null) return;

                  final isBranch = fulfillmentType == BilaoFulfillmentType.branchPickup;
                  if (isBranch && selectedBranch == null) return;

                  final newOrder = BilaoOrder(
                    id: 'ord${DateTime.now().millisecondsSinceEpoch}',
                    customerName: name,
                    contactNumber: contact,
                    size: selectedSize,
                    quantity: quantity,
                    scheduledDateTime: scheduledDateTime,
                    fulfillmentType: fulfillmentType,
                    deliveryAddress:
                        isBranch ? '' : addressController.text.trim(),
                    pickupBranchId: isBranch ? selectedBranch!.id : null,
                    pickupBranchName:
                        isBranch ? selectedBranch!.fullName : null,
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                    createdAt: DateTime.now(),
                  );
                  FirestoreService.createBilaoOrder(newOrder);
                  setState(() {
                    _orders.insert(0, newOrder);
                  });
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
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
                placeholder: 'Search by customer, contact, or branch',
                onChanged: (v) => setState(() {
                  _searchQuery = v;
                  _currentPage = 0;
                }),
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
                      onTap: () => setState(() {
                        _statusFilter = status;
                        _currentPage = 0;
                      }),
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
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            itemCount: (_visibleOrders.length -
                                    (_currentPage * _pageSize))
                                .clamp(0, _pageSize),
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) => _buildOrderCard(
                                _visibleOrders[
                                    (_currentPage * _pageSize) + index]),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: AppPaginationBar(
                            currentPage: _currentPage,
                            totalItems: _visibleOrders.length,
                            pageSize: _pageSize,
                            onPageChanged: (p) =>
                                setState(() => _currentPage = p),
                          ),
                        ),
                      ],
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

  Widget _prepStepPill(BilaoOrder order) {
    final status = order.preparationStatus;
    final color = _prepColor(status);
    final isPending = status == PreparationStatus.pending;
    final isPreparing = status == PreparationStatus.preparing;
    final isReady = status == PreparationStatus.ready;

    return GestureDetector(
      onTap: isReady ? null : () => _advancePreparation(order),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isReady
                  ? CupertinoIcons.checkmark_alt_circle_fill
                  : (isPreparing ? CupertinoIcons.flame_fill : CupertinoIcons.clock_fill),
              size: 12,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              isPending
                  ? 'Prep: Pending (I-start)'
                  : (isPreparing ? 'Prep: Preparing (Gawing Ready)' : 'Prep: Ready (Bahay ni Owner)'),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
            if (!isReady) ...[
              const SizedBox(width: 4),
              Icon(CupertinoIcons.arrow_right, size: 11, color: color),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(BilaoOrder order) {
    final isBranchPickup = order.isBranchPickup;
    final fulfillmentColor =
        isBranchPickup ? const Color(0xFF6366F1) : AppColors.accent;
    final fulfillmentIcon = isBranchPickup
        ? CupertinoIcons.location_solid
        : CupertinoIcons.car_fill;

    return StaffCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.contactNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Fulfillment type badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: fulfillmentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: fulfillmentColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(fulfillmentIcon,
                        size: 11, color: fulfillmentColor),
                    const SizedBox(width: 4),
                    Text(
                      order.fulfillmentType.label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: fulfillmentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${order.size.label} \u00d7 ${order.quantity} '
            '\u00b7 \u20b1${order.totalAmount.toStringAsFixed(0)}',
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          // Destination
          Row(
            children: [
              Icon(
                isBranchPickup
                    ? CupertinoIcons.location
                    : CupertinoIcons.map,
                size: 11,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  order.destinationDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Note: ${order.notes}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 2),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _prepStepPill(order),
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
