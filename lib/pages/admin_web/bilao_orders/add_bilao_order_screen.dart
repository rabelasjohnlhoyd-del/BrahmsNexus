import 'package:flutter/material.dart';
import '../../../models/bilao_order.dart';
import '../../../models/branch.dart';
import '../../../services/firestore_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';

class AddBilaoOrderScreen extends StatefulWidget {
  const AddBilaoOrderScreen({super.key});

  @override
  State<AddBilaoOrderScreen> createState() => _AddBilaoOrderScreenState();
}

class _AddBilaoOrderScreenState extends State<AddBilaoOrderScreen> {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _formKey               = GlobalKey<FormState>();
  final _nameController        = TextEditingController();
  final _contactController     = TextEditingController();
  final _addressController     = TextEditingController();
  final _notesController       = TextEditingController();
  final _quantityController    = TextEditingController(text: '1');
  final _depositController     = TextEditingController();
  final _gcashRefController    = TextEditingController();
  final _gcashAmountController = TextEditingController();

  // ── State ──────────────────────────────────────────────────────────────────
  int                  _currentStep    = 0;
  BilaoFulfillmentType _fulfillmentType = BilaoFulfillmentType.branchPickup;
  BilaoOrderChannel    _orderChannel   = BilaoOrderChannel.branchOrder;
  PaymentMethod        _paymentMethod  = PaymentMethod.cash;
  PaymentType          _paymentType    = PaymentType.fullPayment;
  String               _selectedBranchId =
      kSampleBranches.isNotEmpty ? kSampleBranches.first.id : 'br1';
  BilaoSize            _selectedSize   = BilaoSize.medium;
  DateTime             _scheduledDateTime =
      DateTime.now().add(const Duration(hours: 2));
  bool                 _isSaving       = false;

  // ── Computed ───────────────────────────────────────────────────────────────

  int get _qty => int.tryParse(_quantityController.text.trim()) ?? 1;
  double get _totalPrice => _selectedSize.price * (_qty > 0 ? _qty : 1);
  double get _minDeposit => _totalPrice * 0.65;

  String _peso(double v) => '\u20b1${v.toStringAsFixed(0)}';

