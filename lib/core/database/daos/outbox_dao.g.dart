// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outbox_dao.dart';

// ignore_for_file: type=lint
mixin _$OutboxDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalOutboxTableTable get localOutboxTable =>
      attachedDatabase.localOutboxTable;
  OutboxDaoManager get managers => OutboxDaoManager(this);
}

class OutboxDaoManager {
  final _$OutboxDaoMixin _db;
  OutboxDaoManager(this._db);
  $$LocalOutboxTableTableTableManager get localOutboxTable =>
      $$LocalOutboxTableTableTableManager(
        _db.attachedDatabase,
        _db.localOutboxTable,
      );
}
