import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

/// Consistent section heading used across every Driver screen — an
/// optional icon in a soft tinted circle plus an uppercase,
/// letter-spaced label. Mirrors widgets/staff_section_header.dart so
/// section headers read as one deliberate design system across both
/// apps instead of plain text repeated with drifting sizes/weights.
class DriverSectionHeader extends StatelessWidget {
  const DriverSectionHeader({
    super.key,
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
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
}
