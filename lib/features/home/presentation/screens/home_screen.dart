import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_master/core/providers.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess Master'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Error loading profile')),
          data: (user) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _GreetingCard(
                username: user?.username ?? 'Guest',
                rating: user?.rating ?? 1200,
                streak: user?.streak ?? 0,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go('/play'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('♟', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                      Text('Play Now', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Quick Play', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              _buildModeGrid(context),
              const SizedBox(height: 24),
              Text('Daily Puzzle', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              _buildPuzzleCard(context, theme),
              const SizedBox(height: 24),
              if (user != null) ...[
                Text('Your Stats', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                _buildStatsRow(context, user),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeGrid(BuildContext context) {
    final modes = [
      ('vs Friend', '🔑', '/matchmaking/room', const Color(0xFF4B7B4B)),
      ('Random', '🌐', '/matchmaking/random', const Color(0xFF1565C0)),
      ('vs Bot', '🤖', '/setup/bot', const Color(0xFF6A1B9A)),
      ('Local', '👥', '/setup/local', const Color(0xFF00695C)),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: modes.map((m) {
        return InkWell(
          onTap: () => context.go(m.$3),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: m.$4.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: m.$4.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Text(m.$2, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  m.$1,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: m.$4, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPuzzleCard(BuildContext context, ThemeData theme) {
    return InkWell(
      onTap: () => context.go('/puzzle'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Text('🧩', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Puzzle of the Day',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Solve today\'s puzzle to keep your streak!',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: theme.colorScheme.onTertiaryContainer),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, UserEntity user) {
    return Row(
      children: [
        _StatBox(label: 'Games', value: '${user.gamesPlayed}'),
        const SizedBox(width: 8),
        _StatBox(label: 'Wins', value: '${user.wins}', color: Colors.green),
        const SizedBox(width: 8),
        _StatBox(label: 'Losses', value: '${user.losses}', color: Colors.red),
        const SizedBox(width: 8),
        _StatBox(label: 'Draws', value: '${user.draws}', color: Colors.grey),
      ],
    );
  }
}

class _GreetingCard extends StatelessWidget {
  final String username;
  final int rating;
  final int streak;
  const _GreetingCard({
    required this.username,
    required this.rating,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, $username!', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.star, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text('$rating ELO', style: theme.textTheme.bodyMedium),
                  if (streak > 0) ...[
                    const SizedBox(width: 12),
                    const Text('🔥', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 3),
                    Text('$streak day streak',
                        style: theme.textTheme.bodyMedium),
                  ],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatBox({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
