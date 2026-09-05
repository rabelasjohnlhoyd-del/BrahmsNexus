import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../auth/login_screen.dart';

/// Binubuksan mula sa profile avatar sa tuktok ng bawat tab. Ipinapakita
/// dito ang mga detalye ng account ng naka-login na cook.
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
            Center(
              child: Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentDark.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(color: CupertinoColors.white, width: 3),
                ),
                child: const Text(
                  'JD',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Juan Dela Cruz',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Center(
              child: Text(
                'Staff · Cook',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            _infoTile(CupertinoIcons.person, 'Username', 'juan.delacruz'),
            _infoTile(CupertinoIcons.phone, 'Contact Number', '0917 123 4567'),
            _infoTile(
                CupertinoIcons.building_2_fill, 'Current Branch', 'Sta. Cruz'),
            _infoTile(
                CupertinoIcons.calendar, 'Member Since', 'January 2024'),
            const SizedBox(height: 28),
            StaffButton(
              label: 'Log Out',
              color: AppColors.error,
              onPressed: () => _confirmLogout(context),
            ),
          ],
        ),
      ),
    );
  }

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
      padding: const EdgeInsets.only(bottom: 10),
      child: StaffCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.pastelBrown.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