  Branch get _selectedBranch => kSampleBranches.firstWhere(
        (b) => b.id == _selectedBranchId,
        orElse: () => kSampleBranches.first,
      );

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _depositController.text = _totalPrice.toStringAsFixed(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateShellActions());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _quantityController.dispose();
    _depositController.dispose();
    _gcashRefController.dispose();
    _gcashAmountController.dispose();
    super.dispose();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setTitle('RECORD NEW BILAO ORDER');
    shell?.setActions([]);
  }

  // ── Payment helpers ────────────────────────────────────────────────────────

  void _onSelectPaymentType(PaymentType type) {
    setState(() {
      _paymentType = type;
      _depositController.text = type == PaymentType.fullPayment
          ? _totalPrice.toStringAsFixed(0)
          : _minDeposit.toStringAsFixed(0);
    });
  }

  void _refreshDeposit() {
    if (_paymentType == PaymentType.fullPayment) {
      _depositController.text = _totalPrice.toStringAsFixed(0);
    } else {
      _depositController.text = _minDeposit.toStringAsFixed(0);
    }
  }

  // ── Stepper navigation ─────────────────────────────────────────────────────

  bool _validateCurrentStep() {
    if (_currentStep == 1) {
      final name = _nameController.text.trim();
      final contact = _contactController.text.trim();

      if (name.isEmpty) {
        _showSnack('Customer name is required.');
        return false;
      }
      if (name.length < 2) {
        _showSnack('Customer name must be at least 2 characters.');
        return false;
      }
      if (name.length > 60) {
        _showSnack('Customer name must not exceed 60 characters.');
        return false;
      }
      if (!RegExp(r"^[a-zA-ZñÑáéíóúÁÉÍÓÚ\s\-'.]+$").hasMatch(name)) {
        _showSnack('Customer name must only contain letters.');
        return false;
      }

      if (contact.isEmpty) {
        _showSnack('Customer contact number is required.');
        return false;
      }
      final digits = contact.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 7 || digits.length > 12) {
        _showSnack('Enter a valid contact number (7 to 12 digits, e.g. 0917 123 4567).');
        return false;
      }

      if (_fulfillmentType == BilaoFulfillmentType.directDelivery) {
        final address = _addressController.text.trim();
        if (address.isEmpty) {
          _showSnack('Please enter the delivery address.');
          return false;
        }
        if (address.length < 5) {
          _showSnack('Delivery address must be at least 5 characters.');
          return false;
        }
      }
    }
    if (_currentStep == 2) {
      if (_qty <= 0) {
        _showSnack('Quantity must be at least 1.');
        return false;
      }
      if (_qty > 100) {
        _showSnack('Quantity cannot exceed 100 bilaos per order.');
        return false;
      }
    }
    if (_currentStep == 3) {
      final entered = double.tryParse(_depositController.text.trim()) ?? 0.0;
      if (entered <= 0) {
        _showSnack('Please enter a valid deposit or payment amount.');
        return false;
      }
      if (_paymentType == PaymentType.downPayment) {
        if (entered < _minDeposit - 0.01) {
          _showSnack(
              'Minimum downpayment is 65% of total (${_peso(_minDeposit)}).');
          return false;
        }
        if (entered > _totalPrice) {
          _showSnack(
              'Downpayment cannot exceed the total order amount (${_peso(_totalPrice)}).');
          return false;
        }
      } else {
        if (entered < _totalPrice - 0.01) {
          _showSnack(
              'Full payment must equal the total amount (${_peso(_totalPrice)}).');
          return false;
        }
      }

      if (_paymentMethod == PaymentMethod.gcash) {
        final ref = _gcashRefController.text.trim();
        if (ref.isEmpty) {
          _showSnack('Please provide the GCash reference number for verification.');
          return false;
        }
        if (ref.length < 6 || ref.length > 30) {
          _showSnack('Enter a valid GCash reference number (e.g. 1002 9384 1928).');
          return false;
        }
      }
    }
    return true;
  }

  void _goNext() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _handleSave();
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AdminWebColors.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final isPickup = _fulfillmentType == BilaoFulfillmentType.branchPickup;

    final newOrder = BilaoOrder(
      id: 'ord${DateTime.now().millisecondsSinceEpoch}',
      customerName:     _nameController.text.trim(),
      contactNumber:    _contactController.text.trim(),
      size:             _selectedSize,
      quantity:         _qty,
      scheduledDateTime: _scheduledDateTime,
      fulfillmentType:  _fulfillmentType,
      orderChannel:     _orderChannel,
      pickupBranchId:   _selectedBranch.id,
      pickupBranchName: _selectedBranch.fullName,
      deliveryAddress:  isPickup ? '' : _addressController.text.trim(),
      notes:            _notesController.text.trim().isNotEmpty
                            ? _notesController.text.trim()
                            : null,
      depositAmount:    double.tryParse(_depositController.text.trim()) ?? 0.0,
      paymentMethod:    _paymentMethod,
      paymentType:      _paymentType,
      gcashRefNumber:   _paymentMethod == PaymentMethod.gcash &&
                            _gcashRefController.text.trim().isNotEmpty
                            ? _gcashRefController.text.trim()
                            : null,
      gcashAmount:      _paymentMethod == PaymentMethod.gcash
                            ? double.tryParse(_gcashAmountController.text.trim())
                            : null,
      gcashVerified:    false,
      createdAt:        DateTime.now(),
    );

    final orderId = await FirestoreService.createBilaoOrder(newOrder);
    if (!mounted) return;
    final saved = orderId != null ? newOrder.copyWith(id: orderId) : newOrder;
    Navigator.of(context).pop(saved);
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AdminWebColors.textSecondary,
          ),
        ),
      );

  Widget _infoCard(String text, {IconData icon = Icons.info_outline_rounded}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AdminWebColors.warning.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AdminWebColors.warning.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: AdminWebColors.warning),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AdminWebColors.textSecondary))),
          ],
        ),
      );

  Widget _choiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AdminWebColors.accent.withValues(alpha: 0.07)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AdminWebColors.accent : AdminWebColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? AdminWebColors.accent
                    : AdminWebColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18,
                  color: selected
                      ? Colors.white
                      : AdminWebColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AdminWebColors.accent
                              : AdminWebColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AdminWebColors.textSecondary)),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 18,
              color: selected
                  ? AdminWebColors.accent
                  : AdminWebColors.border,
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: Order Source ───────────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('ORDER SOURCE'),
        _infoCard(
          'Branch Order = cook earns commission. '
          'Direct to Owner = no cook commission.',
        ),
        const SizedBox(height: 12),
        _choiceCard(
          title: 'Branch Order',
          subtitle: 'Customer ordered through the branch',
          icon: Icons.storefront_rounded,
          selected: _orderChannel == BilaoOrderChannel.branchOrder,
          onTap: () => setState(() => _orderChannel = BilaoOrderChannel.branchOrder),
        ),
        const SizedBox(height: 8),
        _choiceCard(
          title: 'Direct to Owner',
          subtitle: 'Customer contacted the Owner directly',
          icon: Icons.person_rounded,
          selected: _orderChannel == BilaoOrderChannel.directToOwner,
          onTap: () => setState(
              () => _orderChannel = BilaoOrderChannel.directToOwner),
        ),
      ],
    );
  }

  // ── Step 2: Customer Info ──────────────────────────────────────────────────

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('CUSTOMER INFORMATION'),
        _webField(
          controller: _nameController,
          label: 'Customer Name',
          hint: 'e.g. Maria Clara',
          icon: Icons.person_outline_rounded,
          capitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        _webField(
          controller: _contactController,
          label: 'Contact Number',
          hint: 'e.g. 0917 123 4567',
          icon: Icons.phone_outlined,
          keyboard: TextInputType.phone,
        ),
        const SizedBox(height: 20),

        _sectionLabel('FULFILLMENT TYPE'),
        LayoutBuilder(builder: (ctx, c) {
          final wide = c.maxWidth >= 520;
          final pickup = _choiceCard(
            title: 'Branch Pickup',
            subtitle: 'Customer picks up at the branch',
            icon: Icons.store_rounded,
            selected: _fulfillmentType == BilaoFulfillmentType.branchPickup,
            onTap: () => setState(
                () => _fulfillmentType = BilaoFulfillmentType.branchPickup),
          );
          final delivery = _choiceCard(
            title: 'Home Delivery',
            subtitle: 'Driver delivers to customer',
            icon: Icons.delivery_dining_rounded,
            selected:
                _fulfillmentType == BilaoFulfillmentType.directDelivery,
            onTap: () => setState(
                () => _fulfillmentType = BilaoFulfillmentType.directDelivery),
          );
          return wide
              ? Row(children: [
                  Expanded(child: pickup),
                  const SizedBox(width: 10),
                  Expanded(child: delivery),
                ])
              : Column(children: [
                  pickup,
                  const SizedBox(height: 8),
                  delivery,
                ]);
        }),
        const SizedBox(height: 20),

        _sectionLabel('BRANCH & NOTES'),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedBranchId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Branch Outlet',
                isDense: true,
                prefixIcon: const Icon(Icons.storefront_rounded, size: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              items: kSampleBranches
                  .map((b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(b.fullName,
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedBranchId = v);
              },
            ),
            if (_fulfillmentType ==
                BilaoFulfillmentType.directDelivery) ...[
              const SizedBox(height: 12),
              _webField(
                controller: _addressController,
                label: 'Delivery Address',
                hint: 'Street, Barangay, City',
                icon: Icons.location_on_outlined,
              ),
            ],
            const SizedBox(height: 12),
            _webField(
              controller: _notesController,
              label: 'Notes / Instructions (Optional)',
              hint: 'e.g. Table 2, waiting at the counter',
              icon: Icons.edit_note_rounded,
              maxLines: 2,
            ),
          ]),
        ),
      ],
    );
  }

  // ── Step 3: Order Details ──────────────────────────────────────────────────

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('BILAO SIZE & QUANTITY'),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Size selector
              Row(
                children: BilaoSize.values.map((s) {
                  final sel = _selectedSize == s;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedSize = s;
                        _refreshDeposit();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: EdgeInsets.only(
                            right: s != BilaoSize.large ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel
                              ? AdminWebColors.accent
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sel
                                ? AdminWebColors.accent
                                : AdminWebColors.border,
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              s.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: sel
                                    ? Colors.white
                                    : AdminWebColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\u20b1${s.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: sel
                                    ? Colors.white70
                                    : AdminWebColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Quantity + total
              Row(
                children: [
                  const Text('Quantity',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AdminWebColors.textPrimary)),
                  const Spacer(),
                  _webQtyBtn(Icons.remove_rounded, _qty > 1, () {
                    setState(() {
                      _quantityController.text = '${_qty - 1}';
                      _refreshDeposit();
                    });
                  }),
                  Container(
                    width: 48,
                    alignment: Alignment.center,
                    child: Text(
                      '$_qty',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AdminWebColors.textPrimary),
                    ),
                  ),
                  _webQtyBtn(Icons.add_rounded, true, () {
                    setState(() {
                      _quantityController.text = '${_qty + 1}';
                      _refreshDeposit();
                    });
                  }),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AdminWebColors.accent.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _peso(_totalPrice),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AdminWebColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _sectionLabel('SCHEDULED DATE & TIME'),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.event_rounded,
                  color: AdminWebColors.accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_scheduledDateTime.month}/${_scheduledDateTime.day}/${_scheduledDateTime.year}'
                  '  at  '
                  '${_scheduledDateTime.hour.toString().padLeft(2, '0')}:${_scheduledDateTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AdminWebColors.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _scheduledDateTime,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (date == null || !mounted || !context.mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime:
                        TimeOfDay.fromDateTime(_scheduledDateTime),
                  );
                  if (time == null) return;
                  setState(() {
                    _scheduledDateTime = DateTime(
                      date.year, date.month, date.day,
                      time.hour, time.minute,
                    );
                  });
                },
                icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                label: const Text('Change'),
                style: TextButton.styleFrom(
                    foregroundColor: AdminWebColors.accent),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _webQtyBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? AdminWebColors.accent : AdminWebColors.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AdminWebColors.border),
        ),
        child: Icon(icon, size: 16,
            color: enabled ? Colors.white : AdminWebColors.textSecondary),
      ),
    );
  }

  // ── Step 4: Payment ────────────────────────────────────────────────────────

  Widget _buildStep4() {
    final isFull = _paymentType == PaymentType.fullPayment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('PAYMENT METHOD'),
        LayoutBuilder(builder: (ctx, c) {
          final wide = c.maxWidth >= 520;
          final cash = _choiceCard(
            title: 'Cash Payment',
            subtitle: 'Cash on Delivery or at counter',
            icon: Icons.payments_outlined,
            selected: _paymentMethod == PaymentMethod.cash,
            onTap: () => setState(() => _paymentMethod = PaymentMethod.cash),
          );
          final gcash = _choiceCard(
            title: 'GCash Payment',
            subtitle: 'Online transfer with reference #',
            icon: Icons.account_balance_wallet_outlined,
            selected: _paymentMethod == PaymentMethod.gcash,
            onTap: () =>
                setState(() => _paymentMethod = PaymentMethod.gcash),
          );
          return wide
              ? Row(children: [
                  Expanded(child: cash),
                  const SizedBox(width: 10),
                  Expanded(child: gcash),
                ])
              : Column(children: [
                  cash,
                  const SizedBox(height: 8),
                  gcash,
                ]);
        }),
        const SizedBox(height: 18),

        _sectionLabel('PAYMENT TYPE'),
        LayoutBuilder(builder: (ctx, c) {
          final wide = c.maxWidth >= 520;
          final full = _choiceCard(
            title: 'Full Payment',
            subtitle: 'Buong bayad ngayon — ${_peso(_totalPrice)}',
            icon: Icons.check_circle_outline_rounded,
            selected: _paymentType == PaymentType.fullPayment,
            onTap: () => _onSelectPaymentType(PaymentType.fullPayment),
          );
          final down = _choiceCard(
            title: 'Down Payment',
            subtitle: 'Minimum 65% — ${_peso(_minDeposit)} pababa',
            icon: Icons.receipt_long_rounded,
            selected: _paymentType == PaymentType.downPayment,
            onTap: () => _onSelectPaymentType(PaymentType.downPayment),
          );
          return wide
              ? Row(children: [
                  Expanded(child: full),
                  const SizedBox(width: 10),
                  Expanded(child: down),
                ])
              : Column(children: [
                  full,
                  const SizedBox(height: 8),
                  down,
                ]);
        }),
        const SizedBox(height: 18),

        _sectionLabel('PAYMENT AMOUNT'),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order total banner
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AdminWebColors.accent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color:
                          AdminWebColors.accent.withValues(alpha: 0.18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedSize.label} × $_qty',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AdminWebColors.textSecondary),
                    ),
                    Text(
                      'Total: ${_peso(_totalPrice)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AdminWebColors.accent,
                      ),
                    ),
                  ],
                ),
              ),

              if (isFull) ...[
                TextFormField(
                  controller: _depositController,
                  readOnly: true,
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Full Payment Amount — Fixed',
                    isDense: true,
                    prefixIcon:
                        const Icon(Icons.payments_outlined, size: 18),
                    prefixText: '\u20b1 ',
                    filled: true,
                    fillColor: AdminWebColors.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AdminWebColors.border),
                    ),
                  ),
                ),
              ] else ...[
                TextFormField(
                  controller: _depositController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Down Payment Amount (min. 65%)',
                    isDense: true,
                    prefixIcon:
                        const Icon(Icons.payments_outlined, size: 18),
                    prefixText: '\u20b1 ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AdminWebColors.accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Minimum: ${_peso(_minDeposit)} (65% of ${_peso(_totalPrice)})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AdminWebColors.warning,
                  ),
                ),
              ],
            ],
          ),
        ),

        // GCash ref/amount fields
        if (_paymentMethod == PaymentMethod.gcash) ...[
          const SizedBox(height: 18),
          _sectionLabel('GCASH DETAILS'),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LayoutBuilder(builder: (ctx, c) {
                  final wide = c.maxWidth >= 520;
                  final ref = _webField(
                    controller: _gcashRefController,
                    label: 'Reference Number',
                    hint: 'e.g. 1002345678901',
                    icon: Icons.tag_rounded,
                    keyboard: TextInputType.number,
                  );
                  final amt = _webField(
                    controller: _gcashAmountController,
                    label: 'GCash Amount (₱)',
                    hint: 'e.g. 900.00',
                    icon: Icons.account_balance_wallet_outlined,
                    keyboard: const TextInputType.numberWithOptions(
                        decimal: true),
                    prefixText: '\u20b1 ',
                  );
                  return wide
                      ? Row(children: [
                          Expanded(flex: 2, child: ref),
                          const SizedBox(width: 12),
                          Expanded(child: amt),
                        ])
                      : Column(children: [
                          ref,
                          const SizedBox(height: 10),
                          amt,
                        ]);
                }),
                const SizedBox(height: 10),
                _infoCard(
                    'GCash payment awaits Owner verification before kitchen starts.'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _webField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
    int maxLines = 1,
    String? prefixText,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        prefixText: prefixText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AdminWebColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 12),
      ),
    );
  }

  // ── Custom compact step header ─────────────────────────────────────────────

  Widget _buildStepHeader() {
    const steps = [
      ('Order Source', Icons.storefront_outlined),
      ('Customer Info', Icons.person_outline_rounded),
      ('Order Details', Icons.shopping_basket_outlined),
      ('Payment', Icons.payments_outlined),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AdminWebColors.border)),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector
            final filled = (i ~/ 2) < _currentStep;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 20),
                color: filled
                    ? AdminWebColors.accent
                    : AdminWebColors.border,
              ),
            );
          }
          final idx  = i ~/ 2;
          final done = idx < _currentStep;
          final act  = idx == _currentStep;
          final step = steps[idx];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: done
                      ? AdminWebColors.accent
                      : act
                          ? Colors.white
                          : AdminWebColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: done || act
                        ? AdminWebColors.accent
                        : AdminWebColors.border,
                    width: act ? 2 : 1.5,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: Colors.white)
                    : Icon(step.$2,
                        size: 15,
                        color: act
                            ? AdminWebColors.accent
                            : AdminWebColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                step.$1,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      act ? FontWeight.w700 : FontWeight.w500,
                  color: act
                      ? AdminWebColors.accent
                      : done
                          ? AdminWebColors.textPrimary
                          : AdminWebColors.textSecondary,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── Step labels for title bar ──────────────────────────────────────────────

  static const _stepTitles = [
    'Order Source',
    'Customer Info',
    'Order Details',
    'Payment',
  ];
  static const _stepSubtitles = [
    'Is this a branch order or direct to owner?',
    'Customer name, contact & fulfillment',
    'Bilao size, quantity & schedule',
    'Payment method, type & deposit',
  ];

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // ── Custom step header ─────────────────────────────────────────────
          _buildStepHeader(),

          // ── Content ────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Step title
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Step ${_currentStep + 1} of 4 — ${_stepTitles[_currentStep]}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AdminWebColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _stepSubtitles[_currentStep],
                              style: const TextStyle(
                                fontSize: 13,
                                color: AdminWebColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Animated step content
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        transitionBuilder: (child, anim) =>
                            FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.03, 0),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(_currentStep),
                          child: switch (_currentStep) {
                            0 => _buildStep1(),
                            1 => _buildStep2(),
                            2 => _buildStep3(),
                            _ => _buildStep4(),
                          },
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Nav buttons ────────────────────────────────────────
                      Row(
                        children: [
                          // Back / Cancel
                          OutlinedButton.icon(
                            onPressed: _isSaving ? null : _goBack,
                            icon: Icon(
                              _currentStep == 0
                                  ? Icons.close_rounded
                                  : Icons.arrow_back_rounded,
                              size: 16,
                            ),
                            label: Text(_currentStep == 0
                                ? 'Cancel'
                                : 'Back'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AdminWebColors.textSecondary,
                              side: const BorderSide(
                                  color: AdminWebColors.border),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const Spacer(),

                          // Next / Save
                          ElevatedButton.icon(
                            onPressed: _isSaving ? null : _goNext,
                            icon: _isSaving && _currentStep == 3
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white)),
                                  )
                                : Icon(
                                    _currentStep == 3
                                        ? Icons.check_rounded
                                        : Icons.arrow_forward_rounded,
                                    size: 16,
                                  ),
                            label: Text(
                              _currentStep == 3
                                  ? 'Save Order'
                                  : 'Next Step',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminWebColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
