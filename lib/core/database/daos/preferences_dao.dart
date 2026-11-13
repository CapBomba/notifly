import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/preferences_table.dart';

part 'preferences_dao.g.dart';

/// Data-access object for local notification preferences.
@DriftAccessor(tables: [LocalPreferencesTable])
class PreferencesDao extends DatabaseAccessor<AppDatabase>
    with _$PreferencesDaoMixin {
  PreferencesDao(super.db);

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  Future<String?> getValue(String key) async {
    final row = await (select(localPreferencesTable)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final v = await getValue(key);
    if (v == null) return defaultValue;
    return v == 'true';
  }

  Future<int?> getInt(String key) async {
    final v = await getValue(key);
    return v == null ? null : int.tryParse(v);
  }

  Stream<String?> watchValue(String key) =>
      (select(localPreferencesTable)..where((t) => t.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  Future<void> setValue(String key, String value) =>
      into(localPreferencesTable).insertOnConflictUpdate(
        LocalPreferencesTableCompanion(
          key: Value(key),
          value: Value(value),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> setBool(String key, {required bool value}) =>
      setValue(key, value.toString());

  Future<void> setInt(String key, int value) =>
      setValue(key, value.toString());

  Future<int> clearAll() => delete(localPreferencesTable).go();
}
