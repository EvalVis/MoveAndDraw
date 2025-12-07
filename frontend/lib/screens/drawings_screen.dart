import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../services/google_auth_service.dart';

class DrawingsScreen extends StatefulWidget {
  const DrawingsScreen({super.key});

  @override
  State<DrawingsScreen> createState() => _DrawingsScreenState();
}

class _DrawingsScreenState extends State<DrawingsScreen> {
  final _authService = GoogleAuthService();
  List<Drawing> _drawings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDrawings();
  }

  Future<void> _fetchDrawings() async {
    final token = await _authService.getIdToken();
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    final response = await http.get(
      Uri.parse('${dotenv.env['BACKEND_URL']}/drawings/view'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      setState(() {
        _drawings = data.map((d) => Drawing.fromJson(d)).toList();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Drawings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _drawings.isEmpty
          ? const Center(child: Text('No drawings yet'))
          : RefreshIndicator(
              onRefresh: _fetchDrawings,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _drawings.length,
                itemBuilder: (context, index) {
                  return DrawingCard(drawing: _drawings[index]);
                },
              ),
            ),
    );
  }
}

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
  final String title;
  final List<DrawingSegment> segments;
  int likeCount;
  bool isLiked;
  final DateTime createdAt;

  Drawing({
    required this.id,
    required this.title,
    required this.segments,
    required this.likeCount,
    required this.isLiked,
    required this.createdAt,
  });

  factory Drawing.fromJson(Map<String, dynamic> json) {
    final segmentsJson = json['segments'] as List;
    final segments = segmentsJson
        .map<DrawingSegment>((s) => DrawingSegment.fromJson(s))
        .toList();

    return Drawing(
      id: json['id'],
      title: json['title'],
      segments: segments,
      likeCount: json['likeCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
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

class DrawingCard extends StatefulWidget {
  final Drawing drawing;

  const DrawingCard({super.key, required this.drawing});

  @override
  State<DrawingCard> createState() => _DrawingCardState();
}

class _DrawingCardState extends State<DrawingCard> {
  final _authService = GoogleAuthService();
  bool _isLiking = false;

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    setState(() => _isLiking = true);

    final token = await _authService.getIdToken();
    if (token == null) {
      setState(() => _isLiking = false);
      return;
    }

    final response = await http.post(
      Uri.parse('${dotenv.env['BACKEND_URL']}/drawings/like/${widget.drawing.id}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        widget.drawing.likeCount = data['likeCount'];
        widget.drawing.isLiked = data['isLiked'];
      });
    }
    setState(() => _isLiking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 200, child: DrawingMap(drawing: widget.drawing)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.drawing.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${widget.drawing.createdAt.day}/${widget.drawing.createdAt.month}/${widget.drawing.createdAt.year}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _isLiking ? null : _toggleLike,
                          icon: Icon(
                            widget.drawing.isLiked ? Icons.favorite : Icons.favorite_border,
                          ),
                          color: Colors.red,
                        ),
                        Text(
                          '${widget.drawing.likeCount}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DrawingMap extends StatefulWidget {
  final Drawing drawing;

  const DrawingMap({super.key, required this.drawing});

  @override
  State<DrawingMap> createState() => _DrawingMapState();
}

class _DrawingMapState extends State<DrawingMap> {
  GoogleMapController? _controller;

  @override
  Widget build(BuildContext context) {
    final bounds = widget.drawing.getBounds();
    final center = LatLng(
      (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
      (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
    );

    final polylines = <Polyline>{};
    for (var i = 0; i < widget.drawing.segments.length; i++) {
      final segment = widget.drawing.segments[i];
      polylines.add(
        Polyline(
          polylineId: PolylineId('segment_${widget.drawing.id}_$i'),
          points: segment.points,
          color: segment.color,
          width: 3,
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 15),
      polylines: polylines,
      onMapCreated: (controller) {
        _controller = controller;
        Future.delayed(const Duration(milliseconds: 100), () {
          _controller?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 40));
        });
      },
      zoomControlsEnabled: false,
      scrollGesturesEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      zoomGesturesEnabled: true,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
