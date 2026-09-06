import 'package:flutter/material.dart';
import '../../../theme/admin_theme.dart';

/// Landing page of Admin Web — a stats-at-a-glance overview (today's
/// orders, active staff, low-stock alerts), a lightweight sales
/// snapshot, and shortcuts to sections that don't have their own spot
/// in the sidebar (e.g. Order History, Search Records).
///
/// Visual layout follows the "Skydash"-style reference the Owner
/// provided: a greeting banner, four colored stat blocks, an order
/// summary card, and a weekly sales chart. Colors use [AdminColors]
/// (the indigo/violet Admin Web palette) rather than the warm-brown
/// [AppColors] used elsewhere, matching the rest of the Admin Web
/// chrome (see widgets/admin_page_header.dart, widgets/admin_top_bar.dart).
///
/// NOTE: The numbers on this page are sample/placeholder data — there
/// is no live Firestore query wired in yet. The layout is intentionally
/// built so a real stream from lib/models/sales_record.dart,
/// daily_report.dart, inventory_item.dart, etc. can be dropped in
/// later without changing the visual structure.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _WelcomeBanner(),
          SizedBox(height: 24),
          _StatGrid(),
          SizedBox(height: 24),
          _OverviewRow(),
          SizedBox(height: 24),
          _QuickLinksSection(),
        ],
      ),
    );
  }
}

/// Greeting + today's date on the left, a small "today's sales" pill
/// on the right — a functional stand-in for the reference design's
/// hero illustration/weather widget, sized to information that's
/// actually useful for this app.
class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();

  static const _weekdayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday', //
  ];
  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];

  String _formatToday() {
    final now = DateTime.now();
    final weekday = _weekdayNames[now.weekday - 1];
    final month = _monthNames[now.month - 1];
    return '$weekday, $month ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AdminColors.primary, AdminColors.primaryDark],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -12,
            top: -12,
            child: Icon(
              Icons.storefront_rounded,
              size: 110,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 480;

              final greeting = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Welcome back, Owner 👋',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Here's an overview of your operations for "
                    '${_formatToday()}.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13.5,
                    ),
                  ),
                ],
              );

              final pill = Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up_rounded, color: Colors.white),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₱18,240',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "Today's sales",
                          style: TextStyle(color: Colors.white70, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    greeting,
                    const SizedBox(height: 16),
                    pill,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: greeting),
                  const SizedBox(width: 16),
                  pill,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

enum _StatStyle { light, medium, dark, warning }

class _StatData {
  const _StatData({
    required this.label,
    required this.value,
    required this.caption,
    required this.style,
  });

  final String label;
  final String value;
  final String caption;
  final _StatStyle style;
}

/// Responsive 4-up (desktop) / 2-up (tablet) / 1-up (phone) grid of
/// colored stat blocks — the reference design's "Today's Bookings /
/// Total Bookings / Number of Meetings / Number of Clients" row,
/// re-mapped to metrics that actually matter for a bilao-order/staff
/// operation instead of a generic CRM template.
class _StatGrid extends StatelessWidget {
  const _StatGrid();

  static const _stats = [
    _StatData(
      label: "Today's Orders",
      value: '128',
      caption: '+8% vs yesterday',
      style: _StatStyle.light,
    ),
    _StatData(
      label: 'Total Orders (30d)',
      value: '3,482',
      caption: '+12% (30 days)',
      style: _StatStyle.dark,
    ),
    _StatData(
      label: 'Active Staff',
      value: '24',
      caption: 'across 6 branches',
      style: _StatStyle.medium,
    ),
    _StatData(
      label: 'Low Stock Alerts',
      value: '3',
      caption: 'needs attention',
      style: _StatStyle.warning,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900 ? 4 : (width >= 560 ? 2 : 1);
        const spacing = 16.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final stat in _stats)
              SizedBox(width: cardWidth, child: _StatCard(data: stat)),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatData data;

  @override
  Widget build(BuildContext context) {
    late final Color background;
    late final Color foreground;
    late final Color captionColor;

    switch (data.style) {
      case _StatStyle.light:
        background = AdminColors.primarySoft;
        foreground = AdminColors.primary;
        captionColor = AdminColors.textSecondary;
        break;
      case _StatStyle.medium:
        background = AdminColors.primaryMedium;
        foreground = Colors.white;
        captionColor = Colors.white70;
        break;
      case _StatStyle.dark:
        background = AdminColors.primaryDark;
        foreground = Colors.white;
        captionColor = Colors.white70;
        break;
      case _StatStyle.warning:
        background = AdminColors.error;
        foreground = Colors.white;
        captionColor = Colors.white70;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            data.label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: foreground.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.caption,
            style: TextStyle(fontSize: 11.5, color: captionColor),
          ),
        ],
      ),
    );
  }
}

