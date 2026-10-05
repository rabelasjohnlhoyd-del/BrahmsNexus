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

  // Track who has been notified in the current session
  final Set<String> _notifiedStaffIds = {};

  List<Branch> _branches = [];
  StreamSubscription? _statusSubscription;

  // ── Guided Tour Keys (Live Spotlight) ───────────────────────────
  final GlobalKey _rfidBannerKey = GlobalKey();
  final GlobalKey _firstStopCardKey = GlobalKey();
  final GlobalKey _notifyBtnKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
    AssignmentService.changeNotifier.addListener(_onAssignmentsChanged);
    _listenToBranchStatus();
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
          title: '1. Unang Destinasyon (Sequential Route)',
          instruction: 'PINDUTIN: I-tap ang Stop 1 para magpatuloy.',
          explanation:
              'Ito ang iyong unang deployment stop (Brgy. Gatid). Naka-lock ang Stop 2 hangga\'t hindi natatapos ang nauna upang masiguro ang tamang pagkakasunod-sunod.',
          tip: 'Magsisimula ang ruta sa Main Warehouse kung saan ikinakarga ang mga sariwang karne.',
        ),
        GuidedTourStep(
          targetKey: _notifyBtnKey,
          roleBadge: 'DRIVER ROUTE ONBOARDING',
          title: '2. Alerto sa Branch Cook (On The Way)',
          instruction: 'PINDUTIN: I-tap ang "On the way" button.',
          explanation:
              'Pindutin ito bago bumiyahe. Awtomatikong magpapadala ng alert sa cellphone ng branch cook upang makapaghanda siya sa pagdating ng mga supplies.',
          tip: 'Pindutin ito mga 10-15 minuto bago makarating sa sangay.',
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
          instruction: 'PINDUTIN: I-tap ang RFID notice banner upang magpatuloy.',
          explanation:
              'WALA NANG DROPPED OFF BUTTON: Pagdating mo sa branch, ipa-tap lang sa Cook ang kanyang RFID card sa portable reader. Kusa nang magbubukas ang tindahan at magiging COMPLETED ang stop!',
          tip: 'Ang RFID tap ang opisyal na time-in ng branch cook at verification ng supply arrival.',
        ),
      ],
      onCompleted: () => TutorialService.markTutorialSeen('driver_spotlight'),
      onSkipped: () => TutorialService.markTutorialSeen('driver_spotlight'),
    );
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    AssignmentService.changeNotifier.removeListener(_onAssignmentsChanged);
    super.dispose();
  }

  void _onAssignmentsChanged() {
    if (mounted) setState(() {});
  }

  void _listenToBranchStatus() {
    _statusSubscription = FirebaseFirestore.instance
        .collection('branch_status')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        for (final doc in snap.docs) {
          final data = doc.data();
          final isOpen = data['isOpen'] == true;
          final lastTapType = data['lastTapType'] as String?;
          if (isOpen || lastTapType == 'deployment_opening') {
            _completedDeploymentIds.add(doc.id);
          }
          if (!isOpen && lastTapType == 'retrieval_closing') {
            _completedRetrievalIds.add(doc.id);
          }
          if (data['driverOnWay'] == true) {
            _notifiedStaffIds.add(doc.id);
          }
        }
      });
    }, onError: (e) {
      debugPrint('Branch status stream error: $e');
    });
  }

  Future<void> _loadData() async {
    try {
      final branches = await SupabaseService.getBranches();
      if (!mounted) return;
      setState(() {
        _branches = branches.isNotEmpty ? branches : List.from(kSampleBranches);
      });
      await AssignmentService.ensureInitialized();
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
    // 1. Find staff whose effective assigned branch matches this branch
    final matching = allStaff.where((s) {
      if (s.isArchived || !s.isActive) return false;
      final assignedBranch = AssignmentService.getAssignedBranch(
        s.username,
        fallback: AssignmentService.getAssignedBranch(s.id, fallback: s.branch),
      );
      return assignedBranch == branch.fullName ||
          assignedBranch == branch.name ||
          (assignedBranch.isNotEmpty && branch.fullName.contains(assignedBranch));
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

  Set<String> get _currentCompletedSet =>
      _activeMode == RouteMode.deployment ? _completedDeploymentIds : _completedRetrievalIds;

  void _toggleMode(RouteMode? mode) {
    if (mode != null) {
      setState(() {
        _activeMode = mode;
        _notifiedStaffIds.clear();
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
                  SnackBar(content: Text('Error placing call: $e')),
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
            onPressed: () async {
              Navigator.pop(dialogCtx);
              setState(() {
                _notifiedStaffIds.add(branch.id);
              });
              final driverName = AuthService.currentAppUser?.fullName ?? 'Driver';
              await NotificationService.notifyStaffDriverOnTheWay(
                staffName: staffName,
                branchName: branch.fullName,
                mode: _activeMode.name,
                staffId: staff.id,
                staffUsername: staff.username,
                driverName: driverName,
              );
              // Update branch_status in Firestore so the owner's Branch Status
              // overview reflects "DRIVER ON THE WAY" in real-time.
              await FirestoreService.setDriverOnTheWay(
                branchId: branch.id,
                branchName: branch.fullName,
                cookName: staffName,
                driverName: driverName,
                isDeployment: _activeMode == RouteMode.deployment,
              );
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Notified $staffName: "Driver is on the way"')),
                );
              }
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _confirmSimulatedRfidTap(Branch branch, StaffMember? staff) {
    final isDeployment = _activeMode == RouteMode.deployment;
    final action = isDeployment ? 'Opening (Arrival)' : 'Closing (Departure)';
    final staffName = staff?.fullName ?? 'Assigned Cook';

    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text('Simulate Cook RFID $action'),
        content: Text(
          'Simulate RFID card tap for $staffName at ${branch.name}?\n\n'
          'This will mark ${branch.name} as ${isDeployment ? "OPEN" : "CLOSED"} in real-time and complete this stop.',
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
              _handleSimulatedRfidTap(branch, staff);
            },
            child: Text(isDeployment ? 'Confirm & Open' : 'Confirm & Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSimulatedRfidTap(Branch branch, StaffMember? staff) async {
    final isDeployment = _activeMode == RouteMode.deployment;
    final staffName = staff?.fullName ?? 'Assigned Cook';
    final cookId = staff?.id ?? 'cook_${branch.id}';
    final rfidTag = (staff?.rfidTag != null && staff!.rfidTag.isNotEmpty)
        ? staff.rfidTag
        : 'SIM_${isDeployment ? "OPEN" : "CLOSE"}_${branch.id}';

    setState(() {
      if (isDeployment) {
        _completedDeploymentIds.add(branch.id);
      } else {
        _completedRetrievalIds.add(branch.id);
      }
    });

    await FirestoreService.processBranchCookRfidTap(
      branchId: branch.id,
      branchName: branch.fullName,
      cookName: staffName,
      cookId: cookId,
      isDeployment: isDeployment,
      rfidTag: rfidTag,
      deviceId: 'simulated_driver_route',
    );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          isDeployment
              ? '✅ ${branch.name} is now OPEN! (Simulated Cook Tap logged)'
              : '🔒 ${branch.name} is now CLOSED! (Simulated Cook Tap logged)',
        ),
        backgroundColor: isDeployment ? AppColors.success : const Color(0xFFC62828),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final branches = (_branches.isNotEmpty ? [..._branches] : [...kSampleBranches])
      ..sort((a, b) => a.dailyRouteSequence.compareTo(b.dailyRouteSequence));

    final completedCount = _currentCompletedSet.length;
    final allDone = completedCount == branches.length;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const DriverNavBar(
        title: 'Route',
        trailing: DriverTopActions(),
      ),
      child: SafeArea(
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
                                    '$completedCount of ${branches.length} stops reached',
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
                            value: branches.isEmpty ? 0 : completedCount / branches.length,
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

                  ...List.generate(branches.length, (index) {
                    final branch = branches[index];
                    final isLast = index == branches.length - 1;
                    final completed = _currentCompletedSet.contains(branch.id);
                    final notified = _notifiedStaffIds.contains(branch.id);
                    final staff = _getAssignedStaff(branch);
                    final hasStaff = staff != null;
                    final staffName = staff?.fullName ?? 'Unassigned';
                    final hours = _branchHours[branch.id] ?? '8:00 AM - 8:00 PM';

                    // Sequence Enforcement: A stop is active ONLY if all preceding stops are completed.
                    bool isLocked = false;
                    for (int i = 0; i < index; i++) {
                      if (!_currentCompletedSet.contains(branches[i].id)) {
                        isLocked = true;
                        break;
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
                                opacity: isLocked ? 0.6 : 1.0,
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
                                                    Text(
                                                      'Hours: $hours',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors.textSecondary,
                                                        fontWeight: FontWeight.w500,
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
                                        // Temporary Simulated Cook RFID Tap Button (Opening for Deployment, Closing for Retrieval)
                                        CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(double.infinity, 42),
                                          color: _activeMode == RouteMode.deployment
                                              ? AppColors.success
                                              : const Color(0xFFC62828),
                                          borderRadius: BorderRadius.circular(12),
                                          onPressed: isLocked ? null : () => _confirmSimulatedRfidTap(branch, staff),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                CupertinoIcons.radiowaves_right,
                                                size: 16,
                                                color: CupertinoColors.white,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _activeMode == RouteMode.deployment
                                                    ? 'Simulate Cook Tap (Open Branch)'
                                                    : 'Simulate Cook Tap (Close Branch)',
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: CupertinoColors.white,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(CupertinoIcons.info_circle, size: 11, color: AppColors.textSecondary),
                                            const SizedBox(width: 4),
                                            Text(
                                              _activeMode == RouteMode.deployment
                                                  ? 'Temporary trigger for branch opening arrival'
                                                  : 'Temporary trigger for branch closing retrieval',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                color: AppColors.textSecondary,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
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
                                                CupertinoIcons.bell,
                                                size: 14,
                                                color: (isLocked || !hasStaff)
                                                    ? AppColors.border
                                                    : AppColors.accent,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                !hasStaff ? 'No Staff' : 'On the way',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: (isLocked || !hasStaff)
                                                      ? AppColors.border
                                                      : AppColors.accent,
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
    );
  }
}

