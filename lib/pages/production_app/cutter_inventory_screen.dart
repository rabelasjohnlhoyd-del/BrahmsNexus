import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';

class CutterInventoryScreen extends StatefulWidget {
  const CutterInventoryScreen({super.key});

  @override
  State<CutterInventoryScreen> createState() => _CutterInventoryScreenState();
}

class _CutterInventoryScreenState extends State<CutterInventoryScreen> {
  final _meatLeftController = TextEditingController();
  
  // Packaging status: 0 = GOOD, 1 = LOW
  final Map<String, int> _packaging = {
    'Plastic Labo (1kg)': 0,
    'Plastic Sando Bag (10kg)': 0,
  };

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

  void _showStatusPicker(String name) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Status ng $name'),
        message: const Text('Piliin ang kasalukuyang dami ng stock.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _packaging[name] = 0);
              Navigator.pop(context);
            },
            child: const Text('Good Stock (Marami pa)'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              setState(() => _packaging[name] = 1);
              Navigator.pop(context);
            },
            child: const Text('Low Stock (Paubos na)'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
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
                label: 'Half-Cooked Meat',
                icon: CupertinoIcons.cube_box,
                large: true,
                subtitle: 'Remaining weight after portioning',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CupertinoColors.white, 
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('REMAINING WEIGHT (KG)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: _meatLeftController,
                      placeholder: '0.0',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.accent),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const StaffSectionHeader(
                label: 'Packaging Stocks',
                icon: CupertinoIcons.bag,
                large: true,
                subtitle: 'Plastic supplies monitor',
              ),
              const SizedBox(height: 16),
              ..._packaging.keys.map((name) => _buildPackagingRow(name)),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPackagingRow(String name) {
    final status = _packaging[name] ?? 0;
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
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                GestureDetector(
                  onTap: () => _showStatusPicker(name),
                  child: Row(
                    children: [
                      Text(status == 0 ? 'GOOD STOCK' : 'LOW STOCK', 
                        style: TextStyle(fontSize: 12, color: status == 0 ? AppColors.success : AppColors.error, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Icon(CupertinoIcons.chevron_down, size: 12, color: status == 0 ? AppColors.success : AppColors.error),
                    ],
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: () => _requestStock(name),
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            child: const Text('Request', style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
