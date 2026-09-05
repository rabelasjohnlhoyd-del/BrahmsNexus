import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show BottomNavigationBarItem;
import '../../theme/app_theme.dart';
import 'bilao_deliveries_screen.dart';
import 'homepage_screen.dart';
import 'route_screen.dart';
import 'stock_transfer_screen.dart';

/// Main shell ng Driver app — CupertinoTabScaffold na may 4 tabs
/// (Homepage, Route, Stock Transfer, Bilao Deliveries), sinusunod ang
/// iOS Human Interface Guidelines gamit ang totoong Cupertino widgets
/// (parehong pattern sa Staff/Cook app shell).
class DriverShell extends StatelessWidget {
  const DriverShell({super.key});

  @override
  Widget build(BuildContext context) {
    const cupertinoThemeData = CupertinoThemeData(
      primaryColor: AppColors.accent,
      scaffoldBackgroundColor: AppColors.background,
      barBackgroundColor: CupertinoColors.white,
    );

    return CupertinoTheme(
      data: cupertinoThemeData,
      // Builder + DefaultTextStyle: kailangan para tama ang na-iinherit
      // na font size ng lahat ng plain Text widgets (naka-loob tayo sa
      // MaterialApp, hindi CupertinoApp).
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
                  icon: Icon(CupertinoIcons.map_fill),
                  label: 'Route',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.arrow_2_squarepath),
                  label: 'Transfer',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.bag_fill),
                  label: 'Deliveries',
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
    );
  }
}
