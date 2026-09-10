import 'package:flutter/material.dart';
import '../../../models/staff_member.dart';
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
  late final TextEditingController _ageController;
  late final TextEditingController _addressController;
  late final TextEditingController _otherBranchController;

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
    shell?.setTitle('EDIT STAFF: ${widget.member.fullName.toUpperCase()}');
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
    _ageController.dispose();
    _addressController.dispose();
    _otherBranchController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String fieldName) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '$fieldName is required';
    return null;
  }

  String? _validateUsername(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Username is required';
    if (trimmed.length < 4) return 'Username must be at least 4 characters';
    if (trimmed.contains(' ')) return 'Username cannot contain spaces';
    if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(trimmed)) {
      return 'Use letters, numbers, dots, or underscores only';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(trimmed)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (!RegExp(r'^[0-9+\-\s]{7,14}$').hasMatch(trimmed)) {
      return 'Enter a valid phone number';
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

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the highlighted fields.')),
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
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
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
                  const SizedBox(height: 20),
                  
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
                                  labelText: 'FIRST NAME',
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
                                  labelText: 'LAST NAME',
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
                                  labelText: 'USERNAME',
                                  isDense: true,
                                  helperText: 'Used for logging in. No spaces.',
                                  prefixIcon: Icon(Icons.person_outline, size: 20),
                                ),
                                validator: _validateUsername,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Spacer(),
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
                                  labelText: 'EMAIL (OPTIONAL)',
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
                                  labelText: 'PHONE NUMBER (OPTIONAL)',
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
                              flex: 1,
                              child: TextFormField(
                                controller: _ageController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'AGE',
                                  isDense: true,
                                  prefixIcon: Icon(Icons.cake_outlined, size: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _addressController,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'HOME ADDRESS',
                                  isDense: true,
                                  prefixIcon: Icon(Icons.home_outlined, size: 20),
                                ),
                              ),
                            ),
                          ],
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
                                value: _selectedPosition,
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
                          activeColor: AdminWebColors.accent,
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

