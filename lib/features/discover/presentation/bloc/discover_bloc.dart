import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/storage/preferences_service.dart';
import '../../../../core/utils/bloc_transformers.dart';
import '../../data/repositories/discover_repository.dart';
import '../cubit/discover_state.dart';
import 'discover_event.dart';

export '../cubit/discover_state.dart';
export 'discover_event.dart';

/// Manages movie discovery categories, debounced search cancellation, and pagination.
class DiscoverBloc extends Bloc<DiscoverEvent, DiscoverState> {
  DiscoverBloc(
    this._repository, {
    PreferencesService? preferencesService,
    Duration? debounceDuration,
  }) : _preferencesService = preferencesService,
       _debounceDuration = debounceDuration ?? AppConstants.searchDebounce,
       super(
         DiscoverState(
           selectedCategory: preferencesService != null
               ? DiscoverCategory.fromKey(
                   preferencesService.selectedDiscoverCategory,
                 )
               : DiscoverCategory.trending,
         ),
       ) {
    on<DiscoverFeedLoadEvent>(_onFeedLoadEvent, transformer: restartable());
    on<DiscoverNextPageLoaded>(_onNextPageLoaded, transformer: droppable());
  }

  final DiscoverRepository _repository;
  final PreferencesService? _preferencesService;
  final Duration _debounceDuration;

  CancelToken? _searchCancelToken;
  int _activeRequestId = 0;

  Future<void> _onFeedLoadEvent(
    DiscoverFeedLoadEvent event,
    Emitter<DiscoverState> emit,
  ) async {
    switch (event) {
      case DiscoverInitialLoaded():
        await _loadCategory(state.selectedCategory, page: 1, emit: emit);
      case DiscoverCategorySelected(:final category):
        await _selectCategory(category, emit);
      case DiscoverGenreSelected(:final genreId):
        await _selectGenre(genreId, emit);
      case DiscoverSearchChanged(:final query):
        await _searchChanged(query, emit);
      case DiscoverSearchCleared():
        await _clearSearch(emit);
      case DiscoverRetried():
        await _retry(emit);
    }
  }

  Future<void> _selectCategory(
    DiscoverCategory category,
    Emitter<DiscoverState> emit,
  ) async {
    if (category == state.selectedCategory &&
        state.selectedGenreId == null &&
        !state.isSearching &&
        state.status == DiscoverStatus.loaded) {
      return;
    }

    _cancelOngoingSearch();
    await _preferencesService?.setSelectedDiscoverCategory(category.key);
    if (emit.isDone) return;

    emit(
      state.copyWith(
        selectedCategory: category,
        clearGenre: true,
        searchQuery: '',
        clearError: true,
      ),
    );
    await _loadCategory(category, page: 1, emit: emit);
  }

  Future<void> _selectGenre(int? genreId, Emitter<DiscoverState> emit) async {
    if (genreId == state.selectedGenreId && !state.isSearching) return;

    _cancelOngoingSearch();

    if (genreId == null) {
      emit(state.copyWith(clearGenre: true, searchQuery: '', clearError: true));
      await _loadCategory(state.selectedCategory, page: 1, emit: emit);
      return;
    }

    emit(
      state.copyWith(
        selectedGenreId: genreId,
        searchQuery: '',
        clearError: true,
      ),
    );
    await _loadGenre(genreId, page: 1, emit: emit);
  }

  Future<void> _searchChanged(String query, Emitter<DiscoverState> emit) async {
    final trimmed = query.trim();
    emit(state.copyWith(searchQuery: query, clearError: true));

    if (trimmed.isEmpty) {
      _cancelOngoingSearch();
      await _loadCategory(state.selectedCategory, page: 1, emit: emit);
      return;
    }

    await Future<void>.delayed(_debounceDuration);
    if (emit.isDone || isClosed) return;
    await _performSearch(trimmed, page: 1, emit: emit);
  }

  Future<void> _clearSearch(Emitter<DiscoverState> emit) async {
    if (!state.isSearching && state.searchQuery.isEmpty) return;
    _cancelOngoingSearch();
    emit(state.copyWith(searchQuery: '', clearError: true));
    await _loadCategory(state.selectedCategory, page: 1, emit: emit);
  }

  Future<void> _retry(Emitter<DiscoverState> emit) async {
    if (state.isSearching) {
      await _performSearch(state.searchQuery.trim(), page: 1, emit: emit);
    } else if (state.selectedGenreId != null) {
      await _loadGenre(
        state.selectedGenreId!,
        page: 1,
        emit: emit,
        forceRefresh: true,
      );
    } else {
      await _loadCategory(
        state.selectedCategory,
        page: 1,
        emit: emit,
        forceRefresh: true,
      );
    }
  }

  Future<void> _onNextPageLoaded(
    DiscoverNextPageLoaded event,
    Emitter<DiscoverState> emit,
  ) async {
    if (!state.hasMore ||
        state.isLoadingMore ||
        state.status == DiscoverStatus.loading) {
      return;
    }

    final nextPage = state.currentPage + 1;
    emit(state.copyWith(isLoadingMore: true));

    if (state.isSearching) {
      await _performSearch(
        state.searchQuery.trim(),
        page: nextPage,
        emit: emit,
      );
    } else if (state.selectedGenreId != null) {
      await _loadGenre(state.selectedGenreId!, page: nextPage, emit: emit);
    } else {
      await _loadCategory(state.selectedCategory, page: nextPage, emit: emit);
    }
  }

