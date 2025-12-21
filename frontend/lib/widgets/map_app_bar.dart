import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'brush_size_picker.dart';
import 'color_picker_button.dart';
import 'drawing_controls.dart';
import 'sign_out_button.dart';
import 'help_dialog.dart';

class MapAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorChanged;
  final int selectedBrushSize;
  final ValueChanged<int> onBrushSizeChanged;
  final bool isDrawing;
  final bool isPaused;
  final VoidCallback onStartDrawing;
  final VoidCallback onTogglePause;
  final VoidCallback onStopDrawing;
  final int ink;
  final int totalPoints;
  final bool isGuest;
  final GoogleSignInAccount? user;
  final VoidCallback? onUserAvatarTap;

  const MapAppBar({
    super.key,
    required this.selectedColor,
    required this.onColorChanged,
    required this.selectedBrushSize,
    required this.onBrushSizeChanged,
    required this.isDrawing,
    required this.isPaused,
    required this.onStartDrawing,
    required this.onTogglePause,
    required this.onStopDrawing,
    required this.ink,
    required this.totalPoints,
    required this.isGuest,
    required this.user,
    required this.onUserAvatarTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 0,
      toolbarHeight: kToolbarHeight,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColorPickerButton(
            selectedColor: selectedColor,
            onColorChanged: onColorChanged,
          ),
          BrushSizePicker(
            selectedSize: selectedBrushSize,
            onSizeChanged: onBrushSizeChanged,
          ),
          const SizedBox(width: 4),
          DrawingControls(
            isDrawing: isDrawing,
            isPaused: isPaused,
            onStart: onStartDrawing,
            onTogglePause: onTogglePause,
            onStop: onStopDrawing,
          ),
        ],
      ),
      actions: [
        _InkDisplay(ink: ink, totalPoints: totalPoints, isDrawing: isDrawing),
        IconButton(
          icon: const Icon(Icons.help_outline, size: 20),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const HelpDialog(),
            );
          },
          tooltip: 'Help',
        ),
        _UserAvatar(isGuest: isGuest, user: user, onTap: onUserAvatarTap),
        SignOutButton(isGuest: isGuest),
      ],
    );
  }
}

class _InkDisplay extends StatelessWidget {
  final int ink;
  final int totalPoints;
  final bool isDrawing;

  const _InkDisplay({
    required this.ink,
    required this.totalPoints,
    required this.isDrawing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.water_drop, size: 14),
          const SizedBox(width: 2),
          Text(
            isDrawing ? '${ink - totalPoints}' : '$ink',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final bool isGuest;
  final GoogleSignInAccount? user;
  final VoidCallback? onTap;

  const _UserAvatar({
    required this.isGuest,
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isGuest) {
      return const Padding(
        padding: EdgeInsets.all(3.0),
        child: CircleAvatar(child: Icon(Icons.person_outline)),
      );
    }

    if (user == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: GestureDetector(
        onTap: onTap,
        child: CircleAvatar(
          backgroundImage: user!.photoUrl != null
              ? NetworkImage(user!.photoUrl!)
              : null,
          child: user!.photoUrl == null
              ? Text(user!.displayName?[0] ?? 'U')
              : null,
        ),
      ),
    );
  }
}
