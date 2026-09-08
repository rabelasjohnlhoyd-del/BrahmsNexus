import 'package:flutter/material.dart';
import '../admin_web_colors.dart';
import '../admin_web_widgets/glass_card.dart';
import '../admin_web_widgets/simple_bar_chart.dart';

/// DSS Analytics — Optimized for the new standardized Admin Web layout.
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
            // --- 1. DESCRIPTIVE ANALYTICS ---
            _SectionHeader(
              title: 'Historical Performance',
              subtitle: 'Sales volume and product distribution',
              icon: Icons.analytics_rounded,
            ),
            const SizedBox(height: 20),
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
                          'Branch Performance (Last 7 Days)',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AdminWebColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const SimpleBarChart(
                          labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
                          series: [
                            BarSeries(
                              values: [120, 150, 180, 140, 210, 250, 230],
                              color: AdminWebColors.accent,
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
                          'Size Popularity',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AdminWebColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _StatItem(label: 'Medium Bilao', value: '45%', color: AdminWebColors.accent),
                        _StatItem(label: 'Large Bilao', value: '32%', color: AdminWebColors.textSecondary),
                        _StatItem(label: 'Small Bilao', value: '23%', color: AdminWebColors.border),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // --- 2. PREDICTIVE ANALYTICS ---
            _SectionHeader(
              title: 'Forecast & Predictions',
              subtitle: 'Data-driven business projections',
              icon: Icons.auto_awesome_motion_rounded,
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sales Volume Forecast',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AdminWebColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Predicting a 15% increase in weekend orders based on historical pay-day trends.',
                          style: TextStyle(fontSize: 13, color: AdminWebColors.textSecondary, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        LinearProgressIndicator(
                          value: 0.85,
                          backgroundColor: AdminWebColors.border.withValues(alpha: 0.2),
                          color: AdminWebColors.success,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 8),
                        const Text('Confidence Level: 85%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminWebColors.textSecondary)),
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
                          'Depletion Risk',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AdminWebColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _RiskRow(label: 'Sta. Cruz', value: 'Critically Low', color: AdminWebColors.error),
                        _RiskRow(label: 'Dayap', value: 'Moderate', color: AdminWebColors.warning),
                        _RiskRow(label: 'Pila', value: 'Stable', color: AdminWebColors.success),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // --- 3. PRESCRIPTIVE ANALYTICS ---
            _SectionHeader(
              title: 'Prescriptive Insights',
              subtitle: 'Intelligent business recommendations',
              icon: Icons.tips_and_updates_rounded,
            ),
            const SizedBox(height: 20),
            _InsightCard(
              title: 'Stock Optimization',
              description: 'Transfer 20kg of surplus Karne from Pila to Sta. Cruz to avoid stock-out before tomorrow\'s delivery.',
              tag: 'ACTIONABLE',
              icon: Icons.local_shipping_rounded,
            ),
            const SizedBox(height: 12),
            _InsightCard(
              title: 'Staffing Insight',
              description: 'Victoria branch consistently exceeds capacity on Sundays. Recommended: Assign 1 additional staff member.',
              tag: 'EFFICIENCY',
              icon: Icons.groups_rounded,
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AdminWebColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AdminWebColors.accent, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AdminWebColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AdminWebColors.textSecondary,
                fontWeight: FontWeight.w500,
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminWebColors.textSecondary)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AdminWebColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: double.parse(value.replaceAll('%', '')) / 100,
              backgroundColor: AdminWebColors.border.withValues(alpha: 0.2),
              color: color,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  const _RiskRow({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AdminWebColors.textPrimary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Text(
              value.toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.description,
    required this.tag,
    required this.icon,
  });

  final String title;
  final String description;
  final String tag;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AdminWebColors.accent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AdminWebColors.accent, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AdminWebColors.textPrimary)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AdminWebColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AdminWebColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: AdminWebColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              backgroundColor: AdminWebColors.accent,
            ),
            child: const Text('Execute', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
