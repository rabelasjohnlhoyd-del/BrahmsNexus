import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/staff_member.dart';
import 'attendance_service.dart';
import 'auth_service.dart';
import 'supabase_service.dart';
import 'firestore_service.dart';

/// Bluetooth Classic (SPP/RFCOMM) service for the Brahms Driver App.
/// Connects to the paired Driver Portable RFID Reader ("Brahms_Driver_Reader"),
/// captures card taps over Serial, processes attendance via AttendanceService
/// (Supabase + Firestore branch auto-opening), and manages an offline queue
/// when the driver has no internet connectivity.
class DriverBleService {
  static final DriverBleService _instance = DriverBleService._internal();
  factory DriverBleService() => _instance;

  /// Branches that have an offline RFID tap queued (not yet synced to server).
  /// Used by route_screen to guard against stale Firestore snapshots reverting
  /// the UI to "On the way" before the offline sync completes.
  static final Set<String> offlinePendingDeploymentIds = {};
  static final Set<String> offlinePendingRetrievalIds = {};
  DriverBleService._internal();

  static const String targetDeviceName = 'Brahms_Driver_Reader';
  static const String _offlineQueueKey = 'driver_offline_rfid_taps';

  final FlutterClassicBluetooth _bluetooth = FlutterClassicBluetooth();
  BtcConnection? _connection;
  StreamSubscription<Uint8List>? _incomingSub;
  StreamSubscription<BtcConnectionState>? _stateSub;
  Timer? _offlineSyncTimer;
  Timer? _autoReconnectTimer;

  bool _isConnecting = false;
  bool _autoReconnectEnabled = true;
  String _incomingBuffer = '';

  /// Driver Dispatch active state (tracks if driver pressed "On the way" in the app)
  bool isDriverOnTheWay = false;
  bool isDeploymentMode = true; // true = deployment (Time-In/Opening), false = retrieval (Time-Out/Closing)
  String activeBranchId = '';
  String activeBranchName = '';
  String activeCookName = '';

  void setActiveDispatch({
    required String branchId,
    required String branchName,
    required String cookName,
    required bool isOnTheWay,
    bool isDeployment = true,
  }) {
    isDriverOnTheWay = isOnTheWay;
    isDeploymentMode = isDeployment;
    activeBranchId = branchId;
    activeBranchName = branchName;
    activeCookName = cookName;
    debugPrint('[BT] Active dispatch updated: branch=$branchName, cook=$cookName, isOnTheWay=$isOnTheWay, mode=${isDeployment ? "deployment" : "retrieval"}');
  }

  void clearActiveDispatch() {
    isDriverOnTheWay = false;
    isDeploymentMode = true;
    activeBranchId = '';
    activeBranchName = '';
    activeCookName = '';
  }

  /// Public connection status notifiers for UI
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> statusNotifier = ValueNotifier<String>('Disconnected');

  /// Initializes the Bluetooth service, starts auto-connect, and begins offline sync polling.
  Future<void> initialize() async {
    if (kIsWeb) return;

    _startOfflineSyncWorker();

    try {
      final isEnabled = await _bluetooth.isEnabled();
      if (!isEnabled) {
        statusNotifier.value = 'Bluetooth Disabled';
        debugPrint('[BT] Bluetooth is disabled on phone');
        return;
      }

      await startScanAndConnect();
    } catch (e) {
      debugPrint('[BT] DriverBleService.initialize error: $e');
    }
  }

