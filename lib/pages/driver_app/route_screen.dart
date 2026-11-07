import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/branch.dart';
import '../../models/branch_assignment.dart';
import '../../models/staff_member.dart';
import '../../services/assignment_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/firestore_service.dart';
import '../../services/attendance_service.dart';
import '../../services/driver_ble_service.dart';
import '../../services/supabase_service.dart';
import '../../services/tutorial_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_card.dart';
import '../../widgets/driver_nav_bar.dart';
import '../../widgets/driver_top_actions.dart';
import '../../widgets/driver_section_header.dart';
import '../../widgets/guided_tour_overlay.dart';

/// The Transport Mode for the Route — either Deployment (morning pickup)
/// or Retrieval (evening pickup).
enum RouteMode { deployment, retrieval }

/// Route tab — manages the transport of staff to and from their branches.
class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  /// GlobalKey used by [DriverProfileScreen] to call [RouteScreenState.startTour]
  /// directly without telling the user to navigate anywhere.
  static final GlobalKey<RouteScreenState> globalKey = GlobalKey<RouteScreenState>();

  @override
  State<RouteScreen> createState() => RouteScreenState();
}

class RouteScreenState extends State<RouteScreen> {
  RouteMode _activeMode = RouteMode.deployment;

  // Track completed stops for each mode
  final Set<String> _completedDeploymentIds = {};
  final Set<String> _completedRetrievalIds = {};

  // Confirmed attendance from direct Supabase attendance_logs stream
  final Set<String> _attendanceConfirmedRetrievalIds = {};
  final Set<String> _attendanceConfirmedDeploymentIds = {};

  // Branches opened today (either via cook arrival RFID, open status, or attendance time-in)
  final Set<String> _openedBranchIdsToday = {};

  // Track who has been notified in the current session (split by mode)
  final Set<String> _notifiedDeploymentIds = {};
  final Set<String> _notifiedRetrievalIds = {};

  Set<String> get _notifiedStaffIds =>
      _activeMode == RouteMode.deployment ? _notifiedDeploymentIds : _notifiedRetrievalIds;

  List<Branch> _branches = [];
  StreamSubscription? _statusSubscription;
  StreamSubscription? _meatStocksSubscription;
  StreamSubscription? _attendanceSubscription;

  // Track closed branches (set by owner via Branch Allocation / branch_status)
  final Set<String> _closedBranchIds = {};

  // ── Daily Reset ──────────────────────────────────────────────────
  // Tracks the current route calendar date; at midnight, stops are cleared.
  Timer? _dayResetTimer;
  String _routeDateStr = DateTime.now().toIso8601String().substring(0, 10);

