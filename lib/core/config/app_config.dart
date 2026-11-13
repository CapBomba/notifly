/// Central place for environment-level configuration.
class AppConfig {
  AppConfig._();

  // ---------------------------------------------------------------------------
  // Supabase
  // ---------------------------------------------------------------------------

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://oigwtrrjlgetxqqkwunc.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_Wj88x3PZg0uGsuLHQ88G0g_UaCsqwAW',
  );

  // ---------------------------------------------------------------------------
  // Android notification channels
  // ---------------------------------------------------------------------------

  static const String defaultChannelId = 'notifly_default';
  static const String defaultChannelName = 'General Notifications';
  static const String defaultChannelDescription =
      'General app notifications from NotiFly';

  static const String urgentChannelId = 'notifly_urgent';
  static const String urgentChannelName = 'Urgent Alerts';
  static const String urgentChannelDescription =
      'High-priority alerts that require immediate attention';

  static const String chatChannelId = 'notifly_chat';
  static const String chatChannelName = 'Chat Messages';
  static const String chatChannelDescription =
      'New messages from your conversations';

  // ---------------------------------------------------------------------------
  // Supabase table / function names
  // ---------------------------------------------------------------------------

  static const String notificationsTable = 'notifications';
  static const String outboxTable = 'notification_outbox';
  static const String preferencesTable = 'notification_preferences';
  static const String profilesTable = 'profiles';
  static const String announcementsTable = 'announcements';
  static const String conversationsTable = 'conversations';
  static const String messagesTable = 'messages';
  static const String fcmTokensTable = 'fcm_tokens';
  static const String conversationMembersTable = 'conversation_members';
}