  /// Finds "Brahms_Driver_Reader" in the paired devices list and connects.
  Future<void> startScanAndConnect() async {
    if (kIsWeb || _isConnecting || isConnectedNotifier.value) return;

    _isConnecting = true;
    statusNotifier.value = 'Connecting to Reader...';

    try {
      final isEnabled = await _bluetooth.isEnabled();
      if (!isEnabled) {
        statusNotifier.value = 'Bluetooth Disabled';
        _isConnecting = false;
        return;
      }

      // Automatically request Bluetooth permissions (BLUETOOTH_SCAN & BLUETOOTH_CONNECT) on Android 12+
      final permStatus = await _bluetooth.checkPermissions();
      if (permStatus != BtcPermissionStatus.granted && permStatus != BtcPermissionStatus.notRequired) {
        debugPrint('[BT] Requesting Bluetooth permissions (current: $permStatus)...');
        final newStatus = await _bluetooth.requestPermissions();
        if (newStatus != BtcPermissionStatus.granted && newStatus != BtcPermissionStatus.notRequired) {
          debugPrint('[BT] Bluetooth permission denied: $newStatus');
          statusNotifier.value = 'Permission Denied: Allow Nearby Devices';
          _isConnecting = false;
          return;
        }
      }

      final pairedDevices = await _bluetooth.getPairedDevices();
      debugPrint('[BT] Paired devices found: ${pairedDevices.map((d) => d.name).toList()}');

      BtcDevice? targetDevice;
      for (final device in pairedDevices) {
        final name = (device.name ?? '').trim();
        if (name == targetDeviceName || name.contains('Brahms_Driver')) {
          targetDevice = device;
          break;
        }
      }

      if (targetDevice == null) {
        debugPrint('[BT] $targetDeviceName not found in paired devices.');
        statusNotifier.value = 'Please Pair Reader in Settings';
        _isConnecting = false;
        _scheduleReconnect();
        return;
      }

      debugPrint('[BT] Connecting to ${targetDevice.name} (${targetDevice.address})...');
      final conn = await _bluetooth.connect(
        address: targetDevice.address,
        timeout: const Duration(seconds: 10),
      );

      _connection = conn;
      isConnectedNotifier.value = true;
      statusNotifier.value = 'Connected';
      debugPrint('[BT] Connected successfully to ${targetDevice.name}!');

      // Listen for connection state changes (e.g. device turned off)
      _stateSub?.cancel();
      _stateSub = conn.stateStream.listen((state) {
        if (state == BtcConnectionState.disconnected) {
          debugPrint('[BT] State stream reported disconnected');
          _handleDisconnection();
        }
      });

      // Listen for incoming data from ESP32
      _incomingBuffer = '';
      _incomingSub?.cancel();
      _incomingSub = conn.input.listen(
        (data) => _handleIncomingBytes(data),
        onError: (e) {
          debugPrint('[BT] Stream error: $e');
          _handleDisconnection();
        },
        onDone: () {
          debugPrint('[BT] Connection closed by device');
          _handleDisconnection();
        },
      );

      // Immediately trigger sync of any pending offline records
      triggerOfflineSync();
    } catch (e) {
      debugPrint('[BT] Connection exception: $e');
      statusNotifier.value = 'Connection Failed';
      _handleDisconnection();
    } finally {
      _isConnecting = false;
    }
  }

  /// Buffers incoming bytes until newline (\n) and parses the JSON message.
  void _handleIncomingBytes(Uint8List data) {
    try {
      final chunk = utf8.decode(data);
      _incomingBuffer += chunk;

      while (_incomingBuffer.contains('\n')) {
        final newlineIndex = _incomingBuffer.indexOf('\n');
        final line = _incomingBuffer.substring(0, newlineIndex).trim();
        _incomingBuffer = _incomingBuffer.substring(newlineIndex + 1);

        if (line.isNotEmpty) {
          _processIncomingLine(line);
        }
      }
    } catch (e) {
      debugPrint('[BT] Error decoding incoming bytes: $e');
    }
  }

  /// Processes incoming JSON string from ESP32: {"event":"rfid_tap","uid":"..."}
  Future<void> _processIncomingLine(String line) async {
    debugPrint('[BT RECV] $line');
    try {
      final doc = jsonDecode(line);
      if (doc is Map && doc['event'] == 'rfid_tap') {
        final uid = doc['uid']?.toString() ?? '';
        final deviceId = doc['device_id']?.toString() ?? 'esp32_driver_portable';

        if (uid.isNotEmpty) {
          await _processDriverTap(uid, deviceId);
        }
      }
    } catch (e) {
      debugPrint('[BT] JSON parse error: $e on line: $line');
    }
  }

