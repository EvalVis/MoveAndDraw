import 'package:flutter/material.dart';
import '../services/google_auth_service.dart';
import '../services/guest_service.dart';
import '../screens/login_screen.dart';

class SignOutButton extends StatelessWidget {
  final bool isGuest;

  const SignOutButton({super.key, required this.isGuest});

  Future<void> _handleSignOut(BuildContext context) async {
    if (isGuest) {
      await GuestService().exitGuestMode();
    } else {
      await GoogleAuthService().signOut();
    }
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout),
      onPressed: () => _handleSignOut(context),
      tooltip: 'Sign out',
    );
  }
}

