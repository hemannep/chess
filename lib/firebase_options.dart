// Generated from google-services.json
// Project: chess-232e5  |  Package: com.manjojuice.chess
// To regenerate: flutterfire configure --project=chess-232e5

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web not configured. Run: flutterfire configure');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Platform ${defaultTargetPlatform.name} not configured.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDJsJxiMu3FCpLxxOHngieUpsRiaZv9cIA',
    appId: '1:794632400427:android:c95f5a21d304acd1d2446e',
    messagingSenderId: '794632400427',
    projectId: 'chess-232e5',
    storageBucket: 'chess-232e5.firebasestorage.app',
  );

  // NOTE: Add your iOS app to the Firebase console (bundle: com.manjojuice.chess)
  // then replace the values below by running: flutterfire configure
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_API_KEY',
    appId: 'REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: '794632400427',
    projectId: 'chess-232e5',
    storageBucket: 'chess-232e5.firebasestorage.app',
    iosBundleId: 'com.manjojuice.chess',
  );
}
