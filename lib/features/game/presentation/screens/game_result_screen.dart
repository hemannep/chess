import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';
import 'package:chess_master/features/game/domain/chess_engine_service.dart';

class GameResultSheet extends StatelessWidget {
  final GameEntity game;
  final String? myUid;
  final VoidCallback onRematch;

  const GameResultSheet({
    super.key,
    required this.game,
    this.myUid,
    required this.onRematch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, subtitle, emoji) = _buildResultInfo();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(emoji, style: const TextStyle(fontSize: 56))
              .animate()
              .scale(
                  begin: const Offset(0.5, 0.5),
                  duration: 400.ms,
                  curve: Curves.elasticOut),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.displayMedium)
              .animate()
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.2),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodyMedium)
              .animate()
              .fadeIn(delay: 300.ms),
          const SizedBox(height: 20),
          if (game.mode == GameMode.online) ...[
            _PlayersRow(game: game),
            const SizedBox(height: 20),
          ],
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share PGN'),
                onPressed: _sharePgn,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Rematch'),
                onPressed: () {
                  Navigator.pop(context);
                  onRematch();
                },
              ),
            ),
          ]).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Home'),
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }

  (String title, String subtitle, String emoji) _buildResultInfo() {
    if (game.mode == GameMode.local) {
      return switch (game.result) {
        GameResult.whiteWins =>
          ('White Wins!', _reasonLabel(game.resultReason), '👑'),
        GameResult.blackWins =>
          ('Black Wins!', _reasonLabel(game.resultReason), '👑'),
        GameResult.draw => ('Draw', _reasonLabel(game.resultReason), '🤝'),
        GameResult.ongoing => ('Game Ended', '', '🏁'),
      };
    }
    final myColor =
        myUid == game.white?.uid ? PlayerColor.white : PlayerColor.black;
    final iWon = (game.result == GameResult.whiteWins &&
            myColor == PlayerColor.white) ||
        (game.result == GameResult.blackWins && myColor == PlayerColor.black);
    final isDraw = game.result == GameResult.draw;

    if (isDraw) return ('Draw', _reasonLabel(game.resultReason), '🤝');
    if (iWon) return ('You Won!', _reasonLabel(game.resultReason), '🏆');
    return ('You Lost', _reasonLabel(game.resultReason), '😔');
  }

  String _reasonLabel(ResultReason? reason) => switch (reason) {
        ResultReason.checkmate => 'by Checkmate',
        ResultReason.timeout => 'on Time',
        ResultReason.resign => 'by Resignation',
        ResultReason.agreement => 'by Agreement',
        ResultReason.stalemate => 'Stalemate',
        ResultReason.insufficientMaterial => 'Insufficient Material',
        ResultReason.fiftyMoveRule => '50-Move Rule',
        ResultReason.repetition => 'Threefold Repetition',
        ResultReason.abandoned => 'Opponent Abandoned',
        null => '',
      };

  void _sharePgn() {
    final engine = ChessEngineService();
    final pgn = engine.buildPgn(
      white: game.white,
      black: game.black,
      moves: game.moves,
      result: game.result,
      date: game.startedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(game.startedAt!)
          : null,
    );
    Share.share(pgn, subject: 'Chess game from Chess Master');
  }
}

class _PlayersRow extends StatelessWidget {
  final GameEntity game;
  const _PlayersRow({required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _PlayerRatingCard(
              player: game.white,
              result: game.result,
              side: PlayerColor.white),
          Text(_resultSymbol(),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          _PlayerRatingCard(
              player: game.black,
              result: game.result,
              side: PlayerColor.black),
        ],
      ),
    );
  }

  String _resultSymbol() => switch (game.result) {
        GameResult.whiteWins => '1 – 0',
        GameResult.blackWins => '0 – 1',
        GameResult.draw => '½ – ½',
        GameResult.ongoing => '?',
      };
}

class _PlayerRatingCard extends StatelessWidget {
  final PlayerInfo? player;
  final GameResult result;
  final PlayerColor side;
  const _PlayerRatingCard(
      {required this.player, required this.result, required this.side});

  @override
  Widget build(BuildContext context) {
    final p = player;
    if (p == null) return const SizedBox();
    final won =
        (result == GameResult.whiteWins && side == PlayerColor.white) ||
            (result == GameResult.blackWins && side == PlayerColor.black);
    final draw = result == GameResult.draw;
    final ratingChange = won ? '+12' : draw ? '+2' : '-10';
    final changeColor = won ? Colors.green : draw ? Colors.grey : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(p.username,
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text('${p.rating}',
            style:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        Text(ratingChange,
            style: TextStyle(
                fontSize: 12,
                color: changeColor,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
