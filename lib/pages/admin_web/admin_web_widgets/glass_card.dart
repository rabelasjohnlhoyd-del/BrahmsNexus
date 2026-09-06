import 'dart:ui';

import 'package:flutter/material.dart';
import '../admin_web_colors.dart';

/// A "glassmorphism" surface used for every boxed component on the
/// Admin Web dashboard (welcome banner, KPI cards, chart cards, quick
/// links): semi-transparent white/beige fill, subtle backdrop blur,
/// a thin soft border, and a very light shadow. The blur is
/// deliberately subtle per the design brief — this is not meant to
/// make the whole page look frosted, just to give boxed surfaces a
/// touch of depth on top of the solid white page background.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AdminWebColors.glassFill,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AdminWebColors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: AdminWebColors.accent.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
