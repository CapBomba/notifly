import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/message_model.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showAvatar = false,
    this.otherUserAvatar,
    this.onReactionTap,
  });

  final MessageModel message;
  final bool isMine;
  final bool showAvatar;
  final String? otherUserAvatar;
  final void Function(String emoji)? onReactionTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        top: 2, bottom: 2,
        left: isMine ? 60 : 0,
        right: isMine ? 0 : 60,
      ),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Other user's avatar
          if (!isMine) ...[
            SizedBox(
              width: 30,
              child: showAvatar
                  ? CircleAvatar(
                      radius: 14,
                      backgroundImage: otherUserAvatar != null
                          ? NetworkImage(otherUserAvatar!)
                          : null,
                      backgroundColor:
                          AppColors.messengerBlue.withValues(alpha: 0.15),
                      child: otherUserAvatar == null
                          ? Text(
                              (message.senderName ?? '?')[0].toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.messengerBlue,
                                  fontWeight: FontWeight.bold),
                            )
                          : null,
                    )
                  : null,
            ),
            const SizedBox(width: 6),
          ],

          // Bubble + reactions
          Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Bubble
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65,
                ),
                child: isMine
                    ? _SentBubble(message: message)
                    : _ReceivedBubble(message: message, isDark: isDark),
              ),

              // Reactions row (if any)
              if (message.reactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: _ReactionsRow(
                    reactions: message.reactions,
                    onTap: onReactionTap,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reactions row
// ---------------------------------------------------------------------------

class _ReactionsRow extends StatelessWidget {
  const _ReactionsRow({required this.reactions, this.onTap});
  final Map<String, int> reactions; // emoji → count
  final void Function(String emoji)? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 4,
      children: reactions.entries.map((e) {
        return GestureDetector(
          onTap: () => onTap?.call(e.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightMuted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
            ),
            child: Text(
              e.value > 1 ? '${e.key} ${e.value}' : e.key,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Sent bubble — gradient blue
// ---------------------------------------------------------------------------

class _SentBubble extends StatelessWidget {
  const _SentBubble({required this.message});
  final MessageModel message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.replyToContent != null)
                _QuotedSnippet(
                  senderName: message.replyToSenderName ?? 'User',
                  content: message.replyToContent!,
                  isMine: true,
                ),
              if (message.imageUrl != null) ...[
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            _FullscreenImageViewer(imageUrl: message.imageUrl!),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SmartImage(imageUrl: message.imageUrl!),
                  ),
                ),
                if (message.content.isNotEmpty && message.content != '📷 Photo')
                  const SizedBox(height: 6),
              ],
              if (message.isVoiceNote)
                const _VoiceNoteBubble(isMine: true)
              else if (message.content.isNotEmpty &&
                  (message.imageUrl == null || message.content != '📷 Photo'))
                Text(
                  message.content,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, height: 1.3),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(message.createdAt),
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.done_all,
                size: 14,
                color: AppColors.messengerBlue,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Received bubble
// ---------------------------------------------------------------------------

class _ReceivedBubble extends StatelessWidget {
  const _ReceivedBubble({required this.message, required this.isDark});
  final MessageModel message;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.replyToContent != null)
                _QuotedSnippet(
                  senderName: message.replyToSenderName ?? 'User',
                  content: message.replyToContent!,
                  isMine: false,
                ),
              if (message.imageUrl != null) ...[
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            _FullscreenImageViewer(imageUrl: message.imageUrl!),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SmartImage(imageUrl: message.imageUrl!),
                  ),
                ),
                if (message.content.isNotEmpty && message.content != '📷 Photo')
                  const SizedBox(height: 6),
              ],
              if (message.isVoiceNote)
                const _VoiceNoteBubble(isMine: false)
              else if (message.content.isNotEmpty &&
                  (message.imageUrl == null || message.content != '📷 Photo'))
                Text(
                  message.content,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.lightText,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            _formatTime(message.createdAt),
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline),
          ),
        ),
      ],
    );
  }
}

class SmartImage extends StatelessWidget {
  const SmartImage({super.key, required this.imageUrl, this.fit = BoxFit.cover});
  final String imageUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('data:image/')) {
      try {
        final base64Str = imageUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (_, __, ___) => const SizedBox(
            height: 140,
            child: Icon(Icons.broken_image, color: Colors.white),
          ),
        );
      } catch (_) {
        return const SizedBox(
          height: 140,
          child: Icon(Icons.broken_image, color: Colors.white),
        );
      }
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      maxHeightDiskCache: 600,
      placeholder: (context, url) => const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => const SizedBox(
        height: 140,
        child: Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }
}

class _FullscreenImageViewer extends StatelessWidget {
  const _FullscreenImageViewer({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: SmartImage(imageUrl: imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _VoiceNoteBubble extends StatefulWidget {
  const _VoiceNoteBubble({required this.isMine});
  final bool isMine;

  @override
  State<_VoiceNoteBubble> createState() => _VoiceNoteBubbleState();
}

class _VoiceNoteBubbleState extends State<_VoiceNoteBubble> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isMine ? Colors.white : AppColors.messengerBlue;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isPlaying = !_isPlaying),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
            ),
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: color,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Row(
          children: [3, 5, 8, 4, 9, 6, 8, 5, 3, 7, 5, 2].map((h) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: h * 2.2,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }).toList(),
        ),
        const SizedBox(width: 8),
        Text(
          '0:15',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _QuotedSnippet extends StatelessWidget {
  const _QuotedSnippet({
    required this.senderName,
    required this.content,
    required this.isMine,
  });

  final String senderName;
  final String content;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withValues(alpha: 0.2)
            : AppColors.messengerBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMine ? Colors.white : AppColors.messengerBlue,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isMine ? Colors.white : AppColors.messengerBlue,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: isMine
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _formatTime(DateTime dt) {
  final local = dt.toLocal();
  final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m ${local.hour < 12 ? 'AM' : 'PM'}';
}
