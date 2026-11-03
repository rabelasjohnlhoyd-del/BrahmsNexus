import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, Colors, showModalBottomSheet;
import 'package:intl/intl.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Live Attendance & DTR Card shown at the top of Staff, Production, and Driver apps.
/// Automatically updates in real-time when the staff member taps their RFID card
/// on either the portable driver reader or commissary base reader.
class StaffAttendanceCard extends StatelessWidget {
  const StaffAttendanceCard({
    super.key,
    this.fallbackBranchOpened = false,
  });

  /// If branch was opened via driver arrival verification but Supabase log is still syncing
  final bool fallbackBranchOpened;

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService.currentUserId;
    final currentName = AuthService.currentUser?.fullName ?? AuthService.currentUsername;
    final currentUser = AuthService.currentUsername;

    return StreamBuilder<Map<String, dynamic>?>(
      stream: AttendanceService.watchStaffTodayAttendance(
        staffId: currentUserId,
        staffName: currentName,
        username: currentUser,
      ),
      builder: (context, snapshot) {
        final log = snapshot.data;
        final hasTimeIn = log != null && log['time_in'] != null;
        final hasTimeOut = log != null && log['time_out'] != null;

        final effectiveTimeIn = hasTimeIn || fallbackBranchOpened;

        final timeInDisplay = hasTimeIn
            ? AttendanceService.formatTime(log['time_in'])
            : (fallbackBranchOpened ? 'Verified via Driver' : '-- : --');

        final timeOutDisplay = hasTimeOut
            ? AttendanceService.formatTime(log['time_out'])
            : (hasTimeIn ? 'On Shift (Pending Out)' : '-- : --');

        final statusStr = (log?['status']?.toString() ?? '').toLowerCase();
        final isLate = statusStr == 'late';
        final totalHours = (hasTimeIn && hasTimeOut)
            ? AttendanceService.formatDuration(log['time_in'], log['time_out'])
            : (hasTimeIn ? AttendanceService.formatDuration(log['time_in'], null) : '--');

        Color statusColor;
        String statusLabel;
        IconData statusIcon;

        if (hasTimeOut) {
          statusColor = const Color(0xFF1976D2); // Blue
          statusLabel = 'CLOCKED OUT';
          statusIcon = CupertinoIcons.check_mark_circled_solid;
        } else if (effectiveTimeIn) {
          statusColor = AppColors.success; // Green
          statusLabel = isLate ? 'CLOCKED IN (LATE)' : 'CLOCKED IN (ON TIME)';
          statusIcon = CupertinoIcons.checkmark_alt_circle_fill;
        } else {
          statusColor = const Color(0xFFD97706); // Amber
          statusLabel = 'NOT TIMED IN YET';
          statusIcon = CupertinoIcons.clock_fill;
        }

        return Container(
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: effectiveTimeIn
                  ? statusColor.withValues(alpha: 0.35)
                  : AppColors.border,
              width: effectiveTimeIn ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentDark.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // 1. Card Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.07),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 8),
                    const Text(
                      'DAILY DTR & ATTENDANCE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: CupertinoColors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Metrics Row (Time In, Time Out, Hours)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // TIME IN
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.arrow_down_right_circle_fill, size: 12, color: AppColors.success),
                                SizedBox(width: 4),
                                Text(
                                  'TIME IN',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              timeInDisplay,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: effectiveTimeIn ? AppColors.textPrimary : AppColors.textSecondary,
                              ),
                            ),
                            if (hasTimeIn && isLate)
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Text(
                                  'Late Arrival',
                                  style: TextStyle(fontSize: 9.5, color: Color(0xFFD97706), fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // TIME OUT
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.arrow_up_right_circle_fill, size: 12, color: Color(0xFF1976D2)),
                                SizedBox(width: 4),
                                Text(
                                  'TIME OUT',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              timeOutDisplay,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: hasTimeOut ? AppColors.textPrimary : AppColors.textSecondary,
                              ),
                            ),
                            if (hasTimeIn && !hasTimeOut)
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Text(
                                  'On Shift',
                                  style: TextStyle(fontSize: 9.5, color: AppColors.success, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // TOTAL HOURS
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.timer, size: 12, color: AppColors.accent),
                                SizedBox(width: 4),
                                Text(
                                  'HOURS',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              totalHours,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Helpful Info Footer
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.radiowaves_right, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hasTimeOut
                            ? 'Your attendance record for this shift is complete.'
                            : (effectiveTimeIn
                                ? 'Tap your RFID card before leaving to record Time-Out.'
                                : 'Tap your RFID card on the reader to record official Time-In.'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Modal Bottom Sheet displaying personal DTR attendance history for the staff member
class StaffDtrHistorySheet extends StatefulWidget {
  const StaffDtrHistorySheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => const StaffDtrHistorySheet(),
    );
  }

  @override
  State<StaffDtrHistorySheet> createState() => _StaffDtrHistorySheetState();
}

class _StaffDtrHistorySheetState extends State<StaffDtrHistorySheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];
  Map<String, dynamic>? _todayLog;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    final currentUserId = AuthService.currentUserId;
    final currentName = AuthService.currentUser?.fullName ?? AuthService.currentUsername;
    final currentUsername = AuthService.currentUsername;

    try {
      final historyFuture = AttendanceService.getStaffAttendanceHistory(
        staffId: currentUserId,
        staffName: currentName,
        username: currentUsername,
        limit: 60,
      );

      final todayFuture = AttendanceService.getTodayAttendance();

      final history = await historyFuture;
      final todayAll = await todayFuture;

      // Find today's log for this user
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      Map<String, dynamic>? userToday;
      final targetName = currentName.toLowerCase().trim();
      final targetUser = currentUsername.toLowerCase().trim();

      for (final r in todayAll) {
        final sId = r['staff_id']?.toString() ?? '';
        final sName = (r['staff_name']?.toString() ?? '').toLowerCase().trim();
        final rDate = r['date']?.toString() ?? '';
        if (rDate == todayStr) {
          if (sId == currentUserId ||
              (targetName.isNotEmpty && (sName.contains(targetName) || targetName.contains(sName))) ||
              (targetUser.isNotEmpty && sName.contains(targetUser))) {
            userToday = r;
            break;
          }
        }
      }

      // If userToday was not found in todayAll, check history top record
      if (userToday == null && history.isNotEmpty) {
        final firstDate = history.first['date']?.toString() ?? '';
        if (firstDate == todayStr) {
          userToday = history.first;
        }
      }

      if (mounted) {
        setState(() {
          _logs = history;
          _todayLog = userToday;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('StaffDtrHistorySheet._fetchHistory error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDateHeader(String rawDate) {
    if (rawDate.isEmpty) return 'Date N/A';
    try {
      final dt = DateTime.parse(rawDate);
      return DateFormat('EEEE, MMM d, yyyy').format(dt);
    } catch (_) {
      return rawDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentName = AuthService.currentUser?.fullName ?? AuthService.currentUsername;
    final currentRole = AuthService.currentAppUser?.position ?? 'Staff';

    // Calculate totals from _logs
    double totalHoursRendered = 0.0;
    int onTimeCount = 0;
    for (final r in _logs) {
      final rawH = r['total_hours'];
      if (rawH != null) {
        final h = double.tryParse(rawH.toString()) ?? 0.0;
        totalHoursRendered += h;
      }
      final status = (r['status']?.toString() ?? '').toLowerCase();
      if (status == 'on_time') onTimeCount++;
    }

    final onTimeRate = _logs.isNotEmpty
        ? ((onTimeCount / _logs.length) * 100).round()
        : 100;

    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Sheet Header & Handle
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
              decoration: const BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
              ),
              child: Column(
                children: [
                  // Grab Handle
                  Center(
                    child: Container(
                      width: 42,
                      height: 4.5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          CupertinoIcons.clock_fill,
                          size: 20,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Attendance & DTR History',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$currentName • $currentRole',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Refresh button
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(32, 32),
                        onPressed: _isLoading ? null : _fetchHistory,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: _isLoading
                              ? const CupertinoActivityIndicator(radius: 7)
                              : const Icon(
                                  CupertinoIcons.arrow_clockwise,
                                  size: 15,
                                  color: Color(0xFF475569),
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Close button
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(32, 32),
                        onPressed: () => Navigator.pop(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.xmark,
                            size: 15,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator(radius: 14))
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      children: [
                        // 1. TODAY'S LIVE ATTENDANCE STATUS
                        _buildTodayStatusCard(),
                        const SizedBox(height: 16),

                        // 2. SUMMARY METRICS (If logs exist)
                        if (_logs.isNotEmpty) ...[
                          Row(
                            children: [
                              _buildMetricChip(
                                label: 'TOTAL SHIFTS',
                                value: '${_logs.length}',
                                sub: 'days recorded',
                                icon: CupertinoIcons.calendar,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 8),
                              _buildMetricChip(
                                label: 'HOURS WORKED',
                                value: totalHoursRendered.toStringAsFixed(1),
                                sub: 'total render',
                                icon: CupertinoIcons.timer,
                                color: const Color(0xFF0284C7),
                              ),
                              const SizedBox(width: 8),
                              _buildMetricChip(
                                label: 'PUNCTUALITY',
                                value: '$onTimeRate%',
                                sub: 'on-time rate',
                                icon: CupertinoIcons.checkmark_shield_fill,
                                color: AppColors.success,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],

                        // 3. LOGS SECTION HEADER
                        Row(
                          children: [
                            const Icon(CupertinoIcons.list_bullet, size: 14, color: AppColors.accent),
                            const SizedBox(width: 6),
                            const Text(
                              'DTR LOGS (PAST 30 DAYS)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_logs.length} ${MathTextHelper.plural('record', _logs.length)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // 4. LIST OF LOGS OR EMPTY STATE
                        if (_logs.isEmpty)
                          _buildEmptyState()
                        else
                          ..._logs.map((row) => _buildDtrLogItem(row)),

                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayStatusCard() {
    final hasTimeIn = _todayLog != null && _todayLog!['time_in'] != null;
    final hasTimeOut = _todayLog != null && _todayLog!['time_out'] != null;
    final statusStr = (_todayLog?['status']?.toString() ?? '').toLowerCase();
    final isLate = statusStr == 'late';

    final timeInDisplay = hasTimeIn
        ? AttendanceService.formatTime(_todayLog!['time_in'])
        : '-- : --';

    final timeOutDisplay = hasTimeOut
        ? AttendanceService.formatTime(_todayLog!['time_out'])
        : (hasTimeIn ? 'On Shift (Pending Out)' : '-- : --');

    final totalHours = (hasTimeIn && hasTimeOut)
        ? AttendanceService.formatDuration(_todayLog!['time_in'], _todayLog!['time_out'])
        : (hasTimeIn ? AttendanceService.formatDuration(_todayLog!['time_in'], null) : '--');

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (hasTimeOut) {
      statusColor = const Color(0xFF1976D2);
      statusLabel = 'CLOCKED OUT';
      statusIcon = CupertinoIcons.check_mark_circled_solid;
    } else if (hasTimeIn) {
      statusColor = isLate ? const Color(0xFFD97706) : AppColors.success;
      statusLabel = isLate ? 'CLOCKED IN (LATE)' : 'CLOCKED IN (ON TIME)';
      statusIcon = CupertinoIcons.checkmark_alt_circle_fill;
    } else {
      statusColor = const Color(0xFFD97706);
      statusLabel = 'NOT TIMED IN YET';
      statusIcon = CupertinoIcons.clock_fill;
    }

    final todayStr = DateFormat('MMMM d, yyyy').format(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasTimeIn ? statusColor.withValues(alpha: 0.35) : const Color(0xFFE2E8F0),
          width: hasTimeIn ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentDark.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, size: 15, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  'TODAY • $todayStr',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: CupertinoColors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3 Metric Tiles
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: 'TIME IN',
                    value: timeInDisplay,
                    icon: CupertinoIcons.arrow_down_right_circle_fill,
                    iconColor: AppColors.success,
                    subtitle: hasTimeIn && isLate ? 'Late Arrival' : (hasTimeIn ? 'Recorded' : 'Pending'),
                    subColor: hasTimeIn && isLate ? const Color(0xFFD97706) : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    title: 'TIME OUT',
                    value: timeOutDisplay,
                    icon: CupertinoIcons.arrow_up_right_circle_fill,
                    iconColor: const Color(0xFF1976D2),
                    subtitle: hasTimeOut ? 'Shift Done' : (hasTimeIn ? 'On Shift' : 'Pending'),
                    subColor: hasTimeOut ? const Color(0xFF1976D2) : (hasTimeIn ? AppColors.success : AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    title: 'HOURS',
                    value: totalHours,
                    icon: CupertinoIcons.timer,
                    iconColor: AppColors.accent,
                    subtitle: hasTimeIn ? (hasTimeOut ? 'Rendered' : 'Ongoing') : '--',
                    subColor: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Footer info message
          Container(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(CupertinoIcons.radiowaves_right, size: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasTimeOut
                        ? 'Your attendance record for today is complete.'
                        : (hasTimeIn
                            ? 'Tap your RFID card before leaving to record official Time-Out.'
                            : 'Tap your RFID card on the reader to record official Time-In.'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required String subtitle,
    required Color subColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 11, color: iconColor),
              const SizedBox(width: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: subColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              sub,
              style: const TextStyle(
                fontSize: 9.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDtrLogItem(Map<String, dynamic> row) {
    final dateStr = row['date']?.toString() ?? '';
    final timeInStr = AttendanceService.formatTime(row['time_in']);
    final timeOutStr = AttendanceService.formatTime(row['time_out']);
    final statusStr = (row['status']?.toString() ?? 'on_time').toLowerCase();
    final isLate = statusStr == 'late';
    final hours = row['total_hours']?.toString() ?? '--';
    final branch = row['branch_name']?.toString() ?? 'Assigned Branch';
    final device = row['device_id']?.toString() ?? 'RFID Reader';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Date & Status & Hours
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDateHeader(dateStr),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: (isLate ? const Color(0xFFD97706) : AppColors.success)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  isLate ? 'LATE' : 'ON TIME',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: isLate ? const Color(0xFFD97706) : AppColors.success,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  AttendanceService.formatHoursDisplay(hours, row['time_in'], row['time_out']),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Branch
          Row(
            children: [
              const Icon(CupertinoIcons.location_solid, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  branch,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // In & Out Cards
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.arrow_down_right_circle_fill, size: 13, color: AppColors.success),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Time-In',
                            style: TextStyle(fontSize: 9.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            timeInStr,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.arrow_up_right_circle_fill, size: 13, color: Color(0xFF1976D2)),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Time-Out',
                              style: TextStyle(fontSize: 9.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              timeOutStr,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Footer
          Row(
            children: [
              const Icon(CupertinoIcons.checkmark_shield_fill, size: 11, color: AppColors.success),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Verified RFID Record • $device',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.calendar_badge_minus,
              size: 30,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Attendance History Found',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your Daily Time Record (DTR) will automatically appear here once you tap your RFID card on the driver reader or commissary base.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class MathTextHelper {
  static String plural(String word, int count) => count == 1 ? word : '${word}s';
}
