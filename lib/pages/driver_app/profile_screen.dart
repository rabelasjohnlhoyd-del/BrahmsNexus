import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';

/// Profile ng Driver — binubuksan mula sa profile avatar sa tuktok ng
/// bawat tab.
///
/// NOTE: Mock data for now — once Supabase/Firebase Auth are wired up,
/// this reads the actual logged-in driver's profile record.
class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(middle: Text('Profile')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.pastelBrown,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  'RS',
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
                'Ramon Santos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Center(
              child: Text(
                'Driver',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            _infoTile(CupertinoIcons.person, 'Username', 'ramon.santos'),
            _infoTile(CupertinoIcons.phone, 'Contact Number', '0917 555 8899'),
            _infoTile(CupertinoIcons.car_detailed, 'Vehicle', 'Multicab'),
            _infoTile(
                CupertinoIcons.calendar, 'Member Since', 'March 2024'),
            const SizedBox(height: 28),
            CupertinoButton(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(12),
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  CupertinoPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('Log Out'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
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
    );
  }
}
