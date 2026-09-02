import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/feature_card.dart';
import '../auth/login_screen.dart';

/// Branch Employee/Staff dashboard. Covers the employee-facing features:
/// viewing branch assignment, submitting daily sales/inventory and
/// reports, and viewing announcements.
class EmployeeHomeScreen extends StatelessWidget {
  const EmployeeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final features = <_FeatureItem>[
      _FeatureItem(
        title: 'Today\'s Assignment',
        subtitle: 'View branch & work status',
        icon: Icons.today_outlined,
      ),
      _FeatureItem(
        title: 'Submit Sales',
        subtitle: 'Record daily sales',
        icon: Icons.point_of_sale_outlined,
      ),
      _FeatureItem(
        title: 'Submit Inventory',
        subtitle: 'Record remaining stock',
        icon: Icons.inventory_outlined,
      ),
      _FeatureItem(
        title: 'Daily Report',
        subtitle: 'Submit operational report',
        icon: Icons.description_outlined,
      ),
      _FeatureItem(
        title: 'Announcements',
        subtitle: 'View admin instructions',
        icon: Icons.campaign_outlined,
      ),
      _FeatureItem(
        title: 'My History',
        subtitle: 'Past submissions & assignments',
        icon: Icons.history_rounded,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Dashboard'),
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
                      onTap: () {
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
  });

  final String title;
  final String subtitle;
  final IconData icon;
}
