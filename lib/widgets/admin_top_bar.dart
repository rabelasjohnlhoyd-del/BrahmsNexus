import 'package:flutter/material.dart';
import '../pages/admin_web/admin_web_colors.dart';

/// DEPRECATED / UNUSED — no longer referenced anywhere in the app.
///
/// Was the persistent top bar for the desktop/wide Admin Web layout,
/// but it duplicated the title/notification/profile row that each
/// admin page (e.g. DashboardScreen) now renders itself, so it was
/// removed from admin_web_shell.dart. Kept on disk only because this
/// tool can't delete files on your machine — safe for you to delete
/// this file yourself (right-click → Delete in Android Studio).
///
/// Previously the wide layout had NO top bar at all — each page just
/// started immediately with its own title text, so there was nowhere
/// consistent for a page label, and no way to log out without
/// scrolling all the way down the sidebar. This adds that missing
/// chrome once, above every page, without needing a hamburger menu
/// (which is reserved for the narrow/mobile-browser layout).
class AdminTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminTopBar({
    super.key,
    required this.currentLabel,
    required this.onLogout,
  });

  final String currentLabel;
  final VoidCallback onLogout;

  static const double _height = 64;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      decoration: const BoxDecoration(
        color: AdminWebColors.background,
        border: Border(bottom: BorderSide(color: AdminWebColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Text(
              currentLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AdminWebColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            offset: const Offset(0, 44),
            onSelected: (value) {
              if (value == 'logout') onLogout();
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AdminWebColors.accent.withValues(alpha: 0.15),
                  child: const Text(
                    'O',
                    style: TextStyle(
                      color: AdminWebColors.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Owner',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AdminWebColors.textPrimary,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: AdminWebColors.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
