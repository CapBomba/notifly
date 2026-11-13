import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/notification_model.dart';

/// A dismissible card representing a single notification in the inbox list.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismissed,
  });

  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: colorScheme.errorContainer,
        child: Icon(Icons.delete_outline,
            color: colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => onDismissed(),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ----- Icon / unread indicator -----
                _LeadingIcon(notification: notification),
                const SizedBox(width: 12),

                // ----- Content -----
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: notification.isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _relativeTime(notification.createdAt),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: colorScheme.outline,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Body preview
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: notification.isRead
                                  ? colorScheme.outline
                                  : null,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MMM d').format(dt.toLocal());
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.notification});
  final NotificationModel notification;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final icon = switch (notification.type) {
      'message' => Icons.chat_bubble_outline,
      'announcement' => Icons.campaign_outlined,
      'task_update' => Icons.task_alt_outlined,
      _ => Icons.notifications_outlined,
    };

    final bg = notification.isUrgent
        ? colorScheme.errorContainer
        : notification.isRead
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primaryContainer;

    final fg = notification.isUrgent
        ? colorScheme.onErrorContainer
        : notification.isRead
            ? colorScheme.onSurfaceVariant
            : colorScheme.onPrimaryContainer;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: fg, size: 22),
        ),
        // Unread dot
        if (!notification.isRead)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
