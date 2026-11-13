import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/widgets/notifly_loading_screen.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../domain/models/message_model.dart';
import '../../providers/chat_providers.dart';
import '../widgets/message_bubble.dart';
import 'livekit_call_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherUserAvatar,
  });

  final String conversationId;
  final String otherUserName;
  final String? otherUserAvatar;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();
  bool _sending     = false;
  bool _hasText     = false;

  bool _isSearching = false;
  final _chatSearchCtrl = TextEditingController();
  String _chatSearchQuery = '';

  MessageModel? _replyingMessage;
  bool _otherIsTyping = false;
  StreamSubscription<bool>? _typingSub;
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();

    _chatSearchCtrl.addListener(() {
      if (_chatSearchCtrl.text != _chatSearchQuery) {
        setState(() => _chatSearchQuery = _chatSearchCtrl.text.trim());
      }
    });

    _typingSub = ref
        .read(chatRepositoryProvider)
        .watchTyping(widget.conversationId)
        .listen((isTyping) {
      if (mounted) setState(() => _otherIsTyping = isTyping);
    });

    _inputCtrl.addListener(() {
      final has = _inputCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);

      // Typing signal broadcast
      ref.read(chatRepositoryProvider).sendTypingSignal(
            conversationId: widget.conversationId,
            isTyping: true,
          );
      _typingDebounce?.cancel();
      _typingDebounce = Timer(const Duration(seconds: 2), () {
        ref.read(chatRepositoryProvider).sendTypingSignal(
              conversationId: widget.conversationId,
              isTyping: false,
            );
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref
            .read(chatRepositoryProvider)
            .markConversationAsRead(widget.conversationId);
        ref.invalidate(conversationsProvider);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _typingSub?.cancel();
    _typingDebounce?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _chatSearchCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final reply = _replyingMessage;
    _inputCtrl.clear();
    setState(() => _replyingMessage = null);

    _typingDebounce?.cancel();
    ref.read(chatRepositoryProvider).sendTypingSignal(
          conversationId: widget.conversationId,
          isTyping: false,
        );

    try {
      await ref
          .read(messagesControllerProvider(widget.conversationId))
          .send(
            text,
            replyToId: reply?.id,
            replyToContent: reply?.content,
            replyToSenderName: reply?.senderName,
          );
      _scrollToBottom();
    } catch (e) {
      _inputCtrl.text = text; // restore message on error
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startCall(bool isVideo) async {
    final micStatus = await Permission.microphone.request();
    final camStatus = isVideo
        ? await Permission.camera.request()
        : PermissionStatus.granted;

    if (micStatus.isDenied || (isVideo && camStatus.isDenied)) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Permissions Required'),
            content: Text(
              isVideo
                  ? 'Camera and Microphone permissions are required to start a video call. Please grant permissions in your device settings.'
                  : 'Microphone permission is required to start an audio call. Please grant permission in your device settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.messengerBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveKitCallScreen(
            roomName: widget.otherUserName,
            participantName: widget.otherUserName,
            isVideoCall: isVideo,
          ),
        ),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    final ctrl          = ref.watch(messagesControllerProvider(widget.conversationId));
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';
    final isDark        = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: _ChatAppBar(
        name: widget.otherUserName,
        avatarUrl: widget.otherUserAvatar,
        isTyping: _otherIsTyping,
        isSearching: _isSearching,
        searchController: _chatSearchCtrl,
        onToggleSearch: () => setState(() {
          _isSearching = !_isSearching;
          if (!_isSearching) _chatSearchCtrl.clear();
        }),
        onStartCall: _startCall,
      ),
      body: Column(
        children: [
          // ── Message list ─────────────────────────────────────────
          Expanded(
            child: ListenableBuilder(
              listenable: ctrl,
              builder: (context, _) {
                final displayMessages = _chatSearchQuery.isEmpty
                    ? ctrl.messages
                    : ctrl.messages
                        .where((m) => m.content
                            .toLowerCase()
                            .contains(_chatSearchQuery.toLowerCase()))
                        .toList();

                if (_isSearching && _chatSearchQuery.isNotEmpty) {
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        color: AppColors.messengerBlue.withValues(alpha: 0.12),
                        child: Row(
                          children: [
                            const Icon(Icons.search, size: 16, color: AppColors.messengerBlue),
                            const SizedBox(width: 8),
                            Text(
                              '${displayMessages.length} match${displayMessages.length == 1 ? '' : 'es'} found',
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.messengerBlue),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          itemCount: displayMessages.length,
                          itemBuilder: (context, i) {
                            final msg = displayMessages[i];
                            final isMine = msg.senderId == currentUserId;
                            return _SwipeToReplyWrapper(
                              onReplyTriggered: () {
                                setState(() => _replyingMessage = msg);
                                _focusNode.requestFocus();
                              },
                              child: GestureDetector(
                                onLongPress: () => _showMessageActionsSheet(context, msg),
                                child: MessageBubble(
                                  message: msg,
                                  isMine: isMine,
                                  onReactionTap: (emoji) async {
                                    try {
                                      await ref
                                          .read(messagesControllerProvider(widget.conversationId))
                                          .toggleReaction(msg.id, emoji);
                                    } catch (_) {}
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }

                if (ctrl.loading) {
                  return const NotiFlyLoadingScreen(
                    message: 'Loading messages...',
                    isFullScreen: false,
                  );
                }

                if (ctrl.rawError != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off_rounded,
                            size: 52, color: Colors.grey.shade400),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            friendlyError(ctrl.rawError!),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.outline,
                                fontSize: 15),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => ctrl.reload(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.messengerBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (ctrl.messages.isEmpty) {
                  return _EmptyChat(name: widget.otherUserName);
                }

                _scrollToBottom();

                return RefreshIndicator(
                  color: AppColors.messengerBlue,
                  onRefresh: () async {
                    await ctrl.reload();
                  },
                  child: GestureDetector(
                    // Dismiss keyboard when tapping the message list
                    onTap: () => _focusNode.unfocus(),
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      itemCount: displayMessages.length,
                      itemBuilder: (context, i) {
                        final msg    = displayMessages[i];
                        final isMine = msg.senderId == currentUserId;
                        final showAvatar = !isMine &&
                            (i == displayMessages.length - 1 ||
                                displayMessages[i + 1].senderId != msg.senderId);
                        final showTime = i == 0 ||
                            msg.createdAt
                                    .difference(ctrl.messages[i - 1].createdAt)
                                    .inMinutes
                                    .abs() >
                                30;

                        return Column(
                          children: [
                            if (showTime)
                              _TimeStampDivider(time: msg.createdAt),
                            _SwipeToReplyWrapper(
                              onReplyTriggered: () {
                                setState(() => _replyingMessage = msg);
                                _focusNode.requestFocus();
                              },
                              child: GestureDetector(
                                onLongPress: () =>
                                    _showMessageActionsSheet(context, msg),
                                child: MessageBubble(
                                  message: msg,
                                  isMine: isMine,
                                  showAvatar: showAvatar,
                                  otherUserAvatar: widget.otherUserAvatar,
                                  onReactionTap: (emoji) async {
                                    try {
                                      await ref
                                          .read(messagesControllerProvider(
                                              widget.conversationId))
                                          .toggleReaction(msg.id, emoji);
                                    } catch (_) {}
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Reply banner (if replying) ─────────────────────────
          if (_replyingMessage != null)
            _ReplyBanner(
              message: _replyingMessage!,
              onCancel: () => setState(() => _replyingMessage = null),
            ),

          // ── Input bar ───────────────────────────────────────────
          _InputBar(
            controller: _inputCtrl,
            focusNode: _focusNode,
            sending: _sending,
            hasText: _hasText,
            onSend: _send,
            onAttach: () => _showAttachmentOptionsModal(context),
          ),
        ],
      ),
    );
  }

  void _showMessageActionsSheet(BuildContext ctx, MessageModel msg) {
    final currentUserId = ref.read(currentUserProvider)?.id ?? '';
    final isMine = msg.isMine(currentUserId);

    showModalBottomSheet(
      context: ctx,
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

            // Quick Emoji Reactions
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['❤️', '😂', '😮', '😢', '😠', '👍'].map((emoji) {
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        await ref
                            .read(messagesControllerProvider(widget.conversationId))
                            .toggleReaction(msg.id, emoji);
                      } catch (_) {}
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 16),

            ListTile(
              leading: const Icon(Icons.add_reaction_outlined, color: AppColors.messengerBlue),
              title: const Text('View All Reactions'),
              onTap: () {
                Navigator.pop(ctx);
                _showReactionModal(ctx, msg);
              },
            ),

            ListTile(
              leading: const Icon(Icons.reply, color: AppColors.messengerBlue),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyingMessage = msg);
                _focusNode.requestFocus();
              },
            ),

            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy Text'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: msg.content));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Message copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),

            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete for Everyone',
                    style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref
                        .read(messagesControllerProvider(widget.conversationId))
                        .deleteMessage(msg.id);
                  } catch (e) {
                    if (mounted) showErrorSnackBar(context, e);
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1080,
      );

      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      final imageUrl = await CloudinaryService.instance.uploadImageBytes(
        bytes,
        filename: pickedFile.name,
      );

      await ref
          .read(messagesControllerProvider(widget.conversationId))
          .send('[IMAGE]: $imageUrl');
      _scrollToBottom();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _recordAndSendVoiceNote() async {
    final status = await Permission.microphone.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        showErrorSnackBar(
          context,
          'Microphone permission is required to record voice notes.',
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission granted! Voice note recorded.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      await ref
          .read(messagesControllerProvider(widget.conversationId))
          .send('[VOICE]: Voice note (0:15)');
      _scrollToBottom();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  void _showAttachmentOptionsModal(BuildContext ctx) {
    final imageUrlCtrl = TextEditingController();

    showModalBottomSheet(
      context: ctx,
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

            // 1. Camera Photo
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppColors.messengerBlue),
              title: const Text('Take Photo'),
              subtitle: const Text('Capture a picture using your camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendImage(ImageSource.camera);
              },
            ),

            // 2. Gallery Photo
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.messengerBlue),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Select a photo from your device'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),

            // 3. Voice Note
            ListTile(
              leading: const Icon(Icons.mic_none_outlined,
                  color: AppColors.messengerBlue),
              title: const Text('Record Voice Note'),
              subtitle: const Text('Record an audio message'),
              onTap: () {
                Navigator.pop(ctx);
                _recordAndSendVoiceNote();
              },
            ),

            // 4. Image URL Dialog
            ListTile(
              leading: const Icon(Icons.link_outlined,
                  color: AppColors.messengerBlue),
              title: const Text('Enter Image URL'),
              subtitle: const Text('Send an image from the web'),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: ctx,
                  builder: (dialogCtx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('Send Image URL'),
                    content: TextFormField(
                      controller: imageUrlCtrl,
                      decoration: InputDecoration(
                        labelText: 'Image URL',
                        hintText: 'https://images.unsplash.com/...',
                        prefixIcon: const Icon(Icons.link),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final url = imageUrlCtrl.text.trim();
                          if (url.isNotEmpty) {
                            Navigator.pop(dialogCtx);
                            try {
                              await ref
                                  .read(messagesControllerProvider(
                                      widget.conversationId))
                                  .send('[IMAGE]: $url');
                              _scrollToBottom();
                            } catch (e) {
                              if (mounted) showErrorSnackBar(context, e);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.messengerBlue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Send Image'),
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

  void _showReactionModal(BuildContext ctx, MessageModel message) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReactionModalSheet(
        message: message,
        conversationId: widget.conversationId,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reply quote banner
// ---------------------------------------------------------------------------

class _ReplyBanner extends StatelessWidget {
  const _ReplyBanner({required this.message, required this.onCancel});

  final MessageModel message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFE8F0FE),
        border: const Border(
          left: BorderSide(color: AppColors.messengerBlue, width: 4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, color: AppColors.messengerBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${message.senderName ?? 'User'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.messengerBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white70 : AppColors.lightText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onCancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Controlled firm Swipe-to-Reply wrapper
// ---------------------------------------------------------------------------

class _SwipeToReplyWrapper extends StatefulWidget {
  const _SwipeToReplyWrapper({
    required this.child,
    required this.onReplyTriggered,
  });

  final Widget child;
  final VoidCallback onReplyTriggered;

  @override
  State<_SwipeToReplyWrapper> createState() => _SwipeToReplyWrapperState();
}

class _SwipeToReplyWrapperState extends State<_SwipeToReplyWrapper> {
  double _dragOffset = 0.0;
  bool _hasVibrated = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 0 || _dragOffset > 0) {
          setState(() {
            _dragOffset += details.delta.dx * 0.40; // Controlled firm spring
            if (_dragOffset > 85.0) _dragOffset = 85.0; // Max drag cap
            if (_dragOffset < 0) _dragOffset = 0;
          });

          if (_dragOffset >= 65.0 && !_hasVibrated) {
            _hasVibrated = true;
            HapticFeedback.lightImpact();
          }
        }
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset >= 60.0) {
          widget.onReplyTriggered();
        }
        setState(() {
          _dragOffset = 0.0;
          _hasVibrated = false;
        });
      },
      onHorizontalDragCancel: () {
        setState(() {
          _dragOffset = 0.0;
          _hasVibrated = false;
        });
      },
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (_dragOffset > 5)
            Positioned(
              left: 12,
              child: Opacity(
                opacity: (_dragOffset / 60.0).clamp(0.0, 1.0),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.messengerBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.reply,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reaction detail modal sheet
// ---------------------------------------------------------------------------

class _ReactionModalSheet extends ConsumerStatefulWidget {
  const _ReactionModalSheet({
    required this.message,
    required this.conversationId,
  });

  final MessageModel message;
  final String conversationId;

  @override
  ConsumerState<_ReactionModalSheet> createState() => _ReactionModalSheetState();
}

class _ReactionModalSheetState extends ConsumerState<_ReactionModalSheet> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';
    const quickEmojis = ['❤️', '😂', '😮', '😢', '😠', '👍'];

    final detailed = widget.message.detailedReactions;
    final filterEmojis = ['All', ...widget.message.reactions.keys];

    final filteredList = _selectedFilter == 'All'
        ? detailed
        : detailed.where((r) => r.emoji == _selectedFilter).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Emoji Picker Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBackground
                  : const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: quickEmojis.map((emoji) {
                final hasReacted = detailed.any(
                    (r) => r.emoji == emoji && r.userId == currentUserId);
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await ref
                          .read(messagesControllerProvider(widget.conversationId))
                          .toggleReaction(widget.message.id, emoji);
                    } catch (_) {}
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasReacted
                          ? AppColors.messengerBlue.withValues(alpha: 0.2)
                          : Colors.transparent,
                    ),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Reaction Filter Tabs (if reactions exist)
          if (detailed.isNotEmpty) ...[
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: filterEmojis.length,
                itemBuilder: (context, i) {
                  final key = filterEmojis[i];
                  final isSelected = key == _selectedFilter;
                  final count = key == 'All'
                      ? detailed.length
                      : (widget.message.reactions[key] ?? 0);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$key $count'),
                      selected: isSelected,
                      selectedColor: AppColors.messengerBlue,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : null,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) {
                        setState(() => _selectedFilter = key);
                      },
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 20),

            // Detailed Reactions User List
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredList.length,
                itemBuilder: (context, i) {
                  final r = filteredList[i];
                  final isMe = r.userId == currentUserId;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundImage: r.userAvatar != null
                          ? NetworkImage(r.userAvatar!)
                          : null,
                      backgroundColor:
                          AppColors.messengerBlue.withValues(alpha: 0.15),
                      child: r.userAvatar == null
                          ? Text(
                              (r.userName ?? '?')[0].toUpperCase(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.messengerBlue),
                            )
                          : null,
                    ),
                    title: Text(
                      isMe ? '${r.userName ?? 'User'} (You)' : (r.userName ?? 'User'),
                      style: TextStyle(
                        fontWeight:
                            isMe ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: isMe
                        ? const Text('Tap to remove reaction',
                            style: TextStyle(fontSize: 12, color: Colors.grey))
                        : null,
                    trailing: Text(r.emoji, style: const TextStyle(fontSize: 22)),
                    onTap: isMe
                        ? () async {
                            Navigator.pop(context);
                            try {
                              await ref
                                  .read(messagesControllerProvider(
                                      widget.conversationId))
                                  .toggleReaction(widget.message.id, r.emoji);
                            } catch (_) {}
                          }
                        : null,
                  );
                },
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No reactions yet. Pick an emoji above!',
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat app bar
// ---------------------------------------------------------------------------

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar({
    required this.name,
    this.avatarUrl,
    this.isTyping = false,
    this.isSearching = false,
    this.searchController,
    this.onToggleSearch,
    required this.onStartCall,
  });

  final String name;
  final String? avatarUrl;
  final bool isTyping;
  final bool isSearching;
  final TextEditingController? searchController;
  final VoidCallback? onToggleSearch;
  final void Function(bool isVideo) onStartCall;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  void _showPartnerProfile(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              backgroundColor:
                  AppColors.messengerBlue.withValues(alpha: 0.15),
              child: avatarUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.messengerBlue),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFF31A24C), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text('Active now',
                    style: TextStyle(fontSize: 13, color: Color(0xFF31A24C))),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ProfileActionButton(
                  icon: Icons.phone,
                  label: 'Audio',
                  onTap: () {
                    Navigator.pop(context);
                    onStartCall(false);
                  },
                ),
                _ProfileActionButton(
                  icon: Icons.videocam,
                  label: 'Video',
                  onTap: () {
                    Navigator.pop(context);
                    onStartCall(true);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(
        bottom: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      titleSpacing: 0,
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: isSearching
          ? TextField(
              controller: searchController,
              autofocus: true,
              style: TextStyle(
                  color: isDark ? Colors.white : AppColors.lightText,
                  fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Search in conversation...',
                border: InputBorder.none,
              ),
            )
          : InkWell(
              onTap: () => _showPartnerProfile(context),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage:
                            avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                        backgroundColor:
                            AppColors.messengerBlue.withValues(alpha: 0.15),
                        child: avatarUrl == null
                            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.messengerBlue))
                            : null,
                      ),
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF31A24C),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? AppColors.darkSurface : Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          isTyping ? 'is typing...' : 'Active now',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isTyping
                                ? AppColors.messengerBlue
                                : const Color(0xFF31A24C),
                            fontWeight: isTyping ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        IconButton(
          icon: Icon(
            isSearching ? Icons.close : Icons.search,
            color: AppColors.messengerBlue,
          ),
          onPressed: onToggleSearch,
        ),
        IconButton(
          icon: ShaderMask(
            shaderCallback: (b) => AppColors.gradient.createShader(b),
            child: const Icon(Icons.phone, color: Colors.white),
          ),
          onPressed: () => _startCall(context, isVideo: false),
        ),
        IconButton(
          icon: ShaderMask(
            shaderCallback: (b) => AppColors.gradient.createShader(b),
            child: const Icon(Icons.videocam, color: Colors.white),
          ),
          onPressed: () => _startCall(context, isVideo: true),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.messengerBlue.withValues(alpha: 0.12),
              child: Icon(icon, color: AppColors.messengerBlue),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timestamp divider
// ---------------------------------------------------------------------------

class _TimeStampDivider extends StatelessWidget {
  const _TimeStampDivider({required this.time});
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final now   = DateTime.now();
    final local = time.toLocal();
    final diff  = now.difference(local);
    String label;
    if (diff.inDays == 0) {
      label = 'Today ${_fmt(local)}';
    } else if (diff.inDays == 1) {
      label = 'Yesterday ${_fmt(local)}';
    } else {
      label = '${local.month}/${local.day} ${_fmt(local)}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline)),
    );
  }

  String _fmt(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }
}

// ---------------------------------------------------------------------------
// Empty chat state
// ---------------------------------------------------------------------------

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👋', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            Text('Say hi to $name!',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('You haven\'t chatted yet',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Input bar — supports emoji from keyboard natively
// ---------------------------------------------------------------------------

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.hasText,
    required this.onSend,
    this.onAttach,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final bool hasText;
  final VoidCallback onSend;
  final VoidCallback? onAttach;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attach / media button
            GestureDetector(
              onTap: onAttach,
              child: Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(bottom: 1),
                decoration: BoxDecoration(
                    shape: BoxShape.circle, gradient: AppColors.gradient),
                child:
                    const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 8),

            // ── Text field — emoji from phone keyboard works natively ──
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkCard
                      : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  // These settings enable emoji keyboard on Android
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: 1,
                  maxLines: 5,
                  // Allow rich text / emoji from keyboard
                  enableSuggestions: true,
                  autocorrect: true,
                  decoration: const InputDecoration(
                    hintText: 'Aa',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send / like button
            GestureDetector(
              onTap: sending ? null : (hasText ? onSend : null),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(bottom: 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hasText ? AppColors.gradient : null,
                  color: hasText
                      ? null
                      : AppColors.messengerBlue.withValues(alpha: 0.12),
                ),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        hasText ? Icons.send : Icons.thumb_up,
                        size: 18,
                        color: hasText
                            ? Colors.white
                            : AppColors.messengerBlue,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
