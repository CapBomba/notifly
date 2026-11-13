import 'package:drift/drift.dart';

/// Local copy of the user's notification preferences.
///
/// Allows the preferences screen to load instantly without a network call.
/// Changes are written locally first, then synced via the outbox.
class LocalPreferencesTable extends Table {
  @override
  String get tableName => 'local_preferences';

  /// The preference key — e.g. 'notifications_enabled', 'quiet_hours_start'.
  TextColumn get key => text()();

  /// String-encoded value.
  TextColumn get value => text()();

  /// When this preference was last modified.
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}
