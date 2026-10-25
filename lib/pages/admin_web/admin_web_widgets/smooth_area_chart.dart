import 'package:flutter/material.dart';
import '../admin_web_colors.dart';

/// One data series for [SmoothAreaChart].
class AreaSeries {
  const AreaSeries({
    required this.name,
    required this.values,
    required this.color,
    this.gradientColors,
    this.unit = 'orders',
  });

  final String name;
  final List<num> values;
  final Color color;
  final List<Color>? gradientColors;
  final String unit;
}

/// A modern, smooth spline area & line chart designed for executive dashboards.
///
/// Features:
/// - Smooth cubic Bézier interpolation curves
/// - Vertical gradient fill under curves
/// - Styled circular node dots at data points
/// - Horizontal grid lines with automatically scaled Y-axis ticks
/// - Interactive hover detection with vertical indicator guide & tooltip
class SmoothAreaChart extends StatefulWidget {
  const SmoothAreaChart({
    super.key,
    required this.labels,
    required this.series,
    this.height = 185,
    this.emptyMessage = 'No order data recorded yet',
  });

  final List<String> labels;
  final List<AreaSeries> series;
  final double height;
  final String emptyMessage;

  @override
  State<SmoothAreaChart> createState() => _SmoothAreaChartState();
}

class _SmoothAreaChartState extends State<SmoothAreaChart> {
  int? _hoveredIndex;

