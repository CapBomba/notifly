// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversations_dao.dart';

// ignore_for_file: type=lint
mixin _$ConversationsDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalConversationsTableTable get localConversationsTable =>
      attachedDatabase.localConversationsTable;
  ConversationsDaoManager get managers => ConversationsDaoManager(this);
}

class ConversationsDaoManager {
  final _$ConversationsDaoMixin _db;
  ConversationsDaoManager(this._db);
  $$LocalConversationsTableTableTableManager get localConversationsTable =>
      $$LocalConversationsTableTableTableManager(
        _db.attachedDatabase,
        _db.localConversationsTable,
      );
}
