import 'package:flutter/material.dart';
import 'admin_web_colors.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/admin_notifications_dialog.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/admin_top_bar.dart';
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

  void setActions(List<Widget> actions) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _currentActions = List.from(actions));
      }
    });
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

  List<Widget> get _pages => [
    DashboardScreen(onLogout: _handleLogout),
    const StaffManagementScreen(),
    const AccountApprovalsScreen(),
    const BranchAssignmentsScreen(),
    const InventoryScreen(),
    const SalesPayrollScreen(),
    const BilaoOrderScreen(),
    const EmployeeReportsScreen(),
    const AnnouncementsScreen(),
    const AnalyticsScreen(),
    const BranchManagementScreen(),
    const ActivityLogScreen(),
    const SystemSettingsScreen(),
  ];

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
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
              );
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _handleNavigateRoute(String route) {
    int targetIndex = 0;
    switch (route) {
      case 'account_approvals':
        targetIndex = 2; // Account Approvals
        break;
      case 'inventory':
        targetIndex = 4; // Inventory
        break;
      case 'announcements':
        targetIndex = 8; // Announcements
        break;
      case 'sales':
        targetIndex = 5; // Sales & Payroll
        break;
      default:
        targetIndex = 0;
    }
    setState(() {
      _selectedIndex = targetIndex;
      _currentActions = [];
      _customTitle = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AdminWebTheme.themeData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideBreakpoint;
          final currentPage = _pages[_selectedIndex];

          if (isWide) {
            // --- DESKTOP / TABLET: side-nav, no separate top bar —
            // each page (e.g. DashboardScreen's own header) owns its
            // title/subtitle/notification/profile row, so we don't
            // render a second duplicate bar above it here.
            return Scaffold(
              backgroundColor: AdminWebColors.background,
              body: Row(
                children: [
                  AdminSidebar(
                    items: _items,
                    selectedIndex: _selectedIndex,
                    onSelect: (index) =>
                        setState(() {
                          _selectedIndex = index;
                          _currentActions = [];
                          _customTitle = null;
                        }),
                    onLogout: _handleLogout,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        AdminTopBar(
                          title: _customTitle ?? _items[_selectedIndex].label,
                          subtitle: 'Brahms Nexus Management System',
                          onLogout: _handleLogout,
                          actions: _currentActions,
                          onNavigateRoute: _handleNavigateRoute,
                        ),
                        Expanded(
                          child: SafeArea(
                            child: Navigator(
                              key: ValueKey(_selectedIndex),
                              onGenerateRoute: (settings) => MaterialPageRoute(
                                builder: (context) => currentPage,
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
            );
          }

          // --- PHONE BROWSER: Drawer (hamburger menu) ---
          final pageTitle = _customTitle ?? _items[_selectedIndex].label;

          return Scaffold(
            backgroundColor: AdminWebColors.background,
            appBar: AppBar(
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AdminWebColors.headerStart, AdminWebColors.headerEnd],
                  ),
                ),
              ),
              elevation: 2,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                pageTitle.toUpperCase(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.8,
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
                                  color: Colors.white, size: 22),
                            )
                          : const Icon(Icons.notifications_outlined,
                              color: Colors.white, size: 22),
                    );
                  },
                ),
                PopupMenuButton<String>(
                  offset: const Offset(0, 45),
                  icon: const Icon(Icons.account_circle_rounded, color: Colors.white, size: 26),
                  onSelected: (value) {
                    if (value == 'logout') _handleLogout();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, size: 18, color: AdminWebColors.accent),
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
                          Icon(Icons.logout_rounded, size: 18, color: AdminWebColors.error),
                          SizedBox(width: 10),
                          Text('Log Out', style: TextStyle(color: AdminWebColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
            drawer: Drawer(
              child: AdminSidebar(
                items: _items,
                selectedIndex: _selectedIndex,
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
              child: Navigator(
                key: ValueKey(_selectedIndex),
                onGenerateRoute: (settings) => MaterialPageRoute(
                  builder: (context) => currentPage,
                  settings: settings,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

