import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/feature_card.dart';

/// Home tab ng Admin Dashboard. Simpleng overview + quick-access shortcuts
/// para sa mga feature na wala nang sariling puwesto sa bottom nav o drawer
/// (Order History, Search Records).
class HomeTabScreen extends StatelessWidget {
  const HomeTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.82,
                children: [
                  FeatureCard(
                    title: 'Order History',
                    subtitle: 'Completed bilao orders',
                    icon: Icons.history_rounded,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Order History — coming soon'),
                        ),
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
                          content: Text('Search Records — coming soon'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