  Future<void> _loadGenre(
    int genreId, {
    required int page,
    required Emitter<DiscoverState> emit,
    bool forceRefresh = false,
  }) async {
    final requestId = ++_activeRequestId;
    if (page == 1) {
      emit(
        state.copyWith(
          status: DiscoverStatus.loading,
          isLoadingMore: false,
          clearError: true,
        ),
      );
    }

    try {
      final response = forceRefresh
          ? await _repository.fetchByGenre(
              genreId,
              page: page,
              forceRefresh: true,
            )
          : await _repository.fetchByGenre(genreId, page: page);
      if (requestId != _activeRequestId || emit.isDone || isClosed) return;

      final combined = page == 1
          ? response.results
          : [...state.movies, ...response.results];

      emit(
        state.copyWith(
          status: combined.isEmpty
              ? DiscoverStatus.empty
              : DiscoverStatus.loaded,
          movies: combined,
          currentPage: response.page,
          hasMore: response.hasMore,
          isLoadingMore: false,
          clearError: true,
          isAuthConfigError: false,
        ),
      );
    } on AppException catch (e) {
      if (requestId != _activeRequestId || emit.isDone || isClosed) return;
      _handleError(e, isFirstPage: page == 1, emit: emit);
    } catch (_) {
      if (requestId != _activeRequestId || emit.isDone || isClosed) return;
      _handleError(
        const NetworkException('Unable to load genre movies right now.'),
        isFirstPage: page == 1,
        emit: emit,
      );
    }
  }

  Future<void> _loadCategory(
    DiscoverCategory category, {
    required int page,
    required Emitter<DiscoverState> emit,
    bool forceRefresh = false,
  }) async {
    final requestId = ++_activeRequestId;
    if (page == 1) {
      emit(
        state.copyWith(
          status: DiscoverStatus.loading,
          isLoadingMore: false,
          clearError: true,
        ),
      );
    }

    try {
      final response = forceRefresh
          ? await _repository.fetchByCategory(
              category,
              page: page,
              forceRefresh: true,
            )
          : await _repository.fetchByCategory(category, page: page);
      if (requestId != _activeRequestId || emit.isDone || isClosed) return;

      final combined = page == 1
          ? response.results
          : [...state.movies, ...response.results];

      emit(
        state.copyWith(
          status: combined.isEmpty
              ? DiscoverStatus.empty
              : DiscoverStatus.loaded,
          movies: combined,
          currentPage: response.page,
          hasMore: response.hasMore,
          isLoadingMore: false,
          clearError: true,
          isAuthConfigError: false,
        ),
      );
    } on AppException catch (e) {
      if (requestId != _activeRequestId || emit.isDone || isClosed) return;
      _handleError(e, isFirstPage: page == 1, emit: emit);
    } catch (_) {
      if (requestId != _activeRequestId || emit.isDone || isClosed) return;
      _handleError(
        const NetworkException('Unable to load movies right now.'),
        isFirstPage: page == 1,
        emit: emit,
      );
    }
  }

  Future<void> _performSearch(
    String query, {
    required int page,
    required Emitter<DiscoverState> emit,
  }) async {
    final requestId = ++_activeRequestId;
    _cancelOngoingSearch();
    _searchCancelToken = CancelToken();

    if (page == 1) {
      emit(
        state.copyWith(
          status: DiscoverStatus.loading,
          isLoadingMore: false,
          clearError: true,
        ),
      );
    }

    try {
      final response = await _repository.searchMovies(
        query: query,
        page: page,
        cancelToken: _searchCancelToken,
      );
      if (requestId != _activeRequestId || emit.isDone || isClosed) return;

      final combined = page == 1
          ? response.results
          : [...state.movies, ...response.results];

      emit(
        state.copyWith(
          status: combined.isEmpty
              ? DiscoverStatus.empty
              : DiscoverStatus.loaded,
          movies: combined,
          currentPage: response.page,
          hasMore: response.hasMore,
          isLoadingMore: false,
          clearError: true,
          isAuthConfigError: false,
        ),
      );
    } on AppException catch (e) {
      if (e.code == 'cancelled' ||
          requestId != _activeRequestId ||
          emit.isDone ||
          isClosed) {
        return;
      }
      _handleError(e, isFirstPage: page == 1, emit: emit);
    } catch (_) {
      if (requestId != _activeRequestId || emit.isDone || isClosed) return;
      _handleError(
        const NetworkException('Search failed. Please try again.'),
        isFirstPage: page == 1,
        emit: emit,
      );
    }
  }

  void _handleError(
    AppException e, {
    required bool isFirstPage,
    required Emitter<DiscoverState> emit,
  }) {
    if (!isFirstPage && state.movies.isNotEmpty) {
      emit(
        state.copyWith(
          isLoadingMore: false,
          errorMessage: e.message,
          isAuthConfigError: e.isAuthConfigError,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: DiscoverStatus.error,
        movies: const [],
        isLoadingMore: false,
        errorMessage: e.message,
        isAuthConfigError: e.isAuthConfigError,
      ),
    );
  }

  void _cancelOngoingSearch() {
    if (_searchCancelToken != null && !_searchCancelToken!.isCancelled) {
      _searchCancelToken!.cancel('Superseded by newer request');
    }
    _searchCancelToken = null;
  }

  @override
  Future<void> close() {
    _cancelOngoingSearch();
    return super.close();
  }
}
