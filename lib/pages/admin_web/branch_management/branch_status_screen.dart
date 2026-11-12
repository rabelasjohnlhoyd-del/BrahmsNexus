import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/branch.dart';
import '../../../services/attendance_service.dart';
import '../../../services/supabase_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';

/// Real-time Branch Status Overview — replaces the old Map screen.
/// Shows which branches are OPEN, CLOSED, or have Driver On the Way.
/// Data flows from Supabase [attendance_logs] (RFID taps from portable driver reader)
/// and [branch_status] Firestore collection.
class BranchStatusScreen extends StatefulWidget {
  const BranchStatusScreen({super.key, this.isEmbedded = false});

  final bool isEmbedded;

  @override
  State<BranchStatusScreen> createState() => _BranchStatusScreenState();
}

class _BranchStatusScreenState extends State<BranchStatusScreen> {
  StreamSubscription<QuerySnapshot>? _sub;
  StreamSubscription<List<Map<String, dynamic>>>? _attendanceSub;

  // Map of documentId or branchId -> live status data
  final Map<String, _BranchLiveStatus> _statuses = {};
  List<Branch> _branches = List.from(kSampleBranches);

  @override
  void initState() {
    super.initState();
    if (!widget.isEmbedded) {
      _updateShellActions();
    }
    _loadBranches();
    AttendanceService.ensureAttendanceSync();

    // 1. Direct real-time stream of Supabase attendance_logs (ESP32 RFID card taps)
    _attendanceSub = AttendanceService.watchTodayAttendance().listen((todayLogs) {
      if (!mounted) return;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      setState(() {
        for (final log in todayLogs) {
          final sName = log['staff_name']?.toString() ?? '';
          final sId = log['staff_id']?.toString() ?? '';
          final rawBId = (log['branch_id']?.toString() ?? '').toLowerCase();
          final bName = log['branch_name']?.toString() ?? '';
          final canonId = AttendanceService.resolveBranchForStaff(rawBId.isNotEmpty ? rawBId : bName, sName, sId);

          if (canonId.isNotEmpty && canonId != 'commissary' && canonId != 'unassigned') {
            final hasTimeIn = log['time_in'] != null;
            final hasTimeOut = log['time_out'] != null;
            final effectiveIsOpen = hasTimeIn && !hasTimeOut;

            final prev = _statuses[canonId];
            final status = _BranchLiveStatus(
              branchId: canonId,
              branchName: bName.isNotEmpty ? bName : (prev?.branchName ?? canonId),
              isOpen: effectiveIsOpen,
              isClosed: hasTimeOut,
              driverOnWay: false,
              cookName: sName.isNotEmpty ? sName : (prev?.cookName ?? ''),
              driverName: prev?.driverName ?? '',
              lastUpdated: DateTime.now(),
              timeIn: log['time_in'] != null ? AttendanceService.formatTime(log['time_in']) : prev?.timeIn,
              timeOut: log['time_out'] != null ? AttendanceService.formatTime(log['time_out']) : prev?.timeOut,
              rfidUid: log['rfid_uid']?.toString() ?? prev?.rfidUid,
            );
            _statuses[canonId] = status;
            if (rawBId.isNotEmpty) _statuses[rawBId] = status;

            // Sync to Firestore branch_status doc for cross-platform app sync
            FirebaseFirestore.instance.collection('branch_status').doc(canonId).set({
              'branchId': canonId,
              'branchName': bName,
              'isOpen': effectiveIsOpen,
              'isClosed': hasTimeOut,
              'driverOnWay': false,
              'cookName': sName,
              'openedDateStr': todayStr,
              'lastTapType': hasTimeOut ? 'retrieval_closing' : 'deployment_opening',
              'lastUpdated': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)).catchError((_) {});
          }
        }
      });
    });

    // 2. Listen to Firestore branch_status collection
    _sub = FirebaseFirestore.instance
        .collection('branch_status')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      setState(() {
        for (final doc in snap.docs) {
          final data = doc.data();
          final rawIsOpen = data['isOpen'] as bool? ?? false;
          final isClosed = data['isClosed'] as bool? ?? false;
          final lastTapType = data['lastTapType'] as String?;
          final openedDateStr = data['openedDateStr'] as String?;
          final isOpenedToday = openedDateStr == null || openedDateStr == todayStr;
          final isDeploymentOpeningToday = lastTapType == 'deployment_opening' && isOpenedToday;
          final isClosedByRetrieval = lastTapType == 'retrieval_closing';

          // Store is strictly OPEN only if it was opened today and not closed by retrieval
          final effectiveIsOpen = !isClosedByRetrieval && isOpenedToday && (isDeploymentOpeningToday || (rawIsOpen && !isClosed));
          final effectiveIsClosed = !effectiveIsOpen;

          final rawId = (data['branchId']?.toString() ?? doc.id).toLowerCase();
          final cookName = data['cookName']?.toString() ?? '';
          final canonId = AttendanceService.normalizeBranchId(rawId, cookName);

          final driverOnWayDateStr = data['driverOnWayDateStr'] as String?;
          final isDriverOnWayToday = (data['driverOnWay'] as bool? ?? false) &&
              (driverOnWayDateStr == null || driverOnWayDateStr == todayStr);

          final prev = _statuses[canonId];
          final status = _BranchLiveStatus(
            branchId: canonId,
            branchName: data['branchName']?.toString() ?? prev?.branchName ?? '',
            isOpen: effectiveIsOpen,
            isClosed: effectiveIsClosed,
            driverOnWay: isDriverOnWayToday,
            cookName: cookName.isNotEmpty ? cookName : (prev?.cookName ?? ''),
            driverName: data['driverName']?.toString() ?? prev?.driverName ?? '',
            lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? prev?.lastUpdated,
            timeIn: prev?.timeIn,
            timeOut: prev?.timeOut,
            rfidUid: data['rfidTag']?.toString() ?? prev?.rfidUid,
          );
          _statuses[doc.id.toLowerCase()] = status;
          _statuses[canonId] = status;
          if (rawId.isNotEmpty) _statuses[rawId] = status;
        }
      });
    });
  }

  Future<void> _loadBranches() async {
    final list = await SupabaseService.getBranches();
    if (!mounted) return;
    if (list.isNotEmpty) {
      setState(() {
        _branches = list;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _attendanceSub?.cancel();
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

  void _showBranchDetailDialog(Branch branch, _BranchLiveStatus? status) {
    final isOpen = status?.isOpen ?? false;
    final cookName = (status?.cookName ?? '').isNotEmpty ? status!.cookName : 'Assigned Branch Cook';
    final timeIn = status?.timeIn ?? 'Awaiting RFID Tap';
    final rfidTag = status?.rfidUid ?? 'None';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isOpen ? AdminWebColors.success : AdminWebColors.accent).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isOpen ? Icons.store_rounded : Icons.storefront_outlined,
                color: isOpen ? AdminWebColors.success : AdminWebColors.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(branch.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(
                    isOpen ? 'STORE CURRENTLY OPEN' : 'STORE CURRENTLY CLOSED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isOpen ? AdminWebColors.success : AdminWebColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: AdminWebColors.border),
            const SizedBox(height: 8),
            _dialogInfoRow('Assigned Cook', cookName, Icons.person_rounded),
            const SizedBox(height: 10),
            _dialogInfoRow(
              'Status',
              isOpen ? 'OPEN (Live Active)' : (status?.driverOnWay == true ? 'Driver On The Way' : 'CLOSED'),
              Icons.info_outline_rounded,
            ),
            const SizedBox(height: 10),
            _dialogInfoRow('RFID Time-In', timeIn, Icons.nfc_rounded),
            if (rfidTag.isNotEmpty && rfidTag != 'None') ...[
              const SizedBox(height: 10),
              _dialogInfoRow('RFID Card UID', rfidTag, Icons.credit_card_rounded),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminWebColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_tethering_rounded, size: 16, color: AdminWebColors.accent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Awtomatikong magiging OPEN kapag nag-tap ang cook sa portable RFID reader ng driver.',
                      style: TextStyle(fontSize: 11, color: AdminWebColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _dialogInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AdminWebColors.accent),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminWebColors.textSecondary)),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AdminWebColors.textPrimary)),
        ),
      ],
    );
  }

  _BranchLiveStatus? _getStatusForBranch(Branch branch) {
    final bId = branch.id.toLowerCase().trim();
    if (_statuses.containsKey(bId)) return _statuses[bId];

    final canonId = AttendanceService.normalizeBranchId(bId, branch.name);
    if (canonId.isNotEmpty && canonId != 'unassigned' && canonId != 'commissary') {
      if (_statuses.containsKey(canonId)) return _statuses[canonId];
    }

    final cleanName = branch.name.toLowerCase().trim();
    if (_statuses.containsKey(cleanName)) return _statuses[cleanName];

    // Match strictly by canonical branch ID (e.g. br1..br6)
    for (final entry in _statuses.entries) {
      final key = entry.key.toLowerCase().trim();
      final statusName = entry.value.branchName.toLowerCase().trim();
      final entryCanon = AttendanceService.normalizeBranchId(key, statusName);
      if (entryCanon.isNotEmpty && entryCanon == canonId) {
        return entry.value;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final openCount = _branches
        .where((b) => _getStatusForBranch(b)?.isOpen == true)
        .length;
    final closedCount = _branches.length - openCount;

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
                      childAspectRatio: 1.6,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _branches.length,
                    itemBuilder: (ctx, i) => _buildBranchCard(_branches[i], i + 1, isWide: true),
                  );
                }
                return ListView.separated(
                  itemCount: _branches.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (ctx, i) => _buildBranchCard(_branches[i], i + 1, isWide: false),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _summaryPill(
            label: '$openCount BRANCHES OPEN',
            color: AdminWebColors.success,
            icon: Icons.lock_open_rounded,
          ),
          _summaryPill(
            label: '$closedCount BRANCHES CLOSED',
            color: AdminWebColors.error,
            icon: Icons.lock_rounded,
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

  Widget _buildBranchCard(Branch branch, int stopNumber, {bool isWide = true}) {
    final status = _getStatusForBranch(branch);
    final isOpen = status?.isOpen ?? false;
    final driverOnWay = status?.driverOnWay ?? false;

    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    if (isOpen) {
      statusColor = AdminWebColors.success;
      statusText = 'OPEN';
      statusIcon = Icons.lock_open_rounded;
    } else if (driverOnWay) {
      statusColor = AdminWebColors.warning;
      statusText = 'DRIVER ON THE WAY';
      statusIcon = Icons.directions_car_rounded;
    } else {
      statusColor = AdminWebColors.textSecondary;
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

    final cardInner = Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isWide ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STOP $stopNumber · ROUTE SEQUENCE ${branch.dailyRouteSequence}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AdminWebColors.accent,
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
                      branch.municipality.isNotEmpty
                          ? 'Brgy. ${branch.municipality}'
                          : branch.fullName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminWebColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
          if (isWide) const Spacer() else const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if ((status?.cookName ?? '').isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_rounded,
                              size: 13, color: AdminWebColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Cook: ${status!.cookName}',
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
                      if (isOpen && (status.timeIn ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.nfc_rounded, size: 11, color: AdminWebColors.success),
                            const SizedBox(width: 4),
                            Text(
                              'RFID In: ${status.timeIn}',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AdminWebColors.success),
                            ),
                          ],
                        ),
                      ],
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
    );

    return InkWell(
      onTap: () => _showBranchDetailDialog(branch, status),
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: isWide ? MainAxisSize.max : MainAxisSize.min,
          children: [
            // Colored status bar at top
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            if (isWide) Expanded(child: cardInner) else cardInner,
          ],
        ),
      ),
    );
  }
}

class _BranchLiveStatus {
  const _BranchLiveStatus({
    required this.branchId,
    required this.branchName,
    required this.isOpen,
    this.isClosed = false,
    required this.driverOnWay,
    required this.cookName,
    required this.driverName,
    this.lastUpdated,
    this.timeIn,
    this.timeOut,
    this.rfidUid,
  });
  final String branchId;
  final String branchName;
  final bool isOpen;
  final bool isClosed;
  final bool driverOnWay;
  final String cookName;
  final String driverName;
  final DateTime? lastUpdated;
  final String? timeIn;
  final String? timeOut;
  final String? rfidUid;
}
