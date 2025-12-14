import 'package:flutter/material.dart';
import '../models/drawing.dart';
import '../screens/drawing_fullscreen.dart';
import '../services/drawings_service.dart';
import 'drawing_map.dart';
import 'comments_section.dart';

class DrawingCard extends StatefulWidget {
  final Drawing drawing;
  final DrawingsService service;

  const DrawingCard({super.key, required this.drawing, required this.service});

  @override
  State<DrawingCard> createState() => _DrawingCardState();
}

class _DrawingCardState extends State<DrawingCard> {
  bool _showComments = false;

  Future<void> _toggleLike() async {
    final wasLiked = widget.drawing.isLiked;
    setState(() {
      widget.drawing.isLiked = !wasLiked;
      widget.drawing.likeCount += wasLiked ? -1 : 1;
    });

    widget.service.toggleLike(widget.drawing.id);
  }

  void _toggleShowComments() {
    setState(() => _showComments = !_showComments);
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DrawingFullscreen(drawing: widget.drawing),
      ),
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
          Stack(
            children: [
              SizedBox(height: 200, child: DrawingMap(drawing: widget.drawing)),
              Positioned(
                right: 8,
                top: 8,
                child: Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                  child: InkWell(
                    onTap: _openFullscreen,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 4),
                _buildArtistName(context),
                const SizedBox(height: 4),
                _buildDateAndLikes(context),
                _buildFooter(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
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
    );
  }

  Widget _buildArtistName(BuildContext context) {
    return Text(
      'by ${widget.drawing.artistName}',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
    );
  }

  Widget _buildDateAndLikes(BuildContext context) {
    return Row(
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
    );
  }

  Widget _buildFooter(BuildContext context) {
    if (widget.drawing.isGuestDrawing) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Guest drawing (saved locally)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (widget.drawing.commentsEnabled)
          TextButton.icon(
            onPressed: _toggleShowComments,
            icon: Icon(_showComments ? Icons.expand_less : Icons.expand_more),
            label: Text(_showComments ? 'Hide comments' : 'View comments'),
          )
        else
          Text(
            'Comments are disabled for this drawing',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        if (_showComments && widget.drawing.commentsEnabled)
          CommentsSection(
            drawingId: widget.drawing.id,
            service: widget.service,
          ),
      ],
    );
  }
}
