import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_master/core/providers.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    void update(UserSettings s) {
      ref.read(settingsProvider.notifier).state = s;
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        ref.read(profileRepositoryProvider).updateSettings(user.uid, s);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: settings.darkMode,
            onChanged: (v) => update(settings.copyWith(darkMode: v)),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Board Theme'),
            subtitle: Text(settings.boardTheme),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showBoardThemePicker(context, settings, update),
          ),
          ListTile(
            leading: const Icon(Icons.extension_outlined),
            title: const Text('Piece Set'),
            subtitle: Text(settings.pieceSet),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          const _SectionHeader('Gameplay'),
          SwitchListTile(
            title: const Text('Show Legal Moves'),
            secondary: const Icon(Icons.circle_outlined),
            value: settings.showLegalMoves,
            onChanged: (v) => update(settings.copyWith(showLegalMoves: v)),
          ),
          SwitchListTile(
            title: const Text('Show Coordinates'),
            secondary: const Icon(Icons.grid_on),
            value: settings.showCoordinates,
            onChanged: (v) => update(settings.copyWith(showCoordinates: v)),
          ),
          SwitchListTile(
            title: const Text('Auto-promote to Queen'),
            secondary: const Icon(Icons.upgrade),
            value: settings.autoPromoteToQueen,
            onChanged: (v) => update(settings.copyWith(autoPromoteToQueen: v)),
          ),
          const Divider(),
          const _SectionHeader('Sound & Haptics'),
          SwitchListTile(
            title: const Text('Sound Effects'),
            secondary: const Icon(Icons.volume_up_outlined),
            value: settings.soundEnabled,
            onChanged: (v) => update(settings.copyWith(soundEnabled: v)),
          ),
          SwitchListTile(
            title: const Text('Haptic Feedback'),
            secondary: const Icon(Icons.vibration),
            value: settings.hapticEnabled,
            onChanged: (v) => update(settings.copyWith(hapticEnabled: v)),
          ),
          const Divider(),
          const _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: const Text('Achievements'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/achievements'),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out',
                style: TextStyle(color: Colors.red)),
            onTap: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/auth/login');
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showBoardThemePicker(BuildContext ctx, UserSettings settings,
      void Function(UserSettings) update) {
    const themes = ['classic', 'ocean', 'marble', 'green'];
    showModalBottomSheet(
      context: ctx,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Board Theme',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: themes
                  .map((t) => ChoiceChip(
                        label: Text(t[0].toUpperCase() + t.substring(1)),
                        selected: settings.boardTheme == t,
                        onSelected: (_) {
                          update(settings.copyWith(boardTheme: t));
                          Navigator.pop(ctx);
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5)),
    );
  }
}
