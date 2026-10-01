import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/activity_entry.dart';
import '../../../services/firestore_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import '../admin_web_widgets/admin_pagination_bar.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  StreamSubscription<List<ActivityEntry>>? _sub;
  List<ActivityEntry> _liveEntries = [];
  bool _isLoading = true;

  int _currentPage = 0;
  static const int _pageSize = 8;
  static const List<String> _types = ['Orders', 'Staff', 'Sales', 'System'];

  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _updateShellActions();
    _listenToActivities();
  }

  @override
  void didUpdateWidget(ActivityLogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([]);
  }

  void _listenToActivities() {
    _sub = FirestoreService.watchRecentActivities(limit: 50).listen(
      (entries) {
        if (mounted) {
          setState(() {
            _liveEntries = entries;
            _isLoading = false;
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'Orders':
        return const Color(0xFFE65100); // Warm Amber
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
    final filtered = _liveEntries
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

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (filtered.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 48,
                        color: AdminWebColors.textSecondary.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedType == null
                            ? 'No activity logs recorded in the database.'
                            : 'No activity logs found for category $_selectedType.',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AdminWebColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Logs will automatically appear here when accounts are approved, bilao orders are delivered, or EOD reports are submitted.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AdminWebColors.textSecondary,
                        ),
                      ),
                    ],
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
