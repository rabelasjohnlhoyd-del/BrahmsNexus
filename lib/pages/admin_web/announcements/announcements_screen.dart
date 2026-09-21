import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/announcement.dart';
import '../../../services/firestore_service.dart';
import '../../../services/notification_service.dart';
import '../admin_web_colors.dart';
import '../admin_web_shell.dart';
import '../admin_web_widgets/glass_card.dart';
import '../admin_web_widgets/admin_pagination_bar.dart';

/// Owner composes and posts announcements here — visible to Staff and
/// Driver on their respective apps (see staff_app/announcements_screen
/// and driver_app home).
///
/// Backed by live real-time Firestore sync.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _messageController = TextEditingController();
  bool _isPosting = false;
  String _selectedTargetPosition = 'Branch Cook';
  StreamSubscription<List<Announcement>>? _announcementsSub;
  int _currentPage = 0;
  static const int _pageSize = 5;

  static const List<String> _positionChoices = [
    'Branch Cook',
    'Production Cook',
    'Production Meat Cutter',
    'Driver',
    'All Positions',
  ];

  final List<Announcement> _announcements = [];

  @override
  void initState() {
    super.initState();
    _updateShellActions();
    _announcementsSub =
        FirestoreService.watchAnnouncements().listen((list) {
      if (mounted) {
        setState(() {
          _announcements
            ..clear()
            ..addAll(list);
        });
      }
    });
  }

  @override
  void didUpdateWidget(AnnouncementsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateShellActions();
  }

  void _updateShellActions() {
    final shell = context.findAncestorStateOfType<AdminWebShellState>();
    shell?.setActions([]);
  }

  @override
  void dispose() {
    _announcementsSub?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _postAnnouncement() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);
    _updateShellActions();

    final docId = await FirestoreService.postAnnouncement(
      text,
      targetPosition: _selectedTargetPosition,
    );
    await NotificationService.notifyStaffAndDriversOfAnnouncement(
      messageContent: text,
      targetPosition: _selectedTargetPosition,
    );
    if (!mounted) return;

    setState(() {
      _announcements.insert(
        0,
        Announcement(
          id: docId ?? 'an${DateTime.now().millisecondsSinceEpoch}',
          messageContent: text,
          datePosted: DateTime.now(),
          targetPosition: _selectedTargetPosition,
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
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this announcement?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminWebColors.error),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await FirestoreService.deleteAnnouncement(id);
              if (!mounted) return;
              setState(() => _announcements.removeWhere((a) => a.id == id));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Announcement permanently deleted.')),
              );
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedTargetPosition,
                          decoration: const InputDecoration(
                            labelText: 'TARGET POSITION / AUDIENCE',
                            prefixIcon: Icon(Icons.people_alt_outlined, size: 20),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              letterSpacing: 0.8,
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: _positionChoices.map((pos) {
                            return DropdownMenuItem<String>(
                              value: pos,
                              child: Text(
                                pos,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedTargetPosition = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminWebColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        label: const Text('POST ANNOUNCEMENT'),
                        icon: _isPosting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 16),
                        onPressed: _isPosting ? null : _postAnnouncement,
                      ),
                    ],
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
            else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: (_announcements.length - (_currentPage * _pageSize)).clamp(0, _pageSize),
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final a = _announcements[(_currentPage * _pageSize) + index];
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
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AdminWebColors.accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: AdminWebColors.accent.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      'TARGET: ${a.targetPosition.toUpperCase()}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        color: AdminWebColors.accent,
                                      ),
                                    ),
                                  ),
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
              AdminPaginationBar(
                currentPage: _currentPage,
                totalItems: _announcements.length,
                pageSize: _pageSize,
                onPageChanged: (p) => setState(() => _currentPage = p),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}


