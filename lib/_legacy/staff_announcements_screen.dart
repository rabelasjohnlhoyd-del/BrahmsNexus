import 'package:flutter/material.dart';
import '../models/announcement.dart';
import '../theme/app_theme.dart';

/// View-only para sa Staff — ang pag-post ng announcements ay sa
/// Admin Web na lang (see admin_web/announcements).
class StaffAnnouncementsScreen extends StatelessWidget {
  const StaffAnnouncementsScreen({super.key});

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
          'May advance na bilao order bukas ng umaga — asikasuhin '
          'agad ang preparation.',
      datePosted: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: SafeArea(
        child: _mockAnnouncements.isEmpty
            ? const Center(
                child: Text(
                  'Walang announcement sa ngayon.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _mockAnnouncements.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final a = _mockAnnouncements[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.campaign_rounded,
                              color: AppColors.accent),
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
                },
              ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} · '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
