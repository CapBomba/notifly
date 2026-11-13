import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/database/app_database.dart';
import 'core/fcm/fcm_service.dart';
import 'core/notifications/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/preferences/presentation/pages/preferences_page.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase — guarded for web (no web config set up)
  bool firebaseReady = false;
  try {
    if (!kIsWeb) {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler);
      firebaseReady = true;
    }
  } catch (_) {}

  // 2. Supabase
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  // 3. Local notification channels
  await NotificationService.instance.init();

  // 4. FCM token registration + foreground handler (Android only)
  if (firebaseReady) {
    await FcmService.instance.init();
  }

  // 5. Drift database
  AppDatabase.instance;

  runApp(const ProviderScope(child: NotiFlyApp()));
}

class NotiFlyApp extends ConsumerWidget {
  const NotiFlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routerDelegate = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'NotiFly',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerDelegate: routerDelegate,
      routeInformationParser: const AppRouteInformationParser(),
      debugShowCheckedModeBanner: false,
    );
  }
}
