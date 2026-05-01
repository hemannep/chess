import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:chess_master/app/theme.dart';
import 'package:chess_master/app/router.dart';
import 'package:chess_master/core/providers.dart';
import 'package:chess_master/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase using options generated from google-services.json
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Catch Flutter framework errors and report to Crashlytics
  FlutterError.onError =
      FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Local storage
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('localGames');

  runApp(
    const ProviderScope(
      child: ChessMasterApp(),
    ),
  );
}

class ChessMasterApp extends ConsumerWidget {
  const ChessMasterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'Chess Master',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}
