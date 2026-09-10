import 'package:flutter/material.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import '../admin_web_widgets/kpi_card.dart';
import '../admin_web_widgets/simple_bar_chart.dart';

/// Admin Web dashboard — glassmorphism redesign following standard page layout.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onLogout});

  final VoidCallback? onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _updateShellActions();
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([]); // Clear header actions as requested
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
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final today = _formattedToday();

    return Container(
      color: AdminWebColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final isMedium = constraints.maxWidth >= 600;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WelcomeBanner(today: today),
                const SizedBox(height: 24),
                _KpiGrid(crossAxisCount: isWide ? 5 : (isMedium ? 3 : 1)),
                const SizedBox(height: 24),
                isWide
                    ? const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _OrderDetailsCard()),
                          SizedBox(width: 20),
                          Expanded(child: _SalesReportCard()),
                        ],
                      )
                    : const Column(
                        children: [
                          _OrderDetailsCard(),
                          SizedBox(height: 20),
                          _SalesReportCard(),
                        ],
                      ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.today});

  final String today;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AdminWebColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wb_sunny_rounded, size: 24, color: AdminWebColors.accent),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Welcome back, Admin',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AdminWebColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Today is $today. All systems are operational.",
                  style: const TextStyle(
                    fontSize: 13,
                    color: AdminWebColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.crossAxisCount});

  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    const cards = [
      KpiCard(
        icon: Icons.payments_outlined,
        label: "Today's Revenue",
        value: '₱18,240',
        subtitle: '+15% vs yesterday',
      ),
      KpiCard(
        icon: Icons.shopping_bag_outlined,
        label: "Today's Orders",
        value: '128',
        subtitle: '+8% vs yesterday',
      ),
      KpiCard(
        icon: Icons.receipt_long_outlined,
        label: 'Total Orders (30d)',
        value: '3,482',
        subtitle: '+12% (30 days)',
      ),
      KpiCard(
        icon: Icons.store_outlined,
        label: 'Active Staff',
        value: '24',
        subtitle: 'across 6 branches',
      ),
      KpiCard(
        icon: Icons.warning_amber_rounded,
        label: 'Low Stock Alerts',
        value: '3',
        subtitle: 'needs attention',
      ),
    ];

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      childAspectRatio: crossAxisCount == 5 ? 1.2 : (crossAxisCount == 1 ? 2.6 : 1.5),
      children: cards,
    );
  }
}

class _OrderDetailsCard extends StatelessWidget {
  const _OrderDetailsCard();

  @override
  Widget build(BuildContext context) {
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bar_chart_rounded,
                    size: 20, color: AdminWebColors.accent),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Order Analytics',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AdminWebColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Weekly order volume distribution across all channels.',
            style: TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              _StatBlock(value: '₱642', label: 'Avg. value'),
              SizedBox(width: 32),
              _StatBlock(value: '170', label: 'Orders (7d)'),
              SizedBox(width: 32),
              _StatBlock(value: '94%', label: 'Efficiency'),
            ],
          ),
          const SizedBox(height: 24),
          SimpleBarChart(
            labels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
            series: [
              BarSeries(
                values: const [90, 150, 70, 110, 60, 170, 95],
                color: AdminWebColors.chartBarPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalesReportCard extends StatelessWidget {
  const _SalesReportCard();

  @override
  Widget build(BuildContext context) {
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.show_chart_rounded,
                    size: 20, color: AdminWebColors.accent),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Sales Distribution',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AdminWebColors.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AdminWebColors.textSecondary),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Comparison of offline and online sales performance.',
            style: TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _LegendDot(color: AdminWebColors.chartBarPrimary, label: 'Store Sales'),
              const SizedBox(width: 20),
              _LegendDot(color: AdminWebColors.chartBarSecondary, label: 'Online Deliveries'),
            ],
          ),
          const SizedBox(height: 20),
          SimpleBarChart(
            labels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
            series: [
              BarSeries(
                values: const [60, 90, 55, 40, 75, 110, 85],
                color: AdminWebColors.chartBarPrimary,
              ),
              BarSeries(
                values: const [40, 60, 35, 55, 45, 130, 70],
                color: AdminWebColors.chartBarSecondary,
              ),
            ],
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
            fontSize: 18,
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

