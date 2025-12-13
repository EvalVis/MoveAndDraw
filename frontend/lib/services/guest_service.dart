import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class GuestDrawing {
  final String id;
  final String title;
  final List<Map<String, dynamic>> segments;
  final DateTime createdAt;

  GuestDrawing({
    required this.id,
    required this.title,
    required this.segments,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'segments': segments,
    'createdAt': createdAt.toIso8601String(),
  };

  factory GuestDrawing.fromJson(Map<String, dynamic> json) => GuestDrawing(
    id: json['id'],
    title: json['title'],
    segments: List<Map<String, dynamic>>.from(json['segments']),
    createdAt: DateTime.parse(json['createdAt']),
  );
}

class GuestService {
  static final GuestService _instance = GuestService._internal();
  factory GuestService() => _instance;
  GuestService._internal();

  static const _isGuestKey = 'guest_mode';
  static const _inkKey = 'guest_ink';
  static const _lastInkRefreshKey = 'guest_last_ink_refresh';
  static const _drawingsKey = 'guest_drawings';
  static const _initialInk = 1000;
  static const _inkPerHour = 100;

  bool _isGuest = false;
  int _ink = _initialInk;
  DateTime? _lastInkRefresh;
  List<GuestDrawing> _drawings = [];

  bool get isGuest => _isGuest;
  int get ink => _ink;
  List<GuestDrawing> get drawings => List.unmodifiable(_drawings);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isGuestKey);
    _isGuest = false;
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _ink = prefs.getInt(_inkKey) ?? _initialInk;

    final lastRefreshStr = prefs.getString(_lastInkRefreshKey);
    if (lastRefreshStr != null) {
      _lastInkRefresh = DateTime.parse(lastRefreshStr);
      _applyInkRefresh();
    } else {
      _lastInkRefresh = DateTime.now();
      await _saveLastInkRefresh();
    }

    final drawingsJson = prefs.getString(_drawingsKey);
    if (drawingsJson != null) {
      final List<dynamic> list = jsonDecode(drawingsJson);
      _drawings = list.map((d) => GuestDrawing.fromJson(d)).toList();
    }
  }

  void _applyInkRefresh() {
    if (_lastInkRefresh == null) return;
    final now = DateTime.now();
    final hoursPassed = now.difference(_lastInkRefresh!).inHours;
    if (hoursPassed > 0) {
      _ink += hoursPassed * _inkPerHour;
      _lastInkRefresh = _lastInkRefresh!.add(Duration(hours: hoursPassed));
      _saveInk();
      _saveLastInkRefresh();
    }
  }

  Future<void> enterGuestMode() async {
    _isGuest = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isGuestKey, true);

    final hasExistingData = prefs.containsKey(_inkKey);
    if (hasExistingData) {
      await _loadData();
    } else {
      _ink = _initialInk;
      _lastInkRefresh = DateTime.now();
      _drawings = [];
      await _saveInk();
      await _saveLastInkRefresh();
      await _saveDrawings();
    }
  }

  Future<void> exitGuestMode() async {
    _isGuest = false;
    _ink = _initialInk;
    _lastInkRefresh = null;
    _drawings = [];

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isGuestKey);
  }

  Future<void> _saveInk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_inkKey, _ink);
  }

  Future<void> _saveLastInkRefresh() async {
    if (_lastInkRefresh == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastInkRefreshKey,
      _lastInkRefresh!.toIso8601String(),
    );
  }

  Future<void> _saveDrawings() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_drawings.map((d) => d.toJson()).toList());
    await prefs.setString(_drawingsKey, json);
  }

  Future<int> refreshInk() async {
    _applyInkRefresh();
    return _ink;
  }

  Future<bool> saveDrawing({
    required String title,
    required List<Map<String, dynamic>> segments,
  }) async {
    final totalPoints = segments.fold<int>(
      0,
      (sum, seg) => sum + (seg['points'] as List).length,
    );

    if (totalPoints > _ink) return false;

    _ink -= totalPoints;
    await _saveInk();

    final drawing = GuestDrawing(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      segments: segments,
      createdAt: DateTime.now(),
    );
    _drawings.insert(0, drawing);
    await _saveDrawings();

    return true;
  }

  Future<void> deleteDrawing(String id) async {
    _drawings.removeWhere((d) => d.id == id);
    await _saveDrawings();
  }
}
