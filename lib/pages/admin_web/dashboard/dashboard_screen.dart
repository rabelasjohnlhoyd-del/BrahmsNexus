import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/bilao_order.dart';
import '../../../models/branch.dart';
import '../../../models/branch_assignment.dart';
import '../../../models/sales_record.dart';
import '../../../models/staff_member.dart';
import '../../../services/assignment_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/supabase_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import '../admin_web_widgets/kpi_card.dart';
import '../admin_web_widgets/smooth_area_chart.dart';

/// Admin Web Dashboard — Executive Operations & Analytics View.
/// Layout:
/// - Desktop (>= 950px):
///   - Left Column (68%):
///     - Top: Today's Revenue card (occupying the former "My Card" position)
///     - Middle: 2 cards — Today's Orders & Bilao Orders
///     - Bottom: Graph card (Weekly Order Analytics with toggle button to view Sales & Distribution Breakdown)
///   - Right Column (32%):
///     - Top: Active Staff card (occupying the former Transactions position)
///     - Bottom: Available Branches card
/// - Mobile / Phone (< 950px):
///   - Clean vertical stack: Today's Revenue, 2x2 grid (Orders, Bilao, Staff, Branches),
///     followed by the toggleable Analytics Graph card.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onLogout});

  final VoidCallback? onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription<List<SalesRecord>>? _salesSub;
  StreamSubscription<List<BilaoOrder>>? _bilaoOrdersSub;

  List<SalesRecord> _salesRecords = [];
  List<BilaoOrder> _bilaoOrders = [];
  List<StaffMember> _allStaff = [];

  // Toggle between 0: Weekly Order Analytics, 1: Sales & Distribution Breakdown
  int _activeChartIndex = 0;

  @override
  void initState() {
    super.initState();
    _updateShellActions();
    _loadInitialStaff();
    _subscribeRealtime();
    AssignmentService.changeNotifier.addListener(_onAssignmentsChanged);
  }

  @override
  void dispose() {
    AssignmentService.changeNotifier.removeListener(_onAssignmentsChanged);
    _salesSub?.cancel();
    _bilaoOrdersSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([]);
  }

  void _loadInitialStaff() {
    _allStaff = SupabaseService.getAllStaff();
  }

  void _onAssignmentsChanged() {
    if (mounted) {
      setState(() {
        _allStaff = SupabaseService.getAllStaff();
      });
    }
  }

  void _subscribeRealtime() {
    _salesSub = FirestoreService.watchRecentSales(limit: 50).listen((records) {
      if (mounted) setState(() => _salesRecords = records);
    });

    _bilaoOrdersSub = FirestoreService.watchAllBilaoOrders().listen((orders) {
      if (mounted) setState(() => _bilaoOrders = orders);
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formattedToday() {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  WorkStatus _getStaffStatus(StaffMember staff) {
    return AssignmentService.getWorkStatus(
      staff.username,
      fallback: AssignmentService.getWorkStatus(
        staff.id,
        fallback: staff.isRestDay ? WorkStatus.restDay : WorkStatus.onDuty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStr = _formattedToday();

    // ── 1. Calculate Today's Sales Metrics ────────────────────────────────────
    final todaySales = _salesRecords.where((r) => _isSameDay(r.date, now)).toList();
    final double todayRevenue = todaySales.fold(0.0, (sum, r) => sum + r.totalSalesAmount);
    final int todayOrders = todaySales.fold(0, (sum, r) => sum + r.displayTotalOrders);
    final int todayPortions = todaySales.fold(0, (sum, r) => sum + r.displayPortions);

    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdaySales = _salesRecords.where((r) => _isSameDay(r.date, yesterday)).toList();
    final double yesterdayRevenue = yesterdaySales.fold(0.0, (sum, r) => sum + r.totalSalesAmount);

    String revenueSubtitle = '';
    if (todaySales.isNotEmpty) {
      if (yesterdayRevenue > 0) {
        final diff = ((todayRevenue - yesterdayRevenue) / yesterdayRevenue) * 100;
        final sign = diff >= 0 ? '+' : '';
        revenueSubtitle = '$sign${diff.toStringAsFixed(0)}% vs yesterday';
      } else {
        revenueSubtitle = '${todaySales.length} of 6 branches submitted';
      }
    }

    // ── 2. Staff Deployment Counts ───────────────────────────────────────────
    final branchCooks = _allStaff.where((s) => s.position == 'Branch Cook' || s.position == 'Floating Cook').toList();
    int activeStaffCount = 0;
    int restDayCount = 0;
    for (final s in branchCooks) {
      final status = _getStaffStatus(s);
      if (status == WorkStatus.onDuty) {
        activeStaffCount++;
      } else {
        restDayCount++;
      }
    }

    // ── 3. Bilao Orders Metrics ──────────────────────────────────────────────
    final activeBilaoOrders = _bilaoOrders.where((b) {
      return b.deliveryStatus != DeliveryStatus.completed;
    }).toList();
    final bilaoTodayCount = _bilaoOrders.where((b) => _isSameDay(b.scheduledDateTime, now)).length;

    // ── 4. 7-Day Trend Chart Calculations ────────────────────────────────────
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final labels = <String>[];
    final orderSeriesValues = <num>[];
    final bilaoSeriesValues = <num>[];
    double total7dRevenue = 0.0;
    int total7dOrders = 0;
    int total7dBilao = 0;

    for (int i = 6; i >= 0; i--) {
      final targetDate = now.subtract(Duration(days: i));
      labels.add(dayNames[targetDate.weekday - 1]);

      final daySales = _salesRecords.where((r) => _isSameDay(r.date, targetDate)).toList();
      final dayOrderCount = daySales.fold<int>(0, (sum, r) => sum + r.displayTotalOrders);
      final dayRev = daySales.fold<double>(0.0, (sum, r) => sum + r.totalSalesAmount);
      orderSeriesValues.add(dayOrderCount);
      total7dRevenue += dayRev;
      total7dOrders += dayOrderCount;

      final dayBilao = _bilaoOrders.where((b) => _isSameDay(b.scheduledDateTime, targetDate)).toList();
      final dayBilaoCount = dayBilao.fold<int>(0, (sum, b) => sum + b.quantity);
      bilaoSeriesValues.add(dayBilaoCount);
      total7dBilao += dayBilaoCount;
    }

    final effectiveAvgValue = total7dOrders > 0 ? (total7dRevenue / total7dOrders) : 0.0;
    final int combinedTotal = total7dOrders + total7dBilao;
    final String channelShare = combinedTotal > 0
        ? '${((total7dOrders / combinedTotal) * 100).toStringAsFixed(0)}% Store'
        : '100% Store';

    String ordersSubtitle = '';
    if (todayOrders > 0) {
      ordersSubtitle = '$todayPortions meat portions';
    } else if (yesterdaySales.isNotEmpty) {
      final yOrders = yesterdaySales.fold<int>(0, (s, r) => s + r.displayTotalOrders);
      ordersSubtitle = '$yOrders orders yesterday';
    }

    return Container(
      color: AdminWebColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 950;
          final isMedium = constraints.maxWidth >= 600;

          if (isDesktop) {
            return _buildDesktopLayout(
              todayStr: todayStr,
              todayRevenue: todayRevenue,
              revenueSubtitle: revenueSubtitle,
              todayOrders: todayOrders,
              ordersSubtitle: ordersSubtitle,
              activeStaffCount: activeStaffCount,
              restDayCount: restDayCount,
              activeBilaoOrders: activeBilaoOrders,
              bilaoTodayCount: bilaoTodayCount,
              effectiveAvgValue: effectiveAvgValue,
              total7dOrders: total7dOrders,
              total7dBilao: total7dBilao,
              channelShare: channelShare,
              labels: labels,
              orderSeriesValues: orderSeriesValues,
              bilaoSeriesValues: bilaoSeriesValues,
            );
          } else {
            return _buildMobileLayout(
              isMedium: isMedium,
              todayStr: todayStr,
              todayRevenue: todayRevenue,
              revenueSubtitle: revenueSubtitle,
              todayOrders: todayOrders,
              ordersSubtitle: ordersSubtitle,
              activeStaffCount: activeStaffCount,
              restDayCount: restDayCount,
              activeBilaoOrders: activeBilaoOrders,
              bilaoTodayCount: bilaoTodayCount,
              effectiveAvgValue: effectiveAvgValue,
              total7dOrders: total7dOrders,
              total7dBilao: total7dBilao,
              channelShare: channelShare,
              labels: labels,
              orderSeriesValues: orderSeriesValues,
              bilaoSeriesValues: bilaoSeriesValues,
            );
          }
        },
      ),
    );
  }

  // ===========================================================================
  // DESKTOP LAYOUT (Exact User Specified Arrangement)
  // ===========================================================================
  Widget _buildDesktopLayout({
    required String todayStr,
    required double todayRevenue,
    required String revenueSubtitle,
    required int todayOrders,
    required String ordersSubtitle,
    required int activeStaffCount,
    required int restDayCount,
    required List<BilaoOrder> activeBilaoOrders,
    required int bilaoTodayCount,
    required double effectiveAvgValue,
    required int total7dOrders,
    required int total7dBilao,
    required String channelShare,
    required List<String> labels,
    required List<num> orderSeriesValues,
    required List<num> bilaoSeriesValues,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── LEFT COLUMN (68% Width) ───────────────────────────────────────
          Expanded(
            flex: 68,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. In place of "My Card": Today's Revenue Card (Original Content & Brahms Styling)
                _buildTodayRevenueHeroCard(
                  todayStr: todayStr,
                  todayRevenue: todayRevenue,
                  revenueSubtitle: revenueSubtitle,
                  orderSeriesValues: orderSeriesValues,
                ),
                const SizedBox(height: 18),

                // 2. Below it: 2 Cards — Today's Orders & Bilao Orders
                Row(
                  children: [
                    Expanded(
                      child: KpiCard(
                        icon: Icons.storefront_rounded,
                        label: "Today's Orders",
                        value: '$todayOrders',
                        subtitle: ordersSubtitle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: KpiCard(
                        icon: Icons.shopping_bag_outlined,
                        label: 'Bilao Orders',
                        value: '${activeBilaoOrders.length}',
                        subtitle: '',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 3. In place of "Money Flow": Toggleable Analytics Chart Card
                // Shows Weekly Order Analytics by default, toggles to Sales & Distribution Breakdown
                _buildToggleableAnalyticsCard(
                  labels: labels,
                  orderSeriesValues: orderSeriesValues,
                  bilaoSeriesValues: bilaoSeriesValues,
                  effectiveAvgValue: effectiveAvgValue,
                  total7dOrders: total7dOrders,
                  total7dBilao: total7dBilao,
                  activeStaffCount: activeStaffCount,
                  channelShare: channelShare,
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // ── RIGHT COLUMN (32% Width) ──────────────────────────────────────
          Expanded(
            flex: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. In place of "Transactions": Active Staff Card (Original Content & Quick View)
                _buildActiveStaffSideCard(
                  activeStaffCount: activeStaffCount,
                  restDayCount: restDayCount,
                  branchCooks: _allStaff
                      .where((s) => s.position == 'Branch Cook' || s.position == 'Floating Cook')
                      .toList(),
                ),
                const SizedBox(height: 18),

                // 2. Available Branches Card
                _buildAvailableBranchesCard(
                  activeStaffCount: activeStaffCount,
                  restDayCount: restDayCount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MOBILE / PHONE LAYOUT
  // ===========================================================================
  Widget _buildMobileLayout({
    required bool isMedium,
    required String todayStr,
    required double todayRevenue,
    required String revenueSubtitle,
    required int todayOrders,
    required String ordersSubtitle,
    required int activeStaffCount,
    required int restDayCount,
    required List<BilaoOrder> activeBilaoOrders,
    required int bilaoTodayCount,
    required double effectiveAvgValue,
    required int total7dOrders,
    required int total7dBilao,
    required String channelShare,
    required List<String> labels,
    required List<num> orderSeriesValues,
    required List<num> bilaoSeriesValues,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMedium ? 20 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Today's Revenue Card
          _buildTodayRevenueHeroCard(
            todayStr: todayStr,
            todayRevenue: todayRevenue,
            revenueSubtitle: revenueSubtitle,
            orderSeriesValues: orderSeriesValues,
            isMobile: true,
          ),
          const SizedBox(height: 14),

          // 2. 2 Cards Row: Today's Orders & Bilao Orders
          Row(
            children: [
              Expanded(
                child: KpiCard(
                  icon: Icons.storefront_rounded,
                  label: "Today's Orders",
                  value: '$todayOrders',
                  subtitle: ordersSubtitle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KpiCard(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Bilao Orders',
                  value: '${activeBilaoOrders.length}',
                  subtitle: '',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Active Staff Card
          _buildActiveStaffSideCard(
            activeStaffCount: activeStaffCount,
            restDayCount: restDayCount,
            branchCooks: _allStaff
                .where((s) => s.position == 'Branch Cook' || s.position == 'Floating Cook')
                .toList(),
            isMobile: true,
          ),
          const SizedBox(height: 14),

          // 4. Toggleable Analytics Chart (Weekly Order Analytics <-> Sales & Distribution Breakdown)
          _buildToggleableAnalyticsCard(
            labels: labels,
            orderSeriesValues: orderSeriesValues,
            bilaoSeriesValues: bilaoSeriesValues,
            effectiveAvgValue: effectiveAvgValue,
            total7dOrders: total7dOrders,
            total7dBilao: total7dBilao,
            activeStaffCount: activeStaffCount,
            channelShare: channelShare,
            isMobile: true,
          ),
          const SizedBox(height: 14),

          // 5. Available Branches Card
          _buildAvailableBranchesCard(
            activeStaffCount: activeStaffCount,
            restDayCount: restDayCount,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUB-COMPONENTS (100% Original Content & Brahms Styling)
  // ===========================================================================

  /// 1. Replaces "My Card": Today's Revenue Hero Card
  Widget _buildTodayRevenueHeroCard({
    required String todayStr,
    required double todayRevenue,
    required String revenueSubtitle,
    required List<num> orderSeriesValues,
    bool isMobile = false,
  }) {
    return GlassCard(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 22, vertical: isMobile ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AdminWebColors.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.payments_outlined, size: 22, color: AdminWebColors.accent),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "TODAY'S REVENUE",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AdminWebColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(
                width: 60,
                height: 28,
                child: CustomPaint(painter: _HeroTrendPainter()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '₱${todayRevenue.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: isMobile ? 32 : 38,
                    fontWeight: FontWeight.w900,
                    color: AdminWebColors.textPrimary,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  revenueSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: revenueSubtitle.contains('+')
                        ? AdminWebColors.success
                        : AdminWebColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. In place of "Money Flow": Toggleable Analytics Chart Card
  Widget _buildToggleableAnalyticsCard({
    required List<String> labels,
    required List<num> orderSeriesValues,
    required List<num> bilaoSeriesValues,
    required double effectiveAvgValue,
    required int total7dOrders,
    required int total7dBilao,
    required int activeStaffCount,
    required String channelShare,
    bool isMobile = false,
  }) {
    final isWeeklyView = _activeChartIndex == 0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Title & Toggle Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AdminWebColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isWeeklyView ? Icons.bar_chart_rounded : Icons.show_chart_rounded,
                      size: 20,
                      color: AdminWebColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isWeeklyView ? 'Weekly Order Analytics' : 'Sales & Distribution Breakdown',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: isMobile ? 14 : 16,
                      color: AdminWebColors.textPrimary,
                    ),
                  ),
                ],
              ),

              // Interactive Toggle Button on the Right Side
              InkWell(
                onTap: () {
                  setState(() {
                    _activeChartIndex = _activeChartIndex == 0 ? 1 : 0;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AdminWebColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminWebColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_horiz_rounded,
                        size: 16,
                        color: AdminWebColors.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isWeeklyView ? 'View Sales & Distribution' : 'View Weekly Analytics',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AdminWebColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Key Stats Row
          if (isWeeklyView)
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _StatBlock(value: '₱${effectiveAvgValue.toStringAsFixed(0)}', label: 'Avg. per order'),
                _StatBlock(value: '$total7dOrders', label: 'Orders (7d)'),
                _StatBlock(value: '$activeStaffCount/6 Branches', label: 'Staff Deployed'),
              ],
            )
          else
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _StatBlock(value: '$total7dOrders', label: 'Store Orders (7d)'),
                _StatBlock(value: '$total7dBilao', label: 'Bilao Orders (7d)'),
                _StatBlock(value: channelShare, label: 'Channel Share'),
              ],
            ),
          const SizedBox(height: 14),

          // Legend
          if (isWeeklyView)
            const Row(
              children: [
                _LegendDot(
                  color: AdminWebColors.chartBarPrimary,
                  label: 'Store Sisig Orders',
                ),
              ],
            )
          else
            const Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _LegendDot(
                  color: AdminWebColors.chartBarPrimary,
                  label: 'Store Sisig Orders',
                ),
                _LegendDot(
                  color: AdminWebColors.chartBarSecondary,
                  label: 'Advance Bilao Orders',
                ),
              ],
            ),
          const SizedBox(height: 14),

          // Dynamic Spline Area Chart
          SmoothAreaChart(
            labels: labels,
            height: isMobile ? 180 : 220,
            series: isWeeklyView
                ? [
                    AreaSeries(
                      name: 'Store Sisig Orders',
                      values: orderSeriesValues,
                      color: AdminWebColors.chartBarPrimary,
                      unit: 'orders',
                    ),
                  ]
                : [
                    AreaSeries(
                      name: 'Store Sisig Orders',
                      values: orderSeriesValues,
                      color: AdminWebColors.chartBarPrimary,
                      unit: 'orders',
                    ),
                    AreaSeries(
                      name: 'Advance Bilao Orders',
                      values: bilaoSeriesValues,
                      color: AdminWebColors.chartBarSecondary,
                      unit: 'packages',
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  /// 3. In place of "Transactions": Active Staff Card (Original Content + Cook Breakdown)
  Widget _buildActiveStaffSideCard({
    required int activeStaffCount,
    required int restDayCount,
    required List<StaffMember> branchCooks,
    bool isMobile = false,
  }) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AdminWebColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.groups_rounded, size: 20, color: AdminWebColors.accent),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Active Staff',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AdminWebColors.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: 44,
                height: 22,
                child: CustomPaint(painter: _HeroTrendPainter()),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$activeStaffCount',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: AdminWebColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Scrollable Cook Roster (All staff viewable)
          if (branchCooks.isEmpty)
            const Text(
              'No cooks registered.',
              style: TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
            )
          else
            SizedBox(
              height: 180,
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: branchCooks.length,
                  itemBuilder: (context, index) {
                    final cook = branchCooks[index];
                    final status = _getStaffStatus(cook);
                    final isOnDuty = status == WorkStatus.onDuty;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.5, horizontal: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isOnDuty ? AdminWebColors.success : AdminWebColors.textSecondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cook.fullName,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AdminWebColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            isOnDuty ? 'On Duty' : 'Rest Day',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isOnDuty ? AdminWebColors.success : AdminWebColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 4. Available Branches Card
  Widget _buildAvailableBranchesCard({
    required int activeStaffCount,
    required int restDayCount,
  }) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AdminWebColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_rounded, size: 20, color: AdminWebColors.accent),
              ),
              const SizedBox(width: 12),
              const Text(
                'Available Branches',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AdminWebColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _branchTile(
            title: '6 Branches Active',
            subtitle: 'Main Commissary Station',
            tag: 'CENTRAL',
            icon: Icons.storefront_rounded,
          ),
          const SizedBox(height: 10),
          _branchTile(
            title: '$activeStaffCount Cooks Deployed',
            subtitle: '$restDayCount rest day today',
            tag: 'ACTIVE',
            icon: Icons.groups_rounded,
          ),
        ],
      ),
    );
  }

  Widget _branchTile({
    required String title,
    required String subtitle,
    required String tag,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminWebColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AdminWebColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AdminWebColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AdminWebColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AdminWebColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AdminWebColors.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AdminWebColors.border),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AdminWebColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: AdminWebColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AdminWebColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AdminWebColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _HeroTrendPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AdminWebColors.accent.withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(0, size.height * 0.85)
      ..cubicTo(
        size.width * 0.25, size.height * 0.9,
        size.width * 0.35, size.height * 0.35,
        size.width * 0.55, size.height * 0.5,
      )
      ..cubicTo(
        size.width * 0.7, size.height * 0.6,
        size.width * 0.8, size.height * 0.05,
        size.width, 0,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeroTrendPainter oldDelegate) => false;
}
