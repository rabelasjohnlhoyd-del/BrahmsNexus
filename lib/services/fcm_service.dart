import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import '../models/user_role.dart';

// ── Android Notification Channel ──────────────────────────────────────────────
/// The channel used for all BrahmsNexus operational alerts.
/// Must match: AndroidManifest.xml  com.google.firebase.messaging.default_notification_channel_id
const AndroidNotificationChannel _kChannel = AndroidNotificationChannel(
  'brahms_operational_alerts', // channel ID (must match Manifest meta-data)
  'Operational Alerts', // channel name shown in Android Settings
  description: 'Real-time alerts for deliveries, announcements, and stock updates.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  enableLights: true,
);

// ── Local Notifications plugin instance ───────────────────────────────────────
final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();

/// In-memory cache to deduplicate push alerts arriving simultaneously via
/// both role topic broadcast and direct device token dispatch.
final Set<String> _recentNotifKeys = <String>{};

/// Top-level background message handler invoked by Android OS when a push
/// notification arrives while the application is terminated or in the background.
///
/// Must be annotated with `@pragma('vm:entry-point')` to prevent tree-shaking
/// in release builds.
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  // Invoked when app is terminated or swiped away from Recent Apps.
  // Explicitly triggers a local heads-up notification so the banner appears
  // on the status bar and lockscreen even on aggressive Android skins like XOS/MIUI.
  try {
    // 1. Stale message guard: Ignore queued backlog messages older than 10 minutes
    if (message.sentTime != null) {
      final age = DateTime.now().difference(message.sentTime!);
      if (age.inMinutes > 10) {
        debugPrint('FCM: Safely skipped stale queued notification (${age.inMinutes}m old).');
        return;
      }
    }

    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'Brahms Nexus Alert';
    final body = notification?.body ?? message.data['body'] ?? message.data['message'] ?? '';

    // 2. Duplicate suppression (e.g. topic + direct token dual arrivals)
    final dedupeKey = message.data['notificationId'] ?? message.messageId ?? '${title}_$body';
    if (_recentNotifKeys.contains(dedupeKey)) {
      debugPrint('FCM: Suppressing duplicate background notification for key: $dedupeKey');
      return;
    }
    _recentNotifKeys.add(dedupeKey);
    if (_recentNotifKeys.length > 50) {
      _recentNotifKeys.remove(_recentNotifKeys.first);
    }

    if (title.isNotEmpty || body.isNotEmpty) {
      final localNotif = FlutterLocalNotificationsPlugin();
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await localNotif.initialize(initSettings);

      const channel = AndroidNotificationChannel(
        'brahms_operational_alerts',
        'Operational Alerts',
        description: 'Real-time alerts for deliveries, announcements, and stock updates.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );

      await localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      final stableId = dedupeKey.hashCode.abs() % 100000;
      await localNotif.show(
        stableId,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'brahms_operational_alerts',
            'Operational Alerts',
            channelDescription: 'Real-time alerts for deliveries, announcements, and stock updates.',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  } catch (e) {
    debugPrint('FCM: Background notification show error: $e');
  }
}

/// Central coordinator for Firebase Cloud Messaging (FCM) push notifications
/// in Brahms Nexus.
///
/// Features:
/// - Native Android system-tray & lock-screen push alerts (foreground + background)
/// - Role-based topic subscriptions (drivers, production, all_staff, admin_alerts)
/// - Device token registration in Cloud Firestore and Supabase
/// - Zero-cost Supabase Edge Function dispatch integration
class FcmService {
  const FcmService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static bool _isInitialized = false;
  static String? _cachedToken;

  /// Returns the current device FCM token, if available.
  static String? get currentToken => _cachedToken;

  // ── 1. Initialization ──────────────────────────────────────────────────────
  /// Initializes FCM listeners, Android notification channel, requests OS
  /// permissions, and registers the background message handler.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Register top-level background message handler (Mobile only)
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);
      }

      // 2. Request notification permission (Required for Android 13+ & iOS)
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
          'FCM: Permission authorization status: ${settings.authorizationStatus}');

      // 3. Create Android notification channel (must happen before any push is shown)
      if (!kIsWeb) {
        await _localNotif
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_kChannel);
      }

      // 4. Initialize flutter_local_notifications plugin for foreground display
      if (!kIsWeb) {
        const initSettings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        );
        await _localNotif.initialize(initSettings);
      }

      // 5. Configure foreground presentation options (so alerts show while app is open)
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 6. Retrieve initial token (safely wrapped for web/mobile)
      try {
        _cachedToken = await _messaging.getToken();
        if (_cachedToken != null) {
          debugPrint(
              'FCM: Device Token acquired: ${_cachedToken!.substring(0, 10)}...');
        }
      } catch (tokenErr) {
        debugPrint('FCM: Token retrieval note (safely skipped): $tokenErr');
      }

      // 7. Listen to token refreshes
      _messaging.onTokenRefresh.listen((newToken) {
        _cachedToken = newToken;
        debugPrint('FCM: Token refreshed by Google Play Services');
      });

      // 8. Foreground message listener — show local notification when app is open
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
            'FCM: Foreground message received: ${message.notification?.title}');
        _showLocalNotification(message);
      });

      // 9. Notification tap handler (User tapped notification in tray)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM: App opened from notification tray: ${message.data}');
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('FCM: Initialization error (graceful fallback): $e');
    }
  }

  // ── Internal: Display local notification banner ────────────────────────────
  /// Shows a heads-up (foreground) notification banner using flutter_local_notifications.
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    if (kIsWeb) return;

    // 1. Stale message guard: Ignore queued backlog messages older than 10 minutes
    if (message.sentTime != null) {
      final age = DateTime.now().difference(message.sentTime!);
      if (age.inMinutes > 10) {
        debugPrint('FCM: Safely skipped stale foreground notification (${age.inMinutes}m old).');
        return;
      }
    }

    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? '';
    final body = notification?.body ?? message.data['body'] ?? message.data['message'] ?? '';
    if (title.isEmpty && body.isEmpty) return;

    // 2. Duplicate suppression
    final dedupeKey = message.data['notificationId'] ?? message.messageId ?? '${title}_$body';
    if (_recentNotifKeys.contains(dedupeKey)) {
      debugPrint('FCM: Suppressing duplicate foreground notification for key: $dedupeKey');
      return;
    }
    _recentNotifKeys.add(dedupeKey);
    if (_recentNotifKeys.length > 50) {
      _recentNotifKeys.remove(_recentNotifKeys.first);
    }

    try {
      final stableId = dedupeKey.hashCode.abs() % 100000;
      await _localNotif.show(
        stableId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannel.id,
            _kChannel.name,
            channelDescription: _kChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    } catch (e) {
      debugPrint('FCM: Local notification display error: $e');
    }
  }

  // ── 2. User Token & Topic Synchronization ──────────────────────────────────
  /// Associates the device's FCM token with the authenticated user and
  /// subscribes to role-specific broadcast topics.
  static Future<void> syncUserToken(AppUser user) async {
    try {
      _cachedToken ??= await _messaging.getToken();
      final token = _cachedToken;
      if (token == null || token.isEmpty) return;

      final targetId = user.uid.isNotEmpty ? user.uid : user.username;
      if (targetId.isEmpty) return;

      // A. Save token to Firestore users collection
      try {
        await _firestore.collection('users').doc(targetId).set({
          'fcmToken': token,
          'fcmPlatform': defaultTargetPlatform.name,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
          'role': user.role.name,
          'position': user.position,
        }, SetOptions(merge: true));
      } catch (fsErr) {
        debugPrint('FCM: Firestore token sync note: $fsErr');
      }

      // B. Save token to Supabase if table exists
      try {
        final client = Supabase.instance.client;
        await client.from('user_fcm_tokens').upsert({
          'user_id': targetId,
          'fcm_token': token,
          'platform': defaultTargetPlatform.name,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // Table is optional; ignore if not created in Supabase schema
      }

      // C. Subscribe to Role-Based Broadcast Topics (Mobile only)
      if (!kIsWeb) {
        // Universal announcements topic
        await _messaging.subscribeToTopic('all_staff');

        if (user.role == UserRole.owner) {
          await _messaging.subscribeToTopic('admin_alerts');
        }

        final pos = user.position.toLowerCase();
        if (pos.contains('driver')) {
          await _messaging.subscribeToTopic('drivers');
        } else if (pos.contains('cutter') || pos.contains('production')) {
          await _messaging.subscribeToTopic('production');
        } else if (pos.contains('cook') || pos.contains('branch')) {
          await _messaging.subscribeToTopic('branch_cook');
        }
      }

      debugPrint('FCM: User $targetId topics & token synchronized successfully.');
    } catch (e) {
      debugPrint('FCM: syncUserToken error (non-blocking): $e');
    }
  }

  // ── 3. Token Cleanup on Sign-Out ───────────────────────────────────────────
  /// Unsubscribes from topics and removes token upon logout to prevent
  /// cross-account notification leakage.
  static Future<void> clearUserToken([String? userId]) async {
    try {
      if (!kIsWeb) {
        await _messaging.unsubscribeFromTopic('all_staff');
        await _messaging.unsubscribeFromTopic('admin_alerts');
        await _messaging.unsubscribeFromTopic('drivers');
        await _messaging.unsubscribeFromTopic('production');
        await _messaging.unsubscribeFromTopic('branch_cook');
      }

      if (userId != null && userId.isNotEmpty) {
        try {
          await _firestore.collection('users').doc(userId).update({
            'fcmToken': FieldValue.delete(),
          });
        } catch (_) {}
      }
      debugPrint('FCM: User session unsubscribed and cleared.');
    } catch (e) {
      debugPrint('FCM: clearUserToken note: $e');
    }
  }

  // ── 4. Free Supabase Edge Function Push Dispatcher ─────────────────────────
  /// Dispatches a push notification via Supabase Edge Function (Zero-cost,
  /// no Google Cloud Billing / Credit Card required).
  ///
  /// Automatically fetches registered device tokens from Cloud Firestore to
  /// deliver direct device-level pushes alongside topic broadcasts for 100%
  /// instant lock-screen & system-tray alerts.
  ///
  /// Parameters:
  /// - [topic]: Optional target topic (e.g. 'drivers', 'all_staff', 'admin_alerts')
  /// - [targetUserId]: Optional target specific user
  /// - [title]: Push notification title
  /// - [body]: Push notification message body
  /// - [data]: Optional payload data for deep linking (all values must be strings)
  static Future<bool> sendPushViaSupabase({
    String? topic,
    String? targetUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final client = Supabase.instance.client;

      // Convert all data values to strings (FCM data payload requires String values)
      final Map<String, String> stringData = (data ?? {}).map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );

      // Collect direct device tokens from Firestore for instant lock-screen delivery
      final List<String> directTokens = [];
      try {
        if (targetUserId != null && targetUserId.isNotEmpty) {
          final doc = await _firestore.collection('users').doc(targetUserId).get();
          final token = doc.data()?['fcmToken'] as String?;
          if (token != null && token.isNotEmpty) {
            directTokens.add(token);
          }
        } else {
          // Broadcast: collect tokens of all registered staff/drivers
          final snapshot = await _firestore
              .collection('users')
              .where('fcmToken', isNull: false)
              .limit(50)
              .get();
          for (final doc in snapshot.docs) {
            final token = doc.data()['fcmToken'] as String?;
            if (token != null && token.isNotEmpty && !directTokens.contains(token)) {
              directTokens.add(token);
            }
          }
        }
      } catch (tokenFetchErr) {
        debugPrint('FCM: Token discovery note (falling back to topic): $tokenFetchErr');
      }

      final response = await client.functions.invoke(
        'send-fcm-push',
        body: {
          'title': title,
          'body': body,
          'data': stringData,
          'topic': topic,
          'targetUserId': targetUserId,
          'tokens': directTokens,
        }..removeWhere((_, v) => v == null),
      );

      debugPrint('FCM: Supabase Edge Function response status: ${response.status} (targeted ${directTokens.length} direct devices)');
      return response.status == 200;
    } catch (e) {
      debugPrint('FCM: Supabase Edge Function invocation note: $e');
      return false;
    }
  }
}
