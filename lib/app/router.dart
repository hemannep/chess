import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_master/core/providers.dart';

// Auth
import 'package:chess_master/features/auth/presentation/screens/splash_screen.dart';
import 'package:chess_master/features/auth/presentation/screens/login_screen.dart';

// Home
import 'package:chess_master/features/home/presentation/screens/home_screen.dart';

// Matchmaking / Setup
import 'package:chess_master/features/matchmaking/presentation/screens/play_options_screen.dart';
import 'package:chess_master/features/matchmaking/presentation/screens/bot_setup_screen.dart';
import 'package:chess_master/features/matchmaking/presentation/screens/local_setup_screen.dart';
import 'package:chess_master/features/matchmaking/presentation/screens/room_screen.dart';
import 'package:chess_master/features/matchmaking/presentation/screens/random_matchmaking_screen.dart';

// Profile / Settings / History
import 'package:chess_master/features/profile/presentation/screens/profile_screen.dart';
import 'package:chess_master/features/settings/presentation/screens/settings_screen.dart';
import 'package:chess_master/features/history/presentation/screens/game_history_screen.dart';

// Puzzle / Achievements
import 'package:chess_master/features/puzzle/presentation/screens/puzzle_screen.dart';
import 'package:chess_master/features/achievements/presentation/screens/achievements_screen.dart';

// Game
import 'package:chess_master/features/game/presentation/screens/game_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final loc = state.matchedLocation;
      final isOnAuth = loc.startsWith('/auth');
      final isOnSplash = loc == '/splash';

      if (isOnSplash) return null;
      if (!isLoggedIn && !isOnAuth) return '/auth/login';
      if (isLoggedIn && isOnAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),

      // Bottom nav shell
      ShellRoute(
        builder: (_, __, child) => _MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/play', builder: (_, __) => const PlayOptionsScreen()),
          GoRoute(path: '/puzzle', builder: (_, __) => const PuzzleScreen()),
          GoRoute(
              path: '/history', builder: (_, __) => const GameHistoryScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),

      // Full-screen routes
      GoRoute(
        path: '/game/:gameId',
        builder: (_, state) => GameScreen(
          gameId: state.pathParameters['gameId']!,
          myUid: state.uri.queryParameters['uid']?.isNotEmpty == true
              ? state.uri.queryParameters['uid']
              : null,
        ),
      ),
      GoRoute(
          path: '/matchmaking/random',
          builder: (_, __) => const RandomMatchmakingScreen()),
      GoRoute(
          path: '/matchmaking/room',
          builder: (_, __) => const RoomScreen()),
      GoRoute(
          path: '/matchmaking/join',
          builder: (_, __) => const JoinRoomScreen()),
      GoRoute(path: '/setup/bot', builder: (_, __) => const BotSetupScreen()),
      GoRoute(
          path: '/setup/local', builder: (_, __) => const LocalSetupScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
          path: '/achievements',
          builder: (_, __) => const AchievementsScreen()),
    ],
  );
});

class _MainShell extends StatelessWidget {
  final Widget child;
  const _MainShell({required this.child});

  static const _tabs = ['/home', '/play', '/puzzle', '/history', '/profile'];

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    int index = _tabs.indexWhere((t) => loc.startsWith(t));
    if (index < 0) index = 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.sports_esports_outlined),
              selectedIcon: Icon(Icons.sports_esports),
              label: 'Play'),
          NavigationDestination(
              icon: Icon(Icons.extension_outlined),
              selectedIcon: Icon(Icons.extension),
              label: 'Puzzle'),
          NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}