  /// Processes the tap: calls Supabase online, or caches offline if network is down.
  Future<void> _processDriverTap(String uid, String deviceId) async {
    Map<String, dynamic> responsePayload;

    try {
      // 1. Attempt online attendance processing
      final result = await AttendanceService.processTap(
        rfidUid: uid,
        deviceId: deviceId,
        branchId: activeBranchId,
      ).timeout(const Duration(milliseconds: 2500));

      final success = result['success'] == true;
      final type = result['type']?.toString() ?? '';
      final code = result['code']?.toString() ?? '';
      final staffName = result['staff_name']?.toString() ?? 'Staff';
      final message = result['message']?.toString() ?? '';

      // RETRIEVAL INTERCEPTION (STORE CLOSING / TIME-OUT):
      // Kung retrieval mode (hapon/uwian) at nag-tap ang cook, ito ay TIME-OUT.
      // Kung sinabi ng Supabase na ALREADY_TIMED_IN o DRIVER_NOT_ON_THE_WAY o error,
      // i-override at i-record bilang Time-Out at i-close ang branch!
      if (!isDeploymentMode && (code == 'ALREADY_TIMED_IN' || code == 'DRIVER_NOT_ON_THE_WAY' || (!success && type != 'time_out'))) {
        final staff = await AttendanceService.findStaffByRfid(uid);
        if (staff != null) {
          final canonId = AttendanceService.normalizeBranchId(
            activeBranchId.isNotEmpty ? activeBranchId : staff.branch,
            staff.fullName,
          );
          final bName = activeBranchName.isNotEmpty ? activeBranchName : AttendanceService.canonicalBranchName(canonId);

          await AttendanceService.ensureSupabaseAttendanceLog(
            staff: staff,
            branchId: canonId,
            branchName: bName,
            rfidUid: uid,
            deviceId: deviceId,
            isDeployment: false,
          );

          await FirestoreService.processBranchCookRfidTap(
            branchId: canonId,
            branchName: bName,
            cookName: staff.fullName,
            cookId: staff.id,
            isDeployment: false,
            rfidTag: uid,
            deviceId: deviceId,
          );

          isDriverOnTheWay = false;

          responsePayload = {
            'status': 'success',
            'type': 'time_out',
            'name': staff.fullName,
            'code': 'TIME_OUT',
            'offline': false,
          };
          await _sendResponseToEsp32(responsePayload);
          return;
        }
      }

      final isOffline = result['is_offline'] == true || code == 'CONN_ERR' || code == 'SERVER_ERR';
      if (isOffline) {
        // WALANG INTERNET ANG PHONE:
        // Suriin kung si driver mismo ang nag-tap ng sarili niyang attendance card:
        final tappedStaff = await AttendanceService.findStaffByRfid(uid);
        final tappedPos = (tappedStaff?.position ?? '').toLowerCase();
        final isDriverSelfTap = tappedPos.contains('driver') ||
            (AuthService.currentAppUser != null &&
                tappedStaff != null &&
                tappedStaff.fullName.toLowerCase().trim() == AuthService.currentAppUser!.fullName.toLowerCase().trim());

        if (!isDriverSelfTap && !isDriverOnTheWay) {
          debugPrint('[BT] Offline Tap REJECTED: Driver has NOT tapped "On the way" in the app!');
          responsePayload = {
            'status': 'error',
            'code': 'DRIVER_NOT_ON_THE_WAY',
            'message': 'Driver route is not yet active for this branch.',
            'name': 'Branch Cook',
          };
          await _sendResponseToEsp32(responsePayload);
          return;
        }

        // Kung driver self-tap o cook tap habang on the way:
        final displayName = isDriverSelfTap
            ? (tappedStaff?.fullName ?? AuthService.currentAppUser?.fullName ?? 'Driver')
            : (activeCookName.isNotEmpty ? activeCookName : (tappedStaff?.fullName ?? staffName));

        debugPrint('[BT] Phone offline. Saving tap offline for $displayName (isDriverSelf=$isDriverSelfTap, isDeployment=$isDeploymentMode)...');
        await _saveTapOffline(
          uid,
          deviceId,
          branchId: isDriverSelfTap ? 'commissary' : activeBranchId,
          cookName: displayName,
          isDeployment: isDeploymentMode,
        );

        responsePayload = {
          'status': 'offline_saved',
          'type': isDeploymentMode ? 'time_in' : 'time_out',
          'name': displayName,
          'code': 'OFFLINE_SAVED',
          'offline': true,
        };

        if (!isDriverSelfTap) {
          isDriverOnTheWay = false;
        }
      } else if (success && (type == 'time_in' || type == 'time_out')) {
        // 1. Success mula sa Supabase (May pangalan at tamang shift)
        if (!isDeploymentMode) {
          // Auto-close branch in Firestore for retrieval shift
          final cleanBId = AttendanceService.normalizeBranchId(activeBranchId, staffName);
          final bName = activeBranchName.isNotEmpty ? activeBranchName : AttendanceService.canonicalBranchName(cleanBId);
          final staff = await AttendanceService.findStaffByRfid(uid);
          await FirestoreService.processBranchCookRfidTap(
            branchId: cleanBId,
            branchName: bName,
            cookName: staffName,
            cookId: staff?.id ?? 'cook',
            isDeployment: false,
            rfidTag: uid,
            deviceId: deviceId,
          );
        }

        responsePayload = {
          'status': 'success',
          'type': type,
          'name': staffName,
          'code': code,
          'offline': false,
        };
      } else {
        // 2. Rejection o Notice mula sa Supabase:
        // DRIVER_NOT_ON_THE_WAY, UNREGISTERED, WRONG_LOCATION, ALREADY_COMPLETED, etc.
        if (code == 'UNREGISTERED' || code == 'UNKNOWN_CARD') {
          try {
            await SupabaseService.client?.from('rfid_scan_queue').insert({
              'rfid_uid': uid.toUpperCase(),
              'device_id': deviceId,
            });
            debugPrint('[BT] Pushed unregistered card $uid to rfid_scan_queue for Admin Web enrollment!');
          } catch (e) {
            debugPrint('[BT] Failed to push to rfid_scan_queue: $e');
          }
        }

        if (result['details'] != null) {
          debugPrint('[BT] Supabase error details: ${result['details']}');
        }
        responsePayload = {
          'status': 'error',
          'code': code.isNotEmpty ? code : 'REJECTED',
          'message': message,
          'name': staffName,
        };
      }
    } catch (e) {
      // 2. Offline Mode: Network failed or timed out during transit
      debugPrint('[BT] Online tap timed out (Saving Offline): $e');
      final tappedStaff = await AttendanceService.findStaffByRfid(uid);
      final tappedPos = (tappedStaff?.position ?? '').toLowerCase();
      final isDriverSelfTap = tappedPos.contains('driver') ||
          (AuthService.currentAppUser != null &&
              tappedStaff != null &&
              tappedStaff.fullName.toLowerCase().trim() == AuthService.currentAppUser!.fullName.toLowerCase().trim());

      if (!isDriverSelfTap && !isDriverOnTheWay) {
        responsePayload = {
          'status': 'error',
          'code': 'DRIVER_NOT_ON_THE_WAY',
          'message': 'Driver route is not yet active for this branch.',
          'name': 'Branch Cook',
        };
      } else {
        final displayName = isDriverSelfTap
            ? (tappedStaff?.fullName ?? AuthService.currentAppUser?.fullName ?? 'Driver')
            : (activeCookName.isNotEmpty ? activeCookName : (tappedStaff?.fullName ?? 'Staff'));

        await _saveTapOffline(
          uid,
          deviceId,
          branchId: isDriverSelfTap ? 'commissary' : activeBranchId,
          cookName: displayName,
          isDeployment: isDeploymentMode,
        );

        responsePayload = {
          'status': 'offline_saved',
          'type': isDeploymentMode ? 'time_in' : 'time_out',
          'name': displayName,
          'code': 'OFFLINE_SAVED',
          'offline': true,
        };
        if (!isDriverSelfTap) {
          isDriverOnTheWay = false;
        }
      }
    }

    // 3. Send response line back to ESP32 so OLED and Buzzer update
    await _sendResponseToEsp32(responsePayload);
  }

