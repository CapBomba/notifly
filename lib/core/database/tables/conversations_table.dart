import 'package:drift/drift.dart';

/// Local cache of conversations (direct message threads).
class LocalConversationsTable extends Table {
  @override
  String get tableName => 'local_conversations';

  /// UUID — matches the remote `conversations.id`.
  TextColumn get id => text()();

  /// Display name (other participant's name).
  TextColumn get peerName => text()();

  /// Other participant's user ID.
  TextColumn get peerId => text()();

  /// Other participant's avatar URL (nullable).
  TextColumn get peerAvatarUrl => text().nullable()();

  /// Text preview of the last message.
  TextColumn get lastMessagePreview => text().nullable()();

  /// Timestamp of the last message.
  DateTimeColumn get lastMessageAt => dateTime().nullable()();

  /// How many unread messages in this conversation.
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();

  /// When this row was last synced.
  DateTimeColumn get syncedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
