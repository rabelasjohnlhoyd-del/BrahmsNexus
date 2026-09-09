import 'package:flutter/material.dart';
import '../../../models/staff_member.dart';
import '../admin_web_widgets/glass_card.dart';
import '../../../widgets/primary_button.dart';
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

  late final TextEditingController _fullNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _positionController;
  late final TextEditingController _otherBranchController;

  String? _selectedBranch;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _fullNameController = TextEditingController(text: m.fullName);
    _usernameController = TextEditingController(text: m.username);
    _emailController = TextEditingController(text: m.email ?? '');
    _phoneController = TextEditingController(text: m.phone ?? '');
    _positionController = TextEditingController(text: m.position);
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
    shell?.setActions([
      TextButton(
        onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        child: const Text('CANCEL', style: TextStyle(color: Colors.white)),
      ),
      ElevatedButton.icon(
        onPressed: _isSaving ? null : _handleSave,
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.save_outlined, size: 18, color: Colors.white),
        label: const Text('SAVE CHANGES'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.15),
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          elevation: 0,
        ),
      ),
    ]);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _otherBranchController.dispose();
    super.dispose();
  }

  String? _validateFullName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Full name is required';
    if (trimmed.length < 2) return 'Enter a valid full name';
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
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Position is required';
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
      fullName: _fullNameController.text.trim(),
      username: _usernameController.text.trim(),
      branch: branch,
      position: _positionController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      isActive: _isActive,
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
                              child: TextFormField(
                                controller: _fullNameController,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'FULL NAME',
                                  isDense: true,
                                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                                ),
                                validator: _validateFullName,
                              ),
                            ),
                            const SizedBox(width: 16),
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
                                value: _selectedBranch,
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
                              child: TextFormField(
                                controller: _positionController,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                  labelText: 'POSITION',
                                  isDense: true,
                                  hintText: 'e.g., Cashier, Cook',
                                  prefixIcon: Icon(Icons.work_outline, size: 20),
                                ),
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
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _isActive,
                          onChanged: (value) => setState(() => _isActive = value),
                          activeColor: AdminWebColors.accent,
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
                            style: TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
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
