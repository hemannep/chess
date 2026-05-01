import 'dart:async';
import 'package:chess/chess.dart' as ch_lib;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';
import 'package:chess_master/features/game/domain/chess_engine_service.dart';
import 'package:chess_master/features/game/data/repositories/firebase_game_repository.dart';
import 'package:chess_master/features/bot/bot_service.dart';
import 'package:chess_master/services/sound_service.dart';
import 'package:chess_master/services/haptic_service.dart';
import 'package:chess_master/services/analytics_service.dart';

enum GameScreenPhase { loading, active, paused, result, error }

class GameState {
  final GameEntity? game;
  final GameScreenPhase phase;
  final String? selectedSquare;
  final List<String> legalMoves;
  final bool isMyTurn;
  final bool isBotThinking;
  final bool opponentConnected;
  final String? errorMessage;
  final String? pendingPromotion;

  const GameState({
    this.game,
    this.phase = GameScreenPhase.loading,
    this.selectedSquare,
    this.legalMoves = const [],
    this.isMyTurn = true,
    this.isBotThinking = false,
    this.opponentConnected = true,
    this.errorMessage,
    this.pendingPromotion,
  });

  GameState copyWith({
    GameEntity? game,
    GameScreenPhase? phase,
    String? selectedSquare,
    List<String>? legalMoves,
    bool? isMyTurn,
    bool? isBotThinking,
    bool? opponentConnected,
    String? errorMessage,
    String? pendingPromotion,
    bool clearSelectedSquare = false,
    bool clearPendingPromotion = false,
  }) =>
      GameState(
        game: game ?? this.game,
        phase: phase ?? this.phase,
        selectedSquare:
            clearSelectedSquare ? null : selectedSquare ?? this.selectedSquare,
        legalMoves:
            clearSelectedSquare ? const [] : legalMoves ?? this.legalMoves,
        isMyTurn: isMyTurn ?? this.isMyTurn,
        isBotThinking: isBotThinking ?? this.isBotThinking,
        opponentConnected: opponentConnected ?? this.opponentConnected,
        errorMessage: errorMessage ?? this.errorMessage,
        pendingPromotion: clearPendingPromotion
            ? null
            : pendingPromotion ?? this.pendingPromotion,
      );
}

class GameNotifier extends StateNotifier<GameState> {
  final FirebaseGameRepository _repo;
  final ChessEngineService _engine;
  final SoundService _sound;
  final HapticService _haptic;
  final AnalyticsService _analytics;
  final FirebaseFunctions _functions;

  final String gameId;
  final String? myUid;

  StreamSubscription<GameEntity?>? _gameSub;
  StreamSubscription<Map<String, dynamic>>? _liveSub;
  BotService? _bot;
  Timer? _abandonTimer;

  GameNotifier({
    required FirebaseGameRepository repo,
    required ChessEngineService engine,
    required SoundService sound,
    required HapticService haptic,
    required AnalyticsService analytics,
    required FirebaseFunctions functions,
    required this.gameId,
    this.myUid,
  })  : _repo = repo,
        _engine = engine,
        _sound = sound,
        _haptic = haptic,
        _analytics = analytics,
        _functions = functions,
        super(const GameState());

  Future<void> init() async {
    state = state.copyWith(phase: GameScreenPhase.loading);

    _gameSub = _repo.watchGame(gameId).listen((game) async {
      if (game == null) {
        state = state.copyWith(
            phase: GameScreenPhase.error, errorMessage: 'Game not found');
        return;
      }

      final wasOngoing = state.game?.isOngoing ?? false;
      final isNowOver = !game.isOngoing;

      state = state.copyWith(
        game: game,
        phase: isNowOver ? GameScreenPhase.result : GameScreenPhase.active,
        isMyTurn: _isMyTurn(game),
        clearSelectedSquare: true,
      );

      if (!wasOngoing && isNowOver) {
        _onGameOver(game);
      }

      if (game.mode == GameMode.bot && _isOpponentTurn(game) && game.isOngoing) {
        await _scheduleBotMove(game);
      }

      if (game.mode == GameMode.online && myUid != null) {
        await _repo.setPresence(myUid!, gameId);
      }
    });

    _liveSub = _repo.watchLiveState(gameId).listen(_onLiveStateUpdate);
  }

