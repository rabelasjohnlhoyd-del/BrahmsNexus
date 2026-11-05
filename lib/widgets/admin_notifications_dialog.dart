import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../pages/admin_web/admin_web_colors.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

import '../pages/admin_web/admin_web_widgets/admin_pagination_bar.dart';

class AdminNotificationsDialog extends StatefulWidget {
  const AdminNotificationsDialog({
    super.key,
    this.onNavigateRoute,
  });

  final void Function(String route)? onNavigateRoute;

  static void show(BuildContext context, {void Function(String route)? onNavigateRoute}) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => AdminNotificationsDialog(onNavigateRoute: onNavigateRoute),
    );
  }

  @override
  State<AdminNotificationsDialog> createState() => _AdminNotificationsDialogState();
}

class _AdminNotificationsDialogState extends State<AdminNotificationsDialog> {
  int _currentPage = 0;
  static const int _pageSize = 7;

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.currentUserId;
    final username = AuthService.currentUsername;

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 16 : 24,
      ),
      child: Center(
        child: Container(
          width: isMobile ? double.infinity : 540,
          constraints: BoxConstraints(
            maxWidth: 540,
            maxHeight: MediaQuery.of(context).size.height * (isMobile ? 0.88 : 0.85),
          ),
          decoration: BoxDecoration(
            color: AdminWebColors.surfaceTint,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
            border: Border.all(color: AdminWebColors.border),
          ),
          child: StreamBuilder<List<AppNotification>>(
            stream: NotificationService.watchNotifications(
              role: 'owner',
              userId: userId,
            ),
            builder: (context, snapshot) {
              final notifications = snapshot.data ?? [];
              final unreadCount = notifications.where((n) => !n.isRead(userId, username)).length;
              final total = notifications.length;
              final totalPages = (total / _pageSize).ceil();
              final effectivePage = totalPages == 0 ? 0 : _currentPage.clamp(0, totalPages - 1);
              final pagedNotifications = notifications
                  .skip(effectivePage * _pageSize)
                  .take(_pageSize)
                  .toList();

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 14 : 20,
                      isMobile ? 12 : 16,
                      isMobile ? 8 : 16,
                      isMobile ? 12 : 16,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AdminWebColors.border)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_rounded,
                          color: AdminWebColors.accent,
                          size: isMobile ? 20 : 22,
                        ),
                        SizedBox(width: isMobile ? 8 : 10),
                        Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: isMobile ? 15 : 17,
                            fontWeight: FontWeight.w800,
                            color: AdminWebColors.textPrimary,
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          SizedBox(width: isMobile ? 6 : 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AdminWebColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unreadCount new',
                              style: TextStyle(
                                fontSize: isMobile ? 10.5 : 11,
                                fontWeight: FontWeight.w800,
                                color: AdminWebColors.warning,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (unreadCount > 0)
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => NotificationService.markAllAsRead(
                              notifications: notifications,
                              userId: userId,
                              username: username,
                            ),
                            child: Text(
                              isMobile ? 'Mark read' : 'Mark all as read',
                              style: TextStyle(
                                fontSize: isMobile ? 11.5 : 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        SizedBox(width: isMobile ? 4 : 8),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          iconSize: isMobile ? 20 : 22,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          color: AdminWebColors.textSecondary,
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  // Notifications list
                  Flexible(
                    child: notifications.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.notifications_off_outlined,
                                  size: 48,
                                  color: AdminWebColors.textSecondary.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No notifications right now.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AdminWebColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shrinkWrap: true,
                            itemCount: pagedNotifications.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              color: AdminWebColors.border,
                            ),
                            itemBuilder: (context, index) {
                              final item = pagedNotifications[index];
                              final isRead = item.isRead(userId, username);

                              return InkWell(
                                onTap: () async {
                                  await NotificationService.markAsRead(
                                    notificationId: item.id,
                                    userId: userId,
                                    username: username,
                                  );
                                  if (item.route != null && context.mounted) {
                                    Navigator.of(context).pop();
                                    widget.onNavigateRoute?.call(item.route!);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                  color: isRead
                                      ? Colors.transparent
                                      : AdminWebColors.accent.withValues(alpha: 0.04),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isRead
                                              ? AdminWebColors.border.withValues(alpha: 0.5)
                                              : item.type.color.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          item.type.icon,
                                          color: isRead
                                              ? AdminWebColors.textSecondary
                                              : item.type.color,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.title,
                                                    style: TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight: isRead
                                                          ? FontWeight.w600
                                                          : FontWeight.w800,
                                                      color: AdminWebColors.textPrimary,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  _formatTime(item.createdAt),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AdminWebColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.message,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: isRead
                                                    ? AdminWebColors.textSecondary
                                                    : AdminWebColors.textPrimary,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isRead) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(top: 6),
                                          decoration: const BoxDecoration(
                                            color: AdminWebColors.accent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Pagination controls if more than 7 items
                  if (total > _pageSize)
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AdminWebColors.border)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: AdminPaginationBar(
                        currentPage: effectivePage,
                        totalItems: total,
                        pageSize: _pageSize,
                        onPageChanged: (p) => setState(() => _currentPage = p),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
