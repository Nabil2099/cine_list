import 'package:equatable/equatable.dart';

import '../../../../shared/models/movie_summary.dart';

/// A single taste-DNA trait score (0..100) inferred from the user's watchlist.
class CinemaDnaTrait extends Equatable {
  const CinemaDnaTrait({required this.label, required this.score});

  final String label;
  final int score;

  @override
  List<Object?> get props => [label, score];
}

/// An unseen "blind-spot" movie recommended to complement the user's Cinema DNA.
class CinemaDnaBlindSpot extends Equatable {
  const CinemaDnaBlindSpot({
    required this.title,
    this.year,
    required this.reason,
    this.movie,
  });

  final String title;
  final String? year;
  final String reason;
  final MovieSummary? movie;

  CinemaDnaBlindSpot copyWith({MovieSummary? movie}) {
    return CinemaDnaBlindSpot(
      title: title,
      year: year,
      reason: reason,
      movie: movie ?? this.movie,
    );
  }

  @override
  List<Object?> get props => [title, year, reason, movie];
}

/// Complete AI + local-stats Cinema DNA profile for a user's watchlist.
class CinemaDnaProfile extends Equatable {
  const CinemaDnaProfile({
    required this.archetype,
    required this.tagline,
    required this.traits,
    required this.blindSpots,
    required this.totalMovies,
    required this.watchedCount,
    this.averageRating,
    this.topDecade,
  });

  final String archetype;
  final String tagline;
  final List<CinemaDnaTrait> traits;
  final List<CinemaDnaBlindSpot> blindSpots;
  final int totalMovies;
  final int watchedCount;
  final double? averageRating;
  final String? topDecade;

  CinemaDnaProfile copyWith({List<CinemaDnaBlindSpot>? blindSpots}) {
    return CinemaDnaProfile(
      archetype: archetype,
      tagline: tagline,
      traits: traits,
      blindSpots: blindSpots ?? this.blindSpots,
      totalMovies: totalMovies,
      watchedCount: watchedCount,
      averageRating: averageRating,
      topDecade: topDecade,
    );
  }

  @override
  List<Object?> get props => [
    archetype,
    tagline,
    traits,
    blindSpots,
    totalMovies,
    watchedCount,
    averageRating,
    topDecade,
  ];
}
