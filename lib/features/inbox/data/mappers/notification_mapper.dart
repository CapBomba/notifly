import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/models/notification_model.dart';

/// Converts between the domain model, Supabase map, and Drift row.
class NotificationMapper {
  const NotificationMapper._();

  // ---------------------------------------------------------------------------
  // Domain → Drift companion (for upsert)
  // ---------------------------------------------------------------------------

  static LocalNotificationsTableCompanion toCompanion(
    NotificationModel n,
  ) =>
      LocalNotificationsTableCompanion.insert(
        id: n.id,
        userId: n.userId,
        title: n.title,
        body: n.body,
        type: Value(n.type),
        payload: Value(n.payload),
        isRead: Value(n.isRead),
        priority: Value(n.priorityInt),
        createdAt: n.createdAt,
      );

  // ---------------------------------------------------------------------------
  // Drift row → domain
  // ---------------------------------------------------------------------------

  static NotificationModel fromRow(LocalNotificationsTableData row) =>
      NotificationModel(
        id: row.id,
        userId: row.userId,
        title: row.title,
        body: row.body,
        type: row.type,
        payload: row.payload,
        isRead: row.isRead,
        priority: _priorityFromInt(row.priority),
        createdAt: row.createdAt,
      );

  static NotificationPriority _priorityFromInt(int v) {
    switch (v) {
      case 2:
        return NotificationPriority.urgent;
      case 1:
        return NotificationPriority.high;
      default:
        return NotificationPriority.normal;
    }
  }
}
