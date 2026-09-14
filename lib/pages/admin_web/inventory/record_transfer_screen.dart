import 'package:flutter/material.dart';
import '../../../models/branch.dart';
import '../../../models/meat_dispatch.dart';
import '../../../services/firestore_service.dart';
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
  
  // Source is always Main Warehouse (Owner's House)
  final String _sourceName = 'Main Warehouse (Owner\'s House)';
  
  String _destId = kSampleBranches.first.id;
  final _regController = TextEditingController();
  final _medController = TextEditingController();
  final _b1t1Controller = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _updateShellActions();
  }

  @override
  void dispose() {
    _regController.dispose();
    _medController.dispose();
    _b1t1Controller.dispose();
    super.dispose();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setTitle('RECORD STOCK DISPATCH');
    shell?.setActions([]);
  }

  Future<void> _handleSave() async {
    final reg = int.tryParse(_regController.text.trim()) ?? 0;
    final med = int.tryParse(_medController.text.trim()) ?? 0;
    final b1t1 = int.tryParse(_b1t1Controller.text.trim()) ?? 0;

    if (reg == 0 && med == 0 && b1t1 == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pakiusap maglagay ng kahit isang bilang ng pcs (250g, 300g, o 400g).')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _updateShellActions();
    });

    final dest = kSampleBranches.firstWhere((b) => b.id == _destId);

    final dispatch = MeatDispatch(
      id: '',
      destinationBranchId: dest.id,
      destinationBranchName: dest.fullName,
      regular250gPcs: reg,
      medium300gPcs: med,
      b1t1_400gPcs: b1t1,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await FirestoreService.createMeatDispatch(dispatch);

    await NotificationService.notifyDriverOfDeliveryTask(
      branchName: dest.fullName,
      quantityKg: (reg * 0.25) + (med * 0.30) + (b1t1 * 0.40),
    );

    if (!mounted) return;
    Navigator.of(context).pop(dispatch);
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
                          'DISPATCH DETAILS (PCS)',
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
                            prefixIcon: Icon(Icons.storefront_rounded, size: 20),
                          ),
                          items: kSampleBranches
                              .map((b) =>
                                  DropdownMenuItem(value: b.id, child: Text(b.fullName)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _destId = v);
                          },
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'BILANG NG PCS NA IPAPADALA:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AdminWebColors.accent),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _regController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '250 grams - Regular',
                            hintText: 'e.g. 20',
                            isDense: true,
                            prefixIcon: Icon(Icons.fastfood_rounded, size: 20),
                            suffixText: 'PCS',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _medController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '300 grams - Medium',
                            hintText: 'e.g. 10',
                            isDense: true,
                            prefixIcon: Icon(Icons.lunch_dining_rounded, size: 20),
                            suffixText: 'PCS',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _b1t1Controller,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '400 grams - B1T1 (Buy 1 Take 1)',
                            hintText: 'e.g. 10',
                            isDense: true,
                            prefixIcon: Icon(Icons.dinner_dining_rounded, size: 20),
                            suffixText: 'PCS',
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
