import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/storage/preferences_service.dart';
import '../../../../core/utils/debouncer.dart';
import '../../data/repositories/discover_repository.dart';
import 'discover_state.dart';

/// Manages movie discovery categories, debounced search, pagination, and errors.
class DiscoverCubit extends Cubit<DiscoverState> {
  DiscoverCubit(
    this._repository, {
    PreferencesService? preferencesService,
    Duration? debounceDuration,
  }) : _preferencesService = preferencesService,
       _debouncer = Debouncer(
         delay: debounceDuration ?? AppConstants.searchDebounce,
       ),
       super(
         DiscoverState(
           selectedCategory: preferencesService != null
               ? DiscoverCategory.fromKey(
                   preferencesService.selectedDiscoverCategory,
                 )
               : DiscoverCategory.trending,
         ),
       );

  final DiscoverRepository _repository;
  final PreferencesService? _preferencesService;
  final Debouncer _debouncer;

  CancelToken? _searchCancelToken;
  int _activeRequestId = 0;

  Future<void> loadInitial() async {
    await _loadCategory(state.selectedCategory, page: 1);
  }

  Future<void> selectCategory(DiscoverCategory category) async {
    if (category == state.selectedCategory &&
        state.selectedGenreId == null &&
        !state.isSearching &&
        state.status == DiscoverStatus.loaded) {
      return;
    }

    _debouncer.cancel();
    _cancelOngoingSearch();
    await _preferencesService?.setSelectedDiscoverCategory(category.key);

    emit(
      state.copyWith(
        selectedCategory: category,
        clearGenre: true,
        searchQuery: '',
        clearError: true,
      ),
    );
    await _loadCategory(category, page: 1);
  }

  Future<void> selectGenre(int? genreId) async {
    if (genreId == state.selectedGenreId && !state.isSearching) return;

    _debouncer.cancel();
    _cancelOngoingSearch();

    if (genreId == null) {
      emit(state.copyWith(clearGenre: true, searchQuery: '', clearError: true));
      await _loadCategory(state.selectedCategory, page: 1);
      return;
    }

    emit(
      state.copyWith(
        selectedGenreId: genreId,
        searchQuery: '',
        clearError: true,
      ),
    );
    await _loadGenre(genreId, page: 1);
  }

  void onSearchChanged(String query) {
    final trimmed = query.trim();
    emit(state.copyWith(searchQuery: query, clearError: true));

    if (trimmed.isEmpty) {
      _debouncer.cancel();
      _cancelOngoingSearch();
      _loadCategory(state.selectedCategory, page: 1);
      return;
    }

    _debouncer.run(() {
      _performSearch(trimmed, page: 1);
    });
  }

  void clearSearch() {
    if (!state.isSearching && state.searchQuery.isEmpty) return;
    _debouncer.cancel();
    _cancelOngoingSearch();
    emit(state.copyWith(searchQuery: '', clearError: true));
    _loadCategory(state.selectedCategory, page: 1);
  }

  Future<void> retry() async {
    if (state.isSearching) {
      await _performSearch(state.searchQuery.trim(), page: 1);
    } else if (state.selectedGenreId != null) {
      await _loadGenre(state.selectedGenreId!, page: 1);
    } else {
      await _loadCategory(state.selectedCategory, page: 1);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore ||
        state.isLoadingMore ||
        state.status == DiscoverStatus.loading) {
      return;
    }

    final nextPage = state.currentPage + 1;
    emit(state.copyWith(isLoadingMore: true));

    if (state.isSearching) {
      await _performSearch(state.searchQuery.trim(), page: nextPage);
    } else if (state.selectedGenreId != null) {
      await _loadGenre(state.selectedGenreId!, page: nextPage);
    } else {
      await _loadCategory(state.selectedCategory, page: nextPage);
    }
  }

  Future<void> _loadGenre(int genreId, {required int page}) async {
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
      final response = await _repository.fetchByGenre(genreId, page: page);
      if (requestId != _activeRequestId || isClosed) return;

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
      if (requestId != _activeRequestId || isClosed) return;
      _handleError(e, isFirstPage: page == 1);
    } catch (_) {
      if (requestId != _activeRequestId || isClosed) return;
      _handleError(
        const NetworkException('Unable to load genre movies right now.'),
        isFirstPage: page == 1,
      );
    }
  }

  Future<void> _loadCategory(
    DiscoverCategory category, {
    required int page,
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
      final response = await _repository.fetchByCategory(category, page: page);
      if (requestId != _activeRequestId || isClosed) return;

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
      if (requestId != _activeRequestId || isClosed) return;
      _handleError(e, isFirstPage: page == 1);
    } catch (_) {
      if (requestId != _activeRequestId || isClosed) return;
      _handleError(
        const NetworkException('Unable to load movies right now.'),
        isFirstPage: page == 1,
      );
    }
  }

  Future<void> _performSearch(String query, {required int page}) async {
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
      if (requestId != _activeRequestId || isClosed) return;

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
      if (e.code == 'cancelled' || requestId != _activeRequestId || isClosed) {
        return;
      }
      _handleError(e, isFirstPage: page == 1);
    } catch (_) {
      if (requestId != _activeRequestId || isClosed) return;
      _handleError(
        const NetworkException('Search failed. Please try again.'),
        isFirstPage: page == 1,
      );
    }
  }

  void _handleError(AppException e, {required bool isFirstPage}) {
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
    _debouncer.dispose();
    _cancelOngoingSearch();
    return super.close();
  }
}
