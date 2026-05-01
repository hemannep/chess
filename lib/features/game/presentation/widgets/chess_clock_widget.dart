import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';
import 'package:chess_master/app/theme.dart';

class ChessClockWidget extends StatefulWidget {
  final TimerState timerState;
  final bool isActive;
  final bool isCritical;

  const ChessClockWidget({
    super.key,
    required this.timerState,
    required this.isActive,
    required this.isCritical,
  });

  @override
  State<ChessClockWidget> createState() => _ChessClockWidgetState();
}

class _ChessClockWidgetState extends State<ChessClockWidget>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  late int _displayMs;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _displayMs = widget.timerState.displayMs;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _startTicker();
  }

  @override
  void didUpdateWidget(ChessClockWidget old) {
    super.didUpdateWidget(old);
    if (old.timerState.remainingMs != widget.timerState.remainingMs ||
        old.timerState.running != widget.timerState.running) {
      _displayMs = widget.timerState.displayMs;
    }
    if (old.isActive != widget.isActive) {
      _startTicker();
      if (widget.isActive) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
    if (!old.isCritical && widget.isCritical) {
      _pulseController.repeat(reverse: true);
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    if (widget.isActive && widget.timerState.running) {
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) setState(() => _displayMs = widget.timerState.displayMs);
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chessTheme;
    final color = _clockColor(theme);
    final bg = widget.isActive ? color.withOpacity(0.12) : Colors.transparent;
    final isTicking = widget.isActive && widget.timerState.running;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final scale = widget.isCritical && isTicking
            ? 1.0 + _pulseController.value * 0.04
            : 1.0;
        return Transform.scale(
          scale: scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isActive
                    ? color.withOpacity(0.4)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Text(
              _formatTime(_displayMs),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: widget.isCritical ? 20 : 18,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 1.2,
              ),
            ),
          ),
        );
      },
    );
  }

  Color _clockColor(ChessThemeExtension theme) {
    if (_displayMs < 10000) return theme.clockCritical;
    if (_displayMs < 30000) return theme.clockWarning;
    if (widget.isActive) return theme.clockActive;
    return Colors.grey;
  }

  String _formatTime(int ms) {
    if (ms <= 0) return '0:00';
    if (ms < 10000) {
      final s = ms ~/ 1000;
      final tenth = (ms % 1000) ~/ 100;
      return '0:${s.toString().padLeft(2, '0')}.$tenth';
    }
    final totalSeconds = (ms / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class MoveHistorySheet extends StatelessWidget {
  final List<MoveRecord> moves;
  const MoveHistorySheet({super.key, required this.moves});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text('Move History',
                style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            Expanded(
              child: moves.isEmpty
                  ? const Center(
                      child: Text('No moves yet',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: (moves.length / 2).ceil(),
                      itemBuilder: (_, index) {
                        final white = index * 2 < moves.length
                            ? moves[index * 2]
                            : null;
                        final black = index * 2 + 1 < moves.length
                            ? moves[index * 2 + 1]
                            : null;
                        return _MoveRow(
                            number: index + 1, white: white, black: black);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveRow extends StatelessWidget {
  final int number;
  final MoveRecord? white;
  final MoveRecord? black;
  const _MoveRow({required this.number, this.white, this.black});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('$number.',
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(child: _MoveCell(record: white)),
          Expanded(child: _MoveCell(record: black)),
        ],
      ),
    );
  }
}

class _MoveCell extends StatelessWidget {
  final MoveRecord? record;
  const _MoveCell({this.record});

  @override
  Widget build(BuildContext context) {
    if (record == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        record!.san,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
