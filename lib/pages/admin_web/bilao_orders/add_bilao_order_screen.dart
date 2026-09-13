import 'package:flutter/material.dart';
import '../../../models/bilao_order.dart';
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
  final _quantityController = TextEditingController(text: '1');
  BilaoSize _selectedSize = BilaoSize.medium;
  DateTime _scheduledDateTime = DateTime.now().add(const Duration(hours: 2));
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _updateShellActions();
    });

    final newOrder = BilaoOrder(
      id: 'ord${DateTime.now().millisecondsSinceEpoch}',
      customerName: _nameController.text.trim(),
      contactNumber: _contactController.text.trim(),
      size: _selectedSize,
      quantity: int.parse(_quantityController.text),
      scheduledDateTime: _scheduledDateTime,
    );

    final orderId = await FirestoreService.createBilaoOrder(newOrder);

    if (!mounted) return;

    final savedOrder = orderId != null ? newOrder.copyWith(id: orderId) : newOrder;
    Navigator.of(context).pop(savedOrder);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminWebColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CUSTOMER INFORMATION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AdminWebColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'CUSTOMER NAME',
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
                            isDense: true,
                            prefixIcon: Icon(Icons.phone_outlined, size: 20),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ORDER DETAILS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AdminWebColors.textSecondary,
                          ),
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
                                            '${s.label.toUpperCase()} (₱${s.price.toStringAsFixed(0)})',
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
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (int.tryParse(v) == null) return 'Invalid';
                                  return null;
                                },
                              ),
                            ),
                          ],
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
                            child: Text(
                              '${_scheduledDateTime.month}/${_scheduledDateTime.day}/'
                              '${_scheduledDateTime.year} · '
                              '${_scheduledDateTime.hour.toString().padLeft(2, '0')}:'
                              '${_scheduledDateTime.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AdminWebColors.textPrimary,
                              ),
                            ),
                          ),
                          trailing: Container(
                            decoration: BoxDecoration(
                              color: AdminWebColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.edit_calendar_rounded, color: AdminWebColors.accent),
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _scheduledDateTime,
                                  firstDate: DateTime.now(),
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

