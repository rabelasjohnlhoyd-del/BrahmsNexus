import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/feature_card.dart';
import '../pages/auth/login_screen.dart';
import 'staff_announcements_screen.dart';
import 'my_assignment_screen.dart';
import 'submit_inventory_screen.dart';
import 'submit_report_screen.dart';
import 'submit_sales_screen.dart';

/// Branch Employee/Staff — MOBILE. Covers the employee-facing features:
/// viewing branch assignment, submitting daily sales/inventory/reports,
/// and viewing announcements.
class StaffHomeScreen extends StatelessWidget {
  const StaffHomeScreen({super.key});

  void _handleLogout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final features = <_FeatureItem>[
      _FeatureItem(
        title: 'Today\'s Assignment',
        subtitle: 'View branch & work status',
        icon: Icons.today_outlined,
        builder: (_) => const MyAssignmentScreen(),
      ),
      _FeatureItem(
        title: 'Submit Sales',
        subtitle: 'Record daily sales',
        icon: Icons.point_of_sale_outlined,
        builder: (_) => const SubmitSalesScreen(),
      ),
      _FeatureItem(
        title: 'Submit Inventory',
        subtitle: 'Record remaining stock',
        icon: Icons.inventory_outlined,
        builder: (_) => const SubmitInventoryScreen(),
      ),
      _FeatureItem(
        title: 'Daily Report',
        subtitle: 'Submit operational report',
        icon: Icons.description_outlined,
        builder: (_) => const SubmitReportScreen(),
      ),
      _FeatureItem(
        title: 'Announcements',
        subtitle: 'View admin instructions',
        icon: Icons.campaign_outlined,
        builder: (_) => const StaffAnnouncementsScreen(),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Staff Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log out',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Here\'s what you can do today.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  itemCount: features.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, index) {
                    final item = features[index];
                    return FeatureCard(
                      title: item.title,
                      subtitle: item.subtitle,
                      icon: item.icon,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: item.builder),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem {
  const _FeatureItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
}
