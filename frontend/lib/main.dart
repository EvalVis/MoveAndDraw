import 'package:flutter/material.dart';
import 'services/google_auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = GoogleAuthService();
  await authService.initialize();
  runApp(MainApp(authService: authService));
}

class MainApp extends StatelessWidget {
  final GoogleAuthService authService;

  const MainApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: authService.isSignedIn ? const MapScreen() : const LoginScreen(),
    );
  }
}
