import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/philippine_address_data.dart';
import '../../models/account_status.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/gemini_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_admin_layout.dart';
import '../../widgets/auth_brand_mark.dart';
import '../../widgets/primary_button.dart';
import 'account_status_screen.dart';

/// Clean, simple, and professional Registration Screen for Web Admin & Applicants.
///
/// Designed with proper enterprise UI standards:
/// - Clean 3-step wizard with persistent state and step validation
/// - Refined form fields and clear typography
/// - Ample spacing and dignified color palette
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Current wizard step (0: Personal, 1: Address & Role, 2: Account)
  int _currentStep = 0;

  // Form Controllers
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

  // Philippine Address Cascading Selector
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
  String? _stepError;
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
        _stepError = null;
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
          rejectionReason: 'Unable to process the image ($e). Please try again.',
        );
      });
    }
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();
    setState(() => _stepError = null);

    if (_currentStep == 0) {
      if (_firstNameController.text.trim().isEmpty) {
        setState(() => _stepError = 'Please enter your first name.');
        return;
      }
      if (_lastNameController.text.trim().isEmpty) {
        setState(() => _stepError = 'Please enter your last name.');
        return;
      }
      final age = int.tryParse(_ageController.text.trim());
      if (age == null || age < 18) {
        setState(() => _stepError = 'Applicant must be at least 18 years old.');
        return;
      }
      if (_contactController.text.trim().isEmpty) {
        setState(() => _stepError = 'Please enter a contact number.');
        return;
      }

      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (_selectedCity == null || _selectedCity!.isEmpty) {
        setState(() => _stepError = 'Please select your City / Municipality.');
        return;
      }
      if (_selectedBarangay == null || _selectedBarangay!.isEmpty) {
        setState(() => _stepError = 'Please select your Barangay.');
        return;
      }
      if (_selectedRoleString == 'Driver') {
        if (_photoLicenseResult == null || !_photoLicenseResult!.isValid) {
          setState(() => _stepError =
              'Driver applicants must upload a valid verified LTO Driver\'s License photo.');
          return;
        }
      }

      setState(() => _currentStep = 2);
    }
  }

  void _prevStep() {
    FocusScope.of(context).unfocus();
    setState(() {
      _stepError = null;
      _registerError = null;
      if (_currentStep > 0) {
        _currentStep--;
      } else {
        Navigator.of(context).maybePop();
      }
    });
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _registerError = null;
      _stepError = null;
    });

    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _registerError = 'Please enter a username.');
      return;
    }
    if (username.length < 3) {
      setState(() => _registerError = 'Username must be at least 3 characters.');
      return;
    }

    final email = _emailController.text.trim();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _registerError = 'Please enter a valid email address.');
      return;
    }

    final password = _passwordController.text;
    if (password.length < 6) {
      setState(() => _registerError = 'Password must be at least 6 characters.');
      return;
    }

    if (password != _confirmPasswordController.text) {
      setState(() => _registerError = 'Passwords do not match.');
      return;
    }

    setState(() => _isSubmitting = true);

    final fullName = [
      _firstNameController.text.trim(),
      if (_middleNameController.text.trim().isNotEmpty)
        _middleNameController.text.trim(),
      _lastNameController.text.trim(),
      if (_selectedSuffix != null && _selectedSuffix!.isNotEmpty) _selectedSuffix!,
    ].join(' ');

    final error = await AuthService.register(
      username: username,
      password: password,
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
        builder: (_) => const AccountStatusScreen(status: AccountStatus.pending),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentStep > 0) {
          _prevStep();
        }
      },
      child: AuthAdminLayout(
        maxWidth: 460,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top header with Back button & Centered Logo (exact same vertical height as Login)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: Color(0xFF6B584C),
                        ),
                        onPressed: _prevStep,
                        tooltip:
                            _currentStep > 0 ? 'Previous Step' : 'Back to Sign In',
                      ),
                    ),
                    const Center(
                      child: AuthBrandMark(size: 72),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Title & Description matching LoginScreen baseline
                const Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF24140B),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _getStepSubtitle(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7A6556),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),

                // Stepper Progress Indicators
                _buildStepIndicator(),
                const SizedBox(height: 18),

                // Step Content with smooth animated transition
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: _buildCurrentStepContent(),
                  ),
                ),

                // Inline Step Error Banner
                if (_stepError != null) ...[
                  const SizedBox(height: 12),
                  _buildErrorBanner(_stepError!),
                ],

                // Submission Error Banner (on Step 3)
                if (_currentStep == 2 && _registerError != null) ...[
                  const SizedBox(height: 12),
                  _buildErrorBanner(_registerError!),
                ],

                const SizedBox(height: 22),

                // Navigation Buttons for Current Step
                _buildStepButtons(),

                const SizedBox(height: 16),

                // Bottom Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(
                        color: Color(0xFF7A6556),
                        fontSize: 12.5,
                      ),
                    ),
                    GestureDetector(
                      onTap: _isSubmitting ? null : () => Navigator.of(context).maybePop(),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
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
    );
  }

  String _getStepSubtitle() {
    switch (_currentStep) {
      case 0:
        return 'Step 1 of 3: Personal details & application role';
      case 1:
        return 'Step 2 of 3: Residential address & verification';
      case 2:
        return 'Step 3 of 3: Account security & credentials';
      default:
        return '';
    }
  }

  /// Matches LoginScreen field typography so labels stay readable
  /// instead of overflowing in compact register rows.
  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6B584C),
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6B584C),
      ),
      hintStyle: TextStyle(
        fontSize: 13,
        color: const Color(0xFF6B584C).withValues(alpha: 0.4),
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

  static const _fieldTextStyle = TextStyle(
    fontSize: 13,
    color: Color(0xFF24140B),
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  static const _sectionLabelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
    color: Color(0xFF7A6556),
  );

  // ─────────────────────────────────────────────────────────────
  // STEPPER PROGRESS BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildStepIndicator() {
    final steps = ['Personal', 'Address', 'Account'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED3)),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            final stepIndex = index ~/ 2;
            final isPassed = _currentStep > stepIndex;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: isPassed ? const Color(0xFF8B4513) : const Color(0xFFE2D4C5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }

          final stepIndex = index ~/ 2;
          final isCurrent = _currentStep == stepIndex;
          final isCompleted = _currentStep > stepIndex;

          return InkWell(
            onTap: isCompleted ? () => setState(() => _currentStep = stepIndex) : null,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted || isCurrent ? const Color(0xFF8B4513) : Colors.white,
                    border: Border.all(
                      color: isCompleted || isCurrent ? const Color(0xFF8B4513) : const Color(0xFFC0AFA2),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 11, color: Colors.white)
                        : Text(
                            '${stepIndex + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isCurrent ? Colors.white : const Color(0xFF7A6556),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  steps[stepIndex],
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    color: isCurrent
                        ? const Color(0xFF24140B)
                        : isCompleted
                            ? const Color(0xFF4A3B32)
                            : const Color(0xFF9E8B7E),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Personal();
      case 1:
        return _buildStep2AddressAndRole();
      case 2:
        return _buildStep3Account();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // STEP 1: ROLE & PERSONAL DETAILS
  // ─────────────────────────────────────────────────────────────
  Widget _buildStep1Personal() {
    return Column(
      key: const ValueKey('step_1_personal'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('APPLYING AS', style: _sectionLabelStyle),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'Staff',
              label: Text('Staff / Cook'),
              icon: Icon(Icons.badge_outlined, size: 16),
            ),
            ButtonSegment(
              value: 'Driver',
              label: Text('Driver'),
              icon: Icon(Icons.local_shipping_outlined, size: 16),
            ),
          ],
          selected: {_selectedRoleString},
          onSelectionChanged: (value) {
            setState(() {
              _selectedRoleString = value.first;
              _stepError = null;
            });
          },
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: const Color(0xFF8B4513),
            selectedForegroundColor: Colors.white,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF24140B),
            side: const BorderSide(color: Color(0xFFDCCFC3)),
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 16),

        const Text('FULL LEGAL NAME', style: _sectionLabelStyle),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _firstNameController,
                textInputAction: TextInputAction.next,
                style: _fieldTextStyle,
                decoration: _fieldDecoration(
                  label: 'First Name',
                  hint: 'Juan',
                ),
                validator: (v) => _required(v, 'First name'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _lastNameController,
                textInputAction: TextInputAction.next,
                style: _fieldTextStyle,
                decoration: _fieldDecoration(
                  label: 'Last Name',
                  hint: 'Dela Cruz',
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
                style: _fieldTextStyle,
                decoration: _fieldDecoration(
                  label: 'Middle Name',
                  hint: 'Optional',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: DropdownButtonFormField<String?>(
                initialValue: _selectedSuffix,
                style: _fieldTextStyle,
                decoration: _fieldDecoration(label: 'Suffix'),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: null, child: Text('None', style: _fieldTextStyle)),
                  DropdownMenuItem(value: 'Jr.', child: Text('Jr.', style: _fieldTextStyle)),
                  DropdownMenuItem(value: 'Sr.', child: Text('Sr.', style: _fieldTextStyle)),
                  DropdownMenuItem(value: 'II', child: Text('II', style: _fieldTextStyle)),
                  DropdownMenuItem(value: 'III', child: Text('III', style: _fieldTextStyle)),
                  DropdownMenuItem(value: 'IV', child: Text('IV', style: _fieldTextStyle)),
                  DropdownMenuItem(value: 'V', child: Text('V', style: _fieldTextStyle)),
                ],
                onChanged: (value) => setState(() => _selectedSuffix = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        const Text('CONTACT & DEMOGRAPHICS', style: _sectionLabelStyle),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                style: _fieldTextStyle,
                decoration: _fieldDecoration(
                  label: 'Age',
                  hint: '21',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                style: _fieldTextStyle,
                decoration: _fieldDecoration(
                  label: 'Contact Number',
                  hint: '0917 123 4567',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STEP 2: ADDRESS & ROLE VERIFICATION
  // ─────────────────────────────────────────────────────────────
  Widget _buildStep2AddressAndRole() {
    return Column(
      key: const ValueKey('step_2_address'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('RESIDENTIAL LOCATION', style: _sectionLabelStyle),
        const SizedBox(height: 8),

        DropdownButtonFormField<String>(
          initialValue: _selectedProvince,
          isExpanded: true,
          style: _fieldTextStyle,
          decoration: _fieldDecoration(
            label: 'Province',
            prefixIcon: const Icon(Icons.map_outlined, size: 19),
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
            });
            _updateFullAddress();
          },
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          initialValue: _selectedCity,
          isExpanded: true,
          style: _fieldTextStyle,
          decoration: _fieldDecoration(
            label: 'City / Municipality',
            prefixIcon: const Icon(Icons.location_city_outlined, size: 19),
          ),
          hint: const Text('Select city or municipality', style: _fieldTextStyle),
          items: PhilippineAddressData.getCities(_selectedProvince)
              .map((c) => DropdownMenuItem(value: c, child: Text(c, style: _fieldTextStyle)))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedCity = value;
              _selectedBarangay = null;
            });
            _updateFullAddress();
          },
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          initialValue: _selectedBarangay,
          isExpanded: true,
          style: _fieldTextStyle,
          decoration: _fieldDecoration(
            label: 'Barangay',
            prefixIcon: const Icon(Icons.holiday_village_outlined, size: 19),
          ),
          hint: const Text('Select barangay', style: _fieldTextStyle),
          items: (_selectedCity == null
                  ? <String>[]
                  : PhilippineAddressData.getBarangays(_selectedCity!))
              .map((b) => DropdownMenuItem(value: b, child: Text(b, style: _fieldTextStyle)))
              .toList(),
          onChanged: _selectedCity == null
              ? null
              : (value) {
                  setState(() => _selectedBarangay = value);
                  _updateFullAddress();
                },
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _streetController,
          textInputAction: TextInputAction.next,
          style: _fieldTextStyle,
          onChanged: (_) => _updateFullAddress(),
          decoration: _fieldDecoration(
            label: 'Street / House No.',
            hint: 'e.g. 12 Sampaguita St., Purok 3',
            prefixIcon: const Icon(Icons.home_outlined, size: 19),
          ),
        ),

        if (_addressController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE8DED3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF8B4513)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _addressController.text,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF24140B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Driver LTO AI Verification Section
        if (_selectedRoleString == 'Driver') ...[
          const SizedBox(height: 16),
          const Text('DRIVER\'S LICENSE VERIFICATION', style: _sectionLabelStyle),
          const SizedBox(height: 4),
          const Text(
            'Upload a clear photo of your official LTO card for instant verification.',
            style: TextStyle(fontSize: 13, color: Color(0xFF7A6556), height: 1.35),
          ),
          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _photoLicenseResult?.isValid == true
                    ? AppColors.success.withValues(alpha: 0.5)
                    : (_photoLicenseResult != null && !_photoLicenseResult!.isValid)
                        ? AppColors.error.withValues(alpha: 0.5)
                        : const Color(0xFFDCCFC3),
                width: 1.2,
              ),
            ),
            child: Column(
              children: [
                if (_licenseImageBytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Image.memory(
                          _licenseImageBytes!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: CircleAvatar(
                            radius: 13,
                            backgroundColor: Colors.black.withValues(alpha: 0.6),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.refresh, size: 14, color: Colors.white),
                              onPressed: _isAnalyzingPhoto
                                  ? null
                                  : () => _pickLicensePhoto(ImageSource.camera),
                              tooltip: 'Retake',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isAnalyzingPhoto
                            ? null
                            : () => _pickLicensePhoto(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined, size: 15),
                        label: const Text('Take Photo', style: TextStyle(fontSize: 11.5)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF24140B),
                          side: const BorderSide(color: Color(0xFFDCCFC3)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isAnalyzingPhoto
                            ? null
                            : () => _pickLicensePhoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, size: 15),
                        label: const Text('Upload File', style: TextStyle(fontSize: 11.5)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF24140B),
                          side: const BorderSide(color: Color(0xFFDCCFC3)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                  ],
                ),

                if (_isAnalyzingPhoto) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Verifying license card...',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8B4513)),
                        ),
                      ),
                    ],
                  ),
                ],

                if (!_isAnalyzingPhoto && _photoLicenseResult != null) ...[
                  const SizedBox(height: 8),
                  if (_photoLicenseResult!.isValid)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: AppColors.success, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'LTO License Verified: ${_photoLicenseResult!.licenseNumber}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.success),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 15),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _photoLicenseResult!.rejectionReason,
                              style: const TextStyle(fontSize: 11, color: AppColors.error),
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
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STEP 3: ACCOUNT & SECURITY CREDENTIALS
  // ─────────────────────────────────────────────────────────────
  Widget _buildStep3Account() {
    return Column(
      key: const ValueKey('step_3_account'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('LOGIN CREDENTIALS', style: _sectionLabelStyle),
        const SizedBox(height: 8),

        TextFormField(
          controller: _usernameController,
          textInputAction: TextInputAction.next,
          style: _fieldTextStyle,
          decoration: _fieldDecoration(
            label: 'Username',
            hint: 'Choose a login username',
            prefixIcon: const Icon(Icons.alternate_email_rounded, size: 19),
          ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: _fieldTextStyle,
          decoration: _fieldDecoration(
            label: 'Email Address',
            hint: 'name@example.com',
            prefixIcon: const Icon(Icons.email_outlined, size: 19),
          ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          style: _fieldTextStyle,
          decoration: _fieldDecoration(
            label: 'Password',
            hint: 'At least 6 characters',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 19,
                color: const Color(0xFF7A6556),
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          textInputAction: TextInputAction.done,
          style: _fieldTextStyle,
          onFieldSubmitted: (_) => _handleRegister(),
          decoration: _fieldDecoration(
            label: 'Confirm Password',
            hint: 'Re-enter your password',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 19,
                color: const Color(0xFF7A6556),
              ),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE8DED3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.security_rounded, size: 15, color: Color(0xFF8B4513)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'All applicant registrations undergo approval by Brahms Management before activation.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B584C), height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // NAVIGATION BUTTONS (BACK & NEXT / SUBMIT)
  // ─────────────────────────────────────────────────────────────
  Widget _buildStepButtons() {
    if (_currentStep == 0) {
      return SizedBox(
        height: 46,
        child: ElevatedButton(
          onPressed: _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B4513),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text(
            'Continue to Address',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              letterSpacing: 0.3,
            ),
          ),
        ),
      );
    }

    if (_currentStep == 1) {
      return Row(
        children: [
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: _prevStep,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: const Color(0xFF24140B),
                side: const BorderSide(color: Color(0xFFDCCFC3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Back',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B4513),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Step 2 (Final submission)
    return Row(
      children: [
        Expanded(
          flex: 1,
            child: OutlinedButton(
            onPressed: _isSubmitting ? null : _prevStep,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              foregroundColor: const Color(0xFF24140B),
              side: const BorderSide(color: Color(0xFFDCCFC3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Back',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: PrimaryButton(
            label: 'SUBMIT APPLICATION',
            isLoading: _isSubmitting,
            onPressed: _handleRegister,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
