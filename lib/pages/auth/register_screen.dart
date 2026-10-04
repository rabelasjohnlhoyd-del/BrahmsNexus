import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  final _contactFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();

  String? _phoneValidationError;
  String? _usernameValidationError;
  String? _emailValidationError;
  bool _isCheckingPhone = false;
  bool _isCheckingUsername = false;
  bool _isCheckingEmail = false;

  bool get _isDriver => _selectedPosition == 'Driver';
  int get _finalStepIndex => _isDriver ? 3 : 2;

  List<String> get _stepTitles => _isDriver
      ? ['Personal', 'License', 'Address', 'Account']
      : ['Personal', 'Address', 'Account'];

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

  String? _selectedSuffix;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  bool _agreedToTerms = false;
  String? _stepError;
  String? _registerError;

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _middleNameController.addListener(_onFieldChanged);
    _contactController.addListener(() {
      if (_phoneValidationError != null) {
        setState(() => _phoneValidationError = null);
      }
      final raw = _contactController.text.trim();
      if (raw.length == 11 && raw.startsWith('09')) {
        _checkPhoneUniqueness();
      }
      _onFieldChanged();
    });
    _streetController.addListener(_onFieldChanged);
    _usernameController.addListener(() {
      if (_usernameValidationError != null) {
        setState(() => _usernameValidationError = null);
      }
      _onFieldChanged();
    });
    _emailController.addListener(() {
      if (_emailValidationError != null) {
        setState(() => _emailValidationError = null);
      }
      _onFieldChanged();
    });

    _contactFocusNode.addListener(() {
      if (!_contactFocusNode.hasFocus) {
        _checkPhoneUniqueness();
      }
    });
    _usernameFocusNode.addListener(() {
      if (!_usernameFocusNode.hasFocus) {
        _checkUsernameUniqueness();
      }
    });
    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus) {
        _checkEmailUniqueness();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFormCache());
  }

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
    _contactFocusNode.dispose();
    _usernameFocusNode.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkPhoneUniqueness() async {
    final raw = _contactController.text.trim();
    if (raw.length != 11 || !raw.startsWith('09') || !RegExp(r'^[0-9]+$').hasMatch(raw)) {
      return;
    }
    setState(() => _isCheckingPhone = true);
    final normalized = _normalizePhPhone(raw);
    final exists = await SupabaseService.isPhoneRegistered(normalized);
    if (!mounted) return;
    setState(() {
      _isCheckingPhone = false;
      if (exists) {
        _phoneValidationError = 'Mobile number already exists.';
      } else {
        _phoneValidationError = null;
      }
    });
  }

  Future<void> _checkUsernameUniqueness() async {
    final username = _usernameController.text.trim().toLowerCase();
    if (username.length < 5 || username.length > 30) {
      return;
    }
    if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(username)) {
      return;
    }
    setState(() => _isCheckingUsername = true);
    final exists = await SupabaseService.isUsernameRegistered(username);
    if (!mounted) return;
    setState(() {
      _isCheckingUsername = false;
      if (exists) {
        _usernameValidationError = 'Username already exists.';
      } else {
        _usernameValidationError = null;
      }
    });
  }

  Future<void> _checkEmailUniqueness() async {
    final email = _emailController.text.trim().toLowerCase();
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return;
    }
    setState(() => _isCheckingEmail = true);
    final exists = await SupabaseService.isEmailRegistered(email);
    if (!mounted) return;
    setState(() {
      _isCheckingEmail = false;
      if (exists) {
        _emailValidationError = 'Email address already exists.';
      } else {
        _emailValidationError = null;
      }
    });
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
    // Max: must be born by 2008 (18+ in 2026) — Dec 31, 2008
    final lastDate = DateTime(2008, 12, 31);
    // Min: born as early as 1961
    final firstDate = DateTime(1961, 1, 1);
    final initialDate = _selectedBirthDate != null
        ? (_selectedBirthDate!.isBefore(lastDate) ? _selectedBirthDate! : lastDate)
        : DateTime(1995, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
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

    if (picked == null || !mounted) return;

    // If born in 1961–1979 (very senior), show a confirmation dialog
    if (picked.year <= 1979) {
      final age = now.year - picked.year - ((now.month < picked.month || (now.month == picked.month && now.day < picked.day)) ? 1 : 0);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Kumpirmasyon sa Edad'),
          content: Text(
            'Ang napili mong taon ng kapanganakan ay ${picked.year} ($age taong gulang). Kumpirmahin na ikaw ay may kakayahan at handang magtrabaho pa.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Kanselahin'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Oo, Handa at May Kakayahan',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B4513)),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    _setBirthDate(picked);
    _onFieldChanged();
  }

  String? _validatePhilippinePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required.';
    }
    if (value.contains(' ')) {
      return 'Mobile number must not contain spaces.';
    }
    if (!value.startsWith('09')) {
      return 'Mobile number must start with 09 (e.g. 09171234567).';
    }
    if (value.length != 11 || !RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Mobile number must be exactly 11 numeric digits.';
    }
    // Hanggang 3 lang ang pwedeng consecutive identical digits (bawal 4 o higit pa)
    if (RegExp(r'(.)\1{3,}').hasMatch(value)) {
      return 'Mobile number cannot have more than 3 consecutive identical digits.';
    }
    return null;
  }

  String _normalizePhPhone(String phone) {
    return phone.trim().replaceAll(RegExp(r'[\s]'), '');
  }

  String? _validateName(String? value, String label, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? '$label is required.' : null;
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return '$label must be at least 2 characters.';
    }
    if (trimmed.length > 50) {
      return '$label must not exceed 50 characters.';
    }
    if (value.contains(' ')) {
      return '$label must not contain spaces in between letters.';
    }
    final nameRegex = RegExp(r'^[a-zA-ZñÑáéíóúÁÉÍÓÚ]+$');
    if (!nameRegex.hasMatch(trimmed)) {
      return '$label must contain letters only (no numbers, symbols, or special characters).';
    }
    return null;
  }

  String _normalizeName(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    return trimmed[0].toUpperCase() + (trimmed.length > 1 ? trimmed.substring(1).toLowerCase() : '');
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
    _onFieldChanged();
  }

  // ── Form Cache ───────────────────────────────────────────────
  static const _cachePrefix = 'reg_cache_';

  void _onFieldChanged() {
    _saveFormCache();
  }

  Future<void> _saveFormCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_cachePrefix}firstName', _firstNameController.text);
    await prefs.setString('${_cachePrefix}lastName', _lastNameController.text);
    await prefs.setString('${_cachePrefix}middleName', _middleNameController.text);
    await prefs.setString('${_cachePrefix}birthDate', _birthDateController.text);
    await prefs.setString('${_cachePrefix}contact', _contactController.text);
    await prefs.setString('${_cachePrefix}position', _selectedPosition);
    await prefs.setString('${_cachePrefix}suffix', _selectedSuffix ?? '');
    await prefs.setString('${_cachePrefix}street', _streetController.text);
    await prefs.setString('${_cachePrefix}province', _selectedProvince);
    await prefs.setString('${_cachePrefix}city', _selectedCity ?? '');
    await prefs.setString('${_cachePrefix}barangay', _selectedBarangay ?? '');
    await prefs.setString('${_cachePrefix}username', _usernameController.text);
    await prefs.setString('${_cachePrefix}email', _emailController.text);
  }

  Future<void> _loadFormCache() async {
    final prefs = await SharedPreferences.getInstance();
    final fn = prefs.getString('${_cachePrefix}firstName') ?? '';
    final ln = prefs.getString('${_cachePrefix}lastName') ?? '';
    final mn = prefs.getString('${_cachePrefix}middleName') ?? '';
    final bd = prefs.getString('${_cachePrefix}birthDate') ?? '';
    final ct = prefs.getString('${_cachePrefix}contact') ?? '';
    final pos = prefs.getString('${_cachePrefix}position') ?? 'Branch Cook';
    final suf = prefs.getString('${_cachePrefix}suffix') ?? '';
    final st = prefs.getString('${_cachePrefix}street') ?? '';
    final prov = prefs.getString('${_cachePrefix}province') ?? 'Laguna';
    final city = prefs.getString('${_cachePrefix}city') ?? '';
    final brgy = prefs.getString('${_cachePrefix}barangay') ?? '';
    final uname = prefs.getString('${_cachePrefix}username') ?? '';
    final eml = prefs.getString('${_cachePrefix}email') ?? '';
    setState(() {
      _firstNameController.text = fn;
      _lastNameController.text = ln;
      _middleNameController.text = mn;
      _birthDateController.text = bd;
      if (bd.isNotEmpty) {
        _selectedBirthDate = DateTime.tryParse(bd);
        if (_selectedBirthDate != null) {
          final now = DateTime.now();
          int age = now.year - _selectedBirthDate!.year;
          if (now.month < _selectedBirthDate!.month ||
              (now.month == _selectedBirthDate!.month && now.day < _selectedBirthDate!.day)) {
            age--;
          }
          _ageController.text = age.toString();
        }
      }
      _contactController.text = ct;
      _selectedPosition = pos;
      _selectedSuffix = suf.isEmpty ? null : suf;
      _streetController.text = st;
      _selectedProvince = prov;
      _selectedCity = city.isEmpty ? null : city;
      _selectedBarangay = brgy.isEmpty ? null : brgy;
      _usernameController.text = uname;
      _emailController.text = eml;
    });
  }

  Future<void> _clearFormCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_cachePrefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
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
        final mNameErr = _validateName(_middleNameController.text, 'Middle name', required: false);
        if (mNameErr != null) {
          setState(() => _stepError = mNameErr);
          return;
        }
      }

      if (_selectedBirthDate == null || _birthDateController.text.trim().isEmpty) {
        setState(() => _stepError = 'Please select your Date of Birth.');
        return;
      }
      // Age is computed from birth date directly — no longer from _ageController
      final now = DateTime.now();
      int age = now.year - _selectedBirthDate!.year;
      if (now.month < _selectedBirthDate!.month ||
          (now.month == _selectedBirthDate!.month && now.day < _selectedBirthDate!.day)) {
        age--;
      }
      if (age < 18 || _selectedBirthDate!.year > 2008) {
        setState(() => _stepError =
            'Bawal ang minor (ipinanganak noong 2009 pataas). Dapat ay 18 taong gulang pataas (ipinanganak 2008 o mas maaga).');
        return;
      }
      if (_selectedBirthDate!.year < 1961) {
        setState(() => _stepError = 'Ang pinakamababang taon ng kapanganakan ay 1961.');
        return;
      }
      // _ageController kept in sync by _setBirthDate

      final phoneErr = _validatePhilippinePhone(_contactController.text);
      if (phoneErr != null) {
        setState(() => _stepError = phoneErr);
        return;
      }

      // Use cached uniqueness result if already checked
      if (_phoneValidationError != null) {
        setState(() => _stepError = _phoneValidationError);
        return;
      }

      final normalizedPhone = _normalizePhPhone(_contactController.text);
      final phoneRegistered = await SupabaseService.isPhoneRegistered(normalizedPhone);
      if (!mounted) return;
      if (phoneRegistered) {
        setState(() => _stepError = 'This mobile number is already registered.');
        return;
      }

      await _saveFormCache();
      setState(() => _currentStep = 1);

    } else if (_currentStep == 1 && _isDriver) {
      // Driver Step 1 → License validation
      if (_licenseImageBytes == null) {
        setState(() => _stepError = 'Please upload a photo of your Driver\'s License to continue.');
        return;
      }
      if (_isAnalyzingPhoto) {
        setState(() => _stepError = 'Please wait while we verify your license photo.');
        return;
      }
      if (_photoLicenseResult == null || !_photoLicenseResult!.isValid) {
        setState(() => _stepError =
            'License verification failed. Please upload a clear, valid Driver\'s License photo.');
        return;
      }
      await _saveFormCache();
      setState(() => _currentStep = 2);

    } else if (_currentStep == 1 && !_isDriver) {
      // Staff Step 1 → Address validation
      if (!_validateAddressFields()) return;
      await _saveFormCache();
      setState(() => _currentStep = 2);

    } else if (_currentStep == 2 && _isDriver) {
      // Driver Step 2 → Address validation
      if (!_validateAddressFields()) return;
      await _saveFormCache();
      setState(() => _currentStep = 3);
    }
  }

  /// Validates address fields and sets _stepError if invalid.
  /// Returns true if valid, false otherwise.
  bool _validateAddressFields() {
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      setState(() => _stepError = 'Please select your city or municipality.');
      return false;
    }
    if (_selectedBarangay == null || _selectedBarangay!.isEmpty) {
      setState(() => _stepError = 'Please select your barangay.');
      return false;
    }
    final street = _streetController.text.trim();
    if (street.isEmpty) {
      setState(() => _stepError = 'Street and House No. is required.');
      return false;
    }
    if (street.length < 3) {
      setState(() => _stepError = 'Street address must be at least 3 characters.');
      return false;
    }
    if (street.length > 100) {
      setState(() => _stepError = 'Street address must not exceed 100 characters.');
      return false;
    }
    if (!RegExp(r"^[a-zA-Z0-9\s.,\-/#']+$").hasMatch(street)) {
      setState(() => _stepError = 'Street address contains invalid characters.');
      return false;
    }
    // Hindi dapat puro numbers
    if (RegExp(r'^[0-9\s.,\-/#]+$').hasMatch(street) && !RegExp(r'[a-zA-Z]').hasMatch(street)) {
      setState(() => _stepError = 'Street address cannot be numbers or symbols only. Please include a street name.');
      return false;
    }
    // Hindi dapat puro special characters
    if (!RegExp(r'[a-zA-Z0-9]').hasMatch(street)) {
      setState(() => _stepError = 'Please enter a valid street address.');
      return false;
    }
    // Reject obvious invalid inputs
    final streetLower = street.toLowerCase();
    if (streetLower == 'asdf' || streetLower == 'qwerty' || streetLower == 'none' ||
        streetLower == 'n/a' || streetLower.contains('---')) {
      setState(() => _stepError = 'Please enter a valid, realistic street address.');
      return false;
    }
    return true;
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

    final username = _usernameController.text.trim().toLowerCase();
    if (username.isEmpty) {
      setState(() => _registerError = 'Please enter a username.');
      return;
    }
    if (username.length < 5) {
      setState(() => _registerError = 'Username must be at least 5 characters.');
      return;
    }
    if (username.length > 30) {
      setState(() => _registerError = 'Username must not exceed 30 characters.');
      return;
    }
    // Letters, numbers, underscore, period only
    if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(username)) {
      setState(() => _registerError = 'Username can only contain letters, numbers, underscores (_), and periods (.).');
      return;
    }
    // Cannot start or end with _ or .
    if (RegExp(r'^[_.]|[_.]$').hasMatch(username)) {
      setState(() => _registerError = 'Username cannot start or end with underscore or period.');
      return;
    }
    // No consecutive special chars (.. or __)
    if (RegExp(r'[_.]{2,}').hasMatch(username)) {
      setState(() => _registerError = 'Username cannot have consecutive periods or underscores.');
      return;
    }
    if (_usernameValidationError != null) {
      setState(() => _registerError = _usernameValidationError);
      return;
    }
    final isUsernameTaken = await SupabaseService.isUsernameRegistered(username);
    if (isUsernameTaken) {
      setState(() => _registerError = 'This username is already taken. Please choose another.');
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (email.isEmpty) {
      setState(() => _registerError = 'Please enter your email address.');
      return;
    }
    if (!emailRegex.hasMatch(email)) {
      setState(() => _registerError = 'Please enter a valid email address (e.g. name@example.com).');
      return;
    }

    if (_emailValidationError != null) {
      setState(() => _registerError = _emailValidationError);
      return;
    }
    final isEmailTaken = await SupabaseService.isEmailRegistered(email);
    if (isEmailTaken) {
      setState(() => _registerError = 'This email address is already registered.');
      return;
    }

    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _registerError = 'Password is required.');
      return;
    }
    if (password.length < 8) {
      setState(() => _registerError = 'Password must be at least 8 characters.');
      return;
    }
    if (password.length > 64) {
      setState(() => _registerError = 'Password must not exceed 64 characters.');
      return;
    }
    if (password.contains(' ')) {
      setState(() => _registerError = 'Password must not contain spaces.');
      return;
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      setState(() => _registerError = 'Password must contain at least one uppercase letter (A-Z).');
      return;
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      setState(() => _registerError = 'Password must contain at least one lowercase letter (a-z).');
      return;
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      setState(() => _registerError = 'Password must contain at least one number (0-9).');
      return;
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>\-_=+\\[\]~`/]').hasMatch(password)) {
      setState(() => _registerError = 'Password must contain at least one special character.');
      return;
    }
    // Must not contain username (case-insensitive)
    if (password.toLowerCase().contains(username.toLowerCase())) {
      setState(() => _registerError = 'Password must not contain your username.');
      return;
    }
    // Must not contain email local part (before @)
    final emailLocal = email.split('@').first;
    if (emailLocal.isNotEmpty && password.toLowerCase().contains(emailLocal.toLowerCase())) {
      setState(() => _registerError = 'Password must not contain your email address.');
      return;
    }
    if (password != _confirmPasswordController.text) {
      setState(() => _registerError = 'Passwords do not match.');
      return;
    }

    final normFirst = _normalizeName(_firstNameController.text);
    final normMiddle = _middleNameController.text.trim().isNotEmpty
        ? _normalizeName(_middleNameController.text)
        : '';
    final normLast = _normalizeName(_lastNameController.text);
    final fullName = [
      normFirst,
      if (normMiddle.isNotEmpty) normMiddle,
      normLast,
      if (_selectedSuffix != null && _selectedSuffix!.isNotEmpty) _selectedSuffix!,
    ].join(' ');

    final normalizedPhone = _normalizePhPhone(_contactController.text);
    final targetPosition = _selectedPosition;

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
              driverLicenseNumber: _selectedPosition == 'Driver' ? (_photoLicenseResult?.licenseNumber ?? '') : '',
              driverLicenseExpiry: _selectedPosition == 'Driver' ? (_photoLicenseResult?.expiryDate ?? '') : '',
              isLicenseVerified: _selectedPosition == 'Driver' && _photoLicenseResult?.isValid == true,
              isEmailVerified: true,
              isPhoneVerified: false,
              firstName: normFirst,
              middleName: normMiddle,
              lastName: normLast,
            );

            if (error == null) {
              await _clearFormCache();
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

              // Submission Error Banner (on final step)
              if (_currentStep == _finalStepIndex && _registerError != null) ...[
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
    if (_isDriver) {
      switch (_currentStep) {
        case 0:
          return 'Step 1 of 4: Personal Details';
        case 1:
          return 'Step 2 of 4: Driver\'s License';
        case 2:
          return 'Step 3 of 4: Home Address';
        case 3:
          return 'Step 4 of 4: Account Credentials';
        default:
          return '';
      }
    } else {
      switch (_currentStep) {
        case 0:
          return 'Step 1 of 3: Personal Details';
        case 1:
          return 'Step 2 of 3: Home Address';
        case 2:
          return 'Step 3 of 3: Account Credentials';
        default:
          return '';
      }
    }
  }

  /// Matches LoginScreen field typography so labels stay readable
  /// instead of overflowing in compact register rows.
  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      errorStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.error,
      ),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
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
    final steps = _stepTitles;

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
                margin: EdgeInsets.symmetric(horizontal: _isDriver ? 4 : 6),
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
                  width: _isDriver ? 18 : 20,
                  height: _isDriver ? 18 : 20,
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
                        ? Icon(Icons.check, size: _isDriver ? 10 : 11, color: Colors.white)
                        : Text(
                            '${stepIndex + 1}',
                            style: TextStyle(
                              fontSize: _isDriver ? 9 : 10,
                              fontWeight: FontWeight.w800,
                              color: isCurrent ? Colors.white : const Color(0xFF7A6556),
                            ),
                          ),
                  ),
                ),
                SizedBox(width: _isDriver ? 4 : 6),
                Text(
                  steps[stepIndex],
                  style: TextStyle(
                    fontSize: _isDriver ? 10.5 : 11.5,
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
    if (_isDriver) {
      switch (_currentStep) {
        case 0:
          return _buildStep1Personal();
        case 1:
          return _buildStepDriverLicense();
        case 2:
          return _buildStepAddress();
        case 3:
          return _buildStep3Account();
        default:
          return const SizedBox.shrink();
      }
    } else {
      switch (_currentStep) {
        case 0:
          return _buildStep1Personal();
        case 1:
          return _buildStepAddress();
        case 2:
          return _buildStep3Account();
        default:
          return const SizedBox.shrink();
      }
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE8DED3)),
          ),
          child: Row(
            children: const [
              Icon(Icons.badge_outlined, size: 18, color: Color(0xFF8B4513)),
              SizedBox(width: 8),
              Text(
                'Role: Staff',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF24140B),
                ),
              ),
            ],
          ),
        ),
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
            DropdownMenuItem(value: 'Production Cook', child: Text('Production Cook')),
            DropdownMenuItem(value: 'Production Meat Cutter', child: Text('Production Meat Cutter')),
            DropdownMenuItem(value: 'Driver', child: Text('Driver')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                final wasDriver = _selectedPosition == 'Driver';
                _selectedPosition = val;
                _stepError = null;
                // Reset license data when switching away from Driver
                if (wasDriver && val != 'Driver') {
                  _licenseImageBytes = null;
                  _photoLicenseResult = null;
                }
              });
              _onFieldChanged();
            }
          },
        ),
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
                onChanged: (value) {
                  setState(() => _selectedSuffix = value);
                  _onFieldChanged();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        const Text('BIRTHDATE & CONTACT', style: _sectionLabelStyle),
        const SizedBox(height: 8),
        InkWell(
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
        const SizedBox(height: 16),
        TextFormField(
          controller: _contactController,
          focusNode: _contactFocusNode,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          maxLength: 11,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          style: _fieldTextStyle,
          decoration: _fieldDecoration(
            label: 'Mobile Number',
            hint: '09XXXXXXXXX',
            prefixIcon: const Icon(Icons.phone_iphone_outlined, size: 19),
            suffixIcon: _isCheckingPhone
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                    ),
                  )
                : (_phoneValidationError != null
                    ? const Icon(Icons.error_outline, size: 19, color: AppColors.error)
                    : null),
            errorText: _phoneValidationError,
          ).copyWith(counterText: ''),
        ),
      ],
    );
  }


  // ─────────────────────────────────────────────────────────────
  // DRIVER LICENSE STEP (Driver Step 2)
  // ─────────────────────────────────────────────────────────────
  Widget _buildStepDriverLicense() {
    return Column(
      key: const ValueKey('step_driver_license'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('DRIVER\'S LICENSE', style: _sectionLabelStyle),
        const SizedBox(height: 4),
        const Text(
          'Take or upload a clear photo of your Driver\'s License. It will be verified via AI.',
          style: TextStyle(fontSize: 13, color: Color(0xFF7A6556), height: 1.35),
        ),
        const SizedBox(height: 12),

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
                        height: 140,
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
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ADDRESS STEP (Staff Step 2 / Driver Step 3)
  // ─────────────────────────────────────────────────────────────
  Widget _buildStepAddress() {
    return Column(
      key: const ValueKey('step_address'),
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
          focusNode: _usernameFocusNode,
          textInputAction: TextInputAction.next,
          style: _fieldTextStyle,
          decoration: _fieldDecoration(
            label: 'Username',
            hint: 'Choose a login username',
            prefixIcon: const Icon(Icons.alternate_email_rounded, size: 19),
            suffixIcon: _isCheckingUsername
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                    ),
                  )
                : (_usernameValidationError != null
                    ? const Icon(Icons.error_outline, size: 19, color: AppColors.error)
                    : null),
            errorText: _usernameValidationError,
          ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: _fieldTextStyle,
          decoration: _fieldDecoration(
            label: 'Email Address',
            hint: 'name@example.com',
            prefixIcon: const Icon(Icons.email_outlined, size: 19),
            suffixIcon: _isCheckingEmail
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                    ),
                  )
                : (_emailValidationError != null
                    ? const Icon(Icons.error_outline, size: 19, color: AppColors.error)
                    : null),
            errorText: _emailValidationError,
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
      final nextLabel = _isDriver ? 'Continue to License' : 'Continue to Address';
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
          child: Text(
            nextLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              letterSpacing: 0.3,
            ),
          ),
        ),
      );
    }

    if (_currentStep < _finalStepIndex) {
      String nextLabel = 'Continue';
      if (_isDriver) {
        if (_currentStep == 1) nextLabel = 'Continue to Address';
        if (_currentStep == 2) nextLabel = 'Continue to Account';
      } else {
        if (_currentStep == 1) nextLabel = 'Continue to Account';
      }

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
                child: Text(
                  nextLabel,
                  style: const TextStyle(
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

    // Final step submission (_currentStep == _finalStepIndex)
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
