import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/branch.dart';
import '../../../models/branch_meat_inventory.dart';
import '../../../models/meat_dispatch.dart';
import '../../../services/firestore_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/system_busy_coordinator.dart';
import '../admin_web_colors.dart';

/// Pop-up modal dialog for dispatching meat and supply restocks to branches.
class RecordTransferDialog extends StatefulWidget {
  const RecordTransferDialog({super.key, this.initialBranchId});

  final String? initialBranchId;

  @override
  State<RecordTransferDialog> createState() => _RecordTransferDialogState();
}

class _RecordTransferDialogState extends State<RecordTransferDialog> {
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

  BranchMeatStock? get _selectedBranchStock {
    for (final st in _allStocks) {
      if (st.branchId == _destId) return st;
    }
    return null;
  }

  bool get _isSelectedBranchClosed => _selectedBranchStock?.isClosed ?? false;

  @override
  void initState() {
    super.initState();
    if (_branches.isEmpty) _branches = List.from(kSampleBranches);
    if (widget.initialBranchId != null &&
        _branches.any((b) => b.id == widget.initialBranchId)) {
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
  }

  Future<void> _loadBranches() async {
    final list = await SupabaseService.getBranches();
    if (mounted && list.isNotEmpty) {
      setState(() {
        _branches = list;
        if (!_branches.any((b) => b.id == _destId)) {
          // Try to find first open branch
          final firstOpen = _branches.firstWhere(
            (b) => !(_allStocks.firstWhere(
              (st) => st.branchId == b.id,
              orElse: () => BranchMeatStock.defaultForBranch(b),
            ).isClosed),
            orElse: () => _branches.first,
          );
          _destId = firstOpen.id;
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

  Future<void> _handleSave() async {
    if (_hasSubmittedSales) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot restock: Closing EOD Sales have already been submitted for today.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (_isSelectedBranchClosed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hindi pwedeng mag-restock: Ang branch ay SARADO. I-open muna ito sa Branch Allocation.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final reg = int.tryParse(_regController.text.trim()) ?? 0;
    final med = int.tryParse(_medController.text.trim()) ?? 0;
    final b1t1 = int.tryParse(_b1t1Controller.text.trim()) ?? 0;
    final mayo = int.tryParse(_mayoController.text.trim()) ?? 0;
    final styro = int.tryParse(_styroController.text.trim()) ?? 0;
    final toyo = int.tryParse(_toyoController.text.trim()) ?? 0;

    // Per-field: no negative values
    if (reg < 0 || med < 0 || b1t1 < 0 || mayo < 0 || styro < 0 || toyo < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quantities cannot be negative.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    // Per-field: cap at 999 pcs per item
    if (reg > 999 || med > 999 || b1t1 > 999 || mayo > 999 || styro > 999 || toyo > 999) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quantity per item must not exceed 999 pcs.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (reg == 0 && med == 0 && b1t1 == 0 && mayo == 0 && styro == 0 && toyo == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one item quantity to restock.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    SystemBusyCoordinator.setBusy(true);

    try {
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
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Restock request dispatched to Driver for ${dest.fullName}! Live stock will update once the driver confirms delivery.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      Navigator.of(context).pop(dispatch);
    } finally {
      SystemBusyCoordinator.setBusy(false);
      if (mounted) setState(() => _isSaving = false);
    }
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
        child: AbsorbPointer(
          absorbing: _isSaving,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: AdminWebColors.border)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AdminWebColors.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_shopping_cart_rounded, color: AdminWebColors.accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RESTOCK BRANCH',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AdminWebColors.textPrimary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Magpadala ng karagdagang supply sa napiling branch via driver',
                            style: TextStyle(fontSize: 11.5, color: AdminWebColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AdminWebColors.textSecondary, size: 20),
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),

              // Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TARGET BRANCH
                        DropdownButtonFormField<String>(
                          key: ValueKey(_destId),
                          initialValue: _destId,
                          decoration: const InputDecoration(
                            labelText: 'TARGET BRANCH',
                            isDense: true,
                            prefixIcon: Icon(Icons.storefront_rounded, size: 20),
                          ),
                          isExpanded: true,
                          items: _branches.map((b) {
                            final bStock = _allStocks.firstWhere(
                              (st) => st.branchId == b.id,
                              orElse: () => BranchMeatStock.defaultForBranch(b),
                            );
                            final isClosed = bStock.isClosed;
                            return DropdownMenuItem<String>(
                              value: b.id,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      b.fullName,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isClosed ? const Color(0xFF94A3B8) : null,
                                      ),
                                    ),
                                  ),
                                  if (isClosed) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                                      ),
                                      child: const Text(
                                        'SARADO',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFFDC2626),
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
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
                                    'This branch cannot be restocked because the Closing EOD Sales for today have already been submitted.',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AdminWebColors.error),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Closed branch warning banner
                        if (_isSelectedBranchClosed) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock_rounded, color: Color(0xFFDC2626), size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Hindi pwedeng mag-restock: Ang branch na ito ay SARADO. I-open muna ang branch sa Branch Allocation bago mag-dispatch.',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFDC2626)),
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
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AdminWebColors.accent.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AdminWebColors.accent.withValues(alpha: 0.18)),
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
                        const SizedBox(height: 20),

                        const Text(
                          'ILAGAY ANG MGA IDADAGDAG NA PCS (RESTOCK):',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AdminWebColors.accent),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _regController,
                                keyboardType: TextInputType.number,
                                enabled: !_hasSubmittedSales && !_isSelectedBranchClosed,
                                maxLength: 3,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  labelText: 'Regular (250g)',
                                  hintText: '0',
                                  isDense: true,
                                  counterText: '',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _medController,
                                keyboardType: TextInputType.number,
                                enabled: !_hasSubmittedSales && !_isSelectedBranchClosed,
                                maxLength: 3,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  labelText: 'Medium (300g)',
                                  hintText: '0',
                                  isDense: true,
                                  counterText: '',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _b1t1Controller,
                                keyboardType: TextInputType.number,
                                enabled: !_hasSubmittedSales && !_isSelectedBranchClosed,
                                maxLength: 3,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  labelText: 'B1T1 (400g)',
                                  hintText: '0',
                                  isDense: true,
                                  counterText: '',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _mayoController,
                                keyboardType: TextInputType.number,
                                enabled: !_hasSubmittedSales && !_isSelectedBranchClosed,
                                maxLength: 3,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  labelText: 'Mayo Packs',
                                  hintText: '0',
                                  isDense: true,
                                  counterText: '',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _styroController,
                                keyboardType: TextInputType.number,
                                enabled: !_hasSubmittedSales && !_isSelectedBranchClosed,
                                maxLength: 3,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  labelText: 'Styro Boxes',
                                  hintText: '0',
                                  isDense: true,
                                  counterText: '',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _toyoController,
                                keyboardType: TextInputType.number,
                                enabled: !_hasSubmittedSales && !_isSelectedBranchClosed,
                                maxLength: 3,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  labelText: 'Toyo Packs',
                                  hintText: '0',
                                  isDense: true,
                                  counterText: '',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AdminWebColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AdminWebColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    ElevatedButton.icon(
                      onPressed: (_isSaving || _hasSubmittedSales || _isSelectedBranchClosed) ? null : _handleSave,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.add_shopping_cart_rounded, size: 16),
                      label: const Text('DISPATCH RESTOCK TO DRIVER', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_hasSubmittedSales || _isSelectedBranchClosed) ? Colors.grey : AdminWebColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_isSaving)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.25),
              child: Center(
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AdminWebColors.accent),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Dispatching restock... Please wait...',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminWebColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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
          Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AdminWebColors.textPrimary)),
        ],
      ),
    );
  }
}

/// Compatibility screen wrapper (if ever called as a full route)
class RecordTransferScreen extends StatelessWidget {
  const RecordTransferScreen({super.key, this.initialBranchId});

  final String? initialBranchId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminWebColors.background,
      body: Center(
        child: RecordTransferDialog(initialBranchId: initialBranchId),
      ),
    );
  }
}
