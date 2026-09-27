import 'package:flutter/material.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import '../admin_web_widgets/admin_pagination_bar.dart';

class ActivityEntry {
  final String actor;
  final String role; // 'Admin', 'Staff', 'Driver', 'System'
  final String action;
  final String detail;
  final DateTime timestamp;
  final String type; // 'Orders', 'Staff', 'Sales', 'System'

  const ActivityEntry({
    required this.actor,
    required this.role,
    required this.action,
    this.detail = '',
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
  int _currentPage = 0;
  static const int _pageSize = 6;

  static const List<String> _types = ['Orders', 'Staff', 'Sales', 'System'];

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
      actor: 'Staff - Labuin',
      role: 'Staff',
      action: 'Released branch pickup bilao order to customer',
      detail: 'Customer: Mark Villanueva · Medium Bilao (₱900)',
      timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
      type: 'Orders',
    ),
    ActivityEntry(
      actor: 'Driver - Noel',
      role: 'Driver',
      action: 'Completed direct delivery with photo proof',
      detail: 'Customer: Ana Lopez · Large Bilao (₱1,300) in Pila',
      timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 15)),
      type: 'Orders',
    ),
    ActivityEntry(
      actor: 'Admin',
      role: 'Admin',
      action: 'Approved account registration for Maria Santos',
      detail: 'Assigned role: Branch Staff (Sta. Cruz)',
      timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 40)),
      type: 'Staff',
    ),
    ActivityEntry(
      actor: 'Admin',
      role: 'Admin',
      action: 'Assigned Juan Dela Cruz to Dayap branch',
      detail: 'Schedule: Mon-Sat · Position: Branch Cook',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      type: 'Staff',
    ),
    ActivityEntry(
      actor: 'Staff - Sta. Cruz',
      role: 'Staff',
      action: 'Submitted branch End-of-Day (EOD) sales report',
      detail: 'Total Sales: ₱4,850 · 32 Meat Portions sold',
      timestamp: DateTime.now().subtract(const Duration(hours: 7, minutes: 30)),
      type: 'Sales',
    ),
    ActivityEntry(
      actor: 'System',
      role: 'System',
      action: 'Daily sales summary and cook commissions generated',
      detail: 'Automated EOD audit across all 6 active branches',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      type: 'Sales',
    ),
    ActivityEntry(
      actor: 'Admin',
      role: 'Admin',
      action: 'Updated special bilao package pricing',
      detail: 'Small: ₱650 · Medium: ₱900 · Large: ₱1,300',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
      type: 'System',
    ),
    ActivityEntry(
      actor: 'Admin',
      role: 'Admin',
      action: 'Published new branch operational announcement',
      detail: 'Topic: Proper food safety handling & inventory recording',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      type: 'System',
    ),
  ];

  String? _selectedType;

  Color _typeColor(String type) {
    switch (type) {
      case 'Orders':
        return const Color(0xFFE65100); // Warm Amber/Orange
      case 'Staff':
        return const Color(0xFF2E7D32); // Green
      case 'Sales':
        return const Color(0xFF1565C0); // Blue
      case 'System':
      default:
        return AdminWebColors.accent; // Brahms Brown
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Orders':
        return Icons.shopping_bag_outlined;
      case 'Staff':
        return Icons.person_outline_rounded;
      case 'Sales':
        return Icons.receipt_long_outlined;
      case 'System':
      default:
        return Icons.tune_rounded;
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour:$minute $ampm';
  }

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
            const SizedBox(height: 12),
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
                    onSelected: (v) => setState(() {
                      _selectedType = null;
                      _currentPage = 0;
                    }),
                  ),
                  const SizedBox(width: 8),
                  ..._types.map((type) {
                    final isSelected = _selectedType == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(type.toUpperCase()),
                        selected: isSelected,
                        onSelected: (v) => setState(() {
                          _selectedType = v ? type : null;
                          _currentPage = 0;
                        }),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (filtered.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'Walang activity logs para sa napiling filter.',
                    style: TextStyle(color: AdminWebColors.textSecondary),
                  ),
                ),
              )
            else
              Column(
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: (filtered.length - (_currentPage * _pageSize))
                        .clamp(0, _pageSize),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final e = filtered[(_currentPage * _pageSize) + index];
                      final color = _typeColor(e.type);
                      final icon = _typeIcon(e.type);

                      return GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                icon,
                                color: color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          e.action,
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: AdminWebColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: color.withValues(alpha: 0.25),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          e.type.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: color,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (e.detail.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      e.detail,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: AdminWebColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AdminWebColors.accent
                                              .withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          e.actor.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: AdminWebColors.accent,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatDate(e.timestamp),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: AdminWebColors.textSecondary
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  AdminPaginationBar(
                    currentPage: _currentPage,
                    totalItems: filtered.length,
                    pageSize: _pageSize,
                    onPageChanged: (p) => setState(() => _currentPage = p),
                  ),
                ],
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
