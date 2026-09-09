import 'package:flutter/material.dart';
import '../pages/admin_web/admin_web_colors.dart';

/// Standardized title + subtitle + optional trailing actions block
/// used at the top of every Admin Web page.
///
/// Every admin screen previously hand-rolled its own title Text +
/// SizedBox + subtitle Text, each with slightly different font sizes,
/// spacing, and wide/narrow handling. This gives every page identical
/// typography and spacing, and — critically — lets [actions] wrap
/// onto a second line on narrow widths instead of overflowing a Row.
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AdminWebColors.textPrimary,
                letterSpacing: -1.0,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AdminWebColors.textSecondary,
                ),
              ),
            ],
          ],
        );

        if (actions.isEmpty) return titleBlock;

        // Wrap lets the action buttons flow onto their own line on a
        // narrow browser window instead of squeezing into (or
        // overflowing) a fixed Row next to a long title.
        final isNarrow = constraints.maxWidth < 640;

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: actions,
            ),
          ],
        );
      },
    );
  }
}
