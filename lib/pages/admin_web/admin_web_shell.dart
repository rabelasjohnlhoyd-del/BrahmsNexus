import 'dart:ui';
import 'package:flutter/material.dart';
import 'admin_web_colors.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/tutorial_service.dart';
import '../../widgets/admin_notifications_dialog.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/admin_top_bar.dart';
import '../../widgets/guided_tour_overlay.dart';
import '../auth/login_screen.dart';
import 'account_approvals/account_approvals_screen.dart';
import 'analytics/analytics_screen.dart';
import 'announcements/announcements_screen.dart';
import 'bilao_orders/bilao_order_screen.dart';
import 'branch_assignments/branch_assignments_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'employee_reports/employee_reports_screen.dart';
import 'inventory/inventory_screen.dart';
import 'sales_payroll/sales_payroll_screen.dart';
import 'staff_management/staff_management_screen.dart';
import 'branch_management/branch_management_screen.dart';
import 'activity_log/activity_log_screen.dart';
import 'settings/system_settings_screen.dart';
import 'admin_web_widgets/admin_messenger_dock.dart';
import 'bilao_orders/add_bilao_order_screen.dart';
import '../../models/bilao_order.dart';
import '../../services/system_busy_coordinator.dart';

class SmoothWebScrollBehavior extends MaterialScrollBehavior {
  const SmoothWebScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

/// Full Admin shell — WEB (also accessible via phone browser, hence
/// responsive). On a wide screen (desktop/tablet), just the side
/// navigation is shown — no separate top bar, since each page (e.g.
/// DashboardScreen) renders its own title/subtitle/notification/
/// profile row. On a narrow screen (phone browser), that same sidebar
/// content becomes a Drawer (hamburger menu), with a bare AppBar
/// (icon only, no title) always visible at the top just to expose the
/// drawer toggle.
///
/// A Drawer is used instead of a bottom nav on narrow screens because
/// there are 10 sections — too many for a bottom bar (which
/// comfortably fits only 3-5), while all of them fit in one
/// scrollable Drawer.
///
/// Everything under this shell is wrapped in [AdminWebTheme], so
/// standard Material widgets (AppBar, Card, TextField,
/// FloatingActionButton, Switch, etc.) on every admin page
/// automatically pick up the brown/beige 60-30-10 palette instead of
/// the old indigo [AdminTheme] (deprecated, no longer used here) or
/// the mobile Driver/Staff [AppColors] palette.
class AdminWebShell extends StatefulWidget {
  const AdminWebShell({super.key});

  @override
  State<AdminWebShell> createState() => AdminWebShellState();
}

class AdminWebShellState extends State<AdminWebShell> {
  int _selectedIndex = 0;
  String? _customTitle;
  List<Widget> _currentActions = [];
  bool _isSidebarCollapsed = false;

  /// Key for the nested page Navigator — used to push AddBilaoOrderScreen
  /// directly into the correct inner navigator (avoids white-screen bug
  /// caused by pushing on the root navigator while a nested Navigator widget
  /// with ValueKey(_selectedIndex) is in the tree).
  final GlobalKey<NavigatorState> _pageNavigatorKey = GlobalKey<NavigatorState>();

  // Sidebar item GlobalKeys — one per item (null = no spotlight for that item)
  // Indices match _items list: 0=Dashboard, 1=Staff, 2=Approvals, 3=Branch Assignments,
  // 4=Inventory, 5=Sales&Payroll, 6=Bilao, 7=Employee Reports, 8=Announcements,
  // 9=DSS Analytics, 10=Branch Management, 11=Activity Log, 12=System Settings
  final List<GlobalKey?> _sidebarItemKeys = List.generate(13, (i) {
    // Only create keys for the 4 spotlighted sidebar items
    if (i == 10 || i == 2 || i == 4 || i == 5) return GlobalKey();
    return null;
  });

  GlobalKey get _branchMgmtKey  => _sidebarItemKeys[10]!;
  GlobalKey get _approvalsKey   => _sidebarItemKeys[2]!;
  GlobalKey get _inventoryKey   => _sidebarItemKeys[4]!;
  GlobalKey get _salesPayrollKey => _sidebarItemKeys[5]!;


  @override
  void initState() {
    super.initState();
    // Disabled automatic pop-up of tutorial on launch.
    // The tour can still be accessed on-demand via System Settings.
  }

