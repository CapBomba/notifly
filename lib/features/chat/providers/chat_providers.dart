import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/repositories/chat_repository.dart';
import '../domain/models/conversation_model.dart';
import '../domain/models/message_model.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) throw StateError('No authenticated user');
  final repo = ChatRepository(currentUserId: user.id);
  ref.onDispose(repo.dispose);
  return repo;
});

// ---------------------------------------------------------------------------
// Conversations
// ---------------------------------------------------------------------------

final conversationsProvider = StreamProvider<List<ConversationModel>>((ref) {
  return ref.watch(chatRepositoryProvider).watchConversations();
});

// ---------------------------------------------------------------------------
// Messages — per conversation
// ---------------------------------------------------------------------------

class MessagesController with ChangeNotifier {
  MessagesController(this._repo, this._conversationId) {
    _load();
  }

  final ChatRepository _repo;
  final String _conversationId;
  RealtimeChannel? _chatChannel;
  Timer? _autoRefreshTimer;

  List<MessageModel> messages = [];
  bool loading = true;

  /// Raw error object — use friendlyError() in the UI for display.
  Object? rawError;

  /// Convenience string for legacy callers (shows friendly message via getter).
  Object? get error => rawError;

  Future<void> _load() async {
    loading = true;
    rawError = null;
    notifyListeners();
    try {
      messages = await _repo.fetchMessages(_conversationId);
      loading = false;
      notifyListeners();

      _chatChannel = _repo.subscribeToChatUpdates(
        conversationId: _conversationId,
        onUpdate: () => _refreshMessagesQuietly(),
      );

      // Periodic 2-second auto-refresher for active conversation
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _refreshMessagesQuietly();
      });
    } catch (e) {
      rawError = e;
      loading = false;
      debugPrint('MessagesController._load() error: $e');
      notifyListeners();
    }
  }

  /// Refreshes messages list without resetting loading state (useful for reaction updates)
  Future<void> _refreshMessagesQuietly() async {
    try {
      messages = await _repo.fetchMessages(_conversationId);
      notifyListeners();
    } catch (e) {
      debugPrint('MessagesController._refreshMessagesQuietly() error: $e');
    }
  }

  /// Reload messages — exposed so the UI can show a Retry button.
  Future<void> reload() => _load();

  Future<void> send(
    String content, {
    String? replyToId,
    String? replyToContent,
    String? replyToSenderName,
  }) async {
    try {
      final msg = await _repo.sendMessage(
        conversationId: _conversationId,
        content: content,
        replyToId: replyToId,
        replyToContent: replyToContent,
        replyToSenderName: replyToSenderName,
      );
      if (!messages.any((m) => m.id == msg.id)) {
        messages = [...messages, msg];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('MessagesController.send() error: $e');
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _repo.deleteMessage(messageId: messageId);
      messages = messages.where((m) => m.id != messageId).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('MessagesController.deleteMessage() error: $e');
      rethrow;
    }
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    // 1. Optimistic local update for 0ms response time
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      final msg = messages[idx];
      final currentUserId = _repo.currentUserId;
      final newReactions = Map<String, int>.from(msg.reactions);
      final newDetailed = List<ReactionDetail>.from(msg.detailedReactions);

      final existingIndex = newDetailed.indexWhere(
          (r) => r.emoji == emoji && r.userId == currentUserId);

      if (existingIndex != -1) {
        newDetailed.removeAt(existingIndex);
        final currentCount = newReactions[emoji] ?? 1;
        if (currentCount <= 1) {
          newReactions.remove(emoji);
        } else {
          newReactions[emoji] = currentCount - 1;
        }
      } else {
        newDetailed.add(ReactionDetail(
          emoji: emoji,
          userId: currentUserId,
          userName: 'You',
        ));
        newReactions[emoji] = (newReactions[emoji] ?? 0) + 1;
      }

      messages[idx] = msg.copyWith(
        reactions: newReactions,
        detailedReactions: newDetailed,
      );
      notifyListeners();
    }

    // 2. Perform DB update
    try {
      await _repo.toggleReaction(
        messageId: messageId,
        emoji: emoji,
        conversationId: _conversationId,
      );
      await _refreshMessagesQuietly();
    } catch (e) {
      debugPrint('MessagesController.toggleReaction() error: $e');
      rethrow;
    }
  }

  void disposeController() {
    _autoRefreshTimer?.cancel();
    if (_chatChannel != null) {
      _repo.unsubscribeChannel(_chatChannel!);
    }
  }
}

final messagesControllerProvider =
    Provider.family<MessagesController, String>((ref, convId) {
  final repo = ref.watch(chatRepositoryProvider);
  final ctrl = MessagesController(repo, convId);
  ref.onDispose(ctrl.disposeController);
  return ctrl;
});
