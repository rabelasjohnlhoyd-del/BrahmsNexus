import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../staff_app/profile_screen.dart';
import 'cook_task_screen.dart';
import 'cook_inventory_screen.dart';
import 'cutter_portioning_screen.dart';
import 'cutter_inventory_screen.dart';

class ProductionShell extends StatelessWidget {
  const ProductionShell({
    super.key,
    required this.position,
  });

  final String position;

  static const _systemBarStyle = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: CupertinoColors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Color(0x00000000),
  );

  static const _inactiveTint = Color(0xFFB8A99A);

  static Widget _tabItem(IconData icon, String label, {required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
    final isCook = position == 'Production Area Cook';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemBarStyle,
      child: CupertinoTheme(
        data: const CupertinoThemeData(
          brightness: Brightness.light,
          primaryColor: AppColors.accent,
          scaffoldBackgroundColor: AppColors.background,
          barBackgroundColor: CupertinoColors.white,
        ),
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
                    icon: _tabItem(CupertinoIcons.archivebox_fill, 'Inventory', active: false),
                    activeIcon: _tabItem(CupertinoIcons.archivebox_fill, 'Inventory', active: true),
                  ),
                  BottomNavigationBarItem(
                    icon: _tabItem(CupertinoIcons.person_fill, 'Profile', active: false),
                    activeIcon: _tabItem(CupertinoIcons.person_fill, 'Profile', active: true),
                  ),
                ],
              ),
              tabBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return CupertinoTabView(
                      builder: (context) => isCook ? const CookTaskScreen() : const CutterPortioningScreen(),
                    );
                  case 1:
                    return CupertinoTabView(
                      builder: (context) => isCook ? const CookInventoryScreen() : const CutterInventoryScreen(),
                    );
                  case 2:
                    return CupertinoTabView(
                      builder: (context) => const ProfileScreen(isRootTab: true),
                    );
                  default:
                    return CupertinoTabView(
                      builder: (context) => isCook ? const CookTaskScreen() : const CutterPortioningScreen(),
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

