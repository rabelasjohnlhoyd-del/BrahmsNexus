import 'package:flutter/cupertino.dart';
import '../../models/announcement.dart';
import '../../theme/app_theme.dart';

/// Binubuksan mula sa notification bell icon sa tuktok ng bawat tab —
/// kapalit ng dating hiwalay na Announcements tab.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static final _mockAnnouncements = [
    Announcement(
      id: 'an1',
      messageContent:
          'Paalala: Mag-ingat sa paggamit ng mayo. I-double check ang '
          'quantity bago magbenta.',
      datePosted: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    Announcement(
      id: 'an2',
      messageContent:
          'May advance na bilao order bukas ng umaga — asikasuhin agad '
          'ang preparation.',
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
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Notifications'),
      ),
      child: SafeArea(
        child: _mockAnnouncements.isEmpty
            ? const Center(
                child: Text(
                  'Walang notification sa ngayon.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _mockAnnouncements.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final a = _mockAnnouncements[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.border,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          CupertinoIcons.bell_fill,
                          color: AppColors.accent,
                          size: 20,
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
                  );
                },
              ),
      ),
    );
  }
}
