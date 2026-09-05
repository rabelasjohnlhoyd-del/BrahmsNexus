import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

/// Reusable elevated content card for the Staff app.
///
/// Previously every staff screen re-implemented its own bordered
/// [Container] (`_card`, `_displayTile`, etc). They looked flat and
/// slightly inconsistent (radius/padding drifted between screens).
/// This gives every card the same soft, brown-tinted shadow + radius
/// so the UI reads as one polished surface instead of a pile of
/// outlined boxes.
class StaffCard extends StatelessWidget {
  const StaffCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.highlighted = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  /// When true, draws a stronger accent-colored border — used to show
  /// selected/active state (e.g. a checked checklist item) without
  /// needing a whole separate widget.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? AppColors.accent : (borderColor ?? AppColors.border),
          width: highlighted ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentDark.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}
