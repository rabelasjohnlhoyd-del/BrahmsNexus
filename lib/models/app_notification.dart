import 'package:flutter/material.dart';

enum NotificationType {
  accountApproval,
  announcement,
  lowStock,
  deliveryTask,
  salesReport,
  system;

  String get label {
    switch (this) {
      case NotificationType.accountApproval:
        return 'Account Approval';
      case NotificationType.announcement:
        return 'Announcement';
      case NotificationType.lowStock:
        return 'Low Stock Alert';
      case NotificationType.deliveryTask:
        return 'Delivery Task';
      case NotificationType.salesReport:
        return 'Sales Report';
      case NotificationType.system:
        return 'System';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.accountApproval:
        return Icons.how_to_reg_rounded;
      case NotificationType.announcement:
        return Icons.campaign_rounded;
      case NotificationType.lowStock:
        return Icons.warning_amber_rounded;
      case NotificationType.deliveryTask:
        return Icons.local_shipping_rounded;
      case NotificationType.salesReport:
        return Icons.receipt_long_rounded;
      case NotificationType.system:
        return Icons.notifications_rounded;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.accountApproval:
        return const Color(0xFF2E7D32); // Success green
      case NotificationType.announcement:
        return const Color(0xFF8D6E63); // Theme accent brown
      case NotificationType.lowStock:
        return const Color(0xFFE65100); // Warning orange
      case NotificationType.deliveryTask:
        return const Color(0xFF0288D1); // Info blue
      case NotificationType.salesReport:
        return const Color(0xFF6A1B9A); // Purple
      case NotificationType.system:
        return const Color(0xFF546E7A); // Slate
    }
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.targetRole,
    this.targetUserId,
    this.targetBranch,
    this.route,
    this.readBy = const [],
    required this.createdAt,
  });

  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final String targetRole; // 'owner', 'staff', 'driver', 'production', 'all'
  final String? targetUserId;
  final String? targetBranch;
  final String? route; // e.g. 'account_approvals', 'inventory', 'announcements'
  final List<String> readBy;
  final DateTime createdAt;

  bool isRead(String userId) => readBy.contains(userId);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,
      'targetRole': targetRole,
      'targetUserId': targetUserId,
      'targetBranch': targetBranch,
      'route': route,
      'readBy': readBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      // Handle Firestore Timestamp if present
      try {
        final dynamic ts = val;
        return ts.toDate() as DateTime;
      } catch (_) {
        return DateTime.now();
      }
    }

    NotificationType parseType(dynamic val) {
      if (val == null) return NotificationType.system;
      final str = val.toString();
      for (final t in NotificationType.values) {
        if (t.name == str) return t;
      }
      return NotificationType.system;
    }

    final readByList = (map['readBy'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    return AppNotification(
      id: id,
      title: (map['title'] ?? '') as String,
      message: (map['message'] ?? '') as String,
      type: parseType(map['type']),
      targetRole: (map['targetRole'] ?? 'all') as String,
      targetUserId: map['targetUserId'] as String?,
      targetBranch: map['targetBranch'] as String?,
      route: map['route'] as String?,
      readBy: readByList,
      createdAt: parseDate(map['createdAt']),
    );
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    String? targetRole,
    String? targetUserId,
    String? targetBranch,
    String? route,
    List<String>? readBy,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      targetRole: targetRole ?? this.targetRole,
      targetUserId: targetUserId ?? this.targetUserId,
      targetBranch: targetBranch ?? this.targetBranch,
      route: route ?? this.route,
      readBy: readBy ?? this.readBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
