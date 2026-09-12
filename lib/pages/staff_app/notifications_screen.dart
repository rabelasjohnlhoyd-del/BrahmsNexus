import 'package:flutter/cupertino.dart';
import '../../models/app_notification.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../owner_app/owner_account_approvals_screen.dart';

/// Opened from the notification bell icon at the top of every tab.
/// Streams live real-time notifications for the current role/user.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${date.month}/${date.day}/${date.year} · '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  void _onNotificationTap(
    BuildContext context,
    AppNotification item,
    String userId,
  ) {
    if (!item.isRead(userId)) {
      NotificationService.markAsRead(notificationId: item.id, userId: userId);
    }

    if (item.route == 'account_approvals' &&
        AuthService.currentRole == UserRole.owner) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => const OwnerAccountApprovalsScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = AuthService.currentNotificationRole;
    final userId = AuthService.currentUserId;

    return StreamBuilder<List<AppNotification>>(
      stream: NotificationService.watchNotifications(
        role: role,
        userId: userId,
      ),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadCount =
            notifications.where((n) => !n.isRead(userId)).length;

        return CupertinoPageScaffold(
          backgroundColor: AppColors.background,
          navigationBar: StaffNavBar(
            title: 'Notifications',
            showBackButton: true,
            trailing: unreadCount > 0
                ? CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    onPressed: () => NotificationService.markAllAsRead(
                      notifications: notifications,
                      userId: userId,
                    ),
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : null,
          ),
          child: SafeArea(
            child: notifications.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.pastelBrown.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.bell_slash,
                                size: 28, color: AppColors.accent),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No notifications right now.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'All caught up! New updates, tasks, and announcements will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      final isRead = item.isRead(userId);

                      return GestureDetector(
                        onTap: () => _onNotificationTap(context, item, userId),
                        child: StaffCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: item.type.color
                                      .withValues(alpha: isRead ? 0.12 : 0.20),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  item.type.icon,
                                  color: item.type.color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isRead
                                                  ? FontWeight.w600
                                                  : FontWeight.w800,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (!isRead)
                                          Container(
                                            margin: const EdgeInsets.only(
                                                left: 6, top: 2),
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: AppColors.accent,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.message,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isRead
                                            ? AppColors.textSecondary
                                            : AppColors.textPrimary,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: item.type.color
                                                .withValues(alpha: 0.10),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item.type.label,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: item.type.color,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatDate(item.createdAt),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
