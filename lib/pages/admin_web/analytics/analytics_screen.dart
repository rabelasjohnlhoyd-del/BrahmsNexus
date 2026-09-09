import 'package:flutter/material.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import '../admin_web_widgets/simple_bar_chart.dart';

/// DSS Analytics — Descriptive, Predictive, and Prescriptive insights
/// built with consistent Admin Web glassmorphism components.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([
      ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Downloading full DSS report...')),
          );
        },
        icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
        label: const Text('EXPORT REPORT'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.15),
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          elevation: 0,
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminWebColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 900;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // --- 1. DESCRIPTIVE ANALYTICS ---
                _SectionHeader(
                  title: 'Descriptive Analytics',
                  subtitle: 'Historical patterns and current performance',
                  icon: Icons.history_rounded,
                ),
                const SizedBox(height: 16),
                if (isNarrow)
                  Column(
                    children: [
                      _buildSalesVolumeCard(),
                      const SizedBox(height: 20),
                      _buildBestSellingCard(),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildSalesVolumeCard()),
                      const SizedBox(width: 20),
                      Expanded(child: _buildBestSellingCard()),
                    ],
                  ),

                const SizedBox(height: 40),

                // --- 2. PREDICTIVE ANALYTICS ---
                _SectionHeader(
                  title: 'Predictive Analytics',
                  subtitle: 'Forecasting and future trends based on historical data',
                  icon: Icons.auto_graph_rounded,
                ),
                const SizedBox(height: 16),
                if (isNarrow)
                  Column(
                    children: [
                      _buildForecastCard(),
                      const SizedBox(height: 20),
                      _buildDepletionCard(),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildForecastCard()),
                      const SizedBox(width: 20),
                      Expanded(child: _buildDepletionCard()),
                    ],
                  ),

                const SizedBox(height: 40),

                // --- 3. PRESCRIPTIVE ANALYTICS ---
                _SectionHeader(
                  title: 'Prescriptive Analytics',
                  subtitle: 'Automated system recommendations and action items',
                  icon: Icons.lightbulb_outline_rounded,
                ),
                const SizedBox(height: 16),
                _RecommendationCard(
                  title: 'Inventory Optimization',
                  description:
                      'Stock at Sta. Cruz is depleting faster than usual. Consider transferring 15kg extra from Dayap surplus to avoid stockout.',
                  priority: 'High',
                  icon: Icons.inventory_2_rounded,
                ),
                const SizedBox(height: 12),
                _RecommendationCard(
                  title: 'Staffing Adjustment',
                  description:
                      'Orders peak between 11 AM - 1 PM on Saturdays. Consider assigning an additional cook to Pila branch next week.',
                  priority: 'Medium',
                  icon: Icons.people_alt_rounded,
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSalesVolumeCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales Volume by Branch (Last 7 Days)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AdminWebColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 28),
          const SimpleBarChart(
            labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
            series: [
              BarSeries(
                values: [120, 150, 180, 140, 210, 250, 230],
                color: AdminWebColors.chartBarPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBestSellingCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Best Selling Bilao',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AdminWebColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 20),
          _StatItem(
              label: 'Medium (₱950)',
              value: '45%',
              color: AdminWebColors.accent),
          _StatItem(
              label: 'Large (₱1300)',
              value: '32%',
              color: AdminWebColors.textSecondary),
          _StatItem(
              label: 'Small (₱750)',
              value: '23%',
              color: AdminWebColors.border),
        ],
      ),
    );
  }

  Widget _buildForecastCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Projected Sales Forecast',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AdminWebColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Based on moving-average projections, sales are expected to increase by 12% next weekend compared to the monthly average.',
            style: TextStyle(
                fontSize: 13.5,
                color: AdminWebColors.textSecondary,
                height: 1.5),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.75,
              backgroundColor: AdminWebColors.border.withValues(alpha: 0.3),
              color: AdminWebColors.success,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepletionCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inventory Depletion Rate',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AdminWebColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 20),
          _StatRow(
              label: 'Sta. Cruz',
              value: '2.5 days left',
              color: AdminWebColors.error),
          _StatRow(
              label: 'Dayap',
              value: '4.0 days left',
              color: AdminWebColors.warning),
          _StatRow(
              label: 'Pila',
              value: '6.2 days left',
              color: AdminWebColors.success),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AdminWebColors.accent, size: 24),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AdminWebColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AdminWebColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AdminWebColors.textSecondary)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminWebColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: double.parse(value.replaceAll('%', '')) / 100,
              backgroundColor: AdminWebColors.border.withValues(alpha: 0.2),
              color: color,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AdminWebColors.textPrimary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.title,
    required this.description,
    required this.priority,
    required this.icon,
  });

  final String title;
  final String description;
  final String priority;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminWebColors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AdminWebColors.accent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (priority == 'High' ? AdminWebColors.error : AdminWebColors.warning).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        priority,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: priority == 'High' ? AdminWebColors.error : AdminWebColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: AdminWebColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          TextButton(
            onPressed: () {},
            child: const Text('Action'),
          ),
        ],
      ),
    );
  }
}
