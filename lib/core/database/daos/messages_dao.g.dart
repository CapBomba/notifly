// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'messages_dao.dart';

// ignore_for_file: type=lint
mixin _$MessagesDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalMessagesTableTable get localMessagesTable =>
      attachedDatabase.localMessagesTable;
  MessagesDaoManager get managers => MessagesDaoManager(this);
}

class MessagesDaoManager {
  final _$MessagesDaoMixin _db;
  MessagesDaoManager(this._db);
  $$LocalMessagesTableTableTableManager get localMessagesTable =>
      $$LocalMessagesTableTableTableManager(
        _db.attachedDatabase,
        _db.localMessagesTable,
      );
}
