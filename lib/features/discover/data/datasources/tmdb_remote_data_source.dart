import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/models/movie_summary.dart';
import '../models/paginated_movies_response.dart';

/// Remote data source communicating with TMDB REST endpoints.
class TmdbRemoteDataSource {
  TmdbRemoteDataSource(this._dioClient);

  final DioClient _dioClient;

  Future<PaginatedMoviesResponse> getTrendingMovies({int page = 1}) async {
    final data = await _dioClient.get(
      ApiConstants.trendingMoviesWeek,
      queryParameters: {'page': page, 'language': 'en-US'},
    );
    return PaginatedMoviesResponse.fromJson(data);
  }

  Future<PaginatedMoviesResponse> getPopularMovies({int page = 1}) async {
    final data = await _dioClient.get(
      ApiConstants.popularMovies,
      queryParameters: {'page': page, 'language': 'en-US'},
    );
    return PaginatedMoviesResponse.fromJson(data);
  }

  Future<PaginatedMoviesResponse> getTopRatedMovies({int page = 1}) async {
    final data = await _dioClient.get(
      ApiConstants.topRatedMovies,
      queryParameters: {'page': page, 'language': 'en-US'},
    );
    return PaginatedMoviesResponse.fromJson(data);
  }

  Future<PaginatedMoviesResponse> getNowPlayingMovies({int page = 1}) async {
    final data = await _dioClient.get(
      ApiConstants.nowPlayingMovies,
      queryParameters: {'page': page, 'language': 'en-US'},
    );
    return PaginatedMoviesResponse.fromJson(data);
  }

  Future<PaginatedMoviesResponse> getUpcomingMovies({int page = 1}) async {
    final data = await _dioClient.get(
      ApiConstants.upcomingMovies,
      queryParameters: {'page': page, 'language': 'en-US'},
    );
    return PaginatedMoviesResponse.fromJson(data);
  }

  Future<PaginatedMoviesResponse> discoverMoviesByGenre({
    required int genreId,
    int page = 1,
  }) async {
    final data = await _dioClient.get(
      ApiConstants.discoverMovies,
      queryParameters: {
        'with_genres': genreId,
        'sort_by': 'popularity.desc',
        'page': page,
        'language': 'en-US',
      },
    );
    return PaginatedMoviesResponse.fromJson(data);
  }

