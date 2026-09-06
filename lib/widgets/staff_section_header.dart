import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

/// Consistent section heading used across every Staff screen — an
/// optional icon in a soft tinted circle plus an uppercase,
/// letter-spaced label. Pulled out as a shared widget so section
/// headers read as one deliberate design system instead of plain grey
/// text repeated (with drifting sizes/weights) on every screen.
class StaffSectionHeader extends StatelessWidget {
  const StaffSectionHeader({
    super.key,
    required this.label,
    this.icon,
    this.subtitle,
    this.trailing,
    this.large = false,
  });

  final String label;
  final IconData? icon;

  /// Optional supporting line shown under the title. Only used when
  /// [large] is true.
  final String? subtitle;

  /// Optional trailing widget (e.g. a date chip). Only used when
  /// [large] is true.
  final Widget? trailing;

  /// When true, renders the bigger "feature" header style used for a
  /// screen's primary section (round icon badge + bold title +
  /// subtitle) instead of the compact uppercase label. Kept as one
  /// widget rather than two so every screen pulls from the same
  /// source of truth for section styling.
  final bool large;

  @override
  Widget build(BuildContext context) {
    if (!large) {
      return Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 13, color: AppColors.accent),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accentDark,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: CupertinoColors.white),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          trailing!,
        ],
      ],
    );
  }
}
