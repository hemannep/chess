import 'package:flutter/material.dart';

class EmojiReactionBar extends StatefulWidget {
  final Future<void> Function(String emoji) onEmoji;
  const EmojiReactionBar({super.key, required this.onEmoji});

  @override
  State<EmojiReactionBar> createState() => _EmojiReactionBarState();
}

class _EmojiReactionBarState extends State<EmojiReactionBar> {
  static const _emojis = ['👍', '😅', '🤔', '😱', '🎉', '🙄'];
  DateTime? _lastSent;

  void _send(String emoji) {
    final now = DateTime.now();
    if (_lastSent != null && now.difference(_lastSent!).inSeconds < 5) return;
    _lastSent = now;
    widget.onEmoji(emoji);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _emojis.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _send(_emojis[i]),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Center(
              child: Text(_emojis[i], style: const TextStyle(fontSize: 18)),
            ),
          ),
        ),
      ),
    );
  }
}
