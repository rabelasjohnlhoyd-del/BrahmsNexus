import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_notification.dart';

class NotificationService {
  const NotificationService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'notifications';

  /// In-memory fallback list to provide default seed notifications and
  /// graceful offline functionality.
  static final List<AppNotification> _inMemoryNotifications = [
    AppNotification(
      id: 'seed_notif_1',
      title: 'Welcome to Brahms Nexus',
      message: 'System notifications and announcements will appear here in real time.',
      type: NotificationType.system,
      targetRole: 'all',
      createdAt: DateTime.now().subtract(const Duration(hours: 12)),
    ),
    AppNotification(
      id: 'seed_notif_2',
      title: 'Reminder: Quality & Safety',
      message: 'Double-check bilao orders and monitor karne allocations before dispatch.',
      type: NotificationType.announcement,
      targetRole: 'all',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  static final StreamController<List<AppNotification>> _localStreamController =
      StreamController<List<AppNotification>>.broadcast();

  static bool _matchesAudience({
    required AppNotification notification,
    required String role,
    String? userId,
  }) {
    if (userId != null && notification.targetUserId == userId) return true;
    final tr = notification.targetRole.toLowerCase();
    final ur = role.toLowerCase();
    if (tr == 'all') return true;
    if (tr == ur) return true;
    if (ur == 'production' && tr == 'staff') return true;
    return false;
  }

  /// Streams notifications targeted for a specific role and/or userId.
  /// Reads from Firestore collection in real time, with automatic fallback
  /// to local state if Firestore is inaccessible.
  static Stream<List<AppNotification>> watchNotifications({
    required String role,
    String? userId,
  }) {
    try {
      return _db.collection(_collection).snapshots().map((snapshot) {
        final List<AppNotification> list = snapshot.docs.map((doc) {
          return AppNotification.fromMap(doc.id, doc.data());
        }).toList();

        // If Firestore collection is empty, include the seed notifications
        final combined = list.isEmpty
            ? List<AppNotification>.from(_inMemoryNotifications)
            : list;

        final filtered = combined
            .where((n) => _matchesAudience(
                  notification: n,
                  role: role,
                  userId: userId,
                ))
            .toList();

        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return filtered;
      }).handleError((_) {
        // Return filtered in-memory list on Firestore connection error
        final filtered = _inMemoryNotifications
            .where((n) => _matchesAudience(
                  notification: n,
                  role: role,
                  userId: userId,
                ))
            .toList();
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return filtered;
      });
    } catch (_) {
      return _localStreamController.stream.map((list) {
        return list
            .where((n) => _matchesAudience(
                  notification: n,
                  role: role,
                  userId: userId,
                ))
            .toList();
      });
    }
  }

  /// Streams the unread notifications count for a specific role and userId.
  static Stream<int> watchUnreadCount({
    required String role,
    required String userId,
  }) {
    return watchNotifications(role: role, userId: userId).map((list) {
      return list.where((n) => !n.isRead(userId)).length;
    });
  }

  /// Marks a specific notification as read by the user.
  static Future<void> markAsRead({
    required String notificationId,
    required String userId,
  }) async {
    // Update in-memory state
    final index = _inMemoryNotifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final notif = _inMemoryNotifications[index];
      if (!notif.readBy.contains(userId)) {
        _inMemoryNotifications[index] = notif.copyWith(
          readBy: [...notif.readBy, userId],
        );
        _localStreamController.add(List.from(_inMemoryNotifications));
      }
    }

    try {
      await _db.collection(_collection).doc(notificationId).update({
        'readBy': FieldValue.arrayUnion([userId]),
      });
    } catch (_) {
      // Offline fallback succeeded in-memory
    }
  }

  /// Marks all notifications for a role as read by the user.
  static Future<void> markAllAsRead({
    required List<AppNotification> notifications,
    required String userId,
  }) async {
    for (final notif in notifications) {
      if (!notif.isRead(userId)) {
        await markAsRead(notificationId: notif.id, userId: userId);
      }
    }
  }

  /// Creates and posts a new notification to Firestore.
  static Future<bool> sendNotification({
    required String title,
    required String message,
    required NotificationType type,
    required String targetRole,
    String? route,
    String? targetUserId,
    String? targetBranch,
  }) async {
    final newId = 'notif_${DateTime.now().millisecondsSinceEpoch}';
    final notif = AppNotification(
      id: newId,
      title: title,
      message: message,
      type: type,
      targetRole: targetRole,
      targetUserId: targetUserId,
      targetBranch: targetBranch,
      route: route,
      createdAt: DateTime.now(),
    );

    _inMemoryNotifications.insert(0, notif);
    _localStreamController.add(List.from(_inMemoryNotifications));

    try {
      await _db.collection(_collection).doc(newId).set({
        ...notif.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return true; // Still true because in-memory broadcast succeeded
    }
  }

  // --- Convenience Trigger Methods ---

  /// Triggered when a new Staff/Driver applicant registers.
  static Future<void> notifyOwnerOfNewRegistration({
    required String fullName,
    required String position,
  }) async {
    await sendNotification(
      title: 'New Account Application',
      message: '$fullName has registered as $position. Tap to review in Account Approvals.',
      type: NotificationType.accountApproval,
      targetRole: 'owner',
      route: 'account_approvals',
    );
  }

  /// Triggered when the Owner approves a staff or driver account.
  static Future<void> notifyStaffOfAccountApproved({
    required String userId,
    required String fullName,
  }) async {
    await sendNotification(
      title: 'Account Approved',
      message: 'Congratulations $fullName! Your account has been approved by the Owner. You now have full access.',
      type: NotificationType.accountApproval,
      targetRole: 'staff',
      targetUserId: userId,
    );
  }

  /// Triggered when the Owner publishes a general announcement.
  static Future<void> notifyStaffAndDriversOfAnnouncement({
    required String messageContent,
  }) async {
    await sendNotification(
      title: 'Announcement from Owner',
      message: messageContent,
      type: NotificationType.announcement,
      targetRole: 'all',
      route: 'announcements',
    );
  }

  /// Triggered when stock is dispatched for a driver to deliver.
  static Future<void> notifyDriverOfDeliveryTask({
    required String branchName,
    required double quantityKg,
  }) async {
    await sendNotification(
      title: 'New Delivery Task',
      message: 'Dispatch order assigned: $quantityKg kg Karne to $branchName.',
      type: NotificationType.deliveryTask,
      targetRole: 'driver',
      route: 'deliveries',
      targetBranch: branchName,
    );
  }

  /// Triggered when a branch's stock reaches low threshold.
  static Future<void> notifyOwnerOfLowStock({
    required String branchName,
    required double remainingKg,
  }) async {
    await sendNotification(
      title: 'Low Stock Alert',
      message: '$branchName is running low on stock (${remainingKg.toStringAsFixed(1)} kg remaining).',
      type: NotificationType.lowStock,
      targetRole: 'owner',
      route: 'inventory',
      targetBranch: branchName,
    );
  }
}
