import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../../models/bilao_order.dart';
import '../../models/branch.dart';
import '../../services/assignment_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_top_actions.dart';

/// Screen for Branch Staff to monitor Bilao Orders assigned to or waiting
/// at their specific branch location.
///
/// Cards show minimal info (name, contact, package, current status).
/// Tap a card to view full details.
/// The + button on the branch header row opens the add-order form.
/// Orders are auto-completed when the driver submits delivery photo.
class StaffBilaoOrdersScreen extends StatefulWidget {
  const StaffBilaoOrdersScreen({
    super.key,
    this.branchId,
    this.branchName,
    this.isRootTab = true,
  });

  final String? branchId;
  final String? branchName;
  final bool isRootTab;

  @override
  State<StaffBilaoOrdersScreen> createState() => _StaffBilaoOrdersScreenState();
}

class _StaffBilaoOrdersScreenState extends State<StaffBilaoOrdersScreen> {
  StreamSubscription<List<BilaoOrder>>? _ordersSub;
  final List<BilaoOrder> _orders = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _tabIndex = 0; // 0: All, 1: Completed

  String _currentBranchId = 'br1';
  String _currentBranchName = 'Brgy. Gatid, Sta. Cruz';

  @override
  void initState() {
    super.initState();
    _setupBranchAndStream();
    AssignmentService.changeNotifier.addListener(_onAssignmentChanged);
  }

  void _onAssignmentChanged() {
    if (mounted) _setupBranchAndStream();
  }

  void _setupBranchAndStream() {
    if (widget.branchId != null && widget.branchName != null) {
      _currentBranchId = widget.branchId!;
      _currentBranchName = widget.branchName!;
    } else {
      final username = AuthService.currentUsername;
      final currentUid = AuthService.currentUserId;
      var assignedBranchName = AssignmentService.getAssignedBranch(username);
      if (assignedBranchName.isEmpty && currentUid.isNotEmpty) {
        assignedBranchName = AssignmentService.getAssignedBranch(currentUid);
      }

      if (assignedBranchName.isNotEmpty) {
        _currentBranchName = assignedBranchName;
        final matchedBranch = kSampleBranches.firstWhere(
          (b) => b.name == assignedBranchName || b.fullName == assignedBranchName,
          orElse: () => kSampleBranches.first,
        );
        _currentBranchId = matchedBranch.id;
      }
    }

    _ordersSub?.cancel();
    _ordersSub = FirestoreService.watchBranchBilaoOrders(
      branchId: _currentBranchId,
      branchName: _currentBranchName,
    ).listen((orders) {
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
    AssignmentService.changeNotifier.removeListener(_onAssignmentChanged);
    _ordersSub?.cancel();
    super.dispose();
  }

  List<BilaoOrder> get _filteredOrders {
    var list = _orders.where((o) {
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          o.customerName.toLowerCase().contains(q) ||
          o.contactNumber.toLowerCase().contains(q) ||
          (o.notes != null && o.notes!.toLowerCase().contains(q));

      bool matchesTab = true;
      if (_tabIndex == 1) {
        matchesTab = o.deliveryStatus == DeliveryStatus.completed;
      }

      return matchesSearch && matchesTab;
    }).toList();

    list.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));
    return list;
  }

  // ── Status helpers ──────────────────────────────────────────────────────────

