import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_master/core/providers.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.go('/settings')),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load profile')),
        data: (user) {
          if (user == null) return const Center(child: Text('Not logged in'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProfileHeader(user: user),
              const SizedBox(height: 20),
              _RatingCard(user: user),
              const SizedBox(height: 16),
              _XpCard(user: user),
              const SizedBox(height: 16),
              Text('Statistics', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              _StatsGrid(user: user),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Achievements', style: theme.textTheme.titleMedium),
                  TextButton(
                      onPressed: () => context.go('/achievements'),
                      child: const Text('See all')),
                ],
              ),
              const SizedBox(height: 8),
              _AchievementsRow(earned: user.earnedAchievements),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Games', style: theme.textTheme.titleMedium),
                  TextButton(
                      onPressed: () => context.go('/history'),
                      child: const Text('See all')),
                ],
              ),
              const SizedBox(height: 8),
              _RecentGamesSection(uid: user.uid),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserEntity user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: theme.colorScheme.primary,
          child: Text(
            user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.username, style: theme.textTheme.titleLarge),
            if (user.country != null)
              Text('🌍 ${user.country}', style: theme.textTheme.bodyMedium),
            if (user.isGuest)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('Guest Account',
                    style: TextStyle(fontSize: 11, color: Colors.orange)),
              ),
          ]),
        ),
      ],
    );
  }
}

class _RatingCard extends StatelessWidget {
  final UserEntity user;
  const _RatingCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _RatingItem(label: 'Current', value: '${user.rating}', icon: '⭐'),
          Container(
              width: 1,
              height: 40,
              color:
                  theme.colorScheme.onPrimaryContainer.withOpacity(0.2)),
          _RatingItem(label: 'Peak', value: '${user.ratingPeak}', icon: '🏆'),
          Container(
              width: 1,
              height: 40,
              color:
                  theme.colorScheme.onPrimaryContainer.withOpacity(0.2)),
          _RatingItem(label: 'Streak', value: '${user.streak}d', icon: '🔥'),
        ],
      ),
    );
  }
}

class _RatingItem extends StatelessWidget {
  final String label, value, icon;
  const _RatingItem(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(icon, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }
}

class _XpCard extends StatelessWidget {
  final UserEntity user;
  const _XpCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final progress = XpSystem.progressToNextLevel(user.xp);
    final toNext = XpSystem.xpToNextLevel(user.xp);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Level ${user.level}', style: theme.textTheme.titleMedium),
            const Spacer(),
            Text('${user.xp} XP', style: theme.textTheme.bodyMedium),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 4),
          Text('$toNext XP to Level ${user.level + 1}',
              style: theme.textTheme.bodyMedium),
        ]),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final UserEntity user;
  const _StatsGrid({required this.user});

  @override
  Widget build(BuildContext context) {
    final winRate =
        user.gamesPlayed > 0 ? (user.wins / user.gamesPlayed * 100).round() : 0;
    final items = [
      ('${user.gamesPlayed}', 'Games'),
      ('${user.wins}', 'Wins'),
      ('${user.losses}', 'Losses'),
      ('${user.draws}', 'Draws'),
      ('$winRate%', 'Win Rate'),
      ('${user.streak}', 'Streak'),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.5,
      children: items
          .map((i) => Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(i.$1,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(i.$2,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ]),
              ))
          .toList(),
    );
  }
}

class _AchievementsRow extends StatelessWidget {
  final List<String> earned;
  const _AchievementsRow({required this.earned});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (earned.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12)),
        child: const Text(
            'No achievements yet. Start playing to earn some!',
            style: TextStyle(color: Colors.grey)),
      );
    }
    final shown = earned.take(6).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: shown.map((id) {
        final a = Achievements.findById(id);
        if (a == null) return const SizedBox.shrink();
        return Tooltip(
          message: a.title,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
                child: Text(a.icon, style: const TextStyle(fontSize: 22))),
          ),
        );
      }).toList(),
    );
  }
}

class _RecentGamesSection extends ConsumerWidget {
  final String uid;
  const _RecentGamesSection({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(gameHistoryProvider(uid));
    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Failed to load games'),
      data: (games) {
        if (games.isEmpty) {
          return const Text('No games yet',
              style: TextStyle(color: Colors.grey));
        }
        return Column(
          children: games
              .take(5)
              .map((g) => _GameHistoryTile(game: g, uid: uid))
              .toList(),
        );
      },
    );
  }
}

class _GameHistoryTile extends StatelessWidget {
  final GameEntity game;
  final String uid;
  const _GameHistoryTile({required this.game, required this.uid});

  @override
  Widget build(BuildContext context) {
    final isWhite = game.white?.uid == uid;
    final myColor = isWhite ? PlayerColor.white : PlayerColor.black;
    final won = (game.result == GameResult.whiteWins && myColor == PlayerColor.white) ||
        (game.result == GameResult.blackWins && myColor == PlayerColor.black);
    final draw = game.result == GameResult.draw;
    final label = draw ? 'Draw' : won ? 'Win' : 'Loss';
    final color = draw ? Colors.grey : won ? Colors.green : Colors.red;
    final opponent = isWhite ? game.black : game.white;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            draw ? '½' : won ? '✓' : '✗',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ),
      title: Text(
        opponent?.username ?? 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        '${game.mode.name} · ${game.timeControl.displayString}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
