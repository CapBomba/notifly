// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preferences_dao.dart';

// ignore_for_file: type=lint
mixin _$PreferencesDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalPreferencesTableTable get localPreferencesTable =>
      attachedDatabase.localPreferencesTable;
  PreferencesDaoManager get managers => PreferencesDaoManager(this);
}

class PreferencesDaoManager {
  final _$PreferencesDaoMixin _db;
  PreferencesDaoManager(this._db);
  $$LocalPreferencesTableTableTableManager get localPreferencesTable =>
      $$LocalPreferencesTableTableTableManager(
        _db.attachedDatabase,
        _db.localPreferencesTable,
      );
}
