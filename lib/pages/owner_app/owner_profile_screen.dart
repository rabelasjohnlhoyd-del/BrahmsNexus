import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';
import '../auth/login_screen.dart';

/// Profile tab of the Owner App — displays the owner's account
/// credentials, administrative privileges, operational settings,
/// and log out action.
class OwnerProfileScreen extends StatelessWidget {
  const OwnerProfileScreen({super.key});

  void _confirmLogout(BuildContext context) {
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
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                CupertinoPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            _buildProfileHeader(),
            const SizedBox(height: 20),

            const StaffSectionHeader(
              label: 'Account Details',
              icon: CupertinoIcons.person_crop_circle_fill,
            ),
            const SizedBox(height: 8),
            StaffCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _infoTile(CupertinoIcons.person_fill, 'Full Name', 'Ramon Santos'),
                  _divider(),
                  _infoTile(CupertinoIcons.phone_fill, 'Contact Number', '+63 917 888 1234'),
                  _divider(),
                  _infoTile(CupertinoIcons.mail_solid, 'Email', 'owner@brahmsnexus.ph'),
                  _divider(),
                  _infoTile(CupertinoIcons.shield_fill, 'Role', 'Owner / Administrator'),
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
                  _infoTile(CupertinoIcons.checkmark_shield_fill, 'Access Level', 'Full Administrative Access'),
                  _divider(),
                  _infoTile(CupertinoIcons.info_circle_fill, 'System Version', 'Brahms Nexus v1.0.0'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const StaffSectionHeader(
              label: 'Preferences & Security',
              icon: CupertinoIcons.gear_alt_fill,
            ),
            const SizedBox(height: 8),
            StaffCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _settingsTile(CupertinoIcons.lock_fill, 'PIN Protection', 'Enabled'),
                  _divider(),
                  _settingsTile(CupertinoIcons.bell_fill, 'Notifications', 'Enabled'),
                  _divider(),
                  _settingsTile(CupertinoIcons.question_circle_fill, 'Help & Support', null),
                ],
              ),
            ),
            const SizedBox(height: 24),

            StaffButton(
              label: 'Log Out',
              icon: CupertinoIcons.square_arrow_right,
              color: AppColors.error.withValues(alpha: 0.1),
              textColor: AppColors.error,
              onPressed: () => _confirmLogout(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
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
            child: const Text(
              'RS',
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ramon Santos',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Business Owner',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6),
                Row(
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

  Widget _settingsTile(IconData icon, String label, String? value) {
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
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (value != null)
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(width: 6),
          const Icon(CupertinoIcons.chevron_forward, size: 14, color: AppColors.border),
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
