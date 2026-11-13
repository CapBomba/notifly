// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_dao.dart';

// ignore_for_file: type=lint
mixin _$NotificationsDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalNotificationsTableTable get localNotificationsTable =>
      attachedDatabase.localNotificationsTable;
  NotificationsDaoManager get managers => NotificationsDaoManager(this);
}

class NotificationsDaoManager {
  final _$NotificationsDaoMixin _db;
  NotificationsDaoManager(this._db);
  $$LocalNotificationsTableTableTableManager get localNotificationsTable =>
      $$LocalNotificationsTableTableTableManager(
        _db.attachedDatabase,
        _db.localNotificationsTable,
      );
}
