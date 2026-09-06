import 'package:flutter/material.dart';
import '../admin_web_colors.dart';
import '../admin_web_widgets/glass_card.dart';
import '../admin_web_widgets/kpi_card.dart';
import '../admin_web_widgets/quick_link_card.dart';
import '../admin_web_widgets/simple_bar_chart.dart';

/// Admin Web dashboard — glassmorphism redesign per the 60-30-10 brief:
/// 60% white background, 30% pastel brown/beige surfaces, 10% warm
/// medium brown accent. Mock numbers for now — once Supabase/Firebase
/// are wired up, the KPIs and chart data come from real queries.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.onLogout});

  final VoidCallback? onLogout;

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
                _Header(today: today, isWide: isWide, onLogout: onLogout),
                const SizedBox(height: 20),
                _WelcomeBanner(today: today, isWide: isWide),
                const SizedBox(height: 20),
                _KpiGrid(crossAxisCount: isWide ? 4 : (isMedium ? 2 : 1)),
                const SizedBox(height: 20),
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
                const Text(
                  'Quick Links',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AdminWebColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _QuickLinksGrid(
                    crossAxisCount: isWide ? 4 : (isMedium ? 2 : 1)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.today, required this.isWide, this.onLogout});

  final String today;
  final bool isWide;
  final VoidCallback? onLogout;

  void _showNotifications(BuildContext context, Offset position) {
    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      color: AdminWebColors.surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AdminWebColors.border),
      ),
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 320),
      items: const [
        PopupMenuItem<void>(
          enabled: false,
          child: Text(
            'Notifications',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AdminWebColors.textPrimary,
            ),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem<void>(
          enabled: false,
          child: _NotificationRow(
            icon: Icons.warning_amber_rounded,
            title: 'Low stock alert',
            subtitle: '3 items need attention',
          ),
        ),
        PopupMenuItem<void>(
          enabled: false,
          child: _NotificationRow(
            icon: Icons.shopping_bag_outlined,
            title: "Today's orders",
            subtitle: '128 orders so far, +8% vs yesterday',
          ),
        ),
        PopupMenuItem<void>(
          enabled: false,
          child: _NotificationRow(
            icon: Icons.how_to_reg_rounded,
            title: 'Pending approval',
            subtitle: 'A new staff registration is awaiting review',
          ),
        ),
      ],
    );
  }

  void _showOwnerMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      color: AdminWebColors.surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AdminWebColors.border),
      ),
      items: const [
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded,
                  size: 18, color: AdminWebColors.error),
              SizedBox(width: 10),
              Text('Log out'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'logout') onLogout?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AdminWebColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "Here's an overview of your operations for $today.",
          style: const TextStyle(
            fontSize: 13,
            color: AdminWebColors.textSecondary,
          ),
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Builder(
          builder: (context) => InkWell(
            customBorder: const CircleBorder(),
            onTapDown: (details) =>
                _showNotifications(context, details.globalPosition),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AdminWebColors.surfaceTint,
                    shape: BoxShape.circle,
                    border: Border.all(color: AdminWebColors.border),
                  ),
                  child: const Icon(Icons.notifications_none_rounded,
                      size: 19, color: AdminWebColors.accent),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AdminWebColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Builder(
          builder: (context) => InkWell(
            borderRadius: BorderRadius.circular(20),
            onTapDown: (details) =>
                _showOwnerMenu(context, details.globalPosition),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AdminWebColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      'O',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Owner',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AdminWebColors.textPrimary,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AdminWebColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleBlock,
          const SizedBox(height: 12),
          actions,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleBlock),
        actions,
      ],
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.today, required this.isWide});

  final String today;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final greeting = Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AdminWebColors.accent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Text('☀️', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Welcome back, Owner 👋',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AdminWebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Here's an overview of your operations for $today.",
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AdminWebColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final salesBox = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminWebColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.trending_up_rounded,
                  size: 16, color: AdminWebColors.accent),
              const SizedBox(width: 6),
              const Text(
                '₱18,240',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AdminWebColors.accentDark,
                ),
              ),
            ],
          ),
          const Text(
            "Today's sales",
            style: TextStyle(
              fontSize: 11.5,
              color: AdminWebColors.textSecondary,
            ),
          ),
        ],
      ),
    );

    return GlassCard(
      borderRadius: 20,
      child: isWide
          ? Row(
              children: [
                Expanded(child: greeting),
                const SizedBox(width: 16),
                salesBox,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                greeting,
                const SizedBox(height: 16),
                salesBox,
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
    final cards = const [
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
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: crossAxisCount == 1 ? 2.6 : 1.5,
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
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AdminWebColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bar_chart_rounded,
                    size: 18, color: AdminWebColors.accent),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Order Details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AdminWebColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'A quick look at bilao order volume for the last 7 days.',
            style: TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              _StatBlock(value: '₱642', label: 'Avg. order value'),
              SizedBox(width: 24),
              _StatBlock(value: '170', label: 'Orders (7d)'),
              SizedBox(width: 24),
              _StatBlock(value: '94%', label: 'Fulfilled on time'),
            ],
          ),
          const SizedBox(height: 20),
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
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AdminWebColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.show_chart_rounded,
                    size: 18, color: AdminWebColors.accent),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Sales Report',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AdminWebColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Full sales report — coming once reporting is wired up.'),
                    ),
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View all',
                        style: TextStyle(color: AdminWebColors.accent)),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward_rounded,
                        size: 14, color: AdminWebColors.accent),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Offline vs. online orders across the branches this week.',
            style: TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _LegendDot(color: AdminWebColors.chartBarPrimary, label: 'Offline sales'),
              const SizedBox(width: 16),
              _LegendDot(color: AdminWebColors.chartBarSecondary, label: 'Online sales'),
            ],
          ),
          const SizedBox(height: 14),
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
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AdminWebColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
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
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AdminWebColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(top: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AdminWebColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 15, color: AdminWebColors.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AdminWebColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AdminWebColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickLinksGrid extends StatelessWidget {
  const _QuickLinksGrid({required this.crossAxisCount});

  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    void notReady(String feature) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$feature — coming soon.')),
      );
    }

    final links = [
      QuickLinkCard(
        icon: Icons.history_rounded,
        title: 'Order History',
        subtitle: 'View past orders',
        onTap: () => notReady('Order History'),
      ),
      QuickLinkCard(
        icon: Icons.search_rounded,
        title: 'Search Records',
        subtitle: 'Find specific data',
        onTap: () => notReady('Search Records'),
      ),
      QuickLinkCard(
        icon: Icons.description_outlined,
        title: 'Generate Reports',
        subtitle: 'Download reports',
        onTap: () => notReady('Generate Reports'),
      ),
      QuickLinkCard(
        icon: Icons.settings_outlined,
        title: 'System Settings',
        subtitle: 'Manage preferences',
        onTap: () => notReady('System Settings'),
      ),
    ];

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: crossAxisCount == 1 ? 3.2 : 2.6,
      children: links,
    );
  }
}
