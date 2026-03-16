import 'package:flutter/foundation.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';

class CatalogProvider extends ChangeNotifier {
  final TmdbService _tmdbService = TmdbService();

  final List<Movie> _tmdbMovies = [];
  List<Movie> _searchResults = [];

  // Cache for movie details to persist data even when search results are cleared
  final Map<String, Movie> _movieCache = {};

  // Tracking currently resolving IDs to show proper loading indicators
  final Set<String> _resolvingIds = {};

  // Track if a batch resolution is in progress
  bool _isResolvingBatch = false;

  bool _isLoading = false;
  int _currentPage = 1;
  String _currentFilter = 'trending';
  bool _hasMoreTmdb = true;
  String _searchQuery = '';

  bool get isLoading => _isLoading;
  bool get isResolvingBatch => _isResolvingBatch;
  bool isResolving(String id) => _resolvingIds.contains(id);
  bool isAnyResolving(List<String> ids) =>
      ids.any((id) => _resolvingIds.contains(id));

  /// Checks if all IDs in a list are already loaded in the cache.
  bool areAllLoaded(List<String> ids) =>
      ids.every((id) => _movieCache.containsKey(id));

  bool get hasMoreTmdb => _searchQuery.isEmpty ? _hasMoreTmdb : false;
  String get currentFilter => _currentFilter;
  String get searchQuery => _searchQuery;
  bool get isSearching => _searchQuery.isNotEmpty;

  List<Movie> get mergedCatalog {
    // If searching, return search results instead
    if (_searchQuery.isNotEmpty) {
      return _searchResults;
    }

    return _tmdbMovies;
  }

  /// Retrieves a movie by ID from any current list or the persistent cache.
  Movie? getMovieById(String id) {
    // 1. Check persistent cache (most reliable)
    if (_movieCache.containsKey(id)) return _movieCache[id];

    // 2. Check TMDB movies (trending/popular)
    final tmdbIndex = _tmdbMovies.indexWhere(
      (m) => m.uniqueId == id || m.id == id,
    );
    if (tmdbIndex != -1) return _tmdbMovies[tmdbIndex];

    // 3. Check search results
    final searchIndex = _searchResults.indexWhere(
      (m) => m.uniqueId == id || m.id == id,
    );
    if (searchIndex != -1) return _searchResults[searchIndex];

    return null;
  }

  /// Ensures a movie's details are loaded and cached.
  /// Fetches from network if not found locally.
  Future<Movie?> ensureMovieLoaded(String id, [String? type]) async {
    final existing = getMovieById(id);
    if (existing != null) {
      // Add to cache if found in search but not in cache yet
      if (!_movieCache.containsKey(id)) {
        _movieCache[id] = existing;
      }
      return existing;
    }

    if (_resolvingIds.contains(id)) return null;

    // Not found anywhere, fetch from TMDB
    _resolvingIds.add(id);
    notifyListeners();

    try {
      final movie = type != null
          ? await _tmdbService.getMovieDetails(id, type)
          : await _tmdbService.getMovieById(id);

      if (movie != null) {
        _movieCache[id] = movie;
        return movie;
      }
    } catch (e) {
      if (kDebugMode) print('Failed to resolve movie $id: $e');
    } finally {
      _resolvingIds.remove(id);
      notifyListeners();
    }
    return null;
  }

  /// Background resolution for a list of movie IDs.
  /// Useful for populating collection screens.
  Future<void> resolveMovies(List<String> ids) async {
    final List<String> toResolve = ids
        .where((id) => getMovieById(id) == null && !_resolvingIds.contains(id))
        .toList();
    if (toResolve.isEmpty) return;

    _resolvingIds.addAll(toResolve);
    _isResolvingBatch = true;
    notifyListeners();

    try {
      // Fetch details in parallel for efficiency
      final List<Movie?> results = await Future.wait(
        toResolve.map((id) => _tmdbService.getMovieById(id)),
      );

      for (int i = 0; i < toResolve.length; i++) {
        final Movie? movie = results[i];
        if (movie != null) {
          _movieCache[toResolve[i]] = movie;
          // Also store with its own uniqueId for consistency
          _movieCache[movie.uniqueId] = movie;
        }
      }
    } catch (e) {
      if (kDebugMode) print('Failed to resolve movies: $e');
    } finally {
      _resolvingIds.removeAll(toResolve);
      _isResolvingBatch = false;
      notifyListeners();
    }
  }

  CatalogProvider() {
    // Initialize provider - currently only TMDB data is used
  }

  void setFilter(String filter) {
    if (_currentFilter != filter) {
      _currentFilter = filter;
      _currentPage = 1;
      _tmdbMovies.clear();
      _hasMoreTmdb = true;
      notifyListeners();
      loadMoreTmdb();
    }
  }

  Future<void> search(String query) async {
    _searchQuery = query.trim();
    if (_searchQuery.isEmpty) {
      clearSearch();
      return;
    }

    _isLoading = true;
    _searchResults.clear();
    notifyListeners();

    try {
      _searchResults = await _tmdbService.searchMulti(_searchQuery);
      // Automatically cache results to prevent loss
      for (var movie in _searchResults) {
        _movieCache[movie.uniqueId] = movie;
      }
    } catch (e) {
      if (kDebugMode) {
        print('TMDB search error: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults.clear();
    notifyListeners();
  }

  Future<void> loadMoreTmdb({bool refresh = false}) async {
    if (_isLoading || (!_hasMoreTmdb && !refresh)) return;

    if (refresh) {
      _currentPage = 1;
      _tmdbMovies.clear();
      _hasMoreTmdb = true;
    }

    _isLoading = true;
    notifyListeners();

    try {
      List<Movie> newMovies = [];
      if (_currentFilter == 'trending') {
        newMovies = await _tmdbService.getTrendingMovies(page: _currentPage);
      } else if (_currentFilter == 'movies') {
        newMovies = await _tmdbService.getPopularMovies(page: _currentPage);
      } else if (_currentFilter == 'series') {
        newMovies = await _tmdbService.getPopularTvSeries(page: _currentPage);
      }

      _currentPage++;
      _tmdbMovies.addAll(newMovies);

      // Cache trending/popular movies too
      for (var movie in newMovies) {
        _movieCache[movie.uniqueId] = movie;
      }

      if (newMovies.isEmpty) _hasMoreTmdb = false;
    } catch (e) {
      if (kDebugMode) {
        print('TMDB fetch error: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
