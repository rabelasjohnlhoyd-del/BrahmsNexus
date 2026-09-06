import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import 'bilao_deliveries_screen.dart';
import 'homepage_screen.dart';
import 'route_screen.dart';
import 'stock_transfer_screen.dart';

/// Main shell of the Driver app — a CupertinoTabScaffold with 4 tabs
/// (Homepage, Route, Stock Transfer, Bilao Deliveries), following iOS
/// Human Interface Guidelines with real Cupertino widgets (same
/// pattern as the Staff/Cook app shell — see staff_shell.dart).
class DriverShell extends StatelessWidget {
  const DriverShell({super.key});

  /// Muted, clearly "not selected" tint for inactive tabs — kept far
  /// enough from [AppColors.accent] that the active tab is obvious at
  /// a glance instead of both states reading as "brown".
  static const _inactiveTint = Color(0xFFB8A99A);

  /// Solid white/light status bar + gesture-nav bar treatment for the
  /// whole Driver section — mirrors staff_shell.dart so both apps
  /// behave identically instead of being left to Android's defaults
  /// (which could auto-recolor the bars while scrolling).
  static const _systemBarStyle = SystemUiOverlayStyle(
    // The Driver header (DriverNavBar) is a solid dark-brown gradient
    // and sits directly under the status bar, so status bar icons
    // need to be light/white here to stay readable against it.
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: CupertinoColors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Color(0x00000000),
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );

  /// Tab icon + label as one unit with a soft pill background when
  /// active — the at-a-glance "you are here" indicator. Mirrors
  /// staff_shell.dart's _tabItem so both apps' tab bars behave and
  /// look identically instead of relying on CupertinoTabBar's
  /// automatic (and easy-to-miss) label coloring alone.
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
    const cupertinoThemeData = CupertinoThemeData(
      // Forcing this explicitly matters: without it, Cupertino
      // estimates light/dark from the primary color, and our fairly
      // dark accent brown was being misread as a "dark theme" —
      // silently flipping default text (nav titles, placeholders,
      // etc) to pale colors with almost no contrast on our light
      // background. See widgets/driver_nav_bar.dart for more detail.
      brightness: Brightness.light,
      primaryColor: AppColors.accent,
      scaffoldBackgroundColor: AppColors.background,
      barBackgroundColor: CupertinoColors.white,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemBarStyle,
      child: CupertinoTheme(
        data: cupertinoThemeData,
        // Builder + DefaultTextStyle: needed so ALL plain Text
        // widgets inside inherit the correct font size (without
        // this, font sizes come out wrong/too large since we're
        // nested inside a MaterialApp, not a CupertinoApp).
        child: Builder(
          builder: (context) => DefaultTextStyle(
            style: CupertinoTheme.of(context).textTheme.textStyle,
            child: CupertinoTabScaffold(
              tabBar: CupertinoTabBar(
                backgroundColor: CupertinoColors.white,
                // A little taller than the iOS default 50px so the
                // icon+label pill has room to breathe without clipping.
                height: 62,
                // Explicit top hairline so the bar reads as a clearly
                // separate, solid surface from whatever is scrolling
                // behind it, instead of the default near-invisible one.
                border: const Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
                items: [
                  BottomNavigationBarItem(
                    icon: _tabItem(CupertinoIcons.house_fill, 'Home', active: false),
                    activeIcon: _tabItem(CupertinoIcons.house_fill, 'Home', active: true),
                  ),
                  BottomNavigationBarItem(
                    icon: _tabItem(CupertinoIcons.map_fill, 'Route', active: false),
                    activeIcon: _tabItem(CupertinoIcons.map_fill, 'Route', active: true),
                  ),
                  BottomNavigationBarItem(
                    icon: _tabItem(CupertinoIcons.arrow_2_squarepath, 'Transfer', active: false),
                    activeIcon: _tabItem(CupertinoIcons.arrow_2_squarepath, 'Transfer', active: true),
                  ),
                  BottomNavigationBarItem(
                    icon: _tabItem(CupertinoIcons.bag_fill, 'Deliveries', active: false),
                    activeIcon: _tabItem(CupertinoIcons.bag_fill, 'Deliveries', active: true),
                  ),
                ],
              ),
              tabBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return CupertinoTabView(
                      builder: (context) => const DriverHomepageScreen(),
                    );
                  case 1:
                    return CupertinoTabView(
                      builder: (context) => const RouteScreen(),
                    );
                  case 2:
                    return CupertinoTabView(
                      builder: (context) => const StockTransferScreen(),
                    );
                  default:
                    return CupertinoTabView(
                      builder: (context) => const BilaoDeliveriesScreen(),
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
