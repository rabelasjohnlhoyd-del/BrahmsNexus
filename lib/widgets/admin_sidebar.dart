import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';

class AdminSidebarItem {
  const AdminSidebarItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Side navigation for Admin Web — a desktop/web-appropriate pattern
/// (as opposed to a bottom nav, which is for mobile). Used by
/// [AdminWebShell], which has many sections (Dashboard, Staff
/// Management, Account Approvals, Branch Assignments, Inventory,
/// Sales & Payroll, Bilao Orders, Employee Reports, Announcements,
/// Analytics).
///
/// Uses [AdminColors] — a light panel with a solid violet "pill" for
/// the selected item — so it matches the rest of Admin Web instead of
/// the warm-brown [AppColors] used by the mobile Driver/Staff apps.
class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
  });

  final List<AdminSidebarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AdminColors.sidebarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AdminColors.sidebarBorder),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_rounded,
                    color: AdminColors.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'BRAHMS NEXUS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AdminColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final bool isSelected = index == selectedIndex;
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  child: Material(
                    color: isSelected
                        ? AdminColors.sidebarActiveFill
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onSelect(index),
                      hoverColor: AdminColors.sidebarBackgroundElevated,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              size: 20,
                              color: isSelected
                                  ? AdminColors.sidebarTextActive
                                  : AdminColors.sidebarText,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? AdminColors.sidebarTextActive
                                      : AdminColors.sidebarText,
                                ),
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onLogout,
                child: const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded,
                          size: 20, color: AdminColors.error),
                      SizedBox(width: 12),
                      Text(
                        'Log out',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AdminColors.error,
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
    );
  }
}
