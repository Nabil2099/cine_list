import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../data/models/watchlist_collection_model.dart';
import '../../data/models/watchlist_movie_model.dart';
import '../../data/repositories/watchlist_repository.dart';
import 'watchlist_state.dart';

/// Subscribes to the authenticated user's Firestore watchlist and performs CRUD.
class WatchlistCubit extends Cubit<WatchlistState> {
  WatchlistCubit(this._repository) : super(const WatchlistState());

  static const int maxUpNextMovies = 5;

  final WatchlistRepository _repository;
  StreamSubscription<List<WatchlistMovieModel>>? _subscription;
  StreamSubscription<List<WatchlistCollectionModel>>? _collectionsSubscription;
  String? _currentUid;

  void bindUser(String? uid) {
    if (uid == _currentUid && _subscription != null) return;
    _subscription?.cancel();
    _subscription = null;
    _collectionsSubscription?.cancel();
    _collectionsSubscription = null;
    _currentUid = uid;

    if (uid == null) {
      emit(const WatchlistState(status: WatchlistLoadStatus.loaded));
      return;
    }

    emit(
      state.copyWith(
        status: WatchlistLoadStatus.loading,
        clearError: true,
        clearFeedback: true,
      ),
    );

    _subscription = _repository
        .watchWatchlist(uid)
        .listen(
          (movies) {
            emit(
              state.copyWith(
                status: WatchlistLoadStatus.loaded,
                movies: movies,
                clearError: true,
              ),
            );
          },
          onError: (Object error) {
            final message = error is AppException
                ? error.message
                : 'Unable to sync watchlist. Please check your connection or Firestore rules.';
            emit(
              state.copyWith(
                status: WatchlistLoadStatus.error,
                errorMessage: message,
              ),
            );
          },
        );

    _collectionsSubscription = _repository.watchCollections(uid).listen((
      collections,
    ) {
      emit(state.copyWith(collections: collections));
    }, onError: (_) {});
  }

  void selectTab(WatchlistFilterStatus tab) {
    emit(state.copyWith(selectedTab: tab, clearFeedback: true));
  }

