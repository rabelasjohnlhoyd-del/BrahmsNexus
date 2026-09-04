import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/feature_card.dart';
import '../auth/login_screen.dart';
import 'inventory_monitor_screen.dart';
import 'reports_monitor_screen.dart';

/// Owner/Admin — MOBILE. Narrower kaysa sa Admin Web: monitoring lang
/// ng Employee Reports at Staff Inventory, hindi full admin control
/// (ibang buong feature set ay nasa Admin Web na lang).
class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  void _handleLogout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
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
                'Welcome back, Owner',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Monitor branch reports and inventory on the go.',
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
                      title: 'Employee Reports',
                      subtitle: 'Monitor daily branch reports',
                      icon: Icons.fact_check_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ReportsMonitorScreen(),
                          ),
                        );
                      },
                    ),
                    FeatureCard(
                      title: 'Staff Inventory',
                      subtitle: 'Monitor branch stock levels',
                      icon: Icons.inventory_2_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const InventoryMonitorScreen(),
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
      ),
    );
  }
}
