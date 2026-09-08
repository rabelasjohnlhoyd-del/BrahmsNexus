import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../staff_app/profile_screen.dart';
import 'cook_task_screen.dart';
import 'cutter_portioning_screen.dart';

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
  );

  static const _inactiveTint = Color(0xFFB8A99A);

  static Widget _tabItem(IconData icon, String label, {required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.textPrimary : null,
        borderRadius: BorderRadius.circular(12),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              height: 1.1,
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
        ),
        child: Builder(
          builder: (context) => DefaultTextStyle(
            style: CupertinoTheme.of(context).textTheme.textStyle,
            child: CupertinoTabScaffold(
              tabBar: CupertinoTabBar(
                backgroundColor: CupertinoColors.white,
                height: 56,
                border: const Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
                items: isCook ? _cookTabs() : _cutterTabs(),
              ),
              tabBuilder: (context, index) {
                return CupertinoTabView(
                  builder: (context) => isCook 
                      ? _cookPages(index) 
                      : _cutterPages(index),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<BottomNavigationBarItem> _cookTabs() {
    return [
      BottomNavigationBarItem(
        icon: _tabItem(CupertinoIcons.house_fill, 'Home', active: false),
        activeIcon: _tabItem(CupertinoIcons.house_fill, 'Home', active: true),
      ),
      BottomNavigationBarItem(
        icon: _tabItem(CupertinoIcons.person_fill, 'Profile', active: false),
        activeIcon: _tabItem(CupertinoIcons.person_fill, 'Profile', active: true),
      ),
    ];
  }

  Widget _cookPages(int index) {
    switch (index) {
      case 0: return const CookTaskScreen();
      case 1: return const ProfileScreen(isRootTab: true);
      default: return const CookTaskScreen();
    }
  }

  List<BottomNavigationBarItem> _cutterTabs() {
    return [
      BottomNavigationBarItem(
        icon: _tabItem(CupertinoIcons.house_fill, 'Home', active: false),
        activeIcon: _tabItem(CupertinoIcons.house_fill, 'Home', active: true),
      ),
      BottomNavigationBarItem(
        icon: _tabItem(CupertinoIcons.person_fill, 'Profile', active: false),
        activeIcon: _tabItem(CupertinoIcons.person_fill, 'Profile', active: true),
      ),
    ];
  }

  Widget _cutterPages(int index) {
    switch (index) {
      case 0: return const CutterPortioningScreen();
      case 1: return const ProfileScreen(isRootTab: true);
      default: return const CutterPortioningScreen();
    }
  }
}
