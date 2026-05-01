import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_master/core/providers.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';

class LocalSetupScreen extends ConsumerStatefulWidget {
  const LocalSetupScreen({super.key});
  @override
  ConsumerState<LocalSetupScreen> createState() => _LocalSetupScreenState();
}

class _LocalSetupScreenState extends ConsumerState<LocalSetupScreen> {
  TimeControlPreset _preset = TimeControlPreset.rapid10;
  bool _loading = false;

  static const _presets = [
    (TimeControlPreset.bullet1, '1 min', '⚡'),
    (TimeControlPreset.blitz3, '3 min', '🔥'),
    (TimeControlPreset.blitz5, '5 min', '🏃'),
    (TimeControlPreset.rapid10, '10 min', '♟'),
    (TimeControlPreset.rapid15, '15 min', '🧠'),
  ];

  Future<void> _startGame() async {
    setState(() => _loading = true);
    try {
      final timeControl = TimeControl.fromPreset(_preset);
      final gameId = await ref
          .read(gameRepositoryProvider)
          .createLocalGame(timeControl: timeControl);
      if (mounted) context.go('/game/$gameId');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Local Game')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Time Control', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('Choose how much time each player gets',
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    ..._presets.map((p) => _PresetTile(
                          emoji: p.$3,
                          label: p.$2,
                          selected: _preset == p.$1,
                          onTap: () => setState(() => _preset = p.$1),
                        )),
                  ],
                ),
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

class _PresetTile extends StatelessWidget {
  final String emoji, label;
  final bool selected;
  final VoidCallback onTap;
  const _PresetTile(
      {required this.emoji,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Text(label,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: selected ? color : null)),
          const Spacer(),
          if (selected) Icon(Icons.check_circle, color: color),
        ]),
      ),
    );
  }
}
