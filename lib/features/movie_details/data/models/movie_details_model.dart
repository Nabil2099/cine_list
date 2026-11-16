import 'package:equatable/equatable.dart';

import '../../../../shared/models/movie_summary.dart';

/// Detailed movie model parsed from TMDB `/movie/{id}`.
class MovieDetailsModel extends Equatable {
  const MovieDetailsModel({
    required this.id,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.runtime,
    this.voteAverage = 0.0,
    this.overview = '',
    this.tagline = '',
    this.genres = const [],
  });

  factory MovieDetailsModel.fromJson(Map<String, dynamic> json) {
    final rawGenres = json['genres'];
    final genres = rawGenres is List
        ? rawGenres
              .whereType<Map>()
              .map((g) => g['name'] as String?)
              .whereType<String>()
              .where((name) => name.trim().isNotEmpty)
              .toList()
        : const <String>[];

    return MovieDetailsModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : (json['original_title'] as String? ?? 'Untitled'),
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      releaseDate: json['release_date'] as String?,
      runtime: (json['runtime'] as num?)?.toInt(),
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      overview: (json['overview'] as String?) ?? '',
      tagline: (json['tagline'] as String?) ?? '',
      genres: genres,
    );
  }

  final int id;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final int? runtime;
  final double voteAverage;
  final String overview;
  final String tagline;
  final List<String> genres;

  MovieSummary toMovieSummary() {
    return MovieSummary(
      id: id,
      title: title,
      posterPath: posterPath,
      backdropPath: backdropPath,
      releaseDate: releaseDate,
      voteAverage: voteAverage,
      overview: overview,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    posterPath,
    backdropPath,
    releaseDate,
    runtime,
    voteAverage,
    overview,
    tagline,
    genres,
  ];
}