  // ── Guided Tour Keys (Live Spotlight) ───────────────────────────
  final GlobalKey _rfidBannerKey = GlobalKey();
  final GlobalKey _firstStopCardKey = GlobalKey();
  final GlobalKey _notifyBtnKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    AttendanceService.ensureAttendanceSync();
    _loadData();
    AssignmentService.changeNotifier.addListener(_onAssignmentsChanged);
    _listenToBranchStatus();
    _listenToAttendanceLogs();
    _listenToMeatStocks();
    _startDayResetTimer();
    _maybeTriggerGuidedTour();
  }

  Future<void> _maybeTriggerGuidedTour() async {
    final seen = await TutorialService.hasSeenTutorial('driver_spotlight');
    if (!seen && mounted) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      _launchDriverTour();
    }
  }

  /// Public entry point — called by [DriverProfileScreen] Replay button
  /// after the user confirms they want to watch the tour again.
  void startTour() {
    if (!mounted) return;
    _launchDriverTour();
  }

  void _launchDriverTour() {
    GuidedTourOverlay.show(
      context: context,
      steps: [
        GuidedTourStep(
          targetKey: _firstStopCardKey,
          roleBadge: 'DRIVER ROUTE ONBOARDING',
          title: '1. First Destination (Sequential Route)',
          instruction: 'TAP: Tap Stop 1 to proceed.',
          explanation:
              'This is your first deployment stop. Stop 2 remains locked until preceding stops are completed to ensure correct sequence.',
          tip: 'The route begins at the Main Warehouse where fresh meats are loaded.',
        ),
        GuidedTourStep(
          targetKey: _notifyBtnKey,
          roleBadge: 'DRIVER ROUTE ONBOARDING',
          title: '2. Notify Branch Cook (On The Way)',
          instruction: 'TAP: Tap the "On the way" button.',
          explanation:
              'Tap this before departing. It automatically sends an alert to the branch cook so they can prepare for supply arrival.',
          tip: 'Send this alert approximately 10-15 minutes prior to arriving at the branch.',
          onTargetTapped: () {
            // Haptic only during tour — do NOT open the real confirm dialog
            // (that would dismiss the overlay and break the flow)
            HapticFeedback.lightImpact();
          },
        ),
        GuidedTourStep(
          targetKey: _rfidBannerKey,
          roleBadge: 'DRIVER ROUTE ONBOARDING',
          title: '3. RFID Auto-Completion System',
          instruction: 'TAP: Tap the RFID notice banner to proceed.',
          explanation:
              'AUTOMATED ARRIVAL: Upon arriving at the branch, have the Cook tap their RFID card on the portable reader. The store automatically opens and the stop completes.',
          tip: 'The RFID tap serves as the cook\'s official time-in and verifies supply arrival.',
        ),
      ],
      onCompleted: () => TutorialService.markTutorialSeen('driver_spotlight'),
      onSkipped: () => TutorialService.markTutorialSeen('driver_spotlight'),
    );
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _meatStocksSubscription?.cancel();
    _attendanceSubscription?.cancel();
    _dayResetTimer?.cancel();
    AssignmentService.changeNotifier.removeListener(_onAssignmentsChanged);
    super.dispose();
  }

  void _listenToAttendanceLogs() {
    _attendanceSubscription?.cancel();
    _attendanceSubscription = AttendanceService.watchTodayAttendance().listen((todayLogs) {
      if (!mounted) return;
      setState(() {
        for (final log in todayLogs) {
          final sName = log['staff_name']?.toString() ?? '';
          final sId = log['staff_id']?.toString() ?? '';
          final rawBId = (log['branch_id']?.toString() ?? '').toLowerCase();
          final branchCanonId = AttendanceService.resolveBranchForStaff(rawBId, sName, sId);
          if (branchCanonId.isEmpty || branchCanonId == 'commissary' || branchCanonId == 'unassigned') continue;

          final hasTimeIn = log['time_in'] != null && log['time_in'].toString().isNotEmpty;
          final hasTimeOut = log['time_out'] != null && log['time_out'].toString().isNotEmpty;

          if (hasTimeIn) {
            _openedBranchIdsToday.add(branchCanonId);
            _openedBranchIdsToday.add(rawBId);
          }

          if (hasTimeOut) {
            _attendanceConfirmedRetrievalIds.add(branchCanonId);
            _completedRetrievalIds.add(branchCanonId);
            _completedDeploymentIds.add(branchCanonId);
            _notifiedRetrievalIds.remove(branchCanonId);
          } else if (hasTimeIn) {
            _attendanceConfirmedDeploymentIds.add(branchCanonId);
            _completedDeploymentIds.add(branchCanonId);
            _notifiedDeploymentIds.remove(branchCanonId);
            // Cook has timed in for deployment, but not timed out: Retrieval is NOT completed!
            _attendanceConfirmedRetrievalIds.remove(branchCanonId);
            _completedRetrievalIds.remove(branchCanonId);
          }
        }
      });
    }, onError: (e) {
      debugPrint('Driver route attendance stream error: $e');
    });
  }

  void _onAssignmentsChanged() {
    if (mounted) setState(() {});
  }

  // ── Route Reset Scheduler (Midnight & 2:30 PM) ───────────────────
  /// Schedules a Timer that fires at the next operational reset milestone:
  /// 1. 2:30 PM (14:30) of the current day (if before 2:30 PM)
  /// 2. 12:00:01 AM (midnight) of the next day (if after 2:30 PM)
  void _startDayResetTimer() {
    _dayResetTimer?.cancel();
    final now = DateTime.now();
    final today230pm = DateTime(now.year, now.month, now.day, 14, 30, 0);
    final tomorrowMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);

    DateTime nextResetTarget;
    if (now.isBefore(today230pm)) {
      nextResetTarget = today230pm;
    } else {
      nextResetTarget = tomorrowMidnight;
    }

    final delay = nextResetTarget.difference(now);
    _dayResetTimer = Timer(delay, () {
      _resetForNewDay();
      _startDayResetTimer(); // Schedule the next milestone
    });
  }

  /// Clears route progress so the driver starts fresh for the new operational cycle/day.
  void _resetForNewDay() {
    if (!mounted) return;
    setState(() {
      _completedDeploymentIds.clear();
      _completedRetrievalIds.clear();
      _attendanceConfirmedDeploymentIds.clear();
      _attendanceConfirmedRetrievalIds.clear();
      _openedBranchIdsToday.clear();
      _notifiedDeploymentIds.clear();
      _notifiedRetrievalIds.clear();
      // Closed branches remain as-is until owner explicitly opens them
      _activeMode = RouteMode.deployment;
      _routeDateStr = DateTime.now().toIso8601String().substring(0, 10);
    });
    debugPrint('[RouteScreen] Route reset at ${DateTime.now()} — new route date: $_routeDateStr');
  }

  void _listenToBranchStatus() {
    _statusSubscription = FirebaseFirestore.instance
        .collection('branch_status')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      setState(() {
        for (final doc in snap.docs) {
          final data = doc.data();
          final isOpen = data['isOpen'] == true;
          final isClosed = data['isClosed'] == true;
          final lastTapType = data['lastTapType'] as String?;
          final rawBranchId = data['branchId']?.toString() ?? doc.id;
          final cookName = data['cookName']?.toString() ?? '';
          final branchId = AttendanceService.normalizeBranchId(rawBranchId, cookName);
          // openedDateStr tells us which calendar day this branch was opened.
          // If it was opened on a previous day, it does NOT count as a completed
          // deployment stop for today's route.
          final openedDateStr = data['openedDateStr'] as String?;
          final openedToday = openedDateStr == todayStr;

          final closedDateStr = data['closedDateStr'] as String?;
          final closedToday = closedDateStr == todayStr;

          // Track branches that were opened today
          if (openedToday) {
            _openedBranchIdsToday.add(branchId);
            _openedBranchIdsToday.add(doc.id);
            _openedBranchIdsToday.add(rawBranchId);
          }

          // A branch is considered closed for retrieval if:
          // lastTapType is retrieval_closing, it is currently closed and not open,
          // AND it was closed today (closedToday).
          // NOTE: We no longer require openedToday to be true — this was blocking
          // localhost testing and manual fallback closures where morning deployment
          // may not have set openedDateStr in Firestore.
          final isRetrievalClosingTap = closedToday &&
              lastTapType == 'retrieval_closing' &&
              isClosed &&
              !isOpen;

          // Deployment stop is completed when cook tapped arrival today or branch is open today
          final isDeploymentOpeningTap = (lastTapType == 'deployment_opening' || (isOpen && !isClosed)) && openedToday;

          if (isDeploymentOpeningTap) {
            _completedDeploymentIds.add(branchId);
            _completedDeploymentIds.add(doc.id);
            // Branch is currently open in deployment; retrieval CANNOT be completed!
            _completedRetrievalIds.remove(branchId);
            _completedRetrievalIds.remove(doc.id);
            _attendanceConfirmedRetrievalIds.remove(branchId);
            _attendanceConfirmedRetrievalIds.remove(doc.id);
          } else if (!isRetrievalClosingTap) {
            // Guard: Never remove from completedDeployment if:
            // 1. Manually confirmed by attendanceConfirmed set
            // 2. Branch has an offline tap queued (pending sync) — prevents stale
            //    Firestore snapshots (driverOnWay: true) from reverting DONE state
            //    while triggerOfflineSync() is still uploading.
            final hasOfflinePendingDeployment =
                DriverBleService.offlinePendingDeploymentIds.contains(branchId) ||
                DriverBleService.offlinePendingDeploymentIds.contains(doc.id) ||
                DriverBleService.offlinePendingDeploymentIds.contains(rawBranchId);
            if (!_attendanceConfirmedDeploymentIds.contains(branchId) &&
                !_attendanceConfirmedDeploymentIds.contains(doc.id) &&
                !hasOfflinePendingDeployment) {
              _completedDeploymentIds.remove(branchId);
              _completedDeploymentIds.remove(doc.id);
            }
          }

          // Retrieval stop is completed ONLY when cook has performed a closing RFID tap today
          if (isRetrievalClosingTap) {
            _completedRetrievalIds.add(branchId);
            _completedRetrievalIds.add(doc.id);
            // If retrieval is closed, deployment was naturally completed earlier today
            _completedDeploymentIds.add(branchId);
            _completedDeploymentIds.add(doc.id);
            _closedBranchIds.remove(branchId);
            _closedBranchIds.remove(doc.id);
          } else {
            // Guard: Never remove from completedRetrieval if:
            // 1. Manually confirmed by attendanceConfirmed set
            // 2. Branch has an offline retrieval tap queued (pending sync)
            final hasOfflinePendingRetrieval =
                DriverBleService.offlinePendingRetrievalIds.contains(branchId) ||
                DriverBleService.offlinePendingRetrievalIds.contains(doc.id) ||
                DriverBleService.offlinePendingRetrievalIds.contains(rawBranchId);
            if (!_attendanceConfirmedRetrievalIds.contains(branchId) &&
                !_attendanceConfirmedRetrievalIds.contains(doc.id) &&
                !hasOfflinePendingRetrieval) {
              _completedRetrievalIds.remove(branchId);
              _completedRetrievalIds.remove(doc.id);
            }
          }

          // driverOnWay flag — live push from Firestore (scoped to mode)
          final isDriverOnWay = data['driverOnWay'] == true;
          final driverOnWayMode = data['driverOnWayMode'] as String?;

          // Deployment notification tracking
          // KEY GUARD: If branch is already locally confirmed as DONE (completed locally or
          // has an offline tap queued), NEVER move it back to "On the way" — even if Firestore
          // still shows driverOnWay: true from a stale snapshot before sync completes.
          final locallyDoneDeployment = _completedDeploymentIds.contains(branchId) ||
              _completedDeploymentIds.contains(doc.id) ||
              _attendanceConfirmedDeploymentIds.contains(branchId) ||
              DriverBleService.offlinePendingDeploymentIds.contains(branchId) ||
              DriverBleService.offlinePendingDeploymentIds.contains(doc.id) ||
              DriverBleService.offlinePendingDeploymentIds.contains(rawBranchId);

          if (isDriverOnWay && (driverOnWayMode == 'deployment' || driverOnWayMode == null)) {
            if (locallyDoneDeployment) {
              // Branch is locally confirmed DONE — force clear "on the way", don't revert!
              _notifiedDeploymentIds.remove(branchId);
              _notifiedDeploymentIds.remove(doc.id);
              _notifiedDeploymentIds.remove(rawBranchId);
            } else {
              _notifiedDeploymentIds.add(branchId);
              _notifiedDeploymentIds.add(doc.id);
              _notifiedDeploymentIds.add(rawBranchId);
            }
          } else if (isDeploymentOpeningTap || (isDriverOnWay == false && driverOnWayMode == 'deployment')) {
            _notifiedDeploymentIds.remove(branchId);
            _notifiedDeploymentIds.remove(doc.id);
            _notifiedDeploymentIds.remove(rawBranchId);
          }

          // Retrieval notification tracking
          // KEY GUARD: Same as deployment — if already locally confirmed closed for retrieval,
          // never revert to "On the way" due to stale Firestore snapshot.
          final locallyDoneRetrieval = _completedRetrievalIds.contains(branchId) ||
              _completedRetrievalIds.contains(doc.id) ||
              _attendanceConfirmedRetrievalIds.contains(branchId) ||
              DriverBleService.offlinePendingRetrievalIds.contains(branchId) ||
              DriverBleService.offlinePendingRetrievalIds.contains(doc.id) ||
              DriverBleService.offlinePendingRetrievalIds.contains(rawBranchId);

          if (isDriverOnWay && driverOnWayMode == 'retrieval') {
            if (isRetrievalClosingTap || locallyDoneRetrieval) {
              // Already done — force clear "on the way"
              _notifiedRetrievalIds.remove(branchId);
              _notifiedRetrievalIds.remove(doc.id);
              _notifiedRetrievalIds.remove(rawBranchId);
            } else {
              _notifiedRetrievalIds.add(branchId);
              _notifiedRetrievalIds.add(doc.id);
              _notifiedRetrievalIds.add(rawBranchId);
            }
          }
          if (isRetrievalClosingTap || (isDriverOnWay == false && driverOnWayMode == 'retrieval')) {
            // Branch closed for retrieval: clear from "on the way" so it won't revert to ON THE WAY
            _notifiedRetrievalIds.remove(branchId);
            _notifiedRetrievalIds.remove(doc.id);
            _notifiedRetrievalIds.remove(rawBranchId);
          }
        }
      });
    }, onError: (e) {
      debugPrint('Branch status stream error: $e');
    });
  }

  void _listenToMeatStocks() {
    _meatStocksSubscription = FirestoreService.watchBranchMeatStocks().listen((stocks) {
      if (!mounted) return;
      setState(() {
        for (final s in stocks) {
          final canonId = AttendanceService.normalizeBranchId(s.branchId, s.branchName);
          if (s.isClosed && _activeMode == RouteMode.retrieval) {
            _closedBranchIds.add(canonId);
            _closedBranchIds.add(s.branchId);
          } else {
            _closedBranchIds.remove(canonId);
            _closedBranchIds.remove(s.branchId);
          }
        }
      });
    }, onError: (e) {
      debugPrint('Meat stocks stream error: $e');
    });
  }

  Future<void> _loadData() async {
    try {
      final branches = await SupabaseService.getBranches();
      if (!mounted) return;
      setState(() {
        _branches = branches.isNotEmpty ? branches : List.from(kSampleBranches);
      });
      await SupabaseService.refreshStaffFromRemote();
      await AssignmentService.ensureInitialized();
      // Proactively trigger pending offline Bluetooth RFID sync when network loads
      DriverBleService().triggerOfflineSync();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() {
          _branches = List.from(kSampleBranches);
        });
      }
    }
  }

  /// Resolves the currently assigned staff member for a branch based on
  /// live assignments (AssignmentService + Supabase).
  StaffMember? _getAssignedStaff(Branch branch) {
    final allStaff = SupabaseService.getAllStaff();
    final branchCanonId = AttendanceService.normalizeBranchId(branch.id, branch.name);
    final bNameLower = branch.name.toLowerCase().trim();
    final bFullNameLower = branch.fullName.toLowerCase().trim();

    // 1. Find staff whose effective assigned branch matches this branch
    final matching = allStaff.where((s) {
      if (s.isArchived || !s.isActive) return false;
      final assignedBranch = AssignmentService.getAssignedBranch(
        s.username,
        fallback: AssignmentService.getAssignedBranch(s.id, fallback: s.branch),
      ).trim();
      final abLower = assignedBranch.toLowerCase();
      final staffCanonId = AttendanceService.normalizeBranchId(
        abLower.isNotEmpty ? abLower : s.branch,
        s.fullName,
      );

      // Match by canonical branch ID (e.g., br1..br6)
      if (staffCanonId == branchCanonId && staffCanonId.isNotEmpty && staffCanonId != 'unassigned') {
        return true;
      }

      // Match by case-insensitive fuzzy string comparison
      if (abLower.isNotEmpty) {
        if (abLower == bFullNameLower ||
            abLower == bNameLower ||
            bFullNameLower.contains(abLower) ||
            abLower.contains(bNameLower)) {
          return true;
        }
      }

      final origBranchLower = s.branch.toLowerCase().trim();
      if (origBranchLower.isNotEmpty && origBranchLower != 'n/a' && origBranchLower != 'unassigned') {
        if (origBranchLower == bFullNameLower ||
            origBranchLower == bNameLower ||
            bFullNameLower.contains(origBranchLower) ||
            origBranchLower.contains(bNameLower)) {
          return true;
        }
      }

      return false;
    }).toList();

    if (matching.isEmpty) return null;

    // 2. Prefer cook who is onDuty today
    return matching.firstWhere(
      (s) {
        final status = AssignmentService.getWorkStatus(
          s.username,
          fallback: AssignmentService.getWorkStatus(
            s.id,
            fallback: s.isRestDay ? WorkStatus.restDay : WorkStatus.onDuty,
          ),
        );
        return status == WorkStatus.onDuty;
      },
      orElse: () => matching.first,
    );
  }

  bool _isRestDay(StaffMember staff) {
    final status = AssignmentService.getWorkStatus(
      staff.username,
      fallback: AssignmentService.getWorkStatus(
        staff.id,
        fallback: staff.isRestDay ? WorkStatus.restDay : WorkStatus.onDuty,
      ),
    );
    return status == WorkStatus.restDay;
  }

  bool _hasValidPhone(StaffMember? staff) {
    if (staff == null) return false;
    final p = staff.phone?.trim();
    if (p == null || p.isEmpty || p.toLowerCase().contains('pending')) {
      return false;
    }
    final digits = p.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 7;
  }

  static const Map<String, String> _branchHours = {
    'br1': '8:00 AM - 8:00 PM',
    'br2': '8:30 AM - 8:30 PM',
    'br3': '8:00 AM - 8:00 PM',
    'br4': '9:00 AM - 9:00 PM',
    'br5': '8:00 AM - 8:00 PM',
    'br6': '8:30 AM - 8:30 PM',
  };

  Set<String> get _currentCompletedSet {
    if (_activeMode == RouteMode.deployment) {
      return {..._completedDeploymentIds, ..._attendanceConfirmedDeploymentIds};
    } else {
      return {..._completedRetrievalIds, ..._attendanceConfirmedRetrievalIds};
    }
  }

  /// Determines if a branch was opened today via deployment arrival, cook time-in, or open status.
  bool _wasBranchOpenedToday(Branch branch) {
    final canonId = AttendanceService.normalizeBranchId(branch.id, branch.name);
    final bId = branch.id.toLowerCase().trim();
    final bName = branch.name.toLowerCase().trim();
    final bFullName = branch.fullName.toLowerCase().trim();

    return _openedBranchIdsToday.contains(bId) ||
        _openedBranchIdsToday.contains(canonId) ||
        _openedBranchIdsToday.contains(bName) ||
        _openedBranchIdsToday.contains(bFullName) ||
        _completedDeploymentIds.contains(bId) ||
        _completedDeploymentIds.contains(canonId) ||
        _attendanceConfirmedDeploymentIds.contains(canonId) ||
        _attendanceConfirmedRetrievalIds.contains(canonId) ||
        _completedRetrievalIds.contains(bId) ||
        _completedRetrievalIds.contains(canonId);
  }

  void _toggleMode(RouteMode? mode) {
    if (mode != null && mode != _activeMode) {
      setState(() {
        _activeMode = mode;
      });
    }
  }

  void _confirmPhoneCall(StaffMember staff) {
    final messenger = ScaffoldMessenger.of(context);
    final phone = staff.phone ?? '';
    final cleanNumber = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Call Staff'),
        content: Text('Do you want to call ${staff.fullName} ($phone)?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final Uri uri = Uri(scheme: 'tel', path: cleanNumber);
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Unable to open phone dialer for $cleanNumber')),
                  );
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Unable to open phone dialer. Please check device calling capabilities.')),
                );
              }
            },
            child: const Text('Call'),
          ),
        ],
      ),
    );
  }



  void _confirmNotifyStaff(Branch branch, StaffMember? staff) {
    if (_activeMode == RouteMode.retrieval && !_wasBranchOpenedToday(branch)) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Retrieval Unavailable'),
          content: Text(
            '${branch.fullName} was not opened during deployment today. Retrieval cannot be performed on an unopened branch.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (staff == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No assigned staff at ${branch.name}.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final staffName = staff.fullName;
    final modeLabel = _activeMode == RouteMode.deployment
        ? 'Deployment (Drop-off)'
        : 'Retrieval (Pick-up)';

    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Send Notification'),
        content: Text('Notify $staffName that you are "On the way" for $modeLabel at ${branch.name}?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(dialogCtx);
              if (!mounted) return;

              final canonId = AttendanceService.normalizeBranchId(branch.id, branch.name);

              // 1. Instant local Bluetooth Driver State (0ms, no waiting!)
              DriverBleService().setActiveDispatch(
                branchId: branch.id,
                branchName: branch.fullName,
                cookName: staffName,
                isOnTheWay: true,
                isDeployment: _activeMode == RouteMode.deployment,
              );

              // 2. Instant UI update to "Awaiting RFID Card Tap" (No endless spinner!)
              setState(() {
                if (_activeMode == RouteMode.deployment) {
                  _notifiedDeploymentIds.add(branch.id);
                  _notifiedDeploymentIds.add(canonId);
                } else {
                  _notifiedRetrievalIds.add(branch.id);
                  _notifiedRetrievalIds.add(canonId);
                }
              });

              messenger.showSnackBar(
                SnackBar(content: Text('Status set: "Driver is on the way" to ${branch.fullName}')),
              );

              // 3. Cloud update in background (Hindi mag-hahang kahit walang internet!)
              final driverName = AuthService.currentAppUser?.fullName ?? 'Driver';
              FirestoreService.setDriverOnTheWay(
                branchId: branch.id,
                branchName: branch.fullName,
                cookName: staffName,
                driverName: driverName,
                isDeployment: _activeMode == RouteMode.deployment,
              ).catchError((e) {
                debugPrint('setDriverOnTheWay background sync note: $e');
              });

              NotificationService.notifyStaffDriverOnTheWay(
                staffName: staffName,
                branchName: branch.fullName,
                mode: _activeMode.name,
                staffId: staff.id,
                staffUsername: staff.username,
                driverName: driverName,
              ).catchError((_) {});
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _confirmManualArrivalVerification(Branch branch, StaffMember? staff) {
    if (_activeMode == RouteMode.retrieval && !_wasBranchOpenedToday(branch)) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Retrieval Unavailable'),
          content: Text(
            '${branch.fullName} was not opened during deployment today. Cannot close or retrieve an unopened branch.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
      return;
    }
    final isDeployment = _activeMode == RouteMode.deployment;
    final action = isDeployment ? 'Arrival (Store Opening)' : 'Departure (Store Closing)';
    final staffName = staff?.fullName ?? 'Assigned Cook';

    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text('Manual Verification ($action)'),
        content: Text(
          'Manually verify ${isDeployment ? "arrival" : "departure"} for $staffName at ${branch.name}?\n\n'
          'Use this fallback only if the Cook\'s physical RFID card is unavailable or the portable reader is offline.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(dialogCtx);
              _handleManualArrivalVerification(branch, staff);
            },
            child: Text(isDeployment ? 'Confirm & Open' : 'Confirm & Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleManualArrivalVerification(Branch branch, StaffMember? staff) async {
    final isDeployment = _activeMode == RouteMode.deployment;
    // NOTE: Removed early-return guard for retrieval on unopened branch.
    // This was blocking localhost testing where morning deployment wasn't done.
    // Retrieval fallback should always be allowed when driver manually confirms.
    final staffName = staff?.fullName ?? 'Assigned Cook';
    final cookId = staff?.id ?? 'cook_${branch.id}';
    final rfidTag = (staff?.rfidTag != null && staff!.rfidTag.isNotEmpty)
        ? staff.rfidTag
        : 'MANUAL_${isDeployment ? "OPEN" : "CLOSE"}_${branch.id}';

    final branchCanonId = AttendanceService.normalizeBranchId(branch.id, branch.name);
    setState(() {
      if (isDeployment) {
        _notifiedDeploymentIds.remove(branch.id);
        _notifiedDeploymentIds.remove(branchCanonId);
        _completedDeploymentIds.add(branch.id);
        _completedDeploymentIds.add(branchCanonId);
        _openedBranchIdsToday.add(branch.id);
        _openedBranchIdsToday.add(branchCanonId);
        // Deployment opened; retrieval is definitely NOT completed
        _completedRetrievalIds.remove(branch.id);
        _completedRetrievalIds.remove(branchCanonId);
        _attendanceConfirmedRetrievalIds.remove(branch.id);
        _attendanceConfirmedRetrievalIds.remove(branchCanonId);
      } else {
        _notifiedRetrievalIds.remove(branch.id);
        _notifiedRetrievalIds.remove(branchCanonId);
        _completedRetrievalIds.add(branch.id);
        _completedRetrievalIds.add(branchCanonId);
        // Retrieval closed: also force-remove from notified so it won't re-show "ON THE WAY"
        _attendanceConfirmedRetrievalIds.add(branch.id);
        _attendanceConfirmedRetrievalIds.add(branchCanonId);
      }
    });

    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isDeployment ? Icons.store_rounded : Icons.lock_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isDeployment
                      ? '${branch.name} is now OPEN. Manual arrival verified.'
                      : '${branch.name} is now CLOSED. Manual departure verified.',
                ),
              ),
            ],
          ),
          backgroundColor: isDeployment ? AppColors.success : const Color(0xFFC62828),
        ),
      );
    }

    // Cloud updates in background — increased timeout to 8s for slow/cellular connections
    FirestoreService.processBranchCookRfidTap(
      branchId: branch.id,
      branchName: branch.fullName,
      cookName: staffName,
      cookId: cookId,
      isDeployment: isDeployment,
      rfidTag: rfidTag,
      deviceId: 'driver_manual_override',
    ).timeout(const Duration(seconds: 8)).catchError((e) {
      debugPrint('Manual override Firestore note: $e');
      return false;
    });

    if (staff != null) {
      AttendanceService.ensureSupabaseAttendanceLog(
        staff: staff,
        branchId: branchCanonId,
        branchName: branch.fullName,
        rfidUid: rfidTag,
        deviceId: 'driver_manual_override',
        isDeployment: isDeployment,
      ).timeout(const Duration(seconds: 8)).catchError((e) {
        debugPrint('Manual override Supabase note: $e');
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    // Keep full ordered route sequence
    final branches = (_branches.isNotEmpty ? [..._branches] : [...kSampleBranches])
      ..sort((a, b) => a.dailyRouteSequence.compareTo(b.dailyRouteSequence));

    // A branch is active in the driver's route ONLY if:
    // 1. It is OPEN (not closed by owner in inventory/status)
    // 2. It has an assigned staff member who is ON DUTY today (not rest day, not unassigned)
    final activeBranches = branches.where((b) {
      final canonId = AttendanceService.normalizeBranchId(b.id, b.name);
      if (_activeMode == RouteMode.retrieval) {
        final isCompleted = _currentCompletedSet.contains(b.id) || _currentCompletedSet.contains(canonId);
        if (!isCompleted) {
          final isClosed = _closedBranchIds.contains(b.id) ||
              _closedBranchIds.contains(canonId) ||
              _closedBranchIds.contains(b.name.trim().toLowerCase()) ||
              _closedBranchIds.contains(b.fullName.trim().toLowerCase());
          if (isClosed) return false;
        }
      }

      final staff = _getAssignedStaff(b);
      if (staff == null) return false;
      if (_isRestDay(staff)) return false;

      return true;
    }).toList();

    final totalTargets = _activeMode == RouteMode.retrieval
        ? activeBranches.where((b) => _wasBranchOpenedToday(b)).toList()
        : activeBranches;

    final completedCount = totalTargets.where((b) {
      final canonId = AttendanceService.normalizeBranchId(b.id, b.name);
      return _currentCompletedSet.contains(b.id) || _currentCompletedSet.contains(canonId);
    }).length;
    final allDone = totalTargets.isNotEmpty && completedCount == totalTargets.length;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const DriverNavBar(
        title: 'Route',
        trailing: DriverTopActions(),
      ),
      child: AbsorbPointer(
        absorbing: false,
        child: Stack(
          children: [
            SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent, width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _toggleMode(RouteMode.deployment),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _activeMode == RouteMode.deployment ? AppColors.accent : CupertinoColors.transparent,
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Deployment',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _activeMode == RouteMode.deployment ? CupertinoColors.white : AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(width: 1, height: 20, color: AppColors.accent),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _toggleMode(RouteMode.retrieval),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _activeMode == RouteMode.retrieval ? AppColors.accent : CupertinoColors.transparent,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(11)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Retrieval',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _activeMode == RouteMode.retrieval ? CupertinoColors.white : AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DriverCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: allDone
                                    ? AppColors.success.withValues(alpha: 0.10)
                                    : AppColors.accent.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                allDone ? CupertinoIcons.checkmark_alt : CupertinoIcons.arrow_branch,
                                color: allDone ? AppColors.success : AppColors.accent,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    allDone ? 'Route Finished' : 'Active Route Progress',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    totalTargets.isEmpty
                                        ? (_activeMode == RouteMode.retrieval
                                            ? 'No branches opened for retrieval today'
                                            : 'No active branches today')
                                        : (_activeMode == RouteMode.retrieval
                                            ? '$completedCount of ${totalTargets.length} branches retrieved'
                                            : '$completedCount of ${activeBranches.length} active stops reached'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: totalTargets.isEmpty ? 0 : completedCount / totalTargets.length,
                            minHeight: 8,
                            backgroundColor: AppColors.border.withValues(alpha: 0.4),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              allDone ? AppColors.success : AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // RFID info chip
                        Container(
                          key: _rfidBannerKey,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.radiowaves_right, size: 13, color: AppColors.accent),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Stops auto-complete when cook taps the RFID unit',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  DriverSectionHeader(
                    label: _activeMode == RouteMode.deployment 
                        ? 'Staff Deployment Sequence' 
                        : 'Staff Retrieval Sequence',
                    icon: CupertinoIcons.list_number,
                  ),

                  const SizedBox(height: 12),

                  if (activeBranches.isEmpty)
                    DriverCard(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.moon_zzz_fill, size: 36, color: AppColors.accent),
                          SizedBox(height: 12),
                          Text(
                            'No Delivery Route Today',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'All branches are currently closed in Branch Allocation by the Owner.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ...List.generate(activeBranches.length, (index) {
                      final branch = activeBranches[index];
                      final isLast = index == activeBranches.length - 1;
                      final branchCanonId = AttendanceService.normalizeBranchId(branch.id, branch.name);
                      final completed = _currentCompletedSet.contains(branch.id) ||
                          _currentCompletedSet.contains(branchCanonId);
                      final notified = _notifiedStaffIds.contains(branch.id) ||
                          _notifiedStaffIds.contains(branchCanonId);
                      final staff = _getAssignedStaff(branch);
                      final hasStaff = staff != null;
                      final staffName = staff?.fullName ?? 'Unassigned';
                      final hours = _branchHours[branch.id] ?? _branchHours[branchCanonId] ?? '8:00 AM - 8:00 PM';
                      final wasOpenedToday = _wasBranchOpenedToday(branch);
                      final isUnopenedRetrieval = _activeMode == RouteMode.retrieval && !wasOpenedToday && !completed;

                      // Sequence Enforcement: A stop is active ONLY if all preceding active stops are completed.
                      bool isLocked = false;
                      if (isUnopenedRetrieval) {
                        isLocked = true;
                      } else {
                        for (int i = 0; i < index; i++) {
                          final prevBranch = activeBranches[i];
                          if (_activeMode == RouteMode.retrieval && !_wasBranchOpenedToday(prevBranch)) {
                            continue;
                          }
                          final prevCanonId = AttendanceService.normalizeBranchId(prevBranch.id, prevBranch.name);
                          final isPrevDone = _currentCompletedSet.contains(prevBranch.id) ||
                              _currentCompletedSet.contains(prevCanonId);
                          if (!isPrevDone) {
                            isLocked = true;
                            break;
                          }
                        }
                      }

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: completed
                                        ? AppColors.success
                                        : (isLocked ? AppColors.border : AppColors.accent),
                                    shape: BoxShape.circle,
                                  ),
                                  child: completed
                                      ? const Icon(CupertinoIcons.check_mark, color: CupertinoColors.white, size: 14)
                                      : Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: isLocked ? AppColors.textSecondary : CupertinoColors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                                if (!isLast)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    color: completed
                                        ? AppColors.success.withValues(alpha: 0.3)
                                        : (isLocked
                                            ? AppColors.border.withValues(alpha: 0.5)
                                            : AppColors.accent.withValues(alpha: 0.15)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Opacity(
                                opacity: isLocked ? 0.65 : 1.0,
                                child: DriverCard(
                                  key: index == 0 ? _firstStopCardKey : null,
                                  padding: const EdgeInsets.all(16),
                                  highlighted: !completed && notified && !isLocked,
                                  borderColor: completed ? AppColors.success.withValues(alpha: 0.2) : null,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.accent.withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(5),
                                                        ),
                                                        child: Text(
                                                          'Stop ${index + 1} of ${activeBranches.length} • Route #${branch.dailyRouteSequence}',
                                                          style: const TextStyle(
                                                            fontSize: 10.5,
                                                            fontWeight: FontWeight.w700,
                                                            color: AppColors.accent,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  branch.fullName,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: isLocked ? AppColors.textSecondary : AppColors.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(CupertinoIcons.time, size: 12, color: AppColors.textSecondary),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        'Hours: $hours',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: AppColors.textSecondary,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (completed)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.success.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'DONE',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.success,
                                                ),
                                              ),
                                            )
                                          else if (notified)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.warning.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(CupertinoIcons.car_detailed, size: 12, color: AppColors.warning),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'ON THE WAY',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppColors.warning,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            Icon(CupertinoIcons.location_north_fill, 
                                                 size: 16, color: isLocked ? AppColors.border : AppColors.accent),
                                        ],
                                      ),
                                    
                                    const SizedBox(height: 16),
                                    
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 34,
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: hasStaff ? AppColors.accentDark : AppColors.border,
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              hasStaff ? staff.initials : '?',
                                              style: const TextStyle(
                                                color: CupertinoColors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Assigned Staff',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                                Text(
                                                  staffName,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: hasStaff ? AppColors.textPrimary : AppColors.textSecondary,
                                                  ),
                                                ),
                                                if (hasStaff) ...[
                                                  if (_isRestDay(staff))
                                                    const Text(
                                                      'On Rest Day today',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: AppColors.warning,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    )
                                                  else if (_hasValidPhone(staff))
                                                    Text(
                                                      staff.phone!,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: AppColors.textSecondary,
                                                      ),
                                                    )
                                                  else
                                                    const Text(
                                                      'No registered number',
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        fontStyle: FontStyle.italic,
                                                        color: AppColors.textSecondary,
                                                      ),
                                                    ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          if (hasStaff && _hasValidPhone(staff))
                                            CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(34, 34),
                                              child: Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: AppColors.success.withValues(alpha: 0.12),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  CupertinoIcons.phone_fill,
                                                  size: 17,
                                                  color: AppColors.success,
                                                ),
                                              ),
                                              onPressed: () => _confirmPhoneCall(staff),
                                            ),
                                        ],
                                      ),
                                    ),

                                    if (!completed) ...[
                                      const SizedBox(height: 16),
                                      if (notified) ...[
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: (_activeMode == RouteMode.deployment
                                                    ? AppColors.success
                                                    : const Color(0xFFC62828))
                                                .withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: (_activeMode == RouteMode.deployment
                                                      ? AppColors.success
                                                      : const Color(0xFFC62828))
                                                  .withValues(alpha: 0.35),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    CupertinoIcons.radiowaves_right,
                                                    size: 16,
                                                    color: _activeMode == RouteMode.deployment
                                                        ? AppColors.success
                                                        : const Color(0xFFC62828),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      _activeMode == RouteMode.deployment
                                                          ? 'AWAITING COOK RFID TAP (ARRIVAL)'
                                                          : 'AWAITING COOK RFID TAP (CLOSING)',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w800,
                                                        letterSpacing: 0.3,
                                                        color: _activeMode == RouteMode.deployment
                                                            ? AppColors.success
                                                            : const Color(0xFFC62828),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                _activeMode == RouteMode.deployment
                                                    ? 'Have the cook tap their RFID card on the portable reader to automatically open the branch and complete this stop.'
                                                    : 'Have the cook tap their RFID card on the portable reader to close the branch and record time-out.',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textSecondary,
                                                  height: 1.4,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              SizedBox(
                                                width: double.infinity,
                                                height: 34,
                                                child: CupertinoButton(
                                                  padding: EdgeInsets.zero,
                                                  color: AppColors.accent.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(8),
                                                  onPressed: isLocked
                                                      ? null
                                                      : () => _confirmManualArrivalVerification(branch, staff),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: const [
                                                      Icon(CupertinoIcons.checkmark_shield_fill,
                                                          size: 13, color: AppColors.accent),
                                                      SizedBox(width: 6),
                                                      Text(
                                                        'Manual Verification (Fallback)',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          color: AppColors.accent,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ]
                                      else
                                        // "On the way" button — only shown before driver has notified
                                        CupertinoButton(
                                          key: index == 0 ? _notifyBtnKey : null,
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(double.infinity, 38),
                                          color: (isLocked || !hasStaff)
                                              ? AppColors.border.withValues(alpha: 0.1)
                                              : AppColors.accent.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          onPressed: (isLocked || !hasStaff)
                                              ? null
                                              : () => _confirmNotifyStaff(branch, staff),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                isUnopenedRetrieval
                                                    ? CupertinoIcons.slash_circle
                                                    : CupertinoIcons.bell,
                                                size: 14,
                                                color: (isLocked || !hasStaff)
                                                    ? AppColors.border
                                                    : AppColors.accent,
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  isUnopenedRetrieval
                                                      ? 'Branch Not Opened Today'
                                                      : (!hasStaff ? 'No Staff' : 'On the way'),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: (isLocked || !hasStaff)
                                                        ? AppColors.border
                                                        : AppColors.accent,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  ),
),
);
}
}

