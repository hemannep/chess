import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_master/core/providers.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';
import 'package:chess_master/features/matchmaking/data/matchmaking_repository.dart';

class RandomMatchmakingScreen extends ConsumerStatefulWidget {
  const RandomMatchmakingScreen({super.key});
  @override
  ConsumerState<RandomMatchmakingScreen> createState() =>
      _RandomMatchmakingScreenState();
}

class _RandomMatchmakingScreenState
    extends ConsumerState<RandomMatchmakingScreen>
    with SingleTickerProviderStateMixin {
  TimeControlPreset _preset = TimeControlPreset.rapid10;
  bool _started = false;
  late AnimationController _pulse;

  static const _presets = [
    (TimeControlPreset.bullet1, '1 min', '⚡ Bullet'),
    (TimeControlPreset.blitz3, '3 min', '🔥 Blitz'),
    (TimeControlPreset.blitz5, '5 min', '🏃 Blitz'),
    (TimeControlPreset.rapid10, '10 min', '♟ Rapid'),
    (TimeControlPreset.rapid15, '15 min', '🧠 Rapid'),
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _startSearch() {
    final timeControl = TimeControl.fromPreset(_preset);
    ref
        .read(matchmakingNotifierProvider.notifier)
        .startRandomSearch(timeControl);
    setState(() => _started = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchmakingNotifierProvider);
    final theme = Theme.of(context);

    ref.listen(matchmakingNotifierProvider, (_, next) {
      if (next.status == MatchmakingStatus.matched && next.gameId != null) {
        final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
        context.go('/game/${next.gameId}?uid=$uid');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Game'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(matchmakingNotifierProvider.notifier).cancelSearch();
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: _started ? _buildSearching(state, theme) : _buildSetup(theme),
      ),
    );
  }

  Widget _buildSetup(ThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Choose Time Control', style: theme.textTheme.titleLarge),
              const SizedBox(height: 20),
              ..._presets.map((p) => RadioListTile<TimeControlPreset>(
                    title: Text(p.$3,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(p.$2),
                    value: p.$1,
                    groupValue: _preset,
                    onChanged: (v) => setState(() => _preset = v!),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  )),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _startSearch,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child:
                  const Text('Find Opponent', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearching(MatchmakingState state, ThemeData theme) {
    final elapsed = state.elapsed;
    final mm = elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Transform.scale(
                scale: 1.0 + _pulse.value * 0.08,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    border: Border.all(
                        color: theme.colorScheme.primary
                            .withOpacity(0.4 + _pulse.value * 0.3),
                        width: 2),
                  ),
                  child: Center(
                    child: Text('♟',
                        style: TextStyle(
                            fontSize: 50, color: theme.colorScheme.primary)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text('Searching...', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Looking for an opponent', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Text('$mm:$ss',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    fontFamily: 'monospace')),
            const SizedBox(height: 8),
            Text(TimeControl.fromPreset(_preset).displayString,
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 40),
            OutlinedButton(
              onPressed: () {
                ref
                    .read(matchmakingNotifierProvider.notifier)
                    .cancelSearch();
                setState(() => _started = false);
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
