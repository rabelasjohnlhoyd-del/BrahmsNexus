import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/branch_assignment.dart';
import 'firestore_service.dart';
import 'supabase_service.dart';

/// Central, persistent registry for staff daily branch assignments and
/// Rest Day schedules.
///
/// Features 4-tier persistence:
/// 1. Static memory cache (instant, survives logout/re-login in same session)
/// 2. Local JSON cache file (survives app restarts & device reboots)
/// 3. Supabase Cloud PostgreSQL (real-time cross-device sync between Mobile & Web)
/// 4. Firestore cloud collection `staff_assignments` (cloud backup)
class AssignmentService {
  const AssignmentService._();

  static final Map<String, WorkStatus> _workStatusCache = {};
  static final Map<String, String> _branchAssignmentCache = {};
  static bool _initialized = false;
  static StreamSubscription? _supabaseSub;

  // Keys that were manually set by the owner. While a key is "pending",
  // the realtime listener and syncFromSupabase are NOT allowed to overwrite it.
  // This prevents the UI from reverting after a toggle while the cloud write propagates.
  static final Map<String, DateTime> _pendingWrites = {};
  static const Duration _pendingTimeout = Duration(seconds: 6);

  /// Notifier triggered whenever an assignment or rest day changes from any source.
  static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  static File get _cacheFile =>
      File('${Directory.systemTemp.path}/brahms_staff_assignments.json');

  /// Ensures initial load from local file cache + Supabase + Firestore cloud.
  static Future<void> ensureInitialized() async {
    if (!_initialized) {
      _initialized = true;

      // 1. Read local file cache first (instant on native)
      try {
        if (!kIsWeb && await _cacheFile.exists()) {
          final content = await _cacheFile.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          for (final entry in json.entries) {
            final val = entry.value as Map<String, dynamic>;
            final statusStr = val['workStatus'] as String? ?? 'onDuty';
            final status = statusStr == 'restDay' ? WorkStatus.restDay : WorkStatus.onDuty;
            _workStatusCache[entry.key.toLowerCase()] = status;
            if (val['branchName'] != null) {
              _branchAssignmentCache[entry.key.toLowerCase()] = val['branchName'].toString();
            }
          }
        }
      } catch (e) {
        debugPrint('AssignmentService local cache load error: $e');
      }

      // Start realtime listening to Supabase updates
      _startRealtimeListener();
    }

    // 2. Synchronize from Supabase cloud (cross-device source of truth)
    await syncFromSupabase();

    // 3. Refresh from Firestore cloud
    await syncFromCloud();
  }

  static void _startRealtimeListener() {
    _supabaseSub?.cancel();
    _supabaseSub = SupabaseService.watchStaffProfiles().listen((staffList) {
      bool changed = false;
      for (final s in staffList) {
        final uKey = s.username.toLowerCase();
        final idKey = s.id.toLowerCase();

        // Skip update for any key that was manually set within the pending timeout.
        // This is the core fix: prevents the realtime event (triggered by our own
        // cloud write) from reverting the toggle before Supabase confirms the change.
        final isPendingByUsername = uKey.isNotEmpty && _isPending(uKey);
        final isPendingById = idKey.isNotEmpty && _isPending(idKey);
        if (isPendingByUsername || isPendingById) continue;

        final status = s.isRestDay ? WorkStatus.restDay : WorkStatus.onDuty;
        if (uKey.isNotEmpty) {
          _workStatusCache[uKey] = status;
          changed = true;
        }
        if (idKey.isNotEmpty) {
          _workStatusCache[idKey] = status;
          changed = true;
        }
        if (s.branch.isNotEmpty && s.branch != 'N/A') {
          if (uKey.isNotEmpty) _branchAssignmentCache[uKey] = s.branch;
          if (idKey.isNotEmpty) _branchAssignmentCache[idKey] = s.branch;
        }
      }
      if (changed) {
        _saveToLocalFile();
        changeNotifier.value++;
      }
    });
  }

