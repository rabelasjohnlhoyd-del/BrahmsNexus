import 'package:flutter/material.dart';
import '../../../models/branch.dart';
import '../../../models/inventory_item.dart';
import '../../../services/notification_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';

class RecordTransferScreen extends StatefulWidget {
  const RecordTransferScreen({super.key});

  @override
  State<RecordTransferScreen> createState() => _RecordTransferScreenState();
}

class _RecordTransferScreenState extends State<RecordTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Logic updated: Source is always Main Warehouse (Owner's House)
  final String _sourceName = 'Main Warehouse (Owner\'s House)';
  
  String _destId = kSampleBranches.first.id;
  final _qtyController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _updateShellActions();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setTitle('RECORD STOCK DISPATCH');
    shell?.setActions([]);
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _updateShellActions();
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final dest = kSampleBranches.firstWhere((b) => b.id == _destId);
    final qty = double.parse(_qtyController.text);

    final log = StockTransferLog(
      id: 'tl_${DateTime.now().millisecondsSinceEpoch}',
      sourceBranchId: 'warehouse',
      sourceBranchName: _sourceName,
      destinationBranchId: dest.id,
      destinationBranchName: dest.fullName,
      quantityKg: qty,
      dateTime: DateTime.now(),
    );

    await NotificationService.notifyDriverOfDeliveryTask(
      branchName: dest.fullName,
      quantityKg: qty,
    );

    if (!mounted) return;
    Navigator.of(context).pop(log);
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
                          'DISPATCH DETAILS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AdminWebColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // FIXED SOURCE
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AdminWebColors.accent.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AdminWebColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('FROM SOURCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminWebColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text(_sourceName, style: const TextStyle(fontWeight: FontWeight.w800, color: AdminWebColors.textPrimary)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          initialValue: _destId,
                          decoration: const InputDecoration(
                            labelText: 'DESTINATION BRANCH',
                            isDense: true,
                            prefixIcon: Icon(Icons.login_rounded, size: 20),
                          ),
                          items: kSampleBranches
                              .map((b) =>
                                  DropdownMenuItem(value: b.id, child: Text(b.fullName)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _destId = v);
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'QUANTITY (KG)',
                            isDense: true,
                            prefixIcon: Icon(Icons.scale_rounded, size: 20),
                            suffixText: 'KG',
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
                        label: const Text('CONFIRM DISPATCH'),
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
