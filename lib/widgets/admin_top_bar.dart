import 'package:flutter/material.dart';
import '../pages/admin_web/admin_web_colors.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'admin_notifications_dialog.dart';

/// Full-width continuous top header bar for Admin Web.
/// Matches the 64px height of the sidebar header for a seamless, pixel-perfect
/// top boundary across the entire browser window.
class AdminTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onLogout,
    this.onProfile,
    this.actions = const [],
    this.onNavigateRoute,
    this.onToggleSidebar,
    this.showSidebarToggle = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onLogout;
  final VoidCallback? onProfile;
  final List<Widget> actions;
  final void Function(String route)? onNavigateRoute;
  final VoidCallback? onToggleSidebar;
  final bool showSidebarToggle;

  static const double _height = 64;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  static IconData _getSectionIcon(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('dashboard')) return Icons.grid_view_rounded;
    if (lower.contains('staff')) return Icons.groups_rounded;
    if (lower.contains('approval')) return Icons.how_to_reg_rounded;
    if (lower.contains('assignment')) return Icons.store_mall_directory_rounded;
    if (lower.contains('inventory')) return Icons.inventory_2_rounded;
    if (lower.contains('sales') || lower.contains('payroll')) return Icons.payments_rounded;
    if (lower.contains('bilao')) return Icons.shopping_bag_rounded;
    if (lower.contains('report')) return Icons.fact_check_rounded;
    if (lower.contains('announcement')) return Icons.campaign_rounded;
    if (lower.contains('analytics') || lower.contains('dss')) return Icons.insights_rounded;
    if (lower.contains('branch')) return Icons.location_on_rounded;
    if (lower.contains('activity') || lower.contains('log')) return Icons.list_alt_rounded;
    if (lower.contains('setting')) return Icons.settings_rounded;
    return Icons.admin_panel_settings_rounded;
  }

  static String _formattedDate() {
    final now = DateTime.now();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 640;

        return Container(
          height: _height,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: AdminWebColors.border.withValues(alpha: 0.7),
                width: 1,
              ),
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 24),
          child: Row(
            children: [
              // Sidebar Toggle Button (if collapsed or triggered)
              if (showSidebarToggle && onToggleSidebar != null) ...[
                IconButton(
                  icon: const Icon(Icons.menu_rounded,
                      color: AdminWebColors.textPrimary, size: 22),
                  onPressed: onToggleSidebar,
                  tooltip: 'Toggle Sidebar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
              ],

              // Section Icon Badge
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AdminWebColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getSectionIcon(title),
                  size: 19,
                  color: AdminWebColors.accent,
                ),
              ),
              const SizedBox(width: 12),

              // Section Title & Subtitle
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isNarrow ? 14 : 16,
                      fontWeight: FontWeight.w800,
                      color: AdminWebColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (!isNarrow) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle ?? 'Brahms Nexus Management System',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AdminWebColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),

              const Spacer(),

              // ── SYSTEM ONLINE STATUS PILL — hidden on narrow screens ──
              if (!isNarrow) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AdminWebColors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AdminWebColors.success.withValues(alpha: 0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'System Online',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AdminWebColors.textPrimary,
                      ),
                    ),
                  ],
                ),

                // Divider
                Container(
                  height: 18,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: AdminWebColors.border,
                ),

                // ── DATE CHIP ──
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: AdminWebColors.accent,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _formattedDate(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AdminWebColors.textPrimary,
                      ),
                    ),
                  ],
                ),

                // Divider
                Container(
                  height: 18,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: AdminWebColors.border,
                ),
              ],

              // Page Specific Actions (if any)
              ...actions.map((a) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: a,
                  )),

              // ── NOTIFICATION BELL WITH BADGE ──
              StreamBuilder<int>(
                stream: NotificationService.watchUnreadCount(
                  role: 'owner',
                  userId: AuthService.currentUserId,
                ),
                builder: (context, snapshot) {
                  final unread = snapshot.data ?? 0;
                  return IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Notifications',
                    onPressed: () => AdminNotificationsDialog.show(
                      context,
                      onNavigateRoute: onNavigateRoute,
                    ),
                    icon: unread > 0
                        ? Badge(
                            label: Text('$unread'),
                            backgroundColor: AdminWebColors.warning,
                            child: const Icon(Icons.notifications_rounded,
                                color: AdminWebColors.textPrimary, size: 21),
                          )
                        : const Icon(Icons.notifications_outlined,
                            color: AdminWebColors.textPrimary, size: 21),
                  );
                },
              ),
              SizedBox(width: isNarrow ? 8 : 16),

              // ── ADMINISTRATOR PROFILE PILL ──
              PopupMenuButton<String>(
                offset: const Offset(0, 42),
                onSelected: (value) {
                  if (value == 'logout') onLogout?.call();
                  if (value == 'profile') onProfile?.call();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline_rounded,
                            size: 18, color: AdminWebColors.accent),
                        SizedBox(width: 10),
                        Text('Admin Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded,
                            size: 18, color: AdminWebColors.error),
                        SizedBox(width: 10),
                        Text('Log Out',
                            style: TextStyle(color: AdminWebColors.error)),
                      ],
                    ),
                  ),
                ],
                child: isNarrow
                    // On narrow screens: just show a compact avatar
                    ? CircleAvatar(
                        radius: 16,
                        backgroundColor: AdminWebColors.accent,
                        child: const Text(
                          'A',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      )
                    // On wide screens: full pill with "Administrator" label
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AdminWebColors.surfaceTint,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AdminWebColors.border.withValues(alpha: 0.9),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AdminWebColors.accent,
                              child: const Text(
                                'A',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Administrator',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AdminWebColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: AdminWebColors.textSecondary,
                            ),
                          ],
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
