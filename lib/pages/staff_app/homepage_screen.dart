import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../../models/branch.dart';
import '../../models/branch_assignment.dart';
import '../../models/branch_daily_inventory.dart';
import '../../models/branch_meat_inventory.dart';
import '../../models/staff_member.dart';
import '../../services/assignment_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_stat_tile.dart';
import '../../widgets/staff_top_actions.dart';
import '../../services/weather_service.dart';

/// Homepage tab of the Cook/Staff app:
/// 1. Shows which branch Owner assigned them to today.
/// 2. Shows the inventory (Karne/Mayo/Styro/Toyo) Owner says was sent —
///    this is the "allocated" amount that needs to be verified.
/// 3. Cook counts what they actually received and enters it here.
/// 4. If it matches -> only Confirm is enabled. If it doesn't match
///    (too much or too little) -> only Deny is enabled, then they type
///    a message to Owner about the shortfall. NON-BLOCKING: they can
///    still continue to the Sales tab even while the status is
///    "Discrepancy Reported" — Owner handles sending extra stock.
/// 5. Also shows other cooks assigned to other branches today.
class HomepageScreen extends StatefulWidget {
  const HomepageScreen({super.key});

  @override
  State<HomepageScreen> createState() => _HomepageScreenState();
}

class _HomepageScreenState extends State<HomepageScreen> with WidgetsBindingObserver {
  bool _isRefreshing = false;
  bool _isCelsius = true;

  // Live weather state
  int _tempC = 28;
  int _humidity = 81;
  double _windSpeed = 12.5;
  int _feelsLikeC = 30;
  String _condition = 'Partly Cloudy';
  IconData _weatherIcon = CupertinoIcons.cloud_sun_fill;
  String _liveLocation = '';
  Timer? _weatherTimer;

