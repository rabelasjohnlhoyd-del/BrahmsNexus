import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/address_edit_dialog.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/user_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  String _fullName = 'Driver Partner';
  String _initials = 'DR';
  String _age = 'Not set';
  String _currentAddress = '';
  String _driverLicense = 'Not registered';
  String _currentPhotoUrl = '';
  
  String _currentPhone = '';
  String _currentEmail = '';
  String _currentUsername = '';

  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _usernameController;

  final ImagePicker _picker = ImagePicker();
  String? _editingField; 
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentAppUser;
    if (user != null) {
      if (user.fullName.isNotEmpty) _fullName = user.fullName;
      _initials = user.initials;
      if (user.contactNumber.isNotEmpty) _currentPhone = user.contactNumber;
      if (user.username.isNotEmpty) _currentUsername = user.username;
      _currentEmail = user.email.isNotEmpty
          ? user.email
          : '${user.username}@brahmsnexus.ph';
      if (user.age.isNotEmpty) _age = '${user.age} yrs old';
      if (user.address.isNotEmpty) _currentAddress = user.address;
      if (user.photoUrl.isNotEmpty) _currentPhotoUrl = user.photoUrl;
      if (user.driverLicenseNumber.isNotEmpty) {
        _driverLicense = user.isLicenseVerified
            ? '${user.driverLicenseNumber} (LTO Verified)'
            : user.driverLicenseNumber;
      }
    }
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

  String _normalizePhPhone(String phone) {
    var p = phone.trim().replaceAll(RegExp(r'[\s\-]'), '');
    if (p.startsWith('+639')) {
      p = '09${p.substring(4)}';
    }
    return p;
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

  Future<void> _pickProfilePhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 75,
      );
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      // Show Confirmation Dialog with Preview
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogCtx) => CupertinoAlertDialog(
          title: const Text('Confirm Profile Photo'),
          content: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentDark.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.memory(
                    bytes,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Gusto mo bang gamitin ang litratong ito bilang iyong bagong profile picture?',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Save Photo'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      setState(() => _isUploadingPhoto = true);
      final user = AuthService.currentAppUser;
      final userId = user?.uid ?? 'user_${DateTime.now().millisecondsSinceEpoch}';

      final uploadedUrl = await SupabaseService.uploadProfilePhoto(
        userId: userId,
        bytes: bytes,
        extension: 'jpg',
      );

      if (!mounted) return;
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        setState(() {
          _currentPhotoUrl = uploadedUrl;
          _isUploadingPhoto = false;
        });
        // Auto-save photoUrl to Firestore and Supabase
        await AuthService.updateProfile(photoUrl: uploadedUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Matagumpay na na-save ang iyong profile picture!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        setState(() => _isUploadingPhoto = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update photo: $e')),
        );
      }
    }
  }

  void _showPhotoOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Profile Photo'),
        message: const Text('Choose an option to update your profile photo on Brahms Nexus'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickProfilePhoto(ImageSource.camera);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.camera, size: 20),
                SizedBox(width: 8),
                Text('Take Photo'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickProfilePhoto(ImageSource.gallery);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo, size: 20),
                SizedBox(width: 8),
                Text('Choose from Gallery'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _openAddressEditor() async {
    final updatedAddress = await AddressEditDialog.show(
      context,
      initialAddress: _currentAddress,
    );
    if (updatedAddress != null && updatedAddress.trim().isNotEmpty) {
      setState(() {
        _currentAddress = updatedAddress.trim();
        _editingField = 'address'; // Trigger bottom save bar
      });
    }
  }

  void _confirmEdit(String field) {
    if (field == 'address') {
      _openAddressEditor();
      return;
    }

    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Are you sure you want to edit your information?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(dialogCtx);
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
      _currentAddress = AuthService.currentAppUser?.address ?? _currentAddress;
    });
  }

  void _confirmSave() {
    // Validate Phone format first if phone was edited
    final rawPhone = _phoneController.text.trim();
    final phoneErr = _validatePhilippinePhone(rawPhone);
    if (phoneErr != null) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Invalid Contact Number'),
          content: Text(phoneErr),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Save Changes?'),
        content: const Text('Are you sure you want to save these updates to your profile? This will synchronize with Supabase in real time.'),
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
    final normalizedPhone = _normalizePhPhone(_phoneController.text.trim());
    final newUsername = _usernameController.text.trim();
    final newEmail = _emailController.text.trim();
    final newAddress = _currentAddress.trim();

    await AuthService.updateProfile(
      username: newUsername,
      contactNumber: normalizedPhone,
      email: newEmail,
      address: newAddress,
      photoUrl: _currentPhotoUrl,
    );

    if (!mounted) return;
    setState(() {
      _currentPhone = normalizedPhone;
      _phoneController.text = normalizedPhone;
      _currentEmail = newEmail;
      _currentUsername = newUsername;
      _currentAddress = newAddress;
      _isSaving = false;
      _editingField = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAnyEditing = _editingField != null;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Edit Profile',
        showBackButton: true,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // --- PROFILE PHOTO SECTION ---
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            UserAvatar(
                              initials: _initials,
                              photoUrl: _currentPhotoUrl,
                              size: 100,
                              fontSize: 34,
                              onTap: _showPhotoOptions,
                            ),
                            if (_isUploadingPhoto)
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: CupertinoColors.black.withValues(alpha: 0.5),
                                ),
                                child: const Center(
                                  child: CupertinoActivityIndicator(color: CupertinoColors.white, radius: 14),
                                ),
                              ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: _showPhotoOptions,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentDark,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: CupertinoColors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: CupertinoColors.black.withValues(alpha: 0.2),
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.camera_fill,
                                    size: 16,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _showPhotoOptions,
                          child: const Text(
                            'Change Profile Photo',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const StaffSectionHeader(
                    label: 'Personal Information',
                    icon: CupertinoIcons.person_crop_circle_fill,
                    large: true,
                    subtitle: 'Manage your personal and contact details',
                  ),
                  const SizedBox(height: 16),
                  StaffCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _infoRow(label: 'Full Name', value: _fullName),
                        _divider(),
                        _infoRow(label: 'Age', value: _age),
                        _divider(),

                        // --- ADDRESS WITH DROPDOWN SELECTOR ---
                        _addressRow(
                          label: 'Residential Address',
                          value: _currentAddress.isNotEmpty ? _currentAddress : 'Not set',
                        ),
                        _divider(),

                        // --- CONTACT NUMBER WITH PH FORMAT VALIDATION ---
                        _editableRow(
                          label: 'Philippine Mobile Number', 
                          value: _currentPhone,
                          controller: _phoneController,
                          fieldName: 'phone',
                          keyboardType: TextInputType.phone,
                          placeholder: '09XX XXX XXXX',
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

                  const SizedBox(height: 20),
                  const StaffSectionHeader(
                    label: 'Driver Credentials',
                    icon: CupertinoIcons.doc_text_fill,
                    subtitle: 'Official LTO documents',
                  ),
                  const SizedBox(height: 12),
                  StaffCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _infoRow(label: "Driver's License", value: _driverLicense),
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

  Widget _addressRow({required String label, required String value}) {
    final bool isAddressModified = _editingField == 'address';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isAddressModified ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: _openAddressEditor,
                child: const Row(
                  children: [
                    Text('Select / Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.accent)),
                    SizedBox(width: 4),
                    Icon(CupertinoIcons.pencil, size: 14, color: AppColors.accent),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
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
    String? placeholder,
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
                  minimumSize: Size.zero,
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
              placeholder: placeholder,
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
