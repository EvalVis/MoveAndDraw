import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/drawing.dart';
import '../models/comment.dart';
import 'google_auth_service.dart';
import 'guest_service.dart';

class DrawingsResult {
  final List<Drawing> drawings;
  final int page;
  final int totalPages;

  DrawingsResult({
    required this.drawings,
    required this.page,
    required this.totalPages,
  });
}

class CommentsResult {
  final List<Comment> comments;
  final int page;
  final int totalPages;

  CommentsResult({
    required this.comments,
    required this.page,
    required this.totalPages,
  });
}

class DrawingsService {
  final _authService = GoogleAuthService();
  final _guestService = GuestService();

  bool get isGuest => _guestService.isGuest;

  Future<DrawingsResult?> fetchDrawings({
    required SortOption sortOption,
    required String searchQuery,
    required int page,
    required bool myDrawingsOnly,
  }) async {
    if (isGuest) {
      return _fetchGuestDrawings(
        sortOption: sortOption,
        searchQuery: searchQuery,
      );
    }

    final token = await _authService.getIdToken();
    if (token == null) return null;

    final sortParam = sortOption.name;
    final searchParam = Uri.encodeComponent(searchQuery);
    final mineParam = myDrawingsOnly ? '&mine=true' : '';
    final response = await http.get(
      Uri.parse(
        '${dotenv.env['BACKEND_URL']}/drawings/view?sort=$sortParam&search=$searchParam&page=$page$mineParam',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> drawingsData = data['drawings'];
      return DrawingsResult(
        drawings: drawingsData.map((d) => Drawing.fromJson(d)).toList(),
        page: data['page'],
        totalPages: data['totalPages'],
      );
    }
    return null;
  }

  DrawingsResult _fetchGuestDrawings({
    required SortOption sortOption,
    required String searchQuery,
  }) {
    var guestDrawings = _guestService.drawings
        .map((d) => Drawing.fromGuestDrawing(d))
        .toList();

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      guestDrawings = guestDrawings
          .where((d) => d.title.toLowerCase().contains(query))
          .toList();
    }

    switch (sortOption) {
      case SortOption.newest:
        guestDrawings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.oldest:
        guestDrawings.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOption.popular:
      case SortOption.unpopular:
        break;
    }

    return DrawingsResult(drawings: guestDrawings, page: 1, totalPages: 1);
  }

  Future<void> toggleLike(int drawingId) async {
    final token = await _authService.getIdToken();
    if (token == null) return;

    await http.post(
      Uri.parse('${dotenv.env['BACKEND_URL']}/drawings/like/$drawingId'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<CommentsResult?> fetchComments({
    required int drawingId,
    required int page,
  }) async {
    final token = await _authService.getIdToken();
    if (token == null) return null;

    final response = await http.get(
      Uri.parse(
        '${dotenv.env['BACKEND_URL']}/drawings/comments/view?drawingId=$drawingId&page=$page',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> commentsData = data['comments'];
      return CommentsResult(
        comments: commentsData.map((c) => Comment.fromJson(c)).toList(),
        page: data['page'],
        totalPages: data['totalPages'],
      );
    }
    return null;
  }

  Future<void> sendComment({
    required int drawingId,
    required String content,
  }) async {
    final token = await _authService.getIdToken();
    if (token == null) return;

    await http.post(
      Uri.parse('${dotenv.env['BACKEND_URL']}/drawings/comments/save'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'drawingId': drawingId, 'content': content}),
    );
  }

  String? get currentUserName => _authService.currentUser?.displayName;
}
