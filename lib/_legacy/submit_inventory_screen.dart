import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';

/// Staff submits remaining stock at end-of-day here — maps to
/// [BranchStock.remainingKg]. This is what the Owner's Inventory
/// Monitor / Admin Web Inventory screen will read once wired up.
class SubmitInventoryScreen extends StatefulWidget {
  const SubmitInventoryScreen({super.key});

  @override
  State<SubmitInventoryScreen> createState() => _SubmitInventoryScreenState();
}

class _SubmitInventoryScreenState extends State<SubmitInventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _remainingMeatController = TextEditingController();
  final _remainingMayoController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _remainingMeatController.dispose();
    _remainingMayoController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _requiredNumber(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    if (num.tryParse(value) == null) return 'Enter a valid number';
    return null;
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Inventory submitted!')),
    );
    _remainingMeatController.clear();
    _remainingMayoController.clear();
    _notesController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Inventory')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'End-of-Day Remaining Stock',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Isumite ang natitirang stock para ma-monitor ni Owner.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _remainingMeatController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Remaining Meat (kg)',
                    prefixIcon: Icon(Icons.set_meal_rounded),
                  ),
                  validator: (v) => _requiredNumber(v, 'Remaining meat'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _remainingMayoController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Remaining Mayo (kg)',
                    prefixIcon: Icon(Icons.icecream_rounded),
                  ),
                  validator: (v) => _requiredNumber(v, 'Remaining mayo'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes_rounded),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'SUBMIT INVENTORY',
                  isLoading: _isSubmitting,
                  onPressed: _handleSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