  double get _computedMax {
    var maxVal = 0.0;
    for (final s in widget.series) {
      for (final v in s.values) {
        if (v > maxVal) maxVal = v.toDouble();
      }
    }
    if (maxVal <= 10) return 10;
    if (maxVal <= 20) return 20;
    if (maxVal <= 40) return 40;
    if (maxVal <= 80) return 80;
    if (maxVal <= 120) return 120;
    if (maxVal <= 160) return 160;
    if (maxVal <= 200) return 200;
    return ((maxVal / 40).ceil() * 40).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.labels.isEmpty || widget.series.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            widget.emptyMessage,
            style: const TextStyle(
              fontSize: 12,
              color: AdminWebColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final maxValue = _computedMax;
    const steps = 4; // 4 intervals = 5 gridlines (0, 25%, 50%, 75%, 100%)

    return SizedBox(
      height: widget.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Y-Axis Labels
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(steps + 1, (i) {
                      final val = (maxValue * (steps - i) / steps).round();
                      return Text(
                        '$val',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AdminWebColors.textSecondary,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 24), // Reserve space for X-axis labels
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Main Chart Plot Area
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, _) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Custom Painter for Grids, Smooth Spline Area, Curves, and Dots
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _SplineChartPainter(
                                labels: widget.labels,
                                series: widget.series,
                                maxValue: maxValue,
                                steps: steps,
                                hoveredIndex: _hoveredIndex,
                              ),
                            ),
                          ),

                          // Transparent Hover Hit Zones across each day column
                          Positioned.fill(
                            child: Row(
                              children: List.generate(widget.labels.length, (i) {
                                final label = widget.labels[i];
                                final lines = <String>[label];
                                for (final s in widget.series) {
                                  final val = i < s.values.length ? s.values[i] : 0;
                                  lines.add('${s.name}: $val ${s.unit}');
                                }
                                final tooltipMsg = lines.join('\n');

                                return Expanded(
                                  child: Tooltip(
                                    message: tooltipMsg,
                                    waitDuration: const Duration(milliseconds: 50),
                                    showDuration: const Duration(seconds: 4),
                                    verticalOffset: 24,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2B1B12), // Deep Brahms Brown
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AdminWebColors.border.withValues(alpha: 0.4),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    textStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      onEnter: (_) => setState(() => _hoveredIndex = i),
                                      onExit: (_) => setState(() {
                                        if (_hoveredIndex == i) _hoveredIndex = null;
                                      }),
                                      child: Container(color: Colors.transparent),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // X-Axis Day Labels
                SizedBox(
                  height: 16,
                  child: Row(
                    children: List.generate(widget.labels.length, (i) {
                      final isHovered = _hoveredIndex == i;
                      return Expanded(
                        child: Text(
                          widget.labels[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isHovered ? FontWeight.w800 : FontWeight.w600,
                            color: isHovered
                                ? AdminWebColors.accent
                                : AdminWebColors.textSecondary,
                          ),
                        ),
                      );
                    }),
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

class _SplineChartPainter extends CustomPainter {
  const _SplineChartPainter({
    required this.labels,
    required this.series,
    required this.maxValue,
    required this.steps,
    required this.hoveredIndex,
  });

  final List<String> labels;
  final List<AreaSeries> series;
  final double maxValue;
  final int steps;
  final int? hoveredIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty || size.width <= 0 || size.height <= 0) return;

    // 1. Draw horizontal gridlines
    final gridPaint = Paint()
      ..color = AdminWebColors.border.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= steps; i++) {
      final y = size.height * i / steps;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Draw vertical guide line if a column is hovered
    final n = labels.length;
    final stepX = size.width / n;

    if (hoveredIndex != null && hoveredIndex! < n) {
      final hX = stepX * hoveredIndex! + (stepX / 2);
      final guidePaint = Paint()
        ..color = AdminWebColors.accent.withValues(alpha: 0.3)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      // Draw dashed/dotted vertical line
      const dashH = 4.0;
      const dashSpace = 3.0;
      double startY = 0;
      while (startY < size.height) {
        canvas.drawLine(
          Offset(hX, startY),
          Offset(hX, (startY + dashH).clamp(0.0, size.height)),
          guidePaint,
        );
        startY += dashH + dashSpace;
      }
    }

    // 3. Draw Each Series (Fill Area + Smooth Line + Dots)
    for (final s in series) {
      if (s.values.isEmpty) continue;

      final points = <Offset>[];
      for (int i = 0; i < n; i++) {
        final val = i < s.values.length ? s.values[i].toDouble() : 0.0;
        final x = stepX * i + (stepX / 2);
        final ratio = (val / maxValue).clamp(0.0, 1.0);
        final y = size.height - (ratio * size.height);
        points.add(Offset(x, y));
      }

      if (points.isEmpty) continue;

      // Build smooth cubic bezier path
      final linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);

      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];

        // Cubic control points with smooth midpoint tension
        final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
        final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);

        linePath.cubicTo(
          controlPoint1.dx,
          controlPoint1.dy,
          controlPoint2.dx,
          controlPoint2.dy,
          p1.dx,
          p1.dy,
        );
      }

      // Draw Gradient Area Fill under the curve
      final areaPath = Path.from(linePath);
      areaPath.lineTo(points.last.dx, size.height);
      areaPath.lineTo(points.first.dx, size.height);
      areaPath.close();

      final gradColors = s.gradientColors ??
          [
            s.color.withValues(alpha: 0.28),
            s.color.withValues(alpha: 0.02),
          ];

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradColors,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;

      canvas.drawPath(areaPath, fillPaint);

      // Stroke Smooth Line Curve
      final strokePaint = Paint()
        ..color = s.color
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(linePath, strokePaint);

      // Draw Node Dots at data points
      for (int i = 0; i < points.length; i++) {
        final pt = points[i];
        final isHovered = hoveredIndex == i;
        final hasValue = i < s.values.length && s.values[i] > 0;

        if (isHovered) {
          // Glow halo
          final haloPaint = Paint()
            ..color = s.color.withValues(alpha: 0.25)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(pt, 9, haloPaint);
        }

        // Outer dot ring
        final dotOuterPaint = Paint()
          ..color = s.color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pt, isHovered ? 5.5 : (hasValue ? 4.5 : 3.5), dotOuterPaint);

        // Inner white dot
        final dotInnerPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pt, isHovered ? 2.8 : (hasValue ? 2.2 : 1.5), dotInnerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SplineChartPainter oldDelegate) {
    return oldDelegate.maxValue != maxValue ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.series != series ||
        oldDelegate.labels != labels;
  }
}
