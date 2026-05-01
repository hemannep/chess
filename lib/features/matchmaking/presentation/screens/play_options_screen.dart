import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PlayOptionsScreen extends StatelessWidget {
  const PlayOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Play Chess')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Choose a mode', style: theme.textTheme.titleLarge),
            const SizedBox(height: 20),
            _PlayCard(
              emoji: '🌐',
              title: 'Random Match',
              subtitle: 'Play against someone worldwide',
              color: const Color(0xFF1565C0),
              onTap: () => context.go('/matchmaking/random'),
            ),
            const SizedBox(height: 12),
            _PlayCard(
              emoji: '🔑',
              title: 'Play a Friend',
              subtitle: 'Create or join a private room',
              color: const Color(0xFF4B7B4B),
              onTap: () => context.go('/matchmaking/room'),
            ),
            const SizedBox(height: 12),
            _PlayCard(
              emoji: '🤖',
              title: 'Play vs Bot',
              subtitle: 'Challenge the AI at your level',
              color: const Color(0xFF6A1B9A),
              onTap: () => context.go('/setup/bot'),
            ),
            const SizedBox(height: 12),
            _PlayCard(
              emoji: '👥',
              title: 'Local Game',
              subtitle: 'Two players on the same device',
              color: const Color(0xFF00695C),
              onTap: () => context.go('/setup/local'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayCard extends StatelessWidget {
  final String emoji, title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _PlayCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14)),
              child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600])),
                  ]),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}