  /// Syncs latest assignments from Supabase PostgreSQL.
  static Future<void> syncFromSupabase() async {
    try {
      final remoteStaff = await SupabaseService.refreshStaffFromRemote();
      bool changed = false;
      for (final s in remoteStaff) {
        final uKey = s.username.toLowerCase();
        final idKey = s.id.toLowerCase();

        // Same protection: don't let a full sync overwrite a pending manual write.
        final isPendingByUsername = uKey.isNotEmpty && _isPending(uKey);
        final isPendingById = idKey.isNotEmpty && _isPending(idKey);
        if (isPendingByUsername || isPendingById) continue;

        final status = s.isRestDay ? WorkStatus.restDay : WorkStatus.onDuty;
        if (uKey.isNotEmpty) {
          _workStatusCache[uKey] = status;
          changed = true;
        }
        if (idKey.isNotEmpty) {
          _workStatusCache[idKey] = status;
          changed = true;
        }
        if (s.branch.isNotEmpty && s.branch != 'N/A') {
          if (uKey.isNotEmpty) _branchAssignmentCache[uKey] = s.branch;
          if (idKey.isNotEmpty) _branchAssignmentCache[idKey] = s.branch;
        }
      }
      if (changed) {
        _saveToLocalFile();
        changeNotifier.value++;
      }
    } catch (e) {
      debugPrint('AssignmentService syncFromSupabase error: $e');
    }
  }

  /// Syncs latest assignments from Firestore.
  static Future<void> syncFromCloud() async {
    try {
      final savedMap = await FirestoreService.getStaffAssignmentsMap();
      bool changed = false;
      for (final entry in savedMap.entries) {
        final a = entry.value;
        final key = entry.key.toLowerCase();
        final idKey = a.employeeId.toLowerCase();

        // Don't overwrite pending manual writes from Firestore sync either.
        if (_isPending(key) || (idKey.isNotEmpty && _isPending(idKey))) continue;

        _workStatusCache[key] = a.workStatus;
        changed = true;
        if (idKey.isNotEmpty) {
          _workStatusCache[idKey] = a.workStatus;
        }
        if (a.branchName.isNotEmpty) {
          _branchAssignmentCache[key] = a.branchName;
          if (idKey.isNotEmpty) {
            _branchAssignmentCache[idKey] = a.branchName;
          }
        }
      }
      if (changed) {
        _saveToLocalFile();
        changeNotifier.value++;
      }
    } catch (e) {
      debugPrint('AssignmentService syncFromCloud error: $e');
    }
  }

  /// Returns true if the given cache key was recently manually written to
  /// and should not be overwritten by remote sync or realtime events.
  static bool _isPending(String key) {
    final wrote = _pendingWrites[key];
    if (wrote == null) return false;
    if (DateTime.now().difference(wrote) < _pendingTimeout) return true;
    _pendingWrites.remove(key); // expired, clean up
    return false;
  }

  /// Checks if staff member is currently on Rest Day.
  static bool isRestDay(String usernameOrId) {
    final key = usernameOrId.trim().toLowerCase();
    return _workStatusCache[key] == WorkStatus.restDay;
  }

  /// Gets the effective work status for a staff member.
  static WorkStatus getWorkStatus(String usernameOrId, {WorkStatus fallback = WorkStatus.onDuty}) {
    final key = usernameOrId.trim().toLowerCase();
    return _workStatusCache[key] ?? fallback;
  }

  /// Gets the assigned branch name.
  static String getAssignedBranch(String usernameOrId, {String fallback = ''}) {
    final key = usernameOrId.trim().toLowerCase();
    return _branchAssignmentCache[key] ?? fallback;
  }

