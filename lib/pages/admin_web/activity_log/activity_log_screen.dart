import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/activity_entry.dart';
import '../../../models/meat_dispatch.dart';
import '../../../services/firestore_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import '../admin_web_widgets/admin_pagination_bar.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 1),
  );

  StreamSubscription<List<ActivityEntry>>? _activitiesSub;
  StreamSubscription<List<MeatDispatch>>? _dispatchesSub;

  List<ActivityEntry> _liveEntries = [];
  List<MeatDispatch> _liveDispatches = [];
  bool _isLoadingActivities = true;
  bool _isLoadingDispatches = true;

  // Activities tab state
  int _currentPage = 0;
  static const int _pageSize = 8;
  static const List<String> _types = ['Orders', 'Staff', 'Sales', 'System'];
  String? _selectedType;

  // Transfer logs tab state
  int _dispatchesPage = 0;
  static const int _dispatchesPageSize = 8;
  String? _dispatchStatusFilter; // null = all, 'pending', 'delivered'

  @override
  void initState() {
    super.initState();
    _updateShellActions();
    _listenToActivities();
    _listenToDispatches();
  }

  @override
  void didUpdateWidget(ActivityLogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
    if (widget.initialTab != oldWidget.initialTab) {
      _tabController.animateTo(widget.initialTab.clamp(0, 1));
    }
  }

  @override
  void dispose() {
    _activitiesSub?.cancel();
    _dispatchesSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([]);
  }

  void _listenToActivities() {
    _activitiesSub = FirestoreService.watchRecentActivities(limit: 50).listen(
      (entries) {
        if (mounted) {
          setState(() {
            _liveEntries = entries;
            _isLoadingActivities = false;
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isLoadingActivities = false);
      },
    );
  }

  void _listenToDispatches() {
    _dispatchesSub = FirestoreService.watchMeatDispatches().listen(
      (dispatches) {
        if (mounted) {
          setState(() {
            _liveDispatches = dispatches;
            _isLoadingDispatches = false;
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isLoadingDispatches = false);
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

  Future<void> _confirmDeleteDispatch(MeatDispatch dispatch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AdminWebColors.error),
            SizedBox(width: 8),
            Text('Delete Dispatch Record?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this dispatch record to ${dispatch.destinationBranchName} (${dispatch.itemsSummary})?',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: AdminWebColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminWebColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && dispatch.id.isNotEmpty) {
      await FirestoreService.deleteDispatch(dispatch.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Dispatch record deleted.'),
              ],
            ),
            backgroundColor: AdminWebColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingDispatchesCount = _liveDispatches.where((d) => !d.isDelivered).length;

    return Container(
      color: AdminWebColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              const Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Activity Logs'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_shipping_rounded, size: 18),
                    const SizedBox(width: 8),
                    const Text('Transfer Logs'),
                    if (pendingDispatchesCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AdminWebColors.warning,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$pendingDispatchesCount PENDING',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _KeepAliveTab(child: _buildActivitiesTab()),
                _KeepAliveTab(child: _buildTransferLogsTab()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesTab() {
    final filtered = _liveEntries
        .where((e) => _selectedType == null || e.type == _selectedType)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  onSelected: (_) => setState(() {
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
          if (_isLoadingActivities)
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
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildTransferLogsTab() {
    final filtered = _liveDispatches.where((d) {
      if (_dispatchStatusFilter == 'pending') return !d.isDelivered;
      if (_dispatchStatusFilter == 'delivered') return d.isDelivered;
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FILTER BY STATUS',
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
                  label: Text('ALL TRANSFERS (${_liveDispatches.length})'),
                  selected: _dispatchStatusFilter == null,
                  onSelected: (_) => setState(() {
                    _dispatchStatusFilter = null;
                    _dispatchesPage = 0;
                  }),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('PENDING (${_liveDispatches.where((d) => !d.isDelivered).length})'),
                  selected: _dispatchStatusFilter == 'pending',
                  onSelected: (v) => setState(() {
                    _dispatchStatusFilter = v ? 'pending' : null;
                    _dispatchesPage = 0;
                  }),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('DELIVERED (${_liveDispatches.where((d) => d.isDelivered).length})'),
                  selected: _dispatchStatusFilter == 'delivered',
                  onSelected: (v) => setState(() {
                    _dispatchStatusFilter = v ? 'delivered' : null;
                    _dispatchesPage = 0;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_isLoadingDispatches)
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
                      Icons.local_shipping_outlined,
                      size: 48,
                      color: AdminWebColors.textSecondary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _dispatchStatusFilter == null
                          ? 'No stock dispatches recorded in the database.'
                          : 'No ${_dispatchStatusFilter!.toUpperCase()} dispatches found.',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AdminWebColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Dispatches recorded when meat batches are allocated and sent to branches will appear here.',
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
                  itemCount: (filtered.length - (_dispatchesPage * _dispatchesPageSize))
                      .clamp(0, _dispatchesPageSize),
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final dispatch = filtered[(_dispatchesPage * _dispatchesPageSize) + index];
                    final isDelivered = dispatch.isDelivered;

                    return GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (isDelivered ? AdminWebColors.success : AdminWebColors.accent)
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.warehouse_rounded,
                              color: isDelivered ? AdminWebColors.success : AdminWebColors.accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Warehouse → ${dispatch.destinationBranchName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AdminWebColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  dispatch.itemsSummary,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AdminWebColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${dispatch.createdAt.month}/${dispatch.createdAt.day} · ${dispatch.createdAt.hour.toString().padLeft(2, '0')}:${dispatch.createdAt.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AdminWebColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${dispatch.totalPcs} pcs',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: AdminWebColors.accent,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (isDelivered ? AdminWebColors.success : AdminWebColors.warning)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isDelivered ? 'DELIVERED' : 'PENDING',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: isDelivered ? AdminWebColors.success : AdminWebColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AdminWebColors.error,
                              size: 20,
                            ),
                            tooltip: 'Delete Dispatch',
                            onPressed: () => _confirmDeleteDispatch(dispatch),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                AdminPaginationBar(
                  currentPage: _dispatchesPage,
                  totalItems: filtered.length,
                  pageSize: _dispatchesPageSize,
                  onPageChanged: (p) => setState(() => _dispatchesPage = p),
                ),
              ],
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({required this.child});
  final Widget child;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

