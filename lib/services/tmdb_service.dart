import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import '../models/movie.dart';

class TmdbService {
  static String get _apiKey => dotenv.env['TMDB_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  Future<List<Movie>> getTrendingMovies({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/trending/all/week?api_key=$_apiKey&page=$page'),
    );
    return _parseMovies(response);
  }

  Future<List<Movie>> getPopularMovies({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/popular?api_key=$_apiKey&page=$page'),
    );
    return _parseMovies(response);
  }

  Future<List<Movie>> getPopularTvSeries({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/tv/popular?api_key=$_apiKey&page=$page'),
    );
    return _parseMovies(response, forceType: 'tv');
  }

  Future<List<Movie>> searchMulti(String query, {int page = 1}) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/search/multi?api_key=$_apiKey&query=${Uri.encodeComponent(query)}&page=$page',
      ),
    );
    return _parseMovies(response);
  }

  List<Movie> _parseMovies(http.Response response, {String? forceType}) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List results = data['results'] ?? [];
      return results.map((json) {
        if (forceType != null && json['media_type'] == null) {
          json['media_type'] = forceType;
        }
        return Movie.fromTmdbJson(json);
      }).toList();
    } else {
      throw Exception('Failed to load data from TMDB');
    }
  }

  /// Fetches TV series details to get the number of seasons.
  Future<int?> getTvSeasonCount(String tvId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/tv/$tvId?api_key=$_apiKey'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['number_of_seasons'] as int?;
      }
    } catch (_) {
      // Silently fail — season count is optional
    }
    return null;
  }

  /// Fetches full details for a single movie or TV series.
  Future<Movie?> getMovieDetails(String id, String type) async {
    final endpoint = type == 'tv' || type == 'series' ? 'tv' : 'movie';
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$endpoint/$id?api_key=$_apiKey'),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        // Ensure media_type is present for our parser
        json['media_type'] = type == 'series' ? 'tv' : type;
        return Movie.fromTmdbJson(json);
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching $type details: $e');
    }
    return null;
  }

  /// Attempts to fetch movie details by ID, supporting both plain IDs and type-prefixed IDs (e.g. "tv:12345").
  Future<Movie?> getMovieById(String id) async {
    // 1. Check if it's a type-prefixed ID (e.g. "tv:12345" or "movie:12345")
    if (id.contains(':')) {
      final parts = id.split(':');
      if (parts.length == 2) {
        final type = parts[0];
        final actualId = parts[1];
        return await getMovieDetails(actualId, type);
      }
    }

    // 2. Legacy Fallback: Try movie first
    var movie = await getMovieDetails(id, 'movie');
    if (movie != null) return movie;

    // 3. Try TV series if movie failed
    return await getMovieDetails(id, 'tv');
  }
}