/// Side-by-side (desktop) / stacked (narrow) pairing of the Order
/// Details summary and the Sales Report chart — mirrors the
/// reference's two-column "Order Details" + "Sales Report" row.
class _OverviewRow extends StatelessWidget {
  const _OverviewRow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 820;

        if (isWide) {
          return const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _OrderDetailsCard()),
              SizedBox(width: 20),
              Expanded(child: _SalesReportCard()),
            ],
          );
        }

        return const Column(
          children: [
            _OrderDetailsCard(),
            SizedBox(height: 20),
            _SalesReportCard(),
          ],
        );
      },
    );
  }
}

class _OrderDetailsCard extends StatelessWidget {
  const _OrderDetailsCard();

  static const _weeklyOrders = [18.0, 24.0, 15.0, 30.0, 22.0, 34.0, 27.0];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Details',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'A quick look at bilao order volume for the last 7 days.',
            style: TextStyle(fontSize: 12.5, color: AdminColors.textSecondary),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(
                child: _MiniStat(label: 'Avg. order value', value: '₱642'),
              ),
              Expanded(
                child: _MiniStat(label: 'Orders (7d)', value: '170'),
              ),
              Expanded(
                child: _MiniStat(label: 'Fulfilled on time', value: '94%'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SizedBox(
            height: 70,
            child: _MiniBarRow(
              values: _weeklyOrders,
              color: AdminColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AdminColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: AdminColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Simple bottom-aligned bar row used as a lightweight chart — avoids
/// pulling in a charting package (none is currently a dependency) for
/// what is, for now, a handful of static bars. Supports an optional
/// second series so it can be reused for both the single-series
/// "Order Details" sparkline and the two-series "Sales Report" chart.
class _MiniBarRow extends StatelessWidget {
  const _MiniBarRow({
    required this.values,
    required this.color,
    this.secondaryValues,
    this.secondaryColor,
  });

  final List<double> values;
  final Color color;
  final List<double>? secondaryValues;
  final Color? secondaryColor;

  @override
  Widget build(BuildContext context) {
    final maxVal = [
      ...values,
      ...?secondaryValues,
    ].reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal <= 0 ? 1.0 : maxVal;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: FractionallySizedBox(
                    alignment: Alignment.bottomCenter,
                    heightFactor:
                        (values[i] / safeMax).clamp(0.05, 1.0).toDouble(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                  ),
                ),
                if (secondaryValues != null) ...[
                  const SizedBox(width: 3),
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: Alignment.bottomCenter,
                      heightFactor: (secondaryValues![i] / safeMax)
                          .clamp(0.05, 1.0)
                          .toDouble(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: secondaryColor ?? color,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SalesReportCard extends StatelessWidget {
  const _SalesReportCard();

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _offline = [12.0, 18.0, 9.0, 15.0, 20.0, 26.0, 14.0];
  static const _online = [8.0, 14.0, 11.0, 19.0, 13.0, 22.0, 17.0];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sales Report',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sales & Payroll — see full report'),
                    ),
                  );
                },
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Offline vs. online orders across the branches this week.',
            style: TextStyle(fontSize: 12.5, color: AdminColors.textSecondary),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              _LegendDot(color: AdminColors.primary, label: 'Offline sales'),
              SizedBox(width: 16),
              _LegendDot(
                color: AdminColors.primaryMedium,
                label: 'Online sales',
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SizedBox(
            height: 140,
            child: _MiniBarRow(
              values: _offline,
              color: AdminColors.primary,
              secondaryValues: _online,
              secondaryColor: AdminColors.primaryMedium,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final day in _days)
                Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AdminColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
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
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
        ),
      ],
    );
  }
}

/// Shortcuts to sections that don't have their own spot in the
/// sidebar. Kept from the original dashboard so existing navigation
/// paths (e.g. from onboarding/help text) don't break.
class _QuickLinksSection extends StatelessWidget {
  const _QuickLinksSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Links',
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: AdminColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 480 ? 2 : 1;
            const spacing = 16.0;
            final cardWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _QuickLinkCard(
                    title: 'Order History',
                    subtitle: 'Completed bilao orders',
                    icon: Icons.history_rounded,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Order History — coming soon'),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _QuickLinkCard(
                    title: 'Search Records',
                    subtitle: 'Find orders, reports & more',
                    icon: Icons.search_rounded,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Search Records — coming soon'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Admin-palette equivalent of widgets/feature_card.dart's [FeatureCard]
/// — kept local to this page (rather than editing the shared widget)
/// so the mobile Driver/Staff apps, which also use [FeatureCard], keep
/// their existing warm-brown look untouched.
class _QuickLinkCard extends StatelessWidget {
  const _QuickLinkCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdminColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AdminColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AdminColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
