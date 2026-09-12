import 'package:flutter/cupertino.dart';
import '../pages/staff_app/notifications_screen.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Shared trailing actions for every tab of the Staff and Owner apps:
/// notification bell with live unread badge.
class StaffTopActions extends StatelessWidget {
  const StaffTopActions({
    super.key,
    this.hasUnread,
  });

  /// Optional override. If null, automatically streams real-time unread count.
  final bool? hasUnread;

  @override
  Widget build(BuildContext context) {
    final role = AuthService.currentNotificationRole;
    final userId = AuthService.currentUserId;

    return StreamBuilder<int>(
      stream: NotificationService.watchUnreadCount(
        role: role,
        userId: userId,
      ),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        final showDot = hasUnread ?? (unreadCount > 0);

        return CupertinoButton(
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
              if (showDot)
                Positioned(
                  top: -1,
                  right: -1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppColors.headerStart, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
