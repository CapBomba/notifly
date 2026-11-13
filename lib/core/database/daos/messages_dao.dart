import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/messages_table.dart';

part 'messages_dao.g.dart';

@DriftAccessor(tables: [LocalMessagesTable])
class MessagesDao extends DatabaseAccessor<AppDatabase>
    with _$MessagesDaoMixin {
  MessagesDao(super.db);

  /// Watch all messages in a conversation, oldest first.
  Stream<List<LocalMessagesTableData>> watchByConversation(
    String conversationId,
  ) =>
      (select(localMessagesTable)
            ..where((t) => t.conversationId.equals(conversationId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<void> upsert(LocalMessagesTableCompanion companion) =>
      into(localMessagesTable).insertOnConflictUpdate(companion);

  Future<void> upsertAll(List<LocalMessagesTableCompanion> companions) =>
      batch((b) {
        b.insertAllOnConflictUpdate(localMessagesTable, companions);
      });

  Future<int> markAllRead(String conversationId) =>
      (update(localMessagesTable)
            ..where((t) => t.conversationId.equals(conversationId)))
          .write(const LocalMessagesTableCompanion(isRead: Value(true)));

  Future<int> deleteByConversation(String conversationId) =>
      (delete(localMessagesTable)
            ..where((t) => t.conversationId.equals(conversationId)))
          .go();
}
