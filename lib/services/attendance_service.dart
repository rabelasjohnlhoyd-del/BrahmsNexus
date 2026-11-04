import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/staff_member.dart';
import 'assignment_service.dart';
import 'firestore_service.dart';
import 'supabase_service.dart';

/// Service managing RFID attendance logs, live card enrollment,
/// and automated branch opening synchronization.
class AttendanceService {
  /// Normalizes any branch identifier or cook name to canonical 'br1'..'br6'
  static String normalizeBranchId(String raw, [String staffName = '']) {
    final s = raw.toLowerCase().trim();
    if (s == 'n/a' || s == 'na' || s.contains('/') || s == 'none' || s == 'unassigned' || s == 'any branch') {
      return 'unassigned';
    }
    if (s == 'commissary' || s == 'warehouse' || s == 'central' || s.contains('commissary')) {
      return 'commissary';
    }
    if (s == 'br1' || s == 'br2' || s == 'br3' || s == 'br4' || s == 'br5' || s == 'br6') {
      return s;
    }
    if (s.contains('gatid')) return 'br1';
    if (s.contains('labuin')) return 'br2';
    if (s.contains('clara')) return 'br3';
    if (s.contains('nanhaya')) return 'br4';
    if (s.contains('francisco')) return 'br5';
    if (s.contains('dayap')) return 'br6';

    final nameLower = staffName.toLowerCase();
    // Virgenita Espiritu is br4 (Nanhaya), Patricia Espiritu is br3 (Sta Clara Sur)
    if (nameLower.contains('virgenita')) return 'br4';
    if (nameLower.contains('patricia') || nameLower.contains('mharie')) return 'br3';
    if (nameLower.contains('jovelle')) return 'br1';
    if (nameLower.contains('jobelle') || nameLower.contains('fuentes')) return 'br2';
    if (nameLower.contains('alma') || nameLower.contains('agonos')) return 'br5';
    if (nameLower.contains('leany') || nameLower.contains('malla')) return 'br6';
    if (nameLower.contains('jhon patrick') || nameLower.contains('patrick')) return 'br4';
    if (nameLower.contains('joshua') || nameLower.contains('montes')) return 'br5';
    if (nameLower.contains('prince') || nameLower.contains('celis')) return 'br6';
    if (nameLower.contains('camila')) return 'br1';

    return s;
  }

  /// Resolves the store branch ('br1'..'br6') for a staff member using all available sources:
  /// raw branch string, staff name, AssignmentService cache, and Supabase staff records.
  static String resolveBranchForStaff(String rawBranchId, String staffName, [String staffId = '']) {
    var bId = normalizeBranchId(rawBranchId, staffName);
    if (bId.isNotEmpty && bId != 'commissary' && bId != 'unassigned') {
      return bId;
    }

    // 1. Try AssignmentService cache
    if (staffName.isNotEmpty) {
      final assigned = AssignmentService.getAssignedBranch(staffName);
      if (assigned.isNotEmpty) {
        bId = normalizeBranchId(assigned, staffName);
        if (bId.isNotEmpty && bId != 'commissary' && bId != 'unassigned') return bId;
      }
    }
    if (staffId.isNotEmpty) {
      final assigned = AssignmentService.getAssignedBranch(staffId);
      if (assigned.isNotEmpty) {
        bId = normalizeBranchId(assigned, staffName);
        if (bId.isNotEmpty && bId != 'commissary' && bId != 'unassigned') return bId;
      }
    }

    // 2. Try Supabase staff list
    try {
      final allStaff = SupabaseService.getAllStaff();
      final staff = allStaff.cast<StaffMember?>().firstWhere(
        (s) => s != null && (
          (staffId.isNotEmpty && s.id.toLowerCase() == staffId.toLowerCase()) ||
          (staffName.isNotEmpty && s.fullName.toLowerCase() == staffName.toLowerCase()) ||
          (staffName.isNotEmpty && s.username.toLowerCase() == staffName.toLowerCase())
        ),
        orElse: () => null,
      );
      if (staff != null && staff.branch.isNotEmpty) {
        bId = normalizeBranchId(staff.branch, staff.fullName);
        if (bId.isNotEmpty && bId != 'commissary' && bId != 'unassigned') return bId;
      }
    } catch (_) {}

    return bId;
  }

  static SupabaseClient? get _client => SupabaseService.client;

  /// In-memory cache of today's attendance logs for fast UI access
  static List<Map<String, dynamic>> _todayLogs = [];

  // ===========================================================================
  // 1. ATTENDANCE LOG QUERIES & REALTIME
  // ===========================================================================

