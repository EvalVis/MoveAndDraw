import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/drawing.dart';

class DrawingFullscreen extends StatefulWidget {
  final Drawing drawing;

  const DrawingFullscreen({super.key, required this.drawing});

  @override
  State<DrawingFullscreen> createState() => _DrawingFullscreenState();
}

class _DrawingFullscreenState extends State<DrawingFullscreen> {
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
          width: segment.width,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.drawing.title),
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        foregroundColor: Colors.white,
      ),
      extendBodyBehindAppBar: true,
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: center, zoom: 15),
        polylines: polylines,
        onMapCreated: (controller) {
          _controller = controller;
          Future.delayed(const Duration(milliseconds: 100), () {
            _controller?.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 50),
            );
          });
        },
        zoomControlsEnabled: true,
        scrollGesturesEnabled: true,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
        zoomGesturesEnabled: true,
        myLocationButtonEnabled: false,
        mapToolbarEnabled: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
