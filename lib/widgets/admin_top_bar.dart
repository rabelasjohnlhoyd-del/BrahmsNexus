import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';

/// Persistent top bar for the desktop/wide Admin Web layout.
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
        color: AdminColors.surface,
        border: Border(bottom: BorderSide(color: AdminColors.border)),
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
                color: AdminColors.textPrimary,
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
                    Icon(Icons.logout_rounded, size: 18, color: AdminColors.error),
                    SizedBox(width: 10),
                    Text('Log out'),
                  ],
                ),
              ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: AdminColors.primarySoft,
                  child: Text(
                    'O',
                    style: TextStyle(
                      color: AdminColors.primary,
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
                    color: AdminColors.textPrimary,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: AdminColors.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
