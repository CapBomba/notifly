import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/presentation/pages/conversations_page.dart';
import '../../features/chat/presentation/pages/new_conversation_page.dart';
import '../../features/preferences/presentation/pages/preferences_page.dart';
import '../theme/app_theme.dart';
import '../widgets/notifly_loading_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const String login       = '/login';
  static const String home        = '/home';
  static const String preferences = '/preferences';
}

final appRouterProvider = Provider<AppRouterDelegate>((ref) {
  final authAsync = ref.watch(authStateProvider);
  return AppRouterDelegate(authAsync: authAsync);
});

class AppRouterDelegate extends RouterDelegate<String>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  AppRouterDelegate({required this.authAsync});

  final AsyncValue authAsync;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  String? get currentConfiguration => AppRoutes.home;

  @override
  Widget build(BuildContext context) {
    return authAsync.when(
      loading: () {
        final client = Supabase.instance.client;
        if (client.auth.currentSession != null) {
          return Navigator(
            key: navigatorKey,
            pages: const [
              MaterialPage<void>(key: ValueKey('home'), child: HomeShell()),
            ],
            onDidRemovePage: (_) {},
          );
        }
        return const NotiFlyLoadingScreen(message: 'Starting NotiFly...');
      },
      error: (e, __) {
        final client = Supabase.instance.client;
        if (client.auth.currentSession != null) {
          return Navigator(
            key: navigatorKey,
            pages: const [
              MaterialPage<void>(key: ValueKey('home'), child: HomeShell()),
            ],
            onDidRemovePage: (_) {},
          );
        }
        final errStr = e.toString().toLowerCase();
        final isNetworkError = errStr.contains('socketexception') ||
            errStr.contains('failed host lookup') ||
            errStr.contains('no address associated');

        if (isNetworkError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No Internet Connection',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Please check your Wi-Fi or Mobile Data connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Consumer(
                    builder: (context, ref, _) => ElevatedButton.icon(
                      onPressed: () {
                        ref.invalidate(authStateProvider);
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry Connection'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.messengerBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Navigator(
          key: navigatorKey,
          pages: const [
            MaterialPage<void>(key: ValueKey('login'), child: LoginPage()),
          ],
          onDidRemovePage: (_) {},
        );
      },
      data: (session) {
        final isLoggedIn = session != null;
        return Navigator(
          key: navigatorKey,
          pages: [
            if (!isLoggedIn)
              const MaterialPage<void>(key: ValueKey('login'), child: LoginPage())
            else
              const MaterialPage<void>(key: ValueKey('home'), child: HomeShell()),
          ],
          onDidRemovePage: (_) {},
        );
      },
    );
  }

  @override
  Future<void> setNewRoutePath(String configuration) async {}
}

class AppRouteInformationParser extends RouteInformationParser<String> {
  const AppRouteInformationParser();
  @override
  Future<String> parseRouteInformation(RouteInformation routeInformation) async =>
      routeInformation.uri.path;
  @override
  RouteInformation restoreRouteInformation(String configuration) =>
      RouteInformation(uri: Uri.parse(configuration));
}

// ---------------------------------------------------------------------------
// Home shell — 3 tabs: Chats | People | Settings
// ---------------------------------------------------------------------------

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = <Widget>[
    ConversationsPage(),
    NewConversationPage(),
    PreferencesPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Chats',
                selected: index == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.people_outline_rounded,
                activeIcon: Icons.people_rounded,
                label: 'People',
                selected: index == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings_rounded,
                label: 'Settings',
                selected: index == 2,
                onTap: () => onTap(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = selected
        ? AppColors.messengerBlue
        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.messengerBlue.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
