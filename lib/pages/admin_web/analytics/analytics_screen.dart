import 'package:flutter/material.dart';
import '../admin_web_colors.dart';
import '../admin_web_widgets/glass_card.dart';
import '../admin_web_widgets/simple_bar_chart.dart';

/// DSS Analytics — Descriptive, Predictive, and Prescriptive insights
/// built with consistent Admin Web glassmorphism components.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DSS Analytics',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AdminWebColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Decision Support System insights and business intelligence.',
              style: TextStyle(color: AdminWebColors.textSecondary),
            ),
            const SizedBox(height: 28),

            // --- 1. DESCRIPTIVE ANALYTICS ---
            _SectionHeader(
              title: 'Descriptive Analytics',
              subtitle: 'Historical patterns and current performance',
              icon: Icons.history_rounded,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sales Volume by Branch (Last 7 Days)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AdminWebColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 24),
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
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Best Selling Bilao',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AdminWebColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _StatItem(label: 'Medium (₱950)', value: '45%', color: AdminWebColors.accent),
                        _StatItem(label: 'Large (₱1300)', value: '32%', color: AdminWebColors.textSecondary),
                        _StatItem(label: 'Small (₱750)', value: '23%', color: AdminWebColors.border),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // --- 2. PREDICTIVE ANALYTICS ---
            _SectionHeader(
              title: 'Predictive Analytics',
              subtitle: 'Forecasting and future trends',
              icon: Icons.auto_graph_rounded,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Projected Sales Forecast',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AdminWebColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Based on moving-average projections, sales are expected to increase by 12% next weekend.',
                          style: TextStyle(fontSize: 13, color: AdminWebColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: 0.75,
                          backgroundColor: AdminWebColors.border.withValues(alpha: 0.3),
                          color: AdminWebColors.success,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inventory Depletion Rate',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AdminWebColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _StatRow(label: 'Sta. Cruz', value: '2.5 days left', color: AdminWebColors.error),
                        _StatRow(label: 'Dayap', value: '4.0 days left', color: AdminWebColors.warning),
                        _StatRow(label: 'Pila', value: '6.2 days left', color: AdminWebColors.success),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // --- 3. PRESCRIPTIVE ANALYTICS ---
            _SectionHeader(
              title: 'Prescriptive Analytics',
              subtitle: 'System-generated recommendations',
              icon: Icons.lightbulb_outline_rounded,
            ),
            const SizedBox(height: 16),
            _RecommendationCard(
              title: 'Inventory Optimization',
              description: 'Stock at Sta. Cruz is depleting faster than usual. Consider transferring 15kg extra from Dayap surplus.',
              priority: 'High',
              icon: Icons.inventory_2_rounded,
            ),
            const SizedBox(height: 12),
            _RecommendationCard(
              title: 'Staffing Adjustment',
              description: 'Orders peak between 11 AM - 1 PM on Saturdays. Consider assigning an additional cook to Pila branch.',
              priority: 'Medium',
              icon: Icons.people_alt_rounded,
            ),
            const SizedBox(height: 40),
          ],
        ),
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
