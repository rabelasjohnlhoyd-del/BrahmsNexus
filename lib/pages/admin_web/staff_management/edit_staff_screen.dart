import 'package:flutter/material.dart';
import '../../../models/staff_member.dart';
import '../admin_web_colors.dart';
import '../../../widgets/primary_button.dart';

/// Form used by the Administrator to update an EXISTING staff/employee
/// account's profile details. This completes the "Update" part of CRUD
/// for Staff Management (Create = AddStaffScreen, Read = the list +
/// search, Update = this screen, Delete/Archive = Remove + Deactivate
/// on the list itself).
///
/// Does NOT change the password — resetting credentials is a separate
/// concern from editing profile details, and is out of scope here.
///
/// Front-end only for now: on submit this simply builds an updated
/// [StaffMember] locally and returns it via Navigator.pop(). Once
/// Firebase/Supabase are wired up, this will write the update instead.
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

    // The branch might not be one of the current kBranchOptions if it
    // was entered as "Other" previously — fall back to "Other" so the
    // existing value isn't silently lost.
    if (kBranchOptions.contains(m.branch)) {
      _selectedBranch = m.branch;
      _otherBranchController = TextEditingController();
    } else {
      _selectedBranch = 'Other';
      _otherBranchController = TextEditingController(text: m.branch);
    }
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
    if (trimmed.isEmpty) return null; // optional field
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(trimmed)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null; // optional field
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

    setState(() => _isSaving = true);

    // NOTE: front-end simulation only — replace with a real
    // Firebase/Supabase update call once the backend is wired up.
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    final branch = _selectedBranch == 'Other'
        ? _otherBranchController.text.trim()
        : _selectedBranch!;

    // Built directly (not via copyWith) so clearing an optional field
    // (email/phone) to blank is respected instead of falling back to
    // the old value.
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

    setState(() => _isSaving = false);
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Staff Account'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Account Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AdminWebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Update this staff member\'s profile details. Password is '
                'not changed here.',
                style:
                    TextStyle(fontSize: 13, color: AdminWebColors.textSecondary),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _fullNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: _validateFullName,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  helperText: 'Used for logging in. No spaces.',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: _validateUsername,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: _validatePhone,
              ),

              const SizedBox(height: 24),
              const Text(
                'Assignment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AdminWebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _selectedBranch,
                decoration: const InputDecoration(
                  labelText: 'Branch',
                  prefixIcon: Icon(Icons.store_mall_directory_outlined),
                ),
                items: [
                  ...kBranchOptions.map(
                    (branch) =>
                        DropdownMenuItem(value: branch, child: Text(branch)),
                  ),
                  const DropdownMenuItem(
                    value: 'Other',
                    child: Text('Other'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _selectedBranch = value);
                },
                validator: _validateBranch,
              ),

              if (_selectedBranch == 'Other') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _otherBranchController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Specify Branch Name',
                    prefixIcon: Icon(Icons.edit_location_alt_outlined),
                  ),
                  validator: _validateOtherBranch,
                ),
              ],
              const SizedBox(height: 16),

              TextFormField(
                controller: _positionController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Position',
                  hintText: 'e.g., Cashier, Cook, Delivery Staff',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                validator: _validatePosition,
              ),
              const SizedBox(height: 12),

              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
                activeThumbColor: AdminWebColors.accent,
                title: const Text(
                  'Active Account',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AdminWebColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Inactive staff cannot log in until reactivated.',
                  style:
                      TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
                ),
              ),

              const SizedBox(height: 28),
              PrimaryButton(
                label: 'SAVE CHANGES',
                icon: Icons.save_outlined,
                isLoading: _isSaving,
                onPressed: _handleSave,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
