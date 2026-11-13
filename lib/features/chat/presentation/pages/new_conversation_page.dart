import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/widgets/notifly_loading_screen.dart';
import '../../providers/chat_providers.dart';
import 'chat_screen.dart';

class NewConversationPage extends ConsumerStatefulWidget {
  const NewConversationPage({super.key});

  @override
  ConsumerState<NewConversationPage> createState() =>
      _NewConversationPageState();
}

class _NewConversationPageState
    extends ConsumerState<NewConversationPage> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _all      = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final users =
          await ref.read(chatRepositoryProvider).searchUsers('');

      users.sort((a, b) {
        final nameA = (a['display_name'] as String? ?? a['email'] as String? ?? '').toLowerCase();
        final nameB = (b['display_name'] as String? ?? b['email'] as String? ?? '').toLowerCase();
        return nameA.compareTo(nameB);
      });

      setState(() { _all = users; _filtered = users; });
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((u) {
              final n = (u['display_name'] as String? ?? '').toLowerCase();
              final e = (u['email']        as String? ?? '').toLowerCase();
              return n.contains(q) || e.contains(q);
            }).toList();
    });
  }

  Future<void> _openChat(Map<String, dynamic> user) async {
    setState(() => _loading = true);
    try {
      final convId = await ref
          .read(chatRepositoryProvider)
          .getOrCreateConversation(user['id'] as String);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: convId,
            otherUserName: user['display_name'] as String? ??
                user['email']        as String? ?? 'User',
            otherUserAvatar: user['avatar_url'] as String?,
          ),
        ),
      );
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : const Color(0xFFF5F5F5),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(116),
          child: Container(
            color: AppColors.messengerBlue,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'People',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search people...',
                        hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7)),
                        prefixIcon: Icon(Icons.search,
                            color:
                                Colors.white.withValues(alpha: 0.8),
                            size: 20),
                        filled: true,
                        fillColor:
                            Colors.white.withValues(alpha: 0.18),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: _buildBody(isDark),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading && _all.isEmpty) {
      return const NotiFlyLoadingScreen(
        message: 'Loading people...',
        isFullScreen: false,
      );
    }

    if (_error != null && _all.isEmpty) {
      return RefreshIndicator(
        color: AppColors.messengerBlue,
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: AppColors.subtleText),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.messengerBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return RefreshIndicator(
        color: AppColors.messengerBlue,
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Text(
                _searchCtrl.text.isEmpty
                    ? 'No users yet'
                    : 'No results for "${_searchCtrl.text}"',
                style: const TextStyle(color: AppColors.subtleText),
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.messengerBlue,
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 6),
        itemCount: _filtered.length,
        itemBuilder: (context, i) {
          final u      = _filtered[i];
          final name   = u['display_name'] as String? ??
                         u['email']        as String? ?? 'User';
          final email  = u['email']     as String? ?? '';
          final avatar = u['avatar_url'] as String?;

          return InkWell(
            onTap: () => _openChat(u),
            child: Container(
              color: isDark ? AppColors.darkBackground : Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _PersonAvatar(name: name, avatarUrl: avatar),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.subtleText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.messengerBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Message',
                      style: TextStyle(
                        color: AppColors.messengerBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar with seed colour
// ---------------------------------------------------------------------------

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({required this.name, this.avatarUrl});
  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFF1877F2), Color(0xFF6C5CE7), Color(0xFF00B894),
      Color(0xFFE17055), Color(0xFFFDAB4D), Color(0xFF74B9FF),
    ];
    final bg = name.isEmpty
        ? colors[0]
        : colors[name.codeUnitAt(0) % colors.length];

    return CircleAvatar(
      radius: 26,
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      backgroundColor: bg,
      child: avatarUrl == null
          ? Text(
              name[0].toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18,
              ),
            )
          : null,
    );
  }
}
