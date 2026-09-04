import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/feature_card.dart';
import '../auth/login_screen.dart';
import 'attendance_scan_screen.dart';
import 'delivery_screen.dart';
import 'route_screen.dart';
import 'stock_transfer_screen.dart';

/// Driver — MOBILE. Nakikita dito: announcements ni owner, ruta base
/// sa branch assignment ng mga tagaluto, RFID attendance collection
/// habang nagli-libot, inter-branch stock transfer tasks (karne/gasul),
/// at bilao order deliveries.
class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

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
        title: 'Today\'s Route',
        subtitle: 'Branch sequence & pickups',
        icon: Icons.alt_route_rounded,
        builder: (_) => const RouteScreen(),
      ),
      _FeatureItem(
        title: 'Attendance',
        subtitle: 'Scan staff RFID along the route',
        icon: Icons.contactless_rounded,
        builder: (_) => const AttendanceScanScreen(),
      ),
      _FeatureItem(
        title: 'Stock Transfer',
        subtitle: 'Meat / gas requests from Owner',
        icon: Icons.local_shipping_outlined,
        builder: (_) => const StockTransferScreen(),
      ),
      _FeatureItem(
        title: 'Bilao Deliveries',
        subtitle: 'Orders for delivery today',
        icon: Icons.shopping_bag_outlined,
        builder: (_) => const DeliveryScreen(),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
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
                'Here\'s today\'s route and tasks.',
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
