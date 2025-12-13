import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../services/google_auth_service.dart';
import 'login_screen.dart';
import 'change_artist_name_dialog.dart';

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
  bool _isPaused = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  int _polylineIdCounter = 0;
  Color _selectedColor = Colors.red;
  Color _currentSegmentColor = Colors.red;
  int _ink = 0;
  Timer? _inkRefreshTimer;
  String? _artistName;

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
    final token = await _authService.getIdToken();
    if (token == null) return;

    final response = await http.post(
      Uri.parse('${dotenv.env['BACKEND_URL']}/user/login'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() => _artistName = data['artistName']);
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
    final token = await _authService.getIdToken();
    if (token == null) return;

    final response = await http.get(
      Uri.parse('${dotenv.env['BACKEND_URL']}/user/ink'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _ink = data['ink'];
      });
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
            distanceFilter: 5,
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
    _showSaveDrawingDialog();
  }

  void _showSaveDrawingDialog() {
    final TextEditingController nameController = TextEditingController();
    bool commentsEnabled = true;
    bool isPublic = true;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Save Drawing'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Drawing Name',
                      hintText: 'Enter a name for your drawing',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Public'),
                    subtitle: const Text('Visible to everyone'),
                    value: isPublic,
                    onChanged: (value) {
                      setDialogState(() {
                        isPublic = value ?? true;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('Allow comments'),
                    value: commentsEnabled,
                    onChanged: (value) {
                      setDialogState(() {
                        commentsEnabled = value ?? true;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final token = await _authService.getIdToken();
                    if (token == null) return;

                    final segments = <Map<String, dynamic>>[];
                    for (final polyline in _polylines) {
                      final points = polyline.points
                          .map((p) => [p.longitude, p.latitude])
                          .toList();
                      final colorHex =
                          '#${polyline.color.value.toRadixString(16).substring(2).toUpperCase()}';
                      segments.add({'points': points, 'color': colorHex});
                    }
                    final response = await http.post(
                      Uri.parse('${dotenv.env['BACKEND_URL']}/drawings/save'),
                      headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer $token',
                      },
                      body: jsonEncode({
                        'title': nameController.text,
                        'segments': segments,
                        'commentsEnabled': commentsEnabled,
                        'isPublic': isPublic,
                      }),
                    );
                    if (response.statusCode == 201) {
                      final data = jsonDecode(response.body);
                      setState(() {
                        _ink = data['inkRemaining'];
                      });
                      if (context.mounted) Navigator.of(context).pop(true);
                    } else if (response.statusCode == 400) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Not enough ink!')),
                        );
                      }
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    ).then((saved) {
      setState(() {
        _isDrawing = false;
        _isPaused = false;
        if (saved == true) {
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
            if (!_isDrawing)
              ElevatedButton.icon(
                onPressed: _startDrawing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Drawing'),
              )
            else ...[
              ElevatedButton.icon(
                onPressed: _togglePause,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPaused ? Colors.green : Colors.orange,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                label: Text(_isPaused ? 'Continue' : 'Pause'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _stopDrawing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            ],
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                const Icon(Icons.water_drop, size: 20),
                const SizedBox(width: 4),
                Text(
                  _isDrawing ? '${_ink - _getTotalPoints()}' : '$_ink',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (user != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: _showChangeArtistNameDialog,
                child: CircleAvatar(
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? Text(user.displayName?[0] ?? 'U')
                      : null,
                ),
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
    _inkRefreshTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
