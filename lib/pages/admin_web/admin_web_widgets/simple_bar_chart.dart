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
    // Round up to the next nice multiple of 50 (matches the 0/50/100/
    // 150/200 axis in the reference design) so bars never touch the
    // very top gridline.
    if (max <= 0) return 50;
    return ((max / 50).ceil() * 50).toDouble();
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
          // Y-axis labels
          SizedBox(
            width: 32,
            height: height - 20,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(steps + 1, (i) {
                final value = (maxValue * (steps - i) / steps).round();
                return Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AdminWebColors.textSecondary,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          // Plot area: gridlines behind, bars on top, day labels below.
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: height - 20,
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: Size.infinite,
                        painter: _GridPainter(steps: steps),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(labels.length, (dayIndex) {
                            return _BarGroup(
                              values: [
                                for (final s in series) s.values[dayIndex]
                              ],
                              colors: [for (final s in series) s.color],
                              maxValue: maxValue,
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: labels
                      .map((l) => Text(
                            l,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AdminWebColors.textSecondary,
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One day's group of bars (one bar per series), sized relative to
/// [maxValue] via [FractionallySizedBox] so it lays out correctly no
/// matter the available height.
class _BarGroup extends StatelessWidget {
  const _BarGroup({
    required this.values,
    required this.colors,
    required this.maxValue,
  });

  final List<num> values;
  final List<Color> colors;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: FractionallySizedBox(
                heightFactor: (values[i] / maxValue).clamp(0.0, 1.0),
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors[i],
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
