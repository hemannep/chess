import 'package:flutter/material.dart';

class DrawOfferDialog extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const DrawOfferDialog(
      {super.key, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Draw Offered'),
      content: const Text('Your opponent is offering a draw. Accept?'),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDecline();
            },
            child: const Text('Decline')),
        FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onAccept();
            },
            child: const Text('Accept Draw')),
      ],
    );
  }
}
