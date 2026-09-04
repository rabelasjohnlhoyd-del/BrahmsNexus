import 'package:flutter/material.dart';
import '../../../models/announcement.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/primary_button.dart';

/// Owner composes and posts announcements here — visible to Staff and
/// Driver on their respective apps (see staff_app/announcements_screen
/// and driver_app home).
///
/// NOTE: Mock data for now — once Supabase/Firebase are wired up,
/// posting here writes to the real `announcements` table.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _messageController = TextEditingController();
  bool _isPosting = false;

  final List<Announcement> _announcements = [
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

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _postAnnouncement() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() {
      _announcements.insert(
        0,
        Announcement(
          id: 'an${_announcements.length + 1}',
          messageContent: text,
          datePosted: DateTime.now(),
        ),
      );
      _messageController.clear();
      _isPosting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Announcement posted!')),
    );
  }

  void _deleteAnnouncement(String id) {
    setState(() => _announcements.removeWhere((a) => a.id == id));
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} · '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Announcements',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Post instructions or reminders visible to Staff and Driver.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _messageController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'New Announcement',
                      hintText: 'I-type dito ang announcement...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 160,
                      child: PrimaryButton(
                        label: 'POST',
                        icon: Icons.send_rounded,
                        isLoading: _isPosting,
                        onPressed: _postAnnouncement,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Posted Announcements',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _announcements.isEmpty
                ? const Center(
                    child: Text(
                      'Wala pang announcement na na-post.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: _announcements.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final a = _announcements[index];
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: AppColors.error, size: 20),
                                tooltip: 'Delete',
                                onPressed: () => _deleteAnnouncement(a.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
