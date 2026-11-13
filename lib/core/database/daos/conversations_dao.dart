import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/conversations_table.dart';

part 'conversations_dao.g.dart';

@DriftAccessor(tables: [LocalConversationsTable])
class ConversationsDao extends DatabaseAccessor<AppDatabase>
    with _$ConversationsDaoMixin {
  ConversationsDao(super.db);

  /// Watch all conversations, newest message first.
  Stream<List<LocalConversationsTableData>> watchAll() =>
      (select(localConversationsTable)
            ..orderBy([
              (t) => OrderingTerm.desc(
                    t.lastMessageAt,
                    nulls: NullsOrder.last,
                  ),
            ]))
          .watch();

  Future<List<LocalConversationsTableData>> getAll() =>
      (select(localConversationsTable)
            ..orderBy([
              (t) => OrderingTerm.desc(
                    t.lastMessageAt,
                    nulls: NullsOrder.last,
                  ),
            ]))
          .get();

  Future<void> upsert(LocalConversationsTableCompanion companion) =>
      into(localConversationsTable).insertOnConflictUpdate(companion);

  Future<void> upsertAll(
    List<LocalConversationsTableCompanion> companions,
  ) =>
      batch((b) {
        b.insertAllOnConflictUpdate(localConversationsTable, companions);
      });

  Future<int> updateUnreadCount(String id, int count) =>
      (update(localConversationsTable)..where((t) => t.id.equals(id)))
          .write(LocalConversationsTableCompanion(
        unreadCount: Value(count),
      ));

  Future<int> clearUnread(String id) => updateUnreadCount(id, 0);

  Future<int> deleteAll() => delete(localConversationsTable).go();
}
