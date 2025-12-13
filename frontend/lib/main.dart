import 'package:flutter/material.dart';
import 'services/google_auth_service.dart';
import 'services/guest_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = GoogleAuthService();
  final guestService = GuestService();
  await authService.initialize();
  await guestService.initialize();
  runApp(MainApp(authService: authService, guestService: guestService));
}

class MainApp extends StatelessWidget {
  final GoogleAuthService authService;
  final GuestService guestService;

  const MainApp({
    super.key,
    required this.authService,
    required this.guestService,
  });

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = authService.isSignedIn || guestService.isGuest;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
