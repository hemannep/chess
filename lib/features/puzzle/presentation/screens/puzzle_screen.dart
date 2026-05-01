import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/providers.dart';
import 'package:chess_master/features/puzzle/data/puzzle_repository.dart';

final puzzleRepositoryProvider = Provider((ref) => PuzzleRepository());

final puzzleNotifierProvider =
    StateNotifierProvider.autoDispose<PuzzleNotifier, PuzzleState>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return PuzzleNotifier(
    repo: ref.watch(puzzleRepositoryProvider),
    engine: ref.watch(chessEngineProvider),
    uid: user?.uid ?? 'guest',
  );
});

class PuzzleScreen extends ConsumerStatefulWidget {
  const PuzzleScreen({super.key});
  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(puzzleNotifierProvider.notifier).loadDailyPuzzle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(puzzleNotifierProvider);
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserProvider);
    final streak = userAsync.valueOrNull?.streak ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Puzzle'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(children: [
              const Text('🔥', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text('$streak', style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ),
        ],
      ),
      body: SafeArea(
        child: state.phase == PuzzlePhase.loading
            ? const Center(child: CircularProgressIndicator())
            : _buildPuzzleBody(context, state, theme),
      ),
    );
  }

  Widget _buildPuzzleBody(BuildContext context, PuzzleState state, ThemeData theme) {
    final notifier = ref.read(puzzleNotifierProvider.notifier);
    final puzzle = state.puzzle;
    if (puzzle == null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('No puzzle available today', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: () => notifier.loadRandomPuzzle(),
              child: const Text('Load Random Puzzle')),
        ]),
      );
    }

    return Column(
      children: [
        _StatusBanner(phase: state.phase),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _DifficultyBadge(difficulty: puzzle.difficulty),
              const Spacer(),
              Text(
                puzzle.themes.isNotEmpty ? puzzle.themes.first.name : '',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('♟', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 12),
                    Text(
                      'FEN: ${state.currentFen.split(' ').first}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.currentFen.split(' ').length > 1 &&
                              state.currentFen.split(' ')[1] == 'w'
                          ? 'White to move'
                          : 'Black to move',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.lightbulb_outline, size: 18),
                label: const Text('Show Solution'),
                onPressed: state.phase == PuzzlePhase.playing
                    ? notifier.showSolution
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('New Puzzle'),
                onPressed: () => notifier.loadRandomPuzzle(),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final PuzzlePhase phase;
  const _StatusBanner({required this.phase});

  @override
  Widget build(BuildContext context) {
    final (text, color, icon) = switch (phase) {
      PuzzlePhase.correct => ('Correct! Well done!', Colors.green, '🎉'),
      PuzzlePhase.incorrect =>
        ('Not quite — try again!', Colors.orange, '🤔'),
      PuzzlePhase.reviewing => ('Here\'s the solution', Colors.blue, '💡'),
      _ => ('Find the best move', Theme.of(context).colorScheme.primary, '♟'),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withOpacity(0.1),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text(text,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final PuzzleDifficulty difficulty;
  const _DifficultyBadge({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (difficulty) {
      PuzzleDifficulty.beginner => ('Beginner', Colors.green),
      PuzzleDifficulty.intermediate => ('Intermediate', Colors.orange),
      PuzzleDifficulty.advanced => ('Advanced', Colors.red),
      PuzzleDifficulty.expert => ('Expert', Colors.purple),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
