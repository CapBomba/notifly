import 'package:equatable/equatable.dart';

/// Notification priority levels.
enum NotificationPriority { normal, high, urgent }

/// Domain model for a single notification item.
///
/// This is the canonical representation used throughout the UI and business
/// logic layers. It is mapped to/from both the Supabase row and the local
/// Drift row.
class NotificationModel extends Equatable {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.payload,
    this.isRead = false,
    this.priority = NotificationPriority.normal,
  });

  final String id;
  final String userId;
  final String title;
  final String body;

  /// Semantic type — 'message' | 'announcement' | 'task_update' | 'generic'.
  final String type;

  final String? payload;
  final bool isRead;
  final NotificationPriority priority;
  final DateTime createdAt;

  // ---------------------------------------------------------------------------
  // Factory — from Supabase row (Map)
  // ---------------------------------------------------------------------------

  factory NotificationModel.fromSupabase(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      type: (map['type'] as String?) ?? 'generic',
      payload: map['payload'] as String?,
      isRead: (map['is_read'] as bool?) ?? false,
      priority: _parsePriority(map['priority'] as int? ?? 0),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // ---------------------------------------------------------------------------
  // Copy
  // ---------------------------------------------------------------------------

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    String? payload,
    bool? isRead,
    NotificationPriority? priority,
    DateTime? createdAt,
  }) =>
      NotificationModel(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        body: body ?? this.body,
        type: type ?? this.type,
        payload: payload ?? this.payload,
        isRead: isRead ?? this.isRead,
        priority: priority ?? this.priority,
        createdAt: createdAt ?? this.createdAt,
      );

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static NotificationPriority _parsePriority(int raw) {
    switch (raw) {
      case 2:
        return NotificationPriority.urgent;
      case 1:
        return NotificationPriority.high;
      default:
        return NotificationPriority.normal;
    }
  }

  int get priorityInt => priority.index;

  bool get isUrgent => priority == NotificationPriority.urgent;

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        body,
        type,
        payload,
        isRead,
        priority,
        createdAt,
      ];
}
