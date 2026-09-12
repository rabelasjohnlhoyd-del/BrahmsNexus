import 'package:flutter/cupertino.dart';
import '../../models/announcement.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_dialog.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_section_header.dart';

/// Announcements — Owner composes and posts announcements here,
/// visible to Staff and Driver on their respective apps. Owner is
/// kept reachable here (inside More) rather than moved to a
/// notification bell like Staff/Driver, since Owner is the one
/// COMPOSING these, not just receiving them.
///
/// Migrated from the old `admin_web/announcements` screen — same
/// model, rebuilt with Cupertino widgets and [StaffDialog] for the
/// delete confirmation instead of a bare delete icon button.
///
/// NOTE: Mock data for now — once Supabase/Firebase are wired up,
/// posting here writes to the real `announcements` table.
class OwnerAnnouncementsScreen extends StatefulWidget {
  const OwnerAnnouncementsScreen({super.key});

  @override
  State<OwnerAnnouncementsScreen> createState() =>
      _OwnerAnnouncementsScreenState();
}

class _OwnerAnnouncementsScreenState extends State<OwnerAnnouncementsScreen> {
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
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _postAnnouncement() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);

    // Broadcast notification to all Staff and Drivers
    await NotificationService.notifyStaffAndDriversOfAnnouncement(
      messageContent: text,
    );

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
  }

  Future<void> _confirmDelete(Announcement a) async {
    final confirmed = await StaffDialog.confirm(
      context,
      title: 'Delete Announcement',
      message: 'Are you sure you want to delete this announcement? '
          'Staff and Driver will no longer see it.',
      icon: CupertinoIcons.trash_fill,
      isDestructive: true,
      confirmLabel: 'Delete',
    );
    if (confirmed) {
      setState(() => _announcements.removeWhere((x) => x.id == a.id));
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} \u00b7 '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const StaffNavBar(
        title: 'Announcements',
        showBackButton: true,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: StaffCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const StaffSectionHeader(
                      label: 'New Announcement',
                      icon: CupertinoIcons.speaker_2_fill,
                    ),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: _messageController,
                      maxLines: 3,
                      placeholder:
                          'Post instructions or reminders for Staff and '
                          'Driver...',
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    StaffButton(
                      label: _isPosting ? 'Posting...' : 'Post',
                      icon: CupertinoIcons.paperplane_fill,
                      onPressed: _isPosting ? null : _postAnnouncement,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _announcements.isEmpty
                  ? const Center(
                      child: Text(
                        'No announcements posted yet.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _announcements.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _buildAnnouncementCard(_announcements[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(Announcement a) {
    return StaffCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.speaker_2_fill,
              size: 16,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.messageContent,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDate(a.datePosted),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () => _confirmDelete(a),
            child: const Icon(
              CupertinoIcons.delete,
              size: 18,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
