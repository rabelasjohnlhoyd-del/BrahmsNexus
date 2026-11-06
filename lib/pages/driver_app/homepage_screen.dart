import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar, SnackBarAction, Icons;
import '../../services/driver_ble_service.dart';
import '../../models/branch.dart';
import '../../models/branch_assignment.dart';
import '../../models/branch_meat_inventory.dart';
import '../../models/staff_member.dart';
import '../../services/assignment_service.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/supabase_service.dart';
import '../../services/weather_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_pagination_bar.dart';
import '../../widgets/driver_card.dart';
import '../../widgets/driver_nav_bar.dart';
import '../../widgets/driver_section_header.dart';
import '../../widgets/driver_stat_tile.dart';
import '../../widgets/driver_top_actions.dart';

/// Homepage tab of the Driver app — shows ALL branches and which staff
/// is assigned to each one today.
class DriverHomepageScreen extends StatefulWidget {
  const DriverHomepageScreen({super.key});

  @override
  State<DriverHomepageScreen> createState() => _DriverHomepageScreenState();
}

class _DriverHomepageScreenState extends State<DriverHomepageScreen> {
  int _branchesPage = 0;
  static const int _pageSize = 5;
  bool _isRefreshing = false;
  bool _isCelsius = true;

  List<StaffMember> _allStaff = [];
  List<Branch> _allBranches = [];
  StreamSubscription<List<BranchMeatStock>>? _meatStocksSub;
  final Map<String, bool> _branchClosedMap = {};

