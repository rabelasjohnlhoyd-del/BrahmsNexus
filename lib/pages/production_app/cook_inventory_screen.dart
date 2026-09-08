import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';

class CookInventoryScreen extends StatefulWidget {
  const CookInventoryScreen({super.key});

  @override
  State<CookInventoryScreen> createState() => _CookInventoryScreenState();
}

class _CookInventoryScreenState extends State<CookInventoryScreen> {
  final Map<String, int> _ingredients = {
    'Toyo (1 Gallon)': 0,
    'Asin (1 Sack)': 0,
    'Paminta (1 Kilo)': 0,
    'Vetsin (1 Kilo)': 0,
    'Laurel (1 Kilo)': 0,
    'Gasul (LPG Tank)': 0,
  };

  void _requestStock(String name) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Request Supply'),
        content: Text('Sigurado ka bang kailangan na ng bagong stock ng $name?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
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
    return Column(
      children: [
        const StaffNavBar(
          title: 'Inventory',
          trailing: const StaffTopActions(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const StaffSectionHeader(
                label: 'Ingredient Status',
                icon: CupertinoIcons.archivebox,
                large: true,
                subtitle: 'Monitor and request supplies',
              ),
              const SizedBox(height: 16),
              ..._ingredients.keys.map((name) => _buildIngredientRow(name)),
              const SizedBox(height: 24),
              const StaffSectionHeader(
                label: 'Actions',
                icon: CupertinoIcons.bell,
                large: true,
                subtitle: 'Quick notify owner',
              ),
              const SizedBox(height: 12),
              CupertinoButton.filled(
                onPressed: () {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Owner has been notified of low stocks.')),
                  );
                },
                child: const Text('SEND LOW STOCK ALERT'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientRow(String name) {
    final status = _ingredients[name] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                Text(
                  _getStatusText(status),
                  style: TextStyle(fontSize: 12, color: _getStatusColor(status), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showStatusPicker(name),
            child: Icon(CupertinoIcons.ellipsis_circle, color: AppColors.accent),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: () => _requestStock(name),
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            child: const Text('Request', style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showStatusPicker(String name) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Status ng $name'),
        actions: [
          CupertinoActionSheetAction(onPressed: () { setState(() => _ingredients[name] = 0); Navigator.pop(context); }, child: const Text('Good Stock')),
          CupertinoActionSheetAction(onPressed: () { setState(() => _ingredients[name] = 1); Navigator.pop(context); }, child: const Text('Low Stock')),
          CupertinoActionSheetAction(onPressed: () { setState(() => _ingredients[name] = 2); Navigator.pop(context); }, isDestructiveAction: true, child: const Text('Out of Stock')),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ),
    );
  }

  String _getStatusText(int status) {
    if (status == 0) return 'GOOD';
    if (status == 1) return 'LOW';
    return 'OUT';
  }

  Color _getStatusColor(int status) {
    if (status == 0) return AppColors.success;
    if (status == 1) return AppColors.warning;
    return AppColors.error;
  }
}
