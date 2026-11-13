import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'notification_service.dart';

/// Global 24/7 Realtime Listener for incoming message notifications.
class GlobalNotificationListener {
  GlobalNotificationListener._();
  static final GlobalNotificationListener instance = GlobalNotificationListener._();

  RealtimeChannel? _globalChannel;
  String? _currentUserId;

  void startListening(String userId) {
    if (_currentUserId == userId && _globalChannel != null) return;
    _currentUserId = userId;

    _globalChannel?.unsubscribe();

    final channelName = 'global_notifications_$userId';
    _globalChannel = Supabase.instance.client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: AppConfig.messagesTable,
          callback: (payload) async {
            try {
              final newRecord = payload.newRecord;
              final senderId = newRecord['sender_id'] as String?;
              final conversationId = newRecord['conversation_id'] as String?;
              final rawContent = newRecord['content'] as String? ?? '';

              if (senderId != null && senderId != userId && conversationId != null) {
                final senderProfile = await Supabase.instance.client
                    .from('profiles')
                    .select('display_name, email')
                    .eq('id', senderId)
                    .maybeSingle();

                final senderName = senderProfile?['display_name'] as String? ??
                    senderProfile?['email'] as String? ??
                    'New Message';

                String cleanContent = rawContent;
                if (cleanContent.startsWith('┌ [')) {
                  final firstLineEnd = cleanContent.indexOf('\n');
                  if (firstLineEnd != -1) {
                    cleanContent = cleanContent.substring(firstLineEnd + 1);
                  }
                }

                if (cleanContent.startsWith('[IMAGE]:') ||
                    cleanContent.startsWith('http://') ||
                    cleanContent.startsWith('https://') ||
                    cleanContent.startsWith('data:image/')) {
                  cleanContent = '📷 Sent a photo';
                } else if (cleanContent.startsWith('[VOICE]:')) {
                  cleanContent = '🎙️ Sent a voice note';
                }

                await NotificationService.instance.showChatHeadsUpNotification(
                  id: (newRecord['id'] as String? ?? conversationId).hashCode,
                  title: senderName,
                  body: cleanContent,
                  conversationId: conversationId,
                  senderName: senderName,
                );
              }
            } catch (e) {
              debugPrint('Global notification error: $e');
            }
          },
        )
        .subscribe();
  }

  void stopListening() {
    _globalChannel?.unsubscribe();
    _globalChannel = null;
    _currentUserId = null;
  }
}
