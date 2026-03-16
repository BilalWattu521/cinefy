import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/catalog_provider.dart';
import '../widgets/movie_card.dart';
import 'movie_detail_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catalog'), actions: const []),
      body: Consumer<CatalogProvider>(
        builder: (context, catalog, child) {
          final movies = catalog.mergedCatalog;

          return Column(
            children: [
              _buildSearchBar(catalog),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => catalog.loadMoreTmdb(refresh: true),
                  child: GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
                              builder: (context) =>
                                  MovieDetailScreen(movie: movie),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
