import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';
import '../../widgets/staff_dialog.dart';
import '../../services/auth_service.dart';
import '../../models/app_user.dart';
import '../auth/login_screen.dart';

/// Profile tab of the Owner App — displays the owner's account
/// credentials, administrative privileges, operational settings,
/// and log out action.
class OwnerProfileScreen extends StatefulWidget {
  const OwnerProfileScreen({super.key});

  @override
  State<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  bool _isEditing = false;

  // Defaults
  String _fullName = 'Business Owner';
  String _age = 'Not set';
  String _address = 'Not set';
  String _contact = '';
  String _email = 'owner@brahmsnexus.ph';
  String _username = 'owner';

  late TextEditingController _contactController;
  late TextEditingController _emailController;
  late TextEditingController _usernameController;

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentAppUser;
    if (user != null) {
      if (user.fullName.isNotEmpty) _fullName = user.fullName;
      if (user.contactNumber.isNotEmpty) _contact = user.contactNumber;
      if (user.username.isNotEmpty) {
        _username = user.username;
      }
      _email = user.email.isNotEmpty
          ? user.email
          : '${user.username.isNotEmpty ? user.username : 'owner'}@brahmsnexus.ph';
      if (user.age.isNotEmpty) _age = '${user.age} yrs old';
      if (user.address.isNotEmpty) _address = user.address;
    }
    _contactController = TextEditingController(text: _contact);
    _emailController = TextEditingController(text: _email);
    _usernameController = TextEditingController(text: _username);
  }

  @override
  void dispose() {
    _contactController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _confirmLogout() {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out from the Owner app?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await AuthService.signOut();
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  CupertinoPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleEditToggle() async {
    if (!_isEditing) {
      final confirm = await StaffDialog.confirm(
        context,
        title: 'Edit Account Details',
        message: 'Are you sure you want to edit your account details?',
        icon: CupertinoIcons.pencil,
        confirmLabel: 'Edit',
      );
      if (confirm) setState(() => _isEditing = true);
    } else {
      // Handled by Discard / Save buttons
    }
  }

  Future<void> _discardChanges() async {
    final confirm = await StaffDialog.confirm(
      context,
      title: 'Discard Changes',
      message: 'Are you sure you want to discard your changes?',
      icon: CupertinoIcons.xmark_circle,
      isDestructive: true,
      confirmLabel: 'Discard',
    );
    if (confirm) {
      setState(() {
        _isEditing = false;
        _contactController.text = _contact;
        _emailController.text = _email;
        _usernameController.text = _username;
      });
    }
  }

  Future<void> _saveChanges() async {
    final confirm = await StaffDialog.confirm(
      context,
      title: 'Save Changes',
      message: 'Are you sure you want to save these changes?',
      icon: CupertinoIcons.checkmark_circle,
      confirmLabel: 'Save',
    );
    if (confirm) {
      final newContact = _contactController.text.trim();
      final newUsername = _usernameController.text.trim();
      final newEmail = _emailController.text.trim();
      await AuthService.updateProfile(
        username: newUsername,
        contactNumber: newContact,
        email: newEmail,
      );
      if (mounted) {
        setState(() {
          _contact = newContact;
          _email = newEmail;
          _username = newUsername;
          _isEditing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: AuthService.watchCurrentUser(),
      initialData: AuthService.currentAppUser,
      builder: (context, snapshot) {
        final user = snapshot.data ?? AuthService.currentAppUser;
        final displayName = user?.fullName.isNotEmpty == true
            ? user!.fullName
            : (user?.username.isNotEmpty == true ? user!.username : _fullName);
        final initials = user?.initials ?? 'BO';
        final displayRole = user?.displayRole ?? 'Business Owner';
        final displayAge = user?.age.isNotEmpty == true ? '${user!.age} yrs old' : _age;
        final displayAddress = user?.address.isNotEmpty == true ? user!.address : _address;

        // Keep controllers in sync when not editing
        if (!_isEditing) {
          if (user?.contactNumber.isNotEmpty == true &&
              _contactController.text != user!.contactNumber) {
            _contact = user.contactNumber;
            _contactController.text = user.contactNumber;
          }
          if (user?.username.isNotEmpty == true &&
              _usernameController.text != user!.username) {
            _username = user.username;
            _usernameController.text = user.username;
          }
          final actualEmail = user?.email.isNotEmpty == true
              ? user!.email
              : '${user?.username ?? 'owner'}@brahmsnexus.ph';
          if (_emailController.text != actualEmail) {
            _email = actualEmail;
            _emailController.text = _email;
          }
        }

        return CupertinoPageScaffold(
          backgroundColor: AppColors.background,
          navigationBar: const StaffNavBar(
            title: 'Profile',
            trailing: StaffTopActions(),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildProfileHeader(displayName, initials, displayRole),
            const SizedBox(height: 20),
            StaffSectionHeader(
              label: 'Account Details',
              icon: CupertinoIcons.person_crop_circle_fill,
              trailing: _isEditing
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _discardChanges,
                          child: const Text('Discard',
                              style: TextStyle(fontSize: 12, color: AppColors.error)),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _saveChanges,
                          child: const Text('Save',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  : CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _handleEditToggle,
                      child: const Text('Edit', style: TextStyle(fontSize: 13)),
                    ),
            ),
            const SizedBox(height: 8),
            StaffCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _infoTile(CupertinoIcons.person_fill, 'Full Name', displayName),
                  _divider(),
                  _infoTile(CupertinoIcons.number, 'Age', displayAge),
                  _divider(),
                  _infoTile(CupertinoIcons.location_fill, 'Address', displayAddress),
                  _divider(),
                  _editTile(CupertinoIcons.phone_fill, 'Contact', _contactController,
                      _isEditing),
                  _divider(),
                  _editTile(CupertinoIcons.mail_solid, 'Email', _emailController,
                      _isEditing),
                  _divider(),
                  _editTile(CupertinoIcons.shield_fill, 'Username', _usernameController,
                      _isEditing),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const StaffSectionHeader(
              label: 'Operations & Business',
              icon: CupertinoIcons.building_2_fill,
            ),
            const SizedBox(height: 8),
            StaffCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _infoTile(CupertinoIcons.map_pin_ellipse, 'Active Branches', '6 Branches'),
                  _divider(),
                  _infoTile(CupertinoIcons.checkmark_shield_fill, 'Access Level',
                      'Full Administrative Access'),
                  _divider(),
                  _infoTile(CupertinoIcons.info_circle_fill, 'System Version',
                      'Brahms Nexus v1.0.0'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            StaffButton(
              label: 'Log Out',
              icon: CupertinoIcons.square_arrow_right,
              color: AppColors.error.withValues(alpha: 0.1),
              textColor: AppColors.error,
              onPressed: _confirmLogout,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildProfileHeader(String name, String initials, String role) {
    return StaffCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accentDark, AppColors.accent],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentDark.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              initials,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(CupertinoIcons.checkmark_seal_fill, size: 14, color: AppColors.accent),
                    SizedBox(width: 4),
                    Text(
                      'Verified Administrator',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editTile(
      IconData icon, String label, TextEditingController controller, bool editing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: editing
                ? CupertinoTextField(
                    controller: controller,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: null,
                  )
                : Text(
                    controller.text,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        margin: const EdgeInsets.only(left: 46),
        height: 0.5,
        color: AppColors.border.withValues(alpha: 0.5),
      );
}
