import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

/// Primary action button for the Staff app.
///
/// Mirrors widgets/driver_button.dart: raw [CupertinoButton] usages
/// left their label color to be inherited from the ambient theme,
/// which could make a disabled button render with **no visible label
/// at all** because the text color happened to match the button's
/// own background almost exactly. This widget hard-codes a readable
/// color for both the enabled and disabled states so that can't
/// happen again.
class StaffButton extends StatelessWidget {
  const StaffButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.accent,
    this.textColor,
    this.icon,
    this.padding = const EdgeInsets.symmetric(vertical: 14),
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color? textColor;
  final EdgeInsetsGeometry padding;

  /// Optional leading icon. Used for actions like Confirm/Deny so the
  /// intent reads at a glance instead of relying on label text alone.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    // When a custom textColor is provided, the disabled state should 
    // be a faded version of that color instead of the default brown.
    final displayTextColor = enabled
        ? (textColor ?? CupertinoColors.white)
        : (textColor != null
            ? textColor!.withValues(alpha: 0.4)
            : AppColors.textSecondary);

    return CupertinoButton(
      padding: padding,
      borderRadius: BorderRadius.circular(12),
      color: enabled ? color : null,
      disabledColor: color.withValues(alpha: 0.16),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: displayTextColor),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: displayTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
