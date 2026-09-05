import 'package:flutter/cupertino.dart';
import '../pages/auth/login_screen.dart';
import '../pages/driver_app/notifications_screen.dart';
import '../pages/driver_app/profile_screen.dart';
import '../theme/app_theme.dart';

/// Shared trailing actions para sa bawat tab ng Driver app:
/// notification bell (kaliwa, para sa announcements ni Owner) +
/// profile avatar (kanan, Profile/Logout menu).
class DriverTopActions extends StatelessWidget {
  const DriverTopActions({super.key, required this.initials});

  final String initials;

  void _showProfileMenu(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const DriverProfileScreen()),
              );
            },
            child: const Text('Profile'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).pushAndRemoveUntil(
                CupertinoPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => const DriverNotificationsScreen(),
              ),
            );
          },
          child: const Icon(
            CupertinoIcons.bell,
            color: AppColors.accent,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: () => _showProfileMenu(context),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.pastelBrown,
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
