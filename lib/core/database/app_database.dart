import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/notifications_table.dart';
import 'tables/outbox_table.dart';
import 'tables/preferences_table.dart';
import 'tables/conversations_table.dart';
import 'tables/messages_table.dart';
import 'daos/notifications_dao.dart';
import 'daos/outbox_dao.dart';
import 'daos/preferences_dao.dart';
import 'daos/conversations_dao.dart';
import 'daos/messages_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    LocalNotificationsTable,
    LocalOutboxTable,
    LocalPreferencesTable,
    LocalConversationsTable,
    LocalMessagesTable,
  ],
  daos: [
    NotificationsDao,
    OutboxDao,
    PreferencesDao,
    ConversationsDao,
    MessagesDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  AppDatabase.forTesting(super.executor);

  static final AppDatabase instance = AppDatabase();

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Add chat tables added in schema v2
            await m.createTable(localConversationsTable);
            await m.createTable(localMessagesTable);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'notifly',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
