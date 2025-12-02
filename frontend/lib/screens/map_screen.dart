import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
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
  List<LatLng> _currentPathPoints = [];
  final Set<Polyline> _polylines = {};
  bool _isDrawing = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  int _polylineIdCounter = 0;
  Color _selectedColor = Colors.red;
  Color _currentSegmentColor = Colors.red;

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
    _positionStreamSubscription =
        Geolocator.getPositionStream(
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
              _currentPathPoints.add(newPoint);

              _polylines.removeWhere((p) => p.polylineId.value == 'current');
              _polylines.add(
                Polyline(
                  polylineId: const PolylineId('current'),
                  points: List.from(_currentPathPoints),
                  color: _currentSegmentColor,
                  width: 5,
                ),
              );
            });
          }
        });
  }

  void _finalizeCurrentSegment() {
    if (_currentPathPoints.length >= 2) {
      _polylines.removeWhere((p) => p.polylineId.value == 'current');
      _polylines.add(
        Polyline(
          polylineId: PolylineId('path_$_polylineIdCounter'),
          points: List.from(_currentPathPoints),
          color: _currentSegmentColor,
          width: 5,
        ),
      );
      _polylineIdCounter++;

      final lastPoint = _currentPathPoints.last;
      _currentPathPoints = [lastPoint];
      _currentSegmentColor = _selectedColor;
    }
  }

  void _toggleDrawing() {
    if (_isDrawing) {
      _showSaveDrawingDialog();
    } else {
      setState(() {
        _isDrawing = true;
        _currentPathPoints = [];
        _currentSegmentColor = _selectedColor;
        if (_currentPosition != null) {
          _currentPathPoints.add(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          );
        }
      });
    }
  }

  void _showSaveDrawingDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Drawing'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Drawing Name',
              hintText: 'Enter a name for your drawing',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Submit'),
            ),
          ],
        );
      },
    ).then((_) {
      setState(() {
        _isDrawing = false;
        if (_currentPathPoints.isNotEmpty) {
          _polylines.removeWhere((p) => p.polylineId.value == 'current');
          _polylines.add(
            Polyline(
              polylineId: PolylineId('path_$_polylineIdCounter'),
              points: List.from(_currentPathPoints),
              color: _currentSegmentColor,
              width: 5,
            ),
          );
          _polylineIdCounter++;
          _currentPathPoints = [];
        }
      });
    });
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _selectedColor,
              onColorChanged: (Color color) {
                setState(() {
                  _selectedColor = color;
                  if (_isDrawing && _currentPathPoints.length >= 2) {
                    _finalizeCurrentSegment();
                  } else if (_isDrawing) {
                    _currentSegmentColor = color;
                  }
                });
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Done'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _selectedColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              onPressed: _showColorPicker,
              tooltip: 'Pick color',
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _toggleDrawing,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDrawing ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
              icon: Icon(_isDrawing ? Icons.stop : Icons.play_arrow),
              label: Text(_isDrawing ? 'Stop Drawing' : 'Start Drawing'),
            ),
          ],
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
