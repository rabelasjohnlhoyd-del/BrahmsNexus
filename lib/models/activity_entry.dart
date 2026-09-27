import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a persistent business activity or audit event in Brahms Nexus.
class ActivityEntry {
  final String id;
  final String actor;
  final String role; // 'Admin', 'Staff', 'Driver', 'System'
  final String action;
  final String detail;
  final DateTime timestamp;
  final String type; // 'Orders', 'Staff', 'Sales', 'System'

  const ActivityEntry({
    this.id = '',
    required this.actor,
    required this.role,
    required this.action,
    this.detail = '',
    required this.timestamp,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'actor': actor,
      'role': role,
      'action': action,
      'detail': detail,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
    };
  }

  factory ActivityEntry.fromDoc(String id, Map<String, dynamic> data) {
    DateTime ts = DateTime.now();
    final rawTs = data['timestamp'];
    if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else if (rawTs is DateTime) {
      ts = rawTs;
    }

    return ActivityEntry(
      id: id,
      actor: data['actor'] as String? ?? 'System',
      role: data['role'] as String? ?? 'System',
      action: data['action'] as String? ?? '',
      detail: data['detail'] as String? ?? '',
      timestamp: ts,
      type: data['type'] as String? ?? 'System',
    );
  }
}
