import 'package:drift/drift.dart';

/// Local cache of notifications received from Supabase Realtime.
///
/// This mirrors the shape of the `notifications` table in Postgres so that the
/// app can display the inbox without a network connection.
class LocalNotificationsTable extends Table {
  @override
  String get tableName => 'local_notifications';

  /// UUID from the remote Postgres row — used as the idempotency key.
  TextColumn get id => text()();

  /// UUID of the user who owns this notification.
  TextColumn get userId => text()();

  /// Display title.
  TextColumn get title => text()();

  /// Full notification body.
  TextColumn get body => text()();

  /// Semantic type — e.g. 'message', 'announcement', 'task_update'.
  TextColumn get type => text().withDefault(const Constant('generic'))();

  /// Optional JSON payload for deep-linking or extra context.
  TextColumn get payload => text().nullable()();

  /// Whether the user has opened/read this notification.
  BoolColumn get isRead =>
      boolean().withDefault(const Constant(false))();

  /// Priority level: 0 = normal, 1 = high, 2 = urgent.
  IntColumn get priority => integer().withDefault(const Constant(0))();

  /// UTC timestamp from the remote server.
  DateTimeColumn get createdAt => dateTime()();

  /// When it was synced locally.
  DateTimeColumn get syncedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
