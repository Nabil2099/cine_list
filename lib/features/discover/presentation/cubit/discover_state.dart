import 'package:equatable/equatable.dart';

import '../../../../shared/models/movie_summary.dart';
import '../../data/repositories/discover_repository.dart';

enum DiscoverStatus { initial, loading, loaded, empty, error }

class DiscoverState extends Equatable {
  const DiscoverState({
    this.status = DiscoverStatus.initial,
    this.selectedCategory = DiscoverCategory.trending,
    this.selectedGenreId,
    this.movies = const [],
    this.searchQuery = '',
    this.currentPage = 1,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.isAuthConfigError = false,
  });

  final DiscoverStatus status;
  final DiscoverCategory selectedCategory;
  final int? selectedGenreId;
  final List<MovieSummary> movies;
  final String searchQuery;
  final int currentPage;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;
  final bool isAuthConfigError;

  bool get isSearching => searchQuery.trim().isNotEmpty;

  DiscoverState copyWith({
    DiscoverStatus? status,
    DiscoverCategory? selectedCategory,
    int? selectedGenreId,
    bool clearGenre = false,
    List<MovieSummary>? movies,
    String? searchQuery,
    int? currentPage,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    bool? isAuthConfigError,
  }) {
    return DiscoverState(
      status: status ?? this.status,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedGenreId: clearGenre
          ? null
          : (selectedGenreId ?? this.selectedGenreId),
      movies: movies ?? this.movies,
      searchQuery: searchQuery ?? this.searchQuery,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isAuthConfigError: isAuthConfigError ?? this.isAuthConfigError,
    );
  }

  @override
  List<Object?> get props => [
    status,
    selectedCategory,
    selectedGenreId,
    movies,
    searchQuery,
    currentPage,
    hasMore,
    isLoadingMore,
    errorMessage,
    isAuthConfigError,
  ];
}
