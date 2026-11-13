import 'package:drift/drift.dart';

/// Local cache of chat messages.
class LocalMessagesTable extends Table {
  @override
  String get tableName => 'local_messages';

  /// UUID — matches the remote `messages.id`.
  TextColumn get id => text()();

  /// The conversation this message belongs to.
  TextColumn get conversationId => text()();

  /// Sender's user ID.
  TextColumn get senderId => text()();

  /// Sender's display name (denormalised for offline display).
  TextColumn get senderName => text()();

  /// Message body.
  TextColumn get body => text()();

  /// 'text' | 'image' (extensible).
  TextColumn get type => text().withDefault(const Constant('text'))();

  /// Whether the current user has read this message.
  BoolColumn get isRead =>
      boolean().withDefault(const Constant(false))();

  /// Server-assigned timestamp.
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
