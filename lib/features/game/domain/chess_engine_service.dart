import 'package:chess/chess.dart' as ch;
import 'package:chess_master/features/game/domain/entities/game_entity.dart';

/// Wraps chess.dart. Stateless — pass FEN in, get results out.
class ChessEngineService {
  static const String startingFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  bool isMoveLegal(String fen, String from, String to, {String? promotion}) {
    final game = ch.Chess.fromFEN(fen);
    final moves = game.generate_moves();
    return moves.any((m) {
      if (m.fromAlgebraic != from || m.toAlgebraic != to) return false;
      if (promotion != null && m.promotion != null) {
        return m.promotion.toString().toLowerCase() == promotion.toLowerCase();
      }
      return true;
    });
  }

  String? applyMove(String fen, String from, String to, {String? promotion}) {
    final game = ch.Chess.fromFEN(fen);
    final moveMap = <String, String>{'from': from, 'to': to};
    if (promotion != null) moveMap['promotion'] = promotion;
    final result = game.move(moveMap);
    if (!result) return null;
    return game.fen;
  }

  List<String> getLegalMovesForSquare(String fen, String square) {
    final game = ch.Chess.fromFEN(fen);
    return game
        .generate_moves()
        .where((m) => m.fromAlgebraic == square)
        .map((m) => m.toAlgebraic)
        .toSet()
        .toList();
  }

  bool isCheck(String fen) => ch.Chess.fromFEN(fen).in_check;
  bool isCheckmate(String fen) => ch.Chess.fromFEN(fen).in_checkmate;
  bool isStalemate(String fen) => ch.Chess.fromFEN(fen).in_stalemate;
  bool isDraw(String fen) => ch.Chess.fromFEN(fen).in_draw;
  bool isGameOver(String fen) => ch.Chess.fromFEN(fen).game_over;

  ResultReason? getAutoResultReason(String fen) {
    final g = ch.Chess.fromFEN(fen);
    if (g.in_checkmate) return ResultReason.checkmate;
    if (g.in_stalemate) return ResultReason.stalemate;
    if (g.insufficient_material) return ResultReason.insufficientMaterial;
    if (g.in_threefold_repetition) return ResultReason.repetition;
    final parts = fen.split(' ');
    final halfmove = parts.length > 4 ? (int.tryParse(parts[4]) ?? 0) : 0;
    if (halfmove >= 100) return ResultReason.fiftyMoveRule;
    return null;
  }

  GameResult? getAutoResult(String fen) {
    final g = ch.Chess.fromFEN(fen);
    if (g.in_checkmate) {
      final parts = fen.split(' ');
      final turn = parts.length > 1 ? parts[1] : 'w';
      return turn == 'w' ? GameResult.blackWins : GameResult.whiteWins;
    }
    if (g.in_draw) return GameResult.draw;
    return null;
  }

  /// Computes SAN after applying the move. Returns simple coord notation
  /// if something goes wrong.
  Object getMovesan(String fen, String from, String to, {String? promotion}) {
    try {
      final game = ch.Chess.fromFEN(fen);
      final moveMap = <String, String>{'from': from, 'to': to};
      if (promotion != null) moveMap['promotion'] = promotion;
      if (!game.move(moveMap)) return '$from$to';
      final history = game.history;
      if (history.isEmpty) return '$from$to';
      final last = history.last;
      return last is String ? last : last.toString();
    } catch (_) {
      return '$from$to';
    }
  }

  String buildPgn({
    required PlayerInfo? white,
    required PlayerInfo? black,
    required List<MoveRecord> moves,
    required GameResult result,
    String? event,
    DateTime? date,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('[Event "${event ?? 'Chess Master Game'}"]');
    buffer.writeln('[Site "Chess Master App"]');
    buffer.writeln('[Date "${_formatPgnDate(date ?? DateTime.now())}"]');
    buffer.writeln('[White "${white?.username ?? 'Player 1'}"]');
    buffer.writeln('[Black "${black?.username ?? 'Player 2'}"]');
    buffer.writeln('[WhiteElo "${white?.rating ?? '?'}"]');
    buffer.writeln('[BlackElo "${black?.rating ?? '?'}"]');
    buffer.writeln('[Result "${_resultToPgn(result)}"]');
    buffer.writeln();

    for (int i = 0; i < moves.length; i++) {
      if (i % 2 == 0) buffer.write('${(i ~/ 2) + 1}. ');
      buffer.write('${moves[i].san} ');
    }
    buffer.write(_resultToPgn(result));
    return buffer.toString();
  }

  String _formatPgnDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  String _resultToPgn(GameResult r) => switch (r) {
        GameResult.whiteWins => '1-0',
        GameResult.blackWins => '0-1',
        GameResult.draw => '1/2-1/2',
        GameResult.ongoing => '*',
      };
}
