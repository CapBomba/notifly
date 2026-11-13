import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';

/// Periodically drains the local outbox by replaying events to Supabase.
///
/// Lifecycle:
/// - Call [start] after the user signs in.
/// - Call [stop] before the user signs out.
///
/// Retry policy: exponential back-off up to 60 minutes.
/// After [maxAttempts] failures the event is marked as permanently failed
/// and will not be retried automatically.
class OutboxSyncService {
  OutboxSyncService({
    SupabaseClient? client,
    AppDatabase? database,
    this.pollInterval = const Duration(seconds: 30),
    this.maxAttempts = 5,
  })  : _client = client ?? Supabase.instance.client,
        _db = database ?? AppDatabase.instance;

  final SupabaseClient _client;
  final AppDatabase _db;
  final Duration pollInterval;
  final int maxAttempts;

  final _log = Logger();

  Timer? _timer;
  bool _running = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  void start() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(pollInterval, (_) => _flush());
    _log.i('OutboxSyncService started (interval: $pollInterval)');
    // Flush immediately on start.
    _flush();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    _log.i('OutboxSyncService stopped');
  }

  // ---------------------------------------------------------------------------
  // Flush
  // ---------------------------------------------------------------------------

  Future<void> _flush() async {
    final outboxDao = _db.outboxDao;
    final pending = await outboxDao.getPending();
    if (pending.isEmpty) return;

    _log.d('OutboxSyncService: flushing ${pending.length} event(s)');

    for (final event in pending) {
      try {
        await _dispatch(event.eventType, event.payload);
        await outboxDao.markProcessed(event.id);
        _log.d('Outbox event ${event.id} (${event.eventType}) processed');
      } catch (e) {
        _log.w(
          'Outbox event ${event.id} failed (attempt ${event.attemptCount + 1})',
          error: e,
        );

        if (event.attemptCount + 1 >= maxAttempts) {
          await outboxDao.markFailed(event.id);
          _log.e('Outbox event ${event.id} permanently failed after $maxAttempts attempts');
        } else {
          await outboxDao.recordFailure(
            id: event.id,
            attemptCount: event.attemptCount,
            error: e.toString(),
          );
        }
      }
    }

    // Prune processed events older than 7 days.
    await outboxDao.pruneProcessed(
      DateTime.now().subtract(const Duration(days: 7)),
    );
  }

  // ---------------------------------------------------------------------------
  // Dispatch individual event types to Supabase
  // ---------------------------------------------------------------------------

  Future<void> _dispatch(String eventType, String payloadJson) async {
    final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

    switch (eventType) {
      case 'notification.read':
        final id = payload['notification_id'] as String;
        await _client
            .from('notifications')
            .update({'is_read': true})
            .eq('id', id);

      case 'notifications.read_all':
        final userId = payload['user_id'] as String;
        await _client
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', userId);

      case 'notification.deleted':
        final id = payload['notification_id'] as String;
        await _client.from('notifications').delete().eq('id', id);

      case 'preference.updated':
        final userId = payload['user_id'] as String;
        final key = payload['key'] as String;
        final value = payload['value'] as String;
        await _client.from('notification_preferences').upsert({
          'user_id': userId,
          'key': key,
          'value': value,
          'updated_at': DateTime.now().toIso8601String(),
        });

      default:
        // Unknown event — log and skip (don't throw so we can mark processed).
        _log.w('Unknown outbox event type: $eventType — skipping');
    }
  }
}
