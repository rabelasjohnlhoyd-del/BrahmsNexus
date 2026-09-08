import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';

/// Opened from the profile avatar at the top of every tab. Shows
/// the logged-in cook's account details.
///
/// NOTE: Mock data for now — once Supabase/Firebase Auth are wired up,
/// this reads the actual logged-in user's profile record.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Profile',
        showBackButton: true,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildProfileHeader(context),
            
            const SizedBox(height: 24),

            const StaffSectionHeader(label: 'Account Details'),
            const SizedBox(height: 8),
            StaffCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _infoTile(CupertinoIcons.person, 'Username', 'juan.delacruz'),
                  _divider(),
                  _infoTile(CupertinoIcons.phone, 'Contact Number', '0917 123 4567'),
                  _divider(),
                  _infoTile(CupertinoIcons.building_2_fill, 'Current Branch', 'Sta. Cruz'),
                  _divider(),
                  _infoTile(CupertinoIcons.calendar, 'Member Since', 'January 2024'),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            const StaffSectionHeader(label: 'Preferences'),
            const SizedBox(height: 12),
            StaffCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _settingsTile(CupertinoIcons.bell, 'Notifications', 'Enabled'),
                  _divider(),
                  _settingsTile(CupertinoIcons.lock_shield, 'Security'),
                  _divider(),
                  _settingsTile(CupertinoIcons.question_circle, 'Support'),
                ],
              ),
            ),

            const SizedBox(height: 32),
            StaffButton(
              label: 'Log Out',
              color: AppColors.error.withValues(alpha: 0.1),
              textColor: AppColors.error,
              onPressed: () => _confirmLogout(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return StaffCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => const EditProfileScreen()),
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                        border: Border.all(color: AppColors.background, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentDark.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'JD',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.accentDark,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.pencil,
                          size: 12,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Juan Dela Cruz',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.6,
                      ),
                    ),
                    Text(
                      'Branch Cook',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(CupertinoIcons.checkmark_seal_fill, size: 14, color: AppColors.success),
                        SizedBox(width: 4),
                        Text(
                          'Verified Staff',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _settingsTile(IconData icon, String label, [String? value]) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (value != null)
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(width: 4),
          const Icon(CupertinoIcons.chevron_forward, size: 16, color: AppColors.border),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    margin: const EdgeInsets.only(left: 48),
    height: 0.5,
    color: AppColors.border.withValues(alpha: 0.4),
  );


  /// Explicit confirmation before actually logging out — logout is
  /// destructive (clears the whole Staff shell + tab stack), so a
  /// single accidental tap shouldn't be enough to trigger it.
  void _confirmLogout(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // rootNavigator: true is essential here — ProfileScreen is
              // pushed inside one tab's own nested Navigator
              // (CupertinoTabView), so a plain Navigator.of(context)
              // would only replace that tab's stack, leaving the outer
              // StaffShell (and its bottom tab bar) still on screen.
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

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.accent.withValues(alpha: 0.8)),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
