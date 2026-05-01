import 'dart:isolate';
import 'dart:math';
import 'package:chess/chess.dart' as ch;
import 'package:chess_master/features/game/domain/entities/game_entity.dart';

abstract class BotService {
  Future<BotMove> bestMove(String fen, BotDifficulty difficulty);
  void dispose();
}

class BotMove {
  final String from;
  final String to;
  final String? promotion;
  final int? evalCentipawns;

  const BotMove({
    required this.from,
    required this.to,
    this.promotion,
    this.evalCentipawns,
  });
}

class BotServiceFactory {
  static BotService create(BotDifficulty difficulty) {
    return switch (difficulty) {
      BotDifficulty.easy => MinimaxBotService(depth: 1, randomFactor: 0.35),
      BotDifficulty.medium => MinimaxBotService(depth: 3, randomFactor: 0.10),
      BotDifficulty.hard => MinimaxBotService(depth: 4, randomFactor: 0.0),
      BotDifficulty.expert => MinimaxBotService(depth: 5, randomFactor: 0.0),
    };
  }
}

class MinimaxBotService implements BotService {
  final int depth;
  final double randomFactor;

  MinimaxBotService({required this.depth, required this.randomFactor});

  @override
  Future<BotMove> bestMove(String fen, BotDifficulty difficulty) async {
    // Isolate.run handles lifecycle automatically — no manual kill needed.
    return await Isolate.run(() => _findBestMoveSync(fen, depth, randomFactor));
  }

  @override
  void dispose() {
    // Nothing to dispose — Isolate.run auto-cleans.
  }
}

// ─── Isolate-safe entry (top-level static logic) ────────────────────────────

BotMove _findBestMoveSync(String fen, int depth, double randomFactor) {
  final engine = _MinimaxEngine(randomFactor: randomFactor);
  return engine.findBestMove(fen, depth);
}

class _MinimaxEngine {
  final double randomFactor;
  final Random _rng = Random();

  _MinimaxEngine({required this.randomFactor});

  BotMove findBestMove(String fen, int depth) {
    final game = ch.Chess.fromFEN(fen);
    final isWhite = fen.split(' ')[1] == 'w';
    final moves = game.generate_moves();

    if (moves.isEmpty) return const BotMove(from: 'e2', to: 'e4');

    if (randomFactor > 0 && _rng.nextDouble() < randomFactor) {
      final m = moves[_rng.nextInt(moves.length)];
      return BotMove(
        from: m.fromAlgebraic,
        to: m.toAlgebraic,
        promotion: m.promotion?.toString().toLowerCase(),
      );
    }

    BotMove? best;
    int bestScore = isWhite ? -999999 : 999999;

    for (final move in moves) {
      final copy = ch.Chess.fromFEN(fen);
      copy.move({
        'from': move.fromAlgebraic,
        'to': move.toAlgebraic,
        'promotion': move.promotion?.toString(),
      });
      final score = _minimax(copy, depth - 1, -999999, 999999, !isWhite);
      if ((isWhite && score > bestScore) || (!isWhite && score < bestScore)) {
        bestScore = score;
        best = BotMove(
          from: move.fromAlgebraic,
          to: move.toAlgebraic,
          promotion: move.promotion?.toString().toLowerCase(),
          evalCentipawns: score,
        );
      }
    }

    return best ??
        BotMove(from: moves.first.fromAlgebraic, to: moves.first.toAlgebraic);
  }

  int _minimax(ch.Chess game, int depth, int alpha, int beta, bool maximizing) {
    if (depth == 0 || game.game_over) return _evaluate(game);

    final moves = game.generate_moves();
    if (maximizing) {
      int maxEval = -999999;
      for (final move in moves) {
        final copy = ch.Chess.fromFEN(game.fen);
        copy.move({
          'from': move.fromAlgebraic,
          'to': move.toAlgebraic,
          'promotion': move.promotion?.toString(),
        });
        final eval = _minimax(copy, depth - 1, alpha, beta, false);
        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) break;
      }
      return maxEval;
    } else {
      int minEval = 999999;
      for (final move in moves) {
        final copy = ch.Chess.fromFEN(game.fen);
        copy.move({
          'from': move.fromAlgebraic,
          'to': move.toAlgebraic,
          'promotion': move.promotion?.toString(),
        });
        final eval = _minimax(copy, depth - 1, alpha, beta, true);
        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) break;
      }
      return minEval;
    }
  }

  int _evaluate(ch.Chess game) {
    if (game.in_checkmate) {
      return game.turn == ch.Color.WHITE ? -99999 : 99999;
    }
    if (game.in_draw) return 0;

    int score = 0;
    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

    for (int f = 0; f < 8; f++) {
      for (int r = 0; r < 8; r++) {
        final sq = '${files[f]}${r + 1}';
        final piece = game.get(sq);
        if (piece == null) continue;
        final val = _pieceValue(piece.type) +
            _pstBonus(piece.type, piece.color, f, r);
        score += piece.color == ch.Color.WHITE ? val : -val;
      }
    }
    return score;
  }

  int _pieceValue(ch.PieceType type) => switch (type) {
        ch.PieceType.PAWN => 100,
        ch.PieceType.KNIGHT => 320,
        ch.PieceType.BISHOP => 330,
        ch.PieceType.ROOK => 500,
        ch.PieceType.QUEEN => 900,
        ch.PieceType.KING => 20000,
        _ => 0,
      };

  int _pstBonus(ch.PieceType type, ch.Color color, int file, int rank) {
    final r = color == ch.Color.WHITE ? rank : 7 - rank;
    final centerDist = ((file - 3.5).abs() + (r - 3.5).abs()).round();
    return switch (type) {
      ch.PieceType.PAWN => r * 5,
      ch.PieceType.KNIGHT => (4 - centerDist) * 15,
      ch.PieceType.BISHOP => (4 - centerDist) * 10,
      _ => 0,
    };
  }
}

class BotThinkDelay {
  static Duration forDifficulty(BotDifficulty difficulty) {
    final extra = Random().nextInt(600);
    return switch (difficulty) {
      BotDifficulty.easy => Duration(milliseconds: 400 + extra),
      BotDifficulty.medium => Duration(milliseconds: 700 + extra),
      BotDifficulty.hard => Duration(milliseconds: 1000 + extra),
      BotDifficulty.expert => Duration(milliseconds: 1400 + extra),
    };
  }
}
