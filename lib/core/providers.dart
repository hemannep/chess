import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:chess_master/features/auth/data/auth_repository.dart';
import 'package:chess_master/features/game/data/repositories/firebase_game_repository.dart';
import 'package:chess_master/features/game/domain/chess_engine_service.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';
import 'package:chess_master/features/game/presentation/notifiers/game_notifier.dart';
import 'package:chess_master/features/matchmaking/data/matchmaking_repository.dart';
import 'package:chess_master/features/profile/data/profile_repository.dart';
import 'package:chess_master/services/sound_service.dart';
import 'package:chess_master/services/haptic_service.dart';
import 'package:chess_master/services/analytics_service.dart';

// ── Firebase ────────────────────────────────────────────────────────────────

final firebaseAuthProvider = Provider((_) => FirebaseAuth.instance);
final firestoreProvider = Provider((_) => FirebaseFirestore.instance);
final rtdbProvider = Provider((_) => FirebaseDatabase.instance);
final functionsProvider =
    Provider((_) => FirebaseFunctions.instanceFor(region: 'us-central1'));

// ── Services ────────────────────────────────────────────────────────────────

final soundServiceProvider = Provider((_) => SoundService());
final hapticServiceProvider = Provider((_) => HapticService());
final analyticsServiceProvider = Provider((_) => AnalyticsService());
final chessEngineProvider = Provider((_) => ChessEngineService());

// ── Repositories ────────────────────────────────────────────────────────────

final authRepositoryProvider = Provider((ref) => AuthRepository(
      auth: ref.watch(firebaseAuthProvider),
      db: ref.watch(firestoreProvider),
      analytics: ref.watch(analyticsServiceProvider),
    ));

final gameRepositoryProvider = Provider((ref) => FirebaseGameRepository(
      firestore: ref.watch(firestoreProvider),
      rtdb: ref.watch(rtdbProvider),
      engine: ref.watch(chessEngineProvider),
    ));

final matchmakingRepositoryProvider =
    Provider((ref) => MatchmakingRepository(
          rtdb: ref.watch(rtdbProvider),
          firestore: ref.watch(firestoreProvider),
          functions: ref.watch(functionsProvider),
        ));

final profileRepositoryProvider = Provider((ref) => ProfileRepository(
      firestore: ref.watch(firestoreProvider),
      auth: ref.watch(firebaseAuthProvider),
    ));

// ── Auth State ──────────────────────────────────────────────────────────────

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final currentUserProvider = StreamProvider<UserEntity?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(profileRepositoryProvider).watchUser(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// ── Game Notifier ───────────────────────────────────────────────────────────

final gameNotifierProvider =
    StateNotifierProvider.family<GameNotifier, GameState, String>(
  (ref, gameId) {
    final authUser = ref.watch(authStateProvider).valueOrNull;
    return GameNotifier(
      repo: ref.watch(gameRepositoryProvider),
      engine: ref.watch(chessEngineProvider),
      sound: ref.watch(soundServiceProvider),
      haptic: ref.watch(hapticServiceProvider),
      analytics: ref.watch(analyticsServiceProvider),
      functions: ref.watch(functionsProvider),
      gameId: gameId,
      myUid: authUser?.uid,
    );
  },
);

// ── Matchmaking Notifier ────────────────────────────────────────────────────

final matchmakingNotifierProvider =
    StateNotifierProvider.autoDispose<MatchmakingNotifier, MatchmakingState>(
  (ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    return MatchmakingNotifier(
      repo: ref.watch(matchmakingRepositoryProvider),
      uid: user?.uid ?? '',
      rating: user?.rating ?? 1200,
    );
  },
);

// ── Game History ────────────────────────────────────────────────────────────

final gameHistoryProvider =
    StreamProvider.family<List<GameEntity>, String>(
  (ref, uid) => ref.watch(gameRepositoryProvider).watchUserHistory(uid),
);

// ── Settings ────────────────────────────────────────────────────────────────

final settingsProvider = StateProvider<UserSettings>((ref) {
  return ref.watch(currentUserProvider).valueOrNull?.settings ??
      const UserSettings();
});
