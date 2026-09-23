import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/branch.dart';
import '../../models/branch_assignment.dart';
import '../../models/staff_member.dart';
import '../../services/assignment_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_card.dart';
import '../../widgets/driver_nav_bar.dart';
import '../../widgets/driver_top_actions.dart';
import '../../widgets/driver_section_header.dart';

/// The Transport Mode for the Route — either Deployment (morning pickup)
/// or Retrieval (evening pickup).
enum RouteMode { deployment, retrieval }

/// Route tab — manages the transport of staff to and from their branches.
class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  RouteMode _activeMode = RouteMode.deployment;

  // Track completed stops for each mode
  final Set<String> _completedDeploymentIds = {};
  final Set<String> _completedRetrievalIds = {};

  // Track who has been notified in the current session
  final Set<String> _notifiedStaffIds = {};

  List<Branch> _branches = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    AssignmentService.changeNotifier.addListener(_onAssignmentsChanged);
  }

  @override
  void dispose() {
    AssignmentService.changeNotifier.removeListener(_onAssignmentsChanged);
    super.dispose();
  }

  void _onAssignmentsChanged() {
    if (mounted) setState(() {});
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
        title: const Text('Tawagan ang Staff'),
        content: Text('Gusto mo bang tawagan si ${staff.fullName} ($phone)?'),
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
                    SnackBar(content: Text('Hindi mabuksan ang phone dialer para sa $cleanNumber')),
                  );
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error sa pagtawag: $e')),
                );
              }
            },
            child: const Text('Tawagan'),
          ),
        ],
      ),
    );
  }



  void _confirmNotifyStaff(Branch branch, StaffMember? staff) {
    final messenger = ScaffoldMessenger.of(context);
    final staffName = staff?.fullName ?? 'Staff';
    final modeLabel = _activeMode == RouteMode.deployment
        ? 'Deployment (Hatid)'
        : 'Retrieval (Sundo)';

    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Magpadala ng Notification'),
        content: Text('I-notify si $staffName na "On the way" ka na para sa $modeLabel sa ${branch.name}?'),
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
                staffId: staff?.id,
                staffUsername: staff?.username,
                driverName: driverName,
              );
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Na-notify si $staffName: "Driver is on the way"')),
                );
              }
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _confirmMarkCompleted(Branch branch, StaffMember? staff) {
    final messenger = ScaffoldMessenger.of(context);
    final isDeployment = _activeMode == RouteMode.deployment;
    final action = isDeployment ? 'Dropped Off' : 'Picked Up';
    final staffName = staff?.fullName ?? 'Staff';

    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Status Update'),
        content: Text('I-confirm na $action na si $staffName sa ${branch.name}?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(dialogCtx);
              setState(() {
                _currentCompletedSet.add(branch.id);
              });

              final driverName = AuthService.currentAppUser?.fullName ?? 'Driver';
              if (isDeployment) {
                await NotificationService.notifyOwnerStaffDroppedOff(
                  staffName: staffName,
                  branchName: branch.fullName,
                  driverName: driverName,
                );
              } else {
                await NotificationService.notifyOwnerStaffPickedUp(
                  staffName: staffName,
                  branchName: branch.fullName,
                  driverName: driverName,
                );
              }

              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text('$action: $staffName sa ${branch.name} — Na-notify si Owner!')),
                );
              }
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _showMapModal() {
    showCupertinoModalPopup(
      context: context,
      barrierDismissible: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Route Navigation',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Text(
                        'Visualizing stops and sequence',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(CupertinoIcons.xmark_circle_fill, size: 28, color: AppColors.border),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  CustomPaint(
                    painter: _MapPainter(),
                    size: Size.infinite,
                  ),
                ],
              ),
            ),
          ],
        ),
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
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _showMapModal,
                          child: Container(
                            height: 100,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CustomPaint(
                                    painter: _MapPainter(),
                                    size: Size.infinite,
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        CupertinoColors.black.withValues(alpha: 0.0),
                                        CupertinoColors.black.withValues(alpha: 0.3),
                                      ],
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(CupertinoIcons.map_fill, size: 14, color: AppColors.accent),
                                        SizedBox(width: 8),
                                        Text(
                                          'Open Live Route Map',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
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
                                                      'Naka Rest Day ngayon',
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
                                                      'Walang registered number',
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
                                      Row(
                                        children: [
                                          Expanded(
                                            child: CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(0, 38),
                                              color: notified 
                                                ? AppColors.background 
                                                : (isLocked ? AppColors.border.withValues(alpha: 0.1) : AppColors.accent.withValues(alpha: 0.1)),
                                              borderRadius: BorderRadius.circular(12),
                                              onPressed: isLocked ? null : () => _confirmNotifyStaff(branch, staff),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    notified ? CupertinoIcons.bell_fill : CupertinoIcons.bell,
                                                    size: 14,
                                                    color: isLocked ? AppColors.border : (notified ? AppColors.textSecondary : AppColors.accent),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    notified ? 'Notified' : 'On the way',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: isLocked ? AppColors.border : (notified ? AppColors.textSecondary : AppColors.accent),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(0, 38),
                                              color: isLocked ? AppColors.border : AppColors.accent,
                                              borderRadius: BorderRadius.circular(12),
                                              onPressed: isLocked ? null : () => _confirmMarkCompleted(branch, staff),
                                              child: Text(
                                                _activeMode == RouteMode.deployment ? 'Dropped Off' : 'Picked Up',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: isLocked ? AppColors.textSecondary : CupertinoColors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var i = 0.0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (var i = 0.0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    final roadPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final roadPath = Path();
    roadPath.moveTo(0, size.height * 0.4);
    roadPath.lineTo(size.width * 0.3, size.height * 0.4);
    roadPath.lineTo(size.width * 0.3, size.height * 0.7);
    roadPath.lineTo(size.width * 0.8, size.height * 0.7);
    roadPath.lineTo(size.width * 0.8, size.height * 0.2);
    roadPath.lineTo(size.width, size.height * 0.2);
    canvas.drawPath(roadPath, roadPaint);

    final stopPaint = Paint()..color = AppColors.accent;
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.4), 5, stopPaint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.7), 5, stopPaint);
    
    final currentPosPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.7), 6, currentPosPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

