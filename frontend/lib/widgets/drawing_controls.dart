import 'package:flutter/material.dart';

class DrawingControls extends StatelessWidget {
  final bool isDrawing;
  final bool isPaused;
  final VoidCallback onStart;
  final VoidCallback onTogglePause;
  final VoidCallback onStop;

  const DrawingControls({
    super.key,
    required this.isDrawing,
    required this.isPaused,
    required this.onStart,
    required this.onTogglePause,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDrawing) {
      return IconButton(
        onPressed: onStart,
        icon: const Icon(Icons.play_arrow),
        tooltip: 'Start Drawing',
        style: IconButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onTogglePause,
          icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
          tooltip: isPaused ? 'Continue' : 'Pause',
          style: IconButton.styleFrom(
            backgroundColor: isPaused ? Colors.green : Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: onStop,
          icon: const Icon(Icons.stop),
          tooltip: 'Stop',
          style: IconButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

