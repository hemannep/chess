import 'package:flutter/material.dart';

class ResignDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  const ResignDialog({super.key, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Resign?'),
      content: const Text('Are you sure you want to resign this game?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Playing')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: onConfirm,
          child: const Text('Resign'),
        ),
      ],
    );
  }
}
