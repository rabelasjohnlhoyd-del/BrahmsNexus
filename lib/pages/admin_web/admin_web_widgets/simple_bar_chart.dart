import 'package:flutter/material.dart';
import '../admin_web_colors.dart';

/// One data series (a set of bar values + a color) for [SimpleBarChart].
class BarSeries {
  const BarSeries({required this.values, required this.color});

  final List<num> values;
  final Color color;
}

/// A clean, minimal grouped bar chart: horizontal gridlines with
/// numeric labels on the left, day labels along the bottom, and one
/// or more bar series per day (side-by-side when there's more than
/// one series, e.g. offline vs. online sales).
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.labels,
    required this.series,
    this.height = 170,
  });

  final List<String> labels;
  final List<BarSeries> series;
  final double height;

  double get _maxValue {
    var max = 0.0;
    for (final s in series) {
      for (final v in s.values) {
        if (v > max) max = v.toDouble();
      }
    }
    if (max <= 20) return 20;
    if (max <= 40) return 40;
    if (max <= 60) return 60;
    if (max <= 80) return 80;
    if (max <= 100) return 100;
    return ((max / 40).ceil() * 40).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final maxValue = _maxValue;
    final steps = 4; // 4 intervals -> 5 gridlines (0, 25%, 50%, 75%, 100%)

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Y-axis labels: precisely aligned with the gridlines
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(steps + 1, (i) {
                      final value = (maxValue * (steps - i) / steps).round();
                      return Text(
                        '$value',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AdminWebColors.textSecondary,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 22), // Space for X-axis labels (8 + 14)
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Plot area: gridlines + bars + day labels below.
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      // Gridlines
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _GridPainter(steps: steps),
                        ),
                      ),
                      // Bars
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(labels.length, (dayIndex) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: _BarGroup(
                                  label: labels[dayIndex],
                                  values: [
                                    for (final s in series) s.values[dayIndex]
                                  ],
                                  colors: [for (final s in series) s.color],
                                  maxValue: maxValue,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // X-axis labels
                SizedBox(
                  height: 14,
                  child: Row(
                    children: labels
                        .map((l) => Expanded(
                              child: Text(
                                l,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AdminWebColors.textSecondary,
                                ),
                              ),
                            ))
                        .toList(),
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

/// One day's group of bars (one bar per series).
class _BarGroup extends StatelessWidget {
  const _BarGroup({
    this.label,
    required this.values,
    required this.colors,
    required this.maxValue,
  });

  final String? label;
  final List<num> values;
  final List<Color> colors;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Flexible(
            child: FractionallySizedBox(
              heightFactor: (values[i] / maxValue).clamp(0.01, 1.0),
              alignment: Alignment.bottomCenter,
              child: Tooltip(
                message: label != null ? '$label: ${values[i]}' : '${values[i]}',
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                decoration: BoxDecoration(
                  color: AdminWebColors.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    constraints: const BoxConstraints(maxWidth: 32),
                    decoration: BoxDecoration(
                      color: colors[i],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Faint horizontal gridlines behind the bars.
class _GridPainter extends CustomPainter {
  const _GridPainter({required this.steps});

  final int steps;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AdminWebColors.border
      ..strokeWidth = 1;

    for (var i = 0; i <= steps; i++) {
      final y = size.height * i / steps;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.steps != steps;
}

