import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';
import 'package:chess_master/features/game/presentation/notifiers/game_notifier.dart';
import 'package:chess_master/features/game/presentation/widgets/chess_clock_widget.dart';
import 'package:chess_master/features/game/presentation/widgets/emoji_reaction_bar.dart';
import 'package:chess_master/features/game/presentation/dialogs/promotion_dialog.dart';
import 'package:chess_master/features/game/presentation/dialogs/resign_dialog.dart';
import 'package:chess_master/features/game/presentation/dialogs/draw_offer_dialog.dart';
import 'package:chess_master/features/game/presentation/screens/game_result_screen.dart';
import 'package:chess_master/app/theme.dart';
import 'package:chess_master/core/providers.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String gameId;
  final String? myUid;

  const GameScreen({super.key, required this.gameId, this.myUid});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameNotifierProvider(widget.gameId).notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameNotifierProvider(widget.gameId));
    final theme = context.chessTheme;

    ref.listen(gameNotifierProvider(widget.gameId), (prev, next) {
      if (prev?.phase != GameScreenPhase.result &&
          next.phase == GameScreenPhase.result &&
          next.game != null) {
        _showResultSheet(next.game!);
      }
      if (next.pendingPromotion != null &&
          prev?.pendingPromotion != next.pendingPromotion) {
        _showPromotionDialog(next.game!);
      }
      if (next.game?.drawOfferBy != null &&
          next.game!.drawOfferBy != widget.myUid &&
          prev?.game?.drawOfferBy == null) {
        _showDrawOfferDialog();
      }
    });

    if (gameState.phase == GameScreenPhase.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final game = gameState.game;
    if (game == null) {
      return Scaffold(
          body: Center(child: Text(gameState.errorMessage ?? 'Game not found')));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, game, gameState),
      body: SafeArea(
        child: Column(
          children: [
            _buildPlayerSection(context, game, gameState, isTop: true),
            if (!gameState.opponentConnected && game.mode == GameMode.online)
              _DisconnectBanner(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildBoard(context, game, gameState, theme),
              ),
            ),
            _buildPlayerSection(context, game, gameState, isTop: false),
            _buildControlBar(context, game, gameState),
            if (game.mode == GameMode.online)
              EmojiReactionBar(
                onEmoji: (emoji) => ref
                    .read(gameNotifierProvider(widget.gameId).notifier)
                    .sendEmoji(emoji),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, GameEntity game, GameState gs) {
    return AppBar(
      title: Text(_gameModeLabel(game)),
      actions: [
        IconButton(
          icon: const Icon(Icons.format_list_numbered_rtl),
          onPressed: () => _showMoveHistory(game),
        ),
      ],
    );
  }

  Widget _buildPlayerSection(
      BuildContext context, GameEntity game, GameState gs,
      {required bool isTop}) {
    final PlayerInfo? player;
    final TimerState timerState;
    final bool isTheirTurn;

    if (game.mode == GameMode.local) {
      player = isTop ? game.black : game.white;
      isTheirTurn = isTop
          ? game.currentTurn == PlayerColor.black
          : game.currentTurn == PlayerColor.white;
      timerState = isTop ? game.blackTimer : game.whiteTimer;
    } else {
      final iAmWhite = widget.myUid == game.white?.uid;
      player = isTop
          ? (iAmWhite ? game.black : game.white)
          : (iAmWhite ? game.white : game.black);
      timerState = isTop
          ? (iAmWhite ? game.blackTimer : game.whiteTimer)
          : (iAmWhite ? game.whiteTimer : game.blackTimer);
      isTheirTurn = isTop
          ? game.currentTurnUid != widget.myUid
          : game.currentTurnUid == widget.myUid;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _PlayerInfoBar(player: player, isActive: isTheirTurn),
          const Spacer(),
          ChessClockWidget(
            timerState: timerState,
            isActive: isTheirTurn,
            isCritical: timerState.displayMs < 10000,
          ),
        ],
      ),
    );
  }

  Widget _buildBoard(BuildContext context, GameEntity game, GameState gs,
      ChessThemeExtension chessTheme) {
    final notifier = ref.read(gameNotifierProvider(widget.gameId).notifier);
    return AspectRatio(
      aspectRatio: 1,
      child: _SimpleBoardWidget(
        fen: game.fen,
        selectedSquare: gs.selectedSquare,
        legalMoves: gs.legalMoves,
        lastFrom: game.moves.isNotEmpty ? game.moves.last.from : null,
        lastTo: game.moves.isNotEmpty ? game.moves.last.to : null,
        chessTheme: chessTheme,
        flipped: widget.myUid != null && widget.myUid == game.black?.uid,
        onSquareTapped:
            gs.phase == GameScreenPhase.active ? notifier.onSquareTapped : null,
      ),
    );
  }

  Widget _buildControlBar(
      BuildContext context, GameEntity game, GameState gs) {
    final notifier = ref.read(gameNotifierProvider(widget.gameId).notifier);
    final isActive = gs.phase == GameScreenPhase.active;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (game.mode == GameMode.online) ...[
            _ControlButton(
                icon: Icons.handshake_outlined,
                label: 'Draw',
                onTap: isActive ? () => _offerDraw(notifier) : null),
            const SizedBox(width: 16),
          ],
          _ControlButton(
              icon: Icons.flag_outlined,
              label: 'Resign',
              color: Colors.red,
              onTap: isActive ? () => _resignDialog(notifier) : null),
          const SizedBox(width: 16),
          _ControlButton(
              icon: Icons.history_outlined,
              label: 'Moves',
              onTap: () => _showMoveHistory(game)),
        ],
      ),
    );
  }

  void _showResultSheet(GameEntity game) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GameResultSheet(
        game: game,
        myUid: widget.myUid,
        onRematch: () => ref
            .read(gameNotifierProvider(widget.gameId).notifier)
            .requestRematch(),
      ),
    );
  }

  void _showPromotionDialog(GameEntity game) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PromotionDialog(
        color: game.currentTurn,
        onSelect: (piece) => ref
            .read(gameNotifierProvider(widget.gameId).notifier)
            .onPromotionSelected(piece),
      ),
    );
  }

  void _showDrawOfferDialog() {
    if (!mounted) return;
    final notifier = ref.read(gameNotifierProvider(widget.gameId).notifier);
    showDialog(
      context: context,
      builder: (_) => DrawOfferDialog(
        onAccept: notifier.acceptDraw,
        onDecline: notifier.declineDraw,
      ),
    );
  }

  void _offerDraw(GameNotifier notifier) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Offer Draw?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              notifier.offerDraw();
            },
            child: const Text('Send Offer'),
          ),
        ],
      ),
    );
  }

  void _resignDialog(GameNotifier notifier) {
    showDialog(
      context: context,
      builder: (_) => ResignDialog(onConfirm: () {
        Navigator.pop(context);
        notifier.resign();
      }),
    );
  }

  void _showMoveHistory(GameEntity game) {
    showModalBottomSheet(
      context: context,
      builder: (_) => MoveHistorySheet(moves: game.moves),
    );
  }

  String _gameModeLabel(GameEntity game) => switch (game.mode) {
        GameMode.local => 'Local Game',
        GameMode.online =>
          game.roomCode != null ? '🔑 Friend Match' : '🌐 Online Match',
        GameMode.bot =>
          '🤖 vs ${game.botDifficulty?.name.toUpperCase() ?? "Bot"}',
      };
}

