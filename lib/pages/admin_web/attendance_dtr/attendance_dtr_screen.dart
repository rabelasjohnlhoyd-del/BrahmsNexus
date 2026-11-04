import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/attendance_service.dart';
import '../../../services/excel_export_service.dart';
import '../../../services/supabase_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import '../admin_web_widgets/kpi_card.dart';
import '../admin_web_widgets/admin_pagination_bar.dart';

/// Admin Web Screen for viewing and auditing company-wide Daily Time Records (DTR)
/// and real-time biometric RFID attendance across all branches and commissary.
class AttendanceDtrScreen extends StatefulWidget {
  const AttendanceDtrScreen({super.key});

  @override
  State<AttendanceDtrScreen> createState() => _AttendanceDtrScreenState();
}

class _AttendanceDtrScreenState extends State<AttendanceDtrScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _selectedBranch = 'All Branches';
  String _selectedPosition = 'All Positions';
  String _selectedDatePreset = 'Today'; // 'Today', 'Yesterday', 'Past 7 Days', 'All Dates', 'Custom'
  DateTime? _customSelectedDate;

  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  bool _isExporting = false;
  bool _productionGateOpen = false;
  bool _isProductionGateLoading = false;
  Timer? _autoRefreshTimer;
  int _currentPage = 0;
  static const int _pageSize = 5;

  static const List<String> _branchOptions = [
    'All Branches',
    'Brgy. Gatid',
    'Brgy. Labuin',
    'Brgy. Sta. Clara Sur',
    'Brgy. Nanhaya',
    'Brgy. San Francisco',
    'Brgy. Dayap',
    'Central Commissary',
  ];

  static const List<String> _positionOptions = [
    'All Positions',
    'Branch Cook',
    'Driver',
    'Production Meat Cutter',
    'Production Cook',
    'Floating Cook',
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _loadProductionGate();
    AttendanceService.attendanceChangeNotifier.addListener(_onAttendanceChanged);
    _updateShellActions();

    // Auto-refresh periodically for real-time live attendance feed
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadLogs(isSilent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    AttendanceService.attendanceChangeNotifier.removeListener(_onAttendanceChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onAttendanceChanged() {
    if (mounted) _loadLogs(isSilent: true);
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([]);
  }

  String? _getDateFilterString() {
    final now = DateTime.now();
    switch (_selectedDatePreset) {
      case 'Today':
        return now.toIso8601String().substring(0, 10);
      case 'Yesterday':
        final yest = now.subtract(const Duration(days: 1));
        return yest.toIso8601String().substring(0, 10);
      case 'Custom':
        if (_customSelectedDate != null) {
          return _customSelectedDate!.toIso8601String().substring(0, 10);
        }
        return now.toIso8601String().substring(0, 10);
      case 'All Dates':
      case 'Past 7 Days':
      default:
        return null;
    }
  }

  Future<void> _loadLogs({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() => _isLoading = true);
    }

    try {
      final dateStr = _getDateFilterString();
      final branchId = _selectedBranch == 'All Branches'
          ? null
          : AttendanceService.normalizeBranchId(_selectedBranch);
      final posFilter = _selectedPosition == 'All Positions' ? null : _selectedPosition;

      final results = await AttendanceService.getAttendanceLogs(
        dateStr: dateStr,
        branchId: branchId,
        positionFilter: posFilter,
        query: _query,
        limit: 150,
      );

      // Filter locally for 'Past 7 Days' if selected
      var filtered = results;
      if (_selectedDatePreset == 'Past 7 Days') {
        final cutoff = DateTime.now().subtract(const Duration(days: 7));
        filtered = results.where((r) {
          final dStr = r['date']?.toString();
          if (dStr == null) return false;
          final dt = DateTime.tryParse(dStr);
          return dt != null && dt.isAfter(cutoff);
        }).toList();
      }

      if (mounted) {
        setState(() {
          _logs = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('AttendanceDtrScreen._loadLogs error: $e');
      if (mounted && !isSilent) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleExportExcel() async {
    if (_logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No attendance records available to export for the current filter.'),
          backgroundColor: AdminWebColors.warning,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final dateLabel = _selectedDatePreset == 'Custom' && _customSelectedDate != null
          ? DateFormat('yyyy-MM-dd').format(_customSelectedDate!)
          : _selectedDatePreset;

      await ExcelExportService.exportAttendanceDtrReport(
        records: _logs,
        selectedDate: dateLabel,
        selectedBranch: _selectedBranch,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Attendance & DTR Report (.xlsx) downloaded successfully!'),
              ],
            ),
            backgroundColor: AdminWebColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('Unable to export attendance report. Please try again.')),
              ],
            ),
            backgroundColor: AdminWebColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _selectCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customSelectedDate ?? DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AdminWebColors.accent,
              onPrimary: Colors.white,
              onSurface: AdminWebColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customSelectedDate = picked;
        _selectedDatePreset = 'Custom';
        _currentPage = 0;
      });
      _loadLogs();
    }
  }

  Future<void> _toggleTimeoutAllowed(Map<String, dynamic> log) async {
    final logId = log['id']?.toString();
    if (logId == null) return;
    final current = log['timeout_allowed'] == true;
    final nextVal = !current;
    setState(() => log['timeout_allowed'] = nextVal);

    try {
      await SupabaseService.client
          ?.from('attendance_logs')
          .update({'timeout_allowed': nextVal})
          .eq('id', logId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  nextVal ? Icons.check_circle_rounded : Icons.lock_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nextVal
                        ? 'Time-out clearance granted for ${log['staff_name']}.'
                        : 'Time-out clearance locked for ${log['staff_name']}.',
                  ),
                ),
              ],
            ),
            backgroundColor: nextVal ? const Color(0xFF059669) : const Color(0xFFD97706),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling timeout_allowed: $e');
      if (mounted) {
        setState(() => log['timeout_allowed'] = current);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Unable to update shift clearance. Please try again.')),
              ],
            ),
            backgroundColor: AdminWebColors.error,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showEmployeeDetailDialog(Map<String, dynamic> log) {
    final staffName = log['staff_name']?.toString() ?? 'Staff Member';
    final staffId = log['staff_id']?.toString() ?? 'ID N/A';
    final branch = log['branch_name']?.toString() ?? 'Assigned Station';
    final position = log['position']?.toString() ?? 'Staff';
    final date = log['date']?.toString() ?? '--';
    final timeIn = AttendanceService.formatTime(log['time_in']);
    final timeOut = AttendanceService.formatTime(log['time_out']);
    final totalHours = log['total_hours']?.toString() ?? '--';
    final status = (log['status']?.toString() ?? 'on_time').toUpperCase();
    final isLate = status == 'LATE';
    final rfidTag = log['rfid_uid']?.toString() ?? 'Not Recorded';
    final deviceId = log['device_id']?.toString() ?? 'Portable RFID Reader';
    final hasTimeOut = log['time_out'] != null && log['time_out'].toString().isNotEmpty;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final logDate = log['date']?.toString() ?? '';
    final logStatus = log['status']?.toString() ?? '';
    final isToday = logDate.isEmpty || logDate.startsWith(todayStr);
    final isIncomplete = logStatus == 'INCOMPLETE' || (!isToday && !hasTimeOut);
    final posLower = position.toLowerCase();
    final isProductionStaff = posLower.contains('cutter') || posLower.contains('production');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AdminWebColors.accent.withValues(alpha: 0.15),
              child: Text(
                staffName.isNotEmpty ? staffName[0].toUpperCase() : 'S',
                style: const TextStyle(fontWeight: FontWeight.w800, color: AdminWebColors.accent),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    staffName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AdminWebColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$position • $branch',
                    style: const TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              const Divider(height: 1, color: AdminWebColors.border),
              const SizedBox(height: 16),
              _buildDetailRow('Employee ID', staffId),
              _buildDetailRow('Date', date),
              _buildDetailRow('Time In', timeIn),
              _buildDetailRow(
                'Time Out',
                isIncomplete
                    ? 'No Time-Out Recorded'
                    : (timeOut.isEmpty || timeOut == '-- : --' ? 'On Shift (Pending Out)' : timeOut),
                color: isIncomplete ? AdminWebColors.error : null,
              ),
              _buildDetailRow(
                'Hours Worked',
                isIncomplete
                    ? '0.00 hrs (Incomplete Shift)'
                    : (timeOut.isNotEmpty && timeOut != '-- : --'
                        ? AttendanceService.formatHoursDisplay(totalHours, log['time_in'], log['time_out'])
                        : 'On Shift (Pending Out)'),
                color: isIncomplete ? AdminWebColors.error : null,
              ),
              _buildDetailRow(
                'Arrival Status',
                isLate ? 'Late Arrival (Past Shift Start)' : 'On Time',
                color: isLate ? AdminWebColors.warning : AdminWebColors.success,
              ),
              _buildDetailRow('RFID Card UID', rfidTag),
              _buildDetailRow('Scanner Device', deviceId),
              if (!hasTimeOut && isProductionStaff) ...[
                const SizedBox(height: 12),
                StatefulBuilder(
                  builder: (context, setModalState) {
                    final isAllowed = log['timeout_allowed'] == true;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isAllowed ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isAllowed ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isAllowed ? Icons.check_circle_rounded : Icons.lock_clock_rounded,
                            size: 20,
                            color: isAllowed ? const Color(0xFF059669) : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isAllowed ? 'Time-Out Clearance Granted' : 'Time-Out Clearance Locked',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: isAllowed ? const Color(0xFF065F46) : const Color(0xFF92400E),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isAllowed
                                      ? 'Staff is authorized to log out for this shift.'
                                      : 'Shift time-out is locked pending supervisor clearance.',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _toggleTimeoutAllowed(log);
                              setModalState(() {});
                            },
                            icon: Icon(
                              isAllowed ? Icons.lock_outline_rounded : Icons.check_rounded,
                              size: 14,
                            ),
                            label: Text(
                              isAllowed ? 'Revoke' : 'Authorize',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isAllowed ? const Color(0xFFEF4444) : const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.verified_rounded, size: 16, color: AdminWebColors.success),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Verified Biometric Record: Confirms physical presence at the assigned station via RFID tap.\n*Note: Attendance tracking is for operational shift auditing and does not penalize sales-based commission.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminWebColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color ?? AdminWebColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasActiveFilters =>
      _query.isNotEmpty ||
      _selectedBranch != 'All Branches' ||
      _selectedPosition != 'All Positions' ||
      _selectedDatePreset != 'Today';

  void _resetFilters() {
    setState(() {
      _query = '';
      _searchController.clear();
      _selectedBranch = 'All Branches';
      _selectedPosition = 'All Positions';
      _selectedDatePreset = 'Today';
      _customSelectedDate = null;
      _currentPage = 0;
    });
    _loadLogs();
  }

  Future<void> _loadProductionGate() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final result = await SupabaseService.client
          ?.from('production_shift_control')
          .select('is_open')
          .eq('date', today)
          .maybeSingle();
      if (mounted) {
        setState(() => _productionGateOpen = result?['is_open'] == true);
      }
    } catch (e) {
      debugPrint('_loadProductionGate error: $e');
    }
  }

  Future<void> _toggleProductionGate() async {
    final newVal = !_productionGateOpen;
    setState(() {
      _isProductionGateLoading = true;
      _productionGateOpen = newVal;
    });

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await SupabaseService.client
          ?.from('production_shift_control')
          .upsert({'date': today, 'is_open': newVal}, onConflict: 'date');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newVal ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  newVal
                      ? 'Production shift is now OPEN. Staff may now time in.'
                      : 'Production shift is now CLOSED.',
                ),
              ],
            ),
            backgroundColor: newVal ? const Color(0xFF059669) : const Color(0xFFD97706),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('_toggleProductionGate error: $e');
      if (mounted) {
        setState(() => _productionGateOpen = !newVal); // revert on error
      }
    } finally {
      if (mounted) setState(() => _isProductionGateLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate KPIs
    final uniqueStaff = <String>{};
    int onShiftNow = 0;
    int completedShifts = 0;

    for (final r in _logs) {
      final sId = r['staff_id']?.toString() ?? r['staff_name']?.toString() ?? '';
      if (sId.isNotEmpty) uniqueStaff.add(sId);

      final hasTimeOut = r['time_out'] != null && r['time_out'].toString().isNotEmpty;
      if (hasTimeOut) {
        completedShifts++;
      } else if (r['time_in'] != null && r['time_in'].toString().isNotEmpty) {
        onShiftNow++;
      }
    }

    return Container(
      color: AdminWebColors.background,
      child: Column(
        children: [
          // 1. TOP KPI CARDS ROW (Staff Present, On Shift Now, Completed Shifts)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                final kpis = [
                  KpiCard(
                    icon: Icons.groups_rounded,
                    label: 'STAFF PRESENT',
                    value: '${uniqueStaff.length}',
                    subtitle: '',
                  ),
                  KpiCard(
                    icon: Icons.schedule_rounded,
                    label: 'ON SHIFT NOW',
                    value: '$onShiftNow',
                    subtitle: '',
                  ),
                  KpiCard(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'COMPLETED SHIFTS',
                    value: '$completedShifts',
                    subtitle: '',
                  ),
                ];

                if (isWide) {
                  return Row(
                    children: kpis
                        .map((k) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                child: k,
                              ),
                            ))
                        .toList(),
                  );
                } else {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: kpis[0]),
                          const SizedBox(width: 10),
                          Expanded(child: kpis[1]),
                        ],
                      ),
                      const SizedBox(height: 10),
                      kpis[2],
                    ],
                  );
                }
              },
            ),
          ),

          

          // 3. FILTER & SEARCH CONTROLS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Search Box
                  SizedBox(
                    width: 280,
                    height: 42,
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 13, color: AdminWebColors.textPrimary, fontWeight: FontWeight.w600),
                      onChanged: (val) {
                        setState(() {
                          _query = val;
                          _currentPage = 0;
                        });
                        _loadLogs();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search staff, ID, or RFID...',
                        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AdminWebColors.textSecondary),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _query = '';
                                    _currentPage = 0;
                                  });
                                  _loadLogs();
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AdminWebColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AdminWebColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AdminWebColors.accent, width: 1.5),
                        ),
                      ),
                    ),
                  ),

                  // Date Filter Dropdown with icon
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminWebColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 15, color: AdminWebColors.accent),
                        const SizedBox(width: 8),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDatePreset == 'Custom' && _customSelectedDate != null
                                ? 'Custom'
                                : _selectedDatePreset,
                            items: [
                              const DropdownMenuItem(value: 'Today', child: Text('Today', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                              const DropdownMenuItem(value: 'Yesterday', child: Text('Yesterday', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                              const DropdownMenuItem(value: 'Past 7 Days', child: Text('Past 7 Days', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                              const DropdownMenuItem(value: 'All Dates', child: Text('All Dates', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                              if (_selectedDatePreset == 'Custom' && _customSelectedDate != null)
                                DropdownMenuItem(
                                  value: 'Custom',
                                  child: Text(
                                    DateFormat('MMM d, yyyy').format(_customSelectedDate!),
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AdminWebColors.accent),
                                  ),
                                ),
                              const DropdownMenuItem(
                                value: 'Pick Custom Date...',
                                child: Text('Pick Date...', style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic)),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == 'Pick Custom Date...') {
                                _selectCustomDate();
                              } else if (v != null && v != 'Custom') {
                                setState(() {
                                  _selectedDatePreset = v;
                                  _customSelectedDate = null;
                                  _currentPage = 0;
                                });
                                _loadLogs();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Branch Dropdown with icon
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminWebColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront_rounded, size: 15, color: AdminWebColors.accent),
                        const SizedBox(width: 8),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedBranch,
                            items: _branchOptions
                                .map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _selectedBranch = v;
                                  _currentPage = 0;
                                });
                                _loadLogs();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Position Dropdown with icon
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminWebColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge_outlined, size: 15, color: AdminWebColors.accent),
                        const SizedBox(width: 8),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPosition,
                            items: _positionOptions
                                .map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _selectedPosition = v;
                                  _currentPage = 0;
                                });
                                _loadLogs();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Production Gate Toggle
                  _isProductionGateLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AdminWebColors.accent),
                        )
                      : GestureDetector(
                          onTap: _toggleProductionGate,
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: _productionGateOpen ? const Color(0xFFECFDF5) : AdminWebColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _productionGateOpen ? const Color(0xFF059669) : AdminWebColors.error,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _productionGateOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
                                  size: 15,
                                  color: _productionGateOpen ? const Color(0xFF059669) : AdminWebColors.error,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _productionGateOpen ? 'Production: OPEN' : 'Production: CLOSED',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _productionGateOpen ? const Color(0xFF065F46) : AdminWebColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                  // Reset Filters Button (if active)
                  if (_hasActiveFilters)
                    TextButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                      label: const Text('Reset Filters', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        foregroundColor: AdminWebColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4. EXPORT DTR BUTTON (BELOW PRODUCTION CLOSED BOX)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _handleExportExcel,
                icon: _isExporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 16),
                label: Text(
                  _isExporting ? 'EXPORTING...' : 'EXPORT DTR (.XLSX)',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ),

          // 4. MAIN ATTENDANCE DATA TABLE (FULL WIDTH & BALANCED)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: GlassCard(
                padding: EdgeInsets.zero,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AdminWebColors.accent),
                      )
                    : _logs.isEmpty
                        ? _buildEmptyState()
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                const minTableWidth = 1100.0;
                                final tableWidth = constraints.maxWidth > minTableWidth
                                    ? constraints.maxWidth
                                    : minTableWidth;

                                final totalCount = _logs.length;
                                final totalPages = (totalCount / _pageSize).ceil();
                                final safeCurrentPage = totalPages > 0 ? _currentPage.clamp(0, totalPages - 1) : 0;
                                final pagedLogs = _logs.skip(safeCurrentPage * _pageSize).take(_pageSize).toList();

                                return Column(
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: SizedBox(
                                          width: tableWidth,
                                          child: Column(
                                            children: [
                                              // ── Full-Width Header Row ──
                                              Container(
                                                height: 52,
                                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                                decoration: BoxDecoration(
                                                  color: AdminWebColors.accent.withValues(alpha: 0.08),
                                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Expanded(flex: 5, child: Text('STAFF MEMBER', style: _colHeaderStyle)),
                                                    Expanded(flex: 4, child: Text('ROLE & BRANCH', style: _colHeaderStyle)),
                                                    Expanded(flex: 3, child: Text('DATE', style: _colHeaderStyle)),
                                                    Expanded(flex: 3, child: Text('TIME IN', style: _colHeaderStyle)),
                                                    Expanded(flex: 3, child: Text('TIME OUT', style: _colHeaderStyle)),
                                                    Expanded(flex: 4, child: Text('STATUS', style: _colHeaderStyle)),
                                                  ],
                                                ),
                                              ),

                                              // ── Full-Width Data Rows ──
                                              Expanded(
                                                child: ListView.separated(
                                                  itemCount: pagedLogs.length,
                                                  separatorBuilder: (context, index) =>
                                                      const Divider(height: 1, color: AdminWebColors.border),
                                                  itemBuilder: (context, index) => _buildTableRow(pagedLogs[index]),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (totalCount > _pageSize)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: AdminPaginationBar(
                                          currentPage: safeCurrentPage,
                                          totalItems: totalCount,
                                          pageSize: _pageSize,
                                          onPageChanged: (p) => setState(() => _currentPage = p),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const TextStyle _colHeaderStyle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 11.5,
    letterSpacing: 0.6,
    color: AdminWebColors.textPrimary,
  );

  String _formatDateString(String? raw) {
    if (raw == null || raw.isEmpty) return '--';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  Widget _buildTableRow(Map<String, dynamic> log) {
    final staffName = log['staff_name']?.toString() ?? 'Staff';
    final position = log['position']?.toString() ?? 'Staff';
    final branchName = log['branch_name']?.toString() ?? 'Central Commissary';
    final dateStr = _formatDateString(log['date']?.toString());
    final timeInStr = AttendanceService.formatTime(log['time_in']);
    final timeOutStr = AttendanceService.formatTime(log['time_out']);
    final hasTimeOut = log['time_out'] != null && log['time_out'].toString().isNotEmpty;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final logDate = log['date']?.toString() ?? '';
    final logStatus = log['status']?.toString() ?? '';
    final isToday = logDate.isEmpty || logDate.startsWith(todayStr);
    final isIncomplete = logStatus == 'INCOMPLETE' || (!isToday && !hasTimeOut);
    final posLower = position.toLowerCase();
    final isProductionStaff = posLower.contains('cutter') || posLower.contains('production');
    final isBranchRole = !(posLower.contains('driver') ||
        posLower.contains('cutter') ||
        posLower.contains('production') ||
        posLower.contains('meat') ||
        branchName == 'N/A' ||
        branchName == 'Central Commissary');
    final isTimeoutAllowed = log['timeout_allowed'] == true;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // 1. Staff Member (flex: 5)
          Expanded(
            flex: 5,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AdminWebColors.accent.withValues(alpha: 0.12),
                  child: Text(
                    staffName.isNotEmpty ? staffName[0].toUpperCase() : 'S',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AdminWebColors.accent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    staffName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AdminWebColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // 2. Role & Branch (flex: 4)
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  position,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isBranchRole) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, size: 12, color: AdminWebColors.accent),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          branchName,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // 3. Date (flex: 3)
          Expanded(
            flex: 3,
            child: Text(
              dateStr,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AdminWebColors.textPrimary),
            ),
          ),

          // 4. Time In (flex: 3)
          Expanded(
            flex: 3,
            child: Text(
              timeInStr,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AdminWebColors.textPrimary),
            ),
          ),

          // 5. Time Out (flex: 3)
          Expanded(
            flex: 3,
            child: Text(
              hasTimeOut ? timeOutStr : '--',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: hasTimeOut ? AdminWebColors.textPrimary : const Color(0xFF94A3B8),
              ),
            ),
          ),

          // 6. Status (flex: 4)
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isIncomplete
                          ? const Color(0xFFFEF2F2)
                          : hasTimeOut
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isIncomplete
                            ? const Color(0xFFFECACA)
                            : hasTimeOut
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFFA7F3D0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isIncomplete
                                ? const Color(0xFFDC2626)
                                : hasTimeOut
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isIncomplete
                              ? 'INCOMPLETE (NO TIMEOUT)'
                              : hasTimeOut
                                  ? 'SHIFT COMPLETED'
                                  : 'ON ACTIVE SHIFT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isIncomplete
                                ? const Color(0xFF991B1B)
                                : hasTimeOut
                                    ? const Color(0xFF334155)
                                    : const Color(0xFF065F46),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!hasTimeOut && isProductionStaff) ...[
                    const SizedBox(height: 4),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _toggleTimeoutAllowed(log),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isTimeoutAllowed
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isTimeoutAllowed
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isTimeoutAllowed
                                    ? Icons.check_circle_rounded
                                    : Icons.lock_clock_rounded,
                                size: 11,
                                color: isTimeoutAllowed
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFD97706),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isTimeoutAllowed ? 'Out Authorized' : 'Authorize Out',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isTimeoutAllowed
                                      ? const Color(0xFF047857)
                                      : const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AdminWebColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.access_time_rounded, size: 32, color: AdminWebColors.accent),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Attendance Records Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AdminWebColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'No attendance logs recorded for the selected date or search filter.\nNew logs will automatically appear once staff tap their RFID card.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              textAlign: TextAlign.center,
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                label: const Text('Reset Filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminWebColors.accent,
                  side: const BorderSide(color: AdminWebColors.accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
