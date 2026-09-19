/// Instructions/reminders posted by the Owner, visible to Staff and
/// Driver on their respective apps.
class Announcement {
  const Announcement({
    required this.id,
    required this.messageContent,
    required this.datePosted,
    this.targetPosition = 'All Positions',
  });

  final String id;
  final String messageContent;
  final DateTime datePosted;
  final String targetPosition;

  Announcement copyWith({
    String? id,
    String? messageContent,
    DateTime? datePosted,
    String? targetPosition,
  }) {
    return Announcement(
      id: id ?? this.id,
      messageContent: messageContent ?? this.messageContent,
      datePosted: datePosted ?? this.datePosted,
      targetPosition: targetPosition ?? this.targetPosition,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageContent': messageContent,
      'datePosted': datePosted.toIso8601String(),
      'targetPosition': targetPosition,
    };
  }

  factory Announcement.fromMap(String id, Map<String, dynamic> map) {
    return Announcement(
      id: id,
      messageContent: map['messageContent']?.toString() ?? '',
      datePosted: map['datePosted'] != null
          ? DateTime.tryParse(map['datePosted'].toString()) ?? DateTime.now()
          : DateTime.now(),
      targetPosition: map['targetPosition']?.toString() ?? 'All Positions',
    );
  }
}
