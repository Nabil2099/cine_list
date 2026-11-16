import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
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
