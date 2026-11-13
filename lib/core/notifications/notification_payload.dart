import 'dart:convert';

/// The JSON payload attached to a local notification.
/// Enables the app to navigate to the right screen when the user taps a
/// notification — even if it arrived while the app was backgrounded.
class NotificationPayload {
  const NotificationPayload({
    required this.notificationId,
    this.type = 'generic',
    this.deepLink,
  });

  /// The UUID of the notification in the local database.
  final String notificationId;

  /// Semantic type matching the remote row's `type` column.
  final String type;

  /// Optional deep-link path for in-app navigation.
  final String? deepLink;

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  factory NotificationPayload.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return NotificationPayload(
      notificationId: map['notification_id'] as String,
      type: (map['type'] as String?) ?? 'generic',
      deepLink: map['deep_link'] as String?,
    );
  }

  String toJson() => jsonEncode({
        'notification_id': notificationId,
        'type': type,
        'deep_link': deepLink,
      });

  @override
  String toString() =>
      'NotificationPayload(notificationId: $notificationId, type: $type)';
}
