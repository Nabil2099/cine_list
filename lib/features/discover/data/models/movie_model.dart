import '../../../../shared/models/movie_summary.dart';

/// TMDB movie item parsed from list/search endpoints.
class MovieModel extends MovieSummary {
  const MovieModel({
    required super.id,
    required super.title,
    super.posterPath,
    super.backdropPath,
    super.releaseDate,
    super.voteAverage,
    super.overview,
    super.genreIds,
  });

  factory MovieModel.fromJson(Map<String, dynamic> json) {
    final rawGenres = json['genre_ids'];
    final genreIds = rawGenres is List
        ? rawGenres.whereType<num>().map((e) => e.toInt()).toList()
        : const <int>[];

    return MovieModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : (json['original_title'] as String? ?? 'Untitled'),
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      releaseDate: json['release_date'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      overview: (json['overview'] as String?) ?? '',
      genreIds: genreIds,
    );
  }
}
