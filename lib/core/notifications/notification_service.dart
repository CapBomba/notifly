import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

import '../config/app_config.dart';
import 'notification_payload.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _log = Logger();

  // Local notification taps
  final _tapController = StreamController<NotificationPayload>.broadcast();
  Stream<NotificationPayload> get onNotificationTapped => _tapController.stream;

  // FCM / Incoming chat notification taps (conversation_id etc.)
  final _fcmTapController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onFcmTapped => _fcmTapController.stream;

  /// Holds notification tap payload if tapped while app was terminated
  Map<String, dynamic>? pendingFcmTapPayload;

  void clearPendingFcmTap() => pendingFcmTapPayload = null;

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onLocalTap,
    );

    await _createChannels();
    await requestPermission();
    _log.i('NotificationService initialised');
  }

  // ---------------------------------------------------------------------------
  // Android channels
  // ---------------------------------------------------------------------------

  Future<void> _createChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(const AndroidNotificationChannel(
      AppConfig.defaultChannelId,
      AppConfig.defaultChannelName,
      description: AppConfig.defaultChannelDescription,
      importance: Importance.defaultImportance,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      AppConfig.urgentChannelId,
      AppConfig.urgentChannelName,
      description: AppConfig.urgentChannelDescription,
      importance: Importance.high,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      AppConfig.chatChannelId,
      AppConfig.chatChannelName,
      description: AppConfig.chatChannelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ));
  }

  // ---------------------------------------------------------------------------
  // Show Heads-Up Chat Notification (Pops up at top of Android screen)
  // ---------------------------------------------------------------------------

  Future<void> showChatHeadsUpNotification({
    required int id,
    required String title,
    required String body,
    required String conversationId,
    required String senderName,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      AppConfig.chatChannelId,
      AppConfig.chatChannelName,
      channelDescription: AppConfig.chatChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final payloadMap = {
      'conversation_id': conversationId,
      'sender_name': senderName,
    };

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(payloadMap),
    );
  }

  // ---------------------------------------------------------------------------
  // Generic notification fallback
  // ---------------------------------------------------------------------------

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    bool urgent = false,
    bool isChat = false,
    String? payloadJson,
  }) async {
    final channelId = isChat
        ? AppConfig.chatChannelId
        : urgent
            ? AppConfig.urgentChannelId
            : AppConfig.defaultChannelId;

    final channelName = isChat
        ? AppConfig.chatChannelName
        : urgent
            ? AppConfig.urgentChannelName
            : AppConfig.defaultChannelName;

    final importance = (urgent || isChat) ? Importance.max : Importance.defaultImportance;
    final priority = (urgent || isChat) ? Priority.max : Priority.defaultPriority;

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: importance,
          priority: priority,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payloadJson,
    );
  }

  // ---------------------------------------------------------------------------
  // Tap handlers
  // ---------------------------------------------------------------------------

  void _onLocalTap(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic> && json.containsKey('conversation_id')) {
        handleFcmTap(json);
      } else {
        _tapController.add(NotificationPayload.fromJson(raw));
      }
    } catch (e) {
      _log.w('Could not parse local notification payload: $e');
    }
  }

  /// Called by FcmService when the user taps an FCM notification or local notification.
  void handleFcmTap(Map<String, dynamic> data) {
    pendingFcmTapPayload = data;
    _fcmTapController.add(data);
  }

  // ---------------------------------------------------------------------------
  // Permission
  // ---------------------------------------------------------------------------

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  Future<void> cancelAll() => _plugin.cancelAll();
  Future<void> cancel(int id) => _plugin.cancel(id);

  void dispose() {
    _tapController.close();
    _fcmTapController.close();
  }
}
