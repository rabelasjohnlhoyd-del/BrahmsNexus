import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/feature_card.dart';

/// Landing page of Admin Web — quick overview + shortcuts to
/// sections that no longer have their own spot in the sidebar (e.g.
/// Order History, Search Records).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome back, Owner',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Here\'s an overview of your operations.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth >= 700
                    ? 4
                    : constraints.maxWidth >= 420
                        ? 2
                        : 1;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: crossAxisCount == 1 ? 2.4 : 1.1,
                  children: [
                    FeatureCard(
                      title: 'Order History',
                      subtitle: 'Completed bilao orders',
                      icon: Icons.history_rounded,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Order History — coming soon')),
                        );
                      },
                    ),
                    FeatureCard(
                      title: 'Search Records',
                      subtitle: 'Find orders, reports & more',
                      icon: Icons.search_rounded,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Search Records — coming soon')),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
