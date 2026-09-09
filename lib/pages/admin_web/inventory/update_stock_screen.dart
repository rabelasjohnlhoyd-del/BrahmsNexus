import 'package:flutter/material.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';

class UpdateStockScreen extends StatefulWidget {
  final double currentStock;

  const UpdateStockScreen({super.key, required this.currentStock});

  @override
  State<UpdateStockScreen> createState() => _UpdateStockScreenState();
}

class _UpdateStockScreenState extends State<UpdateStockScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _stockController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _stockController = TextEditingController(text: widget.currentStock.toStringAsFixed(0));
    _updateShellActions();
  }

  @override
  void dispose() {
    _stockController.dispose();
    super.dispose();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setTitle('UPDATE WAREHOUSE STOCK');
    shell?.setActions([
      TextButton(
        onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        child: const Text('CANCEL', style: TextStyle(color: Colors.white)),
      ),
      ElevatedButton.icon(
        onPressed: _isSaving ? null : _handleSave,
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.check_rounded, size: 18, color: Colors.white),
        label: const Text('UPDATE STOCK'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.15),
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          elevation: 0,
        ),
      ),
    ]);
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _updateShellActions();
    });

    // Simulate save delay
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final value = double.tryParse(_stockController.text);
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminWebColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
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
                          'MAIN WAREHOUSE TOTAL STOCK',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AdminWebColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'TOTAL STOCK (KG)',
                            isDense: true,
                            prefixIcon: Icon(Icons.inventory_2_rounded, size: 20),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Must be a number';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
