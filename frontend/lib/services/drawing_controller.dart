import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DrawingController extends ChangeNotifier {
  final Set<Polyline> _polylines = {};
  List<LatLng> _currentPathPoints = [];
  bool _isDrawing = false;
  bool _isPaused = false;
  Color _selectedColor = Colors.red;
  Color _currentSegmentColor = Colors.red;
  int _polylineIdCounter = 0;

  Set<Polyline> get polylines => _polylines;
  bool get isDrawing => _isDrawing;
  bool get isPaused => _isPaused;
  Color get selectedColor => _selectedColor;

  int get totalPoints {
    int total = 0;
    for (final polyline in _polylines) {
      total += polyline.points.length;
    }
    return total;
  }

  void startDrawing(LatLng? currentPosition) {
    _isDrawing = true;
    _isPaused = false;
    _currentPathPoints = [];
    _currentSegmentColor = _selectedColor;
    if (currentPosition != null) {
      _currentPathPoints.add(currentPosition);
    }
    notifyListeners();
  }

  void togglePause(LatLng? currentPosition) {
    if (_isPaused) {
      _currentPathPoints = [];
      _currentSegmentColor = _selectedColor;
      if (currentPosition != null) {
        _currentPathPoints.add(currentPosition);
      }
    } else {
      _finalizeCurrentSegment();
    }
    _isPaused = !_isPaused;
    notifyListeners();
  }

  void stopDrawing() {
    if (!_isPaused) {
      _finalizeCurrentSegment();
      _isPaused = true;
    }
    notifyListeners();
  }

  void addPoint(LatLng point) {
    if (!_isDrawing || _isPaused) return;

    _currentPathPoints.add(point);
    _polylines.removeWhere((p) => p.polylineId.value == 'current');
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('current'),
        points: List.from(_currentPathPoints),
        color: _currentSegmentColor,
        width: 5,
      ),
    );
    notifyListeners();
  }

  void changeColor(Color color) {
    _selectedColor = color;
    if (_isDrawing && _currentPathPoints.length >= 2) {
      _finalizeCurrentSegment();
    } else if (_isDrawing) {
      _currentSegmentColor = color;
    }
    notifyListeners();
  }

  void handleSaveResult({required bool saved, required bool discarded}) {
    _isDrawing = false;
    _isPaused = false;
    if (saved || discarded) {
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
    notifyListeners();
  }

  List<Map<String, dynamic>> toSegments() {
    final segments = <Map<String, dynamic>>[];
    for (final polyline in _polylines) {
      final points = polyline.points
          .map((p) => [p.longitude, p.latitude])
          .toList();
      final colorHex =
          '#${polyline.color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
      segments.add({'points': points, 'color': colorHex});
    }
    return segments;
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
}
