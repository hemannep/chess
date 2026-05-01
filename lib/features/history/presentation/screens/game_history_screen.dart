import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/providers.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';

class GameHistoryScreen extends ConsumerWidget {
  const GameHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Game History')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error')),
        data: (user) {
          if (user == null) {
            return const Center(
                child: Text('Please log in to view history'));
          }
          return _HistoryList(uid: user.uid);
        },
      ),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  final String uid;
  const _HistoryList({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(gameHistoryProvider(uid));
    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load games')),
      data: (games) {
        if (games.isEmpty) {
          return const Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('♟', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text('No games yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text('Play your first game to see it here',
                  style: TextStyle(color: Colors.grey)),
            ]),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: games.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) => _GameTile(game: games[i], myUid: uid),
        );
      },
    );
  }
}

class _GameTile extends StatelessWidget {
  final GameEntity game;
  final String myUid;
  const _GameTile({required this.game, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final isWhite = game.white?.uid == myUid;
    final myColor = isWhite ? PlayerColor.white : PlayerColor.black;
    final iWon = (game.result == GameResult.whiteWins &&
            myColor == PlayerColor.white) ||
        (game.result == GameResult.blackWins && myColor == PlayerColor.black);
    final isDraw = game.result == GameResult.draw;

    final resultLabel = isDraw ? 'Draw' : iWon ? 'Win' : 'Loss';
    final resultColor = isDraw
        ? Colors.grey
        : iWon
            ? Colors.green
            : Colors.red;

    final opponent = isWhite ? game.black : game.white;
    final date = game.endedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(game.endedAt!)
            .toString()
            .substring(0, 10)
        : '';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: resultColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                    child: Text(
                  isDraw ? '½' : iWon ? '✓' : '✗',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: resultColor),
                )),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opponent?.username ?? 'Unknown',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text(game.mode.name,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        const Text(' · ', style: TextStyle(color: Colors.grey)),
                        Text(game.timeControl.displayString,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        if (game.resultReason != null) ...[
                          const Text(' · ',
                              style: TextStyle(color: Colors.grey)),
                          Text(_reasonShort(game.resultReason),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ]),
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: resultColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(resultLabel,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: resultColor)),
                ),
                const SizedBox(height: 4),
                Text(date,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  String _reasonShort(ResultReason? r) => switch (r) {
        ResultReason.checkmate => 'Checkmate',
        ResultReason.timeout => 'Timeout',
        ResultReason.resign => 'Resigned',
        ResultReason.agreement => 'Agreement',
        ResultReason.stalemate => 'Stalemate',
        _ => '',
      };
}
