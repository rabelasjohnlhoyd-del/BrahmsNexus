import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
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

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submitPortions() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Submit Portions'),
        content: const Text('Sigurado ka bang tama ang lahat ng portion counts na nilagay mo?'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Portioning report submitted to Owner!')),
              );
              setState(() {
                for (var controller in _controllers.values) {
                  controller.text = '0';
                }
              });
            },
            child: const Text('Submit'),
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
          title: 'Portioning',
          mode: StaffHeaderMode.greeting,
          greetingName: 'Abby',
          trailing: const StaffTopActions(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const StaffSectionHeader(
                label: 'Meat Portioning',
                icon: CupertinoIcons.scissors_alt,
                large: true,
                subtitle: 'Enter final counts per size',
              ),
              const SizedBox(height: 20),
              _buildPortionInputCard('250g'),
              const SizedBox(height: 12),
              _buildPortionInputCard('300g'),
              const SizedBox(height: 12),
              _buildPortionInputCard('400g'),
              const SizedBox(height: 32),
              CupertinoButton.filled(
                onPressed: _submitPortions,
                child: const Text('SUBMIT PORTION COUNTS'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortionInputCard(String size) {
    final target = _targets[size] ?? 0;
    final controller = _controllers[size]!;
    
    // Simple validation logic for UI feedback
    int current = int.tryParse(controller.text) ?? 0;
    bool isDone = current >= target;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone ? AppColors.success : AppColors.border.withValues(alpha: 0.5),
          width: isDone ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(size, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('Target: $target pcs', 
                  style: TextStyle(color: isDone ? AppColors.success : AppColors.textSecondary, fontSize: 13)),
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
              placeholder: 'Count',
              style: TextStyle(
                fontWeight: FontWeight.w800, 
                fontSize: 20, 
                color: isDone ? AppColors.success : AppColors.accent,
              ),
              onChanged: (val) => setState(() {}),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
