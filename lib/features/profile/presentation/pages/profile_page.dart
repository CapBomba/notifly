import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../chat/providers/chat_providers.dart';

final userProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  try {
    final response = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    return response;
  } catch (_) {
    return null;
  }
});

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nicknameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  bool _checkIsGoogleUser(User user) {
    final provider = user.appMetadata['provider'] as String? ?? '';
    final hasGoogle = user.identities?.any((i) => i.provider == 'google') ?? false;
    return provider == 'google' || hasGoogle;
  }

  Future<void> _saveNickname(User user) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final nickname = _nicknameCtrl.text.trim();

    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'email': user.email ?? '',
        'display_name': nickname,
        'updated_at': DateTime.now().toIso8601String(),
      });

      ref.invalidate(userProfileProvider);
      ref.invalidate(conversationsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nickname saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('No user logged in.')),
      );
    }

    final isGoogle = _checkIsGoogleUser(user);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0.5,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (profile) {
          final currentName = profile?['display_name'] as String? ??
              user.userMetadata?['full_name'] as String? ??
              user.userMetadata?['name'] as String? ??
              '';
          final avatarUrl = profile?['avatar_url'] as String? ??
              user.userMetadata?['avatar_url'] as String? ??
              user.userMetadata?['picture'] as String?;

          if (!_initialized) {
            _nicknameCtrl.text = currentName;
            _initialized = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ── Header Card ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundImage:
                                avatarUrl != null ? NetworkImage(avatarUrl) : null,
                            backgroundColor:
                                AppColors.messengerBlue.withValues(alpha: 0.15),
                            child: avatarUrl == null
                                ? Text(
                                    currentName.isNotEmpty
                                        ? currentName[0].toUpperCase()
                                        : (user.email?.isNotEmpty == true
                                            ? user.email![0].toUpperCase()
                                            : '?'),
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.messengerBlue,
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        currentName.isNotEmpty ? currentName : (user.email ?? 'User'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email ?? '',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Provider Badge
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isGoogle
                              ? const Color(0xFF4285F4).withValues(alpha: 0.12)
                              : AppColors.messengerBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isGoogle ? Icons.g_mobiledata : Icons.email,
                              color: isGoogle
                                  ? const Color(0xFF4285F4)
                                  : AppColors.messengerBlue,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isGoogle ? 'Google Account' : 'Email Account',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isGoogle
                                    ? const Color(0xFF4285F4)
                                    : AppColors.messengerBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Google Details OR Manual Email + Nickname ────────────
                if (isGoogle) ...[
                  // Google Details card
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.info_outline, color: AppColors.messengerBlue),
                              SizedBox(width: 8),
                              Text(
                                'Account Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _DetailRow(
                            label: 'Display Name',
                            value: currentName.isNotEmpty ? currentName : 'Not set',
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            label: 'Gmail / Email',
                            value: user.email ?? 'N/A',
                          ),
                          const SizedBox(height: 12),
                          const _DetailRow(
                            label: 'Sign-in Method',
                            value: 'Google Sign-In (OAuth)',
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F0FE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.check_circle_outline,
                                    color: Color(0xFF1A73E8), size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Account details are synced from Google.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF174EA6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Manual Email + Set Nickname Form
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.badge_outlined,
                                    color: AppColors.messengerBlue),
                                SizedBox(width: 8),
                                Text(
                                  'Set Nickname',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Set a custom nickname to display in chats and messages.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            const Divider(height: 24),

                            TextFormField(
                              controller: _nicknameCtrl,
                              decoration: InputDecoration(
                                labelText: 'Nickname',
                                hintText: 'Enter your preferred nickname',
                                prefixIcon: const Icon(Icons.person_outline),
                                filled: true,
                                fillColor: isDark
                                    ? AppColors.darkBackground
                                    : const Color(0xFFF2F4F7),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Please enter a nickname';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _saving ? null : () => _saveNickname(user),
                                icon: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(_saving ? 'Saving...' : 'Save Nickname'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.messengerBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Account Info Card
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.email_outlined,
                                  color: AppColors.messengerBlue),
                              SizedBox(width: 8),
                              Text(
                                'Account Info',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _DetailRow(
                            label: 'Email',
                            value: user.email ?? 'N/A',
                          ),
                          const SizedBox(height: 12),
                          const _DetailRow(
                            label: 'Creation Method',
                            value: 'Manual Email Registration',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // ── Sign Out Button ─────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(authActionsProvider).signOut();
                      if (context.mounted) {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      }
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
