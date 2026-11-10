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

  /// Clears pending offline queues from memory and disk (used on route reset or fresh start)
  static Future<void> clearOfflineQueue() async {
    offlinePendingDeploymentIds.clear();
    offlinePendingRetrievalIds.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_offlineQueueKey);
    } catch (_) {}
  }
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
  String activeCookStaffId = '';
  String activeCookRfidTag = '';

  /// Broadcast stream to immediately notify RouteScreen and other UI listeners
  /// when a card tap has been processed (whether online or saved offline).
  static final StreamController<Map<String, dynamic>> _tapEventsController =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get tapEventsStream => _tapEventsController.stream;

  void setActiveDispatch({
    required String branchId,
    required String branchName,
    required String cookName,
    required bool isOnTheWay,
    bool isDeployment = true,
    String? cookStaffId,
    String? cookRfidTag,
  }) {
    isDriverOnTheWay = isOnTheWay;
    isDeploymentMode = isDeployment;
    activeBranchId = branchId;
    activeBranchName = branchName;
    activeCookName = cookName;
    activeCookStaffId = cookStaffId ?? '';
    activeCookRfidTag = cookRfidTag ?? '';
    debugPrint('[BT] Active dispatch updated: branch=$branchName, cook=$cookName, isOnTheWay=$isOnTheWay, mode=${isDeployment ? "deployment" : "retrieval"}');
  }

  void clearActiveDispatch() {
    isDriverOnTheWay = false;
    isDeploymentMode = true;
    activeBranchId = '';
    activeBranchName = '';
    activeCookName = '';
    activeCookStaffId = '';
    activeCookRfidTag = '';
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

  /// Processes the tap: validates staff registration, route status, and location match;
  /// processes attendance online or queues offline, and immediately notifies RouteScreen.
  Future<void> _processDriverTap(String uid, String deviceId) async {
    Map<String, dynamic> responsePayload = {
      'status': 'error',
      'code': 'CONN_ERR',
      'message': 'Unable to process tap',
      'name': 'Staff',
    };
    final cleanUid = uid.replaceAll(':', '').replaceAll(' ', '').toUpperCase().trim();

    try {
      // 1. Identify staff member by RFID tag
      StaffMember? tappedStaff = await AttendanceService.findStaffByRfid(uid);

      // Fallback: If not found in staff registry but matches active cook's tag
      if (tappedStaff == null && activeCookRfidTag.isNotEmpty) {
        final cleanActiveTag = activeCookRfidTag.replaceAll(':', '').replaceAll(' ', '').toUpperCase().trim();
        if (cleanActiveTag == cleanUid) {
          tappedStaff = StaffMember(
            id: activeCookStaffId.isNotEmpty ? activeCookStaffId : 'cook',
            firstName: activeCookName,
            lastName: '',
            username: 'cook',
            branch: activeBranchId,
            position: 'Branch Cook',
            rfidTag: uid,
            isActive: true,
            isArchived: false,
          );
        }
      }

      // VALIDATION 1: UNREGISTERED CARD (Reject immediately, do NOT save offline!)
      if (tappedStaff == null) {
        debugPrint('[BT] Tap REJECTED: Card $uid is not registered to any staff member!');
        try {
          if (SupabaseService.client != null) {
            await SupabaseService.client!.from('rfid_scan_queue').insert({
              'rfid_uid': uid.toUpperCase(),
              'device_id': deviceId,
            });
            debugPrint('[BT] Pushed unregistered card $uid to rfid_scan_queue for enrollment');
          }
        } catch (_) {}

        responsePayload = {
          'status': 'error',
          'code': 'UNREGISTERED',
          'message': 'RFID card is not registered.',
          'name': 'Unknown Card',
        };
        await _sendResponseToEsp32(responsePayload);
        return;
      }

      // VALIDATION 2: DRIVER SELF-TAP (Time-in/out for driver himself)
      final tappedPos = (tappedStaff.position).toLowerCase();
      final isDriverSelfTap = tappedPos.contains('driver') ||
          (AuthService.currentAppUser != null &&
              tappedStaff.fullName.toLowerCase().trim() ==
                  AuthService.currentAppUser!.fullName.toLowerCase().trim());

      if (isDriverSelfTap) {
        debugPrint('[BT] Driver self-attendance tap detected for ${tappedStaff.fullName}');
        bool selfSavedOnline = false;
        try {
          final res = await AttendanceService.processTap(
            rfidUid: uid,
            deviceId: deviceId,
            branchId: 'commissary',
          ).timeout(const Duration(milliseconds: 2500));
          if (res['success'] == true) {
            selfSavedOnline = true;
            responsePayload = {
              'status': 'success',
              'type': res['type']?.toString() ?? 'time_in',
              'name': tappedStaff.fullName,
              'code': res['code']?.toString() ?? 'TIME_IN',
              'offline': false,
            };
          }
        } catch (_) {}

        if (!selfSavedOnline) {
          await _saveTapOffline(
            uid,
            deviceId,
            branchId: 'commissary',
            cookName: tappedStaff.fullName,
            isDeployment: true,
          );
          responsePayload = {
            'status': 'offline_saved',
            'type': 'time_in',
            'name': tappedStaff.fullName,
            'code': 'OFFLINE_SAVED',
            'offline': true,
          };
        }

        await _sendResponseToEsp32(responsePayload);
        return;
      }

      // VALIDATION 3: DRIVER MUST BE "ON THE WAY"
      if (!isDriverOnTheWay) {
        debugPrint('[BT] Tap REJECTED: Driver has not tapped "On the way" in the app!');
        responsePayload = {
          'status': 'error',
          'code': 'DRIVER_NOT_ON_THE_WAY',
          'message': 'Driver route is not active for this branch. Tap "On the way" first.',
          'name': tappedStaff.fullName,
        };
        await _sendResponseToEsp32(responsePayload);
        return;
      }

      // VALIDATION 4: COOK & BRANCH MATCHING (Prevent wrong cook / wrong branch tap)
      final tappedCanonBranch = AttendanceService.normalizeBranchId(tappedStaff.branch, tappedStaff.fullName);
      final activeCanonBranch = AttendanceService.normalizeBranchId(activeBranchId, activeCookName);

      final nameMatches = activeCookName.isNotEmpty &&
          (tappedStaff.fullName.toLowerCase().trim() == activeCookName.toLowerCase().trim() ||
           tappedStaff.fullName.toLowerCase().contains(activeCookName.toLowerCase().trim()) ||
           activeCookName.toLowerCase().contains(tappedStaff.fullName.toLowerCase().trim()));

      final branchMatches = tappedCanonBranch.isNotEmpty &&
          activeCanonBranch.isNotEmpty &&
          tappedCanonBranch == activeCanonBranch;

      final idMatches = activeCookStaffId.isNotEmpty &&
          tappedStaff.id.toLowerCase().trim() == activeCookStaffId.toLowerCase().trim();

      final tagMatches = activeCookRfidTag.isNotEmpty &&
          activeCookRfidTag.replaceAll(':', '').replaceAll(' ', '').toUpperCase().trim() == cleanUid;

      final isAuthorizedCook = nameMatches || branchMatches || idMatches || tagMatches;

      if (!isAuthorizedCook) {
        debugPrint('[BT] Tap REJECTED: Wrong cook! Tapped: ${tappedStaff.fullName} (${tappedStaff.branch}), Expected: $activeCookName ($activeBranchId)');
        responsePayload = {
          'status': 'error',
          'code': 'WRONG_COOK',
          'message': 'Card belongs to ${tappedStaff.fullName}, not assigned to $activeBranchName.',
          'name': tappedStaff.fullName,
        };
        await _sendResponseToEsp32(responsePayload);
        return;
      }

      // VALIDATION 5: RETRIEVAL MODE (STORE CLOSING / TIME-OUT)
      if (!isDeploymentMode) {
        final canonId = activeCanonBranch.isNotEmpty ? activeCanonBranch : tappedCanonBranch;
        final bName = activeBranchName.isNotEmpty ? activeBranchName : AttendanceService.canonicalBranchName(canonId);

        bool onlineCloseSuccess = false;
        try {
          final res = await AttendanceService.processTap(
            rfidUid: uid,
            deviceId: deviceId,
            branchId: canonId,
          ).timeout(const Duration(milliseconds: 2500));
          if (res['success'] == true && res['type'] == 'time_out') {
            onlineCloseSuccess = true;
          }
        } catch (_) {}

        if (onlineCloseSuccess) {
          await FirestoreService.processBranchCookRfidTap(
            branchId: canonId,
            branchName: bName,
            cookName: tappedStaff.fullName,
            cookId: tappedStaff.id,
            isDeployment: false,
            rfidTag: uid,
            deviceId: deviceId,
          );
          responsePayload = {
            'status': 'success',
            'type': 'time_out',
            'name': tappedStaff.fullName,
            'code': 'TIME_OUT',
            'offline': false,
          };
        } else {
          await _saveTapOffline(
            uid,
            deviceId,
            branchId: canonId,
            cookName: tappedStaff.fullName,
            isDeployment: false,
          );
          responsePayload = {
            'status': 'offline_saved',
            'type': 'time_out',
            'name': tappedStaff.fullName,
            'code': 'OFFLINE_SAVED',
            'offline': true,
          };
        }

        // Notify RouteScreen instantly so UI updates stop to completed
        _tapEventsController.add({
          'branch_id': activeBranchId,
          'canon_id': canonId,
          'cook_name': tappedStaff.fullName,
          'is_deployment': false,
          'is_offline': !onlineCloseSuccess,
          'uid': uid,
        });

        clearActiveDispatch();
        await _sendResponseToEsp32(responsePayload);
        return;
      }

      // DEPLOYMENT MODE (TIME-IN / STORE OPENING):
      final canonId = activeCanonBranch.isNotEmpty ? activeCanonBranch : tappedCanonBranch;
      final bName = activeBranchName.isNotEmpty ? activeBranchName : AttendanceService.canonicalBranchName(canonId);

      // Proactively ensure Supabase driver_dispatch_status is ON THE WAY
      // so Supabase RPC process_rfid_tap will never reject the cook's tap!
      try {
        if (SupabaseService.client != null && canonId.isNotEmpty) {
          await SupabaseService.client!.from('driver_dispatch_status').upsert({
            'branch_id': canonId,
            'branch_name': bName,
            'driver_name': AuthService.currentAppUser?.fullName ?? 'Driver',
            'driver_on_the_way': true,
            'mode': 'deployment',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).timeout(const Duration(seconds: 3));
        }
      } catch (_) {}

      bool onlineSuccess = false;
      try {
        final result = await AttendanceService.processTap(
          rfidUid: uid,
          deviceId: deviceId,
          branchId: canonId,
        ).timeout(const Duration(milliseconds: 5000));

        final success = result['success'] == true;
        final code = result['code']?.toString() ?? '';
        final isOffline = result['is_offline'] == true || code == 'CONN_ERR' || code == 'SERVER_ERR';

        if (!isOffline && (success || code == 'ALREADY_TIMED_IN')) {
          onlineSuccess = true;

          await FirestoreService.processBranchCookRfidTap(
            branchId: canonId,
            branchName: bName,
            cookName: tappedStaff.fullName,
            cookId: tappedStaff.id,
            isDeployment: true,
            rfidTag: uid,
            deviceId: deviceId,
          );

          responsePayload = {
            'status': 'success',
            'type': 'time_in',
            'name': tappedStaff.fullName,
            'code': code.isNotEmpty ? code : 'TIME_IN',
            'offline': false,
          };
        }
      } catch (e) {
        debugPrint('[BT] Online tap timed out or errored: $e');
      }

      if (!onlineSuccess) {
        // Save to offline queue
        await _saveTapOffline(
          uid,
          deviceId,
          branchId: canonId,
          cookName: tappedStaff.fullName,
          isDeployment: true,
        );

        responsePayload = {
          'status': 'offline_saved',
          'type': 'time_in',
          'name': tappedStaff.fullName,
          'code': 'OFFLINE_SAVED',
          'offline': true,
        };
      }

      // NOTIFY ROUTE SCREEN INSTANTLY TO MARK STOP COMPLETED & UNLOCK NEXT STOP
      _tapEventsController.add({
        'branch_id': activeBranchId,
        'canon_id': canonId,
        'cook_name': tappedStaff.fullName,
        'is_deployment': true,
        'is_offline': !onlineSuccess,
        'uid': uid,
      });

      clearActiveDispatch();
      await _sendResponseToEsp32(responsePayload);
    } catch (e) {
      debugPrint('[BT] _processDriverTap exception: $e');
      responsePayload = {
        'status': 'error',
        'code': 'PARSE_ERR',
        'message': 'System busy - retry',
        'name': 'Error',
      };
      await _sendResponseToEsp32(responsePayload);
    }
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
          final isDep = data['is_deployment'] != false;

          final staff = await AttendanceService.findStaffByRfid(uid);
          final cName = cookName.isNotEmpty ? cookName : (staff?.fullName ?? 'Branch Cook');
          final canonId = AttendanceService.normalizeBranchId(
            branchId.isNotEmpty ? branchId : (staff?.branch ?? ''),
            cName,
          );
          final bName = AttendanceService.canonicalBranchName(canonId);

          // Proactively ensure driver_dispatch_status is active so process_rfid_tap allows offline sync
          try {
            if (SupabaseService.client != null && canonId.isNotEmpty) {
              await SupabaseService.client!.from('driver_dispatch_status').upsert({
                'branch_id': canonId,
                'branch_name': bName,
                'driver_name': 'Driver',
                'driver_on_the_way': true,
                'mode': isDep ? 'deployment' : 'retrieval',
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              }).timeout(const Duration(seconds: 3));
            }
          } catch (_) {}

          var res = await AttendanceService.processTap(
            rfidUid: uid,
            deviceId: deviceId,
            branchId: canonId.isNotEmpty ? canonId : branchId,
          ).timeout(const Duration(seconds: 4));

          // Kung offline pa rin ang phone, ihinto na muna ang sync loop para hindi mag-spam
          if (res['is_offline'] == true || res['code'] == 'CONN_ERR') {
            debugPrint('[BT] Sync paused: Phone is still offline.');
            remaining.addAll(queue.sublist(i));
            break;
          }

          // 1. Siguraduhing may official attendance_log sa Supabase
          if (staff != null) {
            await AttendanceService.ensureSupabaseAttendanceLog(
              staff: staff,
              branchId: canonId,
              branchName: bName,
              rfidUid: uid,
              deviceId: deviceId,
              isDeployment: isDep,
            );
          }

          // 2. LAGING i-update ang Firestore branch status (opening / closing)
          // kahit ALREADY_TIMED_IN o DRIVER_NOT_ON_THE_WAY ang tugon
          if (canonId.isNotEmpty && canonId != 'commissary' && canonId != 'unassigned') {
            await FirestoreService.processBranchCookRfidTap(
              branchId: canonId,
              branchName: bName,
              cookName: cName,
              cookId: staff?.id ?? 'cook',
              isDeployment: isDep,
              rfidTag: uid,
              deviceId: deviceId,
            );
          }

          // 3. I-broadcast sa UI para maging green/completed ang stop
          _tapEventsController.add({
            'branch_id': branchId,
            'canon_id': canonId,
            'cook_name': cName,
            'is_deployment': isDep,
            'is_offline': false,
            'uid': uid,
          });

          debugPrint('[BT] Successfully synced and opened branch for offline tap UID: $uid ($cName, $canonId)');

          if (branchId.isNotEmpty) {
            offlinePendingDeploymentIds.remove(branchId);
            offlinePendingRetrievalIds.remove(branchId);
          }
          if (canonId.isNotEmpty) {
            offlinePendingDeploymentIds.remove(canonId);
            offlinePendingRetrievalIds.remove(canonId);
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
