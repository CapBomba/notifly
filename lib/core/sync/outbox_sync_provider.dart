import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import 'outbox_sync_service.dart';

/// Starts [OutboxSyncService] while the user is signed in and stops it
/// when the provider is disposed (sign-out / app teardown).
final outboxSyncProvider = Provider<OutboxSyncService>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) throw StateError('No authenticated user');

  final service = OutboxSyncService();
  service.start();
  ref.onDispose(service.stop);

  return service;
});
