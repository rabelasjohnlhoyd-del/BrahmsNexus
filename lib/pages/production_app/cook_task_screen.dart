import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';

class CookTaskScreen extends StatefulWidget {
  const CookTaskScreen({super.key});

  @override
  State<CookTaskScreen> createState() => _CookTaskScreenState();
}

class _CookTaskScreenState extends State<CookTaskScreen> {
  final List<bool> _checkSteps = [false, false, false];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const StaffNavBar(
          title: 'Cooking Tasks',
          mode: StaffHeaderMode.greeting,
          greetingName: 'Menes',
          trailing: StaffTopActions(initials: 'MN'),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const StaffSectionHeader(
                label: 'Today\'s Checklist',
                icon: CupertinoIcons.checkmark_circle,
                large: true,
                subtitle: 'Steps for central kitchen production',
              ),
              const SizedBox(height: 20),
              _buildTaskCard(
                title: 'Production Steps',
                child: Column(
                  children: [
                    _buildCheckItem('Preparation of Raw Meat', 0),
                    _buildCheckItem('Cooking Process (140-150kg)', 1),
                    _buildCheckItem('Cleaning & Proper Storage', 2),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Complete all steps before reporting output in the next tab.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckItem(String label, int index) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => setState(() => _checkSteps[index] = !_checkSteps[index]),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              _checkSteps[index] ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
              color: _checkSteps[index] ? AppColors.success : AppColors.textSecondary,
              size: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: _checkSteps[index] ? AppColors.textPrimary : AppColors.textSecondary,
                  decoration: _checkSteps[index] ? TextDecoration.lineThrough : null,
                  fontSize: 16,
                  fontWeight: _checkSteps[index] ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
