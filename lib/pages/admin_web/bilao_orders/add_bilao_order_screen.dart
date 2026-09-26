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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  BilaoFulfillmentType _fulfillmentType = BilaoFulfillmentType.branchPickup;
  String _selectedBranchId = kSampleBranches.isNotEmpty ? kSampleBranches.first.id : 'br1';
  BilaoSize _selectedSize = BilaoSize.medium;
  DateTime _scheduledDateTime = DateTime.now().add(const Duration(hours: 2));
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setTitle('RECORD NEW BILAO ORDER');
    shell?.setActions([]);
  }

  Branch get _selectedBranch {
    return kSampleBranches.firstWhere(
      (b) => b.id == _selectedBranchId,
      orElse: () => kSampleBranches.first,
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _updateShellActions();
    });

    final isPickup = _fulfillmentType == BilaoFulfillmentType.branchPickup;
    final deliveryAddr = isPickup
        ? _selectedBranch.fullName
        : _addressController.text.trim();

    final newOrder = BilaoOrder(
      id: 'ord${DateTime.now().millisecondsSinceEpoch}',
      customerName: _nameController.text.trim(),
      contactNumber: _contactController.text.trim(),
      size: _selectedSize,
      quantity: int.parse(_quantityController.text),
      scheduledDateTime: _scheduledDateTime,
      fulfillmentType: _fulfillmentType,
      pickupBranchId: isPickup ? _selectedBranch.id : null,
      pickupBranchName: isPickup ? _selectedBranch.fullName : null,
      deliveryAddress: deliveryAddr,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      createdAt: DateTime.now(),
    );

    final orderId = await FirestoreService.createBilaoOrder(newOrder);

    if (!mounted) return;

    final savedOrder = orderId != null ? newOrder.copyWith(id: orderId) : newOrder;
    Navigator.of(context).pop(savedOrder);
  }

  Widget _buildFulfillmentOption({
    required BilaoFulfillmentType type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _fulfillmentType == type;
    return InkWell(
      onTap: () => setState(() => _fulfillmentType = type),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AdminWebColors.accent.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AdminWebColors.accent : AdminWebColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? AdminWebColors.accent
                    : AdminWebColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : AdminWebColors.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AdminWebColors.accent
                          : AdminWebColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AdminWebColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? AdminWebColors.accent
                  : AdminWebColors.textSecondary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qty = int.tryParse(_quantityController.text) ?? 1;
    final totalPrice = _selectedSize.price * (qty > 0 ? qty : 1);

    return Container(
      color: AdminWebColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.person_outline_rounded,
                                size: 18, color: AdminWebColors.accent),
                            SizedBox(width: 8),
                            Text(
                              'CUSTOMER INFORMATION',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: AdminWebColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'CUSTOMER NAME',
                            hintText: 'e.g. Maria Clara',
                            isDense: true,
                            prefixIcon: Icon(Icons.person_outline, size: 20),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contactController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'CONTACT NUMBER',
                            hintText: 'e.g. 0917 123 4567',
                            isDense: true,
                            prefixIcon: Icon(Icons.phone_outlined, size: 20),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 24),

                        // ── FULFILLMENT / LOCATION SELECTION ───────────────
                        const Text(
                          'WHERE WILL THE CUSTOMER RECEIVE THE ORDER?',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AdminWebColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildFulfillmentOption(
                                type: BilaoFulfillmentType.branchPickup,
                                title: 'Branch Pickup / Waiting at Branch',
                                subtitle: 'Customer is at or picking up from a branch',
                                icon: Icons.storefront_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFulfillmentOption(
                                type: BilaoFulfillmentType.directDelivery,
                                title: 'Direct Delivery Address',
                                subtitle: 'Driver delivers directly to an address',
                                icon: Icons.delivery_dining_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Form for Branch Pickup
                        if (_fulfillmentType == BilaoFulfillmentType.branchPickup) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AdminWebColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AdminWebColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PILIIN ANG BRANCH KUNG SAAN NAKA-PWERSTO O NAG-AANTAY',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AdminWebColors.accent,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedBranchId,
                                  decoration: const InputDecoration(
                                    labelText: 'BRANCH OUTLET',
                                    isDense: true,
                                    prefixIcon: Icon(Icons.storefront_rounded, size: 20),
                                  ),
                                  items: kSampleBranches
                                      .map((b) => DropdownMenuItem(
                                            value: b.id,
                                            child: Text(b.fullName),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _selectedBranchId = v);
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _notesController,
                                  decoration: const InputDecoration(
                                    labelText: 'WAITING SPOT / NOTES (OPTIONAL)',
                                    hintText: 'e.g. Naka-pwesto sa table / nag-aantay sa store counter',
                                    isDense: true,
                                    prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Form for Direct Delivery Address
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AdminWebColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AdminWebColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ILAGAY ANG COMPLETE DELIVERY ADDRESS',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AdminWebColors.accent,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _addressController,
                                  decoration: const InputDecoration(
                                    labelText: 'DELIVERY ADDRESS',
                                    hintText: 'House/Unit #, Street, Brgy, Municipality, Laguna',
                                    isDense: true,
                                    prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                                  ),
                                  validator: (v) {
                                    if (_fulfillmentType == BilaoFulfillmentType.directDelivery) {
                                      if (v == null || v.trim().isEmpty) return 'Delivery address is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _notesController,
                                  decoration: const InputDecoration(
                                    labelText: 'DELIVERY NOTES / LANDMARK (OPTIONAL)',
                                    hintText: 'e.g. Tapat ng barangay hall, tawagan pagdating',
                                    isDense: true,
                                    prefixIcon: Icon(Icons.signpost_outlined, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 18, color: AdminWebColors.accent),
                            SizedBox(width: 8),
                            Text(
                              'ORDER DETAILS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: AdminWebColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<BilaoSize>(
                                initialValue: _selectedSize,
                                decoration: const InputDecoration(
                                  labelText: 'BILAO SIZE',
                                  isDense: true,
                                  prefixIcon: Icon(Icons.shopping_basket_outlined, size: 20),
                                ),
                                items: BilaoSize.values
                                    .map((s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(
                                            '${s.label.toUpperCase()} (${s.pax} Pax · ₱${s.price.toStringAsFixed(0)})',
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedSize = value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _quantityController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'QUANTITY',
                                  isDense: true,
                                  prefixIcon: Icon(Icons.tag, size: 20),
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  final n = int.tryParse(v);
                                  if (n == null || n <= 0) return 'Must be >= 1';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Price summary banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AdminWebColors.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AdminWebColors.accent.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_selectedSize.label} Bilao (${_selectedSize.weightLabel})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AdminWebColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₱${_selectedSize.price.toStringAsFixed(0)} × $qty',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AdminWebColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '₱${totalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AdminWebColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'SCHEDULED DATE & TIME',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: AdminWebColors.textSecondary,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded,
                                    size: 16, color: AdminWebColors.accent),
                                const SizedBox(width: 6),
                                Text(
                                  '${_scheduledDateTime.month}/${_scheduledDateTime.day}/'
                                  '${_scheduledDateTime.year} at '
                                  '${_scheduledDateTime.hour.toString().padLeft(2, '0')}:'
                                  '${_scheduledDateTime.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AdminWebColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: Container(
                            decoration: BoxDecoration(
                              color: AdminWebColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.edit_calendar_rounded,
                                  color: AdminWebColors.accent),
                              tooltip: 'Change date and time',
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _scheduledDateTime,
                                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                  lastDate:
                                      DateTime.now().add(const Duration(days: 60)),
                                );
                                if (date == null) return;
                                if (!mounted || !context.mounted) return;
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime:
                                      TimeOfDay.fromDateTime(_scheduledDateTime),
                                );
                                if (time == null) return;
                                setState(() {
                                  _scheduledDateTime = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            _isSaving ? null : () => Navigator.of(context).pop(),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AdminWebColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _handleSave,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 18),
                        label: const Text('SAVE ORDER'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminWebColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

