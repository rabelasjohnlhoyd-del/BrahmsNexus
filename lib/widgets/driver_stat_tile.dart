import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

/// Read-only stat tile for the Driver Home page's "Today at a Glance"
/// summary (e.g. "Branches Today: 6"). Mirrors
/// widgets/staff_stat_tile.dart's StaffDisplayTile so both apps'
/// home-page stat rows look identical — an icon + label header on
/// top, then the value in its own tinted rounded badge underneath,
/// rather than plain text floating on a white card.
class DriverDisplayTile extends StatelessWidget {
  const DriverDisplayTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.dark = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Renders the tile in the solid dark-brown — white text style
  /// instead of white-card style. Used to alternate tiles for visual
  /// rhythm, matching the Staff home page's inventory tiles.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final badgeColor = dark
        ? CupertinoColors.white.withValues(alpha: 0.22)
        : AppColors.pastelBrown.withValues(alpha: 0.3);
    final badgeIconColor = dark ? CupertinoColors.white : AppColors.accent;
    final labelColor = dark
        ? CupertinoColors.white.withValues(alpha: 0.85)
        : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? null : CupertinoColors.white,
        gradient: dark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accentDark, AppColors.accent],
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        border: dark ? null : Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentDark.withValues(alpha: dark ? 0.16 : 0.06),
            blurRadius: dark ? 14 : 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 13, color: badgeIconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dark
                  ? CupertinoColors.white.withValues(alpha: 0.18)
                  : AppColors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: dark ? CupertinoColors.white : AppColors.accentDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
