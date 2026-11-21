import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/movie_summary.dart';
import '../../../watchlist/data/models/watchlist_movie_model.dart';
import '../../data/repositories/recommendation_repository.dart';

enum RecommendationsStatus { initial, loading, loaded, error }

class RecommendationsState extends Equatable {
  const RecommendationsState({
    this.status = RecommendationsStatus.initial,
    this.movies = const [],
    this.isShuffling = false,
    this.usedAi = false,
    this.basedOnWatchlist = false,
  });

  final RecommendationsStatus status;
  final List<MovieSummary> movies;
  final bool isShuffling;
  final bool usedAi;
  final bool basedOnWatchlist;

  RecommendationsState copyWith({
    RecommendationsStatus? status,
    List<MovieSummary>? movies,
    bool? isShuffling,
    bool? usedAi,
    bool? basedOnWatchlist,
  }) {
    return RecommendationsState(
      status: status ?? this.status,
      movies: movies ?? this.movies,
      isShuffling: isShuffling ?? this.isShuffling,
      usedAi: usedAi ?? this.usedAi,
      basedOnWatchlist: basedOnWatchlist ?? this.basedOnWatchlist,
    );
  }

  @override
  List<Object?> get props => [
    status,
    movies,
    isShuffling,
    usedAi,
    basedOnWatchlist,
  ];
}

/// Manages the Discover "Recommended For You" 5-movie AI + taste slide.
class RecommendationsCubit extends Cubit<RecommendationsState> {
  RecommendationsCubit(this._repository) : super(const RecommendationsState());

  final RecommendationRepository _repository;
  String? _lastSignature;
  int _requestId = 0;

  String _signatureFor(List<WatchlistMovieModel> watchlist) {
    if (watchlist.isEmpty) return 'empty';
    final ids = watchlist.map((m) => '${m.movieId}:${m.userRating ?? 0}').toList()
      ..sort();
    return ids.join(',');
  }

  Future<void> syncWithWatchlist(List<WatchlistMovieModel> watchlist) async {
    final sig = _signatureFor(watchlist);
    if (sig == _lastSignature && state.status == RecommendationsStatus.loaded) {
      return;
    }
    _lastSignature = sig;
    await _fetch(watchlist: watchlist, shuffle: false);
  }

  Future<void> shuffle(List<WatchlistMovieModel> watchlist) async {
    if (state.isShuffling) return;
    emit(state.copyWith(isShuffling: true));
    final currentIds = {for (final m in state.movies) m.id};
    await _fetch(
      watchlist: watchlist,
      excludeIds: currentIds,
      shuffle: true,
    );
  }

  Future<void> _fetch({
    required List<WatchlistMovieModel> watchlist,
    Set<int> excludeIds = const {},
    required bool shuffle,
  }) async {
    final reqId = ++_requestId;
    if (state.movies.isEmpty) {
      emit(state.copyWith(status: RecommendationsStatus.loading));
    }
    try {
      final result = await _repository.getRecommendations(
        watchlist: watchlist,
        excludeIds: excludeIds,
        shuffle: shuffle,
        limit: 5,
      );
      if (isClosed || reqId != _requestId) return;
      emit(
        state.copyWith(
          status: RecommendationsStatus.loaded,
          movies: result.movies,
          isShuffling: false,
          usedAi: result.usedAi,
          basedOnWatchlist: result.basedOnWatchlist,
        ),
      );
    } catch (_) {
      if (isClosed || reqId != _requestId) return;
      emit(
        state.copyWith(
          status: state.movies.isNotEmpty
              ? RecommendationsStatus.loaded
              : RecommendationsStatus.error,
          isShuffling: false,
        ),
      );
    }
  }
}
