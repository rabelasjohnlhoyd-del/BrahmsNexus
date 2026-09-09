import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final String _fullName = 'Ramon Santos';
  final String _age = '32';
  final String _address = 'San Francisco, Victoria';
  
  String _currentPhone = '+63 917 555 8899';
  String _currentEmail = 'ramon.santos@brahms.ph';
  String _currentUsername = 'ramon.driver';

  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _usernameController;

  String? _editingField; 
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: _currentPhone);
    _emailController = TextEditingController(text: _currentEmail);
    _usernameController = TextEditingController(text: _currentUsername);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _confirmEdit(String field) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Are you sure you want to edit your information?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              setState(() => _editingField = field);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _confirmCancelEditing() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('Are you sure you want to cancel? Any unsaved changes will be lost.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _cancelEditing();
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _cancelEditing() {
    setState(() {
      _editingField = null;
      _phoneController.text = _currentPhone;
      _emailController.text = _currentEmail;
      _usernameController.text = _currentUsername;
    });
  }

  void _confirmSave() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Save Changes?'),
        content: const Text('Are you sure you want to save these updates to your profile?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              _handleSave();
            },
            child: const Text('Yes, Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() {
      _currentPhone = _phoneController.text;
      _currentEmail = _emailController.text;
      _currentUsername = _usernameController.text;
      _isSaving = false;
      _editingField = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAnyEditing = _editingField != null;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Profile Settings',
        showBackButton: true,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const StaffSectionHeader(
                    label: 'Personal Information',
                    icon: CupertinoIcons.person_crop_circle_fill,
                    large: true,
                    subtitle: 'Manage your account details',
                  ),
                  const SizedBox(height: 20),
                  StaffCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _infoRow(label: 'Full Name', value: _fullName),
                        _divider(),
                        _infoRow(label: 'Age', value: _age),
                        _divider(),
                        _infoRow(label: 'Address', value: _address),
                        _divider(),
                        _editableRow(
                          label: 'Contact Number', 
                          value: _currentPhone,
                          controller: _phoneController,
                          fieldName: 'phone',
                          keyboardType: TextInputType.phone,
                        ),
                        _divider(),
                        _editableRow(
                          label: 'Email', 
                          value: _currentEmail,
                          controller: _emailController,
                          fieldName: 'email',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        _divider(),
                        _editableRow(
                          label: 'Username', 
                          value: _currentUsername,
                          controller: _usernameController,
                          fieldName: 'username',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            if (isAnyEditing)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, -5)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: StaffButton(
                        label: _isSaving ? 'Saving...' : 'Save Changes',
                        onPressed: _isSaving ? null : _confirmSave,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _isSaving ? null : _confirmCancelEditing,
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 16)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _editableRow({
    required String label, 
    required String value, 
    required TextEditingController controller,
    required String fieldName,
    TextInputType? keyboardType,
  }) {
    final bool isEditingThis = _editingField == fieldName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(
                fontSize: 13, 
                fontWeight: FontWeight.w700, 
                color: isEditingThis ? AppColors.accent : AppColors.textSecondary
              )),
              if (!isEditingThis)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () => _confirmEdit(fieldName),
                  child: const Row(
                    children: [
                      Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.accent)),
                      SizedBox(width: 4),
                      Icon(CupertinoIcons.pencil, size: 14, color: AppColors.accent),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (isEditingThis)
            CupertinoTextField(
              controller: controller,
              autofocus: true,
              keyboardType: keyboardType,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.accent, width: 1.5)),
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            )
          else
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        margin: const EdgeInsets.only(left: 16),
        height: 0.5,
        color: AppColors.border.withValues(alpha: 0.4),
      );
}
