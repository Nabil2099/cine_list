import 'package:equatable/equatable.dart';

/// Aggregated CineList community rating snapshot for a single movie.
class CommunityMovieSpotlight extends Equatable {
  const CommunityMovieSpotlight({
    required this.movieId,
    required this.movieTitle,
    this.posterPath,
    required this.averageRating,
    required this.reviewCount,
    required this.totalLikes,
    required this.latestReviewedAt,
  });

  final int movieId;
  final String movieTitle;
  final String? posterPath;
  final double averageRating;
  final int reviewCount;
  final int totalLikes;
  final DateTime latestReviewedAt;

  @override
  List<Object?> get props => [
    movieId,
    movieTitle,
    posterPath,
    averageRating,
    reviewCount,
    totalLikes,
    latestReviewedAt,
  ];
}
