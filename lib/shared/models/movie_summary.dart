import 'package:equatable/equatable.dart';

/// Media type for TMDB items (movies vs. TV series such as Anime TV shows).
enum MediaType {
  movie,
  tv;

  static MediaType fromString(String? raw) {
    return raw == 'tv' ? MediaType.tv : MediaType.movie;
  }
}

/// Lightweight shared movie/series summary used across Discover, Details, and Watchlist.
class MovieSummary extends Equatable {
  const MovieSummary({
    required this.id,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.voteAverage = 0.0,
    this.overview = '',
    this.genreIds = const [],
    this.mediaType = MediaType.movie,
  });

  final int id;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final double voteAverage;
  final String overview;
  final List<int> genreIds;
  final MediaType mediaType;

  @override
  List<Object?> get props => [
    id,
    title,
    posterPath,
    backdropPath,
    releaseDate,
    voteAverage,
    overview,
    genreIds,
    mediaType,
  ];
}
