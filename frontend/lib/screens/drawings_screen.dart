import 'package:flutter/material.dart';
import '../models/drawing.dart';
import '../services/drawings_service.dart';
import '../widgets/drawing_card.dart';
import '../widgets/drawings_search_bar.dart';
import '../widgets/pagination_controls.dart';

class DrawingsScreen extends StatefulWidget {
  const DrawingsScreen({super.key});

  @override
  State<DrawingsScreen> createState() => _DrawingsScreenState();
}

class _DrawingsScreenState extends State<DrawingsScreen> {
  final _drawingsService = DrawingsService();
  final _searchController = TextEditingController();
  List<Drawing> _drawings = [];
  bool _isLoading = true;
  SortOption _sortOption = SortOption.newest;
  String _searchQuery = '';
  int _currentPage = 1;
  int _totalPages = 1;
  bool _myDrawingsOnly = false;

  bool get _isGuest => _drawingsService.isGuest;

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
    final result = await _drawingsService.fetchDrawings(
      sortOption: _sortOption,
      searchQuery: _searchQuery,
      page: _currentPage,
      myDrawingsOnly: _myDrawingsOnly,
    );

    if (result != null) {
      setState(() {
        _drawings = result.drawings;
        _currentPage = result.page;
        _totalPages = result.totalPages;
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

  void _toggleMyDrawings() {
    setState(() {
      _myDrawingsOnly = !_myDrawingsOnly;
      _currentPage = 1;
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
                DrawingsSearchBar(
                  controller: _searchController,
                  searchQuery: _searchQuery,
                  isGuest: _isGuest,
                  onSearchSubmitted: _onSearchSubmitted,
                ),
                if (!_isGuest) _buildMyDrawingsButton(context),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildMyDrawingsButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.tonal(
          onPressed: _toggleMyDrawings,
          style: FilledButton.styleFrom(
            backgroundColor: _myDrawingsOnly
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            foregroundColor: _myDrawingsOnly
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurface,
          ),
          child: const Text('My drawings only'),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_drawings.isEmpty) {
      return const Center(child: Text('No drawings yet'));
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchDrawings,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _drawings.length,
              itemBuilder: (context, index) {
                return DrawingCard(
                  drawing: _drawings[index],
                  service: _drawingsService,
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: PaginationControls(
            currentPage: _currentPage,
            totalPages: _totalPages,
            onPageChanged: _goToPage,
          ),
        ),
      ],
    );
  }
}
