import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/branch.dart';
import '../../../models/branch_meat_inventory.dart';
import '../../../models/meat_dispatch.dart';
import '../../../services/firestore_service.dart';
import '../../../services/supabase_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';

class RecordTransferScreen extends StatefulWidget {
  const RecordTransferScreen({super.key, this.initialBranchId});

  final String? initialBranchId;

  @override
  State<RecordTransferScreen> createState() => _RecordTransferScreenState();
}

class _RecordTransferScreenState extends State<RecordTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  
  List<Branch> _branches = SupabaseService.getAllBranchesSync();
  late String _destId;
  final _regController = TextEditingController();
  final _medController = TextEditingController();
  final _b1t1Controller = TextEditingController();
  final _mayoController = TextEditingController();
  final _styroController = TextEditingController();
  final _toyoController = TextEditingController();
  bool _isSaving = false;
  bool _hasSubmittedSales = false;

  StreamSubscription<List<BranchMeatStock>>? _stocksSub;
  List<BranchMeatStock> _allStocks = [];

  @override
  void initState() {
    super.initState();
    if (_branches.isEmpty) _branches = List.from(kSampleBranches);
    if (widget.initialBranchId != null && _branches.any((b) => b.id == widget.initialBranchId)) {
      _destId = widget.initialBranchId!;
    } else {
      _destId = _branches.first.id;
    }
    _loadBranches();
    _checkSalesSubmitted(_destId);
    
    _stocksSub = FirestoreService.watchBranchMeatStocks().listen((stocks) {
      if (mounted) {
        setState(() => _allStocks = stocks);
      }
    });

    _updateShellActions();
  }

  Future<void> _loadBranches() async {
    final list = await SupabaseService.getBranches();
    if (mounted && list.isNotEmpty) {
      setState(() {
        _branches = list;
        if (!_branches.any((b) => b.id == _destId)) {
          _destId = _branches.first.id;
        }
      });
      _checkSalesSubmitted(_destId);
    }
  }

  Future<void> _checkSalesSubmitted(String branchId) async {
    final submitted = await FirestoreService.hasBranchSubmittedSalesToday(branchId);
    if (mounted) {
      setState(() => _hasSubmittedSales = submitted);
    }
  }

  @override
  void dispose() {
    _stocksSub?.cancel();
    _regController.dispose();
    _medController.dispose();
    _b1t1Controller.dispose();
    _mayoController.dispose();
    _styroController.dispose();
    _toyoController.dispose();
    super.dispose();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setTitle('RESTOCK BRANCH');
    shell?.setActions([]);
  }

  Future<void> _handleSave() async {
    if (_hasSubmittedSales) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hindi na maaaring i-restock dahil naisumite na ang Closing EOD Sales.')),
      );
      return;
    }

    final reg = int.tryParse(_regController.text.trim()) ?? 0;
    final med = int.tryParse(_medController.text.trim()) ?? 0;
    final b1t1 = int.tryParse(_b1t1Controller.text.trim()) ?? 0;
    final mayo = int.tryParse(_mayoController.text.trim()) ?? 0;
    final styro = int.tryParse(_styroController.text.trim()) ?? 0;
    final toyo = int.tryParse(_toyoController.text.trim()) ?? 0;

    if (reg == 0 && med == 0 && b1t1 == 0 && mayo == 0 && styro == 0 && toyo == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pakiusap maglagay ng kahit isang bilang ng item na ire-restock.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _updateShellActions();
    });

    final dest = kSampleBranches.firstWhere((b) => b.id == _destId, orElse: () => kSampleBranches.first);

    final dispatch = MeatDispatch(
      id: 'disp_${DateTime.now().millisecondsSinceEpoch}',
      destinationBranchId: dest.id,
      destinationBranchName: dest.fullName,
      regular250gPcs: reg,
      medium300gPcs: med,
      b1t1_400gPcs: b1t1,
      mayoPcs: mayo,
      styroPcs: styro,
      toyoPcs: toyo,
      status: 'pending',
      createdAt: DateTime.now(),
      deliveredAt: null,
    );

    await FirestoreService.createMeatDispatch(dispatch);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Restock request dispatched to Driver for ${dest.fullName}! Live stock will update once the driver confirms delivery.')),
    );
    Navigator.of(context).pop(dispatch);
  }

  @override
  Widget build(BuildContext context) {
    BranchMeatStock? s;
    for (final st in _allStocks) {
      if (st.branchId == _destId) {
        s = st;
        break;
      }
    }
    s ??= BranchMeatStock.defaultForBranch(
      _branches.firstWhere((b) => b.id == _destId, orElse: () => kSampleBranches.first),
    );

    return Container(
      color: AdminWebColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RESTOCK BRANCH',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AdminWebColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          initialValue: _destId,
                          decoration: const InputDecoration(
                            labelText: 'TARGET BRANCH',
                            isDense: true,
                            prefixIcon: Icon(Icons.storefront_rounded, size: 20),
                          ),
                          items: _branches
                              .map((b) =>
                                  DropdownMenuItem(value: b.id, child: Text(b.fullName)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _destId = v);
                              _checkSalesSubmitted(v);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        if (_hasSubmittedSales) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AdminWebColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AdminWebColors.error.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: AdminWebColors.error, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Hindi na maaaring i-restock ang branch na ito dahil naisumite na ang Closing EOD Sales para sa araw na ito.',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AdminWebColors.error),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // CURRENT STOCK DISPLAY AT TOP (Always visible for selected branch)
                        const Text(
                          'CURRENT STOCK SA BRANCH:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminWebColors.accent),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AdminWebColors.accent.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AdminWebColors.accent.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _stockInfoChip('250g Regular', '${s.regular250gRemaining} / ${s.regular250gTotal} pcs')),
                                  const SizedBox(width: 8),
                                  Expanded(child: _stockInfoChip('300g Medium', '${s.medium300gRemaining} / ${s.medium300gTotal} pcs')),
                                  const SizedBox(width: 8),
                                  Expanded(child: _stockInfoChip('400g B1T1', '${s.b1t1_400gRemaining} / ${s.b1t1_400gTotal} pcs')),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _stockInfoChip('Mayo', '${s.mayoRemaining} / ${s.mayoTotal} pcs')),
                                  const SizedBox(width: 8),
                                  Expanded(child: _stockInfoChip('Styro Box', '${s.styroRemaining} / ${s.styroTotal} pcs')),
                                  const SizedBox(width: 8),
                                  Expanded(child: _stockInfoChip('Toyo', '${s.toyoRemaining} / ${s.toyoTotal} pcs')),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          'ILAGAY ANG MGA IDADAGDAG NA PCS (RESTOCK):',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AdminWebColors.accent),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _regController,
                                keyboardType: TextInputType.number,
                                enabled: !_hasSubmittedSales,
                                decoration: const InputDecoration(
                                  labelText: 'Regular (250g)',
                                  hintText: '0',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _medController,
                                keyboardType: TextInputType.number,
                                enabled: !_hasSubmittedSales,
                                decoration: const InputDecoration(
                                  labelText: 'Medium (300g)',
                                  hintText: '0',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _b1t1Controller,
                                keyboardType: TextInputType.number,
                                enabled: !_hasSubmittedSales,
                                decoration: const InputDecoration(
                                  labelText: 'B1T1 (400g)',
                                  hintText: '0',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _mayoController,
                                keyboardType: TextInputType.number,
                                enabled: !_hasSubmittedSales,
                                decoration: const InputDecoration(
                                  labelText: 'Mayo Packs',
                                  hintText: '0',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _styroController,
                                keyboardType: TextInputType.number,
                                enabled: !_hasSubmittedSales,
                                decoration: const InputDecoration(
                                  labelText: 'Styro Boxes',
                                  hintText: '0',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _toyoController,
                                keyboardType: TextInputType.number,
                                enabled: !_hasSubmittedSales,
                                decoration: const InputDecoration(
                                  labelText: 'Toyo Packs',
                                  hintText: '0',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
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
                        onPressed: (_isSaving || _hasSubmittedSales) ? null : _handleSave,
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
                            : const Icon(Icons.add_shopping_cart_rounded, size: 18),
                        label: const Text('DISPATCH RESTOCK TO DRIVER'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _hasSubmittedSales ? Colors.grey : AdminWebColors.accent,
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

  Widget _stockInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AdminWebColors.border),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AdminWebColors.textSecondary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AdminWebColors.textPrimary)),
        ],
      ),
    );
  }
}
