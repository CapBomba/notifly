import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/outbox_table.dart';

part 'outbox_dao.g.dart';

/// Data-access object for the transactional outbox.
@DriftAccessor(tables: [LocalOutboxTable])
class OutboxDao extends DatabaseAccessor<AppDatabase>
    with _$OutboxDaoMixin {
  OutboxDao(super.db);

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// All pending events due for delivery.
  Future<List<LocalOutboxTableData>> getPending() => (select(localOutboxTable)
        ..where((t) =>
            t.status.equals('pending') &
            t.nextRetryAt.isSmallerOrEqualValue(DateTime.now()))
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .get();

  /// All failed events (for diagnostics / admin UI).
  Future<List<LocalOutboxTableData>> getFailed() =>
      (select(localOutboxTable)..where((t) => t.status.equals('failed'))).get();

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Insert a new outbox event.
  Future<void> addEvent(LocalOutboxTableCompanion companion) =>
      into(localOutboxTable).insert(companion);

  /// Mark an event as successfully processed.
  Future<int> markProcessed(String id) =>
      (update(localOutboxTable)..where((t) => t.id.equals(id))).write(
        const LocalOutboxTableCompanion(status: Value('processed')),
      );

  /// Record a failed delivery attempt with exponential back-off.
  Future<int> recordFailure({
    required String id,
    required int attemptCount,
    required String error,
  }) {
    // Back-off: 2^attemptCount minutes, capped at 60 minutes.
    final delayMinutes = (1 << attemptCount).clamp(1, 60);
    final nextRetry =
        DateTime.now().add(Duration(minutes: delayMinutes));

    return (update(localOutboxTable)..where((t) => t.id.equals(id))).write(
      LocalOutboxTableCompanion(
        status: const Value('pending'),
        attemptCount: Value(attemptCount + 1),
        lastError: Value(error),
        nextRetryAt: Value(nextRetry),
      ),
    );
  }

  /// Hard-fail an event that has exceeded the maximum retry threshold.
  Future<int> markFailed(String id) =>
      (update(localOutboxTable)..where((t) => t.id.equals(id))).write(
        const LocalOutboxTableCompanion(status: Value('failed')),
      );

  /// Delete all processed events older than [before].
  Future<int> pruneProcessed(DateTime before) =>
      (delete(localOutboxTable)
            ..where((t) =>
                t.status.equals('processed') &
                t.createdAt.isSmallerOrEqualValue(before)))
          .go();
}
