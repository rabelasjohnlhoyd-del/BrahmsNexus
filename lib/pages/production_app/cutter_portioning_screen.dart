import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';

class CutterPortioningScreen extends StatefulWidget {
  const CutterPortioningScreen({super.key});

  @override
  State<CutterPortioningScreen> createState() => _CutterPortioningScreenState();
}

class _CutterPortioningScreenState extends State<CutterPortioningScreen> {
  final Map<String, int> _targets = {
    '250g': 150,
    '300g': 100,
    '400g': 100,
  };

  final Map<String, TextEditingController> _controllers = {
    '250g': TextEditingController(text: '0'),
    '300g': TextEditingController(text: '0'),
    '400g': TextEditingController(text: '0'),
  };

  final _meatLeftController = TextEditingController();
  
  // Packaging status: 0 = GOOD, 1 = LOW
  final Map<String, int> _packaging = {
    'Plastic Labo (1kg)': 0,
    'Plastic Sando Bag (10kg)': 0,
  };

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _meatLeftController.dispose();
    super.dispose();
  }

  void _submitPortions() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Submit Report'),
        content: const Text('Sigurado ka bang tama ang lahat ng portion counts at inventory report?'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report submitted to Owner!')),
              );
              setState(() {
                for (var controller in _controllers.values) {
                  controller.text = '0';
                }
                _meatLeftController.clear();
              });
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

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
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _packaging[name] = 0);
              Navigator.pop(context);
            },
            child: const Text('Good Stock'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              setState(() => _packaging[name] = 1);
              Navigator.pop(context);
            },
            child: const Text('Low Stock'),
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
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Home',
        mode: StaffHeaderMode.greeting,
        greetingName: 'Abby',
        trailing: StaffTopActions(),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const StaffSectionHeader(
              label: 'Meat Portioning',
              icon: CupertinoIcons.scissors_alt,
              large: true,
              subtitle: 'Enter final counts per size',
            ),
            const SizedBox(height: 14),
            _buildPortionInputCard('250g'),
            const SizedBox(height: 12),
            _buildPortionInputCard('300g'),
            const SizedBox(height: 12),
            _buildPortionInputCard('400g'),
            const SizedBox(height: 26),
            const StaffSectionHeader(
              label: 'Half-Cooked Meat',
              icon: CupertinoIcons.cube_box_fill,
              large: true,
              subtitle: 'Weight after portioning',
            ),
            const SizedBox(height: 14),
            StaffCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'REMAINING WEIGHT (KG)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: _meatLeftController,
                    placeholder: '0.0',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accent,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const StaffSectionHeader(
              label: 'Packaging Stocks',
              icon: CupertinoIcons.bag_fill,
              large: true,
              subtitle: 'Plastic supplies monitor',
            ),
            const SizedBox(height: 14),
            ..._packaging.keys.map((name) => _buildPackagingRow(name)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: StaffButton(
                label: 'SUBMIT REPORT',
                onPressed: _submitPortions,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPortionInputCard(String size) {
    final target = _targets[size] ?? 0;
    final controller = _controllers[size]!;
    int current = int.tryParse(controller.text) ?? 0;
    bool isDone = current >= target;

    return StaffCard(
      padding: const EdgeInsets.all(18),
      highlighted: isDone,
      borderColor: isDone ? AppColors.success : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  size,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Target: $target pcs',
                  style: TextStyle(
                    color: isDone ? AppColors.success : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: CupertinoTextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              placeholder: '0',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: isDone ? AppColors.success : AppColors.accent,
              ),
              onChanged: (val) => setState(() {}),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDone
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.border,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackagingRow(String name) {
    final status = _packaging[name] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StaffCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => _showStatusPicker(name),
                    child: Row(
                      children: [
                        Text(status == 0 ? 'GOOD' : 'LOW', 
                          style: TextStyle(fontSize: 12, color: status == 0 ? AppColors.success : AppColors.error, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 4),
                        Icon(CupertinoIcons.chevron_down, size: 12, color: status == 0 ? AppColors.success : AppColors.error),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            StaffButton(
              label: 'Request',
              onPressed: () => _requestStock(name),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ],
        ),
      ),
    );
  }
}
