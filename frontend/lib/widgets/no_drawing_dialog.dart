import 'package:flutter/material.dart';

class NoDrawingDialog extends StatelessWidget {
  const NoDrawingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('No Drawing'),
      content: const Text('There is no drawing to save.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
