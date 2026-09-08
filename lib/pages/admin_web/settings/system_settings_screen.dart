import 'package:flutter/material.dart';
import '../admin_web_colors.dart';
import '../admin_web_widgets/glass_card.dart';
import '../../../widgets/admin_page_header.dart';
import '../../../widgets/primary_button.dart';

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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminPageHeader(
                title: 'System Settings',
                subtitle:
                    'Configure global application parameters, financial rates, and inventory thresholds.',
                actions: [
                  PrimaryButton(
                    label: 'SAVE SETTINGS',
                    icon: Icons.save_rounded,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('System settings saved successfully.')));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildSection('Financial Parameters', [
                _buildSettingRow(
                  'Default Commission Rate',
                  'Base pay (in ₱) added to staff salary for each portion sold.',
                  _commissionController,
                  prefixText: '₱',
                ),
                const Divider(height: 32),
                _buildToggleRow(
                  'Automatic Tax Calculation',
                  'Apply standard sales tax to all recorded orders by default.',
                  true,
                ),
              ]),
              const SizedBox(height: 24),
              _buildSection('Inventory & Operations', [
                _buildSettingRow(
                  'Low Stock Threshold',
                  'The quantity (in kg) that triggers a "Running Low" warning across branches.',
                  _lowStockController,
                  suffixText: 'kg',
                ),
                const Divider(height: 32),
                _buildToggleRow(
                  'Enable Inter-Branch Transfers',
                  'Allow warehouse managers to record stock movement between branches.',
                  true,
                ),
              ]),
              const SizedBox(height: 24),
              _buildSection('Application Preferences', [
                _buildToggleRow(
                  'Push Notifications',
                  'Send alerts for new account approvals and critical inventory levels.',
                  true,
                ),
                const Divider(height: 32),
                _buildToggleRow(
                  'Daily Summary Reports',
                  'Generate and email a PDF summary of daily gross sales every midnight.',
                  false,
                ),
              ]),
              const SizedBox(height: 40),
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
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.2,
              color: AdminWebColors.accent,
            ),
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingRow(
      String label, String hint, TextEditingController controller,
      {String? prefixText, String? suffixText}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AdminWebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hint,
                style: const TextStyle(
                  fontSize: 13,
                  color: AdminWebColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 32),
        SizedBox(
          width: 120,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: prefixText,
              suffixText: suffixText,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow(String label, String hint, bool initialValue) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AdminWebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hint,
                style: const TextStyle(
                  fontSize: 13,
                  color: AdminWebColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 32),
        Switch(
          value: initialValue,
          onChanged: (v) {},
        ),
      ],
    );
  }
}