  /// Immediately locks the status & branch in the in-memory cache WITHOUT any async calls.
  ///
  /// Call this at the very start of any toggle/branch handler — BEFORE the first `await`.
  /// This marks the keys as "pending" so the realtime listener and sync methods won't
  /// overwrite them for [_pendingTimeout] seconds.
  static void lockStatus({
    required String username,
    required String employeeId,
    required WorkStatus status,
    String? branchName,
  }) {
    final uKey = username.trim().toLowerCase();
    final idKey = employeeId.trim().toLowerCase();

    // Mark as pending so realtime/sync can't overwrite
    final now = DateTime.now();
    if (uKey.isNotEmpty) _pendingWrites[uKey] = now;
    if (idKey.isNotEmpty) _pendingWrites[idKey] = now;

    // Write to cache immediately
    if (uKey.isNotEmpty) _workStatusCache[uKey] = status;
    if (idKey.isNotEmpty) _workStatusCache[idKey] = status;
    if (branchName != null && branchName.isNotEmpty) {
      if (uKey.isNotEmpty) _branchAssignmentCache[uKey] = branchName;
      if (idKey.isNotEmpty) _branchAssignmentCache[idKey] = branchName;
    }
  }

  /// Locks the branch assignment in cache immediately (without changing work status).
  static void lockBranch({
    required String username,
    required String employeeId,
    required String branchName,
  }) {
    final uKey = username.trim().toLowerCase();
    final idKey = employeeId.trim().toLowerCase();

    final now = DateTime.now();
    if (uKey.isNotEmpty) _pendingWrites[uKey] = now;
    if (idKey.isNotEmpty) _pendingWrites[idKey] = now;

    if (uKey.isNotEmpty && branchName.isNotEmpty) _branchAssignmentCache[uKey] = branchName;
    if (idKey.isNotEmpty && branchName.isNotEmpty) _branchAssignmentCache[idKey] = branchName;
  }

  /// Sets work status and branch assignment for a staff member across all persistence tiers.
  static Future<void> setAssignment({
    required String username,
    required String employeeId,
    required String employeeName,
    required String branchId,
    required String branchName,
    required WorkStatus status,
  }) async {
    final uKey = username.trim().toLowerCase();
    final idKey = employeeId.trim().toLowerCase();

    // 1. Lock & update memory cache immediately (also marks as pending)
    lockStatus(
      username: username,
      employeeId: employeeId,
      status: status,
      branchName: branchName,
    );

    // 2. Save to local file cache (survives offline restart)
    _saveToLocalFile();

    // 3. Persist to Supabase cloud (instant cross-device sync)
    final lookupKey = username.isNotEmpty ? username : employeeId;
    await SupabaseService.updateStaffAssignment(
      staffIdOrUsername: lookupKey,
      branchName: branchName,
      isRestDay: status == WorkStatus.restDay,
    );

    // 4. Persist to Firestore cloud
    await FirestoreService.setStaffAssignment(
      username: username,
      employeeId: employeeId,
      employeeName: employeeName,
      branchId: branchId,
      branchName: branchName,
      workStatus: status,
    );

    // Re-lock after cloud writes (in case sync fired mid-await)
    if (uKey.isNotEmpty) _pendingWrites[uKey] = DateTime.now();
    if (idKey.isNotEmpty) _pendingWrites[idKey] = DateTime.now();
    if (uKey.isNotEmpty) _workStatusCache[uKey] = status;
    if (idKey.isNotEmpty) _workStatusCache[idKey] = status;
    if (branchName.isNotEmpty) {
      if (uKey.isNotEmpty) _branchAssignmentCache[uKey] = branchName;
      if (idKey.isNotEmpty) _branchAssignmentCache[idKey] = branchName;
    }

    changeNotifier.value++;
  }

  static void _saveToLocalFile() {
    if (kIsWeb) return;
    try {
      final out = <String, dynamic>{};
      for (final entry in _workStatusCache.entries) {
        out[entry.key] = {
          'workStatus': entry.value.name,
          'branchName': _branchAssignmentCache[entry.key] ?? '',
        };
      }
      _cacheFile.writeAsStringSync(jsonEncode(out));
    } catch (_) {}
  }
}
