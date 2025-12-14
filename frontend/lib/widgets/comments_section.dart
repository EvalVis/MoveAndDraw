import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../services/drawings_service.dart';
import 'pagination_controls.dart';

class CommentsSection extends StatefulWidget {
  final int drawingId;
  final DrawingsService service;

  const CommentsSection({
    super.key,
    required this.drawingId,
    required this.service,
  });

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final _commentController = TextEditingController();
  List<Comment> _comments = [];
  int _commentPage = 1;
  int _commentTotalPages = 1;
  bool _isLoaded = false;

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
    final result = await widget.service.fetchComments(
      drawingId: widget.drawingId,
      page: _commentPage,
    );

    if (result != null) {
      setState(() {
        _comments = result.comments;
        _commentPage = result.page;
        _commentTotalPages = result.totalPages;
        _isLoaded = true;
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

    final userName = widget.service.currentUserName ?? 'You';
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

    widget.service.sendComment(drawingId: widget.drawingId, content: content);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            IconButton(onPressed: _sendComment, icon: const Icon(Icons.send)),
          ],
        ),
        if (_isLoaded && _comments.isNotEmpty) ...[
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(comment.content),
                ],
              ),
            ),
          ),
          PaginationControls(
            currentPage: _commentPage,
            totalPages: _commentTotalPages,
            onPageChanged: _goToCommentPage,
            compact: true,
          ),
        ],
      ],
    );
  }
}
