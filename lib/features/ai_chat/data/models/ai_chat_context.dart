import 'package:equatable/equatable.dart';

import '../../../community/data/models/movie_review_model.dart';
import '../../../community/data/models/weekly_challenge_model.dart';
import '../../../watchlist/data/models/watchlist_collection_model.dart';
import '../../../watchlist/data/models/watchlist_movie_model.dart';

/// Grounding context passed to CineList AI for personalized recommendations.
class AiChatContext extends Equatable {
  const AiChatContext({
    this.watchlist = const [],
    this.collections = const [],
    this.activeChallenge,
    this.followedReviews = const [],
  });

  final List<WatchlistMovieModel> watchlist;
  final List<WatchlistCollectionModel> collections;
  final WeeklyChallengeModel? activeChallenge;
  final List<MovieReviewModel> followedReviews;

  @override
  List<Object?> get props => [
    watchlist,
    collections,
    activeChallenge,
    followedReviews,
  ];
}