  Future<PaginatedMoviesResponse> discoverArabicMovies({int page = 1}) async {
    final data = await _dioClient.get(
      ApiConstants.discoverMovies,
      queryParameters: {
        'with_original_language': 'ar',
        'sort_by': 'popularity.desc',
        'page': page,
        'language': 'en-US',
      },
    );
    return PaginatedMoviesResponse.fromJson(data);
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<PaginatedMoviesResponse> discoverMoviesByCategoryAndGenre({
    required String categoryKey,
    required int genreId,
    int page = 1,
  }) async {
    final isArabic = genreId == -1;
    final now = DateTime.now();
    final queryParams = <String, dynamic>{
      if (isArabic)
        'with_original_language': 'ar'
      else
        'with_genres': genreId,
      'page': page,
      'language': 'en-US',
    };

    switch (categoryKey) {
      case 'top_rated':
        queryParams['sort_by'] = 'vote_average.desc';
        queryParams['vote_count.gte'] = isArabic ? 25 : 200;
      case 'now_playing':
        queryParams['sort_by'] = 'popularity.desc';
        queryParams['primary_release_date.gte'] = _formatDate(
          now.subtract(const Duration(days: 60)),
        );
        queryParams['primary_release_date.lte'] = _formatDate(now);
      case 'upcoming':
        queryParams['sort_by'] = 'popularity.desc';
        queryParams['primary_release_date.gte'] = _formatDate(
          now.add(const Duration(days: 1)),
        );
      case 'trending':
        queryParams['sort_by'] = 'popularity.desc';
        if (!isArabic && page == 1) {
          final results = await Future.wait([
            getTrendingMovies(page: 1),
            _dioClient.get(
              ApiConstants.discoverMovies,
              queryParameters: queryParams,
            ),
          ]);
          final trendingPage = results[0] as PaginatedMoviesResponse;
          final discoverPage = PaginatedMoviesResponse.fromJson(
            results[1] as Map<String, dynamic>,
          );
          final matchingTrending = trendingPage.results
              .where((m) => m.genreIds.contains(genreId))
              .toList();
          final seenIds = {for (final m in matchingTrending) m.id};
          final merged = [
            ...matchingTrending,
            ...discoverPage.results.where((m) => seenIds.add(m.id)),
          ];
          return PaginatedMoviesResponse(
            page: discoverPage.page,
            totalPages: discoverPage.totalPages,
            results: merged,
          );
        }
      case 'popular':
      default:
        queryParams['sort_by'] = 'popularity.desc';
    }

    final data = await _dioClient.get(
      ApiConstants.discoverMovies,
      queryParameters: queryParams,
    );
    return PaginatedMoviesResponse.fromJson(data);
  }

  Future<PaginatedMoviesResponse> searchMovies({
    required String query,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    final data = await _dioClient.get(
      ApiConstants.searchMovies,
      queryParameters: {
        'query': query.trim(),
        'page': page,
        'include_adult': false,
        'language': 'en-US',
      },
      cancelToken: cancelToken,
    );
    return PaginatedMoviesResponse.fromJson(data);
  }

  Future<Map<String, dynamic>> getMovieDetailsJson(int movieId) async {
    return _dioClient.get(
      ApiConstants.movieDetails(movieId),
      queryParameters: {'language': 'en-US'},
    );
  }

  Future<Map<String, dynamic>> getMovieCreditsJson(int movieId) async {
    return _dioClient.get(
      ApiConstants.movieCredits(movieId),
      queryParameters: {'language': 'en-US'},
    );
  }

  Future<Map<String, dynamic>> getMovieVideosJson(int movieId) async {
    return _dioClient.get(
      ApiConstants.movieVideos(movieId),
      queryParameters: {'language': 'en-US'},
    );
  }

  Future<PaginatedMoviesResponse> getMovieRecommendations(
    int movieId, {
    int page = 1,
  }) async {
    final data = await _dioClient.get(
      ApiConstants.movieRecommendations(movieId),
      queryParameters: {'page': page, 'language': 'en-US'},
    );
    return PaginatedMoviesResponse.fromJson(data);
  }

  Future<PaginatedMoviesResponse> getMovieWatchProvidersJsonRaw(
    int movieId,
  ) async {
    return PaginatedMoviesResponse(page: 1, totalPages: 1, results: const []);
  }

  Future<PaginatedMoviesResponse> discoverAnimeMovies({
    int? genreId,
    int page = 1,
  }) async {
    final genresParam =
        (genreId != null && genreId > 0 && genreId != 16)
        ? '16,$genreId'
        : '16';
    final data = await _dioClient.get(
      ApiConstants.discoverMovies,
      queryParameters: {
        'with_genres': genresParam,
        'with_original_language': 'ja',
        'sort_by': 'popularity.desc',
        'page': page,
        'language': 'en-US',
      },
    );
    return PaginatedMoviesResponse.fromJson(data, mediaType: MediaType.movie);
  }

  Future<PaginatedMoviesResponse> discoverAnimeSeries({
    int? genreId,
    int page = 1,
  }) async {
    final genresParam =
        (genreId != null && genreId > 0 && genreId != 16)
        ? '16,$genreId'
        : '16';
    final data = await _dioClient.get(
      ApiConstants.discoverTv,
      queryParameters: {
        'with_genres': genresParam,
        'with_original_language': 'ja',
        'sort_by': 'popularity.desc',
        'page': page,
        'language': 'en-US',
      },
    );
    return PaginatedMoviesResponse.fromJson(data, mediaType: MediaType.tv);
  }

  Future<Map<String, dynamic>> getTvDetailsJson(int tvId) async {
    return _dioClient.get(
      ApiConstants.tvDetails(tvId),
      queryParameters: {'language': 'en-US'},
    );
  }

  Future<Map<String, dynamic>> getTvCreditsJson(int tvId) async {
    return _dioClient.get(
      ApiConstants.tvCredits(tvId),
      queryParameters: {'language': 'en-US'},
    );
  }

  Future<Map<String, dynamic>> getTvVideosJson(int tvId) async {
    return _dioClient.get(
      ApiConstants.tvVideos(tvId),
      queryParameters: {'language': 'en-US'},
    );
  }

  Future<PaginatedMoviesResponse> getTvRecommendations(
    int tvId, {
    int page = 1,
  }) async {
    final data = await _dioClient.get(
      ApiConstants.tvRecommendations(tvId),
      queryParameters: {'page': page, 'language': 'en-US'},
    );
    return PaginatedMoviesResponse.fromJson(data, mediaType: MediaType.tv);
  }

  Future<Map<String, dynamic>> getTvWatchProvidersJson(int tvId) async {
    return _dioClient.get(ApiConstants.tvWatchProviders(tvId));
  }

  Future<Map<String, dynamic>> getMovieWatchProvidersJson(int movieId) async {
    return _dioClient.get(ApiConstants.movieWatchProviders(movieId));
  }

  Future<Map<String, dynamic>> getPersonDetailsJson(int personId) async {
    return _dioClient.get(
      ApiConstants.personDetails(personId),
      queryParameters: {'language': 'en-US'},
    );
  }

  Future<Map<String, dynamic>> getPersonMovieCreditsJson(int personId) async {
    return _dioClient.get(
      ApiConstants.personMovieCredits(personId),
      queryParameters: {'language': 'en-US'},
    );
  }
}
