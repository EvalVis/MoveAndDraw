import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/google_auth_service.dart';
import '../screens/login_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  final _authService = GoogleAuthService();
  final List<LatLng> _pathPoints = [];
  final Set<Polyline> _polylines = {};
  bool _isDrawing = false;
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _startLocationTracking();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoading = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoading = false);
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
    );

    setState(() {
      _currentPosition = position;
      _isLoading = false;
    });

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 15,
        ),
      ),
    );
  }

  void _startLocationTracking() {
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
      });

      if (_isDrawing) {
        final newPoint = LatLng(position.latitude, position.longitude);
        
        setState(() {
          _pathPoints.add(newPoint);
          
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('path'),
              points: _pathPoints,
              color: Colors.red,
              width: 5,
            ),
          );
        });
      }
    });
  }

  void _toggleDrawing() {
    setState(() {
      _isDrawing = !_isDrawing;
    });
  }

  Future<void> _handleSignOut() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: ElevatedButton.icon(
          onPressed: _toggleDrawing,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isDrawing ? Colors.red : Colors.green,
            foregroundColor: Colors.white,
          ),
          icon: Icon(_isDrawing ? Icons.stop : Icons.play_arrow),
          label: Text(_isDrawing ? 'Stop Drawing' : 'Start Drawing'),
        ),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundImage: user.photoUrl != null
                    ? NetworkImage(user.photoUrl!)
                    : null,
                child: user.photoUrl == null
                    ? Text(user.displayName?[0] ?? 'U')
                    : null,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleSignOut,
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition != null
                    ? LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      )
                    : const LatLng(0, 0),
                zoom: 15,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapType: MapType.normal,
              polylines: _polylines,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
            ),
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}



