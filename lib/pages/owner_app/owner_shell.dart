import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import 'owner_homepage_screen.dart';
import 'owner_assignments_screen.dart';
import 'owner_inventory_screen.dart';
import 'owner_sales_payroll_screen.dart';
import 'owner_more_screen.dart';
import 'owner_lock_screen.dart';

/// Main shell for the Owner mobile app — matches the 4-tab structure
/// of the Staff app but with 5 tabs (Home, Assign, Inventory, Sales,
/// More) and Owner-specific data views.
class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  bool _isUnlocked = false;

  void _handleUnlock() {
    setState(() => _isUnlocked = true);
  }

  static const _inactiveTint = Color(0xFFB8A99A);

  static const _systemBarStyle = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: CupertinoColors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  Widget _tabItem(IconData icon, String label, {required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.textPrimary : null,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: active ? CupertinoColors.white : _inactiveTint,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              height: 1.0,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? CupertinoColors.white : _inactiveTint,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return OwnerLockScreen(onUnlocked: _handleUnlock);
    }

    const cupertinoThemeData = CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.accent,
      scaffoldBackgroundColor: AppColors.background,
      barBackgroundColor: CupertinoColors.white,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemBarStyle,
      child: CupertinoTheme(
        data: cupertinoThemeData,
        child: Builder(
          builder: (context) => DefaultTextStyle(
            style: CupertinoTheme.of(context).textTheme.textStyle,
            child: CupertinoTabScaffold(
              tabBar: CupertinoTabBar(
                backgroundColor: CupertinoColors.white,
                height: 62,
                border: const Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
                items: [
                  BottomNavigationBarItem(
                    icon: _tabItem(CupertinoIcons.house_fill, 'Home', active: false),
                    activeIcon: _tabItem(CupertinoIcons.house_fill, 'Home', active: true),
                  ),
                  BottomNavigationBarItem(
                    icon: _tabItem(CupertinoIcons.person_2_fill, 'Assign', active: false),
                    activeIcon: _tabItem(CupertinoIcons.person_2_fill, 'Assign', active: true),
                  ),
                  BottomNavigationBarItem(
                    icon: _tabItem(CupertinoIcons.cube_box_fill, 'Inventory', active: false),
                    activeIcon: _tabItem(CupertinoIcons.cube_box_fill, 'Inventory', active: true),
                  ),
                  BottomNavigationBarItem(
                    icon: _tabItem(CupertinoIcons.money_dollar_circle_fill, 'Sales', active: false),
                    activeIcon: _tabItem(CupertinoIcons.money_dollar_circle_fill, 'Sales', active: true),
                  ),
                  BottomNavigationBarItem(
                    icon: _tabItem(CupertinoIcons.ellipsis_circle_fill, 'More', active: false),
                    activeIcon: _tabItem(CupertinoIcons.ellipsis_circle_fill, 'More', active: true),
                  ),
                ],
              ),
              tabBuilder: (context, index) {
                return CupertinoTabView(
                  builder: (context) {
                    switch (index) {
                      case 0: return const OwnerHomepageScreen();
                      case 1: return const OwnerAssignmentsScreen();
                      case 2: return const OwnerInventoryScreen();
                      case 3: return const OwnerSalesPayrollScreen();
                      case 4: return const OwnerMoreScreen();
                      default: return const OwnerHomepageScreen();
                    }
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
