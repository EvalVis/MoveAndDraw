import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/google_auth_service.dart';
import '../services/guest_service.dart';
import '../services/user_service.dart';
import '../services/location_service.dart';
import '../services/drawing_controller.dart';
import '../services/ink_service.dart';
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
  final _locationService = LocationService();
  final _drawingController = DrawingController();
  final _inkService = InkService();
  int _ink = 0;
  String? _artistName;
  StreamSubscription<Position>? _positionSubscription;

  bool get _isGuest => _guestService.isGuest;

  @override
  void initState() {
    super.initState();
    _drawingController.addListener(_onDrawingChanged);
    _initializeLocation();
    _initializeInk();
    _fetchArtistName();
  }

  void _onDrawingChanged() {
    setState(() {});
  }

  Future<void> _initializeLocation() async {
    final position = await _locationService.getCurrentLocation();
    setState(() {
      _currentPosition = position;
      _isLoading = false;
    });

    if (position != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          ),
        ),
      );
    }

    _locationService.startTracking();
    _positionSubscription = _locationService.positionStream.listen((position) {
      setState(() => _currentPosition = position);
      if (_drawingController.isDrawing && !_drawingController.isPaused) {
        _drawingController.addPoint(
          LatLng(position.latitude, position.longitude),
        );
      }
    });
  }

  Future<void> _initializeInk() async {
    final ink = await _inkService.fetchInk(_isGuest);
    setState(() => _ink = ink);
    _inkService.startRefreshTimer(
      (ink) => setState(() => _ink = ink),
      _isGuest,
    );
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

  LatLng? _currentLatLng() {
    if (_currentPosition == null) return null;
    return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
  }

  void _showSaveDrawingDialog() {
    showDialog<SaveDrawingResult>(
      context: context,
      builder: (context) => SaveDrawingDialog(
        segments: _drawingController.toSegments(),
        isGuest: _isGuest,
      ),
    ).then((result) {
      if (result?.inkRemaining != null) {
        setState(() => _ink = result!.inkRemaining!);
      }
      _drawingController.handleSaveResult(
        saved: result?.saved ?? false,
        discarded: result?.discarded ?? false,
      );
    });
  }

  void _onStopDrawing() {
    _drawingController.stopDrawing();
    _showSaveDrawingDialog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MapAppBar(
        selectedColor: _drawingController.selectedColor,
        onColorChanged: _drawingController.changeColor,
        isDrawing: _drawingController.isDrawing,
        isPaused: _drawingController.isPaused,
        onStartDrawing: () => _drawingController.startDrawing(_currentLatLng()),
        onTogglePause: () => _drawingController.togglePause(_currentLatLng()),
        onStopDrawing: _onStopDrawing,
        ink: _ink,
        totalPoints: _drawingController.totalPoints,
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
              polylines: _drawingController.polylines,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
            ),
    );
  }

  @override
  void dispose() {
    _drawingController.removeListener(_onDrawingChanged);
    _drawingController.dispose();
    _positionSubscription?.cancel();
    _locationService.dispose();
    _inkService.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}
