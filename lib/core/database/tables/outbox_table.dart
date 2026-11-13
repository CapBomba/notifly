import 'package:drift/drift.dart';

/// Transactional outbox — stores events that must be sent to Supabase
/// even if the network was unavailable at the time they were created.
///
/// The OutboxSyncService reads this table and replays events when connectivity
/// is restored, marking them as processed upon success.
class LocalOutboxTable extends Table {
  @override
  String get tableName => 'local_outbox';

  /// Client-generated UUID.
  TextColumn get id => text()();

  /// Event name — e.g. 'notification.read', 'preference.updated'.
  TextColumn get eventType => text()();

  /// JSON-serialised payload to send to Supabase.
  TextColumn get payload => text()();

  /// How many times this event has been attempted.
  IntColumn get attemptCount =>
      integer().withDefault(const Constant(0))();

  /// 'pending' | 'processing' | 'failed' | 'processed'
  TextColumn get status =>
      text().withDefault(const Constant('pending'))();

  /// Optional human-readable error from the last failed attempt.
  TextColumn get lastError => text().nullable()();

  /// When the event was created locally.
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// When to next attempt delivery (for exponential back-off).
  DateTimeColumn get nextRetryAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
