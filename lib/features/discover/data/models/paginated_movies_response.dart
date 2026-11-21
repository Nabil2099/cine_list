import 'package:equatable/equatable.dart';

import '../../../../shared/models/movie_summary.dart';
import 'movie_model.dart';

/// Paginated TMDB movie/series list response.
class PaginatedMoviesResponse extends Equatable {
  const PaginatedMoviesResponse({
    required this.page,
    required this.totalPages,
    required this.results,
  });

  factory PaginatedMoviesResponse.fromJson(
    Map<String, dynamic> json, {
    MediaType? mediaType,
  }) {
    final rawResults = json['results'];
    final movies = rawResults is List
        ? rawResults
              .whereType<Map>()
              .map(
                (e) => MovieModel.fromJson(
                  Map<String, dynamic>.from(e),
                  mediaType: mediaType,
                ),
              )
              .where((m) => m.id > 0)
              .toList()
        : const <MovieModel>[];

    return PaginatedMoviesResponse(
      page: (json['page'] as num?)?.toInt() ?? 1,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
      results: movies,
    );
  }

  final int page;
  final int totalPages;
  final List<MovieModel> results;

  bool get hasMore => page < totalPages;

  @override
  List<Object?> get props => [page, totalPages, results];
}