  void setSortOption(WatchlistSortOption option) {
    emit(state.copyWith(sortOption: option));
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  void clearFeedback() {
    emit(state.copyWith(clearFeedback: true, clearError: true));
  }

  void selectCollection(String? collectionId) {
    if (collectionId == null || collectionId == state.selectedCollectionId) {
      emit(state.copyWith(clearSelectedCollection: true));
    } else {
      emit(state.copyWith(selectedCollectionId: collectionId));
    }
  }

  Future<void> createCollection(String name) async {
    final uid = _currentUid;
    final trimmed = name.trim();
    if (uid == null || trimmed.isEmpty) return;
    try {
      final id = await _repository.createCollection(uid: uid, name: trimmed);
      emit(
        state.copyWith(
          selectedCollectionId: id,
          feedbackMessage: 'Created collection "$trimmed".',
          clearError: true,
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    }
  }

  Future<void> deleteCollection(String collectionId, {String? name}) async {
    final uid = _currentUid;
    if (uid == null) return;
    try {
      await _repository.deleteCollection(uid: uid, collectionId: collectionId);
      emit(
        state.copyWith(
          clearSelectedCollection: state.selectedCollectionId == collectionId,
          feedbackMessage: name != null
              ? 'Deleted "$name".'
              : 'Deleted collection.',
          clearError: true,
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    }
  }

  Future<void> toggleMovieInCollection(
    WatchlistCollectionModel collection,
    WatchlistMovieModel movie,
  ) async {
    final uid = _currentUid;
    if (uid == null) return;
    final currentlyIn = collection.containsMovie(movie.movieId);
    try {
      await _repository.toggleMovieInCollection(
        uid: uid,
        collectionId: collection.id,
        movieId: movie.movieId,
        currentlyInCollection: currentlyIn,
      );
    } on AppException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    }
  }

  Future<void> addToWatchlist(
    MovieSummary movie, {
    WatchlistFilterStatus status = WatchlistFilterStatus.wantToWatch,
  }) async {
    final uid = _currentUid;
    if (uid == null) {
      emit(state.copyWith(errorMessage: 'Please sign in to save movies.'));
      return;
    }

    _setMutating(movie.id, true);
    try {
      final item = WatchlistMovieModel.fromMovieSummary(movie, status: status);
      await _repository.saveMovie(uid, item);
      emit(
        state.copyWith(
          feedbackMessage: 'Added "${movie.title}" to Watchlist.',
          clearError: true,
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    } finally {
      _setMutating(movie.id, false);
    }
  }

  Future<void> toggleWatchedStatus(WatchlistMovieModel movie) async {
    final uid = _currentUid;
    if (uid == null) return;

    final nextStatus = movie.isWatched
        ? WatchlistFilterStatus.wantToWatch
        : WatchlistFilterStatus.watched;

    _setMutating(movie.movieId, true);
    try {
      await _repository.updateStatus(
        uid: uid,
        movieId: movie.movieId,
        status: nextStatus,
      );
      emit(
        state.copyWith(
          feedbackMessage: nextStatus == WatchlistFilterStatus.watched
              ? 'Marked "${movie.title}" as Watched.'
              : 'Moved "${movie.title}" to Want to Watch.',
          clearError: true,
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    } finally {
      _setMutating(movie.movieId, false);
    }
  }

  /// Marks [movie] as Watched (creating the watchlist entry directly if unsaved)
  /// and optionally updates its personal rating, note, and runtime.
  Future<void> logWatchedMovie(
    MovieSummary movie, {
    int? runtimeMinutes,
    int? userRating,
    String? userNote,
    bool updateReviewFields = false,
  }) async {
    final uid = _currentUid;
    if (uid == null) {
      emit(
        state.copyWith(errorMessage: 'Please sign in to log watched movies.'),
      );
      return;
    }

    _setMutating(movie.id, true);
    try {
      final existing = state.findById(movie.id);
      if (existing == null) {
        final item = WatchlistMovieModel.fromMovieSummary(
          movie,
          status: WatchlistFilterStatus.watched,
          watchedAt: DateTime.now(),
          runtimeMinutes: runtimeMinutes,
          userRating: userRating,
          userNote: userNote?.trim().isNotEmpty == true
              ? userNote!.trim()
              : null,
        );
        await _repository.saveMovie(uid, item);
      } else {
        await _repository.markWatchedWithReview(
          uid: uid,
          movieId: movie.id,
          userRating: updateReviewFields ? userRating : existing.userRating,
          userNote: updateReviewFields ? userNote : existing.userNote,
          runtimeMinutes: runtimeMinutes ?? existing.runtimeMinutes,
        );
      }
      emit(
        state.copyWith(
          feedbackMessage: updateReviewFields
              ? 'Saved rating & review for "${movie.title}".'
              : 'Marked "${movie.title}" as Watched.',
          clearError: true,
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    } finally {
      _setMutating(movie.id, false);
    }
  }

  Future<void> updateReview({
    required int movieId,
    required String title,
    int? userRating,
    String? userNote,
  }) async {
    final uid = _currentUid;
    if (uid == null) return;

    _setMutating(movieId, true);
    try {
      await _repository.updateReview(
        uid: uid,
        movieId: movieId,
        userRating: userRating,
        userNote: userNote,
      );
      emit(
        state.copyWith(
          feedbackMessage: 'Saved review for "$title".',
          clearError: true,
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    } finally {
      _setMutating(movieId, false);
    }
  }

  Future<void> toggleUpNext(WatchlistMovieModel movie) async {
    final uid = _currentUid;
    if (uid == null) return;

    final nextUpNext = !movie.isUpNext;
    if (nextUpNext && state.upNextCount >= maxUpNextMovies) {
      emit(
        state.copyWith(
          feedbackMessage: 'Up Next queue is full (max $maxUpNextMovies movies).',
          clearError: true,
        ),
      );
      return;
    }

    _setMutating(movie.movieId, true);
    try {
      await _repository.toggleUpNext(
        uid: uid,
        movieId: movie.movieId,
        isUpNext: nextUpNext,
      );
      emit(
        state.copyWith(
          feedbackMessage: nextUpNext
              ? 'Pinned "${movie.title}" to Up Next.'
              : 'Removed "${movie.title}" from Up Next.',
          clearError: true,
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    } finally {
      _setMutating(movie.movieId, false);
    }
  }

  Future<void> logRewatch(WatchlistMovieModel movie) async {
    final uid = _currentUid;
    if (uid == null) return;

    final nextCount = movie.rewatchCount + 1;
    _setMutating(movie.movieId, true);
    try {
      await _repository.incrementRewatch(
        uid: uid,
        movieId: movie.movieId,
        nextCount: nextCount,
      );
      emit(
        state.copyWith(
          feedbackMessage: 'Logged rewatch #$nextCount for "${movie.title}".',
          clearError: true,
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    } finally {
      _setMutating(movie.movieId, false);
    }
  }

  Future<({String collectionName, int addedCount})?> cloneCuratedList({
    required String title,
    required List<MovieSummary> movies,
  }) async {
    final uid = _currentUid;
    if (uid == null) {
      emit(state.copyWith(errorMessage: 'Please sign in to clone lists.'));
      return null;
    }
    final existingNames = state.collections
        .map((c) => c.name.trim().toLowerCase())
        .toSet();
    final baseName = title.trim().isEmpty ? 'Imported List' : title.trim();
    var targetName = baseName.length > 40 ? baseName.substring(0, 40) : baseName;
    if (existingNames.contains(targetName.toLowerCase())) {
      const suffix = ' (Copy)';
      final maxBase = 40 - suffix.length;
      final prefix = baseName.length > maxBase
          ? baseName.substring(0, maxBase)
          : baseName;
      targetName = '$prefix$suffix';
    }

    final savedIds = state.movies.map((m) => m.movieId).toSet();
    final toSave = movies
        .where((m) => !savedIds.contains(m.id))
        .map((m) => WatchlistMovieModel.fromMovieSummary(m))
        .toList();
    final allIds = movies.map((m) => m.id).toSet().toList();

    try {
      final id = await _repository.cloneCollectionWithMovies(
        uid: uid,
        name: targetName,
        moviesToSave: toSave,
        allMovieIds: allIds,
      );
      emit(
        state.copyWith(
          selectedCollectionId: id,
          feedbackMessage: toSave.isNotEmpty
              ? 'Cloned "$targetName" (${toSave.length} new movies added).'
              : 'Cloned "$targetName" to your collections.',
          clearError: true,
        ),
      );
      return (collectionName: targetName, addedCount: toSave.length);
    } on AppException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
      return null;
    }
  }

  Future<void> removeFromWatchlist(int movieId, {String? title}) async {
    final uid = _currentUid;
    if (uid == null) return;

    _setMutating(movieId, true);
    try {
      await _repository.removeMovie(uid: uid, movieId: movieId);
      emit(
        state.copyWith(
          feedbackMessage: title != null
              ? 'Removed "$title" from Watchlist.'
              : 'Removed from Watchlist.',
          clearError: true,
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    } finally {
      _setMutating(movieId, false);
    }
  }

  void _setMutating(int movieId, bool active) {
    final next = Set<int>.from(state.mutatingMovieIds);
    if (active) {
      next.add(movieId);
    } else {
      next.remove(movieId);
    }
    emit(state.copyWith(mutatingMovieIds: next));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    _collectionsSubscription?.cancel();
    return super.close();
  }
}
