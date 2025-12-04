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

class Drawing {
  final int id;
  final String title;
  final List<LatLng> points;
  final DateTime createdAt;

  Drawing({
    required this.id,
    required this.title,
    required this.points,
    required this.createdAt,
  });

  factory Drawing.fromJson(Map<String, dynamic> json) {
    final geoJson = json['drawing'];
    final coordinates = geoJson['coordinates'][0][0] as List;
    final allPoints = coordinates
        .map<LatLng>((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
        .toList();
    final points = allPoints.length > 1 ? allPoints.sublist(0, allPoints.length - 1) : allPoints;

    return Drawing(
      id: json['id'],
      title: json['title'],
      points: points,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  LatLngBounds getBounds() {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
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

class DrawingCard extends StatelessWidget {
  final Drawing drawing;

  const DrawingCard({super.key, required this.drawing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 200,
            child: DrawingMap(drawing: drawing),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drawing.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${drawing.createdAt.day}/${drawing.createdAt.month}/${drawing.createdAt.year}',
                  style: Theme.of(context).textTheme.bodySmall,
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

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 15),
      polylines: {
        Polyline(
          polylineId: PolylineId('drawing_${widget.drawing.id}'),
          points: widget.drawing.points,
          color: Colors.red,
          width: 3,
        ),
      },
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
      zoomGesturesEnabled: false,
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

