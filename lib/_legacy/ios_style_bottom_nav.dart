import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// iOS-style bottom navigation bar (parang CupertinoTabBar ang itsura).
/// Custom ito para ma-intercept natin ang tap sa "burger" item (index 4)
/// at magpakita ng Drawer/Menu sa halip na magpalit ng tab/page.
class IosStyleBottomNav extends StatelessWidget {
  const IosStyleBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex; // 0-3 lang ang gagamitin para sa tabs
  final ValueChanged<int> onTap;

  static const List<_NavItemData> _items = [
    _NavItemData(icon: CupertinoIcons.house_fill, label: 'Home'),
    _NavItemData(icon: CupertinoIcons.cube_box_fill, label: 'Sales'),
    _NavItemData(icon: CupertinoIcons.map_fill, label: 'Branches'),
    _NavItemData(icon: CupertinoIcons.bag_fill, label: 'Bilao'),
    _NavItemData(icon: CupertinoIcons.line_horizontal_3, label: 'Menu'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.pastelBrown.withValues(alpha: 0.5),
            width: 0.6,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: List.generate(_items.length, (index) {
              // Index 4 (burger) ay hindi na-hi-highlight bilang "selected tab"
              final bool isSelected = index == currentIndex && index != 4;
              final item = _items[index];

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 24,
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.pastelBrown,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.pastelBrown,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
