import 'package:flutter/material.dart';
import 'admin_web_colors.dart';
import '../../widgets/admin_sidebar.dart';
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
  State<AdminWebShell> createState() => _AdminWebShellState();
}

class _AdminWebShellState extends State<AdminWebShell> {
  int _selectedIndex = 0;

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
                  SizedBox(
                    width: 260,
                    child: AdminSidebar(
                      items: _items,
                      selectedIndex: _selectedIndex,
                      onSelect: (index) =>
                          setState(() => _selectedIndex = index),
                      onLogout: _handleLogout,
                    ),
                  ),
                  Expanded(
                    child: SafeArea(
                      child: currentPage,
                    ),
                  ),
                ],
              ),
            );
          }

          // --- PHONE BROWSER: Drawer (hamburger menu) ---
          // No title text here — the page itself (e.g. DashboardScreen's
          // own header) already shows the title/subtitle/notification/
          // profile row, so this bar only needs to expose the drawer
          // toggle. A bare AppBar with a drawer set automatically gets
          // the hamburger icon from Scaffold, so nothing else is drawn.
          return Scaffold(
            backgroundColor: AdminWebColors.background,
            appBar: AppBar(
              backgroundColor: AdminWebColors.background,
              elevation: 1,
              iconTheme: const IconThemeData(color: AdminWebColors.accent),
              titleSpacing: 0,
            ),
            drawer: Drawer(
              child: AdminSidebar(
                items: _items,
                selectedIndex: _selectedIndex,
                onSelect: (index) {
                  setState(() => _selectedIndex = index);
                  Navigator.of(context).pop(); // close the drawer
                },
                onLogout: () {
                  Navigator.of(context).pop(); // close the drawer first
                  _handleLogout();
                },
              ),
            ),
            body: SafeArea(
              child: currentPage,
            ),
          );
        },
      ),
    );
  }
}
