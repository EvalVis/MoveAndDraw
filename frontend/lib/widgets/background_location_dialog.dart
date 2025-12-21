import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class BackgroundLocationDialog extends StatelessWidget {
  const BackgroundLocationDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Background Location Permission'),
      content: const Text(
        'To continue drawing while using other apps, Move & Draw needs "Allow all the time" location permission.\n\n'
        'This allows the app to track your location in the background so you can switch to other apps (like music players) while still creating your artwork.\n\n'
        'You can change this permission anytime in your device settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(context).pop(true);
            await openAppSettings();
          },
          child: const Text('Open Settings'),
        ),
      ],
    );
  }
}

