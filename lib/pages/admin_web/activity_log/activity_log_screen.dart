import 'package:flutter/material.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';

class ActivityEntry {
  final String actor;
  final String action;
  final DateTime timestamp;
  final String type; // 'User', 'System', 'Inventory'

  const ActivityEntry({
    required this.actor,
    required this.action,
    required this.timestamp,
    required this.type,
  });
}

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  @override
  void initState() {
    super.initState();
    _updateShellActions();
  }

  @override
  void didUpdateWidget(ActivityLogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([]);
  }

  final List<ActivityEntry> _allEntries = [
    ActivityEntry(
      actor: 'Owner',
      action: 'Approved registration for Maria Santos',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      type: 'User',
    ),
    ActivityEntry(
      actor: 'System',
      action: 'Low stock alert triggered for Sta. Cruz branch',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      type: 'Inventory',
    ),
    ActivityEntry(
      actor: 'Owner',
      action: 'Updated pricing for Medium Bilao',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      type: 'System',
    ),
    ActivityEntry(
      actor: 'Owner',
      action: 'Assigned Juan Dela Cruz to Dayap branch',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      type: 'User',
    ),
    ActivityEntry(
      actor: 'System',
      action: 'Daily sales summary generated',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      type: 'System',
    ),
  ];

  String? _selectedType;

  @override
  Widget build(BuildContext context) {
    final filtered = _allEntries
        .where((e) => _selectedType == null || e.type == _selectedType)
        .toList();

    return Container(
      color: AdminWebColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
            'FILTER BY TYPE',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.0,
              color: AdminWebColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('ALL ACTIVITIES'),
                  selected: _selectedType == null,
                  onSelected: (v) => setState(() => _selectedType = null),
                ),
                const SizedBox(width: 8),
                ...['User', 'System', 'Inventory'].map((type) {
                  final isSelected = _selectedType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(type.toUpperCase()),
                      selected: isSelected,
                      onSelected: (v) =>
                          setState(() => _selectedType = v ? type : null),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (filtered.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'No activity logs found for the selected filter.',
                  style: TextStyle(color: AdminWebColors.textSecondary),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final e = filtered[index];
                return GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AdminWebColors.accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          e.type == 'User'
                              ? Icons.person_rounded
                              : e.type == 'Inventory'
                                  ? Icons.inventory_2_rounded
                                  : Icons.settings_suggest_rounded,
                          color: AdminWebColors.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.action,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: AdminWebColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${e.actor.toUpperCase()} • ${_formatDate(e.timestamp)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: AdminWebColors.textSecondary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 40),
        ],
      ),
    ),
  );
}

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