  /// Fetches today's attendance logs from Supabase
  static Future<List<Map<String, dynamic>>> getTodayAttendance() async {
    final client = _client;
    if (client == null) return _todayLogs;

    try {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final res = await client
          .from('attendance_logs')
          .select()
          .eq('date', todayStr)
          .order('time_in', ascending: false);

      final list = (res as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
      _todayLogs = list;
      return list;
    } catch (e) {
      debugPrint('AttendanceService.getTodayAttendance error: $e');
      return _todayLogs;
    }
  }

  /// Streams today's attendance logs in real time
  static Stream<List<Map<String, dynamic>>> watchTodayAttendance() {
    final client = _client;
    if (client == null) return Stream.value(_todayLogs);

    try {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      return client
          .from('attendance_logs')
          .stream(primaryKey: ['id'])
          .eq('date', todayStr)
          .order('time_in', ascending: false)
          .map((rows) {
            final list = rows.map((r) => Map<String, dynamic>.from(r)).toList();
            _todayLogs = list;
            return list;
          });
    } catch (e) {
      debugPrint('AttendanceService.watchTodayAttendance stream error: $e');
      return Stream.value(_todayLogs);
    }
  }

  /// Real-time stream of today's attendance log for a specific staff member.
  /// Used by Staff App (Cook, Cutter, Driver) to show their Time In and Time Out live.
  static Stream<Map<String, dynamic>?> watchStaffTodayAttendance({
    required String staffId,
    String? staffName,
    String? username,
  }) {
    final client = _client;
    if (client == null) return Stream.value(null);

    try {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      return client
          .from('attendance_logs')
          .stream(primaryKey: ['id'])
          .eq('date', todayStr)
          .map((rows) {
            final targetName = (staffName ?? '').toLowerCase().trim();
            final targetUser = (username ?? '').toLowerCase().trim();

            final match = rows.firstWhere(
              (r) {
                final sId = r['staff_id']?.toString() ?? '';
                final sName = (r['staff_name']?.toString() ?? '').toLowerCase().trim();
                return sId == staffId ||
                    (targetName.isNotEmpty && sName.contains(targetName)) ||
                    (targetUser.isNotEmpty && sName.contains(targetUser));
              },
              orElse: () => {},
            );
            return match.isNotEmpty ? Map<String, dynamic>.from(match) : null;
          });
    } catch (e) {
      debugPrint('watchStaffTodayAttendance stream error: $e');
      return Stream.value(null);
    }
  }

  /// Fetches recent attendance history for a specific staff member.
  static Future<List<Map<String, dynamic>>> getStaffAttendanceHistory({
    required String staffId,
    String? staffName,
    String? username,
    int limit = 60,
  }) async {
    final client = _client;
    if (client == null) return [];

    try {
      final allStaff = SupabaseService.getAllStaff();
      StaffMember? match;
      for (final s in allStaff) {
        final uMatch = username != null &&
            username.isNotEmpty &&
            s.username.toLowerCase().trim() == username.toLowerCase().trim();
        final idMatch = s.id == staffId;
        final nameMatch = staffName != null &&
            staffName.isNotEmpty &&
            (s.fullName.toLowerCase().contains(staffName.toLowerCase().trim()) ||
                staffName.toLowerCase().contains(s.fullName.toLowerCase().trim()));
        if (uMatch || idMatch || nameMatch) {
          match = s;
          break;
        }
      }

      final possibleIds = <String>{staffId};
      if (match != null && match.id.isNotEmpty) possibleIds.add(match.id);
      final possibleNames = <String>{};
      if (staffName != null && staffName.trim().isNotEmpty) possibleNames.add(staffName.trim());
      if (match != null && match.fullName.trim().isNotEmpty) possibleNames.add(match.fullName.trim());

      final orConditions = <String>[];
      for (final id in possibleIds) {
        if (id.isNotEmpty && id != 'guest') orConditions.add('staff_id.eq.$id');
      }
      for (final name in possibleNames) {
        if (name.isNotEmpty) orConditions.add('staff_name.ilike.%$name%');
      }

      var query = client.from('attendance_logs').select();
      if (orConditions.isNotEmpty) {
        query = query.or(orConditions.join(','));
      }

      final res = await query
          .order('date', ascending: false)
          .order('time_in', ascending: false)
          .limit(limit);

      final results = (res as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      if (results.isNotEmpty) return results;
    } catch (e) {
      debugPrint('getStaffAttendanceHistory filtered query error: $e');
    }

    // Fallback: fetch recent logs and filter locally
    try {
      final res = await client
          .from('attendance_logs')
          .select()
          .order('date', ascending: false)
          .order('time_in', ascending: false)
          .limit(100);

      final list = (res as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      final targetName = (staffName ?? '').toLowerCase().trim();
      final targetUser = (username ?? '').toLowerCase().trim();

      return list.where((r) {
        final sId = (r['staff_id']?.toString() ?? '').toLowerCase().trim();
        final sName = (r['staff_name']?.toString() ?? '').toLowerCase().trim();
        return sId == staffId.toLowerCase().trim() ||
            (targetName.isNotEmpty && (sName.contains(targetName) || targetName.contains(sName))) ||
            (targetUser.isNotEmpty && sName.contains(targetUser));
      }).toList();
    } catch (e) {
      debugPrint('getStaffAttendanceHistory fallback error: $e');
      return [];
    }
  }

  /// Fetches attendance logs for Admin Web with optional filters.
  static Future<List<Map<String, dynamic>>> getAttendanceLogs({
    String? dateStr,
    String? branchId,
    String? positionFilter,
    String? query,
    int limit = 100,
  }) async {
    final client = _client;
    if (client == null) return _todayLogs;

    try {
      var queryBuilder = client.from('attendance_logs').select();
      if (dateStr != null && dateStr.isNotEmpty && dateStr != 'All') {
        queryBuilder = queryBuilder.eq('date', dateStr);
      }
      if (branchId != null && branchId.isNotEmpty && branchId != 'All') {
        queryBuilder = queryBuilder.eq('branch_id', branchId);
      }
      if (positionFilter != null && positionFilter.isNotEmpty && positionFilter != 'All') {
        queryBuilder = queryBuilder.ilike('position', '%$positionFilter%');
      }

      final res = await queryBuilder.order('time_in', ascending: false).limit(limit);
      var list = (res as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();

      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        list = list.where((item) {
          final sName = (item['staff_name']?.toString() ?? '').toLowerCase();
          final pos = (item['position']?.toString() ?? '').toLowerCase();
          final bName = (item['branch_name']?.toString() ?? '').toLowerCase();
          final rfid = (item['rfid_uid']?.toString() ?? '').toLowerCase();
          return sName.contains(q) || pos.contains(q) || bName.contains(q) || rfid.contains(q);
        }).toList();
      }

      return list;
    } catch (e) {
      debugPrint('AttendanceService.getAttendanceLogs error: $e');
      return _todayLogs;
    }
  }

  // ===========================================================================
  // RFID-BASED PAYROLL: Monthly Days Worked Query
  // ===========================================================================

  /// Returns the number of unique days in [year]/[month] where a staff member
  /// (matched by position keywords) has BOTH a time_in AND a time_out recorded.
  ///
  /// A day counts only when the employee tapped in AND tapped out (completed shift).
  /// No time_out = absent/incomplete = not counted for payroll.
  ///
  /// [positionKeywords] - keywords to match against the `position` column.
  /// [staffName] - optional partial name match for disambiguation.
  static Future<int> getRfidDaysWorkedForMonth({
    required List<String> positionKeywords,
    String? staffName,
    int? year,
    int? month,
  }) async {
    final client = _client;
    if (client == null) return 0;

    final now = DateTime.now();
    final targetYear = year ?? now.year;
    final targetMonth = month ?? now.month;

    final startDate =
        '${targetYear.toString()}-${targetMonth.toString().padLeft(2, '0')}-01';
    final endMonth = targetMonth == 12 ? 1 : targetMonth + 1;
    final endYear = targetMonth == 12 ? targetYear + 1 : targetYear;
    final endDate =
        '${endYear.toString()}-${endMonth.toString().padLeft(2, '0')}-01';

    try {
      var query = client
          .from('attendance_logs')
          .select('date, time_in, time_out, position, staff_name')
          .gte('date', startDate)
          .lt('date', endDate);

      if (staffName != null && staffName.trim().isNotEmpty) {
        query = query.ilike('staff_name', '%${staffName.trim()}%');
      }

      final res = await query.order('date', ascending: true).limit(200);
      final rows = (res as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();

      final posRows = rows.where((r) {
        final pos = (r['position']?.toString() ?? '').toLowerCase();
        return positionKeywords.any((kw) => pos.contains(kw.toLowerCase()));
      }).toList();

      // Count UNIQUE dates where BOTH time_in AND time_out are non-null/non-empty
      final completedDates = <String>{};
      for (final row in posRows) {
        final dateStr = row['date']?.toString() ?? '';
        final timeIn = row['time_in']?.toString() ?? '';
        final timeOut = row['time_out']?.toString() ?? '';
        if (dateStr.isNotEmpty && timeIn.isNotEmpty && timeOut.isNotEmpty) {
          completedDates.add(dateStr);
        }
      }

      debugPrint(
          '[RFID Payroll] pos=$positionKeywords name=$staffName -> '
          '${completedDates.length} completed days in $targetYear-$targetMonth');
      return completedDates.length;
    } catch (e) {
      debugPrint('AttendanceService.getRfidDaysWorkedForMonth error: $e');
      return 0;
    }
  }

  /// Returns detailed RFID attendance rows for the month for a given staff/position.
  /// Used to build the per-day attendance breakdown shown in the payroll card.
  static Future<List<Map<String, dynamic>>> getRfidMonthlyAttendanceDetail({
    required List<String> positionKeywords,
    String? staffName,
    int? year,
    int? month,
  }) async {
    final client = _client;
    if (client == null) return [];

    final now = DateTime.now();
    final targetYear = year ?? now.year;
    final targetMonth = month ?? now.month;

    final startDate =
        '${targetYear.toString()}-${targetMonth.toString().padLeft(2, '0')}-01';
    final endMonth = targetMonth == 12 ? 1 : targetMonth + 1;
    final endYear = targetMonth == 12 ? targetYear + 1 : targetYear;
    final endDate =
        '${endYear.toString()}-${endMonth.toString().padLeft(2, '0')}-01';

    try {
      var query = client
          .from('attendance_logs')
          .select(
              'date, time_in, time_out, position, staff_name, status, total_hours')
          .gte('date', startDate)
          .lt('date', endDate);

      if (staffName != null && staffName.trim().isNotEmpty) {
        query = query.ilike('staff_name', '%${staffName.trim()}%');
      }

      final res = await query.order('date', ascending: false).limit(200);
      final rows = (res as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();

      return rows.where((r) {
        final pos = (r['position']?.toString() ?? '').toLowerCase();
        return positionKeywords.any((kw) => pos.contains(kw.toLowerCase()));
      }).toList();
    } catch (e) {
      debugPrint(
          'AttendanceService.getRfidMonthlyAttendanceDetail error: $e');
      return [];
    }
  }
  /// Formats an ISO string, Timestamp, or DateTime to "hh:mm AM/PM" (e.g. 06:45 AM)
  /// Always converts to Philippine Time (Asia/Manila, UTC+8).
  static String formatTime(dynamic value) {
    if (value == null) return '--';
    try {
      DateTime utc;
      if (value is DateTime) {
        utc = value.isUtc ? value : value.toUtc();
      } else if (value is String) {
        final parsed = DateTime.parse(value);
        utc = parsed.isUtc ? parsed : parsed.toUtc();
      } else {
        return value.toString();
      }
      // Convert to Philippine Time (UTC+8)
      final pht = utc.add(const Duration(hours: 8));
      final hour = pht.hour > 12 ? pht.hour - 12 : (pht.hour == 0 ? 12 : pht.hour);
      final minute = pht.minute.toString().padLeft(2, '0');
      final period = pht.hour >= 12 ? 'PM' : 'AM';
      return '${hour.toString().padLeft(2, '0')}:$minute $period';
    } catch (_) {
      return value.toString();
    }
  }

  /// Formats duration between time_in and time_out (e.g. "8h 15m")
  static String formatDuration(dynamic timeInVal, dynamic timeOutVal) {
    if (timeInVal == null) return '--';
    try {
      final inTime = (timeInVal is DateTime ? timeInVal : DateTime.parse(timeInVal.toString())).toUtc();
      final outTime = (timeOutVal != null
          ? (timeOutVal is DateTime ? timeOutVal : DateTime.parse(timeOutVal.toString()))
          : DateTime.now()).toUtc();

      var diff = outTime.difference(inTime);
      if (diff.isNegative) {
        diff = diff.abs();
      }
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      if (timeOutVal == null) {
        return '${hours}h ${minutes}m (On Shift)';
      }
      return '${hours}h ${minutes}m';
    } catch (_) {
      return '--';
    }
  }

  /// Formats total hours into clean, professional DTR representation (e.g. "7h 40m" or "8h 00m").
  /// Handles both raw decimal numbers (e.g. 7.67 or -7.67) and actual time_in/time_out timestamps.
  static String formatHoursDisplay(dynamic totalHoursVal, [dynamic timeInVal, dynamic timeOutVal]) {
    // 1. If time_in and time_out are both provided, compute exact duration from timestamps
    if (timeInVal != null && timeOutVal != null && timeOutVal.toString().isNotEmpty) {
      final formatted = formatDuration(timeInVal, timeOutVal);
      if (formatted != '--') return formatted;
    }

    // 2. Format from numeric total_hours
    if (totalHoursVal == null) return '--';
    final parsed = double.tryParse(totalHoursVal.toString());
    if (parsed == null) return '--';

    // Clamp out any negative numbers caused by timezone mismatch
    final positiveHours = parsed.abs();
    final wholeHours = positiveHours.floor();
    final minutes = ((positiveHours - wholeHours) * 60).round();

    if (wholeHours == 0 && minutes == 0) return '0h 0m';
    return '${wholeHours}h ${minutes}m';
  }

  // ===========================================================================
  // 2. RFID TAP PROCESSING & BRANCH AUTO-OPENING
  // ===========================================================================

  /// Processes an RFID tap event from the ESP32 reader or app simulation.
  /// Automatically:
  /// 1. Calls Supabase RPC `process_rfid_tap`
  /// 2. If employee is a Branch Cook, synchronizes Firestore `branch_status`
  ///    to immediately set `isOpen: true` and unlock the Cook's mobile app.
  static Future<Map<String, dynamic>> processTap({
    required String rfidUid,
    required String deviceId,
    String branchId = '',
  }) async {
    final client = _client;
    final cleanUid = rfidUid.trim().toUpperCase();

    Map<String, dynamic> result = {
      'success': false,
      'message': 'Database not connected',
    };

    if (client != null) {
      try {
        final rpcRes = await client.rpc('process_rfid_tap', params: {
          'p_rfid_uid': cleanUid,
          'p_device_id': deviceId,
          'p_branch_id': branchId,
        });

        if (rpcRes != null && rpcRes is Map) {
          result = Map<String, dynamic>.from(rpcRes);
        }
      } catch (e) {
        debugPrint('AttendanceService.processTap rpc error: $e');
        final errStr = e.toString().toLowerCase();
        final isNetErr = errStr.contains('socketexception') ||
            errStr.contains('clientexception') ||
            errStr.contains('failed host lookup') ||
            errStr.contains('network is unreachable') ||
            errStr.contains('connection refused') ||
            errStr.contains('timeoutexception') ||
            errStr.contains('handshakeexception');

        if (isNetErr) {
          result = {
            'success': false,
            'code': 'CONN_ERR',
            'message': 'No internet connection on phone.',
            'is_offline': true,
          };
        } else {
          result = {
            'success': false,
            'code': 'SERVER_ERR',
            'message': 'System temporary error. Tap saved to offline queue.',
            'details': e.toString(),
            'is_offline': true,
          };
        }
      }
    }

    // Secondary Action: If Cook Time-In, Auto-Open Branch in Firestore!
    if (result['success'] == true) {
      final type = result['type'] as String?;
      final position = (result['position'] as String? ?? '').toLowerCase();
      final cookName = result['staff_name'] as String? ?? 'Branch Cook';
      final cookId = result['staff_id'] as String? ?? 'cook';
      final rawBId = (result['branch_id'] as String? ?? branchId).toLowerCase();
      final bId = normalizeBranchId(rawBId, cookName);
      final bName = result['branch_name'] as String? ?? 'Assigned Branch';

      final isCook = position.contains('cook') && !position.contains('production');
      final isCommissary = rawBId == 'commissary' || deviceId.toLowerCase().contains('commissary');

      if (isCook && !isCommissary && bId.isNotEmpty && bId != 'commissary') {
        if (type == 'time_in') {
          // Open branch & unlock cook supply verification
          FirestoreService.processBranchCookRfidTap(
            branchId: bId,
            branchName: bName,
            cookName: cookName,
            cookId: cookId,
            isDeployment: true,
            rfidTag: cleanUid,
            deviceId: deviceId,
          ).catchError((e) {
            debugPrint('processBranchCookRfidTap opening error: $e');
            return false;
          });
        } else if (type == 'time_out') {
          // Close branch upon departure
          FirestoreService.processBranchCookRfidTap(
            branchId: bId,
            branchName: bName,
            cookName: cookName,
            cookId: cookId,
            isDeployment: false,
            rfidTag: cleanUid,
            deviceId: deviceId,
          ).catchError((e) {
            debugPrint('processBranchCookRfidTap closing error: $e');
            return false;
          });
        }
      }
    }

    return result;
  }

  // ===========================================================================
  // 3. ADMIN WEB LIVE CARD ENROLLMENT LISTENER
  // ===========================================================================

  /// Listens to `rfid_scan_queue` in Supabase for card taps during enrollment.
  /// When Owner clicks "Scan via Base Reader" on Admin Web, this stream listens
  /// for the next tapped card UID.
  static Stream<String> listenForCardEnrollment({Duration timeout = const Duration(seconds: 45)}) {
    final client = _client;
    if (client == null) return const Stream.empty();

    final controller = StreamController<String>();
    RealtimeChannel? channel;
    Timer? timeoutTimer;
    Timer? pollTimer;

    try {
      String? lastSeenId;

      client
          .from('rfid_scan_queue')
          .select('id, rfid_uid, scanned_at')
          .order('scanned_at', ascending: false)
          .limit(1)
          .then((init) {
        if ((init as List).isNotEmpty) {
          lastSeenId = init.first['id']?.toString();
        }
      }).catchError((_) {});

      channel = client
          .channel('public:rfid_scan_queue')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'rfid_scan_queue',
            callback: (payload) {
              final newRecord = payload.newRecord;
              final scannedUid = newRecord['rfid_uid'] as String?;
              final rowId = newRecord['id']?.toString();
              if (scannedUid != null && scannedUid.isNotEmpty && !controller.isClosed) {
                lastSeenId = rowId;
                controller.add(scannedUid.toUpperCase());
              }
            },
          )
          .subscribe();

      // Polling fallback every 1 second (ID-based, zero timezone or clock skew issues)
      pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (controller.isClosed) {
          timer.cancel();
          return;
        }
        try {
          final res = await client
              .from('rfid_scan_queue')
              .select('id, rfid_uid, scanned_at')
              .order('scanned_at', ascending: false)
              .limit(1);

          if ((res as List).isNotEmpty) {
            final row = res.first;
            final rowId = row['id']?.toString();
            if (rowId != null && rowId != lastSeenId) {
              lastSeenId = rowId;
              final uid = row['rfid_uid']?.toString();
              if (uid != null && uid.isNotEmpty && !controller.isClosed) {
                controller.add(uid.toUpperCase());
              }
            }
          }
        } catch (_) {}
      });

      timeoutTimer = Timer(timeout, () {
        if (!controller.isClosed) {
          controller.close();
        }
      });
    } catch (e) {
      debugPrint('listenForCardEnrollment error: $e');
      controller.addError(e);
    }

    controller.onCancel = () {
      timeoutTimer?.cancel();
      pollTimer?.cancel();
      if (channel != null) {
        client.removeChannel(channel);
      }
    };

    return controller.stream;
  }
  // ===========================================================================
  // 4. SUPABASE -> FIRESTORE REALTIME SYNC (Bridge ESP32 Taps to App State)
  // ===========================================================================

  static RealtimeChannel? _syncChannel;
  static RealtimeChannel? _scanQueueChannel;
  static Timer? _pollTimer;
  static DateTime _lastPollTime = DateTime.now().toUtc();
  static bool _isSyncStarted = false;
  static final Map<String, int> _lastProcessedTapMs = {};

  /// Global notifier that fires whenever attendance logs or scans are received
  static final ValueNotifier<int> attendanceChangeNotifier = ValueNotifier<int>(0);

  /// Canonical branch display name lookup
  static String canonicalBranchName(String branchId) {
    switch (branchId.toLowerCase().trim()) {
      case 'br1':
        return 'Gatid';
      case 'br2':
        return 'Labuin';
      case 'br3':
        return 'Sta. Clara Sur';
      case 'br4':
        return 'Nanhaya';
      case 'br5':
        return 'San Francisco';
      case 'br6':
        return 'Dayap';
      default:
        return 'Branch $branchId';
    }
  }

  /// Starts listening to Supabase attendance_logs and rfid_scan_queue in real-time.
  /// When ESP32 posts a tap to Supabase, this automatically syncs to Firestore
  /// branch_status so the Driver Route stop marks as completed and the Cook's
  /// Staff App instantly unlocks in real-time!
  static void ensureAttendanceSync() {
    if (_isSyncStarted) return;
    final client = _client;
    if (client == null) return;

    try {
      _isSyncStarted = true;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      _lastPollTime = DateTime.now().toUtc().subtract(const Duration(seconds: 10));

      // 1. Realtime listener on verified attendance_logs
      _syncChannel = client
          .channel('public:attendance_logs_sync')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'attendance_logs',
            callback: (payload) {
              final record = payload.newRecord;
              if (record.isNotEmpty) {
                final logDate = record['date']?.toString() ?? '';
                if (logDate == todayStr || logDate.isEmpty) {
                  _syncLogToFirestore(record);
                }
              }
            },
          )
          .subscribe();

      // 2. Periodic polling fallback every 2.5s on attendance_logs to guarantee zero missed checkouts
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) async {
        if (!_isSyncStarted) {
          timer.cancel();
          return;
        }
        try {
          final nowLocalStr = DateTime.now().toIso8601String().substring(0, 10);
          final logsRes = await client
              .from('attendance_logs')
              .select()
              .eq('date', nowLocalStr);

          for (final row in (logsRes as List)) {
            _syncLogToFirestore(Map<String, dynamic>.from(row as Map));
          }
        } catch (_) {}
      });

      debugPrint('[AttendanceService] Supabase RFID attendance_logs sync channel & polling started.');
    } catch (e) {
      debugPrint('AttendanceService.ensureAttendanceSync error: $e');
    }
  }

  /// Stops and cleans up the Supabase real-time sync channel if active.
  static void stopAttendanceSync() {
    try {
      _syncChannel?.unsubscribe();
      _syncChannel = null;
      _scanQueueChannel?.unsubscribe();
      _scanQueueChannel = null;
      _pollTimer?.cancel();
      _pollTimer = null;
      _isSyncStarted = false;
      debugPrint('[AttendanceService] Supabase RFID sync channels stopped.');
    } catch (e) {
      debugPrint('AttendanceService.stopAttendanceSync error: $e');
    }
  }

  /// Finds staff member associated with the scanned RFID UID
  static Future<StaffMember?> findStaffByRfid(String rawUid) async {
    final cleanUid = rawUid.replaceAll(':', '').replaceAll(' ', '').toUpperCase().trim();
    if (cleanUid.isEmpty) return null;

    // 1. In-memory check
    final allStaff = SupabaseService.getAllStaff();
    for (final s in allStaff) {
      if (s.isArchived) continue;
      final sTag = s.rfidTag.replaceAll(':', '').replaceAll(' ', '').toUpperCase().trim();
      if (sTag.isNotEmpty && (sTag == cleanUid || s.rfidTag.toUpperCase().trim() == rawUid.toUpperCase().trim())) {
        return s;
      }
    }

    // 2. Remote database lookup in staff_profiles
    final client = _client;
    if (client != null) {
      try {
        final res = await client
            .from('staff_profiles')
            .select()
            .eq('is_archived', false);
        for (final row in (res as List)) {
          final rTag = (row['rfid_tag']?.toString() ?? '').toUpperCase().trim();
          final cleanRTag = rTag.replaceAll(':', '').replaceAll(' ', '');
          if (rTag == rawUid.toUpperCase().trim() || cleanRTag == cleanUid) {
            return StaffMember.fromMap(Map<String, dynamic>.from(row as Map));
          }
        }
      } catch (e) {
        debugPrint('_findStaffByRfid remote error: $e');
      }
    }

    return null;
  }

  /// Handles any RFID card tap detected in rfid_scan_queue (works for any device ID & state)
  static Future<void> _handleRfidQueueScan(Map<String, dynamic> record) async {
    try {
      final rfidUid = (record['rfid_uid']?.toString() ?? '').trim();
      final deviceId = record['device_id']?.toString() ?? 'esp32_reader';
      if (rfidUid.isEmpty) return;

      final cleanUid = rfidUid.replaceAll(':', '').replaceAll(' ', '').toUpperCase();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (_lastProcessedTapMs.containsKey(cleanUid) && (nowMs - _lastProcessedTapMs[cleanUid]!) < 3000) {
        return; // Debounce rapid consecutive taps
      }
      _lastProcessedTapMs[cleanUid] = nowMs;

      debugPrint('[AttendanceService] Live RFID tap received: $rfidUid (device: $deviceId)');

      // If tap originated from commissary base reader, it is strictly for production attendance / enrollment,
      // NOT for driver store arrival / departure automation!
      if (deviceId.toLowerCase().contains('commissary') || deviceId == 'esp32_commissary_base') {
        debugPrint('[AttendanceService] Base station tap ($deviceId) handled via Supabase DTR; skipping store branch automation.');
        return;
      }

      // Look up staff member
      final staff = await findStaffByRfid(rfidUid);
      if (staff == null) {
        debugPrint('[AttendanceService] Unregistered RFID tag tapped: $rfidUid');
        return;
      }

      final position = staff.position.toLowerCase();
      final isCook = position.contains('cook') && !position.contains('production');
      if (!isCook) {
        debugPrint('[AttendanceService] Staff is not a Branch Cook (${staff.position}): ${staff.fullName}');
        return;
      }

      // Determine canonical branch ID
      String branchId = normalizeBranchId(staff.branch, staff.fullName);
      if (branchId.isEmpty || branchId == 'commissary' || branchId == 'unassigned' || branchId == 'n/a' || branchId.contains('/')) {
        branchId = normalizeBranchId('', staff.fullName);
      }
      if (branchId.isEmpty || branchId == 'commissary' || branchId == 'unassigned' || branchId == 'n/a' || branchId.contains('/')) {
        debugPrint('[AttendanceService] Could not resolve store branch for cook: ${staff.fullName}');
        return;
      }

      final branchName = canonicalBranchName(branchId);
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      // Check current Firestore store status
      bool isDeployment = true;
      try {
        final statusDoc = await FirebaseFirestore.instance.collection('branch_status').doc(branchId).get();
        final isOpen = statusDoc.data()?['isOpen'] == true;
        final openedDateStr = statusDoc.data()?['openedDateStr']?.toString() ?? '';
        final isCurrentlyOpenToday = isOpen && openedDateStr == todayStr;

        // Check if cook has an active attendance session today in Supabase (timed in but not timed out)
        bool hasActiveTimeInWithoutTimeOut = false;
        final client = _client;
        if (client != null) {
          try {
            final existingLogs = await client
                .from('attendance_logs')
                .select('id, time_in, time_out')
                .eq('staff_id', staff.id)
                .eq('date', todayStr)
                .order('time_in', ascending: false)
                .limit(1);
            if ((existingLogs as List).isNotEmpty) {
              final row = existingLogs.first;
              if (row['time_in'] != null && (row['time_out'] == null || row['time_out'].toString().isEmpty)) {
                hasActiveTimeInWithoutTimeOut = true;
              }
            }
          } catch (_) {}
        }

        // If cook already has an active time-in today, or branch is currently open today:
        // this tap is a RETRIEVAL CLOSING (store departure / time-out).
        // Otherwise, it is a DEPLOYMENT OPENING (store arrival / time-in).
        if (hasActiveTimeInWithoutTimeOut || isCurrentlyOpenToday) {
          isDeployment = false;
        } else {
          isDeployment = true;
        }
      } catch (e) {
        debugPrint('Firestore status check note: $e');
      }

      debugPrint('[AttendanceService] Triggering processBranchCookRfidTap for $branchName ($branchId): isDeployment=$isDeployment');

      await FirestoreService.processBranchCookRfidTap(
        branchId: branchId,
        branchName: branchName,
        cookName: staff.fullName,
        cookId: staff.id,
        isDeployment: isDeployment,
        rfidTag: rfidUid,
        deviceId: deviceId,
      );

      // Ensure Supabase attendance_logs has record for today if missing
      await ensureSupabaseAttendanceLog(
        staff: staff,
        branchId: branchId,
        branchName: branchName,
        rfidUid: rfidUid,
        deviceId: deviceId,
        isDeployment: isDeployment,
      );

      attendanceChangeNotifier.value++;
    } catch (e) {
      debugPrint('_handleRfidQueueScan error: $e');
    }
  }

  /// Ensures that an attendance_log entry exists in Supabase so official DTR and Staff App reflect the tap
  static Future<void> ensureSupabaseAttendanceLog({
    required StaffMember staff,
    required String branchId,
    required String branchName,
    required String rfidUid,
    required String deviceId,
    required bool isDeployment,
  }) async {
    final client = _client;
    if (client == null) return;

    try {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final existing = await client
          .from('attendance_logs')
          .select()
          .eq('staff_id', staff.id)
          .eq('date', todayStr)
          .order('time_in', ascending: false)
          .limit(1);

      if (isDeployment) {
        // Record Time-In (Branch Arrival / Opening)
        final now = DateTime.now().toUtc();
        final isLate = DateTime.now().hour > 8 || (DateTime.now().hour == 8 && DateTime.now().minute > 0);
        if ((existing as List).isEmpty) {
          await client.from('attendance_logs').insert({
            'staff_id': staff.id,
            'staff_name': staff.fullName,
            'position': staff.position,
            'branch_id': branchId,
            'branch_name': branchName,
            'date': todayStr,
            'time_in': now.toIso8601String(),
            'status': isLate ? 'late' : 'on_time',
            'rfid_uid': rfidUid,
            'device_id': deviceId,
          });
        } else {
          // If a log already exists for today, DO NOT overwrite if already completed!
          final row = (existing as List).first;
          if (row['time_out'] != null && row['time_out'].toString().isNotEmpty) {
            debugPrint('[AttendanceService] Staff ${staff.fullName} already completed shift today. Skipping duplicate time-in.');
            return;
          }
          // If already timed in, keep existing record as is
        }
      } else if (existing.isNotEmpty && !isDeployment) {
        final row = (existing as List).first;
        if (row['time_out'] != null && row['time_out'].toString().isNotEmpty) {
          debugPrint('[AttendanceService] Staff ${staff.fullName} already completed shift today. Skipping duplicate time-out.');
          return;
        }
        final timeIn = (DateTime.tryParse(row['time_in']?.toString() ?? '') ?? DateTime.now()).toUtc();
        final now = DateTime.now().toUtc();
        var diffMinutes = now.difference(timeIn).inMinutes;
        if (diffMinutes < 0) {
          diffMinutes = diffMinutes.abs();
        }
        final hours = diffMinutes / 60.0;
        await client.from('attendance_logs').update({
          'time_out': now.toIso8601String(),
          'total_hours': double.parse(hours.toStringAsFixed(2)),
        }).eq('id', row['id']);
      } else if (existing.isEmpty && !isDeployment) {
        final now = DateTime.now().toUtc();
        await client.from('attendance_logs').insert({
          'staff_id': staff.id,
          'staff_name': staff.fullName,
          'position': staff.position,
          'branch_id': branchId,
          'branch_name': branchName,
          'date': todayStr,
          'time_in': now.toIso8601String(),
          'time_out': now.toIso8601String(),
          'total_hours': 0.0,
          'status': 'on_time',
          'rfid_uid': rfidUid,
          'device_id': deviceId,
        });
      }
    } catch (e) {
      debugPrint('ensureSupabaseAttendanceLog note: $e');
    }
  }

  static final Set<String> _syncedLogSignatures = {};

  static void _syncLogToFirestore(Map<String, dynamic> record) {
    try {
      final logId = record['id']?.toString() ?? '';
      final rawBId = (record['branch_id']?.toString() ?? '').toLowerCase();
      final staffName = record['staff_name']?.toString() ?? 'Staff';
      final staffId = record['staff_id']?.toString() ?? 'staff';
      final branchId = resolveBranchForStaff(rawBId, staffName, staffId);
      final branchName = record['branch_name']?.toString() ?? 'Branch';
      final rfidUid = record['rfid_uid']?.toString() ?? '';
      final deviceId = record['device_id']?.toString() ?? 'esp32_driver_portable';
      final hasTimeOut = record['time_out'] != null && record['time_out'].toString().isNotEmpty;

      // Base station commissary logs are for production attendance only, not store branch automation
      if (deviceId.toLowerCase().contains('commissary') || deviceId == 'esp32_commissary_base' || rawBId == 'commissary') {
        attendanceChangeNotifier.value++;
        return;
      }

      // Skip invalid IDs, commissary, unassigned, and 'n/a'
      if (branchId.isEmpty ||
          branchId == 'commissary' ||
          branchId == 'unassigned' ||
          branchId == 'n/a' ||
          branchId.contains('/')) {
        return;
      }

      // Deduping guard: Do not spam Firestore if this log state was already synced
      final sig = '${logId}_$hasTimeOut';
      if (logId.isNotEmpty && _syncedLogSignatures.contains(sig)) {
        return;
      }
      _syncedLogSignatures.add(sig);

      FirestoreService.processBranchCookRfidTap(
        branchId: branchId,
        branchName: branchName.isNotEmpty && branchName != 'Branch' && !branchName.toLowerCase().contains('commissary')
            ? branchName
            : canonicalBranchName(branchId),
        cookName: staffName,
        cookId: staffId,
        isDeployment: !hasTimeOut,
        rfidTag: rfidUid,
        deviceId: deviceId,
      ).catchError((e) {
        debugPrint('Sync Supabase log to Firestore error: $e');
        return false;
      });
      attendanceChangeNotifier.value++;
    } catch (e) {
      debugPrint('_syncLogToFirestore error: $e');
    }
  }

}
