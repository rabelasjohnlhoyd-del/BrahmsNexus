import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';
import 'owner_announcements_screen.dart';
import 'owner_bilao_orders_screen.dart';
import 'owner_employee_reports_screen.dart';

/// More tab — links to Bilao Orders, Employee Reports, and
/// Announcements (Owner composes these; not just a notification bell
/// like Staff/Driver, since Owner is the one posting).
class OwnerMoreScreen extends StatelessWidget {
  const OwnerMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('More'),
        backgroundColor: CupertinoColors.white,
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(CupertinoIcons.chevron_forward,
              size: 16, color: AppColors.textSecondary),
        ],
      ),
      ),
    );
  }
}
