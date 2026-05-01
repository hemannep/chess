import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';
import 'package:chess_master/features/game/domain/chess_engine_service.dart';

class FirebaseGameRepository {
  final FirebaseFirestore _firestore;
  final FirebaseDatabase _rtdb;
  final ChessEngineService _engine;

  FirebaseGameRepository({
    FirebaseFirestore? firestore,
    FirebaseDatabase? rtdb,
    ChessEngineService? engine,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _rtdb = rtdb ?? FirebaseDatabase.instance,
        _engine = engine ?? ChessEngineService();

  CollectionReference<Map<String, dynamic>> get _games =>
      _firestore.collection('games');

  DocumentReference<Map<String, dynamic>> _gameDoc(String id) => _games.doc(id);

  CollectionReference<Map<String, dynamic>> _movesColl(String id) =>
      _gameDoc(id).collection('moves');

  DatabaseReference _liveRef(String gameId) => _rtdb.ref('games/$gameId/live');
  DatabaseReference _presenceRef(String uid) => _rtdb.ref('presence/$uid');

  // ── Watch ─────────────────────────────────────────────────────────────────

  Stream<GameEntity?> watchGame(String gameId) {
    return _gameDoc(gameId).snapshots().asyncMap((snap) async {
      if (!snap.exists) return null;
      final data = snap.data()!;
      final movesSnap = await _movesColl(gameId).orderBy('moveNumber').get();
      final moves =
          movesSnap.docs.map((d) => MoveRecord.fromMap(d.data())).toList();
      return _gameFromFirestore(data, moves);
    });
  }

  Stream<Map<String, dynamic>> watchLiveState(String gameId) {
    return _liveRef(gameId).onValue.map((event) {
      final v = event.snapshot.value;
      if (v is Map) return v.cast<String, dynamic>();
      return <String, dynamic>{};
    });
  }

  // ── Create games ──────────────────────────────────────────────────────────

  Future<String> createLocalGame({required TimeControl timeControl}) async {
    final ref = _games.doc();
    final now = DateTime.now().millisecondsSinceEpoch;
    final timerMs = timeControl.initialSeconds * 1000;
    await ref.set({
      'id': ref.id,
      'mode': 'local',
      'status': 'in_progress',
      'result': 'ongoing',
      'playerUids': ['local_white', 'local_black'],
      'timeControl': timeControl.toMap(),
      'whiteTimer':
          TimerState(remainingMs: timerMs, running: true, lastStartedAt: now)
              .toMap(),
      'blackTimer': TimerState(remainingMs: timerMs, running: false).toMap(),
      'fen': ChessEngineService.startingFen,
      'moveCount': 0,
      'createdAt': now,
      'startedAt': now,
    });
    return ref.id;
  }

  Future<String> createBotGame({
    required String playerUid,
    required PlayerColor playerColor,
    required TimeControl timeControl,
    required BotDifficulty difficulty,
    required PlayerInfo playerInfo,
  }) async {
    final ref = _games.doc();
    final now = DateTime.now().millisecondsSinceEpoch;
    final timerMs = timeControl.initialSeconds * 1000;
    const bot = PlayerInfo(uid: 'bot', username: 'Chess Bot', rating: 1500);
    final white = playerColor == PlayerColor.white ? playerInfo : bot;
    final black = playerColor == PlayerColor.black ? playerInfo : bot;
    await ref.set({
      'id': ref.id,
      'mode': 'bot',
      'status': 'in_progress',
      'result': 'ongoing',
      'playerUids': [playerUid, 'bot'],
      'white': white.toMap(),
      'black': black.toMap(),
      'timeControl': timeControl.toMap(),
      'whiteTimer':
          TimerState(remainingMs: timerMs, running: true, lastStartedAt: now)
              .toMap(),
      'blackTimer': TimerState(remainingMs: timerMs, running: false).toMap(),
      'fen': ChessEngineService.startingFen,
      'botDifficulty': difficulty.name,
      'moveCount': 0,
      'createdAt': now,
      'startedAt': now,
    });
    return ref.id;
  }

  // ── Apply local/bot move ──────────────────────────────────────────────────

  Future<void> applyLocalMove({
    required String gameId,
    required GameEntity game,
    required String from,
    required String to,
    String? promotion,
  }) async {
    final newFen = _engine.applyMove(game.fen, from, to, promotion: promotion);
    if (newFen == null) throw Exception('Illegal move: $from -> $to');

    final san = _engine.getMovesan(game.fen, from, to, promotion: promotion);
    final now = DateTime.now().millisecondsSinceEpoch;
    final moveNumber = game.moves.length + 1;

    final moverTimer = game.currentTurn == PlayerColor.white
        ? game.whiteTimer
        : game.blackTimer;
    final elapsed = moverTimer.lastStartedAt != null
        ? (now - moverTimer.lastStartedAt!)
        : 0;
    final newRemainingMs = (moverTimer.remainingMs -
            elapsed +
            game.timeControl.incrementSeconds * 1000)
        .clamp(0, 1 << 31);

    final newMoverTimer =
        TimerState(remainingMs: newRemainingMs, running: false);
    final opponentRemainingMs = game.currentTurn == PlayerColor.white
        ? game.blackTimer.remainingMs
        : game.whiteTimer.remainingMs;
    final newOpponentTimer = TimerState(
        remainingMs: opponentRemainingMs, running: true, lastStartedAt: now);

    final autoResult = _engine.getAutoResult(newFen);
    final resultReason = _engine.getAutoResultReason(newFen);
    final isOver = autoResult != null;

    final batch = _firestore.batch();
    final moveRef = _movesColl(gameId).doc();
    batch.set(
      moveRef,
      MoveRecord(
        moveNumber: moveNumber,
        from: from,
        to: to,
        san: san as String,
        fen: newFen,
        promotion: promotion,
        timestamp: now,
      ).toMap(),
    );

    final updates = <String, dynamic>{
      'fen': newFen,
      'moveCount': moveNumber,
      'whiteTimer': (game.currentTurn == PlayerColor.white
              ? newMoverTimer
              : newOpponentTimer)
          .toMap(),
      'blackTimer': (game.currentTurn == PlayerColor.black
              ? newMoverTimer
              : newOpponentTimer)
          .toMap(),
    };
    if (isOver) {
      updates['status'] = 'completed';
      updates['result'] = autoResult.toFirestore;
      updates['endedAt'] = now;
    }
    if (resultReason != null) {
      updates['resultReason'] = resultReason.toFirestore;
    }

    batch.update(_gameDoc(gameId), updates);
    await batch.commit();
  }

  // ── Local finalize (resign from local/bot mode) ───────────────────────────

  Future<void> finalizeLocalGame({
    required String gameId,
    required GameResult result,
    required ResultReason reason,
  }) async {
    await _gameDoc(gameId).update({
      'status': 'completed',
      'result': result.toFirestore,
      'resultReason': reason.toFirestore,
      'endedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ── Presence ──────────────────────────────────────────────────────────────

  Future<void> setPresence(String uid, String? gameId) async {
    final ref = _presenceRef(uid);
    await ref.set({
      'online': true,
      'gameId': gameId,
      'lastSeen': ServerValue.timestamp,
    });
    await ref.onDisconnect().update({
      'online': false,
      'lastSeen': ServerValue.timestamp,
    });
  }

  Future<void> removePresence(String uid) => _presenceRef(uid).remove();

  // ── Draw / Emoji ──────────────────────────────────────────────────────────

  Future<void> offerDraw(String gameId, String uid) =>
      _liveRef(gameId).update({'drawOffer': uid});

  Future<void> cancelDrawOffer(String gameId) =>
      _liveRef(gameId).update({'drawOffer': null});

  Future<void> sendEmoji(String gameId, String uid, String emoji) =>
      _liveRef(gameId).update({
        'emoji': {
          'uid': uid,
          'emoji': emoji,
          'ts': ServerValue.timestamp,
        },
      });

  // ── History ───────────────────────────────────────────────────────────────

  Stream<List<GameEntity>> watchUserHistory(String uid, {int limit = 20}) {
    return _games
        .where('playerUids', arrayContains: uid)
        .where('status', isEqualTo: 'completed')
        .orderBy('endedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => _gameFromFirestore(d.data(), [])).toList());
  }

  Future<GameEntity?> getGame(String gameId) async {
    final snap = await _gameDoc(gameId).get();
    if (!snap.exists) return null;
    final movesSnap = await _movesColl(gameId).orderBy('moveNumber').get();
    final moves =
        movesSnap.docs.map((d) => MoveRecord.fromMap(d.data())).toList();
    return _gameFromFirestore(snap.data()!, moves);
  }

  // ── Mapper ────────────────────────────────────────────────────────────────

  GameEntity _gameFromFirestore(
      Map<String, dynamic> data, List<MoveRecord> moves) {
    return GameEntity(
      id: data['id'] as String? ?? '',
      mode: GameMode.values.firstWhere(
        (m) => m.name == (data['mode'] as String? ?? 'local'),
        orElse: () => GameMode.local,
      ),
      status: GameStatusX.fromString(data['status'] as String?),
      result: GameResultX.fromString(data['result'] as String?),
      resultReason: ResultReasonX.fromString(data['resultReason'] as String?),
      white: data['white'] != null
          ? PlayerInfo.fromMap(Map<String, dynamic>.from(data['white'] as Map))
          : null,
      black: data['black'] != null
          ? PlayerInfo.fromMap(Map<String, dynamic>.from(data['black'] as Map))
          : null,
      playerUids: List<String>.from(data['playerUids'] as List? ?? []),
      timeControl: TimeControl.fromMap(
          Map<String, dynamic>.from(data['timeControl'] as Map? ?? {})),
      whiteTimer: TimerState.fromMap(
          Map<String, dynamic>.from(data['whiteTimer'] as Map? ?? {})),
      blackTimer: TimerState.fromMap(
          Map<String, dynamic>.from(data['blackTimer'] as Map? ?? {})),
      fen: data['fen'] as String? ?? ChessEngineService.startingFen,
      moves: moves,
      pgn: data['pgn'] as String?,
      botDifficulty: data['botDifficulty'] != null
          ? BotDifficulty.values.firstWhere(
              (d) => d.name == data['botDifficulty'],
              orElse: () => BotDifficulty.medium,
            )
          : null,
      roomCode: data['roomCode'] as String?,
      createdAt: data['createdAt'] as int? ?? 0,
      startedAt: data['startedAt'] as int?,
      endedAt: data['endedAt'] as int?,
    );
  }
}
