import 'package:flutter/material.dart';
import '../../../data/philippine_address_data.dart';
import '../../../models/branch.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';

class BranchFormScreen extends StatefulWidget {
  final Branch? branch;

  const BranchFormScreen({super.key, this.branch});

  @override
  State<BranchFormScreen> createState() => _BranchFormScreenState();
}

class _BranchFormScreenState extends State<BranchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sequenceController;

  String? _selectedProvince;
  String? _selectedCity;
  String? _selectedBarangay;

  bool _isSaving = false;

  bool get _isEdit => widget.branch != null;

  @override
  void initState() {
    super.initState();
    _sequenceController = TextEditingController(
        text: widget.branch?.dailyRouteSequence.toString() ?? '1');

    // Pre-fill province, city, and barangay when editing an existing branch.
    // Branch.name stores "Brgy. Gatid" and Branch.municipality stores "Sta. Cruz".
    if (widget.branch != null) {
      final existingCity = widget.branch!.municipality.trim();
      // Strip "Brgy. " prefix from branch name to recover the raw barangay name.
      final rawBrgy = widget.branch!.name.trim().replaceFirst(RegExp(r'^Brgy\.\s*'), '');

      if (existingCity.isNotEmpty) {
        for (final province in PhilippineAddressData.provinces) {
          final cities = PhilippineAddressData.getCities(province);
          if (cities.contains(existingCity)) {
            _selectedProvince = province;
            _selectedCity = existingCity;

            // Check if the barangay exists in the data
            final barangays = PhilippineAddressData.getBarangays(existingCity);
            if (barangays.contains(rawBrgy)) {
              _selectedBarangay = rawBrgy;
            }
            break;
          }
        }
      }
    }

    _updateShellActions();
  }

  @override
  void dispose() {
    _sequenceController.dispose();
    super.dispose();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setTitle(_isEdit ? 'EDIT BRANCH' : 'ADD NEW BRANCH');
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

    final branch = Branch(
      id: _isEdit ? widget.branch!.id : 'br_${DateTime.now().millisecondsSinceEpoch}',
      // Store barangay name with "Brgy." prefix as the branch name
      name: 'Brgy. $_selectedBarangay',
      municipality: _selectedCity ?? '',
      dailyRouteSequence: int.tryParse(_sequenceController.text) ?? 1,
    );

    Navigator.of(context).pop(branch);
  }

  @override
  Widget build(BuildContext context) {
    final cities = _selectedProvince != null
        ? PhilippineAddressData.getCities(_selectedProvince!)
        : <String>[];

    final barangays = _selectedCity != null
        ? PhilippineAddressData.getBarangays(_selectedCity!)
        : <String>[];

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
                          'BRANCH DETAILS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AdminWebColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Preview of combined branch name
                        if (_selectedBarangay != null && _selectedCity != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16, top: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AdminWebColors.accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AdminWebColors.accent.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.storefront_rounded,
                                    size: 16, color: AdminWebColors.accent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Brgy. $_selectedBarangay, $_selectedCity'
                                    '${_selectedProvince != null ? ", $_selectedProvince" : ""}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AdminWebColors.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const SizedBox(height: 16),

                        // ── Province ──────────────────────────────────
                        DropdownButtonFormField<String>(
                          initialValue: _selectedProvince,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'PROVINCE',
                            isDense: true,
                            prefixIcon: Icon(Icons.map_outlined, size: 20),
                          ),
                          hint: const Text('Select province'),
                          items: PhilippineAddressData.provinces
                              .map((p) =>
                                  DropdownMenuItem(value: p, child: Text(p)))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedProvince = value;
                              _selectedCity = null;
                              _selectedBarangay = null;
                            });
                          },
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Select a province' : null,
                        ),
                        const SizedBox(height: 20),

                        // ── City / Municipality ───────────────────────
                        DropdownButtonFormField<String>(
                          key: ValueKey('city_${_selectedProvince ?? "none"}'),
                          initialValue: _selectedCity,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'MUNICIPALITY / CITY',
                            isDense: true,
                            prefixIcon:
                                Icon(Icons.location_city_rounded, size: 20),
                          ),
                          hint: const Text('Select city or municipality'),
                          items: cities
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: _selectedProvince == null
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedCity = value;
                                    _selectedBarangay = null;
                                  });
                                },
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Select a municipality'
                              : null,
                        ),
                        const SizedBox(height: 20),

                        // ── Barangay ──────────────────────────────────
                        DropdownButtonFormField<String>(
                          key: ValueKey('brgy_${_selectedCity ?? "none"}'),
                          initialValue: _selectedBarangay,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'BARANGAY',
                            isDense: true,
                            prefixIcon:
                                Icon(Icons.holiday_village_rounded, size: 20),
                          ),
                          hint: const Text('Select barangay'),
                          items: barangays
                              .map((b) =>
                                  DropdownMenuItem(value: b, child: Text(b)))
                              .toList(),
                          onChanged: _selectedCity == null
                              ? null
                              : (value) {
                                  setState(() => _selectedBarangay = value);
                                },
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Select a barangay'
                              : null,
                        ),
                        const SizedBox(height: 20),

                        // ── Daily Route Sequence ──────────────────────
                        TextFormField(
                          controller: _sequenceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'DAILY ROUTE SEQUENCE',
                            isDense: true,
                            prefixIcon: Icon(Icons.reorder_rounded, size: 20),
                            helperText:
                                'Priority order for the driver\'s daily route (1 = first stop)',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (int.tryParse(v) == null) return 'Must be a number';
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 18),
                        label:
                            Text(_isEdit ? 'UPDATE BRANCH' : 'SAVE BRANCH'),
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
