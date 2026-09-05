import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

/// Primary action button for the Driver app.
///
/// Mirrors widgets/staff_button.dart: raw [CupertinoButton] usages
/// left their label color to be inherited from the ambient theme,
/// which could make a disabled button (e.g. "Submit" while a photo
/// upload is in flight, or "Retake") render with **no visible label
/// at all** because the text color happened to match the button's
/// own background almost exactly. This widget hard-codes a readable
/// color for both the enabled and disabled states so that can't
/// happen again.
class DriverButton extends StatelessWidget {
  const DriverButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.accent,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;

  /// Optional leading icon so the intent reads at a glance instead of
  /// relying on label text alone.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final textColor = enabled ? CupertinoColors.white : AppColors.textSecondary;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 14),
      borderRadius: BorderRadius.circular(12),
      color: enabled ? color : null,
      disabledColor: color.withValues(alpha: 0.16),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