  String _greetingPrefix() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _startWeatherTimer() {
    _fetchLiveWeather();
    _weatherTimer?.cancel();
    _weatherTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchLiveWeather();
    });
  }

  Future<void> _fetchLiveWeather({bool force = false}) async {
    final live = await WeatherService.fetchWeather(force: force);
    if (!mounted) return;
    setState(() {
      _tempC = live.tempC.round();
      _feelsLikeC = live.feelsLikeC.round();
      _humidity = live.humidity;
      _windSpeed = live.windSpeedKmH;
      _condition = live.condition;
      _weatherIcon = live.icon;
      _liveLocation = live.location;
      _isRefreshing = false;
    });
  }

  void _refreshWeather() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await _fetchLiveWeather(force: true);
  }

  void _toggleUnit() {
    setState(() => _isCelsius = !_isCelsius);
  }

  int _convertTemp(int celsius) {
    return _isCelsius ? celsius : ((celsius * 9 / 5) + 32).round();
  }

  String _formattedTime() {
    final now = DateTime.now();
    final day = _weekdays[now.weekday % 7];
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$day $hour:$minute $period';
  }

  static const List<String> _weekdays = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  Widget _weatherWidget() {
    final displayTemp = _convertTemp(_tempC);
    final feelsLike = _convertTemp(_feelsLikeC);
    final unitLabel = _isCelsius ? '°C' : '°F';
    final windUnit = _isCelsius ? 'km/h' : 'mph';
    final displayWind =
        _isCelsius ? _windSpeed : (_windSpeed * 0.621371).roundToDouble();

    return StaffCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Greeting ─────────────────────────────────────────
          Text(
            '${_greetingPrefix()}, ${AuthService.currentUsername}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          // ── Location row ──────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4285F4),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _liveLocation.isNotEmpty
                            ? _liveLocation
                            : (_inventory.branchName.isNotEmpty
                                ? _inventory.branchName
                                : 'San Francisco, Victoria'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _refreshWeather,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Update',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _isRefreshing
                          ? const CupertinoActivityIndicator(radius: 5)
                          : const Icon(CupertinoIcons.refresh,
                              size: 10, color: AppColors.accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(_weatherIcon,
                  size: 48, color: AppColors.pastelBrown),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _toggleUnit,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$displayTemp',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textPrimary,
                          letterSpacing: -2,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 2),
                        child: Text(
                          unitLabel,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _condition,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    _formattedTime(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _weatherInfoItem(
                  CupertinoIcons.thermometer, 'Feels like', '$feelsLike$unitLabel'),
              _weatherInfoItem(CupertinoIcons.drop, 'Humidity', '$_humidity%'),
              _weatherInfoItem(CupertinoIcons.wind, 'Wind',
                  '${displayWind.toStringAsFixed(1)} $windUnit'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weatherInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.accent.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary)),
            Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ],
        ),
      ],
    );
  }

  BranchDailyInventory _inventory = BranchDailyInventory(
    branchId: 'br1',
    branchName: 'Brgy. Gatid, Sta. Cruz',
    date: DateTime.now(),
    allocated: const InventoryCounts(karne: 40, mayo: 40, styro: 40, toyo: 10),
  );

  BranchMeatStock? _branchMeatStock;
  StreamSubscription<BranchDailyInventory?>? _inventorySub;
  StreamSubscription<List<BranchMeatStock>>? _meatStocksSub;
  String _currentBranchId = 'br1';

  final _karneController = TextEditingController();
  final _mayoController = TextEditingController();
  final _styroController = TextEditingController();
  final _toyoController = TextEditingController();
  final _mediumController = TextEditingController();
  final _b1t1Controller = TextEditingController();
  final _discrepancyController = TextEditingController();

  List<Map<String, dynamic>> _getCoworkersToday() {
    final allStaff = SupabaseService.getAllStaff();
    final branchCooks = allStaff.where((s) => s.position == 'Branch Cook' || s.position == 'Floating Cook').toList();

    final currentUsername = AuthService.currentUsername.trim().toLowerCase();
    final currentUid = AuthService.currentUserId.trim().toLowerCase();
    final currentFullName = AuthService.currentUser?.fullName.trim().toLowerCase() ?? '';

    final List<Map<String, dynamic>> list = [];

    for (final s in branchCooks) {
      final sUsername = s.username.trim().toLowerCase();
      final sId = s.id.trim().toLowerCase();
      final sCleanId = sId.replaceAll('-', '');

      // Check real-time work status
      final status = s.username.isNotEmpty
          ? AssignmentService.getWorkStatus(s.username,
              fallback: AssignmentService.getWorkStatus(s.id, fallback: s.isRestDay ? WorkStatus.restDay : WorkStatus.onDuty))
          : AssignmentService.getWorkStatus(s.id, fallback: s.isRestDay ? WorkStatus.restDay : WorkStatus.onDuty);

      // Only show cooks who are ON DUTY today
      if (status != WorkStatus.onDuty) continue;

      final branchName = s.username.isNotEmpty
          ? AssignmentService.getAssignedBranch(s.username,
              fallback: AssignmentService.getAssignedBranch(s.id, fallback: s.branch))
          : AssignmentService.getAssignedBranch(s.id, fallback: s.branch);

      final isSelf = (currentUsername.isNotEmpty && sUsername == currentUsername) ||
          (currentUid.isNotEmpty && (sId == currentUid || sCleanId == currentUid)) ||
          (currentFullName.isNotEmpty && s.fullName.trim().toLowerCase() == currentFullName);

      list.add({
        'name': s.fullName,
        'branch': (branchName.isNotEmpty && branchName != 'N/A') ? branchName : 'Pending Assignment',
        'isSelf': isSelf,
        'initials': s.initials,
      });
    }

    // Sort: Self first, then alphabetical by branch name
    list.sort((a, b) {
      if (a['isSelf'] == true) return -1;
      if (b['isSelf'] == true) return 1;
      return (a['branch'] as String).compareTo(b['branch'] as String);
    });

    return list;
  }

  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AssignmentService.ensureInitialized();
    _setupBranchAndStreams();
    _scheduleMidnightRefresh();
    _startWeatherTimer();
    AssignmentService.changeNotifier.addListener(_onAssignmentChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (!_isSameDay(_inventory.date, now)) {
        _setupBranchAndStreams();
        _scheduleMidnightRefresh();
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    // 12:00:01 AM tomorrow
    final tomorrowMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);
    final delay = tomorrowMidnight.difference(now);
    _midnightTimer = Timer(delay, () {
      if (mounted) {
        _setupBranchAndStreams();
        _scheduleMidnightRefresh();
      }
    });
  }

  void _onAssignmentChanged() {
    if (mounted) {
      _setupBranchAndStreams();
      setState(() {});
    }
  }

  void _setupBranchAndStreams() {
    final username = AuthService.currentUsername;
    final currentUid = AuthService.currentUserId;

    var assignedBranchName = AssignmentService.getAssignedBranch(username);
    if (assignedBranchName.isEmpty && currentUid.isNotEmpty) {
      assignedBranchName = AssignmentService.getAssignedBranch(currentUid);
    }
    if (assignedBranchName.isEmpty) {
      final allStaff = SupabaseService.getAllStaff();
      final match = allStaff.firstWhere(
        (s) => s.username.toLowerCase() == username.toLowerCase() ||
               s.id == currentUid ||
               s.id.replaceAll('-', '') == currentUid.replaceAll('-', ''),
        orElse: () => StaffMember(id: '', firstName: '', lastName: '', username: '', branch: '', position: ''),
      );
      if (match.branch.isNotEmpty && match.branch != 'N/A') {
        assignedBranchName = match.branch;
      }
    }

    Branch? matchedBranch;
    if (assignedBranchName.isNotEmpty) {
      for (final b in kSampleBranches) {
        if (b.fullName.toLowerCase().contains(assignedBranchName.toLowerCase()) ||
            b.name.toLowerCase().contains(assignedBranchName.toLowerCase()) ||
            assignedBranchName.toLowerCase().contains(b.name.toLowerCase())) {
          matchedBranch = b;
          break;
        }
      }
    }
    matchedBranch ??= kSampleBranches.first;
    _currentBranchId = matchedBranch.id;

    final today = DateTime.now();

    _inventory = _inventory.copyWith(
      branchId: matchedBranch.id,
      branchName: matchedBranch.fullName,
      date: today,
    );

    _inventorySub?.cancel();
    _inventorySub = FirestoreService.watchTodayBranchInventory(
      branchId: matchedBranch.id,
      branchName: matchedBranch.fullName,
      date: today,
    ).listen((inv) {
      if (!mounted) return;
      if (inv != null) {
        setState(() {
          _inventory = inv;
          if (inv.status != InventoryVerificationStatus.pending && inv.actualReceived != null) {
            final ar = inv.actualReceived!;
            _karneController.text = '${ar.regular}';
            _mediumController.text = '${ar.medium}';
            _b1t1Controller.text = '${ar.b1t1}';
            _mayoController.text = '${ar.mayo}';
            _styroController.text = '${ar.styro}';
            _toyoController.text = '${ar.toyo}';
          }
        });
      } else {
        // Bagong araw na (12:00 AM) o wala pang record para sa araw na ito:
        // Automatic na nagre-reset sa Pending baseline at nililinis ang inputs!
        setState(() {
          _inventory = BranchDailyInventory(
            branchId: matchedBranch!.id,
            branchName: matchedBranch.fullName,
            date: today,
            allocated: const InventoryCounts(karne: 40, mayo: 40, styro: 40, toyo: 10),
            status: InventoryVerificationStatus.pending,
          );
          _karneController.clear();
          _mediumController.clear();
          _b1t1Controller.clear();
          _mayoController.clear();
          _styroController.clear();
          _toyoController.clear();
        });
      }
    });

    _meatStocksSub?.cancel();
    _meatStocksSub = FirestoreService.watchBranchMeatStocks().listen((stocks) {
      if (mounted) {
        final match = stocks.firstWhere(
          (s) => s.branchId == _currentBranchId,
          orElse: () => BranchMeatStock.defaultForBranch(matchedBranch!),
        );
        setState(() {
          _branchMeatStock = match;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    _weatherTimer?.cancel();
    AssignmentService.changeNotifier.removeListener(_onAssignmentChanged);
    _inventorySub?.cancel();
    _meatStocksSub?.cancel();
    _karneController.dispose();
    _mayoController.dispose();
    _styroController.dispose();
    _toyoController.dispose();
    _mediumController.dispose();
    _b1t1Controller.dispose();
    _discrepancyController.dispose();
    super.dispose();
  }

  bool get _hasEnteredCount =>
      _karneController.text.isNotEmpty &&
      _mediumController.text.isNotEmpty &&
      _b1t1Controller.text.isNotEmpty &&
      _mayoController.text.isNotEmpty &&
      _styroController.text.isNotEmpty &&
      _toyoController.text.isNotEmpty;

  bool get _countsMatch {
    if (!_hasEnteredCount) return false;
    final a = _inventory.allocated;
    final regTarget = _branchMeatStock?.regular250gRemaining ?? 20;
    final medTarget = _branchMeatStock?.medium300gRemaining ?? 10;
    final b1t1Target = _branchMeatStock?.b1t1_400gRemaining ?? 10;

    final regEntered = int.tryParse(_karneController.text) ?? -1;
    final medEntered = int.tryParse(_mediumController.text) ?? -1;
    final b1t1Entered = int.tryParse(_b1t1Controller.text) ?? -1;
    final mayoEntered = int.tryParse(_mayoController.text) ?? -1;
    final styroEntered = int.tryParse(_styroController.text) ?? -1;
    final toyoEntered = int.tryParse(_toyoController.text) ?? -1;

    return regEntered == regTarget &&
        medEntered == medTarget &&
        b1t1Entered == b1t1Target &&
        mayoEntered == a.mayo &&
        styroEntered == a.styro &&
        toyoEntered == a.toyo;
  }

  void _confirm() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Confirm Inventory'),
        content: const Text('Sigurado ka bang tugma ang lahat ng counts na natanggap mo para sa araw na ito?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final updated = _inventory.copyWith(
                date: DateTime.now(),
                status: InventoryVerificationStatus.confirmed,
                actualReceived: ActualReceivedCounts(
                  mayo: int.tryParse(_mayoController.text) ?? 0,
                  toyo: int.tryParse(_toyoController.text) ?? 0,
                  styro: int.tryParse(_styroController.text) ?? 0,
                  regular: int.tryParse(_karneController.text) ?? 0,
                  medium: int.tryParse(_mediumController.text) ?? 0,
                  b1t1: int.tryParse(_b1t1Controller.text) ?? 0,
                ),
                verifiedBy: AuthService.currentUsername,
                verifiedAt: DateTime.now(),
              );
              setState(() {
                _inventory = updated;
              });
              final ok = await FirestoreService.saveDailyInventory(updated);
              if (ok) {
                _showToast('Inventory confirmed & synced!');
              } else {
                _showToast('Inventory confirmed locally.');
              }
            },
            child: const Text('Yes, Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDenyDialog() async {
    _discrepancyController.clear();
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text("Discrepancy Report"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text(
              "Pakilagay kung ano ang kulang o sobra sa natanggap mong stock.",
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            CupertinoTextField(
              controller: _discrepancyController,
              placeholder: 'e.g., short on meat...',
              maxLines: 3,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              placeholderStyle: const TextStyle(color: AppColors.textSecondary),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final updated = _inventory.copyWith(
                date: DateTime.now(),
                status: InventoryVerificationStatus.discrepancyReported,
                discrepancyNote: _discrepancyController.text.trim(),
                actualReceived: ActualReceivedCounts(
                  mayo: int.tryParse(_mayoController.text) ?? 0,
                  toyo: int.tryParse(_toyoController.text) ?? 0,
                  styro: int.tryParse(_styroController.text) ?? 0,
                  regular: int.tryParse(_karneController.text) ?? 0,
                  medium: int.tryParse(_mediumController.text) ?? 0,
                  b1t1: int.tryParse(_b1t1Controller.text) ?? 0,
                ),
                verifiedBy: AuthService.currentUsername,
                verifiedAt: DateTime.now(),
              );
              setState(() {
                _inventory = updated;
              });
              final ok = await FirestoreService.saveDailyInventory(updated);
              if (ok) {
                _showToast('Report sent to Owner & synced!');
              } else {
                _showToast('Report recorded locally.');
              }
            },
            child: const Text('Send to Owner'),
          ),
        ],
      ),
    );
  }

  void _showToast(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(InventoryVerificationStatus status) {
    switch (status) {
      case InventoryVerificationStatus.pending:
        return AppColors.warning;
      case InventoryVerificationStatus.confirmed:
        return AppColors.success;
      case InventoryVerificationStatus.discrepancyReported:
        return AppColors.error;
    }
  }

  IconData _statusIcon(InventoryVerificationStatus status) {
    switch (status) {
      case InventoryVerificationStatus.pending:
        return CupertinoIcons.clock_fill;
      case InventoryVerificationStatus.confirmed:
        return CupertinoIcons.check_mark_circled_solid;
      case InventoryVerificationStatus.discrepancyReported:
        return CupertinoIcons.exclamationmark_circle_fill;
    }
  }

  String _statusSubtitle(InventoryVerificationStatus status) {
    switch (status) {
      case InventoryVerificationStatus.pending:
        return 'Enter all four counts above, then confirm or report a mismatch.';
      case InventoryVerificationStatus.confirmed:
        return 'Your count matches what Owner sent — you\'re good to go.';
      case InventoryVerificationStatus.discrepancyReported:
        final note = _inventory.discrepancyNote;
        return (note != null && note.isNotEmpty)
            ? 'Sent to Owner: "$note"'
            : 'Owner has been notified. You can still continue to Sales.';
    }
  }

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  Widget _dateChip() {
    final now = DateTime.now();
    final label = '${_months[now.month - 1]} ${now.day}, ${now.year}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.pastelBrown.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.calendar, size: 12, color: AppColors.accentDark),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.accentDark,
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final a = _inventory.allocated;
    final status = _inventory.status;
    final statusColor = _statusColor(status);
    final isVerified = status != InventoryVerificationStatus.pending;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Home',
        trailing: StaffTopActions(),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _weatherWidget(),
            const SizedBox(height: 20),
            // Branch indicator pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentDark.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.location_solid,
                      size: 18, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _inventory.branchName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Allocated inventory — 2x2 grid
            StaffSectionHeader(
              label: "Today's Allocated Inventory",
              icon: CupertinoIcons.cube_box_fill,
              subtitle: 'Quick overview of your assigned items',
              large: true,
              trailing: _dateChip(),
            ),
            const SizedBox(height: 14),
            // Horizontally swipeable inventory grid
            // Row 1: Mayo → Toyo → Medium (300g)
            // Row 2: Styro → Regular (250g) → B1T1 (400g)
            LayoutBuilder(
              builder: (ctx, constraints) {
                final cardW = (constraints.maxWidth - 12) / 2;
                final reg = _branchMeatStock?.regular250gRemaining ?? 20;
                final med = _branchMeatStock?.medium300gRemaining ?? 10;
                final b1t1 = _branchMeatStock?.b1t1_400gRemaining ?? 10;
                Widget dtile(String label, String value, {bool dark = false}) =>
                    SizedBox(width: cardW, child: StaffDisplayTile(label: label, value: value, dark: dark));
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const PageScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        dtile('Mayo', '${a.mayo}', dark: true),
                        const SizedBox(width: 12),
                        dtile('Toyo', '${a.toyo}', dark: true),
                        const SizedBox(width: 12),
                        dtile('Medium', '$med pcs'),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        dtile('Styro', '${a.styro}'),
                        const SizedBox(width: 12),
                        dtile('Regular', '$reg pcs'),
                        const SizedBox(width: 12),
                        dtile('B1T1', '$b1t1 pcs'),
                      ]),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 26),

            // Recount — swipeable input grid
            // Page 1: Mayo | Toyo (top) / Styro | — (bottom)
            // Swipe left: Regular | Medium (top) / B1T1 | — (bottom)
            StaffSectionHeader(
              label: isVerified
                  ? 'Verified: Actually Received Counts'
                  : 'Verify: Count What You Actually Received',
              icon: isVerified
                  ? CupertinoIcons.lock_shield_fill
                  : CupertinoIcons.checkmark_seal_fill,
              subtitle: isVerified
                  ? 'Nai-record na ang mga bilang para sa araw na ito (Locked)'
                  : 'Enter the actual count of items you received',
              large: true,
              trailing: isVerified
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.lock_fill, size: 11, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            status.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (ctx, constraints) {
                final cardW = (constraints.maxWidth - 12) / 2;
                Widget itile(String label, TextEditingController ctrl) => SizedBox(
                  width: cardW,
                  child: StaffInputTile(
                    label: label,
                    controller: ctrl,
                    enabled: !isVerified,
                    onChanged: () => setState(() {}),
                  ),
                );
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const PageScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        itile('Mayo', _mayoController),
                        const SizedBox(width: 12),
                        itile('Toyo', _toyoController),
                        const SizedBox(width: 12),
                        itile('Medium', _mediumController),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        itile('Styro', _styroController),
                        const SizedBox(width: 12),
                        itile('Regular', _karneController),
                        const SizedBox(width: 12),
                        itile('B1T1', _b1t1Controller),
                      ]),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Status banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_statusIcon(status), size: 18, color: statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _statusSubtitle(status),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // DYNAMIC CONFIRM/DENY BUTTON
            if (_hasEnteredCount && status == InventoryVerificationStatus.pending)
              SizedBox(
                width: double.infinity,
                child: _countsMatch
                    ? StaffButton(
                        label: 'Confirm Inventory',
                        icon: CupertinoIcons.checkmark_alt,
                        color: AppColors.success,
                        onPressed: _confirm,
                      )
                    : StaffButton(
                        label: 'Report Discrepancy (Deny)',
                        icon: CupertinoIcons.xmark,
                        color: AppColors.error,
                        onPressed: _showDenyDialog,
                      ),
              ),
            if (!_hasEnteredCount && status == InventoryVerificationStatus.pending)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Note: Pakilagay ang lahat ng counts para lumabas ang verification button.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 26),

            // Co-workers Section
            Builder(
              builder: (context) {
                final coworkers = _getCoworkersToday();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StaffSectionHeader(
                      label: 'Coworkers Today',
                      icon: CupertinoIcons.person_2_fill,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${coworkers.length} On Duty',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (coworkers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: StaffCard(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'Walang ibang cook na naka-duty ngayon.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      ...coworkers.map(
                        (c) {
                          final isSelf = c['isSelf'] == true;
                          final branch = c['branch'] as String;
                          final name = c['name'] as String;
                          final initials = c['initials'] as String? ?? '?';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: StaffCard(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelf
                                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                          : AppColors.pastelBrown.withValues(alpha: 0.25),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelf
                                            ? const Color(0xFFA7F3D0)
                                            : AppColors.pastelBrown.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      initials,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isSelf ? const Color(0xFF047857) : AppColors.accentDark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            name,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelf ? FontWeight.w700 : FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (isSelf) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'IKAW',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF047857),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isSelf
                                          ? const Color(0xFFECFDF5)
                                          : AppColors.pastelBrown.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelf
                                            ? const Color(0xFFA7F3D0)
                                            : CupertinoColors.transparent,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.location_solid,
                                          size: 11,
                                          color: isSelf ? const Color(0xFF047857) : AppColors.accentDark,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          branch,
                                          style: TextStyle(
                                            color: isSelf ? const Color(0xFF047857) : AppColors.accentDark,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
