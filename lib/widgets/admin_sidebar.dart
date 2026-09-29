import 'package:flutter/material.dart';
import '../pages/admin_web/admin_web_colors.dart';

class AdminSidebarItem {
  const AdminSidebarItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Refined Side navigation for Admin Web.
/// Keeps the original clean white sidebar background with brand chocolate header,
/// now featuring the official Brahms logo, burger nav toggle, and collapsible support.
class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  final List<AdminSidebarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final width = isCollapsed ? 76.0 : 260.0;

    return ClipRect(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: width,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: AdminWebColors.border)),
        ),
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          maxWidth: 260,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          // ── BRANDING HEADER WITH CHOCOLATE GRADIENT & LOGO ──
          Container(
            height: 64,
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 12 : 16,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AdminWebColors.headerStart, AdminWebColors.headerEnd],
              ),
            ),
            child: isCollapsed
                ? Center(
                    child: onToggleCollapse != null
                        ? IconButton(
                            icon: const Icon(Icons.menu_rounded,
                                color: Colors.white, size: 22),
                            onPressed: onToggleCollapse,
                            tooltip: 'Expand Sidebar',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        : _buildLogoBadge(size: 36),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildLogoBadge(size: 40),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BRAHMSNEXUS',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.2,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2),
                            Text(
                              'MANAGEMENT SYSTEM',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                                letterSpacing: 0.5,
                                fontSize: 9,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (onToggleCollapse != null)
                        IconButton(
                          icon: const Icon(Icons.menu_open_rounded,
                              color: Colors.white, size: 22),
                          onPressed: onToggleCollapse,
                          tooltip: 'Collapse Sidebar',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
          ),

          const SizedBox(height: 12),

          // ── NAVIGATION MENU ITEMS ──
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 8 : 12,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final bool isSelected = index == selectedIndex;

                if (isCollapsed) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Tooltip(
                      message: item.label,
                      preferBelow: false,
                      child: InkWell(
                        onTap: () => onSelect(index),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AdminWebColors.accent.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            item.icon,
                            size: 20,
                            color: isSelected
                                ? AdminWebColors.accent
                                : AdminWebColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Material(
                    color: isSelected
                        ? AdminWebColors.accent.withValues(alpha: 0.09)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onSelect(index),
                      hoverColor: AdminWebColors.accent.withValues(alpha: 0.04),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              size: 19,
                              color: isSelected
                                  ? AdminWebColors.accent
                                  : AdminWebColors.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AdminWebColors.accent
                                      : AdminWebColors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected)
                              Container(
                                width: 4,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: AdminWebColors.accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── LOGOUT SECTION ──
          Padding(
            padding: EdgeInsets.all(isCollapsed ? 10 : 14),
            child: isCollapsed
                ? Tooltip(
                    message: 'Logout',
                    child: InkWell(
                      onTap: onLogout,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AdminWebColors.error.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          size: 20,
                          color: AdminWebColors.error,
                        ),
                      ),
                    ),
                  )
                : Material(
                    color: AdminWebColors.error.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onLogout,
                      hoverColor: AdminWebColors.error.withValues(alpha: 0.12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.logout_rounded,
                              size: 19,
                              color: AdminWebColors.error,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Logout',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AdminWebColors.error,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ),
  ),
),
);
  }

  Widget _buildLogoBadge({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.5),
        child: Image.asset(
          'assets/images/brahms_logo.jpg',
          cacheWidth: (size * 2).toInt(),
          cacheHeight: (size * 2).toInt(),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: AdminWebColors.accent,
            alignment: Alignment.center,
            child: const Icon(Icons.restaurant_menu_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
