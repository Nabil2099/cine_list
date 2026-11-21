import '../../../../shared/models/movie_summary.dart';

/// TMDB movie or TV series item parsed from list/search endpoints.
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
    super.mediaType = MediaType.movie,
  });

  factory MovieModel.fromJson(
    Map<String, dynamic> json, {
    MediaType? mediaType,
  }) {
    final rawGenres = json['genre_ids'];
    final genreIds = rawGenres is List
        ? rawGenres.whereType<num>().map((e) => e.toInt()).toList()
        : const <int>[];

    final resolvedMediaType =
        mediaType ??
        ((json['media_type'] == 'tv' ||
                (json['title'] == null && json['name'] != null))
            ? MediaType.tv
            : MediaType.movie);

    final rawTitle =
        (json['title'] as String?) ??
        (json['name'] as String?) ??
        (json['original_title'] as String?) ??
        (json['original_name'] as String?);
    final title = (rawTitle != null && rawTitle.trim().isNotEmpty)
        ? rawTitle.trim()
        : 'Untitled';

    final releaseDate =
        (json['release_date'] as String?) ??
        (json['first_air_date'] as String?);

    return MovieModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: title,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      releaseDate: releaseDate,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      overview: (json['overview'] as String?) ?? '',
      genreIds: genreIds,
      mediaType: resolvedMediaType,
    );
  }
}
