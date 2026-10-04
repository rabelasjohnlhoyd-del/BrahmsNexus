import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/deactivation_guard.dart';
import '../staff_app/profile_screen.dart';
import 'cook_task_screen.dart';
import 'cook_inventory_screen.dart';
import 'cutter_portioning_screen.dart';
import 'cutter_inventory_screen.dart';

/// Main shell of the Production app — same floating rounded pill nav pattern
/// as staff_shell.dart for a consistent look across all mobile apps.
///
/// The interactive guided tour (GuidedTourOverlay) is triggered
/// automatically from [CookTaskScreen] (Production Cook) and
/// [CutterPortioningScreen] (Meat Cutter) on first launch — not here
/// in the shell — so it spotlights the real live widgets.
class ProductionShell extends StatefulWidget {
  const ProductionShell({
    super.key,
    required this.position,
  });

  final String position;

  static final CupertinoTabController tabController = CupertinoTabController();
  static final GlobalKey inventoryTabKey = GlobalKey();

  @override
  State<ProductionShell> createState() => _ProductionShellState();
}

class _ProductionShellState extends State<ProductionShell> {
  CupertinoTabController get tabController => ProductionShell.tabController;

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
    final isCook = widget.position == 'Production Cook';
    final double bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return DeactivationGuard(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                        ],
                      ),
                      tabBuilder: (context, index) {
                        Widget page;
                        switch (index) {
                          case 0:
                            page = isCook
                                ? CookTaskScreen(key: CookTaskScreen.globalKey)
                                : CutterPortioningScreen(key: CutterPortioningScreen.globalKey);
                            break;
                          case 1:
                            page = isCook
                                ? const CookInventoryScreen()
                                : const CutterInventoryScreen();
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
                                key: ProductionShell.inventoryTabKey,
                                index: 1,
                                currentIndex: currentIndex,
                                activeIcon: CupertinoIcons.archivebox_fill,
                                inactiveIcon: CupertinoIcons.archivebox,
                                label: 'Inventory',
                              ),
                              _buildNavItem(
                                index: 2,
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
          ProductionShell.tabController.index = index;
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
