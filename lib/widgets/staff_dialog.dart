import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Shared confirmation dialog for the Staff app.
///
/// Every staff screen used to call the plain default
/// [CupertinoAlertDialog] for confirmations (Submit Sales, Send
/// Report, Reset Timer, Log Out) — functional, but generic and not
/// visually tied to the rest of the app. This gives every
/// confirmation the same deliberately designed look: a rounded white
/// card, a tinted icon badge, and full-width pill buttons matching
/// [StaffButton] — so confirmations read as part of one polished
/// product instead of a stock system dialog.
class StaffDialog {
  StaffDialog._();

  /// Shows the dialog and returns true only if the person tapped the
  /// confirm action. Returns false for cancel, dismiss, or back.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = CupertinoIcons.question_circle_fill,
    Color iconColor = AppColors.accent,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => _StaffDialogSurface(
        icon: icon,
        iconColor: isDestructive ? AppColors.error : iconColor,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }
}

class _StaffDialogSurface extends StatelessWidget {
  const _StaffDialogSurface({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDestructive,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 36),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.chocolate.withValues(alpha: 0.22),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    color: AppColors.cardCream,
                    borderRadius: BorderRadius.circular(14),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      cancelLabel,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    color: isDestructive ? AppColors.error : AppColors.accent,
                    borderRadius: BorderRadius.circular(14),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop(true);
                    },
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
