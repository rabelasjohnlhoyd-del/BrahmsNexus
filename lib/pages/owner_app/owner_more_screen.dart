import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_top_actions.dart';
import 'owner_account_approvals_screen.dart';
import 'owner_announcements_screen.dart';
import 'owner_bilao_orders_screen.dart';
import 'owner_employee_reports_screen.dart';

/// More tab — links to Account Approvals, Bilao Orders,
/// Employee Reports, and Announcements.
class OwnerMoreScreen extends StatelessWidget {
  const OwnerMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'More',
        trailing: StaffTopActions(),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _MoreRow(
              icon: CupertinoIcons.person_crop_circle_badge_checkmark,
              title: 'Account Approvals',
              subtitle: 'Review & approve new staff registrations',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) => const OwnerAccountApprovalsScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _MoreRow(
              icon: CupertinoIcons.bag_fill,
              title: 'Bilao Orders',
              subtitle: 'Track advance/special orders',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) => const OwnerBilaoOrdersScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _MoreRow(
              icon: CupertinoIcons.doc_text_fill,
              title: 'Employee Reports',
              subtitle: 'Monitor submitted daily reports',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) => const OwnerEmployeeReportsScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _MoreRow(
              icon: CupertinoIcons.speaker_2_fill,
              title: 'Announcements',
              subtitle: 'Post reminders to Staff and Driver',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) => const OwnerAnnouncementsScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: StaffCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
