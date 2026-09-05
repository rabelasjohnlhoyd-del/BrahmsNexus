import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show BottomNavigationBarItem;
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import 'daily_report_screen.dart';
import 'homepage_screen.dart';
import 'sales_screen.dart';
import 'timer_screen.dart';

/// Main shell ng Cook/Staff app — CupertinoTabScaffold na may 4 tabs
/// (Homepage, Sales, Daily Report, Timer), sinusunod ang iOS Human
/// Interface Guidelines gamit ang totoong Cupertino widgets.
///
/// Ang Announcements ay wala nang sariling tab — pinalitan ito ng
/// notification bell + profile avatar sa itaas ng bawat tab
/// (see widgets/staff_top_actions.dart).
class StaffShell extends StatelessWidget {
  const StaffShell({super.key});

  /// Muted, clearly "not selected" tint for inactive tabs — kept far
  /// enough from [AppColors.accent] that the active tab is obvious at
  /// a glance instead of both states reading as "brown".
  static const _inactiveTint = Color(0xFFB8A99A);

  /// Solid white/light status bar + gesture-nav bar treatment for the
  /// whole Staff section. Set explicitly (rather than left to Android's
  /// defaults) so the bars can't be auto-recolored by the OS while
  /// scrolling — see main.dart for the app-wide baseline this overrides.
  static const _systemBarStyle = SystemUiOverlayStyle(
    // The Staff header (StaffNavBar) is solid accent brown and sits
    // directly under the status bar, so status bar icons need to be
    // light/white here to stay readable against it.
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
  /// active — the at-a-glance "you are here" indicator. Built as a
  /// single custom widget (rather than relying on CupertinoTabBar's
  /// automatic label coloring alone) so active vs inactive is obvious
  /// from icon color, label weight, and background all at once instead
  /// of a single subtle color shift that's easy to miss mid-scroll.
  static Widget _tabItem(IconData icon, String label, {required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.accent.withValues(alpha: 0.14) : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: active ? AppColors.accent : _inactiveTint,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              height: 1.0,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppColors.accent : _inactiveTint,
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
      // background. See widgets/staff_nav_bar.dart for more detail.
      brightness: Brightness.light,
      primaryColor: AppColors.accent,
      scaffoldBackgroundColor: AppColors.background,
      barBackgroundColor: CupertinoColors.white,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemBarStyle,
      child: CupertinoTheme(
        data: cupertinoThemeData,
        // Builder + DefaultTextStyle: kailangan ito para tama ang
        // na-iinherit na font size ng LAHAT ng plain Text widgets sa
        // loob (kung wala ito, malaki/mali ang laki ng font dahil naka-
        // loob tayo sa isang MaterialApp, hindi CupertinoApp).
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
                    icon: _tabItem(CupertinoIcons.chart_bar_alt_fill, 'Sales', active: false),
                    activeIcon: _tabItem(CupertinoIcons.chart_bar_alt_fill, 'Sales', active: true),
                  ),
                  BottomNavigationBarItem(
                    icon: _tabItem(CupertinoIcons.doc_text_fill, 'Report', active: false),
                    activeIcon: _tabItem(CupertinoIcons.doc_text_fill, 'Report', active: true),
                  ),
                  BottomNavigationBarItem(
                    icon: _tabItem(CupertinoIcons.timer_fill, 'Timer', active: false),
                    activeIcon: _tabItem(CupertinoIcons.timer_fill, 'Timer', active: true),
                  ),
                ],
              ),
              tabBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return CupertinoTabView(
                      builder: (context) => const HomepageScreen(),
                    );
                  case 1:
                    return CupertinoTabView(
                      builder: (context) => const SalesScreen(),
                    );
                  case 2:
                    return CupertinoTabView(
                      builder: (context) => const DailyReportScreen(),
                    );
                  default:
                    return CupertinoTabView(
                      builder: (context) => const TimerScreen(),
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
