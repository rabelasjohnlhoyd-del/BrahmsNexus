import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

/// Reusable elevated content card for the Driver app.
///
/// Every Driver screen previously re-implemented its own bordered
/// [Container] for tiles/cards, drifting slightly in radius/padding
/// from screen to screen. This gives every card the same soft,
/// brown-tinted shadow + radius, matching widgets/staff_card.dart so
/// both apps read as one polished surface.
class DriverCard extends StatelessWidget {
  const DriverCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderColor,
    this.highlighted = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  /// When true, draws a stronger accent-colored border — used to show
  /// selected/active state without needing a whole separate widget.
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
