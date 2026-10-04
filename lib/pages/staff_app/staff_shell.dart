import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/deactivation_guard.dart';
import 'daily_report_screen.dart';
import 'homepage_screen.dart';
import 'profile_screen.dart';
import 'sales_screen.dart';
import 'staff_bilao_orders_screen.dart';

/// Main shell of the Cook/Staff app — a CupertinoTabScaffold with 4
/// tabs (Homepage, Sales, Daily Report, Timer), following iOS Human
/// Interface Guidelines with real Cupertino widgets.
///
/// The interactive guided tour (GuidedTourOverlay) is triggered
/// automatically from [HomepageScreen] on first launch, and continues
/// to [SalesScreen] via globalKey.currentState?.startTour().
class StaffShell extends StatefulWidget {
  const StaffShell({super.key});

  static final CupertinoTabController tabController = CupertinoTabController();
  static final GlobalKey salesTabKey = GlobalKey();
  static final GlobalKey bilaoTabKey = GlobalKey();
  static final GlobalKey reportTabKey = GlobalKey();

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  CupertinoTabController get tabController => StaffShell.tabController;

  static const _systemBarStyle = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Color(0x00000000),
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );

  @override
  Widget build(BuildContext context) {
    const cupertinoThemeData = CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.accent,
      scaffoldBackgroundColor: AppColors.background,
      barBackgroundColor: CupertinoColors.white,
    );

    final double bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return DeactivationGuard(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _systemBarStyle,
        child: CupertinoTheme(
          data: cupertinoThemeData,
          child: Builder(
            builder: (context) => DefaultTextStyle(
              style: CupertinoTheme.of(context).textTheme.textStyle,
              child: Stack(
                children: [
                  // ── Tab Scaffold with individual Navigators ─────────
                  MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      viewPadding: MediaQuery.of(context).viewPadding.copyWith(bottom: 0),
                      padding: MediaQuery.of(context).padding.copyWith(bottom: 0),
                    ),
                    child: CupertinoTabScaffold(
                      controller: tabController,
                      tabBar: CupertinoTabBar(
                        backgroundColor: const Color(0x00000000),
                        border: null,
                        height: 0,
                        items: const [
                          BottomNavigationBarItem(icon: SizedBox.shrink()),
                          BottomNavigationBarItem(icon: SizedBox.shrink()),
                          BottomNavigationBarItem(icon: SizedBox.shrink()),
                          BottomNavigationBarItem(icon: SizedBox.shrink()),
                          BottomNavigationBarItem(icon: SizedBox.shrink()),
                        ],
                      ),
                      tabBuilder: (context, index) {
                        Widget page;
                        switch (index) {
                          case 0:
                            page = HomepageScreen(key: HomepageScreen.globalKey);
                            break;
                          case 1:
                            page = SalesScreen(key: SalesScreen.globalKey);
                            break;
                          case 2:
                            page = StaffBilaoOrdersScreen(key: StaffBilaoOrdersScreen.globalKey);
                            break;
                          case 3:
                            page = DailyReportScreen(key: DailyReportScreen.globalKey);
                            break;
                          default:
                            page = const ProfileScreen(isRootTab: true);
                            break;
                        }

                        return CupertinoTabView(
                          builder: (ctx) => page,
                        );
                      },
                    ),
                  ),

                  // ── Floating Rounded Bottom Navigation Bar (iPhone Style) ──
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: bottomPadding > 0 ? bottomPadding : 12,
                    child: AnimatedBuilder(
                      animation: tabController,
                      builder: (context, _) {
                        final currentIndex = tabController.index;
                        return Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: CupertinoColors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.8),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: CupertinoColors.black.withValues(alpha: 0.08),
                                blurRadius: 18,
                                offset: const Offset(0, 5),
                              ),
                              BoxShadow(
                                color: AppColors.accentDark.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              _buildNavItem(
                                index: 0,
                                currentIndex: currentIndex,
                                activeIcon: CupertinoIcons.house_fill,
                                inactiveIcon: CupertinoIcons.house,
                                label: 'Home',
                              ),
                              _buildNavItem(
                                key: StaffShell.salesTabKey,
                                index: 1,
                                currentIndex: currentIndex,
                                activeIcon: CupertinoIcons.chart_bar_alt_fill,
                                inactiveIcon: CupertinoIcons.chart_bar_square,
                                label: 'Sales',
                              ),
                              _buildNavItem(
                                key: StaffShell.bilaoTabKey,
                                index: 2,
                                currentIndex: currentIndex,
                                activeIcon: CupertinoIcons.bag_fill,
                                inactiveIcon: CupertinoIcons.bag,
                                label: 'Bilao',
                              ),
                              _buildNavItem(
                                key: StaffShell.reportTabKey,
                                index: 3,
                                currentIndex: currentIndex,
                                activeIcon: CupertinoIcons.doc_text_fill,
                                inactiveIcon: CupertinoIcons.doc_text,
                                label: 'Report',
                              ),
                              _buildNavItem(
                                index: 4,
                                currentIndex: currentIndex,
                                activeIcon: CupertinoIcons.person_fill,
                                inactiveIcon: CupertinoIcons.person,
                                label: 'Profile',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildNavItem({
    required int index,
    required int currentIndex,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
    Key? key,
  }) {
    final bool active = index == currentIndex;

    return Expanded(
      key: key,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          StaffShell.tabController.index = index;
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.textPrimary.withValues(alpha: 0.08)
                    : const Color(0x00000000),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                active ? activeIcon : inactiveIcon,
                size: 19,
                color: active ? AppColors.textPrimary : const Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? AppColors.textPrimary : const Color(0xFF8E8E93),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

