import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';

class CookOutputScreen extends StatefulWidget {
  const CookOutputScreen({super.key});

  @override
  State<CookOutputScreen> createState() => _CookOutputScreenState();
}

class _CookOutputScreenState extends State<CookOutputScreen> {
  final _outputController = TextEditingController();

  void _submitOutput() {
    final val = _outputController.text.trim();
    if (val.isEmpty) return;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Submit Output'),
        content: Text('Sigurado ka bang $val kg ang kabuuang naluto ngayong araw?'),
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
                const SnackBar(content: Text('Production output recorded!')),
              );
              setState(() => _outputController.clear());
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
          title: 'Daily Output',
          trailing: StaffTopActions(initials: 'MN'),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const StaffSectionHeader(
                label: 'Record Output',
                icon: CupertinoIcons.chart_bar_square,
                large: true,
                subtitle: 'Report total kilos produced',
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text(
                      'TOTAL KILOS COOKED',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: _outputController,
                      placeholder: '0.0',
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: AppColors.accent),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Standard range: 140 - 150 kg', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              CupertinoButton.filled(
                onPressed: _submitOutput,
                child: const Text('SUBMIT PRODUCTION REPORT'),
              ),
              const SizedBox(height: 40),
              const StaffSectionHeader(label: 'Recent Reports'),
              const SizedBox(height: 12),
              _buildHistoryItem('Sept 7, 2026', '145.5 kg'),
              _buildHistoryItem('Sept 5, 2026', '142.0 kg'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(String date, String output) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(date, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(output, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
        ],
      ),
    );
  }
}
