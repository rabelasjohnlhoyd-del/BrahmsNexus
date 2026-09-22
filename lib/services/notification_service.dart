import 'dart:async';
import 'package:flutter/foundation.dart';
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
    String? position,
  }) {
    if (userId != null && notification.targetUserId == userId) return true;
    final tr = notification.targetRole.toLowerCase().trim();
    final ur = role.toLowerCase().trim();
    final up = (position ?? '').toLowerCase().trim();

    if (tr == 'all' || tr == 'all positions') return true;
    if (tr == ur) return true;
    if (up.isNotEmpty && tr == up) return true;
    if (ur == 'production' && tr == 'staff') return true;
    return false;
  }

  /// Streams notifications targeted for a specific role and/or userId.
  /// Reads from Firestore collection in real time, with automatic fallback
  /// to local state if Firestore is inaccessible.
  static Stream<List<AppNotification>> watchNotifications({
    required String role,
    String? userId,
    String? position,
  }) {
    try {
      // Basic query to fetch recent notifications. 
      // Fetching everything without a query might hit Firestore limits or trigger security rule rejections 
      // if the collection grows too large or rules require specific filters.
      return _db
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .limit(100) // Keep the real-time sync bounded
          .snapshots()
          .map((snapshot) {
        final List<AppNotification> list = [];
        for (final doc in snapshot.docs) {
          try {
            list.add(AppNotification.fromMap(doc.id, doc.data()));
          } catch (e) {
            // Log or handle individual doc parsing error so one corrupted document doesn't break the entire stream
            debugPrint('Error parsing notification document ${doc.id}: $e');
          }
        }

        // Include seed notifications along with any live records if available, or if collection is empty
        // We put in-memory first so they are overwritten by Firestore records in the map
        final combined = [..._inMemoryNotifications, ...list];

        // Deduplicate by ID favoring firestore ones (last one in wins)
        final Map<String, AppNotification> uniqueMap = {};
        for (final item in combined) {
          uniqueMap[item.id] = item;
        }

        final filtered = uniqueMap.values
            .where((n) => _matchesAudience(
                  notification: n,
                  role: role,
                  userId: userId,
                  position: position,
                ))
            .toList();

        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return filtered;
      }).handleError((error) {
        debugPrint('Firestore notifications stream error: $error');
        // Fallback to filtered in-memory list on Firestore stream error but preserve any known updates
        final filtered = _inMemoryNotifications
            .where((n) => _matchesAudience(
                  notification: n,
                  role: role,
                  userId: userId,
                  position: position,
                ))
            .toList();
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return filtered;
      });
    } catch (e) {
      debugPrint('Firestore notifications watch catch error: $e');
      return _localStreamController.stream.map((list) {
        return list
            .where((n) => _matchesAudience(
                  notification: n,
                  role: role,
                  userId: userId,
                  position: position,
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
    String? username,
  }) async {
    // Update in-memory state
    final index = _inMemoryNotifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final notif = _inMemoryNotifications[index];
      if (!notif.isRead(userId, username)) {
        final List<String> updatedReadBy = List.from(notif.readBy);
        if (!updatedReadBy.contains(userId)) updatedReadBy.add(userId);
        if (username != null && !updatedReadBy.contains(username)) updatedReadBy.add(username);

        _inMemoryNotifications[index] = notif.copyWith(
          readBy: updatedReadBy,
        );
        _localStreamController.add(List.from(_inMemoryNotifications));
      }
    }

    try {
      final List<String> updates = [userId];
      if (username != null) updates.add(username);
      await _db.collection(_collection).doc(notificationId).update({
        'readBy': FieldValue.arrayUnion(updates),
      });
    } catch (_) {
      // Offline fallback succeeded in-memory
    }
  }

  /// Marks all notifications for a role as read by the user.
  static Future<void> markAllAsRead({
    required List<AppNotification> notifications,
    required String userId,
    String? username,
  }) async {
    final unread = notifications.where((n) => !n.isRead(userId, username)).toList();
    if (unread.isEmpty) return;

    await Future.wait(unread.map((notif) => markAsRead(
          notificationId: notif.id,
          userId: userId,
          username: username,
        )));
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

  /// Triggered when the Owner publishes an announcement.
  static Future<void> notifyStaffAndDriversOfAnnouncement({
    required String messageContent,
    String targetPosition = 'All Positions',
  }) async {
    await sendNotification(
      title: 'Announcement from Owner',
      message: messageContent,
      type: NotificationType.announcement,
      targetRole: targetPosition.toLowerCase(),
      route: 'announcements',
    );
  }

  /// Triggered when stock is dispatched for a driver to deliver.
  static Future<void> notifyDriverOfDeliveryTask({
    required String branchName,
    required double quantityKg,
    String? itemsSummary,
  }) async {
    final desc = itemsSummary != null && itemsSummary.isNotEmpty
        ? itemsSummary
        : '${quantityKg.toStringAsFixed(1)} kg Karne';
    await sendNotification(
      title: 'New Delivery Task',
      message: 'Dispatch order assigned: $desc to $branchName.',
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

  /// Triggered when the Driver notifies staff they are "On the way" for deployment or retrieval.
  static Future<void> notifyStaffDriverOnTheWay({
    required String staffName,
    required String branchName,
    required String mode,
    String? staffId,
    String? staffUsername,
    String? driverName,
  }) async {
    final isDeployment = mode.toLowerCase() == 'deployment';
    final actionText = isDeployment ? 'morning deployment (hatid)' : 'evening retrieval (sundo)';
    final dName = (driverName != null && driverName.isNotEmpty) ? driverName : 'Driver';
    await sendNotification(
      title: 'Driver is On The Way',
      message: '$dName is on the way to $branchName for $actionText ($staffName).',
      type: NotificationType.deliveryTask,
      targetRole: 'staff',
      targetBranch: branchName,
      route: 'notifications',
    );
  }

  /// Triggered when the Driver drops off a staff member at a branch during deployment.
  static Future<void> notifyOwnerStaffDroppedOff({
    required String staffName,
    required String branchName,
    String? driverName,
  }) async {
    final dName = (driverName != null && driverName.isNotEmpty) ? driverName : 'Driver';
    await sendNotification(
      title: 'Staff Dropped Off - $branchName',
      message: '$staffName has been safely dropped off at $branchName by $dName for deployment.',
      type: NotificationType.deliveryTask,
      targetRole: 'owner',
      targetBranch: branchName,
      route: 'assignments',
    );
  }

  /// Triggered when the Driver picks up a staff member from a branch during retrieval.
  static Future<void> notifyOwnerStaffPickedUp({
    required String staffName,
    required String branchName,
    String? driverName,
  }) async {
    final dName = (driverName != null && driverName.isNotEmpty) ? driverName : 'Driver';
    await sendNotification(
      title: 'Staff Picked Up - $branchName',
      message: '$staffName has been picked up from $branchName by $dName for retrieval.',
      type: NotificationType.deliveryTask,
      targetRole: 'owner',
      targetBranch: branchName,
      route: 'assignments',
    );
  }
}
