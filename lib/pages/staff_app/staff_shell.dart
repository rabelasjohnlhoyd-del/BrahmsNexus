import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show BottomNavigationBarItem;
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

  @override
  Widget build(BuildContext context) {
    const cupertinoThemeData = CupertinoThemeData(
      primaryColor: AppColors.accent,
      scaffoldBackgroundColor: AppColors.background,
      barBackgroundColor: CupertinoColors.white,
    );

    return CupertinoTheme(
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
              activeColor: AppColors.accent,
              inactiveColor: AppColors.pastelBrown,
              backgroundColor: CupertinoColors.white,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.house_fill),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.chart_bar_alt_fill),
                  label: 'Sales',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.doc_text_fill),
                  label: 'Report',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.timer_fill),
                  label: 'Timer',
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
    );
  }
}
