import 'package:equatable/equatable.dart';

/// Lightweight shared movie summary used across Discover, Details, and Watchlist.
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
  });

  final int id;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final double voteAverage;
  final String overview;
  final List<int> genreIds;

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
  ];
}
