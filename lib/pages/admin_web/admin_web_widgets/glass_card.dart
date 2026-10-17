import 'package:flutter/material.dart';
import '../admin_web_colors.dart';

/// High-performance card surface used across the Admin Web dashboard.
///
/// Pre-renders cleanly with subtle elevation and border without triggering
/// heavy GPU offscreen framebuffer copies (BackdropFilter) on every frame.
/// Wrapped in [RepaintBoundary] so scrolling lists of cards do not force
/// expensive re-rasterization of individual cards.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(24),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: borderColor ?? AdminWebColors.glassBorder),
          boxShadow: [
            BoxShadow(
              color: AdminWebColors.accentDark.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
