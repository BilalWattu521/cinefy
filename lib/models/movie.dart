class Movie {
  final String id;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String? overview;
  final String? releaseDate;
  final double voteAverage;
  final String source; // Always 'tmdb' now
  final String type; // 'movie', 'tv', 'series'

  Movie({
    required this.id,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.overview,
    this.releaseDate,
    this.voteAverage = 0.0,
    required this.source,
    required this.type,
  });

  factory Movie.fromTmdbJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'].toString(),
      title: json['title'] ?? json['name'] ?? 'Unknown',
      posterPath: json['poster_path'] != null
          ? 'https://image.tmdb.org/t/p/w500${json['poster_path']}'
          : null,
      backdropPath: json['backdrop_path'] != null
          ? 'https://image.tmdb.org/t/p/w780${json['backdrop_path']}'
          : null,
      overview: json['overview'],
      releaseDate: json['release_date'] ?? json['first_air_date'],
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      source: 'tmdb',
      type: json['media_type'] ?? (json['name'] != null ? 'tv' : 'movie'),
    );
  }

  /// Returns a globally unique ID combining type and TMDB ID (e.g. "tv:12345" or "movie:67890")
  String get uniqueId => '$type:$id';

  String? get releaseYear {
    if (releaseDate != null && releaseDate!.length >= 4) {
      return releaseDate!.substring(0, 4);
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'posterPath': posterPath,
      'source': source,
      'type': type,
    };
  }
}