  // Live weather state
  int _tempC = 28;
  int _humidity = 81;
  double _windSpeed = 12.5;
  int _feelsLikeC = 30;
  String _condition = 'Partly Cloudy';
  IconData _weatherIcon = CupertinoIcons.cloud_sun_fill;
  String _liveLocation = '';
  Timer? _weatherTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    AssignmentService.changeNotifier.addListener(_onAssignmentsChanged);
    _startWeatherTimer();
    _meatStocksSub = FirestoreService.watchBranchMeatStocks().listen((stocks) {
      if (mounted) {
        setState(() {
          _branchClosedMap.clear();
          for (final s in stocks) {
            final canonId = AttendanceService.normalizeBranchId(s.branchId, s.branchName);
            _branchClosedMap[canonId] = s.isClosed;
            _branchClosedMap[s.branchId.toLowerCase()] = s.isClosed;
            _branchClosedMap[s.branchName.trim().toLowerCase()] = s.isClosed;
          }
        });
      }
    });
  }

  bool _isBranchClosed(Branch branch) {
    final canonId = AttendanceService.normalizeBranchId(branch.id, branch.name);
    if (_branchClosedMap[canonId] == true) return true;
    if (_branchClosedMap[branch.id.toLowerCase()] == true) return true;
    final fullName = branch.fullName.trim().toLowerCase();
    if (_branchClosedMap[fullName] == true) return true;
    final name = branch.name.trim().toLowerCase();
    if (_branchClosedMap[name] == true) return true;
    return false;
  }

  @override
  void dispose() {
    AssignmentService.changeNotifier.removeListener(_onAssignmentsChanged);
    _weatherTimer?.cancel();
    _meatStocksSub?.cancel();
    super.dispose();
  }

  void _loadInitialData() async {
    // Immediate sync load
    _allBranches = SupabaseService.getAllBranchesSync();
    _allStaff = SupabaseService.getAllStaff();
    if (mounted) setState(() {});

    // Remote refresh
    try {
      final branches = await SupabaseService.getBranches();
      await SupabaseService.refreshStaffFromRemote();
      await AssignmentService.ensureInitialized();
      if (mounted) {
        setState(() {
          _allBranches = branches;
          _allStaff = SupabaseService.getAllStaff();
        });
      }
    } catch (_) {}
  }

  void _onAssignmentsChanged() {
    if (mounted) {
      setState(() {
        _allStaff = SupabaseService.getAllStaff();
      });
    }
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

  /// Helper to find who is assigned to a branch today based on AssignmentService.
  String? _getStaffForBranch(Branch branch) {
    final branchCanonId = AttendanceService.normalizeBranchId(branch.id, branch.name);
    final bNameLower = branch.name.toLowerCase().trim();
    final bFullNameLower = branch.fullName.toLowerCase().trim();

    for (final s in _allStaff) {
      if (s.isArchived || !s.isActive) continue;

      final status = AssignmentService.getWorkStatus(
        s.username,
        fallback: AssignmentService.getWorkStatus(
          s.id,
          fallback: s.isRestDay ? WorkStatus.restDay : WorkStatus.onDuty,
        ),
      );

      if (status == WorkStatus.restDay) continue;

      final assignedBranch = AssignmentService.getAssignedBranch(
        s.username,
        fallback: AssignmentService.getAssignedBranch(s.id, fallback: s.branch),
      ).trim();
      final abLower = assignedBranch.toLowerCase();
      final staffCanonId = AttendanceService.normalizeBranchId(
        abLower.isNotEmpty ? abLower : s.branch,
        s.fullName,
      );

      if (staffCanonId == branchCanonId && staffCanonId.isNotEmpty && staffCanonId != 'unassigned') {
        return s.fullName;
      }

      if (abLower.isNotEmpty) {
        if (abLower == bFullNameLower ||
            abLower == bNameLower ||
            bFullNameLower.contains(abLower) ||
            abLower.contains(bNameLower)) {
          return s.fullName;
        }
      }

      final origBranchLower = s.branch.toLowerCase().trim();
      if (origBranchLower.isNotEmpty && origBranchLower != 'n/a' && origBranchLower != 'unassigned') {
        if (origBranchLower == bFullNameLower ||
            origBranchLower == bNameLower ||
            bFullNameLower.contains(origBranchLower) ||
            origBranchLower.contains(bNameLower)) {
          return s.fullName;
        }
      }
    }
    return null;
  }

  int get _staffedBranchesCount {
    int count = 0;
    for (final b in _allBranches) {
      if (_getStaffForBranch(b) != null) {
        count++;
      }
    }
    return count;
  }

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const List<String> _weekdays = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  String _greetingPrefix() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formattedTime() {
    final now = DateTime.now();
    final day = _weekdays[now.weekday % 7];
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$day $hour:$minute $period';
  }

  Widget _rfidReaderBadge() {
    return ValueListenableBuilder<bool>(
      valueListenable: DriverBleService().isConnectedNotifier,
      builder: (context, isConnected, _) {
        return ValueListenableBuilder<String>(
          valueListenable: DriverBleService().statusNotifier,
          builder: (context, status, _) {
            final isConnecting = status.contains('Connecting');
            final bgColor = isConnected
                ? const Color(0xFFE8F5E9)
                : (isConnecting ? const Color(0xFFE3F2FD) : const Color(0xFFFFF3E0));
            final borderColor = isConnected
                ? const Color(0xFF81C784)
                : (isConnecting ? const Color(0xFF90CAF9) : const Color(0xFFFFB74D));
            final textColor = isConnected
                ? const Color(0xFF2E7D32)
                : (isConnecting ? const Color(0xFF1565C0) : const Color(0xFFE65100));

            return GestureDetector(
              onTap: () async {
                if (!isConnected) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const CupertinoActivityIndicator(radius: 8),
                          const SizedBox(width: 12),
                          const Text('Kumokonekta sa Brahms_Driver_Reader...'),
                        ],
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  final res = await DriverBleService().manualReconnect();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  if (res == 'Connected') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: CupertinoColors.white, size: 20),
                            const SizedBox(width: 10),
                            const Text('Connected sa RFID Reader!'),
                          ],
                        ),
                        backgroundColor: const Color(0xFF2E7D32),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  } else if (res.contains('Permission')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Kailangan ang Nearby Devices permission! I-allow sa Settings.',
                        ),
                        backgroundColor: const Color(0xFFC62828),
                        duration: const Duration(seconds: 6),
                        action: SnackBarAction(
                          label: 'SETTINGS',
                          textColor: CupertinoColors.white,
                          onPressed: () => DriverBleService().openSettings(),
                        ),
                      ),
                    );
                  } else if (res.contains('Pair')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Reader not paired! Pumunta sa Phone Settings > Bluetooth at i-pair ang "Brahms_Driver_Reader".',
                        ),
                        backgroundColor: Color(0xFFE65100),
                        duration: Duration(seconds: 5),
                      ),
                    );
                  } else if (res.contains('Bluetooth Disabled')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Naka-off ang Bluetooth ng cellphone. Pakibukas ito.'),
                        backgroundColor: Color(0xFFC62828),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Status: $res (I-check kung bukas ang ESP32 reader)'),
                        backgroundColor: const Color(0xFFC62828),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      isConnected ? CupertinoIcons.bluetooth : CupertinoIcons.bluetooth,
                      size: 16,
                      color: textColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isConnected
                            ? 'RFID Reader: Connected'
                            : (status.isNotEmpty && status != 'Disconnected'
                                ? 'RFID: $status'
                                : 'RFID Reader: Disconnected'),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isConnecting)
                      const CupertinoActivityIndicator(radius: 7)
                    else
                      Text(
                        isConnected ? 'Ready for Taps' : 'Tap to Reconnect',
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor,
                          fontWeight: isConnected ? FontWeight.normal : FontWeight.w600,
                          decoration: isConnected ? TextDecoration.none : TextDecoration.underline,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  Widget _weatherWidget() {
    final displayTemp = _convertTemp(_tempC);
    final feelsLike = _convertTemp(_feelsLikeC);
    final unitLabel = _isCelsius ? '°C' : '°F';
    final windUnit = _isCelsius ? 'km/h' : 'mph';
    final displayWind =
        _isCelsius ? _windSpeed : (_windSpeed * 0.621371).roundToDouble();

    return DriverCard(
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
                            : 'San Francisco, Victoria',
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

  Widget _dateChip() {
    final now = DateTime.now();
    final label = '${_months[now.month - 1]} ${now.day}, ${now.year}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.pastelBrown.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.calendar,
              size: 12, color: AppColors.accentDark),
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
    final totalBranches = _allBranches.length;
    final openBranchesCount = _allBranches.where((b) => !_isBranchClosed(b)).length;
    final staffedBranches = _staffedBranchesCount;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const DriverNavBar(
        title: 'Home',
        trailing: DriverTopActions(),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _rfidReaderBadge(),
            _weatherWidget(),
            const SizedBox(height: 20),
            DriverSectionHeader(
              label: "Today at a Glance",
              icon: CupertinoIcons.speedometer,
              trailing: _dateChip(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DriverDisplayTile(
                    icon: CupertinoIcons.building_2_fill,
                    label: 'Total Branches',
                    value: '$openBranchesCount/$totalBranches',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DriverDisplayTile(
                    icon: CupertinoIcons.person_2_fill,
                    label: 'Staff Assigned',
                    value: '$staffedBranches/$totalBranches',
                    dark: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const DriverSectionHeader(
              label: "Total Branches",
              icon: CupertinoIcons.list_bullet,
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final total = _allBranches.length;
                final totalPages = (total / _pageSize).ceil();
                final effectivePage = totalPages == 0 ? 0 : _branchesPage.clamp(0, totalPages - 1);
                final pagedBranches = _allBranches.skip(effectivePage * _pageSize).take(_pageSize).toList();

                return Column(
                  children: [
                    for (final branch in pagedBranches) ...[
                      Builder(
                        builder: (context) {
                          final isClosed = _isBranchClosed(branch);
                          final staffName = _getStaffForBranch(branch);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: DriverCard(
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isClosed
                                          ? const Color(0xFFDC2626).withValues(alpha: 0.12)
                                          : AppColors.pastelBrown.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isClosed
                                          ? CupertinoIcons.lock_fill
                                          : CupertinoIcons.building_2_fill,
                                      color: isClosed
                                          ? const Color(0xFFDC2626)
                                          : AppColors.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          branch.fullName,
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(
                                              isClosed
                                                  ? CupertinoIcons.lock_fill
                                                  : (staffName != null
                                                      ? CupertinoIcons.person_fill
                                                      : CupertinoIcons.person),
                                              size: 13,
                                              color: isClosed
                                                  ? const Color(0xFFDC2626)
                                                  : (staffName != null
                                                      ? AppColors.success
                                                      : AppColors.textSecondary),
                                            ),
                                            const SizedBox(width: 5),
                                            Expanded(
                                              child: Text(
                                                isClosed
                                                    ? 'Branch closed by owner'
                                                    : (staffName ?? 'No staff assigned yet'),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: isClosed ? FontWeight.w600 : FontWeight.normal,
                                                  color: isClosed
                                                      ? const Color(0xFFDC2626)
                                                      : (staffName != null
                                                          ? AppColors.textSecondary
                                                          : AppColors.warning),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isClosed) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            CupertinoIcons.lock_fill,
                                            size: 10,
                                            color: Color(0xFFDC2626),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'CLOSED',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFDC2626),
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    AppPaginationBar(
                      currentPage: effectivePage,
                      totalItems: total,
                      pageSize: _pageSize,
                      onPageChanged: (page) => setState(() => _branchesPage = page),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
