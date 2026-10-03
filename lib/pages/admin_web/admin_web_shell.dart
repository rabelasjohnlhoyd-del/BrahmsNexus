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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowTutorial();
    });
  }

  Future<void> _maybeShowTutorial() async {
    final seen = await TutorialService.hasSeenTutorial('owner_spotlight');
    if (!seen && mounted) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      showTutorial();
    }
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

  void navigateToTab(int index, {int? inventoryTab}) {
    setState(() {
      _selectedIndex = index;
      _currentActions = [];
      _customTitle = null;
      if (inventoryTab != null) {
        _inventoryInitialTab = inventoryTab;
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

  int _inventoryInitialTab = 0;

  List<Widget> get _pages => [
    DashboardScreen(onLogout: _handleLogout),
    const StaffManagementScreen(),
    const AccountApprovalsScreen(),
    const BranchAssignmentsScreen(),
    InventoryScreen(initialTab: _inventoryInitialTab),
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
    switch (route) {
      case 'account_approvals':
        targetIndex = 2; // Account Approvals
        break;
      case 'inventory_dispatch':
        targetIndex = 4; // Inventory
        _inventoryInitialTab = 2; // Dispatch Logs
        break;
      case 'inventory_supply_requests':
        targetIndex = 4; // Inventory
        _inventoryInitialTab = 3; // Supply Requests
        break;
      case 'inventory':
        targetIndex = 4; // Inventory
        _inventoryInitialTab = 0;
        break;
      case 'sales':
        targetIndex = 5; // Sales & Payroll
        break;
      case 'employee_reports':
        targetIndex = 7; // Employee Reports
        break;
      case 'announcements':
        targetIndex = 8; // Announcements
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
                    isCollapsed: _isSidebarCollapsed,
                    itemKeys: _sidebarItemKeys,
                    onToggleCollapse: () =>
                        setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
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

