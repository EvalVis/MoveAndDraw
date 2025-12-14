import 'package:flutter/material.dart';

class PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final bool compact;

  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: currentPage > 1
              ? () => onPageChanged(currentPage - 1)
              : null,
          icon: Icon(Icons.chevron_left, size: compact ? 20 : 24),
          visualDensity: compact ? VisualDensity.compact : null,
        ),
        Text(
          '$currentPage / $totalPages',
          style: compact
              ? Theme.of(context).textTheme.bodySmall
              : Theme.of(context).textTheme.bodyMedium,
        ),
        IconButton(
          onPressed: currentPage < totalPages
              ? () => onPageChanged(currentPage + 1)
              : null,
          icon: Icon(Icons.chevron_right, size: compact ? 20 : 24),
          visualDensity: compact ? VisualDensity.compact : null,
        ),
      ],
    );
  }
}
