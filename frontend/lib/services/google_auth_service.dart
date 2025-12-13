import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  GoogleSignInAccount? _currentUser;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<void> initialize() async {
    await dotenv.load();
    final serverClientId = dotenv.env['GOOGLE_OAUTH2_SERVER_CLIENT_ID'];
    await _googleSignIn.initialize(serverClientId: serverClientId);
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.authenticate();
      _currentUser = account;
      return account;
    } catch (e) {
      return null;
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      final account = await _googleSignIn.attemptLightweightAuthentication();
      _currentUser = account;
      return account;
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  Future<String?> getIdToken() async {
    if (_currentUser == null) {
      await signInSilently();
    }
    if (_currentUser == null) return null;
    final authentication = await _currentUser!.authentication;
    return authentication.idToken;
  }
}
