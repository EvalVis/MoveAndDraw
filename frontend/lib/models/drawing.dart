import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/guest_service.dart';

enum SortOption { popular, unpopular, newest, oldest }

class DrawingSegment {
  final List<LatLng> points;
  final Color color;

  DrawingSegment({required this.points, required this.color});

  factory DrawingSegment.fromJson(Map<String, dynamic> json) {
    final coords = json['points'] as List;
    final points = coords
        .map<LatLng>((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
        .toList();
    final colorHex = json['color'] as String;
    final colorValue = int.parse(colorHex.substring(1), radix: 16) + 0xFF000000;
    return DrawingSegment(points: points, color: Color(colorValue));
  }
}

class Drawing {
  final int id;
  final String artistName;
  final bool isOwner;
  final String title;
  final List<DrawingSegment> segments;
  final bool commentsEnabled;
  final bool isPublic;
  int likeCount;
  bool isLiked;
  final DateTime createdAt;
  final bool isGuestDrawing;

  Drawing({
    required this.id,
    required this.artistName,
    required this.isOwner,
    required this.title,
    required this.segments,
    required this.commentsEnabled,
    required this.isPublic,
    required this.likeCount,
    required this.isLiked,
    required this.createdAt,
    this.isGuestDrawing = false,
  });

  factory Drawing.fromJson(Map<String, dynamic> json) {
    final segmentsJson = json['segments'] as List;
    final segments = segmentsJson
        .map<DrawingSegment>((s) => DrawingSegment.fromJson(s))
        .toList();

    return Drawing(
      id: json['id'],
      artistName: json['artistName'] ?? '',
      isOwner: json['isOwner'] ?? false,
      title: json['title'],
      segments: segments,
      commentsEnabled: json['commentsEnabled'] ?? true,
      isPublic: json['isPublic'] ?? false,
      likeCount: json['likeCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  factory Drawing.fromGuestDrawing(GuestDrawing gd) {
    final segments = gd.segments
        .map<DrawingSegment>((s) => DrawingSegment.fromJson(s))
        .toList();

    return Drawing(
      id: int.tryParse(gd.id) ?? 0,
      artistName: 'Guest',
      isOwner: true,
      title: gd.title,
      segments: segments,
      commentsEnabled: false,
      isPublic: false,
      likeCount: 0,
      isLiked: false,
      createdAt: gd.createdAt,
      isGuestDrawing: true,
    );
  }

  LatLngBounds getBounds() {
    final allPoints = segments.expand((s) => s.points).toList();
    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (final point in allPoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
