import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';

class CookInventoryScreen extends StatefulWidget {
  const CookInventoryScreen({super.key});

  @override
  State<CookInventoryScreen> createState() => _CookInventoryScreenState();
}

class _CookInventoryScreenState extends State<CookInventoryScreen> {
  final List<String> _ingredients = [
    'Toyo (1 Gallon)',
    'Asin (1 Sack)',
    'Paminta (1 Kilo)',
    'Vetsin (1 Kilo)',
    'Laurel (1 Kilo)',
    'Gasul (LPG Tank)',
  ];

  void _requestStock(String name) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Request Supply'),
        content: Text('Sigurado ka bang kailangan na ng bagong stock ng $name?'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Request for $name sent to Owner!')),
              );
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Inventory',
        trailing: StaffTopActions(),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const StaffSectionHeader(
              label: 'Ingredient Status',
              icon: CupertinoIcons.archivebox_fill,
              large: true,
              subtitle: 'Monitor and request supplies',
            ),
            const SizedBox(height: 16),
            ..._ingredients.map((name) => _buildIngredientRow(name)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientRow(String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StaffCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: const Icon(CupertinoIcons.archivebox, size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ),
            StaffButton(
              label: 'Request',
              onPressed: () => _requestStock(name),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ],
        ),
      ),
    );
  }
}

