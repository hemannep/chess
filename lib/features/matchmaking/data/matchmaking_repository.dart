import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';

enum MatchmakingStatus { idle, searching, matched, cancelled, error }

class MatchmakingState {
  final MatchmakingStatus status;
  final String? gameId;
  final String? roomCode;
  final String? errorMessage;
  final Duration elapsed;

  const MatchmakingState({
    this.status = MatchmakingStatus.idle,
    this.gameId,
    this.roomCode,
    this.errorMessage,
    this.elapsed = Duration.zero,
  });

  MatchmakingState copyWith({
    MatchmakingStatus? status,
    String? gameId,
    String? roomCode,
    String? errorMessage,
    Duration? elapsed,
  }) =>
      MatchmakingState(
        status: status ?? this.status,
        gameId: gameId ?? this.gameId,
        roomCode: roomCode ?? this.roomCode,
        errorMessage: errorMessage ?? this.errorMessage,
        elapsed: elapsed ?? this.elapsed,
      );
}

class MatchmakingRepository {
  final FirebaseDatabase _rtdb;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  MatchmakingRepository({
    FirebaseDatabase? rtdb,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _rtdb = rtdb ?? FirebaseDatabase.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  DatabaseReference _matchStatusRef(String uid) =>
      _rtdb.ref('matchStatus/$uid');

  Stream<MatchmakingState> joinRandomQueue({
    required String uid,
    required int rating,
    required TimeControl timeControl,
  }) async* {
    yield const MatchmakingState(status: MatchmakingStatus.searching);

    try {
      await _functions.httpsCallable('joinMatchmaking').call({
        'timeControl': timeControl.toMap(),
        'rating': rating,
      });

      final matchRef = _matchStatusRef(uid);
      await matchRef.onDisconnect().remove();

      await for (final event in matchRef.onValue) {
        final data = event.snapshot.value;
        if (data is! Map) continue;

        final status = data['status'] as String?;
        if (status == 'matched') {
          final gameId = data['gameId'] as String?;
          yield MatchmakingState(
              status: MatchmakingStatus.matched, gameId: gameId);
          await matchRef.remove();
          return;
        } else if (status == 'cancelled') {
          yield const MatchmakingState(status: MatchmakingStatus.cancelled);
          return;
        }
      }
    } on FirebaseFunctionsException catch (e) {
      yield MatchmakingState(
          status: MatchmakingStatus.error, errorMessage: e.message);
    }
  }

  Future<void> cancelRandomQueue(String uid) async {
    try {
      await _functions.httpsCallable('cancelMatchmaking').call({});
      await _matchStatusRef(uid).remove();
    } catch (_) {}
  }

  Future<String> createRoom({required TimeControl timeControl}) async {
    final result = await _functions
        .httpsCallable('createRoom')
        .call({'timeControl': timeControl.toMap()});
    return result.data['code'] as String;
  }

  Future<String> joinRoom(String code) async {
    final result = await _functions
        .httpsCallable('joinRoom')
        .call({'code': code.toUpperCase()});
    return result.data['gameId'] as String;
  }

  Stream<String?> watchRoomForGameId(String code) {
    return _firestore
        .collection('rooms')
        .doc(code)
        .snapshots()
        .map((snap) => snap.data()?['gameId'] as String?);
  }

  static String generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}

class MatchmakingNotifier extends StateNotifier<MatchmakingState> {
  final MatchmakingRepository _repo;
  final String uid;
  final int rating;

  StreamSubscription<MatchmakingState>? _searchSub;
  Timer? _elapsedTimer;

  MatchmakingNotifier({
    required MatchmakingRepository repo,
    required this.uid,
    required this.rating,
  })  : _repo = repo,
        super(const MatchmakingState());

  Future<void> startRandomSearch(TimeControl timeControl) async {
    state = const MatchmakingState(status: MatchmakingStatus.searching);

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(
          elapsed: state.elapsed + const Duration(seconds: 1));
    });

    _searchSub = _repo
        .joinRandomQueue(uid: uid, rating: rating, timeControl: timeControl)
        .listen((matchState) {
      state = matchState;
      if (matchState.status == MatchmakingStatus.matched ||
          matchState.status == MatchmakingStatus.error) {
        _cleanup();
      }
    });
  }

  Future<void> cancelSearch() async {
    await _repo.cancelRandomQueue(uid);
    _cleanup();
    state = const MatchmakingState(status: MatchmakingStatus.cancelled);
  }

  Future<({String code, Stream<String?> gameIdStream})> createRoom(
      TimeControl timeControl) async {
    final code = await _repo.createRoom(timeControl: timeControl);
    final stream = _repo.watchRoomForGameId(code);
    return (code: code, gameIdStream: stream);
  }

  Future<String> joinRoom(String code) => _repo.joinRoom(code);

  void _cleanup() {
    _elapsedTimer?.cancel();
    _searchSub?.cancel();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
