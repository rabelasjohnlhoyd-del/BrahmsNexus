import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
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

/// Full Admin shell — WEB (may access din via phone browser, kaya
/// responsive ito). Sa malawak na screen (desktop/tablet), side
/// navigation ang ginagamit. Sa makitid na screen (phone browser),
/// nagiging Drawer (hamburger menu) ang parehong sidebar content, at
/// AppBar na lang ang laging makikita sa taas.
///
/// Ginamit ang Drawer sa halip na bottom nav sa narrow screens dahil
/// 10 ang sections — masyadong marami para sa isang bottom bar
/// (karaniwang 3-5 lang ang bagay dito), habang kasya lahat sa isang
/// scrollable na Drawer.
class AdminWebShell extends StatefulWidget {
  const AdminWebShell({super.key});

  @override
  State<AdminWebShell> createState() => _AdminWebShellState();
}

class _AdminWebShellState extends State<AdminWebShell> {
  int _selectedIndex = 0;

  /// Breakpoint: mas mababa dito (hal. phone browser) = Drawer layout.
  /// Mas malawak dito (desktop/tablet) = laging-nakikitang side-nav.
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

  static const _pages = [
    DashboardScreen(),
    StaffManagementScreen(),
    AccountApprovalsScreen(),
    BranchAssignmentsScreen(),
    InventoryScreen(),
    SalesPayrollScreen(),
    BilaoOrderScreen(),
    EmployeeReportsScreen(),
    AnnouncementsScreen(),
    AnalyticsScreen(),
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
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;

        if (isWide) {
          // --- DESKTOP / TABLET: laging-nakikitang side-nav ---
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Row(
              children: [
                AdminSidebar(
                  items: _items,
                  selectedIndex: _selectedIndex,
                  onSelect: (index) => setState(() => _selectedIndex = index),
                  onLogout: _handleLogout,
                ),
                Expanded(
                  child: SafeArea(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _pages,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // --- PHONE BROWSER: Drawer (hamburger menu) ---
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 1,
            iconTheme: const IconThemeData(color: AppColors.accent),
            title: Text(
              _items[_selectedIndex].label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          drawer: Drawer(
            child: AdminSidebar(
              items: _items,
              selectedIndex: _selectedIndex,
              onSelect: (index) {
                setState(() => _selectedIndex = index);
                Navigator.of(context).pop(); // isara ang drawer
              },
              onLogout: () {
                Navigator.of(context).pop(); // isara muna ang drawer
                _handleLogout();
              },
            ),
          ),
          body: SafeArea(
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),
        );
      },
    );
  }
}
