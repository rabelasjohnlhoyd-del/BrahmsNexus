import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/branch.dart';
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

  static const Map<String, String> _assignedStaff = {
    'br1': 'Juan Dela Cruz',
    'br2': 'Pedro Santos',
    'br3': 'Maria Reyes',
    'br4': 'Liza Gomez',
    'br5': 'Ricardo Dalisay',
    'br6': 'Elena Adarna',
  };

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

  void _confirmPhoneCall(String name) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Tawagan ang Staff'),
        content: Text('Gusto mo bang tawagan si $name?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              // Mock call logic
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Calling $name...')),
              );
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _confirmNotifyStaff(String branchId) {
    final staffName = _assignedStaff[branchId] ?? 'Staff';
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Magpadala ng Notification'),
        content: Text('I-notify si $staffName na "On the way" ka na?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _notifiedStaffIds.add(branchId);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Notified $staffName: "Driver is on the way"')),
              );
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _confirmMarkCompleted(String branchId) {
    final action = _activeMode == RouteMode.deployment ? 'Dropped Off' : 'Picked Up';
    final branchName = kSampleBranches.firstWhere((b) => b.id == branchId).name;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Status Update'),
        content: Text('I-confirm na $action na ang staff sa $branchName?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentCompletedSet.add(branchId);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$action staff at $branchName recorded.')),
              );
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
    final branches = [...kSampleBranches]
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
                                        const Text(
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
                    final staffName = _assignedStaff[branch.id] ?? 'Unassigned';
                    final hours = _branchHours[branch.id] ?? 'TBA';

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
                                  color: completed ? AppColors.success : AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: completed
                                    ? const Icon(CupertinoIcons.check_mark, color: CupertinoColors.white, size: 14)
                                    : Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: CupertinoColors.white,
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
                                        : AppColors.accent.withValues(alpha: 0.15),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: DriverCard(
                                padding: const EdgeInsets.all(16),
                                highlighted: !completed && notified,
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
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
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
                                          const Icon(CupertinoIcons.location_north_fill, 
                                                     size: 16, color: AppColors.accent),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 16),
                                    
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: const BoxDecoration(
                                              color: AppColors.accentDark,
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              staffName.substring(0, 1),
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
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          CupertinoButton(
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(32, 32),
                                            child: const Icon(CupertinoIcons.phone_fill, 
                                                              size: 18, color: AppColors.success),
                                            onPressed: () => _confirmPhoneCall(staffName),
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
                                                : AppColors.accent.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                              onPressed: () => _confirmNotifyStaff(branch.id),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    notified ? CupertinoIcons.bell_fill : CupertinoIcons.bell,
                                                    size: 14,
                                                    color: notified ? AppColors.textSecondary : AppColors.accent,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    notified ? 'Notified' : 'On the way',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: notified ? AppColors.textSecondary : AppColors.accent,
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
                                              color: AppColors.accent,
                                              borderRadius: BorderRadius.circular(12),
                                              onPressed: () => _confirmMarkCompleted(branch.id),
                                              child: Text(
                                                _activeMode == RouteMode.deployment ? 'Dropped Off' : 'Picked Up',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: CupertinoColors.white,
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
