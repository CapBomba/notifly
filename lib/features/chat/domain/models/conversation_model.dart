import 'package:equatable/equatable.dart';

class ConversationModel extends Equatable {
  const ConversationModel({
    required this.id,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.otherUserId,
    this.otherUserName,
    this.otherUserAvatar,
    this.unreadCount = 0,
    this.isArchived = false,
    this.lastReactionEmoji,
    this.lastReactionUserId,
    this.lastReactionUserName,
    this.lastReactedMessageContent,
    this.lastReactionAt,
  });

  final String id;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserAvatar;
  final int unreadCount;
  final bool isArchived;

  final String? lastReactionEmoji;
  final String? lastReactionUserId;
  final String? lastReactionUserName;
  final String? lastReactedMessageContent;
  final DateTime? lastReactionAt;

  bool isLastMessageMine(String currentUserId) =>
      lastMessageSenderId == currentUserId;

  static String _cleanSnippet(String msg) {
    if (msg.startsWith('┌ [')) {
      final firstLineEnd = msg.indexOf('\n');
      if (firstLineEnd != -1) {
        msg = msg.substring(firstLineEnd + 1);
      }
    }

    if (msg.startsWith('[IMAGE]:') ||
        msg.startsWith('http://') ||
        msg.startsWith('https://') ||
        msg.startsWith('data:image/')) {
      return '📷 Photo';
    }

    if (msg.startsWith('[VOICE]:')) {
      return '🎙️ Voice note';
    }

    return msg;
  }

  String formattedLastMessage(String currentUserId) {
    if (lastReactionAt != null &&
        lastReactionEmoji != null &&
        (lastMessageAt == null || lastReactionAt!.isAfter(lastMessageAt!))) {
      final rawSnippet = lastReactedMessageContent ?? lastMessage ?? '';
      final clean = _cleanSnippet(rawSnippet);

      String targetDescription;
      if (clean == '📷 Photo') {
        targetDescription = 'a photo';
      } else if (clean == '🎙️ Voice note') {
        targetDescription = 'a voice note';
      } else {
        final snippet =
            clean.length > 25 ? '${clean.substring(0, 22)}...' : clean;
        targetDescription = '"$snippet"';
      }

      if (lastReactionUserId == currentUserId) {
        return 'You reacted $lastReactionEmoji to $targetDescription';
      } else {
        final name = lastReactionUserName ?? otherUserName ?? 'User';
        return '$name reacted $lastReactionEmoji to $targetDescription';
      }
    }

    if (lastMessage == null || lastMessage!.isEmpty) return 'Tap to start chat';

    final cleanMsg = _cleanSnippet(lastMessage!);

    if (lastMessageSenderId == currentUserId) {
      return 'You: $cleanMsg';
    }
    return cleanMsg;
  }

  factory ConversationModel.fromMap(
    Map<String, dynamic> m,
    String currentUserId, {
    int? unreadCountOverride,
    bool? isArchivedOverride,
  }) {
    final members = (m['conversation_members'] as List?) ?? [];
    final other = members.firstWhere(
      (x) => x['user_id'] != currentUserId,
      orElse: () => <String, dynamic>{},
    );
    final profile = other['profiles'] as Map<String, dynamic>? ?? {};

    final msgs = (m['messages'] as List?) ?? [];
    final last = msgs.isNotEmpty ? msgs.first as Map<String, dynamic> : null;

    String? latestEmoji;
    String? latestReactionUserId;
    String? latestReactionUserName;
    String? latestReactedContent;
    DateTime? latestReactionTime;

    for (final msg in msgs) {
      if (msg is Map<String, dynamic>) {
        final rawReactions = (msg['message_reactions'] as List?) ?? [];
        for (final r in rawReactions) {
          if (r is Map<String, dynamic>) {
            final emoji = r['emoji'] as String?;
            final uId = r['user_id'] as String?;
            final createdAt = r['created_at'] != null ? DateTime.parse(r['created_at'] as String) : null;
            final rProfile = r['profiles'] as Map<String, dynamic>? ?? {};

            if (emoji != null && uId != null && createdAt != null) {
              if (latestReactionTime == null || createdAt.isAfter(latestReactionTime)) {
                latestEmoji = emoji;
                latestReactionUserId = uId;
                latestReactionTime = createdAt;
                latestReactedContent = msg['content'] as String?;
                latestReactionUserName = rProfile['display_name'] as String? ?? rProfile['email'] as String?;
              }
            }
          }
        }
      }
    }

    return ConversationModel(
      id: m['id'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      lastMessage: last?['content'] as String?,
      lastMessageAt: last != null
          ? DateTime.parse(last['created_at'] as String)
          : null,
      lastMessageSenderId: last?['sender_id'] as String?,
      otherUserId: other['user_id'] as String?,
      otherUserName: profile['display_name'] as String? ??
          profile['email'] as String? ?? 'User',
      otherUserAvatar: profile['avatar_url'] as String?,
      unreadCount: unreadCountOverride ?? 0,
      isArchived: isArchivedOverride ?? false,
      lastReactionEmoji: latestEmoji,
      lastReactionUserId: latestReactionUserId,
      lastReactionUserName: latestReactionUserName,
      lastReactedMessageContent: latestReactedContent,
      lastReactionAt: latestReactionTime,
    );
  }

  ConversationModel copyWith({
    int? unreadCount,
    bool? isArchived,
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastMessageSenderId,
  }) =>
      ConversationModel(
        id: id,
        createdAt: createdAt,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
        otherUserId: otherUserId,
        otherUserName: otherUserName,
        otherUserAvatar: otherUserAvatar,
        unreadCount: unreadCount ?? this.unreadCount,
        isArchived: isArchived ?? this.isArchived,
      );

  @override
  List<Object?> get props => [
        id, createdAt, lastMessage, lastMessageAt, lastMessageSenderId,
        otherUserId, otherUserName, otherUserAvatar, unreadCount, isArchived,
      ];
}
