import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_master/core/providers.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';

class BotSetupScreen extends ConsumerStatefulWidget {
  const BotSetupScreen({super.key});
  @override
  ConsumerState<BotSetupScreen> createState() => _BotSetupScreenState();
}

class _BotSetupScreenState extends ConsumerState<BotSetupScreen> {
  BotDifficulty _difficulty = BotDifficulty.easy;
  PlayerColor _color = PlayerColor.white;
  TimeControlPreset _preset = TimeControlPreset.rapid10;
  bool _loading = false;

  static const _difficulties = [
    _BotLevel(BotDifficulty.easy, '😊', 'Easy',
        'Makes mistakes, great for beginners', '~600 ELO'),
    _BotLevel(BotDifficulty.medium, '🙂', 'Medium',
        'Plays solid moves, some tactics', '~1000 ELO'),
    _BotLevel(BotDifficulty.hard, '😤', 'Hard',
        'Tactical and positional strength', '~1400 ELO'),
    _BotLevel(BotDifficulty.expert, '😈', 'Expert',
        'Near-perfect play, very challenging', '~1800 ELO'),
  ];

  static const _presets = [
    (TimeControlPreset.bullet1, '1 min'),
    (TimeControlPreset.blitz3, '3 min'),
    (TimeControlPreset.blitz5, '5 min'),
    (TimeControlPreset.rapid10, '10 min'),
    (TimeControlPreset.rapid15, '15 min'),
  ];

  Future<void> _startGame() async {
    setState(() => _loading = true);
    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      final authUser = ref.read(authStateProvider).valueOrNull;
      final timeControl = TimeControl.fromPreset(_preset);
      final gameId = await ref.read(gameRepositoryProvider).createBotGame(
            playerUid: user?.uid ?? authUser?.uid ?? 'guest',
            playerColor: _color,
            timeControl: timeControl,
            difficulty: _difficulty,
            playerInfo: PlayerInfo(
              uid: user?.uid ?? authUser?.uid ?? 'guest',
              username: user?.username ?? 'Guest',
              rating: user?.rating ?? 1200,
            ),
          );
      if (mounted) {
        context.go('/game/$gameId?uid=${user?.uid ?? authUser?.uid ?? ''}');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Play vs Bot')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Difficulty', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  ..._difficulties.map((d) => _DifficultyTile(
                        level: d,
                        selected: _difficulty == d.difficulty,
                        onTap: () =>
                            setState(() => _difficulty = d.difficulty),
                      )),
                  const SizedBox(height: 20),
                  Text('Your Color', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Row(children: [
                    _ColorOption(
                        label: '♙ White',
                        selected: _color == PlayerColor.white,
                        onTap: () =>
                            setState(() => _color = PlayerColor.white)),
                    const SizedBox(width: 10),
                    _ColorOption(
                        label: '♟ Black',
                        selected: _color == PlayerColor.black,
                        onTap: () =>
                            setState(() => _color = PlayerColor.black)),
                  ]),
                  const SizedBox(height: 20),
                  Text('Time Control', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presets
                        .map((p) => ChoiceChip(
                              label: Text(p.$2),
                              selected: _preset == p.$1,
                              onSelected: (_) =>
                                  setState(() => _preset = p.$1),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _startGame,
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Start Game',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotLevel {
  final BotDifficulty difficulty;
  final String emoji, name, desc, elo;
  const _BotLevel(this.difficulty, this.emoji, this.name, this.desc, this.elo);
}

class _DifficultyTile extends StatelessWidget {
  final _BotLevel level;
  final bool selected;
  final VoidCallback onTap;
  const _DifficultyTile(
      {required this.level, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.12)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? color : Colors.grey.withOpacity(0.3),
              width: selected ? 1.5 : 0.5),
        ),
        child: Row(children: [
          Text(level.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(level.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(level.elo,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(level.desc,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
          ),
          if (selected) Icon(Icons.check_circle, color: color),
        ]),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ColorOption(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? accent.withOpacity(0.12)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? accent : Colors.grey.withOpacity(0.3),
                width: selected ? 1.5 : 0.5),
          ),
          child: Center(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? accent : null))),
        ),
      ),
    );
  }
}
