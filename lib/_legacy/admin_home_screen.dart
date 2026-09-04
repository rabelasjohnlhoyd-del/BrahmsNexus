import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/feature_card.dart';
import '../auth/login_screen.dart';
import 'staff/staff_management_screen.dart';

/// Admin/Owner dashboard. Combines the major features from all three
/// merged project concepts: Bilao ordering, employee reporting, and
/// multi-branch sales/inventory management.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final features = <_FeatureItem>[
      _FeatureItem(
        title: 'Bilao Orders',
        subtitle: 'Schedule & monitor bilao orders',
        icon: Icons.ramen_dining_outlined,
      ),
      _FeatureItem(
        title: 'Order History',
        subtitle: 'Completed bilao orders',
        icon: Icons.history_rounded,
      ),
      _FeatureItem(
        title: 'Staff Management',
        subtitle: 'Manage employee accounts',
        icon: Icons.people_alt_outlined,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const StaffManagementScreen(),
            ),
          );
        },
      ),
      _FeatureItem(
        title: 'Branch Assignment',
        subtitle: 'Assign staff to branches',
        icon: Icons.store_mall_directory_outlined,
      ),
      _FeatureItem(
        title: 'Sales & Inventory',
        subtitle: 'Monitor sales and stock',
        icon: Icons.inventory_2_outlined,
      ),
      _FeatureItem(
        title: 'Employee Reports',
        subtitle: 'Review daily branch reports',
        icon: Icons.fact_check_outlined,
      ),
      _FeatureItem(
        title: 'Announcements',
        subtitle: 'Post instructions & reminders',
        icon: Icons.campaign_outlined,
      ),
      _FeatureItem(
        title: 'Search Records',
        subtitle: 'Find orders, reports & more',
        icon: Icons.search_rounded,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log out',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
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
                'Welcome back, Owner',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Here\'s an overview of your operations.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  itemCount: features.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                      onTap: item.onTap ??
                          () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${item.title} — coming soon'),
                              ),
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
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
}
