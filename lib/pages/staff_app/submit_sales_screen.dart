import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';

/// Staff submits their end-of-day sales here. Maps to [SalesRecord]
/// (portionsSold, commissionRatePerPortion, totalSalesAmount) — the
/// computed wage & expected cash remittance are derived automatically
/// once this reaches the backend, per the Sales and Auto-Payroll
/// flowchart.
///
/// NOTE: Front-end only — Submit currently just shows a confirmation.
/// Wiring to Supabase/Firebase happens in the backend phase.
class SubmitSalesScreen extends StatefulWidget {
  const SubmitSalesScreen({super.key});

  @override
  State<SubmitSalesScreen> createState() => _SubmitSalesScreenState();
}

class _SubmitSalesScreenState extends State<SubmitSalesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _portionsController = TextEditingController();
  final _totalSalesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _portionsController.dispose();
    _totalSalesController.dispose();
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
      const SnackBar(content: Text('Sales submitted!')),
    );
    _portionsController.clear();
    _totalSalesController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Sales')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Today\'s Sales',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Isumite ang bilang ng naibentang portions at kabuuang'
                  ' benta ngayong araw.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _portionsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Portions Sold',
                    prefixIcon: Icon(Icons.restaurant_rounded),
                  ),
                  validator: (v) => _requiredNumber(v, 'Portions sold'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _totalSalesController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Total Sales Amount (₱)',
                    prefixIcon: Icon(Icons.payments_rounded),
                  ),
                  validator: (v) => _requiredNumber(v, 'Total sales amount'),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'SUBMIT SALES',
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
