import 'package:flutter/material.dart';
import '../admin_web_colors.dart';
import '../admin_web_widgets/glass_card.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  final _commissionController = TextEditingController(text: '5.00');
  final _lowStockController = TextEditingController(text: '10.0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildSection('Financial Settings', [
                _buildSettingRow(
                  'Default Commission Rate (₱)',
                  'Base pay per portion sold.',
                  _commissionController,
                ),
              ]),
              const SizedBox(height: 24),
              _buildSection('Inventory Settings', [
                _buildSettingRow(
                  'Low Stock Threshold (kg)',
                  'Trigger alerts below this level.',
                  _lowStockController,
                ),
              ]),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('System settings saved successfully.')));
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('SAVE GLOBAL SETTINGS'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AdminWebColors.accent)),
        const SizedBox(height: 12),
        GlassCard(child: Column(children: children)),
      ],
    );
  }

  Widget _buildSettingRow(String label, String hint, TextEditingController controller) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(hint, style: const TextStyle(fontSize: 12, color: AdminWebColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 80,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          ),
        ),
      ],
    );
  }
}
