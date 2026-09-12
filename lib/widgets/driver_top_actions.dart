import 'package:flutter/cupertino.dart';
import '../pages/driver_app/notifications_screen.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Shared trailing actions for every tab of the Driver app:
/// notification bell (for Owner announcements & tasks) with live unread badge.
class DriverTopActions extends StatelessWidget {
  const DriverTopActions({
    super.key,
    this.hasUnread,
  });

  /// Optional override. If null, automatically streams real-time unread count.
  final bool? hasUnread;

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.currentUserId;

    return StreamBuilder<int>(
      stream: NotificationService.watchUnreadCount(
        role: 'driver',
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
              CupertinoPageRoute(
                builder: (_) => const DriverNotificationsScreen(),
              ),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                CupertinoIcons.bell_fill,
                color: CupertinoColors.white,
                size: 22,
              ),
              if (showDot)
                Positioned(
                  top: -1,
                  right: -1,
                  child: Container(
                    width: 8,
                    height: 8,
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
