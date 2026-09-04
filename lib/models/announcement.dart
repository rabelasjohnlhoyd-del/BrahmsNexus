/// Instructions/reminders posted by the Owner, visible to Staff and
/// Driver on their respective apps.
class Announcement {
  const Announcement({
    required this.id,
    required this.messageContent,
    required this.datePosted,
  });

  final String id;
  final String messageContent;
  final DateTime datePosted;
}
