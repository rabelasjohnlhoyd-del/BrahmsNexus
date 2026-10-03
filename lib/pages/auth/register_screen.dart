import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/philippine_address_data.dart';
import '../../models/account_status.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/gemini_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mobile_auth_layout.dart';
import '../../widgets/terms_and_conditions_dialog.dart';
import 'account_status_screen.dart';
import 'email_otp_screen.dart';
import 'login_screen.dart';

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
  final _birthDateController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  final _streetController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  DateTime? _selectedBirthDate;
  String _selectedPosition = 'Branch Cook';

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
  bool _agreedToTerms = false;
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
    _birthDateController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _streetController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _setBirthDate(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    setState(() {
      _selectedBirthDate = birthDate;
      _birthDateController.text =
          '${birthDate.year}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}';
      _ageController.text = age.toString();
      _stepError = null;
    });
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate = _selectedBirthDate ?? DateTime(now.year - 20, now.month, now.day);
    final firstDate = DateTime(now.year - 80, 1, 1);
    final lastDate = DateTime(now.year - 1, 12, 31);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(lastDate) ? lastDate : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select Date of Birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8B4513),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF24140B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _setBirthDate(picked);
    }
  }

  String? _validatePhilippinePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Philippine contact number is required.';
    }
    final raw = value.trim().replaceAll(RegExp(r'[\s\-]'), '');
    final phRegex = RegExp(r'^(09|\+639)\d{9}$');
    if (!phRegex.hasMatch(raw)) {
      return 'Enter a valid Philippine mobile number (e.g. 0917 123 4567 or +639171234567).';
    }
    return null;
  }

  String _normalizePhPhone(String phone) {
    var p = phone.trim().replaceAll(RegExp(r'[\s\-]'), '');
    if (p.startsWith('+639')) {
      p = '09${p.substring(4)}';
    }
    return p;
  }

  String? _validateName(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }
    if (value.trim().length < 2) {
      return '$label must be at least 2 characters.';
    }
    final nameRegex = RegExp(r"^[a-zA-ZñÑáéíóúÁÉÍÓÚ\s\-'.]+$");
    if (!nameRegex.hasMatch(value.trim())) {
      return '$label must only contain letters.';
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

  Future<void> _nextStep() async {
    FocusScope.of(context).unfocus();
    setState(() => _stepError = null);

    if (_currentStep == 0) {
      final fNameErr = _validateName(_firstNameController.text, 'First name');
      if (fNameErr != null) {
        setState(() => _stepError = fNameErr);
        return;
      }

      final lNameErr = _validateName(_lastNameController.text, 'Last name');
      if (lNameErr != null) {
        setState(() => _stepError = lNameErr);
        return;
      }

      if (_middleNameController.text.trim().isNotEmpty) {
        final mNameErr = _validateName(_middleNameController.text, 'Middle name');
        if (mNameErr != null) {
          setState(() => _stepError = mNameErr);
          return;
        }
      }

      if (_selectedBirthDate == null || _birthDateController.text.trim().isEmpty) {
        setState(() => _stepError = 'Please select your Date of Birth.');
        return;
      }

      final age = int.tryParse(_ageController.text.trim());
      if (age == null) {
        setState(() => _stepError = 'Invalid birthdate. Please select your date of birth.');
        return;
      }
      if (age < 18) {
        setState(() => _stepError = 'Applicant must be at least 18 years old (Calculated age: $age).');
        return;
      }
      if (age > 80) {
        setState(() => _stepError = 'Applicant must be at most 80 years old (Calculated age: $age).');
        return;
      }

      final phoneErr = _validatePhilippinePhone(_contactController.text);
      if (phoneErr != null) {
        setState(() => _stepError = phoneErr);
        return;
      }

      final normalizedPhone = _normalizePhPhone(_contactController.text);
      final phoneRegistered = await SupabaseService.isPhoneRegistered(normalizedPhone);
      if (phoneRegistered) {
        setState(() => _stepError = 'This mobile number is already registered.');
        return;
      }

      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (_selectedCity == null || _selectedCity!.isEmpty) {
        setState(() => _stepError = 'Please select your city or municipality.');
        return;
      }
      if (_selectedBarangay == null || _selectedBarangay!.isEmpty) {
        setState(() => _stepError = 'Please select your barangay.');
        return;
      }
      if (_streetController.text.trim().isEmpty) {
        setState(() => _stepError = 'Please enter your street name or house number.');
        return;
      }
      if (_streetController.text.trim().length < 3) {
        setState(() => _stepError = 'Street address must be at least 3 characters.');
        return;
      }

      if (_selectedRoleString == 'Driver') {
        if (_photoLicenseResult == null || !_photoLicenseResult!.isValid) {
          setState(() => _stepError =
              'Driver applicants must upload a clear photo of their Driver\'s License.');
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

    if (!_agreedToTerms) {
      setState(() => _registerError = 'Please read and accept the Terms and Conditions to proceed.');
      return;
    }

    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _registerError = 'Please enter a username.');
      return;
    }
    if (username.length < 3) {
      setState(() => _registerError = 'Username must be at least 3 characters.');
      return;
    }
    if (username.length > 20) {
      setState(() => _registerError = 'Username must not exceed 20 characters.');
      return;
    }
    if (username.contains(' ')) {
      setState(() => _registerError = 'Username must not contain spaces.');
      return;
    }
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_.]+$');
    if (!usernameRegex.hasMatch(username)) {
      setState(() => _registerError = 'Username can only contain letters, numbers, underscores, and dots.');
      return;
    }

    final isUsernameTaken = await SupabaseService.isUsernameRegistered(username);
    if (isUsernameTaken) {
      setState(() => _registerError = 'This username is already taken. Please choose another.');
      return;
    }

    final email = _emailController.text.trim();
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (email.isEmpty) {
      setState(() => _registerError = 'Please enter your email address.');
      return;
    }
    if (!emailRegex.hasMatch(email)) {
      setState(() => _registerError = 'Please enter a valid email address (e.g. name@example.com).');
      return;
    }

    final isEmailTaken = await SupabaseService.isEmailRegistered(email);
    if (isEmailTaken) {
      setState(() => _registerError = 'This email address is already registered.');
      return;
    }

    final password = _passwordController.text;
    final passwordError = AuthService.validateStrongPassword(password);
    if (passwordError != null) {
      setState(() => _registerError = passwordError);
      return;
    }

    if (password != _confirmPasswordController.text) {
      setState(() => _registerError = 'Passwords do not match.');
      return;
    }

    final fullName = [
      _firstNameController.text.trim(),
      if (_middleNameController.text.trim().isNotEmpty)
        _middleNameController.text.trim(),
      _lastNameController.text.trim(),
      if (_selectedSuffix != null && _selectedSuffix!.isNotEmpty) _selectedSuffix!,
    ].join(' ');

    final normalizedPhone = _normalizePhPhone(_contactController.text);
    final targetPosition = _selectedRoleString == 'Driver' ? 'Driver' : _selectedPosition;

    setState(() => _isSubmitting = true);

    if (!mounted) return;

    // Navigate to Email OTP Verification Screen
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => EmailOtpScreen(
          email: email,
          onVerified: () async {
            final error = await AuthService.register(
              username: username,
              password: password,
              fullName: fullName,
              contactNumber: normalizedPhone,
              role: UserRole.staff,
              position: targetPosition,
              email: email,
              age: _ageController.text.trim(),
              address: _addressController.text.trim(),
              driverLicenseNumber: _photoLicenseResult?.licenseNumber ?? '',
              driverLicenseExpiry: _photoLicenseResult?.expiryDate ?? '',
              isLicenseVerified: _selectedRoleString == 'Driver' && _photoLicenseResult?.isValid == true,
              isEmailVerified: true,
              isPhoneVerified: false,
              firstName: _firstNameController.text.trim(),
              middleName: _middleNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
            );

            if (error == null) {
              if (!mounted || !context.mounted) return error;
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const AccountStatusScreen(status: AccountStatus.pending),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOutCubic,
                      ),
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 400),
                ),
                (route) => false,
              );
            }
            return error;
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
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
      child: MobileAuthLayout(
        showBackButton: true,
        onBack: _prevStep,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title & step subtitle (left-aligned, replaces old centered header)
              const Text(
                'Create Account',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF24140B),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getStepSubtitle(),
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF7A6556),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),

              // Stepper Progress Indicators
              _buildStepIndicator(),
              const SizedBox(height: 18),

              // Step Content with smooth animated transition
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOutCubic,
                      ),
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        )),
                        child: child,
                      ),
                    );
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

              // Bottom Login Link with smooth transition
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
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: _isSubmitting
                        ? null
                        : () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              Navigator.of(context).pushReplacement(
                                PageRouteBuilder(
                                  pageBuilder:
                                      (context, animation, secondaryAnimation) =>
                                          const LoginScreen(),
                                  transitionsBuilder: (context, animation,
                                      secondaryAnimation, child) {
                                    return FadeTransition(
                                      opacity: CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeInOutCubic,
                                      ),
                                      child: child,
                                    );
                                  },
                                  transitionDuration:
                                      const Duration(milliseconds: 400),
                                  reverseTransitionDuration:
                                      const Duration(milliseconds: 400),
                                ),
                              );
                            }
                          },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  String _getStepSubtitle() {
    switch (_currentStep) {
      case 0:
        return 'Step 1 of 3: Personal Details';
      case 1:
        return 'Step 2 of 3: Address & Verification';
      case 2:
        return 'Step 3 of 3: Account Credentials';
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
        const Text('ROLE & POSITION', style: _sectionLabelStyle),
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
        if (_selectedRoleString == 'Staff') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedPosition,
            style: _fieldTextStyle,
            decoration: _fieldDecoration(
              label: 'Position',
              prefixIcon: const Icon(Icons.work_outline_rounded, size: 19),
            ),
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'Branch Cook', child: Text('Branch Cook')),
              DropdownMenuItem(value: 'Floating Cook', child: Text('Floating Cook')),
              DropdownMenuItem(value: 'Production Cook', child: Text('Production Cook')),
              DropdownMenuItem(value: 'Production Meat Cutter', child: Text('Production Meat Cutter')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedPosition = val);
            },
          ),
        ],
        const SizedBox(height: 16),

        const Text('FULL NAME', style: _sectionLabelStyle),
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

        const Text('BIRTHDATE & CONTACT', style: _sectionLabelStyle),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: _pickBirthDate,
                borderRadius: BorderRadius.circular(10),
                child: IgnorePointer(
                  child: TextFormField(
                    controller: _birthDateController,
                    style: _fieldTextStyle,
                    decoration: _fieldDecoration(
                      label: 'Date of Birth',
                      hint: 'YYYY-MM-DD',
                      prefixIcon: const Icon(Icons.cake_outlined, size: 19),
                      suffixIcon: const Icon(Icons.calendar_month_outlined, size: 19, color: Color(0xFF8B4513)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _ageController,
                readOnly: true,
                style: _fieldTextStyle.copyWith(fontWeight: FontWeight.bold),
                decoration: _fieldDecoration(
                  label: 'Age',
                  hint: 'Auto',
                  prefixIcon: const Icon(Icons.numbers_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _contactController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          style: _fieldTextStyle,
          decoration: _fieldDecoration(
            label: 'Mobile Number',
            hint: '0917 123 4567',
            prefixIcon: const Icon(Icons.phone_iphone_outlined, size: 19),
          ),
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
        const Text('HOME ADDRESS', style: _sectionLabelStyle),
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
            label: 'City or Municipality',
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
            label: 'Street or House No.',
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
          const Text('DRIVER\'S LICENSE', style: _sectionLabelStyle),
          const SizedBox(height: 4),
          const Text(
            'Take or upload a clear photo of your Driver\'s License.',
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
                          'Verifying license...',
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
            hint: 'Upper, lower, digit, symbol (min. 6)',
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
                  'All applications must be approved by management before account activation.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B584C), height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Terms & Conditions checkbox
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _agreedToTerms,
                activeColor: const Color(0xFF8B4513),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF7A6556),
                    height: 1.35,
                  ),
                  children: [
                    const TextSpan(text: 'I have read and agree to the '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => showTermsDialog(context),
                        child: const Text(
                          'Terms and Conditions',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF8B4513),
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFF8B4513),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
        height: 48,
        child: ElevatedButton(
          onPressed: _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
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
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
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
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
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
        SizedBox(
          width: 80,
          height: 48,
          child: OutlinedButton(
            onPressed: _isSubmitting ? null : _prevStep,
            style: OutlinedButton.styleFrom(
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
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Submit Application',
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
