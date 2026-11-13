import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../domain/models/conversation_model.dart';
import '../../domain/models/message_model.dart';

class ChatRepository {
  ChatRepository({required this.currentUserId, SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final String currentUserId;
  final SupabaseClient _client;
  final _log = Logger();

  final _channels = <RealtimeChannel>[];
  final Set<String> _locallyArchivedIds = {};

  // ---------------------------------------------------------------------------
  // Conversations
  // ---------------------------------------------------------------------------

  Future<List<ConversationModel>> fetchConversations() async {
    final memberRows = await _client
        .from(AppConfig.conversationMembersTable)
        .select('conversation_id')
        .eq('user_id', currentUserId);

    final convIds = (memberRows as List)
        .map((x) => x['conversation_id'] as String)
        .toList();

    if (convIds.isEmpty) return [];

    final rows = await _client
        .from(AppConfig.conversationsTable)
        .select('''
          id,
          created_at,
          conversation_members(
            user_id,
            profiles(display_name, email, avatar_url)
          ),
          messages(
            id, sender_id, content, created_at,
            message_reactions(
              emoji, user_id, created_at,
              profiles(display_name, email)
            )
          )
        ''')
        .inFilter('id', convIds)
        .order('created_at', referencedTable: 'messages', ascending: false)
        .limit(10, referencedTable: 'messages');

    final localDao = AppDatabase.instance.conversationsDao;
    final prefDao  = AppDatabase.instance.preferencesDao;
    final localList = await localDao.getAll();
    final localMap = {for (final c in localList) c.id: c};

    final result = <ConversationModel>[];
    for (final r in rows) {
      final id = r['id'] as String;
      final msgs = (r['messages'] as List?) ?? [];
      final last = msgs.isNotEmpty ? msgs.first as Map<String, dynamic> : null;
      final lastSenderId = last?['sender_id'] as String?;
      final lastCreatedAt = last != null ? DateTime.parse(last['created_at'] as String) : null;

      final local = localMap[id];
      int unread = local?.unreadCount ?? 0;
      bool archived = await prefDao.getBool('archived_$id', defaultValue: false);
      if (_locallyArchivedIds.contains(id)) {
        archived = true;
      }
      final archivedAtStr = await prefDao.getValue('archived_at_$id');

      if (archived && archivedAtStr != null && archivedAtStr.isNotEmpty && lastCreatedAt != null) {
        final archivedAt = DateTime.parse(archivedAtStr);
        if (lastCreatedAt.isAfter(archivedAt)) {
          // A NEW message arrived AFTER archiving -> Auto-unarchive!
          archived = false;
          await prefDao.setBool('archived_$id', value: false);
        }
      }

      if (local != null && lastCreatedAt != null && local.lastMessageAt != null) {
        if (lastCreatedAt.isAfter(local.lastMessageAt!) && lastSenderId != currentUserId) {
          unread += 1;
        }
      } else if (lastSenderId != currentUserId && last != null && local == null) {
        unread = 1;
      }

      final deletedForMeStr = await prefDao.getValue('deleted_for_me_$id');
      if (deletedForMeStr != null) {
        final deletedAt = DateTime.parse(deletedForMeStr);
        if (lastCreatedAt == null || !lastCreatedAt.isAfter(deletedAt)) {
          continue;
        }
      }

      final model = ConversationModel.fromMap(
        r,
        currentUserId,
        unreadCountOverride: unread,
        isArchivedOverride: archived,
      );

      result.add(model);

      await localDao.upsert(
        LocalConversationsTableCompanion.insert(
          id: id,
          peerName: model.otherUserName ?? 'User',
          peerId: model.otherUserId ?? '',
          peerAvatarUrl: Value(model.otherUserAvatar),
          lastMessagePreview: Value(model.lastMessage),
          lastMessageAt: Value(model.lastMessageAt),
          unreadCount: Value(unread),
        ),
      );
    }

    result.sort((a, b) {
      final aTime = a.lastReactionAt ?? a.lastMessageAt ?? a.createdAt;
      final bTime = b.lastReactionAt ?? b.lastMessageAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    return result;
  }

  Future<void> markConversationAsRead(String conversationId) async {
    await AppDatabase.instance.conversationsDao.clearUnread(conversationId);
  }

  Future<void> markAsUnread(String conversationId) async {
    await AppDatabase.instance.conversationsDao.updateUnreadCount(conversationId, 1);
  }

  Future<void> toggleArchive(String conversationId, bool isArchived) async {
    final prefDao = AppDatabase.instance.preferencesDao;
    await prefDao.setBool('archived_$conversationId', value: isArchived);
    if (isArchived) {
      _locallyArchivedIds.add(conversationId);
      await prefDao.setValue(
          'archived_at_$conversationId', DateTime.now().toIso8601String());
    } else {
      _locallyArchivedIds.remove(conversationId);
      await prefDao.setValue('archived_at_$conversationId', '');
    }
  }

  /// Deletes / clears the conversation ONLY for the current user's device/account view.
  Future<void> deleteConversationForMe(String conversationId) async {
    final prefDao = AppDatabase.instance.preferencesDao;
    final nowStr = DateTime.now().toIso8601String();
    await prefDao.setValue('deleted_for_me_$conversationId', nowStr);

    final msgDao = AppDatabase.instance.messagesDao;
    await msgDao.deleteByConversation(conversationId);
  }

  /// Reactive list — re-fetches on any message/reaction INSERT/UPDATE/DELETE.
  Stream<List<ConversationModel>> watchConversations() {
    final controller = StreamController<List<ConversationModel>>.broadcast();

    fetchConversations()
        .then((v) { if (!controller.isClosed) controller.add(v); })
        .catchError((Object e) {
          if (!controller.isClosed) controller.addError(e);
        });

    final msgChannel = _client
        .channel('convos_msgs:$currentUserId:${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: AppConfig.messagesTable,
          callback: (payload) async {
            fetchConversations()
                .then((v) { if (!controller.isClosed) controller.add(v); })
                .catchError((_) {});

            try {
              if (payload.eventType == PostgresChangeEvent.insert) {
                final newRecord = payload.newRecord;
                final senderId = newRecord['sender_id'] as String?;
                final conversationId = newRecord['conversation_id'] as String?;
                final rawContent = newRecord['content'] as String? ?? '';

                if (senderId != null && senderId != currentUserId && conversationId != null) {
                  final senderProfile = await _client
                      .from('profiles')
                      .select('display_name, email')
                      .eq('id', senderId)
                      .maybeSingle();

                  final senderName = senderProfile?['display_name'] as String? ??
                      senderProfile?['email'] as String? ??
                      'New Message';

                  String cleanContent = rawContent;
                  if (cleanContent.startsWith('┌ [')) {
                    cleanContent = cleanContent.substring(cleanContent.indexOf('\n') + 1);
                  } else if (cleanContent.startsWith('[IMAGE]:')) {
                    cleanContent = '📷 Sent a photo';
                  } else if (cleanContent.startsWith('[VOICE]:')) {
                    cleanContent = '🎙️ Sent a voice note';
                  }

                  await NotificationService.instance.showNotification(
                    id: (newRecord['id'] as String? ?? conversationId).hashCode,
                    title: senderName,
                    body: cleanContent,
                    isChat: true,
                    urgent: true,
                    payloadJson: jsonEncode({
                      'conversation_id': conversationId,
                      'sender_name': senderName,
                    }),
                  );
                }
              }
            } catch (e) {
              _log.e('Notification trigger error:', error: e);
            }
          },
        )
        .subscribe();
    _channels.add(msgChannel);

    final reactChannel = _client
        .channel('convos_react:$currentUserId:${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_reactions',
          callback: (_) {
            fetchConversations()
                .then((v) { if (!controller.isClosed) controller.add(v); })
                .catchError((_) {});
          },
        )
        .subscribe();
    _channels.add(reactChannel);

    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // Messages & Reactions
  // ---------------------------------------------------------------------------

  Future<List<MessageModel>> fetchMessages(String conversationId) async {
    final prefDao = AppDatabase.instance.preferencesDao;
    final deletedForMeStr = await prefDao.getValue('deleted_for_me_$conversationId');
    DateTime? deletedAt;
    if (deletedForMeStr != null) {
      deletedAt = DateTime.parse(deletedForMeStr);
    }

    final rows = await _client
        .from(AppConfig.messagesTable)
        .select('*, profiles(display_name, email, avatar_url), message_reactions(emoji, user_id, profiles(display_name, email, avatar_url))')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(50);

    var list = rows.map(MessageModel.fromMap).toList();
    if (deletedAt != null) {
      list = list.where((m) => m.createdAt.isAfter(deletedAt!)).toList();
    }

    return list.reversed.toList();
  }

  /// Dedicated unified Realtime Channel for active conversation updates:
  /// - Message INSERT/UPDATE/DELETE
  /// - Reaction INSERT/UPDATE/DELETE
  /// - Reaction Websocket Broadcast
  RealtimeChannel subscribeToChatUpdates({
    required String conversationId,
    required void Function() onUpdate,
  }) {
    final channelName = 'chat_room_$conversationId';

    final channel = _client.channel(channelName);

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: AppConfig.messagesTable,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (_) => onUpdate(),
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'message_reactions',
      callback: (_) => onUpdate(),
    );

    channel.onBroadcast(
      event: 'reaction_event',
      callback: (_) => onUpdate(),
    );

    channel.subscribe();
    _channels.add(channel);
    return channel;
  }

  Future<void> unsubscribeChannel(RealtimeChannel channel) async {
    try {
      await _client.removeChannel(channel);
      _channels.remove(channel);
    } catch (_) {}
  }

  /// Legacy stream compatibility wrapper
  Stream<MessageModel> watchNewMessages(String conversationId) {
    final controller = StreamController<MessageModel>.broadcast();

    final channel = _client
        .channel('msgs:$conversationId:${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: AppConfig.messagesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            try {
              final newId = payload.newRecord['id'] as String?;
              if (newId != null) {
                final row = await _client
                    .from(AppConfig.messagesTable)
                    .select('*, profiles(display_name, email, avatar_url), message_reactions(emoji, user_id, profiles(display_name, email, avatar_url))')
                    .eq('id', newId)
                    .single();
                if (!controller.isClosed) controller.add(MessageModel.fromMap(row));
              }
            } catch (e) {
              _log.e('watchNewMessages error:', error: e);
            }
          },
        )
        .subscribe();

    _channels.add(channel);
    return controller.stream;
  }

  Stream<void> watchReactions(String conversationId) {
    final controller = StreamController<void>.broadcast();

    final pgChannel = _client
        .channel('reactions_pg:$conversationId:${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_reactions',
          callback: (_) {
            if (!controller.isClosed) controller.add(null);
          },
        )
        .subscribe();
    _channels.add(pgChannel);

    final bcChannel = _client
        .channel('reactions_bc:$conversationId')
        .onBroadcast(
          event: 'reaction_event',
          callback: (_) {
            if (!controller.isClosed) controller.add(null);
          },
        )
        .subscribe();
    _channels.add(bcChannel);

    return controller.stream;
  }

  /// Toggle reaction on a message by current user.
  Future<void> toggleReaction({
    required String messageId,
    required String emoji,
    required String conversationId,
  }) async {
    final existing = await _client
        .from('message_reactions')
        .select('id')
        .eq('message_id', messageId)
        .eq('user_id', currentUserId)
        .eq('emoji', emoji)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', currentUserId)
          .eq('emoji', emoji);
    } else {
      await _client.from('message_reactions').upsert({
        'message_id': messageId,
        'user_id': currentUserId,
        'emoji': emoji,
      }, onConflict: 'message_id,user_id,emoji');
    }

    try {
      final channel = _client.channel('reactions_bc:$conversationId');
      await channel.sendBroadcastMessage(
        event: 'reaction_event',
        payload: {
          'message_id': messageId,
          'emoji': emoji,
          'user_id': currentUserId,
        },
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Send & Delete
  // ---------------------------------------------------------------------------

  Future<MessageModel> sendMessage({
    required String conversationId,
    required String content,
    String? replyToId,
    String? replyToContent,
    String? replyToSenderName,
  }) async {
    final id = const Uuid().v4();

    String finalContent = content.trim();
    if (replyToContent != null && replyToContent.isNotEmpty) {
      final quote = replyToContent.replaceAll('\n', ' ');
      final trimmedQuote = quote.length > 80 ? '${quote.substring(0, 77)}...' : quote;
      finalContent = '┌ [${replyToSenderName ?? 'User'}]: $trimmedQuote\n$finalContent';
    }

    final data = <String, dynamic>{
      'id': id,
      'conversation_id': conversationId,
      'sender_id': currentUserId,
      'content': finalContent,
    };

    final row = await _client
        .from(AppConfig.messagesTable)
        .insert(data)
        .select('*, profiles(display_name, email, avatar_url), message_reactions(emoji, user_id, profiles(display_name, email, avatar_url))')
        .single();

    try {
      await AppDatabase.instance.preferencesDao
          .setBool('archived_$conversationId', value: false);
    } catch (_) {}

    return MessageModel.fromMap(row);
  }

  Future<void> deleteMessage({required String messageId}) async {
    await _client
        .from(AppConfig.messagesTable)
        .delete()
        .eq('id', messageId)
        .eq('sender_id', currentUserId);
  }

  // ---------------------------------------------------------------------------
  // Typing Indicator (Realtime Broadcast)
  // ---------------------------------------------------------------------------

  Future<void> sendTypingSignal({
    required String conversationId,
    required bool isTyping,
  }) async {
    final channel = _client.channel('typing:$conversationId');
    await channel.sendBroadcastMessage(
      event: 'typing',
      payload: {
        'user_id': currentUserId,
        'is_typing': isTyping,
      },
    );
  }

  Stream<bool> watchTyping(String conversationId) {
    final controller = StreamController<bool>.broadcast();

    final channel = _client
        .channel('typing:$conversationId')
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final uid = payload['user_id'] as String?;
            final typing = payload['is_typing'] as bool? ?? false;
            if (uid != currentUserId && !controller.isClosed) {
              controller.add(typing);
            }
          },
        )
        .subscribe();

    _channels.add(channel);
    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // Get or create 1-on-1 conversation
  // ---------------------------------------------------------------------------

  Future<String> getOrCreateConversation(String otherUserId) async {
    final result = await _client.rpc(
      'get_or_create_conversation',
      params: {'user_a': currentUserId, 'user_b': otherUserId},
    );
    return result as String;
  }

  // ---------------------------------------------------------------------------
  // User search
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final q = query.trim();

    // Build filter query then order — or() must come before order/limit
    final rows = q.isEmpty
        ? await _client
            .from(AppConfig.profilesTable)
            .select('id, display_name, email, avatar_url')
            .neq('id', currentUserId)
            .order('display_name', ascending: true)
            .limit(50)
        : await _client
            .from(AppConfig.profilesTable)
            .select('id, display_name, email, avatar_url')
            .neq('id', currentUserId)
            .or('display_name.ilike.%$q%,email.ilike.%$q%')
            .order('display_name', ascending: true)
            .limit(50);

    return List<Map<String, dynamic>>.from(rows);
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  Future<void> dispose() async {
    for (final ch in _channels) {
      await _client.removeChannel(ch);
    }
    _channels.clear();
  }
}
