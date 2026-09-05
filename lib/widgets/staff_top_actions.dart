import 'package:flutter/cupertino.dart';
import '../pages/auth/login_screen.dart';
import '../pages/staff_app/notifications_screen.dart';
import '../pages/staff_app/profile_screen.dart';
import '../theme/app_theme.dart';

/// Shared trailing actions para sa bawat tab ng Cook/Staff app:
/// notification bell (kaliwa) + profile avatar (kanan). Ito ang
/// kapalit ng dating hiwalay na "Announcements" tab.
///
/// Colors here are white/inverted because this sits on top of the
/// solid accent-brown [StaffNavBar] — see that file for why the bar
/// is a solid color instead of the previous translucent white one.
class StaffTopActions extends StatelessWidget {
  const StaffTopActions({
    super.key,
    required this.initials,
    this.hasUnread = true,
  });

  final String initials;

  /// Shows a small dot on the bell when there are unread
  /// announcements. Defaults to true until this is wired to real
  /// notification data.
  final bool hasUnread;

  void _showProfileMenu(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const ProfileScreen()),
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
              CupertinoPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                CupertinoIcons.bell_fill,
                color: CupertinoColors.white,
                size: 24,
              ),
              if (hasUnread)
                Positioned(
                  top: -1,
                  right: -1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: () => _showProfileMenu(context),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: CupertinoColors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: const TextStyle(
                color: AppColors.accent,
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
