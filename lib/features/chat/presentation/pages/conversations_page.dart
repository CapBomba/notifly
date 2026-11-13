import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/notifications/global_notification_listener.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notifly_loading_screen.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../domain/models/conversation_model.dart';
import '../../providers/chat_providers.dart';
import 'archived_chats_page.dart';
import 'chat_screen.dart';

class ConversationsPage extends ConsumerStatefulWidget {
  const ConversationsPage({super.key});

  @override
  ConsumerState<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends ConsumerState<ConversationsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  StreamSubscription? _fcmSub;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (_searchCtrl.text != _query) {
        setState(() => _query = _searchCtrl.text);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        GlobalNotificationListener.instance.startListening(user.id);
      }
      _checkPendingNotificationTap();
      _fcmSub = NotificationService.instance.onFcmTapped.listen((data) {
        _handleNotificationTapData(data);
      });
    });
  }

  void _checkPendingNotificationTap() {
    final pending = NotificationService.instance.pendingFcmTapPayload;
    if (pending != null) {
      NotificationService.instance.clearPendingFcmTap();
      _handleNotificationTapData(pending);
    }
  }

  void _handleNotificationTapData(Map<String, dynamic> data) {
    final convId = data['conversation_id'] as String?;
    final senderName = data['sender_name'] as String? ?? 'Chat';
    if (convId != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: convId,
            otherUserName: senderName,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _fcmSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,

        // ── Shadcn UI Header & App Bar ─────────────────────────────────
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(118),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
                    child: Row(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: AppColors.gradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.near_me_rounded,
                                  color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'NotiFly',
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.lightText,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        _OnlineAvatar(
                          name: currentUser?.email ?? 'Me',
                          avatarUrl: currentUser
                              ?.userMetadata?['avatar_url'] as String?,
                          size: 34,
                          showOnline: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfilePage()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchCtrl,
                        style: TextStyle(
                            color: isDark ? Colors.white : AppColors.lightText,
                            fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search conversations...',
                          hintStyle: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                              fontSize: 13.5),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              size: 18),
                          filled: true,
                          fillColor: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        body: conversationsAsync.when(
          loading: () => const NotiFlyLoadingScreen(
            message: 'Fetching chats...',
            isFullScreen: false,
          ),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (convos) {
            final activeConvos = convos.where((c) => !c.isArchived).toList();
            final archivedCount = convos.where((c) => c.isArchived).length;

            final filtered = _query.isEmpty
                ? activeConvos
                : activeConvos
                    .where((c) =>
                        (c.otherUserName ?? '')
                            .toLowerCase()
                            .contains(_query.toLowerCase()) ||
                        (c.lastMessage ?? '')
                            .toLowerCase()
                            .contains(_query.toLowerCase()))
                    .toList();

            return RefreshIndicator(
              color: AppColors.messengerBlue,
              onRefresh: () async {
                ref.invalidate(conversationsProvider);
                await ref.read(conversationsProvider.future);
              },
              child: CustomScrollView(
                slivers: [
                  // ── Online friends row ─────────────────────────────
                  if (convos.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _OnlineFriendsRow(convos: convos),
                    ),

                  // ── Archived Chats banner (if any) ─────────────────
                  if (archivedCount > 0)
                    SliverToBoxAdapter(
                      child: _ArchivedBannerTile(count: archivedCount),
                    ),

                  // ── Conversation list ──────────────────────────────
                  if (filtered.isEmpty)
                    const SliverFillRemaining(child: _EmptyState())
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) =>
                            _ConversationTile(convo: filtered[i]),
                        childCount: filtered.length,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Online friends horizontal scroll
// ---------------------------------------------------------------------------

class _OnlineFriendsRow extends StatelessWidget {
  const _OnlineFriendsRow({required this.convos});
  final List<ConversationModel> convos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            'Online Friends',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.subtleText,
            ),
          ),
        ),
        SizedBox(
          height: 84,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: convos.length,
            itemBuilder: (context, i) {
              final c    = convos[i];
              final name = c.otherUserName ?? 'User';
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      conversationId: c.id,
                      otherUserName: name,
                      otherUserAvatar: c.otherUserAvatar,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      _OnlineAvatar(
                        name: name,
                        avatarUrl: c.otherUserAvatar,
                        size: 52,
                        showOnline: true,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 54,
                        child: Text(
                          name.split(' ').first,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Archived Chats Banner
// ---------------------------------------------------------------------------

class _ArchivedBannerTile extends StatelessWidget {
  const _ArchivedBannerTile({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.darkBackground : Colors.white,
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.messengerBlue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.archive_outlined,
                  color: AppColors.messengerBlue, size: 22),
            ),
            title: const Text('Archived Chats',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text(
                '$count conversation${count == 1 ? '' : 's'} archived',
                style: const TextStyle(fontSize: 12.5)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArchivedChatsPage()),
              );
            },
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Conversation tile
// ---------------------------------------------------------------------------

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.convo});
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

            if (convo.unreadCount > 0 || convo.unreadCount == -1)
              ListTile(
                leading: const Icon(Icons.mark_chat_read_outlined,
                    color: AppColors.messengerBlue),
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
                leading: const Icon(Icons.mark_chat_unread_outlined,
                    color: AppColors.messengerBlue),
                title: const Text('Mark as Unread'),
                onTap: () async {
                  Navigator.pop(context);
                  await ref
                      .read(chatRepositoryProvider)
                      .markAsUnread(convo.id);
                  ref.invalidate(conversationsProvider);
                },
              ),

            ListTile(
              leading: const Icon(Icons.archive_outlined, color: AppColors.messengerBlue),
              title: const Text('Archive Chat'),
              subtitle: const Text('Move conversation to Archived Chats'),
              onTap: () async {
                Navigator.pop(context);
                await ref
                    .read(chatRepositoryProvider)
                    .toggleArchive(convo.id, true);
                ref.invalidate(conversationsProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${convo.otherUserName ?? 'Chat'} archived. Moved to Archived Chats.'),
                      duration: const Duration(seconds: 4),
                      action: SnackBarAction(
                        label: 'UNDO',
                        textColor: AppColors.messengerBlue,
                        onPressed: () async {
                          await ref
                              .read(chatRepositoryProvider)
                              .toggleArchive(convo.id, false);
                          ref.invalidate(conversationsProvider);
                        },
                      ),
                    ),
                  );
                }
              },
            ),

            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Chat for Me', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Remove conversation from your inbox only'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Delete Chat for Me?'),
                    content: const Text(
                      'This will delete the messages from your view. Your contact will still keep their chat history.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogCtx);
                          await ref
                              .read(chatRepositoryProvider)
                              .deleteConversationForMe(convo.id);
                          ref.invalidate(conversationsProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Chat deleted for you.'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Delete for Me'),
                      ),
                    ],
                  ),
                );
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
    final isDark        = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';
    final name          = convo.otherUserName ?? 'User';
    final previewMsg    = convo.formattedLastMessage(currentUserId);
    final time          = convo.lastMessageAt;
    final unread        = convo.unreadCount;
    final isUnread      = unread > 0 || unread == -1;

    return InkWell(
      onTap: () async {
        try {
          await ref.read(chatRepositoryProvider).markConversationAsRead(convo.id);
          ref.invalidate(conversationsProvider);
        } catch (_) {}

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            _OnlineAvatar(
              name: name,
              avatarUrl: convo.otherUserAvatar,
              size: 54,
              showOnline: true,
            ),
            const SizedBox(width: 12),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 15.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (time != null)
                        Text(
                          _formatTime(time),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isUnread
                                ? AppColors.messengerBlue
                                : AppColors.subtleText,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          previewMsg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isUnread
                                ? (isDark
                                    ? Colors.white
                                    : AppColors.lightText)
                                : AppColors.subtleText,
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Unread badge OR read tick
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.messengerBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else if (unread == -1)
                        // Manual Mark as Unread: blue dot only, NO numbers
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.messengerBlue,
                            shape: BoxShape.circle,
                          ),
                        )
                      else if (convo.isLastMessageMine(currentUserId))
                        const Icon(
                          Icons.done_all,
                          size: 16,
                          color: AppColors.messengerBlue,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now   = DateTime.now();
    final local = dt.toLocal();
    final diff  = now.difference(local);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1)   return '${diff.inMinutes}m';
    if (diff.inDays < 1)    return DateFormat('h:mm a').format(local);
    if (diff.inDays < 7)    return DateFormat('EEE').format(local);
    return DateFormat('MMM d').format(local);
  }
}

// ---------------------------------------------------------------------------
// Reusable avatar with green online dot
// ---------------------------------------------------------------------------

class _OnlineAvatar extends StatelessWidget {
  const _OnlineAvatar({
    required this.name,
    required this.size,
    this.avatarUrl,
    this.showOnline = false,
    this.onTap,
  });

  final String name;
  final String? avatarUrl;
  final double size;
  final bool showOnline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dotSize = size * 0.27;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            backgroundColor: _seedColor(name),
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: size * 0.38,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          if (showOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF31A24C),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Generate a consistent colour from the name
  Color _seedColor(String name) {
    const colors = [
      Color(0xFF1877F2), Color(0xFF6C5CE7), Color(0xFF00B894),
      Color(0xFFE17055), Color(0xFFFDAB4D), Color(0xFF74B9FF),
      Color(0xFFFF7675), Color(0xFF55EFC4),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 64,
                color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No conversations yet',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Go to People tab to start chatting',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      );
}