  void showTutorial() {
    GuidedTourOverlay.show(
      context: context,
      steps: [
        GuidedTourStep(
          targetKey: _branchMgmtKey,
          roleBadge: 'OWNER ONBOARDING',
          title: '1. Branch Status & Live Matrix',
          instruction: 'I-TAP: Piliin ang Branch Management sa sidebar.',
          explanation:
              'Dito makikita ang real-time status ng lahat ng 6 sangay — open/closed, cook attendance, at driver on-the-way alerts. Makikita rin ang RFID logs at live route status per branch.',
          tip: 'Gamitin ito tuwing umaga upang i-verify na nakapasok ang lahat ng cook sa tamang oras.',
        ),
        GuidedTourStep(
          targetKey: _approvalsKey,
          roleBadge: 'OWNER ONBOARDING',
          title: '2. Account Approvals — Staff Applicants',
          instruction: 'I-TAP: Piliin ang Account Approvals sa sidebar.',
          explanation:
              'Lahat ng bagong staff na nag-register ay pumupunta dito bilang "Pending." I-review ang aplikasyon, i-assign sa sangay at posisyon, at i-approve o i-reject. Wala silang access hanggang hindi mo pa na-approve.',
          tip: 'I-double check ang mobile number at role bago i-approve para maiwasan ang maling access.',
        ),
        GuidedTourStep(
          targetKey: _inventoryKey,
          roleBadge: 'OWNER ONBOARDING',
          title: '3. Inventory — Warehouse & Branch Restocking',
          instruction: 'I-TAP: Piliin ang Inventory sa sidebar.',
          explanation:
              'Pamahalaan ang warehouse stock ng karne, packaging, at condiments. Mag-dispatch ng supply sa mga sangay gamit ang transfer records. Lahat ng galaw ng produkto ay naka-log dito.',
          tip: 'Regular na i-update ang warehouse stock para makita ng production team ang aktwal na karga.',
        ),
        GuidedTourStep(
          targetKey: _salesPayrollKey,
          roleBadge: 'OWNER ONBOARDING',
          title: '4. Sales & Payroll — Revenue at Sahod',
          instruction: 'I-TAP: Piliin ang Sales & Payroll sa sidebar.',
          explanation:
              'Suriin ang daily sales bawat sangay, kalkulahin ang komisyon at sahod ng bawat empleyado, at mag-export ng payroll reports para sa accounting.',
          tip: 'Ang spoilage deductions ay awtomatikong idinaragdag sa payroll computation batay sa mga naiulat na cook.',
        ),
      ],
      onCompleted: () => TutorialService.markTutorialSeen('owner_spotlight'),
      onSkipped: () => TutorialService.markTutorialSeen('owner_spotlight'),
    );
  }

