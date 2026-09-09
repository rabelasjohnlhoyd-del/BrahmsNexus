import 'package:flutter/material.dart';
import '../pages/admin_web/admin_web_colors.dart';

/// Standardized top bar for Admin Web pages. Provides consistent
/// page labeling and access to notifications/profile.
class AdminTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onLogout,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onLogout;
  final List<Widget> actions;

  static const double _height = 100;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AdminWebColors.headerStart, AdminWebColors.headerEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Page Specific Actions
          ...actions.map((a) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: a,
          )),
          if (actions.isNotEmpty)
            Container(
              height: 32,
              width: 1,
              margin: const EdgeInsets.only(right: 20, left: 8),
              color: Colors.white.withValues(alpha: 0.2),
            ),
          // Notification Bell
          IconButton(
            onPressed: () {},
            icon: Badge(
              label: const Text('2'),
              backgroundColor: AdminWebColors.warning,
              child: const Icon(Icons.notifications_outlined, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          // Profile Section
          PopupMenuButton<String>(
            offset: const Offset(0, 50),
            onSelected: (value) {
              if (value == 'logout') onLogout?.call();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: AdminWebColors.error),
                    SizedBox(width: 10),
                    Text('Log out'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white,
                    child: const Text(
                      'O',
                      style: TextStyle(
                        color: AdminWebColors.headerStart,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Administrator',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20, color: Colors.white70),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