  /// Sends newline-terminated JSON response back to ESP32 over Bluetooth Serial
  Future<void> _sendResponseToEsp32(Map<String, dynamic> data) async {
    final conn = _connection;
    if (conn == null) return;
    try {
      final jsonStr = jsonEncode(data);
      await conn.output.writeLine(jsonStr, newline: '\n');
      debugPrint('[BT SEND] $jsonStr');
    } catch (e) {
      debugPrint('[BT] Failed to write response to ESP32: $e');
    }
  }

  /// Stores un-synced tap locally in SharedPreferences
  Future<void> _saveTapOffline(
    String uid,
    String deviceId, {
    String branchId = '',
    String cookName = '',
    bool isDeployment = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_offlineQueueKey) ?? [];

      final record = jsonEncode({
        'uid': uid,
        'device_id': deviceId,
        'branch_id': branchId,
        'cook_name': cookName,
        'is_deployment': isDeployment,
        'tapped_at': DateTime.now().toIso8601String(),
      });

      existing.add(record);
      await prefs.setStringList(_offlineQueueKey, existing);

      // Track locally which branches have pending offline taps.
      // route_screen uses this to prevent stale Firestore snapshots from
      // reverting UI to "On the way" before the sync completes.
      if (branchId.isNotEmpty && branchId != 'commissary') {
        final canonId = AttendanceService.normalizeBranchId(branchId, cookName);
        if (isDeployment) {
          offlinePendingDeploymentIds.add(branchId);
          if (canonId.isNotEmpty) offlinePendingDeploymentIds.add(canonId);
        } else {
          offlinePendingRetrievalIds.add(branchId);
          if (canonId.isNotEmpty) offlinePendingRetrievalIds.add(canonId);
        }
      }

      debugPrint('[BT] Saved offline tap for UID: $uid ($cookName). Queue count: ${existing.length}');
    } catch (e) {
      debugPrint('[BT] Error saving tap offline: $e');
    }
  }

  /// Background worker: attempts to upload pending offline taps every 30 seconds
  void _startOfflineSyncWorker() {
    _offlineSyncTimer?.cancel();
    _offlineSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      triggerOfflineSync();
    });
  }

  /// Uploads pending offline taps to Supabase and clears them from storage
  Future<void> triggerOfflineSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_offlineQueueKey) ?? [];
      if (queue.isEmpty) return;

      debugPrint('[BT] Checking offline queue: ${queue.length} items to sync...');
      final remaining = <String>[];

      for (int i = 0; i < queue.length; i++) {
        final item = queue[i];
        try {
          final data = jsonDecode(item) as Map<String, dynamic>;
          final uid = data['uid']?.toString() ?? '';
          final deviceId = data['device_id']?.toString() ?? 'esp32_driver_portable';
          final branchId = data['branch_id']?.toString() ?? '';
          final cookName = data['cook_name']?.toString() ?? '';

          var res = await AttendanceService.processTap(
            rfidUid: uid,
            deviceId: deviceId,
            branchId: branchId,
          ).timeout(const Duration(seconds: 4));

          // Kung offline pa rin ang phone, ihinto na muna ang sync loop para hindi mag-spam
          if (res['is_offline'] == true || res['code'] == 'CONN_ERR') {
            debugPrint('[BT] Sync paused: Phone is still offline.');
            remaining.addAll(queue.sublist(i));
            break;
          }

          // KUNG HINARANG NG DATABASE DAHIL DRIVER_NOT_ON_THE_WAY:
          // Ang offline tap na ito ay na-verify na ng driver phone habang on the way bago na-save.
          // I-bypass ang database restriction at direktang i-save sa attendance_logs at i-open ang branch!
          if (res['code'] == 'DRIVER_NOT_ON_THE_WAY' ||
              (res['success'] != true &&
               res['code'] != 'ALREADY_TIMED_IN' &&
               res['code'] != 'ALREADY_COMPLETED')) {
            final staff = await AttendanceService.findStaffByRfid(uid);
            if (staff != null) {
              final canonId = AttendanceService.normalizeBranchId(
                branchId.isNotEmpty ? branchId : staff.branch,
                staff.fullName,
              );
              final bName = AttendanceService.canonicalBranchName(canonId);

              final isDep = data['is_deployment'] != false;
              // 1. Diretso sa Supabase attendance_logs
              await AttendanceService.ensureSupabaseAttendanceLog(
                staff: staff,
                branchId: canonId,
                branchName: bName,
                rfidUid: uid,
                deviceId: deviceId,
                isDeployment: isDep,
              );

              // 2. I-update ang branch status sa Firestore
              await FirestoreService.processBranchCookRfidTap(
                branchId: canonId,
                branchName: bName,
                cookName: staff.fullName,
                cookId: staff.id,
                isDeployment: isDep,
                rfidTag: uid,
                deviceId: deviceId,
              );

              debugPrint('[BT] Offline tap successfully resolved via fallback for ${staff.fullName} ($canonId)!');
              res = {'success': true};
            }
          }

          if (res['success'] == true || res['code'] == 'ALREADY_TIMED_IN' || res['code'] == 'ALREADY_COMPLETED') {
            debugPrint('[BT] Successfully synced offline tap for UID: $uid');
            // Remove from pending offline sets now that sync is confirmed
            if (branchId.isNotEmpty) {
              offlinePendingDeploymentIds.remove(branchId);
              offlinePendingRetrievalIds.remove(branchId);
            }
          } else {
            remaining.add(item);
          }
        } catch (e) {
          debugPrint('[BT] Sync item error: $e');
          remaining.addAll(queue.sublist(i));
          break;
        }
      }

      await prefs.setStringList(_offlineQueueKey, remaining);
    } catch (e) {
      debugPrint('[BT] triggerOfflineSync error: $e');
    }
  }

  /// Handles disconnection and schedules auto-reconnection
  void _handleDisconnection() {
    isConnectedNotifier.value = false;
    statusNotifier.value = 'Disconnected';
    _connection = null;
    _incomingSub?.cancel();
    _stateSub?.cancel();

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_autoReconnectEnabled && !_isConnecting) {
      _autoReconnectTimer?.cancel();
      _autoReconnectTimer = Timer(const Duration(seconds: 4), () {
        if (!isConnectedNotifier.value) {
          startScanAndConnect();
        }
      });
    }
  }

  /// Opens Android app settings so user can grant Nearby Devices permission
  Future<bool> openSettings() async {
    try {
      return await _bluetooth.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Manual reconnect trigger for the UI button
  Future<String> manualReconnect() async {
    _handleDisconnection();
    await startScanAndConnect();
    return statusNotifier.value;
  }

  void dispose() {
    _autoReconnectEnabled = false;
    _autoReconnectTimer?.cancel();
    _offlineSyncTimer?.cancel();
    _incomingSub?.cancel();
    _stateSub?.cancel();
    _connection?.close();
    _connection = null;
  }
}
