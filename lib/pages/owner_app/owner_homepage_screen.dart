import 'package:flutter/cupertino.dart';
import '../../models/branch_assignment.dart';
import '../../models/daily_report.dart';
import '../../models/inventory_item.dart';
import '../../models/sales_record.dart';
import '../../theme/app_theme.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/owner_sales_trend_chart.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';
import '../../widgets/staff_top_actions.dart';

/// Homepage tab of the Owner app — an at-a-glance overview of today's
/// operations across all branches: interactive weather, staff on duty,
/// low-stock alerts, today's sales, and pending reports.
///
/// Styled to match the Staff and Driver app design system.
class OwnerHomepageScreen extends StatefulWidget {
  const OwnerHomepageScreen({super.key});

  @override
  State<OwnerHomepageScreen> createState() => _OwnerHomepageScreenState();
}

class _OwnerHomepageScreenState extends State<OwnerHomepageScreen> {
  bool _isRefreshing = false;
  bool _isCelsius = true;

  // Mock data for functional simulation
  int _tempC = 28;
  int _humidity = 81;
  double _windSpeed = 12.5;
  int _feelsLikeC = 30;

  Widget _kpiTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return StaffCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _refreshWeather() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _tempC = 27 + (DateTime.now().second % 3);
        _humidity = 80 + (DateTime.now().second % 5);
        _windSpeed = 10.0 + (DateTime.now().second % 10);
        _feelsLikeC = _tempC + 2;
      });
    }
  }

  void _toggleUnit() {
    setState(() => _isCelsius = !_isCelsius);
  }

  int _convertTemp(int celsius) {
    return _isCelsius ? celsius : ((celsius * 9 / 5) + 32).round();
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
    if (hour < 12) return 'Good Morning,';
    if (hour < 18) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  String _formattedTime() {
    final now = DateTime.now();
    final day = _weekdays[now.weekday % 7];
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$day $hour:$minute $period';
  }

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                  const Text(
                    'San Francisco, Victoria',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
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
              const Icon(CupertinoIcons.cloud_fill,
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
                  const Text(
                    'Cloudy',
                    style: TextStyle(
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
              _weatherInfoItem(CupertinoIcons.thermometer, 'Feels like',
                  '$feelsLike$unitLabel'),
              _weatherInfoItem(
                  CupertinoIcons.drop, 'Humidity', '$_humidity%'),
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
        borderRadius: BorderRadius.circular(12),
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

  // Mock data
  static final List<BranchAssignment> _assignments = [
    BranchAssignment(
      id: 'a1',
      employeeId: 'emp1',
      employeeName: 'Juan Dela Cruz',
      branchId: 'br1',
      branchName: 'Brgy. Gatid, Sta. Cruz',
      date: DateTime.now(),
      workStatus: WorkStatus.onDuty,
    ),
    BranchAssignment(
      id: 'a2',
      employeeId: 'emp2',
      employeeName: 'Maria Reyes',
      branchId: 'br3',
      branchName: 'Brgy. Sta. Clara Sur, Pila',
      date: DateTime.now(),
      workStatus: WorkStatus.onDuty,
    ),
    BranchAssignment(
      id: 'a3',
      employeeId: 'emp3',
      employeeName: 'Pedro Santos',
      branchId: 'br2',
      branchName: 'Brgy. Labuin, Pila',
      date: DateTime.now(),
      workStatus: WorkStatus.restDay,
    ),
  ];

  static final List<BranchStock> _branchStocks = [
    BranchStock(
      branchId: 'br6',
      branchName: 'Brgy. Dayap, Calauan',
      date: DateTime.now(),
      allocatedKg: 20,
      remainingKg: 14,
    ),
    BranchStock(
      branchId: 'br1',
      branchName: 'Brgy. Gatid, Sta. Cruz',
      date: DateTime.now(),
      allocatedKg: 25,
      remainingKg: 3,
    ),
    BranchStock(
      branchId: 'br2',
      branchName: 'Brgy. Labuin, Pila',
      date: DateTime.now(),
      allocatedKg: 15,
      remainingKg: 1,
    ),
  ];

  static final List<SalesRecord> _salesRecords = [
    SalesRecord(
      id: 's1',
      branchId: 'br1',
      branchName: 'Brgy. Gatid, Sta. Cruz',
      employeeId: 'emp1',
      employeeName: 'Juan Dela Cruz',
      date: DateTime.now(),
      portionsSold: 42,
      commissionRatePerPortion: 5,
      totalSalesAmount: 4200,
    ),
    SalesRecord(
      id: 's2',
      branchId: 'br2',
      branchName: 'Brgy. Labuin, Pila',
      employeeId: 'emp2',
      employeeName: 'Maria Reyes',
      date: DateTime.now(),
      portionsSold: 35,
      commissionRatePerPortion: 5,
      totalSalesAmount: 3500,
    ),
  ];

  static final List<DailyReport> _reports = [
    DailyReport(
      id: 'r1',
      employeeId: 'emp1',
      employeeName: 'Juan Dela Cruz',
      branchId: 'br1',
      branchName: 'Brgy. Gatid, Sta. Cruz',
      date: DateTime.now(),
      content: 'Kumpleto ang benta ngayong araw, walang isyu sa stock.',
      status: ReportSubmissionStatus.submitted,
    ),
    DailyReport(
      id: 'r2',
      employeeId: 'emp2',
      employeeName: 'Maria Reyes',
      branchId: 'br3',
      branchName: 'Brgy. Sta. Clara Sur, Pila',
      date: DateTime.now(),
      content: '',
      status: ReportSubmissionStatus.missing,
    ),
  ];

  int get _onDutyCount =>
      _assignments.where((a) => a.workStatus == WorkStatus.onDuty).length;

  int get _lowStockCount => _branchStocks.where((s) => s.isRunningLow).length;

  double get _todaysSales =>
      _salesRecords.fold(0, (sum, r) => sum + r.totalSalesAmount);

  int get _pendingReportsCount => _reports
      .where((r) => r.status != ReportSubmissionStatus.submitted)
      .length;

  void _shareSummary() {
    final summary =
        "Brahms Nexus - Today's Summary (${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year})\n\n"
        "💰 Total Sales: ₱${_todaysSales.toStringAsFixed(0)}\n"
        "👨‍🍳 On Duty: $_onDutyCount/${_assignments.length}\n"
        "📦 Low Stock Branches: $_lowStockCount\n"
        "📝 Pending Reports: $_pendingReportsCount\n\n"
        "Keep up the good work!";
    SharePlus.instance.share(ShareParams(text: summary));
  }

  @override
  Widget build(BuildContext context) {
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
            // GREETING
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greetingPrefix(),
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Owner',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                ],
              ),
            ),
            // WEATHER WIDGET
            _weatherWidget(),
            const SizedBox(height: 20),

            // TODAY'S OVERVIEW
            StaffSectionHeader(
              label: "Today's Overview",
              icon: CupertinoIcons.speedometer,
              trailing: _dateChip(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _kpiTile(
                    icon: CupertinoIcons.person_2_fill,
                    label: 'On Duty',
                    value: '$_onDutyCount/${_assignments.length}',
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _kpiTile(
                    icon: CupertinoIcons.exclamationmark_triangle_fill,
                    label: 'Low Stock',
                    value: '$_lowStockCount',
                    color: _lowStockCount > 0 ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _kpiTile(
                    icon: CupertinoIcons.money_dollar_circle_fill,
                    label: "Today's Sales",
                    value: '₱${_todaysSales.toStringAsFixed(0)}',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _kpiTile(
                    icon: CupertinoIcons.doc_text_fill,
                    label: 'Pending',
                    value: '$_pendingReportsCount',
                    color: _pendingReportsCount > 0 ? AppColors.warning : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StaffButton(
              label: "Share Today's Summary",
              icon: CupertinoIcons.share,
              onPressed: _shareSummary,
            ),
            const SizedBox(height: 24),

            // SALES TREND
            const StaffSectionHeader(
              label: "Sales Trend",
              icon: CupertinoIcons.graph_square_fill,
            ),
            const SizedBox(height: 12),
            const StaffCard(
              child: OwnerSalesTrendChart(),
            ),
            const SizedBox(height: 24),

            // TOP PERFORMERS
            const StaffSectionHeader(
              label: 'Top Performers',
              icon: CupertinoIcons.star_fill,
            ),
            const SizedBox(height: 12),
            StaffCard(
              child: Column(
                children: [
                  for (final r in (_salesRecords..sort((a, b) => b.portionsSold.compareTo(a.portionsSold))).take(3)) ...[
                    _TopPerformerRow(
                      name: r.employeeName,
                      branch: r.branchName,
                      portions: r.portionsSold,
                    ),
                    if (r != _salesRecords.last)
                      Container(
                        height: 1,
                        color: AppColors.border,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TopPerformerRow extends StatelessWidget {
  const _TopPerformerRow({
    required this.name,
    required this.branch,
    required this.portions,
  });

  final String name;
  final String branch;
  final int portions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
          child: Text(
            name.substring(0, 1),
            style: const TextStyle(
              color: CupertinoColors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                branch,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$portions',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.accent,
              ),
            ),
            const Text(
              'portions',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
