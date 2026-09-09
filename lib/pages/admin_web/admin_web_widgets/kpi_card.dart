import 'package:flutter/material.dart';
import '../admin_web_colors.dart';
import 'glass_card.dart';

/// One glass KPI tile for the dashboard's top stats row: an icon,
/// a label, a large value, a small subtitle, and a tiny decorative
/// trend sparkline in the corner (mock/illustrative for now — once
/// real data is wired up this can be driven by an actual trend).
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AdminWebColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: AdminWebColors.accent),
              ),
              SizedBox(
                width: 48,
                height: 24,
                child: CustomPaint(painter: _TrendPainter()),
              ),
            ],
          ),
          const Spacer(),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AdminWebColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AdminWebColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: subtitle.contains('+') || subtitle.contains('Active') 
                  ? AdminWebColors.success 
                  : AdminWebColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Small decorative upward sparkline drawn in a KPI card's corner —
/// purely illustrative, matching the reference design's mini trend
/// lines, not derived from real data yet.
class _TrendPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AdminWebColors.accent.withValues(alpha: 0.8)
      ..strokeWidth = 1.6
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
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => false;
}
