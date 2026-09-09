import 'package:flutter/material.dart';
import '../../../models/announcement.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';

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
          'Reminder: Be careful with mayo usage. Double-check the '
          'quantity before selling.',
      datePosted: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    Announcement(
      id: 'an2',
      messageContent:
          "There's an advance bilao order for tomorrow morning — start "
          'preparation right away.',
      datePosted: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _updateShellActions();
  }

  @override
  void didUpdateWidget(AnnouncementsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.15),
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          elevation: 0,
        ),
        label: const Text('POST ANNOUNCEMENT'),
        icon: _isPosting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.send_rounded, size: 18),
        onPressed: _isPosting ? null : _postAnnouncement,
      ),
    ]);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _postAnnouncement() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);
    _updateShellActions();
    
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
    _updateShellActions();

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
    return Container(
      color: AdminWebColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _messageController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'NEW ANNOUNCEMENT',
                      hintText: 'Type your announcement here...',
                      alignLabelWithHint: true,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'POSTED ANNOUNCEMENTS',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.0,
                color: AdminWebColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (_announcements.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'No announcements posted yet.',
                    style: TextStyle(color: AdminWebColors.textSecondary),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _announcements.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final a = _announcements[index];
                  return GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AdminWebColors.accent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.campaign_rounded,
                              color: AdminWebColors.accent, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.messageContent,
                                style: const TextStyle(
                                  color: AdminWebColors.textPrimary,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatDate(a.datePosted),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AdminWebColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AdminWebColors.error, size: 20),
                          tooltip: 'Delete',
                          onPressed: () => _deleteAnnouncement(a.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

