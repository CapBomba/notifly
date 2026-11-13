import 'package:equatable/equatable.dart';

enum MessageStatus { sending, sent, delivered, read }

class ReactionDetail extends Equatable {
  const ReactionDetail({
    required this.emoji,
    required this.userId,
    this.userName,
    this.userAvatar,
  });

  final String emoji;
  final String userId;
  final String? userName;
  final String? userAvatar;

  @override
  List<Object?> get props => [emoji, userId, userName, userAvatar];
}

class MessageModel extends Equatable {
  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
    this.status = MessageStatus.sent,
    this.reactions = const {},
    this.detailedReactions = const [],
    this.replyToId,
    this.replyToContent,
    this.replyToSenderName,
    this.imageUrl,
    this.isVoiceNote = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String? senderName;
  final String? senderAvatar;
  final MessageStatus status;

  /// emoji -> count, populated from message_reactions table
  final Map<String, int> reactions;
  final List<ReactionDetail> detailedReactions;

  final String? replyToId;
  final String? replyToContent;
  final String? replyToSenderName;

  final String? imageUrl;
  final bool isVoiceNote;

  bool isMine(String currentUserId) => senderId == currentUserId;

  factory MessageModel.fromMap(Map<String, dynamic> m) {
    final profile = m['profiles'] as Map<String, dynamic>? ?? {};

    final rawReactions = m['message_reactions'] as List? ?? [];
    final reactionsMap = <String, int>{};
    final detailedList = <ReactionDetail>[];

    for (final r in rawReactions) {
      if (r is Map<String, dynamic>) {
        final emoji = r['emoji'] as String?;
        final uId = r['user_id'] as String?;
        final rProfile = r['profiles'] as Map<String, dynamic>? ?? {};

        if (emoji != null && emoji.isNotEmpty) {
          reactionsMap[emoji] = (reactionsMap[emoji] ?? 0) + 1;
          if (uId != null) {
            detailedList.add(ReactionDetail(
              emoji: emoji,
              userId: uId,
              userName: rProfile['display_name'] as String? ??
                  rProfile['email'] as String?,
              userAvatar: rProfile['avatar_url'] as String?,
            ));
          }
        }
      }
    }

    final rawContent = m['content'] as String? ?? '';
    String cleanContent = rawContent;
    String? parsedReplyToSenderName = m['reply_to_sender_name'] as String?;
    String? parsedReplyToContent = m['reply_to_content'] as String?;

    if (rawContent.startsWith('┌ [') && rawContent.contains(']: ')) {
      final firstLineEnd = rawContent.indexOf('\n');
      if (firstLineEnd != -1) {
        final quoteHeader = rawContent.substring(0, firstLineEnd);
        cleanContent = rawContent.substring(firstLineEnd + 1);

        final nameEnd = quoteHeader.indexOf(']: ');
        if (nameEnd != -1) {
          parsedReplyToSenderName ??= quoteHeader.substring(3, nameEnd);
          parsedReplyToContent ??= quoteHeader.substring(nameEnd + 3);
        }
      }
    }

    String? extractedImageUrl = m['image_url'] as String?;
    bool voiceNote = false;

    if (cleanContent.startsWith('[IMAGE]:')) {
      extractedImageUrl = cleanContent.substring(8).trim();
      cleanContent = '📷 Photo';
    } else if (extractedImageUrl == null &&
        (cleanContent.startsWith('http://') || cleanContent.startsWith('https://')) &&
        (cleanContent.endsWith('.jpg') ||
            cleanContent.endsWith('.jpeg') ||
            cleanContent.endsWith('.png') ||
            cleanContent.endsWith('.webp') ||
            cleanContent.endsWith('.gif'))) {
      extractedImageUrl = cleanContent;
    }

    if (cleanContent.startsWith('[VOICE]:')) {
      voiceNote = true;
      cleanContent = cleanContent.substring(8).trim();
    }

    return MessageModel(
      id: m['id'] as String,
      conversationId: m['conversation_id'] as String,
      senderId: m['sender_id'] as String,
      content: cleanContent,
      createdAt: DateTime.parse(m['created_at'] as String),
      senderName:
          profile['display_name'] as String? ?? profile['email'] as String?,
      senderAvatar: profile['avatar_url'] as String?,
      reactions: reactionsMap,
      detailedReactions: detailedList,
      replyToId: m['reply_to_id'] as String?,
      replyToContent: parsedReplyToContent,
      replyToSenderName: parsedReplyToSenderName,
      imageUrl: extractedImageUrl,
      isVoiceNote: voiceNote,
    );
  }

  MessageModel copyWith({
    MessageStatus? status,
    Map<String, int>? reactions,
    List<ReactionDetail>? detailedReactions,
    String? replyToId,
    String? replyToContent,
    String? replyToSenderName,
    String? imageUrl,
    bool? isVoiceNote,
  }) =>
      MessageModel(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        content: content,
        createdAt: createdAt,
        senderName: senderName,
        senderAvatar: senderAvatar,
        status: status ?? this.status,
        reactions: reactions ?? this.reactions,
        detailedReactions: detailedReactions ?? this.detailedReactions,
        replyToId: replyToId ?? this.replyToId,
        replyToContent: replyToContent ?? this.replyToContent,
        replyToSenderName: replyToSenderName ?? this.replyToSenderName,
        imageUrl: imageUrl ?? this.imageUrl,
        isVoiceNote: isVoiceNote ?? this.isVoiceNote,
      );

  @override
  List<Object?> get props => [
        id,
        conversationId,
        senderId,
        content,
        createdAt,
        status,
        reactions,
        detailedReactions,
        replyToId,
        replyToContent,
        replyToSenderName,
        imageUrl,
        isVoiceNote,
      ];
}
