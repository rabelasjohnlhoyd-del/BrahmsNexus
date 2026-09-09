import 'package:flutter/material.dart';
import '../../../models/branch.dart';
import '../../../models/inventory_item.dart';
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
  String _sourceId = kSampleBranches.first.id;
  String _destId = kSampleBranches[1].id;
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
    shell?.setTitle('RECORD INTER-BRANCH TRANSFER');
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
        label: const Text('SAVE TRANSFER'),
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
    if (_sourceId == _destId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Source and destination branches must be different')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _updateShellActions();
    });

    // Simulate save delay
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final source = kSampleBranches.firstWhere((b) => b.id == _sourceId);
    final dest = kSampleBranches.firstWhere((b) => b.id == _destId);
    final qty = double.parse(_qtyController.text);

    final log = StockTransferLog(
      id: 'tl_${DateTime.now().millisecondsSinceEpoch}',
      sourceBranchId: source.id,
      sourceBranchName: source.fullName,
      destinationBranchId: dest.id,
      destinationBranchName: dest.fullName,
      quantityKg: qty,
      dateTime: DateTime.now(),
    );

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
                          'TRANSFER DETAILS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AdminWebColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        DropdownButtonFormField<String>(
                          value: _sourceId,
                          decoration: const InputDecoration(
                            labelText: 'FROM BRANCH',
                            isDense: true,
                            prefixIcon: Icon(Icons.logout_rounded, size: 20),
                          ),
                          items: kSampleBranches
                              .map((b) =>
                                  DropdownMenuItem(value: b.id, child: Text(b.fullName)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _sourceId = v);
                          },
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          value: _destId,
                          decoration: const InputDecoration(
                            labelText: 'TO BRANCH',
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
