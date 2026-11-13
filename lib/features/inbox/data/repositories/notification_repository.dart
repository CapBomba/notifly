import 'dart:async';

import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/notifications/notification_payload.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../domain/models/notification_model.dart';
import '../mappers/notification_mapper.dart';

/// Repository that mediates between Supabase, the local Drift cache,
/// and the NotificationService.
///
/// Responsibilities:
/// - Initial inbox sync from Supabase on login.
/// - Subscribe to Supabase Realtime for live updates.
/// - Write through to Drift for offline access.
/// - Enqueue read-receipts in the local outbox for eventual delivery.
class NotificationRepository {
  NotificationRepository({
    required this.userId,
    SupabaseClient? client,
    AppDatabase? database,
  })  : _client = client ?? Supabase.instance.client,
        _db = database ?? AppDatabase.instance;

  final String userId;
  final SupabaseClient _client;
  final AppDatabase _db;
  final _log = Logger();

  RealtimeChannel? _channel;

  // ---------------------------------------------------------------------------
  // Reactive stream from local cache
  // ---------------------------------------------------------------------------

  /// Watch the local cache — the single source of truth for the UI.
  Stream<List<NotificationModel>> watchNotifications() =>
      _db.notificationsDao
          .watchAll(userId)
          .map((rows) => rows.map(NotificationMapper.fromRow).toList());

  // ---------------------------------------------------------------------------
  // Initial sync
  // ---------------------------------------------------------------------------

  /// Fetch the latest 50 notifications and seed the local cache.
  Future<void> syncFromRemote() async {
    try {
      final rows = await _client
          .from(AppConfig.notificationsTable)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final models = rows
          .map((r) => NotificationModel.fromSupabase(r))
          .toList();

      final companions =
          models.map(NotificationMapper.toCompanion).toList();

      await _db.notificationsDao.upsertAll(companions);
      _log.i('Synced ${models.length} notifications from Supabase');
    } catch (e, st) {
      _log.e('syncFromRemote failed', error: e, stackTrace: st);
      // Non-fatal — local cache is still available.
    }
  }

  // ---------------------------------------------------------------------------
  // Realtime subscription
  // ---------------------------------------------------------------------------

  /// Subscribe to Supabase Realtime for new notifications.
  ///
  /// When an INSERT arrives, the notification is stored in the local cache
  /// and a system notification is shown (if app is foregrounded).
  void subscribeRealtime() {
    _channel = _client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: AppConfig.notificationsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _handleInsert(payload.newRecord),
        )
        .subscribe((status, [error]) {
      _log.i('Realtime channel status: $status');
      if (error != null) _log.e('Realtime error', error: error);
    });
  }

  Future<void> _handleInsert(Map<String, dynamic> record) async {
    try {
      final model = NotificationModel.fromSupabase(record);
      await _db.notificationsDao
          .upsertNotification(NotificationMapper.toCompanion(model));

      // Derive a stable int id from the UUID for the local notification.
      final notifId = model.id.hashCode.abs();

      await NotificationService.instance.showNotification(
        id: notifId,
        title: model.title,
        body: model.body,
        urgent: model.isUrgent,
        payloadJson: NotificationPayload(
          notificationId: model.id,
          type: model.type,
        ).toJson(),
      );

      _log.d('Handled Realtime INSERT for notification ${model.id}');
    } catch (e, st) {
      _log.e('_handleInsert failed', error: e, stackTrace: st);
    }
  }

  // ---------------------------------------------------------------------------
  // Mark read (write-through with outbox)
  // ---------------------------------------------------------------------------

  /// Mark a notification as read locally, then enqueue the event for remote
  /// delivery via the outbox.
  Future<void> markRead(String notificationId) async {
    // 1. Optimistic local update.
    await _db.notificationsDao.markRead(notificationId);

    // 2. Enqueue outbox event.
    await _enqueueOutboxEvent(
      eventType: 'notification.read',
      payload: '{"notification_id":"$notificationId"}',
    );
  }

  /// Mark all notifications as read.
  Future<void> markAllRead() async {
    await _db.notificationsDao.markAllRead(userId);
    await _enqueueOutboxEvent(
      eventType: 'notifications.read_all',
      payload: '{"user_id":"$userId"}',
    );
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  Future<void> deleteNotification(String notificationId) async {
    await _db.notificationsDao.deleteById(notificationId);
    await _enqueueOutboxEvent(
      eventType: 'notification.deleted',
      payload: '{"notification_id":"$notificationId"}',
    );
  }

  // ---------------------------------------------------------------------------
  // Outbox helper
  // ---------------------------------------------------------------------------

  Future<void> _enqueueOutboxEvent({
    required String eventType,
    required String payload,
  }) async {
    final id = const Uuid().v4();
    await _db.outboxDao.addEvent(
      LocalOutboxTableCompanion.insert(
        id: id,
        eventType: eventType,
        payload: payload,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  Future<void> dispose() async {
    await _client.removeChannel(_channel!);
    _log.i('Realtime channel unsubscribed');
  }
}
