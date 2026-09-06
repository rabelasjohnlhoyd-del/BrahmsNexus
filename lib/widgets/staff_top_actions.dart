import 'package:flutter/cupertino.dart';
import '../pages/auth/login_screen.dart';
import '../pages/staff_app/notifications_screen.dart';
import '../pages/staff_app/profile_screen.dart';
import '../theme/app_theme.dart';

/// Shared trailing actions for every tab of the Cook/Staff app:
/// notification bell (left) + profile avatar (right). This replaces
/// the old, separate "Announcements" tab.
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
              _confirmLogout(context);
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

  /// Second, explicit confirmation step before actually logging out —
  /// logout is destructive (clears the whole Staff shell + tab stack),
  /// so a single accidental tap on the action-sheet item shouldn't be
  /// enough to trigger it.
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
              // rootNavigator: true is essential here — this widget lives
              // inside one tab's own nested Navigator (CupertinoTabView).
              // Without it, LoginScreen would replace just that tab's
              // stack, leaving the outer StaffShell (and its bottom tab
              // bar) still on screen underneath/around it.
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
                      border: Border.all(color: AppColors.headerStart, width: 1.5),
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
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.pastelBrown,
              shape: BoxShape.circle,
              border: Border.all(
                color: CupertinoColors.white.withValues(alpha: 0.6),
                width: 1.5,
              ),
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
