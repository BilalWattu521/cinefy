import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/catalog_provider.dart';
import '../services/auth_service.dart';
import '../widgets/movie_card.dart';
import 'movie_detail_screen.dart';
import 'add_custom_movie_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => CatalogScreenState();
}

class CatalogScreenState extends State<CatalogScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CatalogProvider>(context, listen: false).loadMoreTmdb();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    final catalog = Provider.of<CatalogProvider>(context, listen: false);
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !catalog.isLoading &&
        catalog.hasMoreTmdb) {
      catalog.loadMoreTmdb();
    }
  }

  void _onSearchChanged(String query, CatalogProvider catalog) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) {
        catalog.search(query);
      } else {
        catalog.clearSearch();
      }
    });
  }

  /// Shows a dialog prompting the user to log in.
  /// Returns true if the user chose to log in and successfully authenticated.

  /// Wraps an action behind an auth check. If the user is not logged in,
  /// prompts them to log in first.

  void scrollToTopOrRefresh() {
    if (_scrollController.hasClients) {
      if (_scrollController.offset > 0) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        Provider.of<CatalogProvider>(
          context,
          listen: false,
        ).loadMoreTmdb(refresh: true);
      }
    }
  }

  Widget _buildFilterChips(CatalogProvider catalog, bool isLoggedIn) {
    final filters = [
      {'id': 'trending', 'label': 'Trending'},
      {'id': 'movies', 'label': 'Movies'},
      {'id': 'series', 'label': 'TV Series'},
      if (isLoggedIn) {'id': 'custom', 'label': 'My Custom'},
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = catalog.currentFilter == filter['id'];

          return ChoiceChip(
            label: Text(filter['label']!),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                catalog.setFilter(filter['id']!);
              }
            },
            selectedColor: Theme.of(context).colorScheme.primaryContainer,
            labelStyle: TextStyle(
              color: isSelected 
                  ? Theme.of(context).colorScheme.onPrimaryContainer 
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Catalog'), actions: const []),
      body: Consumer<CatalogProvider>(
        builder: (context, catalog, child) {
          final movies = catalog.mergedCatalog;

          Widget contentWidget;
          if (movies.isEmpty && !catalog.isLoading) {
            contentWidget = Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      catalog.isSearching ? Icons.search_off : Icons.movie_creation_outlined,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      catalog.isSearching 
                          ? 'No Matches Found' 
                          : (catalog.currentFilter == 'custom' ? 'No Custom Titles' : 'No titles found'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      catalog.isSearching
                          ? 'We couldn\'t find any titles in TMDB matching "${catalog.searchQuery}".'
                          : (catalog.currentFilter == 'custom' 
                              ? 'You haven\'t added any custom movies or TV series yet.' 
                              : 'Try checking your connection or pull to refresh.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, height: 1.4),
                    ),
                    if (user != null && (catalog.isSearching || catalog.currentFilter == 'custom')) ...[
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddCustomMovieScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Custom Title'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          } else {
            contentWidget = GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: movies.length + (catalog.hasMoreTmdb ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == movies.length) {
                  return const Center(child: CircularProgressIndicator());
                }

                final movie = movies[index];
                return MovieCard(
                  movie: movie,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MovieDetailScreen(movie: movie),
                      ),
                    );
                  },
                );
              },
            );
          }

          return Column(
            children: [
              _buildSearchBar(catalog),
              _buildFilterChips(catalog, user != null),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => catalog.loadMoreTmdb(refresh: true),
                  child: contentWidget,
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: user != null
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddCustomMovieScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Custom'),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            )
          : null,
    );
  }

  Widget _buildSearchBar(CatalogProvider catalog) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search movies & series...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: catalog.isSearching
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    catalog.clearSearch();
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        textInputAction: TextInputAction.search,
        onChanged: (value) => _onSearchChanged(value, catalog),
      ),
    );
  }
}
