import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/notification_model.dart';

/// Full-screen view for a single notification.
class NotificationDetailPage extends StatelessWidget {
  const NotificationDetailPage({super.key, required this.notification});

  final NotificationModel notification;

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM d, yyyy · h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification'),
        actions: [
          // Priority chip in app bar
          if (notification.isUrgent)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: const Text('URGENT'),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type pill
            _TypeChip(type: notification.type),
            const SizedBox(height: 16),

            // Title
            Text(
              notification.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),

            // Timestamp
            Text(
              dateFormatter.format(notification.createdAt.toLocal()),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const Divider(height: 32),

            // Body
            Text(
              notification.body,
              style: Theme.of(context).textTheme.bodyLarge,
            ),

            // Payload (debug / developer info)
            if (notification.payload != null) ...[
              const SizedBox(height: 32),
              Text(
                'Payload',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  notification.payload!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      'message' => 'Message',
      'announcement' => 'Announcement',
      'task_update' => 'Task Update',
      _ => 'Notification',
    };

    final icon = switch (type) {
      'message' => Icons.chat_bubble_outline,
      'announcement' => Icons.campaign_outlined,
      'task_update' => Icons.task_alt_outlined,
      _ => Icons.notifications_outlined,
    };

    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
