import 'package:flutter/material.dart';
import 'package:chess_master/features/game/domain/entities/game_entity.dart';

class PromotionDialog extends StatelessWidget {
  final PlayerColor color;
  final void Function(String piece) onSelect;
  const PromotionDialog({super.key, required this.color, required this.onSelect});

  static const _pieces = ['q', 'r', 'b', 'n'];
  static const _labels = ['Queen', 'Rook', 'Bishop', 'Knight'];
  static const _whiteIcons = ['♕', '♖', '♗', '♘'];
  static const _blackIcons = ['♛', '♜', '♝', '♞'];

  @override
  Widget build(BuildContext context) {
    final icons = color == PlayerColor.white ? _whiteIcons : _blackIcons;
    return AlertDialog(
      title: const Text('Promote Pawn', textAlign: TextAlign.center),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (i) {
          return InkWell(
            onTap: () {
              Navigator.pop(context);
              onSelect(_pieces[i]);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(icons[i], style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 4),
                Text(_labels[i], style: const TextStyle(fontSize: 10)),
              ]),
            ),
          );
        }),
      ),
    );
  }
}
