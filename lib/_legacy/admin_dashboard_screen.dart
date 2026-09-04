import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'admin_drawer.dart';
import '../widgets/dss_chatbot_fab.dart';
import 'ios_style_bottom_nav.dart';
import '../pages/auth/login_screen.dart';
import '../pages/admin_web/bilao_orders/bilao_order_screen.dart';
import '../pages/admin_web/branch_assignments/branch_assignments_screen.dart';
import 'home_tab_screen.dart';
import '../pages/admin_web/sales_payroll/sales_payroll_screen.dart';

/// Ito ang MAIN SHELL ng Admin Dashboard.
/// Dito nakapaloob ang Bottom Nav, Drawer (burger menu), at ang
/// DSS Chatbot FAB — kaya makikita ito sa LAHAT ng tabs, dahil hindi
/// ito bahagi ng individual tab pages kundi ng outer Scaffold na ito.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Index 0-3 lang ang may kaakibat na tab. Index 4 (burger) ay
  // hindi na dapat pumasok dito — dini-drawer na lang siya.
  final List<Widget> _tabs = const [
    HomeTabScreen(),
    SalesPayrollScreen(),
    BranchAssignmentsScreen(),
    BilaoOrderScreen(),
  ];

  void _onNavTap(int index) {
    if (index == 4) {
      // Burger icon -> buksan ang Menu/Drawer (Announcements, Staff
      // Management, Employee Reports). HINDI ito nagpapalit ng tab.
      _scaffoldKey.currentState?.openEndDrawer();
      return;
    }
    setState(() => _selectedIndex = index);
  }

  void _handleLogout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openDssChatbot() {
    // Placeholder na modal para sa DSS Chatbot.
    // Palitan na lang ito ng aktwal na chatbot UI/logic mo.
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.pastelBrown,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(width: 20),
                const Icon(Icons.smart_toy_outlined, color: AppColors.accent),
                const SizedBox(width: 8),
                const Text(
                  'DSS Chatbot',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Ilagay dito ang DSS Chatbot conversation UI.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: const AdminDrawer(),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log out',
            onPressed: _handleLogout,
          ),
        ],
      ),
      // extendBody: true para "lumutang" nang maayos ang FAB sa ibabaw
      // ng bottom nav bar (walang gap/artifact sa pagitan).
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      floatingActionButton: DssChatbotFab(onTap: _openDssChatbot),
      floatingActionButtonLocation: const DssFabLocation(extraBottomOffset: 20),
      bottomNavigationBar: IosStyleBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
