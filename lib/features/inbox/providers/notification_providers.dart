import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../data/repositories/notification_repository.dart';
import '../domain/models/notification_model.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Creates and manages the lifecycle of [NotificationRepository].
/// Re-created whenever auth state changes (login / logout).
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) throw StateError('No authenticated user');

  final repo = NotificationRepository(userId: user.id);
  repo.subscribeRealtime();
  repo.syncFromRemote(); // fire-and-forget; errors are logged internally

  ref.onDispose(() {
    repo.dispose();
  });

  return repo;
});

// ---------------------------------------------------------------------------
// Notifications stream
// ---------------------------------------------------------------------------

/// Reactive stream of all notifications for the current user.
/// Backed by the local Drift cache — works offline.
final notificationsProvider =
    StreamProvider<List<NotificationModel>>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.watchNotifications();
});

/// Count of unread notifications.
final unreadCountProvider = Provider<int>((ref) {
  final asyncVal = ref.watch(notificationsProvider);
  final list = asyncVal.when(
    data: (d) => d,
    loading: () => <NotificationModel>[],
    error: (e, _) => <NotificationModel>[],
  );
  return list.where((n) => !n.isRead).length;
});

// ---------------------------------------------------------------------------
// Actions (top-level functions called from UI)
// ---------------------------------------------------------------------------

Future<void> markNotificationRead(
  WidgetRef ref,
  String notificationId,
) =>
    ref.read(notificationRepositoryProvider).markRead(notificationId);

Future<void> markAllNotificationsRead(WidgetRef ref) =>
    ref.read(notificationRepositoryProvider).markAllRead();