  void onSquareTapped(String square) {
    final game = state.game;
    if (game == null || state.phase != GameScreenPhase.active) return;
    if (!_canInteract(game)) return;

    if (state.selectedSquare != null && state.legalMoves.contains(square)) {
      _tryMove(state.selectedSquare!, square);
      return;
    }

    final legal = _engine.getLegalMovesForSquare(game.fen, square);
    if (legal.isNotEmpty) {
      state = state.copyWith(selectedSquare: square, legalMoves: legal);
      _haptic.selection();
    } else {
      state = state.copyWith(clearSelectedSquare: true);
    }
  }

  void _tryMove(String from, String to) {
    final game = state.game;
    if (game == null) return;

    if (_needsPromotion(game.fen, from, to)) {
      state = state.copyWith(pendingPromotion: to);
      return;
    }
    _submitMove(from, to);
  }

  void onPromotionSelected(String piece) {
    final from = state.selectedSquare;
    final to = state.pendingPromotion;
    if (from == null || to == null) return;
    _submitMove(from, to, promotion: piece);
    state = state.copyWith(
        clearPendingPromotion: true, clearSelectedSquare: true);
  }

  Future<void> _submitMove(String from, String to, {String? promotion}) async {
    final game = state.game;
    if (game == null) return;

    final newFen = _engine.applyMove(game.fen, from, to, promotion: promotion);
    if (newFen == null) {
      state = state.copyWith(clearSelectedSquare: true);
      return;
    }

    _playMoveSound(game.fen, to);
    _haptic.impact();
    state = state.copyWith(clearSelectedSquare: true);

    if (game.mode == GameMode.local || game.mode == GameMode.bot) {
      await _repo.applyLocalMove(
        gameId: gameId,
        game: game,
        from: from,
        to: to,
        promotion: promotion,
      );
    } else {
      try {
        await _functions.httpsCallable('submitMove').call({
          'gameId': gameId,
          'from': from,
          'to': to,
          'promotion': promotion,
          'clientTimestamp': DateTime.now().millisecondsSinceEpoch,
        });
      } on FirebaseFunctionsException catch (e) {
        await _analytics.logError('move_rejected', e.message ?? 'unknown');
      }
    }
  }

  Future<void> _scheduleBotMove(GameEntity game) async {
    if (state.isBotThinking) return;
    state = state.copyWith(isBotThinking: true);

    _bot ??= BotServiceFactory.create(game.botDifficulty ?? BotDifficulty.medium);

    final delay = BotThinkDelay.forDifficulty(
        game.botDifficulty ?? BotDifficulty.medium);
    await Future.delayed(delay);

    try {
      final move = await _bot!
          .bestMove(game.fen, game.botDifficulty ?? BotDifficulty.medium);
      state = state.copyWith(isBotThinking: false);
      await _submitMove(move.from, move.to, promotion: move.promotion);
    } catch (_) {
      state = state.copyWith(isBotThinking: false);
    }
  }

  Future<void> offerDraw() async {
    if (myUid == null) return;
    await _repo.offerDraw(gameId, myUid!);
  }

  Future<void> acceptDraw() async {
    final game = state.game;
    if (game == null) return;
    if (game.mode == GameMode.online) {
      await _functions.httpsCallable('resolveGame').call({
        'gameId': gameId,
        'action': 'acceptDraw',
      });
    } else {
      await _repo.finalizeLocalGame(
        gameId: gameId,
        result: GameResult.draw,
        reason: ResultReason.agreement,
      );
    }
  }

  Future<void> declineDraw() async {
    await _repo.cancelDrawOffer(gameId);
  }

