import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'google_auth_service.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final _authService = GoogleAuthService();

  Future<String?> fetchArtistName() async {
    final token = await _authService.getIdToken();
    if (token == null) return null;

    final response = await http.post(
      Uri.parse('${dotenv.env['BACKEND_URL']}/user/login'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['artistName'];
    }
    return null;
  }

  Future<int?> fetchInk() async {
    final token = await _authService.getIdToken();
    if (token == null) return null;

    final response = await http.get(
      Uri.parse('${dotenv.env['BACKEND_URL']}/user/ink'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['ink'];
    }
    return null;
  }
}

