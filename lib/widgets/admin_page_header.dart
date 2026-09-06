import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';

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
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AdminColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AdminColors.textSecondary,
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
