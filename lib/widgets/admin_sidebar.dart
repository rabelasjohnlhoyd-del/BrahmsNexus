import 'package:flutter/material.dart';
import '../pages/admin_web/admin_web_colors.dart';
import '../theme/app_theme.dart';

class AdminSidebarItem {
  const AdminSidebarItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Professional side navigation for Admin Web — modeled after the
/// Staff App's gradient header style. Uses a deep-brown-to-warm-brown
/// gradient with decorative background circles for depth.
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
      width: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.headerStart, AppColors.headerEnd],
        ),
      ),
      child: Stack(
        children: [
          // Subtle decorative circles for visual depth (matching StaffNavBar style)
          Positioned(
            left: -30,
            top: -20,
            child: _decorCircle(100),
          ),
          Positioned(
            right: -20,
            bottom: 40,
            child: _decorCircle(80),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sidebar Brand Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.storefront_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'BRAHMS NEXUS',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final bool isSelected = index == selectedIndex;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Material(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onSelect(index),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.icon,
                                  size: 20,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.chocolateTint.withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.chocolateTint.withValues(alpha: 0.8),
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
              const Divider(color: Colors.white10, height: 1),
              // Logout Action
              Padding(
                padding: const EdgeInsets.all(16),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onLogout,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded,
                              size: 20, color: AdminWebColors.error.withValues(alpha: 0.9)),
                          const SizedBox(width: 14),
                          Text(
                            'Log out',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AdminWebColors.error.withValues(alpha: 0.9),
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
        ],
      ),
    );
  }

  Widget _decorCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.03),
      ),
    );
  }
}
