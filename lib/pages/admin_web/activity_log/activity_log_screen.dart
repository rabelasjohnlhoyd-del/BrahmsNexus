import 'package:flutter/material.dart';
import '../admin_web_colors.dart';

class ActivityEntry {
  final String actor;
  final String action;
  final DateTime timestamp;
  final String type; // 'User', 'System', 'Inventory'

  const ActivityEntry({required this.actor, required this.action, required this.timestamp, required this.type});
}

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final List<ActivityEntry> _allEntries = [
    ActivityEntry(actor: 'Owner', action: 'Approved registration for Maria Santos', timestamp: DateTime.now().subtract(const Duration(hours: 2)), type: 'User'),
    ActivityEntry(actor: 'System', action: 'Low stock alert triggered for Sta. Cruz branch', timestamp: DateTime.now().subtract(const Duration(hours: 5)), type: 'Inventory'),
    ActivityEntry(actor: 'Owner', action: 'Updated pricing for Medium Bilao', timestamp: DateTime.now().subtract(const Duration(days: 1)), type: 'System'),
    ActivityEntry(actor: 'Owner', action: 'Assigned Juan Dela Cruz to Dayap branch', timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 3)), type: 'User'),
    ActivityEntry(actor: 'System', action: 'Daily sales summary generated', timestamp: DateTime.now().subtract(const Duration(days: 2)), type: 'System'),
  ];

  String? _selectedType;

  @override
  Widget build(BuildContext context) {
    final filtered = _allEntries.where((e) => _selectedType == null || e.type == _selectedType).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Activity Log')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Filter:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Wrap(
                  spacing: 8,
                  children: ['User', 'System', 'Inventory'].map((type) {
                    final isSelected = _selectedType == type;
                    return ChoiceChip(
                      label: Text(type),
                      selected: isSelected,
                      onSelected: (v) => setState(() => _selectedType = v ? type : null),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final e = filtered[index];
                return ListTile(
                  leading: Icon(
                    e.type == 'User' ? Icons.person : e.type == 'Inventory' ? Icons.inventory : Icons.settings,
                    color: AdminWebColors.accent,
                  ),
                  title: Text(e.action, style: const TextStyle(fontSize: 14)),
                  subtitle: Text('${e.actor} \u2022 ${_formatDate(e.timestamp)}', style: const TextStyle(fontSize: 12)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
