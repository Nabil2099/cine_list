import 'package:equatable/equatable.dart';

import '../../data/models/watchlist_collection_model.dart';
import '../../data/models/watchlist_movie_model.dart';

enum WatchlistLoadStatus { initial, loading, loaded, error }

enum WatchlistSortOption {
  recentlyAdded('Recently Added'),
  highestRated('Highest Rated'),
  releaseYear('Release Year');

  const WatchlistSortOption(this.label);

  final String label;
}

class WatchlistState extends Equatable {
  const WatchlistState({
    this.status = WatchlistLoadStatus.initial,
    this.movies = const [],
    this.collections = const [],
    this.selectedCollectionId,
    this.selectedTab = WatchlistFilterStatus.wantToWatch,
    this.sortOption = WatchlistSortOption.recentlyAdded,
    this.searchQuery = '',
    this.mutatingMovieIds = const {},
    this.errorMessage,
    this.feedbackMessage,
  });

  final WatchlistLoadStatus status;
  final List<WatchlistMovieModel> movies;
  final List<WatchlistCollectionModel> collections;
  final String? selectedCollectionId;
  final WatchlistFilterStatus selectedTab;
  final WatchlistSortOption sortOption;
  final String searchQuery;
  final Set<int> mutatingMovieIds;
  final String? errorMessage;
  final String? feedbackMessage;

  List<WatchlistMovieModel> get wantToWatchMovies => movies
      .where((m) => m.status == WatchlistFilterStatus.wantToWatch)
      .toList();

  List<WatchlistMovieModel> get watchedMovies =>
      movies.where((m) => m.status == WatchlistFilterStatus.watched).toList();

  List<WatchlistMovieModel> get activeTabMovies {
    final base = selectedTab == WatchlistFilterStatus.wantToWatch
        ? wantToWatchMovies
        : watchedMovies;

    final selectedCollection = selectedCollectionId == null
        ? null
        : collections.where((c) => c.id == selectedCollectionId).firstOrNull;
    final collectionFiltered = selectedCollection == null
        ? base
        : base
              .where((m) => selectedCollection.containsMovie(m.movieId))
              .toList();

    final query = searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? List<WatchlistMovieModel>.from(collectionFiltered)
        : collectionFiltered
              .where((m) => m.title.toLowerCase().contains(query))
              .toList();

    switch (sortOption) {
      case WatchlistSortOption.recentlyAdded:
        filtered.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case WatchlistSortOption.highestRated:
        filtered.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
      case WatchlistSortOption.releaseYear:
        filtered.sort(
          (a, b) => (b.releaseDate ?? '').compareTo(a.releaseDate ?? ''),
        );
    }

    return filtered;
  }

  int get completionPercent {
    if (movies.isEmpty) return 0;
    return ((watchedMovies.length / movies.length) * 100).round();
  }

  double? get averagePersonalRating {
    final rated = watchedMovies
        .where((m) => m.userRating != null && m.userRating! > 0)
        .toList();
    if (rated.isEmpty) return null;
    final sum = rated.fold<int>(0, (acc, m) => acc + m.userRating!);
    return sum / rated.length;
  }

  int get totalMinutesWatched {
    return watchedMovies.fold<int>(
      0,
      (acc, m) => acc + (m.runtimeMinutes ?? 120),
    );
  }

  WatchlistMovieModel? findById(int movieId) {
    for (final movie in movies) {
      if (movie.movieId == movieId) return movie;
    }
    return null;
  }

  bool isSaved(int movieId) => findById(movieId) != null;

  bool isMutating(int movieId) => mutatingMovieIds.contains(movieId);

  WatchlistState copyWith({
    WatchlistLoadStatus? status,
    List<WatchlistMovieModel>? movies,
    List<WatchlistCollectionModel>? collections,
    String? selectedCollectionId,
    bool clearSelectedCollection = false,
    WatchlistFilterStatus? selectedTab,
    WatchlistSortOption? sortOption,
    String? searchQuery,
    Set<int>? mutatingMovieIds,
    String? errorMessage,
    bool clearError = false,
    String? feedbackMessage,
    bool clearFeedback = false,
  }) {
    return WatchlistState(
      status: status ?? this.status,
      movies: movies ?? this.movies,
      collections: collections ?? this.collections,
      selectedCollectionId: clearSelectedCollection
          ? null
          : (selectedCollectionId ?? this.selectedCollectionId),
      selectedTab: selectedTab ?? this.selectedTab,
      sortOption: sortOption ?? this.sortOption,
      searchQuery: searchQuery ?? this.searchQuery,
      mutatingMovieIds: mutatingMovieIds ?? this.mutatingMovieIds,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      feedbackMessage: clearFeedback
          ? null
          : (feedbackMessage ?? this.feedbackMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    movies,
    collections,
    selectedCollectionId,
    selectedTab,
    sortOption,
    searchQuery,
    mutatingMovieIds,
    errorMessage,
    feedbackMessage,
  ];
}
