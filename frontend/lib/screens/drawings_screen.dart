import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../services/google_auth_service.dart';
import '../services/guest_service.dart';

class DrawingsScreen extends StatefulWidget {
  const DrawingsScreen({super.key});

  @override
  State<DrawingsScreen> createState() => _DrawingsScreenState();
}

enum SortOption { popular, unpopular, newest, oldest }

class _DrawingsScreenState extends State<DrawingsScreen> {
  final _authService = GoogleAuthService();
  final _guestService = GuestService();
  final _searchController = TextEditingController();
  List<Drawing> _drawings = [];
  bool _isLoading = true;
  SortOption _sortOption = SortOption.newest;
  String _searchQuery = '';
  int _currentPage = 1;
  int _totalPages = 1;
  bool _myDrawingsOnly = false;

  bool get _isGuest => _guestService.isGuest;

  @override
  void initState() {
    super.initState();
    _fetchDrawings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchDrawings() async {
    if (_isGuest) {
      _fetchGuestDrawings();
      return;
    }

    final token = await _authService.getIdToken();
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    final sortParam = _sortOption.name;
    final searchParam = Uri.encodeComponent(_searchQuery);
    final mineParam = _myDrawingsOnly ? '&mine=true' : '';
    final response = await http.get(
      Uri.parse(
        '${dotenv.env['BACKEND_URL']}/drawings/view?sort=$sortParam&search=$searchParam&page=$_currentPage$mineParam',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> drawingsData = data['drawings'];
      setState(() {
        _drawings = drawingsData.map((d) => Drawing.fromJson(d)).toList();
        _currentPage = data['page'];
        _totalPages = data['totalPages'];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _fetchGuestDrawings() {
    var guestDrawings = _guestService.drawings
        .map((d) => Drawing.fromGuestDrawing(d))
        .toList();

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      guestDrawings = guestDrawings
          .where((d) => d.title.toLowerCase().contains(query))
          .toList();
    }

    switch (_sortOption) {
      case SortOption.newest:
        guestDrawings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.oldest:
        guestDrawings.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOption.popular:
      case SortOption.unpopular:
        break;
    }

    setState(() {
      _drawings = guestDrawings;
      _currentPage = 1;
      _totalPages = 1;
      _isLoading = false;
    });
  }

  void _onSortChanged(SortOption? option) {
    if (option == null || option == _sortOption) return;
    setState(() {
      _sortOption = option;
      _currentPage = 1;
      _isLoading = true;
    });
    _fetchDrawings();
  }

  void _onSearchSubmitted(String value) {
    setState(() {
      _searchQuery = value.trim();
      _currentPage = 1;
      _isLoading = true;
    });
    _fetchDrawings();
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages || page == _currentPage) return;
    setState(() {
      _currentPage = page;
      _isLoading = true;
    });
    _fetchDrawings();
  }

  String _sortLabel(SortOption option) {
    switch (option) {
      case SortOption.popular:
        return 'Popular';
      case SortOption.unpopular:
        return 'Unpopular';
      case SortOption.newest:
        return 'Newest';
      case SortOption.oldest:
        return 'Oldest';
    }
  }

  List<SortOption> get _availableSortOptions {
    if (_isGuest) {
      return [SortOption.newest, SortOption.oldest];
    }
    return SortOption.values.toList();
  }

  void _toggleMyDrawings() {
    setState(() {
      _myDrawingsOnly = !_myDrawingsOnly;
      _currentPage = 1;
      _isLoading = true;
    });
    _fetchDrawings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawings'),
        actions: [
          DropdownButton<SortOption>(
            value: _sortOption,
            underline: const SizedBox(),
            icon: const Icon(Icons.sort),
            items: _availableSortOptions.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(_sortLabel(option)),
              );
            }).toList(),
            onChanged: _onSortChanged,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isGuest ? 56 : 90),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _isGuest
                        ? 'Search by title...'
                        : 'Search by artist or title...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchSubmitted('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onSubmitted: _onSearchSubmitted,
                ),
                if (!_isGuest)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: _toggleMyDrawings,
                        style: FilledButton.styleFrom(
                          backgroundColor: _myDrawingsOnly
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          foregroundColor: _myDrawingsOnly
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        child: const Text('My drawings only'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _drawings.isEmpty
          ? const Center(child: Text('No drawings yet'))
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchDrawings,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _drawings.length,
                      itemBuilder: (context, index) {
                        return DrawingCard(drawing: _drawings[index]);
                      },
                    ),
                  ),
                ),
                if (_totalPages > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _currentPage > 1
                              ? () => _goToPage(_currentPage - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('$_currentPage / $_totalPages'),
                        IconButton(
                          onPressed: _currentPage < _totalPages
                              ? () => _goToPage(_currentPage + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
              ],
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

class Comment {
  final int id;
  final String artistName;
  final String content;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.artistName,
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      artistName: json['artistName'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
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
  final _commentController = TextEditingController();
  List<Comment> _comments = [];
  int _commentPage = 1;
  int _commentTotalPages = 1;

  @override
  void initState() {
    super.initState();
    if (!widget.drawing.isGuestDrawing) {
      _fetchComments();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    if (widget.drawing.isGuestDrawing) return;

    final token = await _authService.getIdToken();
    if (token == null) return;

    final response = await http.get(
      Uri.parse(
        '${dotenv.env['BACKEND_URL']}/drawings/comments/view?drawingId=${widget.drawing.id}&page=$_commentPage',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> commentsData = data['comments'];
      setState(() {
        _comments = commentsData.map((c) => Comment.fromJson(c)).toList();
        _commentPage = data['page'];
        _commentTotalPages = data['totalPages'];
      });
    }
  }

  void _goToCommentPage(int page) {
    if (page < 1 || page > _commentTotalPages || page == _commentPage) return;
    setState(() => _commentPage = page);
    _fetchComments();
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final userName = _authService.currentUser?.displayName ?? 'You';
    final optimisticComment = Comment(
      id: -DateTime.now().millisecondsSinceEpoch,
      artistName: userName,
      content: content,
      createdAt: DateTime.now(),
    );

    setState(() {
      _comments.insert(0, optimisticComment);
    });
    _commentController.clear();

    final token = await _authService.getIdToken();
    if (token == null) return;

    http.post(
      Uri.parse('${dotenv.env['BACKEND_URL']}/drawings/comments/save'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'drawingId': widget.drawing.id, 'content': content}),
    );
  }

  Future<void> _toggleLike() async {
    final wasLiked = widget.drawing.isLiked;
    setState(() {
      widget.drawing.isLiked = !wasLiked;
      widget.drawing.likeCount += wasLiked ? -1 : 1;
    });

    final token = await _authService.getIdToken();
    if (token == null) return;

    http.post(
      Uri.parse(
        '${dotenv.env['BACKEND_URL']}/drawings/like/${widget.drawing.id}',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.drawing.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Icon(
                      widget.drawing.isPublic ? Icons.lock_open : Icons.lock,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'by ${widget.drawing.artistName}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${widget.drawing.createdAt.day}/${widget.drawing.createdAt.month}/${widget.drawing.createdAt.year}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (!widget.drawing.isGuestDrawing)
                      Row(
                        children: [
                          IconButton(
                            onPressed: _toggleLike,
                            icon: Icon(
                              widget.drawing.isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
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
                if (widget.drawing.isGuestDrawing) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Guest drawing (saved locally)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  if (widget.drawing.commentsEnabled)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: const InputDecoration(
                              hintText: 'Add a comment...',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _sendComment,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Comments are disabled for this drawing',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
                if (_comments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  ..._comments.map(
                    (comment) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment.artistName,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(comment.content),
                        ],
                      ),
                    ),
                  ),
                  if (_commentTotalPages > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _commentPage > 1
                              ? () => _goToCommentPage(_commentPage - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left, size: 20),
                          visualDensity: VisualDensity.compact,
                        ),
                        Text(
                          '$_commentPage / $_commentTotalPages',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        IconButton(
                          onPressed: _commentPage < _commentTotalPages
                              ? () => _goToCommentPage(_commentPage + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right, size: 20),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                ],
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
