import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../notifications/notification_service.dart';

/// Top-level handler for FCM background/terminated messages.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // firebase_messaging background isolate — show a local notification.
  // NotificationService.instance is NOT available here; use the plugin directly.
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  final notification = message.notification;
  final title = notification?.title ??
      (message.data['sender_name'] as String? ?? 'New Message');
  final body = notification?.body ??
      (message.data['body'] as String? ?? message.data['content'] as String? ?? 'New message received');

  await plugin.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        AppConfig.chatChannelId,
        AppConfig.chatChannelName,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
      ),
    ),
    payload: jsonEncode(message.data),
  );
}

/// Manages FCM token registration, permission requests, and foreground
/// message handling.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _messaging = FirebaseMessaging.instance;
  final _log = Logger();

  // ---------------------------------------------------------------------------
  // Initialise
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    // Request permission (iOS + Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    _log.i('FCM permission: ${settings.authorizationStatus}');

    // Register the background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground messages — show via NotificationService
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Notification tap when app was in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Notification tap when app was completely terminated/destroyed
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }

    // Save token if user is signed in
    await saveCurrentToken();

    // Listen for auth changes to re-sync token
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session?.user != null) {
        saveCurrentToken();
      }
    });

    // Refresh on token rotation
    _messaging.onTokenRefresh.listen(_saveToken);
  }

  Future<void> saveCurrentToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      _log.e('Failed to get FCM token', error: e);
    }
  }

  // ---------------------------------------------------------------------------
  // Foreground handler
  // ---------------------------------------------------------------------------

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _log.d('FCM foreground: ${message.messageId}');
    final notification = message.notification;
    if (notification == null) return;

    await NotificationService.instance.showNotification(
      id: message.hashCode,
      title: notification.title ?? 'New Message',
      body: notification.body ?? '',
      urgent: message.data['priority'] == 'urgent',
      payloadJson: jsonEncode(message.data),
    );
  }

  // ---------------------------------------------------------------------------
  // Tap handler
  // ---------------------------------------------------------------------------

  void _handleMessageTap(RemoteMessage message) {
    _log.d('FCM tap: ${message.data}');
    // Deep-link handled by the router via notificationTapStream
    NotificationService.instance.handleFcmTap(message.data);
  }

  // ---------------------------------------------------------------------------
  // Save token to Supabase
  // ---------------------------------------------------------------------------

  Future<void> _saveToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from(AppConfig.fcmTokensTable).upsert({
        'user_id': user.id,
        'token': token,
        'platform': 'android',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,token');
      _log.i('FCM token saved');
    } catch (e) {
      _log.e('Failed to save FCM token', error: e);
    }
  }

  /// Call after sign-out to remove the token from Supabase.
  Future<void> deleteToken() async {
    final user = Supabase.instance.client.auth.currentUser;
    final token = await _messaging.getToken();
    if (user == null || token == null) return;

    await Supabase.instance.client
        .from(AppConfig.fcmTokensTable)
        .delete()
        .eq('user_id', user.id)
        .eq('token', token);
    await _messaging.deleteToken();
  }
}