  Future<void> resign() async {
    final game = state.game;
    if (game == null) return;

    if (game.mode == GameMode.local || game.mode == GameMode.bot) {
      final result = game.currentTurn == PlayerColor.white
          ? GameResult.blackWins
          : GameResult.whiteWins;
      await _repo.finalizeLocalGame(
        gameId: gameId,
        result: result,
        reason: ResultReason.resign,
      );
    } else {
      await _functions.httpsCallable('resolveGame').call({
        'gameId': gameId,
        'action': 'resign',
      });
    }
  }

  Future<void> requestRematch() async {
    await _functions
        .httpsCallable('requestRematch')
        .call({'gameId': gameId});
  }

  Future<void> sendEmoji(String emoji) async {
    if (myUid == null) return;
    await _repo.sendEmoji(gameId, myUid!, emoji);
  }

  Future<BotMove?> requestHint() async {
    final game = state.game;
    if (game == null || game.mode != GameMode.bot) return null;
    final bot = MinimaxBotService(depth: 3, randomFactor: 0.0);
    final move = await bot.bestMove(game.fen, BotDifficulty.medium);
    bot.dispose();
    return move;
  }

  void _onLiveStateUpdate(Map<String, dynamic> live) {
    final game = state.game;
    if (game == null) return;

    final whiteTimerData = live['whiteTimer'];
    final blackTimerData = live['blackTimer'];
    if (whiteTimerData is Map && blackTimerData is Map) {
      final updatedGame = game.copyWith(
        whiteTimer: TimerState.fromMap(
            Map<String, dynamic>.from(whiteTimerData)),
        blackTimer: TimerState.fromMap(
            Map<String, dynamic>.from(blackTimerData)),
        drawOfferBy: live['drawOffer'] as String?,
      );
      state = state.copyWith(game: updatedGame);
    }
  }

  void _onGameOver(GameEntity game) {
    _sound.playGameOver();
    _haptic.heavyImpact();
    _analytics.logGameCompleted(gameId, game.result.name);
    _bot?.dispose();
    _bot = null;
  }

  bool _canInteract(GameEntity game) {
    if (state.isBotThinking) return false;
    if (game.mode == GameMode.online && !state.isMyTurn) return false;
    if (game.mode == GameMode.online && !state.opponentConnected) return false;
    return true;
  }

  bool _isMyTurn(GameEntity game) {
    if (game.mode == GameMode.local) return true;
    if (game.mode == GameMode.bot) {
      final playerIsWhite = game.white?.uid == myUid;
      return (playerIsWhite && game.currentTurn == PlayerColor.white) ||
          (!playerIsWhite && game.currentTurn == PlayerColor.black);
    }
    return game.currentTurnUid == myUid;
  }

  bool _isOpponentTurn(GameEntity game) {
    if (game.mode != GameMode.bot) return false;
    return !_isMyTurn(game);
  }

  bool _needsPromotion(String fen, String from, String to) {
    try {
      final game = ch_lib.Chess.fromFEN(fen);
      final piece = game.get(from);
      if (piece == null || piece.type != ch_lib.PieceType.PAWN) return false;
      final toRank = int.tryParse(to.length >= 2 ? to[1] : '') ?? 0;
      return toRank == 8 || toRank == 1;
    } catch (_) {
      return false;
    }
  }

  void _playMoveSound(String fen, String toSquare) {
    try {
      final game = ch_lib.Chess.fromFEN(fen);
      final target = game.get(toSquare);
      if (target != null) {
        _sound.playCapture();
      } else {
        _sound.playMove();
      }
    } catch (_) {
      _sound.playMove();
    }
  }

  @override
  void dispose() {
    _gameSub?.cancel();
    _liveSub?.cancel();
    _abandonTimer?.cancel();
    _bot?.dispose();
    if (myUid != null) _repo.removePresence(myUid!);
    super.dispose();
  }
}
