import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/notifications_table.dart';

part 'notifications_dao.g.dart';

/// Data-access object for the local notifications cache.
@DriftAccessor(tables: [LocalNotificationsTable])
class NotificationsDao extends DatabaseAccessor<AppDatabase>
    with _$NotificationsDaoMixin {
  NotificationsDao(super.db);

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// All notifications for a user, newest first.
  Future<List<LocalNotificationsTableData>> getAll(String userId) =>
      (select(localNotificationsTable)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// Watch all notifications reactively.
  Stream<List<LocalNotificationsTableData>> watchAll(String userId) =>
      (select(localNotificationsTable)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  /// Unread count for a user.
  Future<int> unreadCount(String userId) async {
    final countExpr =
        localNotificationsTable.id.count();
    final query = selectOnly(localNotificationsTable)
      ..addColumns([countExpr])
      ..where(localNotificationsTable.userId.equals(userId) &
          localNotificationsTable.isRead.equals(false));
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// Single notification by id.
  Future<LocalNotificationsTableData?> getById(String id) =>
      (select(localNotificationsTable)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Upsert a notification received from Supabase Realtime.
  Future<void> upsertNotification(
    LocalNotificationsTableCompanion companion,
  ) =>
      into(localNotificationsTable).insertOnConflictUpdate(companion);

  /// Upsert a batch of notifications (e.g., initial sync).
  Future<void> upsertAll(
    List<LocalNotificationsTableCompanion> companions,
  ) =>
      batch((b) {
        b.insertAllOnConflictUpdate(localNotificationsTable, companions);
      });

  /// Mark a single notification as read.
  Future<int> markRead(String id) => (update(localNotificationsTable)
        ..where((t) => t.id.equals(id)))
      .write(const LocalNotificationsTableCompanion(
        isRead: Value(true),
      ));

  /// Mark all notifications as read for a user.
  Future<int> markAllRead(String userId) =>
      (update(localNotificationsTable)
            ..where((t) => t.userId.equals(userId)))
          .write(const LocalNotificationsTableCompanion(
        isRead: Value(true),
      ));

  /// Delete a single notification by id.
  Future<int> deleteById(String id) =>
      (delete(localNotificationsTable)..where((t) => t.id.equals(id))).go();

  /// Delete all notifications for a user (e.g., on sign-out).
  Future<int> deleteAllForUser(String userId) =>
      (delete(localNotificationsTable)
            ..where((t) => t.userId.equals(userId)))
          .go();
}