// ── Custom SVG/text-based board widget ──────────────────────────────────────

class _SimpleBoardWidget extends StatelessWidget {
  final String fen;
  final String? selectedSquare;
  final List<String> legalMoves;
  final String? lastFrom;
  final String? lastTo;
  final ChessThemeExtension chessTheme;
  final bool flipped;
  final void Function(String square)? onSquareTapped;

  const _SimpleBoardWidget({
    required this.fen,
    this.selectedSquare,
    this.legalMoves = const [],
    this.lastFrom,
    this.lastTo,
    required this.chessTheme,
    required this.flipped,
    this.onSquareTapped,
  });

  static const _files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
  static const _ranks = ['8', '7', '6', '5', '4', '3', '2', '1'];
  static const _pieceMap = {
    'K': '♔',
    'Q': '♕',
    'R': '♖',
    'B': '♗',
    'N': '♘',
    'P': '♙',
    'k': '♚',
    'q': '♛',
    'r': '♜',
    'b': '♝',
    'n': '♞',
    'p': '♟',
  };

  Map<String, String> _parseFen(String fen) {
    final board = <String, String>{};
    final rows = fen.split(' ')[0].split('/');
    for (int r = 0; r < 8; r++) {
      int f = 0;
      for (final ch in rows[r].runes) {
        final c = String.fromCharCode(ch);
        if (int.tryParse(c) != null) {
          f += int.parse(c);
        } else {
          final sq = '${_files[f]}${8 - r}';
          board[sq] = c;
          f++;
        }
      }
    }
    return board;
  }

  @override
  Widget build(BuildContext context) {
    final pieces = _parseFen(fen);
    final ranks = flipped ? _ranks.reversed.toList() : _ranks;
    final files = flipped ? _files.reversed.toList() : _files;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8),
      itemCount: 64,
      itemBuilder: (_, i) {
        final rank = ranks[i ~/ 8];
        final file = files[i % 8];
        final square = '$file$rank';
        final isLight = (files.indexOf(file) + ranks.indexOf(rank)) % 2 == 0;
        final piece = pieces[square];
        final isSelected = square == selectedSquare;
        final isLegal = legalMoves.contains(square);
        final isLastMove = square == lastFrom || square == lastTo;

        Color sqColor =
            isLight ? chessTheme.lightSquare : chessTheme.darkSquare;
        if (isSelected) sqColor = chessTheme.selectedHighlight;
        if (isLastMove) sqColor = chessTheme.lastMoveHighlight;

        return GestureDetector(
          onTap: () => onSquareTapped?.call(square),
          child: Container(
            color: sqColor,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isLegal && piece == null)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: chessTheme.legalMoveColor),
                  ),
                if (isLegal && piece != null)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: chessTheme.legalMoveColor, width: 3),
                    ),
                  ),
                if (piece != null)
                  FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Text(
                        _pieceMap[piece] ?? piece,
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayerInfoBar extends StatelessWidget {
  final PlayerInfo? player;
  final bool isActive;
  const _PlayerInfoBar({this.player, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final p = player;
    if (p == null) return const SizedBox(width: 120);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(p.username.isNotEmpty ? p.username[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 6),
        Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(p.username,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${p.rating}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
      ]),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  const _ControlButton(
      {required this.icon, required this.label, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    final active = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: c.withOpacity(active ? 0.3 : 0.1)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: c.withOpacity(active ? 1.0 : 0.3), size: 20),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: c.withOpacity(active ? 1.0 : 0.3))),
        ]),
      ),
    );
  }
}

class _DisconnectBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.orange.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: const [
        SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.orange)),
        SizedBox(width: 8),
        Expanded(
            child: Text('Opponent disconnected — waiting 60s...',
                style: TextStyle(fontSize: 12))),
      ]),
    ).animate().fadeIn();
  }
}
