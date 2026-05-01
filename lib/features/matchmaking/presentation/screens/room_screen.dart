import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:chess_master/core/providers.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key});
  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  String? _code;
  bool _creating = false;
  StreamSubscription<String?>? _sub;
  TimeControlPreset _preset = TimeControlPreset.rapid10;

  static const _presets = [
    (TimeControlPreset.blitz3, '3 min'),
    (TimeControlPreset.blitz5, '5 min'),
    (TimeControlPreset.rapid10, '10 min'),
    (TimeControlPreset.rapid15, '15 min'),
  ];

  Future<void> _createRoom() async {
    setState(() => _creating = true);
    try {
      final notifier = ref.read(matchmakingNotifierProvider.notifier);
      final timeControl = TimeControl.fromPreset(_preset);
      final result = await notifier.createRoom(timeControl);
      setState(() {
        _code = result.code;
        _creating = false;
      });
      _sub = result.gameIdStream.listen((gameId) {
        if (gameId != null && mounted) {
          final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
          context.go('/game/$gameId?uid=$uid');
        }
      });
    } catch (e) {
      setState(() => _creating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Friend Match')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _code == null ? _buildSetup(theme) : _buildWaiting(theme),
        ),
      ),
    );
  }

  Widget _buildSetup(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Create a Room', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('Choose a time control and share the code with your friend.',
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: 24),
        Text('Time Control', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presets
              .map((p) => ChoiceChip(
                    label: Text(p.$2),
                    selected: _preset == p.$1,
                    onSelected: (_) => setState(() => _preset = p.$1),
                  ))
              .toList(),
        ),
        const Spacer(),
        FilledButton(
          onPressed: _creating ? null : _createRoom,
          style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16)),
          child: _creating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Create Room', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.go('/matchmaking/join'),
          child: const Text('Join with a Code Instead'),
        ),
      ],
    );
  }

  Widget _buildWaiting(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Share this code',
            style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Your friend needs to enter this code to join.',
            style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            Text(
              _code!.replaceAllMapped(RegExp(r'(.{3})'), (m) => '${m[1]} '),
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: theme.colorScheme.onPrimaryContainer,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _code!));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied!')));
                },
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share'),
                onPressed: () => Share.share(
                    'Join my chess game! Code: $_code\nDownload Chess Master to play.'),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 40),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        Text('Waiting for your friend to join...',
            style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: 40),
        OutlinedButton(
          onPressed: () => setState(() {
            _code = null;
            _sub?.cancel();
          }),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});
  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _join() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Code must be 6 characters');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final gameId = await ref
          .read(matchmakingNotifierProvider.notifier)
          .joinRoom(code);
      final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
      if (mounted) context.go('/game/$gameId?uid=$uid');
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Join a Room')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Enter Room Code', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Ask your friend for their 6-character room code.',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 32),
              TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  labelText: 'Room Code',
                  hintText: 'e.g. KING42',
                  border: const OutlineInputBorder(),
                  errorText: _error,
                  prefixIcon: const Icon(Icons.key),
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                style: const TextStyle(
                    fontSize: 22,
                    letterSpacing: 6,
                    fontWeight: FontWeight.bold),
                onSubmitted: (_) => _join(),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _loading ? null : _join,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Join Game', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
