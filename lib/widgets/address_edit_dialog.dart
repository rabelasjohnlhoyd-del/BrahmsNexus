import 'package:flutter/material.dart';
import '../data/philippine_address_data.dart';
import '../theme/app_theme.dart';
import 'staff_button.dart';

/// Modal bottom sheet for editing a Philippine address with Province, City,
/// and Barangay dropdowns that match the Register page exactly.
class AddressEditDialog extends StatefulWidget {
  final String initialAddress;

  const AddressEditDialog({
    super.key,
    required this.initialAddress,
  });

  static Future<String?> show(BuildContext context, {required String initialAddress}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddressEditDialog(initialAddress: initialAddress),
    );
  }

  @override
  State<AddressEditDialog> createState() => _AddressEditDialogState();
}

class _AddressEditDialogState extends State<AddressEditDialog> {
  String _selectedProvince = 'Laguna';
  String? _selectedCity;
  String? _selectedBarangay;
  late final TextEditingController _streetController;
  String? _error;

  static const _fieldTextStyle = TextStyle(
    fontSize: 14,
    color: Color(0xFF24140B),
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.none,
  );

  static const _hintTextStyle = TextStyle(
    fontSize: 13,
    color: Color(0xFF9E8B7E),
    fontWeight: FontWeight.w400,
    decoration: TextDecoration.none,
  );

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6B584C),
        decoration: TextDecoration.none,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.accent,
        decoration: TextDecoration.none,
      ),
      hintStyle: _hintTextStyle,
      prefixIcon: prefixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDCCFC3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _streetController = TextEditingController();
    _parseInitialAddress();
  }

  void _parseInitialAddress() {
    final raw = widget.initialAddress.trim();
    if (raw.isEmpty || raw == 'Not set') {
      _selectedProvince = 'Laguna';
      _selectedCity = 'Sta. Cruz';
      _updateBarangays();
      return;
    }

    for (final p in PhilippineAddressData.provinces) {
      if (raw.toLowerCase().contains(p.toLowerCase())) {
        _selectedProvince = p;
        break;
      }
    }

    final cities = PhilippineAddressData.getCities(_selectedProvince);
    for (final c in cities) {
      if (raw.toLowerCase().contains(c.toLowerCase())) {
        _selectedCity = c;
        break;
      }
    }
    _selectedCity ??= cities.isNotEmpty ? cities.first : null;
    _updateBarangays();

    if (_selectedCity != null) {
      final brgys = PhilippineAddressData.getBarangays(_selectedCity!);
      for (final b in brgys) {
        if (raw.toLowerCase().contains(b.toLowerCase())) {
          _selectedBarangay = b;
          break;
        }
      }
      if (_selectedBarangay == null && brgys.isNotEmpty) {
        _selectedBarangay = brgys.first;
      }
    }

    final parts = raw.split(',');
    if (parts.isNotEmpty && !parts.first.toLowerCase().contains('brgy')) {
      _streetController.text = parts.first.trim();
    }
  }

  void _updateBarangays() {
    if (_selectedCity == null) {
      _selectedBarangay = null;
      return;
    }
    final brgys = PhilippineAddressData.getBarangays(_selectedCity!);
    if (!brgys.contains(_selectedBarangay)) {
      _selectedBarangay = brgys.isNotEmpty ? brgys.first : null;
    }
  }

  @override
  void dispose() {
    _streetController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final street = _streetController.text.trim();
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      setState(() => _error = 'Pumili ng City / Municipality.');
      return;
    }
    if (_selectedBarangay == null || _selectedBarangay!.isEmpty) {
      setState(() => _error = 'Pumili ng Barangay.');
      return;
    }
    if (street.isEmpty) {
      setState(() => _error = 'Ilagay ang street name o house number.');
      return;
    }
    if (street.length < 3) {
      setState(() => _error = 'Dapat may kahit 3 characters ang street address.');
      return;
    }

    final fullAddress = '$street, Brgy. $_selectedBarangay, $_selectedCity, $_selectedProvince';
    Navigator.of(context).pop(fullAddress);
  }

  @override
  Widget build(BuildContext context) {
    final cities = PhilippineAddressData.getCities(_selectedProvince);
    final barangays = _selectedCity != null
        ? PhilippineAddressData.getBarangays(_selectedCity!)
        : <String>[];

    return Material(
      color: Colors.transparent,
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: '.SF Pro Text',
          decoration: TextDecoration.none,
          color: AppColors.textPrimary,
        ),
        child: Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x20000000),
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pull Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCCFC3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header with Title & Close Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Residential Address',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF24140B),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF9E8B7E)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Piliin ang iyong lokasyon gamit ang mga dropdown.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF7A6556),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Province Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProvince,
                    isExpanded: true,
                    style: _fieldTextStyle,
                    decoration: _fieldDecoration(
                      label: 'Province',
                      prefixIcon: const Icon(Icons.map_outlined, size: 19, color: Color(0xFF8B4513)),
                    ),
                    items: PhilippineAddressData.provinces
                        .map((p) => DropdownMenuItem(value: p, child: Text(p, style: _fieldTextStyle)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedProvince = value;
                        _selectedCity = null;
                        _selectedBarangay = null;
                        _error = null;
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  // City / Municipality Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCity != null && cities.contains(_selectedCity) ? _selectedCity : null,
                    isExpanded: true,
                    style: _fieldTextStyle,
                    decoration: _fieldDecoration(
                      label: 'City / Municipality',
                      prefixIcon: const Icon(Icons.location_city_outlined, size: 19, color: Color(0xFF8B4513)),
                    ),
                    hint: const Text('Select city or municipality', style: _hintTextStyle),
                    items: cities
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: _fieldTextStyle)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCity = value;
                        _selectedBarangay = null;
                        _error = null;
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  // Barangay Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBarangay != null && barangays.contains(_selectedBarangay) ? _selectedBarangay : null,
                    isExpanded: true,
                    style: _fieldTextStyle,
                    decoration: _fieldDecoration(
                      label: 'Barangay',
                      prefixIcon: const Icon(Icons.holiday_village_outlined, size: 19, color: Color(0xFF8B4513)),
                    ),
                    hint: const Text('Select barangay', style: _hintTextStyle),
                    items: barangays
                        .map((b) => DropdownMenuItem(value: b, child: Text(b, style: _fieldTextStyle)))
                        .toList(),
                    onChanged: _selectedCity == null
                        ? null
                        : (value) {
                            setState(() {
                              _selectedBarangay = value;
                              _error = null;
                            });
                          },
                  ),
                  const SizedBox(height: 14),

                  // Street / House No. Field
                  TextFormField(
                    controller: _streetController,
                    textInputAction: TextInputAction.done,
                    style: _fieldTextStyle,
                    decoration: _fieldDecoration(
                      label: 'House No. / Street / Subd.',
                      hint: 'e.g. 124 Rizal St., Purok 3',
                      prefixIcon: const Icon(Icons.home_outlined, size: 19, color: Color(0xFF8B4513)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Apply Address Button
                  SizedBox(
                    width: double.infinity,
                    child: StaffButton(
                      label: 'Apply Address',
                      onPressed: _handleSave,
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
