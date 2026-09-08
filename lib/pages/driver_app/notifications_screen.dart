import 'package:flutter/cupertino.dart';
import '../../models/announcement.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_card.dart';
import '../../widgets/driver_nav_bar.dart';
import '../../widgets/driver_section_header.dart';

/// Opened from the notification bell — announcements from the Owner
/// to the Driver.
class DriverNotificationsScreen extends StatelessWidget {
  const DriverNotificationsScreen({super.key});

  static final _mockAnnouncements = [
    Announcement(
      id: 'an1',
      messageContent:
          'Reminder: Double-check bilao orders before delivering.',
      datePosted: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Announcement(
      id: 'an2',
      messageContent: 'New route today — 6 branches.',
      datePosted: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} · '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const DriverNavBar(
        title: 'Notifications',
        showBackButton: true,
      ),
      child: SafeArea(
        child: _mockAnnouncements.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.pastelBrown.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.bell_slash,
                            size: 32, color: AppColors.accent),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Quiet for Now',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You have no new announcements or notifications at the moment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const DriverSectionHeader(
                    label: 'Latest Announcements',
                    icon: CupertinoIcons.bell_fill,
                  ),
                  const SizedBox(height: 10),
                  ..._mockAnnouncements.map((a) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DriverCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.pastelBrown.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                CupertinoIcons.bell_fill,
                                color: AppColors.accent,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.messageContent,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatDate(a.datePosted),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }
}
