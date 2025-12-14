import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/google_auth_service.dart';
import '../services/guest_service.dart';
import '../services/user_service.dart';
import '../widgets/map_app_bar.dart';
import 'change_artist_name_dialog.dart';
import 'save_drawing_dialog.dart';

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
  final _guestService = GuestService();
  final _userService = UserService();
  List<LatLng> _currentPathPoints = [];
  final Set<Polyline> _polylines = {};
  bool _isDrawing = false;
  bool _isPaused = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  int _polylineIdCounter = 0;
  Color _selectedColor = Colors.red;
  Color _currentSegmentColor = Colors.red;
  int _ink = 0;
  Timer? _inkRefreshTimer;
  String? _artistName;

  bool get _isGuest => _guestService.isGuest;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _startLocationTracking();
    _fetchInk();
    _startInkRefreshTimer();
    _fetchArtistName();
  }

  Future<void> _fetchArtistName() async {
    if (_isGuest) {
      setState(() => _artistName = 'Guest');
      return;
    }
    final artistName = await _userService.fetchArtistName();
    if (artistName != null) {
      setState(() => _artistName = artistName);
    }
  }

  Future<void> _showChangeArtistNameDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => ChangeArtistNameDialog(currentName: _artistName),
    );

    if (result != null) {
      setState(() => _artistName = result);
    }
  }

  void _startInkRefreshTimer() {
    _inkRefreshTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _fetchInk();
    });
  }

  Future<void> _fetchInk() async {
    if (_isGuest) {
      final ink = await _guestService.refreshInk();
      setState(() => _ink = ink);
      return;
    }
    final ink = await _userService.fetchInk();
    if (ink != null) {
      setState(() => _ink = ink);
    }
  }

  int _getTotalPoints() {
    int total = 0;
    for (final polyline in _polylines) {
      total += polyline.points.length;
    }
    return total;
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
            distanceFilter: 20,
          ),
        ).listen((Position position) {
          setState(() {
            _currentPosition = position;
          });

          if (_isDrawing && !_isPaused) {
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

  void _startDrawing() {
    setState(() {
      _isDrawing = true;
      _isPaused = false;
      _currentPathPoints = [];
      _currentSegmentColor = _selectedColor;
      if (_currentPosition != null) {
        _currentPathPoints.add(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        );
      }
    });
  }

  void _togglePause() {
    setState(() {
      if (_isPaused) {
        _currentPathPoints = [];
        _currentSegmentColor = _selectedColor;
        if (_currentPosition != null) {
          _currentPathPoints.add(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          );
        }
      } else {
        _finalizeCurrentSegment();
      }
      _isPaused = !_isPaused;
    });
  }

  void _stopDrawing() {
    if (!_isPaused) {
      _finalizeCurrentSegment();
      setState(() => _isPaused = true);
    }
    _showSaveDrawingDialog();
  }

  void _showSaveDrawingDialog() {
    final segments = <Map<String, dynamic>>[];
    for (final polyline in _polylines) {
      final points = polyline.points
          .map((p) => [p.longitude, p.latitude])
          .toList();
      final colorHex =
          '#${polyline.color.value.toRadixString(16).substring(2).toUpperCase()}';
      segments.add({'points': points, 'color': colorHex});
    }

    showDialog<SaveDrawingResult>(
      context: context,
      builder: (context) =>
          SaveDrawingDialog(segments: segments, isGuest: _isGuest),
    ).then((result) {
      if (result?.inkRemaining != null) {
        setState(() => _ink = result!.inkRemaining!);
      }
      _handleSaveDialogClose(result);
    });
  }

  void _handleSaveDialogClose(SaveDrawingResult? result) {
    setState(() {
      _isDrawing = false;
      _isPaused = false;
      if (result != null && (result.saved || result.discarded)) {
        _polylines.clear();
        _polylineIdCounter = 0;
      } else if (_currentPathPoints.isNotEmpty) {
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
      }
      _currentPathPoints = [];
    });
  }

  void _onColorChanged(Color color) {
    setState(() {
      _selectedColor = color;
      if (_isDrawing && _currentPathPoints.length >= 2) {
        _finalizeCurrentSegment();
      } else if (_isDrawing) {
        _currentSegmentColor = color;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MapAppBar(
        selectedColor: _selectedColor,
        onColorChanged: _onColorChanged,
        isDrawing: _isDrawing,
        isPaused: _isPaused,
        onStartDrawing: _startDrawing,
        onTogglePause: _togglePause,
        onStopDrawing: _stopDrawing,
        ink: _ink,
        totalPoints: _getTotalPoints(),
        isGuest: _isGuest,
        user: _authService.currentUser,
        onUserAvatarTap: _showChangeArtistNameDialog,
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
    _inkRefreshTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
