import 'package:flutter/cupertino.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_button.dart';
import '../../widgets/driver_card.dart';
import '../../widgets/driver_nav_bar.dart';
import '../../widgets/driver_section_header.dart';
import '../../widgets/driver_top_actions.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';

/// Refined Driver Profile — displays the logged-in driver's real account details.
class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: AuthService.watchCurrentUser(),
      initialData: AuthService.currentAppUser,
      builder: (context, snapshot) {
        final user = snapshot.data ?? AuthService.currentAppUser;
        final username =
            user?.username.isNotEmpty == true ? user!.username : 'driver';
        final fullName =
            user?.fullName.isNotEmpty == true ? user!.fullName : username;
        final contactNumber = user?.contactNumber.isNotEmpty == true
            ? user!.contactNumber
            : 'Not provided';
        final position = user?.displayRole ?? 'Driver';
        final initials = user?.initials ?? 'DR';
        final userEmail = user?.email.isNotEmpty == true
            ? user!.email
            : '$username@brahmsnexus.ph';
        final ageStr = user?.age.isNotEmpty == true ? '${user!.age} yrs old' : 'Not set';
        final addressStr = user?.address.isNotEmpty == true
            ? user!.address
            : 'Not set';
        final licenseStr = user?.driverLicenseNumber.isNotEmpty == true
            ? user!.driverLicenseNumber
            : 'Not registered';
        final licenseVerified = user?.isLicenseVerified == true;

        return CupertinoPageScaffold(
          backgroundColor: AppColors.background,
          navigationBar: const DriverNavBar(
            title: 'Profile',
            trailing: DriverTopActions(),
          ),
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                // --- PREMIUM HEADER ---
                _buildProfileHeader(
                  initials: initials,
                  fullName: fullName,
                  position: position,
                ),

                const SizedBox(height: 20),

                // --- PERSONAL DETAILS ---
                const DriverSectionHeader(label: 'Account Information'),
                const SizedBox(height: 8),
                DriverCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _listTile(CupertinoIcons.person_crop_circle, 'Username',
                          username),
                      _divider(),
                      _listTile(
                          CupertinoIcons.person, 'Full Name', fullName),
                      _divider(),
                      _listTile(CupertinoIcons.mail, 'Email Address', userEmail),
                      _divider(),
                      _listTile(CupertinoIcons.number, 'Age', ageStr),
                      _divider(),
                      _listTile(CupertinoIcons.location, 'Address', addressStr),
                      _divider(),
                      _listTile(CupertinoIcons.phone, 'Contact Number',
                          contactNumber),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --- VEHICLE ---
                const DriverSectionHeader(label: 'Vehicle & Documents'),
                const SizedBox(height: 8),
                DriverCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _listTile(
                        CupertinoIcons.doc_text_fill,
                        "Driver's License",
                        licenseVerified
                            ? '$licenseStr (LTO Verified)'
                            : licenseStr,
                        color: licenseVerified ? AppColors.success : null,
                      ),
                      _divider(),
                      _listTile(CupertinoIcons.car_detailed, 'Vehicle Type',
                          'Multicab (L300)'),
                      _divider(),
                      _listTile(
                          CupertinoIcons.number, 'Plate Number', 'ABC 1234'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --- SETTINGS ---
                const DriverSectionHeader(label: 'Preferences'),
                const SizedBox(height: 8),
                DriverCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _listTile(CupertinoIcons.bell, 'Notifications', 'Enabled',
                          showChevron: true),
                      _divider(),
                      _listTile(CupertinoIcons.lock_shield,
                          'Security & Privacy', null,
                          showChevron: true),
                      _divider(),
                      _listTile(CupertinoIcons.question_circle,
                          'Help & Support', null,
                          showChevron: true),
                      _divider(),
                      _listTile(CupertinoIcons.info_circle,
                          'About Brahms Nexus', null,
                          showChevron: true),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                DriverButton(
                  label: 'Log Out',
                  color: AppColors.error.withValues(alpha: 0.1),
                  textColor: AppColors.error,
                  onPressed: () => _confirmLogout(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader({
    required String initials,
    required String fullName,
    required String position,
  }) {
    return DriverCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                        builder: (_) => const EditProfileScreen()),
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
                        border:
                            Border.all(color: AppColors.background, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentDark.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.6,
                      ),
                    ),
                    Text(
                      position,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(CupertinoIcons.checkmark_seal_fill,
                            size: 14, color: AppColors.success),
                        SizedBox(width: 4),
                        Text(
                          'Verified Partner',
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


  Widget _listTile(IconData icon, String label, String? value, {bool showChevron = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AppColors.accent.withValues(alpha: 0.8)),
          ),
          const SizedBox(width: 14),
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
              style: TextStyle(
                fontSize: 14,
                color: color ?? AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (showChevron)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(CupertinoIcons.chevron_forward, size: 16, color: AppColors.border),
            ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    margin: const EdgeInsets.only(left: 56),
    height: 0.5,
    color: AppColors.border.withValues(alpha: 0.4),
  );

  void _confirmLogout(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to end your session?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.signOut();
              if (!context.mounted) return;
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
}
