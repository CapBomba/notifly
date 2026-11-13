import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../chat/presentation/pages/archived_chats_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';

// ---------------------------------------------------------------------------
// Preference keys
// ---------------------------------------------------------------------------

class PrefKeys {
  static const String notificationsEnabled = 'notifications_enabled';
  static const String urgentOnly = 'urgent_only';
  static const String activeStatusEnabled = 'active_status_enabled';
  static const String themeMode = 'theme_mode';
}

// ---------------------------------------------------------------------------
// Theme Mode Provider
// ---------------------------------------------------------------------------

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final v = await AppDatabase.instance.preferencesDao.getValue(PrefKeys.themeMode);
    if (v == 'light') state = ThemeMode.light;
    if (v == 'dark') state = ThemeMode.dark;
    if (v == 'system') state = ThemeMode.system;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    await AppDatabase.instance.preferencesDao.setValue(PrefKeys.themeMode, modeStr);
  }
}

// ---------------------------------------------------------------------------
// General Providers
// ---------------------------------------------------------------------------

final notificationsEnabledProvider = FutureProvider<bool>((ref) async {
  return AppDatabase.instance.preferencesDao
      .getBool(PrefKeys.notificationsEnabled, defaultValue: true);
});

final urgentOnlyProvider = FutureProvider<bool>((ref) async {
  return AppDatabase.instance.preferencesDao.getBool(PrefKeys.urgentOnly);
});

final activeStatusProvider = FutureProvider<bool>((ref) async {
  return AppDatabase.instance.preferencesDao
      .getBool(PrefKeys.activeStatusEnabled, defaultValue: true);
});

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class PreferencesPage extends ConsumerWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsEnabledAsync = ref.watch(notificationsEnabledProvider);
    final urgentOnlyAsync = ref.watch(urgentOnlyProvider);
    final activeStatusAsync = ref.watch(activeStatusProvider);
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentUser = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(userProfileProvider);

    Future<void> setBool(String key, bool value) async {
      await AppDatabase.instance.preferencesDao.setBool(key, value: value);
      ref.invalidate(notificationsEnabledProvider);
      ref.invalidate(urgentOnlyProvider);
      ref.invalidate(activeStatusProvider);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Profile')),
      body: ListView(
        children: [
          // ── User Profile Header Card ───────────────────────────────
          const _SectionHeader(title: 'Account Profile'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: profileAsync.when(
                  data: (p) {
                    final name = p?['display_name'] as String? ??
                        currentUser?.email ??
                        'User';
                    final avatar = p?['avatar_url'] as String? ??
                        currentUser?.userMetadata?['avatar_url'] as String?;
                    return CircleAvatar(
                      radius: 24,
                      backgroundImage:
                          avatar != null ? NetworkImage(avatar) : null,
                      backgroundColor:
                          AppColors.messengerBlue.withValues(alpha: 0.15),
                      child: avatar == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.messengerBlue,
                              ),
                            )
                          : null,
                    );
                  },
                  loading: () => const CircleAvatar(
                    radius: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => CircleAvatar(
                    radius: 24,
                    child: Text(currentUser?.email?[0].toUpperCase() ?? '?'),
                  ),
                ),
                title: profileAsync.when(
                  data: (p) => Text(
                    p?['display_name'] as String? ??
                        currentUser?.email ??
                        'My Profile',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  loading: () => const Text('Loading profile...'),
                  error: (_, __) => Text(currentUser?.email ?? 'My Profile'),
                ),
                subtitle: Text(
                  currentUser?.email ?? 'Tap to view profile details',
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProfilePage()),
                  );
                },
              ),
            ),
          ),

          const Divider(height: 24),

          // ── Archived Chats Section ────────────────────────────────
          const _SectionHeader(title: 'Chat Management'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(Icons.archive_outlined,
                    color: AppColors.messengerBlue),
                title: const Text('Archived Chats',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text(
                    'View archived conversations and move them back to chats'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ArchivedChatsPage()),
                  );
                },
              ),
            ),
          ),

          const Divider(height: 24),

          // ── Theme Mode Section ─────────────────────────────────────
          const _SectionHeader(title: 'App Theme'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose Theme',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode_outlined),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode_outlined),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: Icon(Icons.settings_suggest_outlined),
                        ),
                      ],
                      selected: {currentThemeMode},
                      onSelectionChanged: (Set<ThemeMode> selection) {
                        ref
                            .read(themeModeProvider.notifier)
                            .setMode(selection.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Divider(),

          // ── Privacy & Status Section ──────────────────────────────
          const _SectionHeader(title: 'Privacy & Status'),
          activeStatusAsync.when(
            loading: () => const _SwitchTileSkeleton(),
            error: (e, st) => const SizedBox.shrink(),
            data: (enabled) => SwitchListTile(
              title: const Text('Show Active Status'),
              subtitle: const Text(
                  'Allow contacts to see when you are online or active'),
              value: enabled,
              onChanged: (v) => setBool(PrefKeys.activeStatusEnabled, v),
            ),
          ),

          const Divider(),

          // ── Notifications Section ─────────────────────────────────
          const _SectionHeader(title: 'General Preferences'),

          notificationsEnabledAsync.when(
            loading: () => const _SwitchTileSkeleton(),
            error: (e, st) => const SizedBox.shrink(),
            data: (enabled) => SwitchListTile(
              title: const Text('Enable Notifications'),
              subtitle: const Text(
                  'Show in-app notifications when new events arrive'),
              value: enabled,
              onChanged: (v) => setBool(PrefKeys.notificationsEnabled, v),
            ),
          ),

          urgentOnlyAsync.when(
            loading: () => const _SwitchTileSkeleton(),
            error: (e, st) => const SizedBox.shrink(),
            data: (enabled) => SwitchListTile(
              title: const Text('Urgent Alerts Only'),
              subtitle: const Text(
                  'Only trigger local notifications for high-priority items'),
              value: enabled,
              onChanged: (v) => setBool(PrefKeys.urgentOnly, v),
            ),
          ),

          const Divider(),
          const _SectionHeader(title: 'About Push Delivery'),

          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline),
                        const SizedBox(width: 8),
                        Text(
                          'How notifications work',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'NotiFly uses Supabase Realtime to deliver notifications '
                      'instantly when the app is open.\n\n'
                      'When the app is backgrounded, delivery depends on '
                      'whether the OS keeps the connection alive. Notifications '
                      'sent while the app is fully closed will appear the '
                      'next time you open it.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.2,
              ),
        ),
      );
}

class _SwitchTileSkeleton extends StatelessWidget {
  const _SwitchTileSkeleton();

  @override
  Widget build(BuildContext context) => const ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: SizedBox(height: 14, child: LinearProgressIndicator()),
      );
}
