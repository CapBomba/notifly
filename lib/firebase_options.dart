// THIS FILE IS GENERATED — DO NOT EDIT MANUALLY.
//
// Run the following command to regenerate after adding Firebase to your project:
//
//   flutterfire configure
//
// Prerequisites:
//   dart pub global activate flutterfire_cli
//   # Log in to Firebase CLI first: firebase login

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.\n'
          'Run: flutterfire configure',
        );
    }
  }

  // -------------------------------------------------------------------------
  // TODO: Replace these placeholder values by running:
  //   flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
  //
  // The real google-services.json must also be placed at:
  //   android/app/google-services.json
  // -------------------------------------------------------------------------

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB4E8YOn_T0Q7TBI_M-iM4ITa31UZ4kF4w',
    appId: '1:503008906051:android:f177e5d4417c1c0fd37df6',
    messagingSenderId: '503008906051',
    projectId: 'notifly-deipa-2026',
    storageBucket: 'notifly-deipa-2026.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_REAL_VALUE',
    appId: 'REPLACE_WITH_REAL_VALUE',
    messagingSenderId: 'REPLACE_WITH_REAL_VALUE',
    projectId: 'REPLACE_WITH_REAL_VALUE',
    storageBucket: 'REPLACE_WITH_REAL_VALUE',
    iosClientId: 'REPLACE_WITH_REAL_VALUE',
    iosBundleId: 'com.example.notifly',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_REAL_VALUE',
    appId: 'REPLACE_WITH_REAL_VALUE',
    messagingSenderId: 'REPLACE_WITH_REAL_VALUE',
    projectId: 'REPLACE_WITH_REAL_VALUE',
    storageBucket: 'REPLACE_WITH_REAL_VALUE',
  );
}
