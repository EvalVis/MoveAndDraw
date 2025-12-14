import 'package:flutter/material.dart';

class DrawingsSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  final bool isGuest;
  final ValueChanged<String> onSearchSubmitted;

  const DrawingsSearchBar({
    super.key,
    required this.controller,
    required this.searchQuery,
    required this.isGuest,
    required this.onSearchSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: isGuest
            ? 'Search by title...'
            : 'Search by artist or title...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  onSearchSubmitted('');
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
      onSubmitted: onSearchSubmitted,
    );
  }
}