  /// Returns the human-readable status label shown on the card.
  /// Progression: Pending → Preparing → Out For Delivery → Completed
  String _cardStatusLabel(BilaoOrder o) {
    if (o.deliveryStatus == DeliveryStatus.completed ||
        o.deliveryStatus == DeliveryStatus.delivered) {
      return 'Completed';
    }
    if (o.deliveryStatus == DeliveryStatus.outForDelivery) {
      return 'Out For Delivery';
    }
    switch (o.preparationStatus) {
      case PreparationStatus.pending:
        return 'Pending';
      case PreparationStatus.preparing:
        return 'Preparing';
      case PreparationStatus.ready:
        return 'Ready';
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
    switch (o.preparationStatus) {
      case PreparationStatus.pending:
        return AppColors.warning;
      case PreparationStatus.preparing:
        return AppColors.accent;
      case PreparationStatus.ready:
        return AppColors.success;
    }
  }

  // ── Add Order Sheet ─────────────────────────────────────────────────────────

  void _showAddOrderSheet() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _AddBilaoOrderSheet(
        branchId: _currentBranchId,
        branchName: _currentBranchName,
      ),
    );
  }

  // ── Details Dialog ──────────────────────────────────────────────────────────

  void _showOrderDetails(BilaoOrder order) {
    final statusLabel = _cardStatusLabel(order);
    final statusColor = _cardStatusColor(order);

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
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Text(
              'Total: \u20b1${order.totalAmount.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent),
            ),
            const SizedBox(height: 8),
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              Text('Notes: ${order.notes}',
                  style: const TextStyle(
                      fontSize: 12, fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
            ],
            Text(
              'Schedule: ${order.scheduledDateTime.month}/${order.scheduledDateTime.day} at '
              '${order.scheduledDateTime.hour.toString().padLeft(2, '0')}:'
              '${order.scheduledDateTime.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            if (order.isBranchPickup) ...[
              const SizedBox(height: 4),
              Text(
                'Branch: ${order.pickupBranchName ?? _currentBranchName}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ] else if (order.deliveryAddress.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Delivery Address: ${order.deliveryAddress}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
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
                  Icon(CupertinoIcons.circle_fill,
                      size: 9, color: statusColor),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
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
    final completedCount =
        _orders.where((o) => o.deliveryStatus == DeliveryStatus.completed).length;
    final allCount = _orders.length;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: StaffNavBar(
        title: 'Bilao Orders',
        showBackButton: !widget.isRootTab,
        trailing: const StaffTopActions(),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── BRANCH INFO HEADER ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: CupertinoColors.white,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.placemark_fill,
                        size: 20, color: AppColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentBranchName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$allCount bilao order${allCount == 1 ? '' : 's'} · $completedCount completed',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // + Add Order button
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _showAddOrderSheet,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.add,
                          size: 18, color: CupertinoColors.white),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.border),

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
                        0: Text('All ($allCount)',
                            style: const TextStyle(fontSize: 12)),
                        1: Text('Completed ($completedCount)',
                            style: const TextStyle(fontSize: 12)),
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
                                Icon(
                                  CupertinoIcons.tray_fill,
                                  size: 48,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Walang bilao orders para sa branch na ito.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'I-tap ang + para magdagdag ng bagong order.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
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
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            return _OrderCard(
                              order: order,
                              statusLabel: _cardStatusLabel(order),
                              statusColor: _cardStatusColor(order),
                              onTap: () => _showOrderDetails(order),
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

// ── Minimal Order Card ───────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
  });

  final BilaoOrder order;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCompleted = order.deliveryStatus == DeliveryStatus.completed;

    return GestureDetector(
      onTap: onTap,
      child: StaffCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderColor: isCompleted
            ? AppColors.success.withValues(alpha: 0.2)
            : AppColors.accent.withValues(alpha: 0.25),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.success.withValues(alpha: 0.12)
                    : AppColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                order.customerName.isNotEmpty
                    ? order.customerName[0].toUpperCase()
                    : 'B',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isCompleted ? AppColors.success : AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + contact + package
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerName,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    order.contactNumber,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.size.label} Bilao × ${order.quantity}  ·  \u20b1${order.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Status pill (right side)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.35)),
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
                const SizedBox(height: 4),
                const Icon(CupertinoIcons.chevron_right,
                    size: 13, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Bilao Order Sheet (Cupertino) ────────────────────────────────────────

class _AddBilaoOrderSheet extends StatefulWidget {
  const _AddBilaoOrderSheet({
    required this.branchId,
    required this.branchName,
  });

  final String branchId;
  final String branchName;

  @override
  State<_AddBilaoOrderSheet> createState() => _AddBilaoOrderSheetState();
}

class _AddBilaoOrderSheetState extends State<_AddBilaoOrderSheet> {
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  BilaoSize _size = BilaoSize.medium;
  int _quantity = 1;
  bool _isDirectDelivery = false;
  bool _isSaving = false;
  DateTime _scheduledDateTime = DateTime.now().add(const Duration(hours: 2));

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _notesCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  double get _total => _size.price * _quantity;

  Future<void> _pickDateTime() async {
    DateTime picked = _scheduledDateTime;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => Container(
        height: 280,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: const Text('Done'),
                  onPressed: () {
                    setState(() => _scheduledDateTime = picked);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                initialDateTime: _scheduledDateTime,
                minimumDate: DateTime.now(),
                mode: CupertinoDatePickerMode.dateAndTime,
                use24hFormat: true,
                onDateTimeChanged: (dt) => picked = dt,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final contact = _contactCtrl.text.trim();
    if (name.isEmpty || contact.isEmpty) {
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Kulang ang info'),
          content: const Text('Punan ang pangalan at contact number ng customer.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    if (_isDirectDelivery && _addressCtrl.text.trim().isEmpty) {
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Kulang ang info'),
          content: const Text('Punan ang delivery address ng customer.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final orderId =
          'bilao_${DateTime.now().millisecondsSinceEpoch}';
      final order = BilaoOrder(
        id: orderId,
        customerName: name,
        contactNumber: contact,
        size: _size,
        quantity: _quantity,
        scheduledDateTime: _scheduledDateTime,
        fulfillmentType: _isDirectDelivery
            ? BilaoFulfillmentType.directDelivery
            : BilaoFulfillmentType.branchPickup,
        pickupBranchId: _isDirectDelivery ? null : widget.branchId,
        pickupBranchName: _isDirectDelivery ? null : widget.branchName,
        deliveryAddress:
            _isDirectDelivery ? _addressCtrl.text.trim() : '',
        notes:
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        preparationStatus: PreparationStatus.pending,
        deliveryStatus: DeliveryStatus.forDelivery,
      );

      await FirestoreService.createBilaoOrder(order);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Hindi nai-save ang order: $e'),
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
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CupertinoColors.systemGroupedBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title row
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Bagong Bilao Order',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.branchName,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // Customer Name
              _label('Pangalan ng Customer'),
              const SizedBox(height: 6),
              CupertinoTextField(
                controller: _nameCtrl,
                placeholder: 'Hal. Juan Dela Cruz',
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),

              // Contact Number
              _label('Contact Number'),
              const SizedBox(height: 6),
              CupertinoTextField(
                controller: _contactCtrl,
                placeholder: '09XX XXX XXXX',
                keyboardType: TextInputType.phone,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),

              // Size
              _label('Bilao Size'),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<BilaoSize>(
                  groupValue: _size,
                  children: {
                    BilaoSize.small: Text('Small\n\u20b1${BilaoSize.small.price.toStringAsFixed(0)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11)),
                    BilaoSize.medium: Text('Medium\n\u20b1${BilaoSize.medium.price.toStringAsFixed(0)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11)),
                    BilaoSize.large: Text('Large\n\u20b1${BilaoSize.large.price.toStringAsFixed(0)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11)),
                  },
                  onValueChanged: (v) {
                    if (v != null) setState(() => _size = v);
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Quantity
              _label('Quantity'),
              const SizedBox(height: 6),
              Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(CupertinoIcons.minus, size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$_quantity',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => _quantity++),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(CupertinoIcons.add,
                          size: 16, color: CupertinoColors.white),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Total: \u20b1${_total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Schedule
              _label('Schedule'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickDateTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.calendar,
                          size: 16, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Text(
                        '${_scheduledDateTime.month}/${_scheduledDateTime.day}/${_scheduledDateTime.year}  '
                        '${_scheduledDateTime.hour.toString().padLeft(2, '0')}:${_scheduledDateTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      const Icon(CupertinoIcons.chevron_right,
                          size: 13, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Fulfillment Type Toggle
              _label('Uri ng Order'),
              const SizedBox(height: 6),
              Row(
                children: [
                  _typeChip('Branch Pickup', !_isDirectDelivery, () {
                    setState(() => _isDirectDelivery = false);
                  }),
                  const SizedBox(width: 8),
                  _typeChip('Direct Delivery', _isDirectDelivery, () {
                    setState(() => _isDirectDelivery = true);
                  }),
                ],
              ),
              if (_isDirectDelivery) ...[
                const SizedBox(height: 12),
                _label('Delivery Address'),
                const SizedBox(height: 6),
                CupertinoTextField(
                  controller: _addressCtrl,
                  placeholder: 'Hal. Blk 5 Lot 2, Brgy. Labuin, Pila',
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  maxLines: 2,
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Notes
              _label('Notes (optional)'),
              const SizedBox(height: 6),
              CupertinoTextField(
                controller: _notesCtrl,
                placeholder: 'Hal. Table 2, katabi ng kapilya...',
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                maxLines: 2,
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const CupertinoActivityIndicator(
                          color: CupertinoColors.white)
                      : const Text('I-save ang Order'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );

  Widget _typeChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent
              : CupertinoColors.white,
          borderRadius: BorderRadius.circular(8),
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
}
