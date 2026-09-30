import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';

/// Real-time Branch Status Overview — replaces the old Map screen.
/// Shows which branches are OPEN, CLOSED, or have Driver On the Way.
/// Data flows from [rfid_attendance] and [branch_status] Firestore collections.
class BranchStatusScreen extends StatefulWidget {
  const BranchStatusScreen({super.key, this.isEmbedded = false});

  final bool isEmbedded;

  @override
  State<BranchStatusScreen> createState() => _BranchStatusScreenState();
}

class _BranchStatusScreenState extends State<BranchStatusScreen> {
  StreamSubscription<QuerySnapshot>? _sub;

  // Map of branchId -> status data
  final Map<String, _BranchLiveStatus> _statuses = {};

  static const _orderedBranches = [
    _BranchDef(id: 'labuin', name: 'Labuin', municipality: 'Pila'),
    _BranchDef(id: 'nanhaya', name: 'Nanhaya', municipality: 'Pila'),
    _BranchDef(id: 'san_francisco', name: 'San Francisco', municipality: 'Pila'),
    _BranchDef(id: 'dayap', name: 'Dayap', municipality: 'Calauan'),
    _BranchDef(id: 'gatid', name: 'Gatid', municipality: 'Sta. Cruz'),
    _BranchDef(id: 'pila', name: 'Pila Proper', municipality: 'Pila'),
  ];

  @override
  void initState() {
    super.initState();
    if (!widget.isEmbedded) {
      _updateShellActions();
    }
    _sub = FirebaseFirestore.instance
        .collection('branch_status')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        for (final doc in snap.docs) {
          final data = doc.data();
          _statuses[doc.id] = _BranchLiveStatus(
            isOpen: data['isOpen'] as bool? ?? false,
            driverOnWay: data['driverOnWay'] as bool? ?? false,
            cookName: data['cookName']?.toString() ?? '',
            lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setTitle('BRANCH STATUS OVERVIEW');
    shell?.setActions([]);
  }

  @override
  void didUpdateWidget(BranchStatusScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isEmbedded) {
      _updateShellActions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final openCount = _orderedBranches
        .where((b) => _statuses[b.id]?.isOpen == true)
        .length;
    final closedCount = _orderedBranches.length - openCount;

    return Container(
      color: AdminWebColors.background,
      padding: widget.isEmbedded ? EdgeInsets.zero : const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isEmbedded) const SizedBox(height: 16),
          // Summary bar
          _buildSummaryBar(openCount, closedCount),
          const SizedBox(height: 24),
          // Grid / list of branch cards
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;
                if (isWide) {
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.7,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _orderedBranches.length,
                    itemBuilder: (ctx, i) =>
                        _buildBranchCard(_orderedBranches[i]),
                  );
                }
                return ListView.separated(
                  itemCount: _orderedBranches.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (ctx, i) =>
                      _buildBranchCard(_orderedBranches[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(int openCount, int closedCount) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _summaryPill(
            label: '$openCount BRANCHES OPEN',
            color: AdminWebColors.success,
            icon: Icons.lock_open_rounded,
          ),
          const SizedBox(width: 16),
          _summaryPill(
            label: '$closedCount BRANCHES CLOSED',
            color: AdminWebColors.error,
            icon: Icons.lock_rounded,
          ),
          const Spacer(),
          const Icon(Icons.circle, size: 10, color: AdminWebColors.success),
          const SizedBox(width: 6),
          const Text(
            'REAL-TIME',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AdminWebColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryPill({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchCard(_BranchDef branch) {
    final status = _statuses[branch.id];
    final isOpen = status?.isOpen ?? false;
    final driverOnWay = status?.driverOnWay ?? false;
    final neverUpdated = status == null;

    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    if (neverUpdated) {
      statusColor = AdminWebColors.textSecondary;
      statusText = 'NO DATA';
      statusIcon = Icons.help_outline_rounded;
    } else if (driverOnWay && !isOpen) {
      statusColor = AdminWebColors.warning;
      statusText = 'DRIVER ON THE WAY';
      statusIcon = Icons.directions_car_rounded;
    } else if (isOpen) {
      statusColor = AdminWebColors.success;
      statusText = 'OPEN';
      statusIcon = Icons.lock_open_rounded;
    } else {
      statusColor = AdminWebColors.error;
      statusText = 'CLOSED';
      statusIcon = Icons.lock_rounded;
    }

    String lastUpdatedText = '';
    if (status?.lastUpdated != null) {
      final dt = status!.lastUpdated!;
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      lastUpdatedText = 'Last update: $h:$m';
    }

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Colored status bar at top
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BRANCH ${_orderedBranches.indexOf(branch) + 1}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AdminWebColors.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              branch.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: AdminWebColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Brgy. ${branch.municipality}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AdminWebColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            Icon(statusIcon, size: 13, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if ((status?.cookName ?? '').isNotEmpty)
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.person_rounded,
                                  size: 13,
                                  color: AdminWebColors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  status!.cookName,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AdminWebColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (lastUpdatedText.isNotEmpty)
                        Text(
                          lastUpdatedText,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AdminWebColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchDef {
  const _BranchDef({
    required this.id,
    required this.name,
    required this.municipality,
  });
  final String id;
  final String name;
  final String municipality;
}

class _BranchLiveStatus {
  const _BranchLiveStatus({
    required this.isOpen,
    required this.driverOnWay,
    required this.cookName,
    this.lastUpdated,
  });
  final bool isOpen;
  final bool driverOnWay;
  final String cookName;
  final DateTime? lastUpdated;
}
