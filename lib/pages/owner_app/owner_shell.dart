import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import 'owner_homepage_screen.dart';
import 'owner_assignments_screen.dart';
import 'owner_inventory_screen.dart';
import 'owner_sales_payroll_screen.dart';
import 'owner_more_screen.dart';

/// Main shell of the Owner mobile app — a CupertinoTabScaffold with 5
/// tabs (Home, Assignments, Inventory, Sales & Payroll, More),
/// mirroring the same pattern used by staff_shell.dart and
/// driver_shell.dart so all three mobile apps behave identically.
///
/// Unlike Staff/Driver, Owner keeps Announcements reachable (inside
/// More) rather than moving it to a notification bell — Owner is the
/// one COMPOSING announcements here, not just receiving them.
class OwnerShell extends StatelessWidget {
  const OwnerShell({super.key});

  static const _inactiveTint = Color(0xFFB8A99A);

  static const _systemBarStyle = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: CupertinoColors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Color(0x00000000),
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );

  static Widget _tabItem(IconData icon, String label, {required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            size: 20,
            color: active ? CupertinoColors.white : _inactiveTint,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
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
                switch (index) {
                  case 0:
                    return CupertinoTabView(
                      builder: (context) => const OwnerHomepageScreen(),
                    );
                  case 1:
                    return CupertinoTabView(
                      builder: (context) => const OwnerAssignmentsScreen(),
                    );
                  case 2:
                    return CupertinoTabView(
                      builder: (context) => const OwnerInventoryScreen(),
                    );
                  case 3:
                    return CupertinoTabView(
                      builder: (context) => const OwnerSalesPayrollScreen(),
                    );
                  default:
                    return CupertinoTabView(
                      builder: (context) => const OwnerMoreScreen(),
                    );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
