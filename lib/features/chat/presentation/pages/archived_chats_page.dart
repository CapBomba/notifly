import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notifly_loading_screen.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/models/conversation_model.dart';
import '../../providers/chat_providers.dart';
import 'chat_screen.dart';

class ArchivedChatsPage extends ConsumerWidget {
  const ArchivedChatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Archived Chats',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0.5,
      ),
      body: conversationsAsync.when(
        loading: () => const NotiFlyLoadingScreen(
          message: 'Loading archived chats...',
          isFullScreen: false,
        ),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (allConvos) {
          final archivedList =
              allConvos.where((c) => c.isArchived).toList();

          if (archivedList.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No archived chats',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text('Long-press a conversation in your inbox to archive it',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.messengerBlue,
            onRefresh: () async {
              ref.invalidate(conversationsProvider);
              await ref.read(conversationsProvider.future);
            },
            child: ListView.builder(
              itemCount: archivedList.length,
              itemBuilder: (context, i) {
                final convo = archivedList[i];
                return _ArchivedTile(convo: convo);
              },
            ),
          );
        },
      ),
    );
  }
}

class _ArchivedTile extends ConsumerWidget {
  const _ArchivedTile({required this.convo});
  final ConversationModel convo;

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            ListTile(
              leading: const Icon(Icons.unarchive_outlined,
                  color: AppColors.messengerBlue),
              title: const Text('Unarchive Chat'),
              subtitle: const Text('Move conversation back to main inbox'),
              onTap: () async {
                Navigator.pop(context);
                await ref
                    .read(chatRepositoryProvider)
                    .toggleArchive(convo.id, false);
                ref.invalidate(conversationsProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chat unarchived and moved to inbox'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),

            if (convo.unreadCount > 0)
              ListTile(
                leading: const Icon(Icons.mark_chat_read_outlined),
                title: const Text('Mark as Read'),
                onTap: () async {
                  Navigator.pop(context);
                  await ref
                      .read(chatRepositoryProvider)
                      .markConversationAsRead(convo.id);
                  ref.invalidate(conversationsProvider);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.mark_chat_unread_outlined),
                title: const Text('Mark as Unread'),
                onTap: () async {
                  Navigator.pop(context);
                  await ref
                      .read(chatRepositoryProvider)
                      .markAsUnread(convo.id);
                  ref.invalidate(conversationsProvider);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';
    final name = convo.otherUserName ?? 'User';
    final preview = convo.formattedLastMessage(currentUserId);

    return InkWell(
      onTap: () async {
        await ref
            .read(chatRepositoryProvider)
            .toggleArchive(convo.id, false);
        ref.invalidate(conversationsProvider);

        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                conversationId: convo.id,
                otherUserName: name,
                otherUserAvatar: convo.otherUserAvatar,
              ),
            ),
          );
        }
      },
      onLongPress: () => _showOptions(context, ref),
      child: Container(
        color: isDark ? AppColors.darkBackground : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundImage: convo.otherUserAvatar != null
                  ? NetworkImage(convo.otherUserAvatar!)
                  : null,
              backgroundColor: AppColors.messengerBlue.withValues(alpha: 0.15),
              child: convo.otherUserAvatar == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.messengerBlue),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.unarchive_outlined,
                color: AppColors.messengerBlue, size: 20),
          ],
        ),
      ),
    );
  }
}
