import 'package:flutter/cupertino.dart';
import '../../models/app_notification.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_card.dart';
import '../../widgets/driver_nav_bar.dart';

/// Opened from the notification bell — real-time announcements and tasks
/// from the Owner to the Driver.
class DriverNotificationsScreen extends StatelessWidget {
  const DriverNotificationsScreen({super.key});

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
  }

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.currentUserId;

    return StreamBuilder<List<AppNotification>>(
      stream: NotificationService.watchNotifications(
        role: 'driver',
        userId: userId,
      ),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadCount =
            notifications.where((n) => !n.isRead(userId)).length;

        return CupertinoPageScaffold(
          backgroundColor: AppColors.background,
          navigationBar: DriverNavBar(
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
                            width: 80,
                            height: 80,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.pastelBrown.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.bell_slash,
                                size: 32, color: AppColors.accent),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Quiet for Now',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'You have no new announcements or notifications at the moment.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              height: 1.4,
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
                        child: DriverCard(
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
