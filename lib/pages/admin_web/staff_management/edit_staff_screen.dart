import 'package:flutter/material.dart';
import '../../../models/staff_member.dart';
import '../../../services/rate_limiter.dart';
import '../../../widgets/address_edit_dialog.dart';
import '../admin_web_widgets/glass_card.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';

/// Form used by the Administrator to update an EXISTING staff/employee
/// account's profile details.
class EditStaffScreen extends StatefulWidget {
  const EditStaffScreen({super.key, required this.member});

  final StaffMember member;

  @override
  State<EditStaffScreen> createState() => _EditStaffScreenState();
}

class _EditStaffScreenState extends State<EditStaffScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _birthdateController;
  late final TextEditingController _ageController;
  late final TextEditingController _addressController;
  late final TextEditingController _otherBranchController;

  DateTime? _selectedBirthdate;
  String? _selectedBranch;
  String? _selectedPosition;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _firstNameController = TextEditingController(text: m.firstName);
    _middleNameController = TextEditingController(text: m.middleName);
    _lastNameController = TextEditingController(text: m.lastName);
    _usernameController = TextEditingController(text: m.username);
    _emailController = TextEditingController(text: m.email ?? '');
    _phoneController = TextEditingController(text: m.phone ?? '');
    _ageController = TextEditingController(text: m.age);
    _birthdateController = TextEditingController();
    _addressController = TextEditingController(text: m.address);
    _selectedPosition = m.position;
    _isActive = m.isActive;

    if (kBranchOptions.contains(m.branch)) {
      _selectedBranch = m.branch;
      _otherBranchController = TextEditingController();
    } else {
      _selectedBranch = 'Other';
      _otherBranchController = TextEditingController(text: m.branch);
    }
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setTitle('STAFF MANAGEMENT');
    shell?.setActions([]);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthdateController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _otherBranchController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String fieldName) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '$fieldName is required';
    if (fieldName.toLowerCase().contains('name')) {
      if (trimmed.length < 2) return '$fieldName must be at least 2 characters';
      if (trimmed.length > 50) return '$fieldName must not exceed 50 characters';
      final namePattern = RegExp(r"^[a-zA-ZñÑáéíóúÁÉÍÓÚ\s\-'.]+$");
      if (!namePattern.hasMatch(trimmed)) {
        return '$fieldName must contain only letters';
      }
    }
    if (fieldName.toLowerCase().contains('address')) {
      if (trimmed.length < 5) return '$fieldName must be at least 5 characters';
      if (trimmed.length > 150) return '$fieldName must not exceed 150 characters';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Username is required';
    if (trimmed.length < 4) return 'Username must be at least 4 characters';
    if (trimmed.length > 20) return 'Username must not exceed 20 characters';
    if (trimmed.contains(' ')) return 'Username cannot contain spaces';
    if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(trimmed)) {
      return 'Use letters, numbers, dots, or underscores only';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Email address is required';
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(trimmed)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Phone number is required';
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 12) {
      return 'Enter a valid phone number (7 to 12 digits, e.g. 0917 123 4567)';
    }
    final phRegex = RegExp(r'^(09|\+639)\d{9}$');
    if (digits.length >= 10 && !phRegex.hasMatch(trimmed.replaceAll(RegExp(r'[\s\-]'), ''))) {
      return 'Enter a valid Philippine mobile number (e.g. 0917 123 4567)';
    }
    return null;
  }

  String? _validatePosition(String? value) {
    if (value == null || value.isEmpty) return 'Position is required';
    return null;
  }

  String? _validateBranch(String? value) {
    if (value == null || value.isEmpty) return 'Please select a branch';
    return null;
  }

  String? _validateOtherBranch(String? value) {
    if (_selectedBranch != 'Other') return null;
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Please specify the branch name';
    return null;
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final initialDate = _selectedBirthdate ?? DateTime(now.year - 20, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 15, now.month, now.day),
    );

    if (picked != null) {
      setState(() {
        _selectedBirthdate = picked;
        _birthdateController.text = '${picked.month}/${picked.day}/${picked.year}';
        int calculatedAge = now.year - picked.year;
        if (now.month < picked.month || (now.month == picked.month && now.day < picked.day)) {
          calculatedAge--;
        }
        _ageController.text = calculatedAge.toString();
      });
    }
  }

  Future<void> _pickAddress() async {
    final selected = await AddressEditDialog.show(context, initialAddress: _addressController.text);
    if (selected != null && selected.isNotEmpty) {
      setState(() {
        _addressController.text = selected;
      });
    }
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the highlighted fields.')),
      );
      return;
    }

    // Rate limit: prevent rapid repeated profile updates
    if (!RateLimiter.tryAction(
      key: 'admin_edit_staff',
      cooldown: const Duration(seconds: 15),
    )) {
      final secs = RateLimiter.remainingCooldownSeconds('admin_edit_staff');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please wait $secs second(s) before saving again.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _updateShellActions();
    });

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    final branch = _selectedBranch == 'Other'
        ? _otherBranchController.text.trim()
        : _selectedBranch!;

    final updated = StaffMember(
      id: widget.member.id,
      firstName: _firstNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      username: _usernameController.text.trim(),
      branch: branch,
      position: _selectedPosition!,
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      age: _ageController.text.trim(),
      address: _addressController.text.trim(),
      isActive: _isActive,
      isArchived: widget.member.isArchived,
      dateAdded: widget.member.dateAdded,
    );

    setState(() {
      _isSaving = false;
      _updateShellActions();
    });
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Back Button Header
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: AdminWebColors.textPrimary),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Back to Staff List',
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'BACK TO STAFF LIST',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AdminWebColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACCOUNT INFORMATION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AdminWebColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _firstNameController,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'FIRST NAME *',
                                  isDense: true,
                                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                                ),
                                validator: (v) => _validateRequired(v, 'First name'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: _middleNameController,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'M.I. (OPTIONAL)',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _lastNameController,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'LAST NAME *',
                                  isDense: true,
                                ),
                                validator: (v) => _validateRequired(v, 'Last name'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _usernameController,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                decoration: const InputDecoration(
                                  labelText: 'USERNAME *',
                                  isDense: true,
                                  helperText: 'Used for logging in. No spaces.',
                                  prefixIcon: Icon(Icons.person_outline, size: 20),
                                ),
                                validator: _validateUsername,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'EMAIL *',
                                  isDense: true,
                                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                                ),
                                validator: _validateEmail,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'PHONE NUMBER *',
                                  isDense: true,
                                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                                ),
                                validator: _validatePhone,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _birthdateController,
                                readOnly: true,
                                onTap: _pickBirthdate,
                                decoration: InputDecoration(
                                  labelText: 'BIRTHDATE',
                                  hintText: 'Select birthdate',
                                  isDense: true,
                                  prefixIcon: const Icon(Icons.calendar_month_outlined, size: 20),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                                    onPressed: _pickBirthdate,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: _ageController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'AGE *',
                                  isDense: true,
                                  prefixIcon: Icon(Icons.cake_outlined, size: 20),
                                ),
                                validator: (v) => _validateRequired(v, 'Age'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _addressController,
                          readOnly: true,
                          onTap: _pickAddress,
                          decoration: InputDecoration(
                            labelText: 'HOME ADDRESS *',
                            hintText: 'Click to choose Philippine Address API',
                            isDense: true,
                            prefixIcon: const Icon(Icons.home_outlined, size: 20),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.edit_location_alt_outlined, size: 20),
                              onPressed: _pickAddress,
                            ),
                          ),
                          validator: (v) => _validateRequired(v, 'Home address'),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ASSIGNMENT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AdminWebColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedBranch,
                                decoration: const InputDecoration(
                                  labelText: 'BRANCH',
                                  isDense: true,
                                  prefixIcon: Icon(Icons.store_mall_directory_outlined, size: 20),
                                ),
                                items: [
                                  ...kBranchOptions.map(
                                    (branch) => DropdownMenuItem(
                                        value: branch, child: Text(branch.toUpperCase())),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'Other',
                                    child: Text('OTHER'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() => _selectedBranch = value);
                                },
                                validator: _validateBranch,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedPosition,
                                decoration: const InputDecoration(
                                  labelText: 'POSITION',
                                  isDense: true,
                                  prefixIcon: Icon(Icons.work_outline, size: 20),
                                ),
                                items: kPositionOptions
                                    .map((pos) => DropdownMenuItem(
                                          value: pos,
                                          child: Text(pos.toUpperCase()),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() => _selectedPosition = value);
                                },
                                validator: _validatePosition,
                              ),
                            ),
                          ],
                        ),
                        if (_selectedBranch == 'Other') ...[
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _otherBranchController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'SPECIFY BRANCH NAME',
                              isDense: true,
                              prefixIcon: Icon(Icons.edit_location_alt_outlined, size: 20),
                            ),
                            validator: _validateOtherBranch,
                          ),
                        ],
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _isActive,
                          onChanged: (value) => setState(() => _isActive = value),
                          activeThumbColor: AdminWebColors.accent,
                          activeTrackColor: AdminWebColors.accent.withValues(alpha: 0.3),
                          thumbColor: WidgetStateProperty.resolveWith<Color?>(
                            (states) => states.contains(WidgetState.selected)
                                ? Colors.white
                                : null,
                          ),
                          title: const Text(
                            'ACTIVE ACCOUNT',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AdminWebColors.textPrimary,
                            ),
                          ),
                          subtitle: const Text(
                            'Inactive staff cannot log in until reactivated.',
                            style: TextStyle(
                                fontSize: 12, color: AdminWebColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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
                            : const Icon(Icons.save_outlined, size: 18),
                        label: const Text('SAVE CHANGES'),
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
