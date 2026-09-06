import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import '../theme/app_theme.dart';
import 'staff_top_actions.dart';

/// Shared top header for every Staff tab — a curved, dark chocolate
/// banner (matching the approved reference design) with a decorative
/// leaf accent and the shared bell + profile actions from
/// [StaffTopActions].
///
/// NOTE: this header no longer has a hamburger/menu button. The Staff
/// app already has a bottom tab bar for navigation (see
/// [StaffShell]), so a second, redundant menu button was removed.
///
/// Two modes:
/// - `isHome: true` — a time-of-day greeting ("Good Evening, Staff 👋")
///   plus today's date, used only on the Homepage tab.
/// - `isHome: false` — a simple icon + title row, used on the other
///   three tabs (Sales, Daily Report, Timer) so the whole app shares
///   one consistent chocolate header treatment.
class StaffHeader extends StatelessWidget {
  const StaffHeader({
    super.key,
    this.isHome = false,
    this.title,
    this.icon,
    this.dateLabel,
  });

  final bool isHome;
  final String? title;
  final IconData? icon;
  final String? dateLabel;

  static String _greetingFor(DateTime now) {
    if (now.hour < 12) return 'Good Morning,';
    if (now.hour < 18) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, topInset + 14, 20, 26),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.chocolate, AppColors.chocolateLight],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Decorative leaf accent — echoes the leaf illustration in
            // the reference header. Sits behind all real content.
            Positioned(
              right: -16,
              bottom: -18,
              child: Transform.rotate(
                angle: -0.35,
                child: Icon(
                  Icons.eco,
                  size: 110,
                  color: CupertinoColors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      const StaffTopActions(initials: 'JD'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (isHome) ...[
                    Text(
                      _greetingFor(DateTime.now()),
                      style: const TextStyle(
                        color: AppColors.chocolateTint,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: const [
                        Text(
                          'Staff',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text('👋', style: TextStyle(fontSize: 22)),
                      ],
                    ),
                    if (dateLabel != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(CupertinoIcons.calendar,
                              size: 14, color: AppColors.chocolateTint),
                          const SizedBox(width: 6),
                          Text(
                            dateLabel!,
                            style: const TextStyle(
                              color: AppColors.chocolateTint,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ] else ...[
                    Row(
                      children: [
                        if (icon != null) ...[
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: CupertinoColors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: CupertinoColors.white, size: 18),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          title ?? '',
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The floating "which branch am I on today" pill shown just under
/// [StaffHeader] on every Staff tab — mirrors the "Sta. Cruz >" pill
/// in the reference design.
class StaffLocationPill extends StatelessWidget {
  const StaffLocationPill({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.cardCream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.chocolate.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.location_solid,
                size: 16, color: AppColors.chocolate),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right,
                size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
