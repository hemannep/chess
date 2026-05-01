import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/providers.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error')),
        data: (user) {
          final earned = user?.earnedAchievements ?? [];
          final categories = AchievementCategory.values;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${earned.length}',
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.bold)),
                        Text(' / ${Achievements.all.length} unlocked',
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                  ),
                );
              }
              final cat = categories[i - 1];
              final catAchievements =
                  Achievements.all.where((a) => a.category == cat).toList();
              if (catAchievements.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      cat.name[0].toUpperCase() + cat.name.substring(1),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.0,
                    children: catAchievements.map((a) {
                      final isEarned = earned.contains(a.id);
                      final isLocked = a.isSecret && !isEarned;
                      return _AchievementCard(
                          achievement: a, earned: isEarned, locked: isLocked);
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final bool earned;
  final bool locked;
  const _AchievementCard(
      {required this.achievement, required this.earned, required this.locked});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: earned
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              earned ? theme.colorScheme.primary.withOpacity(0.4) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Text(
            locked ? '🔒' : achievement.icon,
            style: TextStyle(
                fontSize: 24,
                color: earned ? null : Colors.grey.withOpacity(0.5)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  locked ? '???' : achievement.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: earned ? null : Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!locked)
                  Text(
                    '+${achievement.xpReward} XP',
                    style: TextStyle(
                        fontSize: 10,
                        color: earned ? theme.colorScheme.primary : Colors.grey),
                  ),
              ],
            ),
          ),
          if (earned)
            Icon(Icons.check_circle,
                size: 16, color: theme.colorScheme.primary),
        ],
      ),
    );
  }
}
