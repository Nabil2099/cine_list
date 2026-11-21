import 'package:dio/dio.dart';

import '../datasources/tmdb_remote_data_source.dart';
import '../models/movie_model.dart';
import '../models/paginated_movies_response.dart';

enum DiscoverCategory {
  trending('trending', 'Trending'),
  anime('anime', 'Anime'),
  nowPlaying('now_playing', 'Now Playing'),
  upcoming('upcoming', 'Upcoming'),
  popular('popular', 'Popular'),
  topRated('top_rated', 'Top Rated');

  const DiscoverCategory(this.key, this.label);

  final String key;
  final String label;

  static DiscoverCategory fromKey(String key) {
    return DiscoverCategory.values.firstWhere(
      (c) => c.key == key,
      orElse: () => DiscoverCategory.trending,
    );
  }
}

enum AnimeMediaFilter {
  all('All'),
  series('Series'),
  movies('Movies');

  const AnimeMediaFilter(this.label);

  final String label;
}

class DiscoverGenre {
  const DiscoverGenre(this.id, this.label);

  static const int arabicGenreId = -1;

  final int id;
  final String label;

  static const List<DiscoverGenre> defaults = [
    DiscoverGenre(arabicGenreId, 'Arabic'),
    DiscoverGenre(28, 'Action'),
    DiscoverGenre(878, 'Sci-Fi'),
    DiscoverGenre(53, 'Thriller'),
    DiscoverGenre(35, 'Comedy'),
    DiscoverGenre(18, 'Drama'),
    DiscoverGenre(27, 'Horror'),
    DiscoverGenre(16, 'Animation'),
    DiscoverGenre(10749, 'Romance'),
    DiscoverGenre(80, 'Crime'),
    DiscoverGenre(9648, 'Mystery'),
    DiscoverGenre(12, 'Adventure'),
    DiscoverGenre(14, 'Fantasy'),
    DiscoverGenre(99, 'Documentary'),
  ];
}

/// Repository for movie discovery, genre filtering, and search with short-lived
/// in-memory TTL caching to keep tab & genre switches instantaneous.
class DiscoverRepository {
  DiscoverRepository(
    this._remoteDataSource, {
    this.cacheTtl = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final TmdbRemoteDataSource _remoteDataSource;
  final Duration cacheTtl;
  final DateTime Function() _clock;
  final Map<String, _DiscoverCacheEntry> _cache = {};

  Future<PaginatedMoviesResponse> fetchByCategory(
    DiscoverCategory category, {
    int page = 1,
    bool forceRefresh = false,
  }) async {
    final key = 'cat:${category.key}:$page';
    if (!forceRefresh) {
      final cached = _readCache(key);
      if (cached != null) return cached;
    }

    final response = switch (category) {
      DiscoverCategory.trending =>
        await _remoteDataSource.getTrendingMovies(page: page),
      DiscoverCategory.nowPlaying =>
        await _remoteDataSource.getNowPlayingMovies(page: page),
      DiscoverCategory.upcoming =>
        await _remoteDataSource.getUpcomingMovies(page: page),
      DiscoverCategory.popular =>
        await _remoteDataSource.getPopularMovies(page: page),
      DiscoverCategory.topRated =>
        await _remoteDataSource.getTopRatedMovies(page: page),
      DiscoverCategory.anime => await fetchAnime(
        filter: AnimeMediaFilter.all,
        page: page,
        forceRefresh: forceRefresh,
      ),
    };
    _writeCache(key, response);
    return response;
  }

  Future<PaginatedMoviesResponse> fetchAnime({
    required AnimeMediaFilter filter,
    int? genreId,
    int page = 1,
    bool forceRefresh = false,
  }) async {
    if (genreId == DiscoverGenre.arabicGenreId) {
      return const PaginatedMoviesResponse(
        page: 1,
        totalPages: 1,
        results: [],
      );
    }
    final key = 'anime:${filter.name}:${genreId ?? 'all'}:$page';
    if (!forceRefresh) {
      final cached = _readCache(key);
      if (cached != null) return cached;
    }

    final PaginatedMoviesResponse response;
    switch (filter) {
      case AnimeMediaFilter.series:
        response = await _remoteDataSource.discoverAnimeSeries(
          genreId: genreId,
          page: page,
        );
      case AnimeMediaFilter.movies:
        response = await _remoteDataSource.discoverAnimeMovies(
          genreId: genreId,
          page: page,
        );
      case AnimeMediaFilter.all:
        final pages = await Future.wait([
          _remoteDataSource.discoverAnimeSeries(genreId: genreId, page: page),
          _remoteDataSource.discoverAnimeMovies(genreId: genreId, page: page),
        ]);
        final seriesList = pages[0].results;
        final moviesList = pages[1].results;
        final merged = <MovieModel>[];
        final maxLen = seriesList.length > moviesList.length
            ? seriesList.length
            : moviesList.length;
        for (var i = 0; i < maxLen; i++) {
          if (i < seriesList.length) merged.add(seriesList[i]);
          if (i < moviesList.length) merged.add(moviesList[i]);
        }
        final totalPages = pages[0].totalPages > pages[1].totalPages
            ? pages[0].totalPages
            : pages[1].totalPages;
        response = PaginatedMoviesResponse(
          page: page,
          totalPages: totalPages,
          results: merged,
        );
    }
    _writeCache(key, response);
    return response;
  }

  Future<PaginatedMoviesResponse> fetchByGenre(
    int genreId, {
    DiscoverCategory? category,
    int page = 1,
    bool forceRefresh = false,
  }) async {
    final key = category == null
        ? 'genre:$genreId:$page'
        : 'genre:${category.key}:$genreId:$page';
    if (!forceRefresh) {
      final cached = _readCache(key);
      if (cached != null) return cached;
    }

    final PaginatedMoviesResponse response;
    if (category != null) {
      response = await _remoteDataSource.discoverMoviesByCategoryAndGenre(
        categoryKey: category.key,
        genreId: genreId,
        page: page,
      );
    } else if (genreId == DiscoverGenre.arabicGenreId) {
      response = await _remoteDataSource.discoverArabicMovies(page: page);
    } else {
      response = await _remoteDataSource.discoverMoviesByGenre(
        genreId: genreId,
        page: page,
      );
    }
    _writeCache(key, response);
    return response;
  }

  Future<PaginatedMoviesResponse> searchMovies({
    required String query,
    int page = 1,
    CancelToken? cancelToken,
  }) {
    return _remoteDataSource.searchMovies(
      query: query,
      page: page,
      cancelToken: cancelToken,
    );
  }

  PaginatedMoviesResponse? _readCache(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (_clock().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      return null;
    }
    return entry.response;
  }

  void _writeCache(String key, PaginatedMoviesResponse response) {
    _cache[key] = _DiscoverCacheEntry(
      response: response,
      expiresAt: _clock().add(cacheTtl),
    );
  }
}

class _DiscoverCacheEntry {
  const _DiscoverCacheEntry({
    required this.response,
    required this.expiresAt,
  });

  final PaginatedMoviesResponse response;
  final DateTime expiresAt;
}
