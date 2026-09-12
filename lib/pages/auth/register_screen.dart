
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/philippine_address_data.dart';
import '../../models/account_status.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/gemini_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_brand_mark.dart';
import '../../widgets/auth_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/social_login_row.dart';
import 'account_status_screen.dart';

/// Staff/Driver self-registration.
///
/// There is deliberately NO Owner option here — there is exactly one
/// pre-seeded Owner account, and it never goes through registration.
/// Staff vs. Driver IS shown here (unlike on Login) because it's a
/// legitimate thing the applicant states about themselves — which job
/// they're applying for — not a claim about system-level access.
///
/// Shares its overall shape with LoginScreen on purpose (back button +
/// [AuthBrandMark] on the plain page background, then an [AuthCard]
/// holding the form) rather than the old boxed/colored hero banner —
/// so Login and Register read as two states of the same screen
/// instead of two differently-designed pages.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  final _streetController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Philippine Address Cascading Selector (Province -> City -> Barangay)
  String _selectedProvince = 'Laguna';
  String? _selectedCity;
  String? _selectedBarangay;


  // Driver License Photo Verification fields (via Gemini AI Multimodal Vision)
  Uint8List? _licenseImageBytes;
  bool _isAnalyzingPhoto = false;
  GeminiPhotoLicenseResult? _photoLicenseResult;
  final ImagePicker _imagePicker = ImagePicker();

  String _selectedRoleString = 'Staff';
  String? _selectedSuffix;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  String? _registerError;

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _streetController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  void _updateFullAddress() {
    final parts = <String>[];
    final street = _streetController.text.trim();
    if (street.isNotEmpty) parts.add(street);
    if (_selectedBarangay != null && _selectedBarangay!.isNotEmpty) {
      parts.add('Brgy. $_selectedBarangay');
    }
    if (_selectedCity != null && _selectedCity!.isNotEmpty) {
      parts.add(_selectedCity!);
    }
    if (_selectedProvince.isNotEmpty) {
      parts.add(_selectedProvince);
    }
    setState(() {
      _addressController.text = parts.join(', ');
    });
  }

  Future<void> _pickLicensePhoto(ImageSource source) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      setState(() {
        _licenseImageBytes = bytes;
        _isAnalyzingPhoto = true;
        _photoLicenseResult = null;
      });

      final fullName = [
        _firstNameController.text.trim(),
        if (_middleNameController.text.trim().isNotEmpty)
          _middleNameController.text.trim(),
        _lastNameController.text.trim(),
      ].join(' ');

      final result = await GeminiService.validateDriverLicensePhoto(
        imageBytes: bytes,
        mimeType: 'image/jpeg',
        applicantName: fullName,
      );

      if (!mounted) return;
      setState(() {
        _isAnalyzingPhoto = false;
        _photoLicenseResult = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzingPhoto = false;
        _photoLicenseResult = GeminiPhotoLicenseResult(
          isValid: false,
          isDriverLicense: false,
          rejectionReason: 'Hindi mabasa ang litrato ($e). Mangyaring sumubok muli.',
        );
      });
    }
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    setState(() => _registerError = null);
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _registerError = 'Please enter a valid email address.');
      return;
    }

    final ageInt = int.tryParse(_ageController.text.trim()) ?? 0;
    if (ageInt < 18) {
      setState(() => _registerError = 'Applicant must be at least 18 years old.');
      return;
    }

    if (_selectedRoleString == 'Driver') {
      if (_photoLicenseResult == null || !_photoLicenseResult!.isValid) {
        setState(() => _registerError =
            'Mangyaring mag-upload ng valid na litrato ng iyong opisyal na LTO Driver\'s License.');
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final fullName = [
      _firstNameController.text.trim(),
      if (_middleNameController.text.trim().isNotEmpty)
        _middleNameController.text.trim(),
      _lastNameController.text.trim(),
      ?_selectedSuffix,
    ].join(' ');

    final error = await AuthService.register(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      fullName: fullName,
      contactNumber: _contactController.text.trim(),
      role: UserRole.staff,
      position: _selectedRoleString == 'Driver' ? 'Driver' : 'Branch Cook',
      email: email,
      age: _ageController.text.trim(),
      address: _addressController.text.trim(),
      driverLicenseNumber: _photoLicenseResult?.licenseNumber ?? '',
      driverLicenseExpiry: _photoLicenseResult?.expiryDate ?? '',
      isLicenseVerified: _selectedRoleString == 'Driver' && _photoLicenseResult?.isValid == true,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isSubmitting = false;
        _registerError = error;
      });
      return;
    }

    setState(() => _isSubmitting = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            const AccountStatusScreen(status: AccountStatus.pending),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 20),
                        color: AppColors.textPrimary,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: AuthBrandMark(icon: Icons.person_add_alt_1_rounded),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Create your account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Simplify your workday — an Owner reviews every '
                      'application before it goes live.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Elevated form card — matches AuthCard on
                    // LoginScreen, so both screens read as one
                    // consistent surface.
                    AuthCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'APPLYING AS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          // In-app registration is for Staff roles only. Role is determined 
                          // by Owner later. For now, this is just a role suggestion.
                          const SizedBox(height: 12),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'Staff',
                                label: Text('STAFF'),
                                icon: Icon(Icons.badge_outlined, size: 18),
                              ),
                              ButtonSegment(
                                value: 'Driver',
                                label: Text('DRIVER'),
                                icon: Icon(Icons.local_shipping_outlined, size: 18),
                              ),
                            ],
                            selected: {_selectedRoleString},
                            onSelectionChanged: (value) {
                              setState(() => _selectedRoleString = value.first);
                            },
                            style: SegmentedButton.styleFrom(
                              selectedBackgroundColor: AppColors.accent,
                              selectedForegroundColor: Colors.white,
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'FULL NAME',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _firstNameController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'FIRST NAME',
                                    isDense: true,
                                    prefixIcon: Icon(Icons.person_outline, size: 20),
                                  ),
                                  validator: (v) => _required(v, 'First name'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _lastNameController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'LAST NAME',
                                    isDense: true,
                                  ),
                                  validator: (v) => _required(v, 'Last name'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _middleNameController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'MIDDLE NAME (OPTIONAL)',
                                    isDense: true,
                                    prefixIcon: Icon(Icons.person_outline, size: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _selectedSuffix,
                                  decoration: const InputDecoration(
                                    labelText: 'SUFFIX',
                                    isDense: true,
                                  ),
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                        value: null, child: Text('—')),
                                    DropdownMenuItem(
                                        value: 'Jr.', child: Text('JR.')),
                                    DropdownMenuItem(
                                        value: 'Sr.', child: Text('SR.')),
                                    DropdownMenuItem(
                                        value: 'II', child: Text('II')),
                                    DropdownMenuItem(
                                        value: 'III', child: Text('III')),
                                    DropdownMenuItem(
                                        value: 'IV', child: Text('IV')),
                                    DropdownMenuItem(
                                        value: 'V', child: Text('V')),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _selectedSuffix = value);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'PERSONAL & CONTACT DETAILS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'EMAIL ADDRESS',
                              hintText: 'name@example.com',
                              isDense: true,
                              prefixIcon: Icon(Icons.email_outlined, size: 20),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Email is required';
                              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                              if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email address';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 105,
                                child: TextFormField(
                                  controller: _ageController,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'AGE',
                                    hintText: '25',
                                    isDense: true,
                                    prefixIcon: Icon(Icons.cake_outlined, size: 19),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Required';
                                    final a = int.tryParse(v.trim());
                                    if (a == null || a < 18) return '18+ only';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _contactController,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'CONTACT NUMBER',
                                    hintText: '0917 123 4567',
                                    isDense: true,
                                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                                  ),
                                  validator: (v) => _required(v, 'Contact number'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── ADDRESS SECTION HEADER ──────────────────────
                          Row(
                            children: const [
                              Icon(Icons.location_on_outlined,
                                  size: 15, color: AppColors.accent),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'RESIDENTIAL ADDRESS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // ── PROVINCE DROPDOWN ──────────────────────────
                          DropdownButtonFormField<String>(
                            initialValue: _selectedProvince,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'PROVINCE',
                              isDense: true,
                              prefixIcon: Icon(Icons.map_outlined, size: 19),
                            ),
                            items: PhilippineAddressData.provinces
                                .map((p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(p),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedProvince = value;
                                _selectedCity = null;
                                _selectedBarangay = null;
                              });
                              _updateFullAddress();
                            },
                            validator: (v) =>
                                v == null ? 'Province is required' : null,
                          ),
                          const SizedBox(height: 12),

                          // ── CITY / MUNICIPALITY DROPDOWN ───────────────
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCity,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'CITY / MUNICIPALITY',
                              isDense: true,
                              prefixIcon:
                                  Icon(Icons.location_city_outlined, size: 19),
                            ),
                            hint: const Text('Pumili ng lungsod o bayan'),
                            items: PhilippineAddressData.getCities(
                                    _selectedProvince)
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCity = value;
                                _selectedBarangay = null;
                              });
                              _updateFullAddress();
                            },
                            validator: (v) =>
                                v == null ? 'City / Municipality is required' : null,
                          ),
                          const SizedBox(height: 12),

                          // ── BARANGAY DROPDOWN ──────────────────────────
                          DropdownButtonFormField<String>(
                            initialValue: _selectedBarangay,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'BARANGAY',
                              isDense: true,
                              prefixIcon:
                                  Icon(Icons.holiday_village_outlined, size: 19),
                            ),
                            hint: const Text('Pumili ng barangay'),
                            items: (_selectedCity == null
                                    ? <String>[]
                                    : PhilippineAddressData.getBarangays(
                                        _selectedCity!))
                                .map((b) => DropdownMenuItem(
                                      value: b,
                                      child: Text(b),
                                    ))
                                .toList(),
                            onChanged: _selectedCity == null
                                ? null
                                : (value) {
                                    setState(
                                        () => _selectedBarangay = value);
                                    _updateFullAddress();
                                  },
                            validator: (v) =>
                                v == null ? 'Barangay is required' : null,
                          ),
                          const SizedBox(height: 12),

                          // ── STREET / HOUSE / PUROK (optional) ─────────
                          TextFormField(
                            controller: _streetController,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => _updateFullAddress(),
                            decoration: const InputDecoration(
                              labelText: 'STREET / HOUSE NO. / PUROK (optional)',
                              hintText: 'e.g. 12 Sampaguita St., Purok 3',
                              isDense: true,
                              prefixIcon:
                                  Icon(Icons.home_outlined, size: 19),
                            ),
                          ),

                          // ── ADDRESS PREVIEW ────────────────────────────
                          if (_addressController.text.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.accent
                                    .withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.accent
                                        .withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_circle_outline,
                                      size: 15,
                                      color: AppColors.accent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _addressController.text,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Driver-only credentials & LTO validation via Google AI Vision
                          if (_selectedRoleString == 'Driver') ...[
                            const SizedBox(height: 24),
                            Row(
                              children: const [
                                Icon(Icons.badge_rounded, size: 16, color: AppColors.accent),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'DRIVER\'S LICENSE VERIFICATION (AI VISION)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Kumuha o mag-upload ng malinaw na litrato ng iyong opisyal na LTO Driver\'s License card. Susuriin ito ng Gemini AI.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 12),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _photoLicenseResult?.isValid == true
                                      ? AppColors.success.withValues(alpha: 0.5)
                                      : (_photoLicenseResult != null && !_photoLicenseResult!.isValid)
                                          ? AppColors.error.withValues(alpha: 0.5)
                                          : AppColors.border,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  if (_licenseImageBytes != null) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Stack(
                                        alignment: Alignment.topRight,
                                        children: [
                                          Image.memory(
                                            _licenseImageBytes!,
                                            height: 160,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: CircleAvatar(
                                              radius: 16,
                                              backgroundColor: Colors.black.withValues(alpha: 0.6),
                                              child: IconButton(
                                                padding: EdgeInsets.zero,
                                                icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
                                                onPressed: _isAnalyzingPhoto ? null : () => _pickLicensePhoto(ImageSource.camera),
                                                tooltip: 'Retake',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],

                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _isAnalyzingPhoto ? null : () => _pickLicensePhoto(ImageSource.camera),
                                          icon: const Icon(Icons.camera_alt_rounded, size: 18),
                                          label: const Text('Take Photo'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.accent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _isAnalyzingPhoto ? null : () => _pickLicensePhoto(ImageSource.gallery),
                                          icon: const Icon(Icons.photo_library_rounded, size: 18),
                                          label: const Text('From Gallery'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (_isAnalyzingPhoto) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: const [
                                          SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Sinusuri ng Gemini AI ang litrato ng lisensya...',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  if (!_isAnalyzingPhoto && _photoLicenseResult != null) ...[
                                    const SizedBox(height: 16),
                                    if (_photoLicenseResult!.isValid)
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: AppColors.success.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: const [
                                                Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
                                                SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    'LTO Driver\'s License Verified',
                                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.success),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            if (_photoLicenseResult!.licenseNumber.isNotEmpty)
                                              Text('License No: ${_photoLicenseResult!.licenseNumber}',
                                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                            if (_photoLicenseResult!.expiryDate.isNotEmpty)
                                              Text('Valid Until: ${_photoLicenseResult!.expiryDate}',
                                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                            if (_photoLicenseResult!.cardHolderName.isNotEmpty)
                                              Text('Cardholder: ${_photoLicenseResult!.cardHolderName}',
                                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                            if (_photoLicenseResult!.classification.isNotEmpty)
                                              Text('Type: ${_photoLicenseResult!.classification}',
                                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Hindi Valid ang Litrato',
                                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.error),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _photoLicenseResult!.rejectionReason,
                                                    style: const TextStyle(fontSize: 12, color: AppColors.error),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'ACCOUNT CREDENTIALS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'USERNAME',
                              isDense: true,
                              prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                            ),
                            validator: (v) => _required(v, 'Username'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'PASSWORD',
                              isDense: true,
                              prefixIcon: const Icon(Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (v) => _required(v, 'Password'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleRegister(),
                            decoration: InputDecoration(
                              labelText: 'CONFIRM PASSWORD',
                              isDense: true,
                              prefixIcon: const Icon(Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                              ),
                            ),
                            validator: _validateConfirmPassword,
                          ),
                          if (_registerError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _registerError!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          PrimaryButton(
                            label: 'SIGN UP',
                            isLoading: _isSubmitting,
                            onPressed: _handleRegister,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: _isSubmitting
                              ? null
                              : () => Navigator.of(context).maybePop(),
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const _OrDivider(),
                    const SizedBox(height: 18),
                    const SocialLoginRow(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR CONTINUE WITH',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}
