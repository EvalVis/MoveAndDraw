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

enum SortOption { popular, unpopular, newest, oldest }

class _DrawingsScreenState extends State<DrawingsScreen> {
  final _authService = GoogleAuthService();
  final _searchController = TextEditingController();
  List<Drawing> _drawings = [];
  bool _isLoading = true;
  SortOption _sortOption = SortOption.newest;
  String _searchQuery = '';
  int _currentPage = 1;
  int _totalPages = 1;

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
    final token = await _authService.getIdToken();
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    final sortParam = _sortOption.name;
    final searchParam = Uri.encodeComponent(_searchQuery);
    final response = await http.get(
      Uri.parse(
        '${dotenv.env['BACKEND_URL']}/drawings/view?sort=$sortParam&search=$searchParam&page=$_currentPage',
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
            items: SortOption.values.map((option) {
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
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by artist or title...',
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
  bool _isLiking = false;
  bool _isSendingComment = false;
  List<Comment> _comments = [];
  int _commentPage = 1;
  int _commentTotalPages = 1;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
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
    if (content.isEmpty || _isSendingComment) return;

    setState(() => _isSendingComment = true);

    final token = await _authService.getIdToken();
    if (token == null) {
      setState(() => _isSendingComment = false);
      return;
    }

    final response = await http.post(
      Uri.parse('${dotenv.env['BACKEND_URL']}/drawings/comments/save'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'drawingId': widget.drawing.id, 'content': content}),
    );

    if (response.statusCode == 201) {
      _commentController.clear();
      _commentPage = 1;
      _fetchComments();
    }
    setState(() => _isSendingComment = false);
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    setState(() => _isLiking = true);

    final token = await _authService.getIdToken();
    if (token == null) {
      setState(() => _isLiking = false);
      return;
    }

    final response = await http.post(
      Uri.parse(
        '${dotenv.env['BACKEND_URL']}/drawings/like/${widget.drawing.id}',
      ),
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
                    Row(
                      children: [
                        IconButton(
                          onPressed: _isLiking ? null : _toggleLike,
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
                        onPressed: _isSendingComment ? null : _sendComment,
                        icon: _isSendingComment
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
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