  void setActions(List<Widget> actions) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _currentActions = List.from(actions));
      }
    });
  }

  void navigateToTab(int index, {int? inventoryTab, int? activityLogTab}) {
    setState(() {
      _selectedIndex = index;
      _activatedIndices.add(index);
      _currentActions = [];
      _customTitle = null;
      if (inventoryTab != null) {
        _inventoryInitialTab = inventoryTab;
        _pageCache.remove(4);
      }
      if (activityLogTab != null) {
        _activityLogInitialTab = activityLogTab;
        _pageCache.remove(11);
      }
    });

    final nav = _pageNavigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }
  }

  void setTitle(String? title) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _customTitle != title) {
        setState(() => _customTitle = title);
      }
    });
  }

  /// Breakpoint: below this (e.g. phone browser) = Drawer layout.
  /// Above this (desktop/tablet) = always-visible side-nav + top bar.
  static const double _wideBreakpoint = 700;

  static const _items = [
    AdminSidebarItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    AdminSidebarItem(icon: Icons.groups_rounded, label: 'Staff Management'),
    AdminSidebarItem(
        icon: Icons.how_to_reg_rounded, label: 'Account Approvals'),
    AdminSidebarItem(
        icon: Icons.store_mall_directory_rounded,
        label: 'Branch Assignments'),
    AdminSidebarItem(icon: Icons.inventory_2_rounded, label: 'Inventory'),
    AdminSidebarItem(icon: Icons.payments_rounded, label: 'Sales & Payroll'),
    AdminSidebarItem(icon: Icons.shopping_bag_rounded, label: 'Bilao Orders'),
    AdminSidebarItem(
        icon: Icons.fact_check_rounded, label: 'Employee Reports'),
    AdminSidebarItem(icon: Icons.campaign_rounded, label: 'Announcements'),
    AdminSidebarItem(icon: Icons.insights_rounded, label: 'DSS Analytics'),
    AdminSidebarItem(icon: Icons.location_on_rounded, label: 'Branch Management'),
    AdminSidebarItem(icon: Icons.list_alt_rounded, label: 'Activity Log'),
    AdminSidebarItem(icon: Icons.settings_rounded, label: 'System Settings'),
  ];

  int _inventoryInitialTab = 0;
  int _activityLogInitialTab = 0;
  final Map<int, Widget> _pageCache = {};
  final Set<int> _activatedIndices = {0};

  Widget _getPage(int index) {
    return _pageCache.putIfAbsent(index, () {
      switch (index) {
        case 0:
          return DashboardScreen(onLogout: _handleLogout);
        case 1:
          return const StaffManagementScreen();
        case 2:
          return const AccountApprovalsScreen();
        case 3:
          return const BranchAssignmentsScreen();
        case 4:
          return InventoryScreen(initialTab: _inventoryInitialTab);
        case 5:
          return const SalesPayrollScreen();
        case 6:
          return const BilaoOrderScreen();
        case 7:
          return const EmployeeReportsScreen();
        case 8:
          return const AnnouncementsScreen();
        case 9:
          return const AnalyticsScreen();
        case 10:
          return const BranchManagementScreen();
        case 11:
          return ActivityLogScreen(initialTab: _activityLogInitialTab);
        case 12:
          return const SystemSettingsScreen();
        default:
          return DashboardScreen(onLogout: _handleLogout);
      }
    });
  }

  Widget _buildBodyIndexedStack() {
    return IndexedStack(
      index: _selectedIndex,
      children: List.generate(
        _items.length,
        (i) => _activatedIndices.contains(i)
            ? KeyedSubtree(
                key: ValueKey('admin_web_page_$i'),
                child: _getPage(i),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  void _handleLogout() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AdminWebColors.error),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await AuthService.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _showAdminProfile() {
    final user = AuthService.currentAppUser;
    final username = user?.username.isNotEmpty == true ? user!.username : 'admin';
    final fullName = user?.fullName.isNotEmpty == true ? user!.fullName : 'System Administrator';
    final role = user?.role.label ?? 'Admin / Owner';
    final email = AuthService.currentFirebaseUser?.email ?? '$username@brahmsnexus.ph';
    final contact = user?.contactNumber.isNotEmpty == true ? user!.contactNumber : 'N/A';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AdminWebColors.accent,
              foregroundColor: Colors.white,
              child: Text(user?.initials ?? 'A'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(role, style: const TextStyle(fontSize: 12, color: AdminWebColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 8),
            _profileRow(Icons.account_circle, 'Username', username),
            const SizedBox(height: 8),
            _profileRow(Icons.email_outlined, 'Email', email),
            const SizedBox(height: 8),
            _profileRow(Icons.phone_outlined, 'Contact', contact),
            const SizedBox(height: 8),
            _profileRow(Icons.verified_user_outlined, 'Status', user?.status.label ?? 'Active'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _profileRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AdminWebColors.accent),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, color: AdminWebColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _handleNavigateRoute(String route) {
    int targetIndex = 0;
    int? inventoryTab;
    int? activityLogTab;
    switch (route) {
      case 'account_approvals':
        targetIndex = 2;
        break;
      case 'inventory_dispatch':
        targetIndex = 11;
        activityLogTab = 1;
        break;
      case 'inventory_supply_requests':
        targetIndex = 4;
        inventoryTab = 2;
        break;
      case 'inventory':
        targetIndex = 4;
        break;
      case 'sales':
        targetIndex = 5;
        break;
      case 'employee_reports':
        targetIndex = 7;
        break;
      case 'announcements':
        targetIndex = 8;
        break;
      default:
        targetIndex = 0;
    }
    navigateToTab(targetIndex, inventoryTab: inventoryTab, activityLogTab: activityLogTab);
  }

  Future<void> _handleMessengerOrderParsed(dynamic parsedResult) async {
    // 1. Switch to Bilao Orders tab AND update the inner Navigator
    navigateToTab(6);

    // 2. Wait for the nested Navigator to build BilaoOrderScreen
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    final innerNav = _pageNavigatorKey.currentState;
    if (innerNav == null) return;

    // 3. Push AddBilaoOrderScreen INSIDE the nested page Navigator
    //    so that pop() returns cleanly to BilaoOrderScreen (no white screen).
    final newOrder = await innerNav.push<BilaoOrder>(
      MaterialPageRoute(
        builder: (ctx) => AddBilaoOrderScreen(
          initialParsedResult: parsedResult,
        ),
      ),
    );

    if (newOrder != null) {
      BilaoOrderScreen.onOrderAddedGlobally?.call(newOrder);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Order para kay ${newOrder.customerName} naitala nang maayos!'),
            backgroundColor: AdminWebColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AdminWebTheme.themeData,
      child: ScrollConfiguration(
        behavior: const SmoothWebScrollBehavior(),
        child: ValueListenableBuilder<bool>(
          valueListenable: SystemBusyCoordinator.isBusy,
          builder: (context, isBusy, _) {
            return AbsorbPointer(
              absorbing: isBusy,
              child: LayoutBuilder(
                builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _wideBreakpoint;

            if (isWide) {
              // --- DESKTOP / TABLET: side-nav, no separate top bar —
              // each page (e.g. DashboardScreen's own header) owns its
              // title/subtitle/notification/profile row, so we don't
              // render a second duplicate bar above it here.
              return Scaffold(
                backgroundColor: AdminWebColors.background,
                body: Stack(
                  children: [
                    Row(
                      children: [
                        AdminSidebar(
                          items: _items,
                          selectedIndex: _selectedIndex,
                          isCollapsed: _isSidebarCollapsed,
                          itemKeys: _sidebarItemKeys,
                          onToggleCollapse: () =>
                              setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                          onSelect: (index) => navigateToTab(index),
                          onLogout: _handleLogout,
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              AdminTopBar(
                                title: _customTitle ?? _items[_selectedIndex].label,
                                subtitle: 'Brahms Nexus Management System',
                                onLogout: _handleLogout,
                                onProfile: _showAdminProfile,
                                actions: _currentActions,
                                onNavigateRoute: _handleNavigateRoute,
                                showSidebarToggle: _isSidebarCollapsed,
                                onToggleSidebar: () =>
                                    setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                              ),
                              Expanded(
                                child: SafeArea(
                                  child: Navigator(
                                    key: _pageNavigatorKey,
                                    onGenerateRoute: (settings) => MaterialPageRoute(
                                      builder: (context) => _buildBodyIndexedStack(),
                                      settings: settings,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  AdminMessengerDock(
                    onOrderParsed: _handleMessengerOrderParsed,
                  ),
                ],
              ),
            );
          }

          // --- PHONE BROWSER: Drawer (hamburger menu) ---
          final pageTitle = _customTitle ?? _items[_selectedIndex].label;

          return Scaffold(
            backgroundColor: AdminWebColors.background,
            appBar: AppBar(
              backgroundColor: AdminWebColors.background,
              elevation: 0,
              iconTheme: const IconThemeData(color: AdminWebColors.textPrimary),
              title: Text(
                pageTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AdminWebColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  color: AdminWebColors.border.withValues(alpha: 0.7),
                  height: 1,
                ),
              ),
              actions: [
                StreamBuilder<int>(
                  stream: NotificationService.watchUnreadCount(
                    role: 'owner',
                    userId: AuthService.currentUserId,
                  ),
                  builder: (context, snapshot) {
                    final unread = snapshot.data ?? 0;
                    return IconButton(
                      tooltip: 'Notifications',
                      onPressed: () => AdminNotificationsDialog.show(
                        context,
                        onNavigateRoute: _handleNavigateRoute,
                      ),
                      icon: unread > 0
                          ? Badge(
                              label: Text('$unread'),
                              backgroundColor: AdminWebColors.warning,
                              child: const Icon(Icons.notifications_rounded,
                                  color: AdminWebColors.textPrimary, size: 22),
                            )
                          : const Icon(Icons.notifications_outlined,
                              color: AdminWebColors.textPrimary, size: 22),
                    );
                  },
                ),
                PopupMenuButton<String>(
                  offset: const Offset(0, 45),
                  icon: const Icon(Icons.account_circle_rounded,
                      color: AdminWebColors.textPrimary, size: 26),
                  onSelected: (value) {
                    if (value == 'logout') _handleLogout();
                    if (value == 'profile') _showAdminProfile();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: 18, color: AdminWebColors.accent),
                          SizedBox(width: 10),
                          Text('Admin Profile'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded,
                              size: 18, color: AdminWebColors.error),
                          SizedBox(width: 10),
                          Text('Log Out',
                              style: TextStyle(color: AdminWebColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
            drawer: Drawer(
              width: 260,
              backgroundColor: Colors.white,
              child: AdminSidebar(
                items: _items,
                selectedIndex: _selectedIndex,
                itemKeys: _sidebarItemKeys,
                onToggleCollapse: () => Navigator.of(context).pop(),
                onSelect: (index) {
                  setState(() {
                    _selectedIndex = index;
                    _currentActions = [];
                    _customTitle = null;
                  });
                  Navigator.of(context).pop(); // close the drawer
                },
                onLogout: () {
                  Navigator.of(context).pop(); // close the drawer first
                  _handleLogout();
                },
              ),
            ),
            body: SafeArea(
              child: Stack(
                children: [
                  _buildBodyIndexedStack(),
                  AdminMessengerDock(
                    onOrderParsed: _handleMessengerOrderParsed,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  },
),
),
);
}
}

