import 'package:flutter/material.dart';
import '../admin_web_colors.dart';

/// A professional Predictive Analytics chart displaying:
/// 1. Solid curve for Actual Historical Data (up to Today).
/// 2. Dashed projected curve for Simple Moving Average (SMA) Forecast (Future days).
/// 3. A vertical transition line marking where Historical data ends and Forecast begins.
class ForecastLineChart extends StatefulWidget {
  const ForecastLineChart({
    super.key,
    required this.historicalLabels,
    required this.historicalValues,
    required this.forecastLabels,
    required this.forecastValues,
    this.height = 175,
    this.unit = 'portions',
  });

  final List<String> historicalLabels;
  final List<num> historicalValues;
  final List<String> forecastLabels;
  final List<num> forecastValues;
  final double height;
  final String unit;

  @override
  State<ForecastLineChart> createState() => _ForecastLineChartState();
}

class _ForecastLineChartState extends State<ForecastLineChart> {
  int? _hoveredIndex;

  double get _computedMax {
    var maxVal = 0.0;
    for (final v in widget.historicalValues) {
      if (v > maxVal) maxVal = v.toDouble();
    }
    for (final v in widget.forecastValues) {
      if (v > maxVal) maxVal = v.toDouble();
    }
    if (maxVal <= 10) return 10;
    if (maxVal <= 20) return 20;
    if (maxVal <= 40) return 40;
    if (maxVal <= 60) return 60;
    if (maxVal <= 80) return 80;
    if (maxVal <= 120) return 120;
    if (maxVal <= 160) return 160;
    return ((maxVal / 40).ceil() * 40).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final allLabels = [...widget.historicalLabels, ...widget.forecastLabels];
    final totalPoints = allLabels.length;

    if (totalPoints == 0) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text(
            'Insufficient data for forecast modeling',
            style: TextStyle(fontSize: 12, color: AdminWebColors.textSecondary),
          ),
        ),
      );
    }

    final maxValue = _computedMax;
    const steps = 4;
    final splitIndex = widget.historicalLabels.length - 1;

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
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AdminWebColors.textSecondary,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 22),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Plot Area
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, _) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Chart Canvas
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ForecastPainter(
                                historicalCount: widget.historicalLabels.length,
                                historicalValues: widget.historicalValues,
                                forecastValues: widget.forecastValues,
                                maxValue: maxValue,
                                steps: steps,
                                hoveredIndex: _hoveredIndex,
                              ),
                            ),
                          ),

                          // Hover detection hit columns
                          Positioned.fill(
                            child: Row(
                              children: List.generate(totalPoints, (i) {
                                final label = allLabels[i];
                                final isForecast = i > splitIndex;
                                num val;
                                String typeLabel;

                                if (i <= splitIndex) {
                                  val = i < widget.historicalValues.length
                                      ? widget.historicalValues[i]
                                      : 0;
                                  typeLabel = 'Actual Demand';
                                } else {
                                  final fIndex = i - (splitIndex + 1);
                                  val = fIndex < widget.forecastValues.length
                                      ? widget.forecastValues[fIndex]
                                      : 0;
                                  typeLabel = 'SMA Projection';
                                }

                                return Expanded(
                                  child: Tooltip(
                                    message: '$label\n$typeLabel: $val ${widget.unit}',
                                    waitDuration: const Duration(milliseconds: 50),
                                    showDuration: const Duration(seconds: 4),
                                    verticalOffset: 24,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isForecast
                                          ? const Color(0xFFE65100)
                                          : const Color(0xFF2B1B12),
                                      borderRadius: BorderRadius.circular(8),
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
                                      fontWeight: FontWeight.w700,
                                      height: 1.35,
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
                  height: 14,
                  child: Row(
                    children: List.generate(totalPoints, (i) {
                      final isForecast = i > splitIndex;
                      final isHovered = _hoveredIndex == i;
                      return Expanded(
                        child: Text(
                          allLabels[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isHovered
                                ? FontWeight.w800
                                : (isForecast ? FontWeight.w700 : FontWeight.w600),
                            color: isForecast
                                ? const Color(0xFFE65100)
                                : (isHovered
                                    ? AdminWebColors.accent
                                    : AdminWebColors.textSecondary),
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

class _ForecastPainter extends CustomPainter {
  const _ForecastPainter({
    required this.historicalCount,
    required this.historicalValues,
    required this.forecastValues,
    required this.maxValue,
    required this.steps,
    required this.hoveredIndex,
  });

  final int historicalCount;
  final List<num> historicalValues;
  final List<num> forecastValues;
  final double maxValue;
  final int steps;
  final int? hoveredIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final totalPoints = historicalCount + forecastValues.length;
    if (totalPoints <= 0 || size.width <= 0 || size.height <= 0) return;

    final stepX = size.width / totalPoints;

    // 1. Horizontal Gridlines
    final gridPaint = Paint()
      ..color = AdminWebColors.border.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= steps; i++) {
      final y = size.height * i / steps;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Vertical Forecast Divider Line (Where actual ends and forecast starts)
    if (historicalCount > 0 && forecastValues.isNotEmpty) {
      final divX = stepX * (historicalCount - 0.5);
      final divPaint = Paint()
        ..color = const Color(0xFFE65100).withValues(alpha: 0.4)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      // Draw dashed vertical divider
      double curY = 0;
      while (curY < size.height) {
        canvas.drawLine(Offset(divX, curY), Offset(divX, (curY + 4).clamp(0.0, size.height)), divPaint);
        curY += 7;
      }
    }

    // 3. Compute Coordinates
    final histPoints = <Offset>[];
    for (int i = 0; i < historicalCount; i++) {
      final val = i < historicalValues.length ? historicalValues[i].toDouble() : 0.0;
      final x = stepX * i + (stepX / 2);
      final ratio = (val / maxValue).clamp(0.0, 1.0);
      final y = size.height - (ratio * size.height);
      histPoints.add(Offset(x, y));
    }

    final fcPoints = <Offset>[];
    // Start forecast line from the last historical point for continuity
    if (histPoints.isNotEmpty) {
      fcPoints.add(histPoints.last);
    }
    for (int i = 0; i < forecastValues.length; i++) {
      final val = forecastValues[i].toDouble();
      final x = stepX * (historicalCount + i) + (stepX / 2);
      final ratio = (val / maxValue).clamp(0.0, 1.0);
      final y = size.height - (ratio * size.height);
      fcPoints.add(Offset(x, y));
    }

    // 4. Draw Historical Actual (Area Fill + Solid Curve)
    if (histPoints.isNotEmpty) {
      final linePath = Path();
      linePath.moveTo(histPoints.first.dx, histPoints.first.dy);
      for (int i = 0; i < histPoints.length - 1; i++) {
        final p0 = histPoints[i];
        final p1 = histPoints[i + 1];
        final cp1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
        final cp2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
        linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
      }

      // Fill area under actual line
      final areaPath = Path.from(linePath);
      areaPath.lineTo(histPoints.last.dx, size.height);
      areaPath.lineTo(histPoints.first.dx, size.height);
      areaPath.close();

      final areaPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AdminWebColors.accent.withValues(alpha: 0.25),
            AdminWebColors.accent.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;

      canvas.drawPath(areaPath, areaPaint);

      // Solid Stroke for Actual Line
      final strokePaint = Paint()
        ..color = AdminWebColors.accent
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(linePath, strokePaint);

      // Draw Historical Dots
      for (int i = 0; i < histPoints.length; i++) {
        final pt = histPoints[i];
        final isHovered = hoveredIndex == i;
        canvas.drawCircle(pt, isHovered ? 5.5 : 4.0, Paint()..color = AdminWebColors.accent);
        canvas.drawCircle(pt, isHovered ? 2.5 : 1.8, Paint()..color = Colors.white);
      }
    }

    // 5. Draw Forecast Projection (Dashed Amber Line + Glowing Forecast Nodes)
    if (fcPoints.length > 1) {
      final fcPaint = Paint()
        ..color = const Color(0xFFE65100)
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < fcPoints.length - 1; i++) {
        final p0 = fcPoints[i];
        final p1 = fcPoints[i + 1];

        // Draw dotted/dashed segment between p0 and p1
        final dist = (p1 - p0).distance;
        final count = (dist / 8).ceil();
        for (int d = 0; d < count; d++) {
          if (d % 2 == 0) {
            final t1 = d / count;
            final t2 = ((d + 1) / count).clamp(0.0, 1.0);
            final s = Offset.lerp(p0, p1, t1)!;
            final e = Offset.lerp(p0, p1, t2)!;
            canvas.drawLine(s, e, fcPaint);
          }
        }
      }

      // Draw Forecast Nodes (skip index 0 which is shared with actual)
      for (int i = 1; i < fcPoints.length; i++) {
        final pt = fcPoints[i];
        final globalIndex = historicalCount + (i - 1);
        final isHovered = hoveredIndex == globalIndex;

        // Amber halo for future predictions
        canvas.drawCircle(
          pt,
          isHovered ? 8.5 : 6.5,
          Paint()..color = const Color(0xFFE65100).withValues(alpha: 0.2),
        );
        canvas.drawCircle(pt, isHovered ? 5.0 : 4.0, Paint()..color = const Color(0xFFE65100));
        canvas.drawCircle(pt, isHovered ? 2.5 : 1.8, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ForecastPainter oldDelegate) {
    return oldDelegate.maxValue != maxValue ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.historicalValues != historicalValues ||
        oldDelegate.forecastValues != forecastValues;
  }
}
