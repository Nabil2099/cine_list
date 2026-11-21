import 'package:equatable/equatable.dart';

import '../../../../shared/models/movie_summary.dart';

/// Detailed movie or TV series model parsed from TMDB `/movie/{id}` or `/tv/{id}`.
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
    this.mediaType = MediaType.movie,
    this.numberOfSeasons,
    this.numberOfEpisodes,
  });

  factory MovieDetailsModel.fromJson(
    Map<String, dynamic> json, {
    MediaType mediaType = MediaType.movie,
  }) {
    final rawGenres = json['genres'];
    final genres = rawGenres is List
        ? rawGenres
              .whereType<Map>()
              .map((g) => g['name'] as String?)
              .whereType<String>()
              .where((name) => name.trim().isNotEmpty)
              .toList()
        : const <String>[];

    final resolvedMediaType =
        (mediaType == MediaType.tv ||
            (json['title'] == null && json['name'] != null))
        ? MediaType.tv
        : MediaType.movie;

    final rawTitle =
        (json['title'] as String?) ??
        (json['name'] as String?) ??
        (json['original_title'] as String?) ??
        (json['original_name'] as String?);
    final title = (rawTitle != null && rawTitle.trim().isNotEmpty)
        ? rawTitle.trim()
        : 'Untitled';

    int? runtime = (json['runtime'] as num?)?.toInt();
    if (runtime == null && json['episode_run_time'] is List) {
      final list = (json['episode_run_time'] as List).whereType<num>().toList();
      if (list.isNotEmpty) {
        runtime = list.first.toInt();
      }
    }

    return MovieDetailsModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: title,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      releaseDate:
          (json['release_date'] as String?) ??
          (json['first_air_date'] as String?),
      runtime: runtime,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      overview: (json['overview'] as String?) ?? '',
      tagline: (json['tagline'] as String?) ?? '',
      genres: genres,
      mediaType: resolvedMediaType,
      numberOfSeasons: (json['number_of_seasons'] as num?)?.toInt(),
      numberOfEpisodes: (json['number_of_episodes'] as num?)?.toInt(),
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
  final MediaType mediaType;
  final int? numberOfSeasons;
  final int? numberOfEpisodes;

  MovieSummary toMovieSummary() {
    return MovieSummary(
      id: id,
      title: title,
      posterPath: posterPath,
      backdropPath: backdropPath,
      releaseDate: releaseDate,
      voteAverage: voteAverage,
      overview: overview,
      mediaType: mediaType,
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
    mediaType,
    numberOfSeasons,
    numberOfEpisodes,
  ];
}
