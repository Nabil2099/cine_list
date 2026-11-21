import 'dart:collection';

import '../../../../shared/models/movie_summary.dart';
import '../../../discover/data/datasources/tmdb_remote_data_source.dart';
import '../../../discover/data/models/movie_model.dart';
import '../models/cast_member_model.dart';
import '../models/movie_details_model.dart';
import '../models/movie_video_model.dart';
import '../models/person_details_model.dart';
import '../models/watch_provider_model.dart';

/// Repository fetching full movie details, cast, trailers, providers, and
/// recommendations from TMDB with a bounded 10-minute LRU cache.
class MovieDetailsRepository {
  MovieDetailsRepository(
    this._remoteDataSource, {
    this.cacheTtl = const Duration(minutes: 10),
    this.maxCacheEntries = 25,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final TmdbRemoteDataSource _remoteDataSource;
  final Duration cacheTtl;
  final int maxCacheEntries;
  final DateTime Function() _clock;
  final LinkedHashMap<String, _MovieDetailsCacheEntry> _movieCache =
      LinkedHashMap<String, _MovieDetailsCacheEntry>();

  _MovieDetailsCacheEntry _entryFor(
    int movieId, {
    MediaType mediaType = MediaType.movie,
  }) {
    final cacheKey = '${mediaType.name}:$movieId';
    final existing = _movieCache.remove(cacheKey);
    if (existing != null && !_clock().isAfter(existing.expiresAt)) {
      _movieCache[cacheKey] = existing;
      return existing;
    }
    final created = _MovieDetailsCacheEntry(
      expiresAt: _clock().add(cacheTtl),
    );
    _movieCache[cacheKey] = created;
    if (_movieCache.length > maxCacheEntries) {
      _movieCache.remove(_movieCache.keys.first);
    }
    return created;
  }

  Future<MovieDetailsModel> getMovieDetails(
    int movieId, {
    MediaType mediaType = MediaType.movie,
  }) async {
    final entry = _entryFor(movieId, mediaType: mediaType);
    if (entry.details != null) return entry.details!;
    final json = mediaType == MediaType.tv
        ? await _remoteDataSource.getTvDetailsJson(movieId)
        : await _remoteDataSource.getMovieDetailsJson(movieId);
    final details = MovieDetailsModel.fromJson(json, mediaType: mediaType);
    entry.details = details;
    return details;
  }

  Future<List<CastMemberModel>> getMovieCast(
    int movieId, {
    MediaType mediaType = MediaType.movie,
  }) async {
    final entry = _entryFor(movieId, mediaType: mediaType);
    if (entry.cast != null) return entry.cast!;
    final json = mediaType == MediaType.tv
        ? await _remoteDataSource.getTvCreditsJson(movieId)
        : await _remoteDataSource.getMovieCreditsJson(movieId);
    final rawCast = json['cast'];
    if (rawCast is! List) return const [];
    final cast = rawCast
        .whereType<Map>()
        .take(12)
        .map((e) => CastMemberModel.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.id > 0)
        .toList();
    entry.cast = cast;
    return cast;
  }

  Future<MovieVideoModel?> getMovieTrailer(
    int movieId, {
    MediaType mediaType = MediaType.movie,
  }) async {
    final entry = _entryFor(movieId, mediaType: mediaType);
    if (entry.hasTrailer) return entry.trailer;
    final json = mediaType == MediaType.tv
        ? await _remoteDataSource.getTvVideosJson(movieId)
        : await _remoteDataSource.getMovieVideosJson(movieId);
    final rawResults = json['results'];
    if (rawResults is! List) {
      entry
        ..hasTrailer = true
        ..trailer = null;
      return null;
    }

    final youtubeVideos = rawResults
        .whereType<Map>()
        .map((e) => MovieVideoModel.fromJson(Map<String, dynamic>.from(e)))
        .where((v) => v.isYouTube)
        .toList();

    if (youtubeVideos.isEmpty) {
      entry
        ..hasTrailer = true
        ..trailer = null;
      return null;
    }

    final selected = youtubeVideos.firstWhere(
      (v) => v.isTrailer && v.official,
      orElse: () => youtubeVideos.firstWhere(
        (v) => v.isTrailer,
        orElse: () => youtubeVideos.firstWhere(
          (v) => v.isTeaser && v.official,
          orElse: () => youtubeVideos.first,
        ),
      ),
    );
    entry
      ..hasTrailer = true
      ..trailer = selected;
    return selected;
  }

  Future<List<MovieModel>> getSimilarMovies(
    int movieId, {
    MediaType mediaType = MediaType.movie,
  }) async {
    final entry = _entryFor(movieId, mediaType: mediaType);
    if (entry.similarMovies != null) return entry.similarMovies!;
    final response = mediaType == MediaType.tv
        ? await _remoteDataSource.getTvRecommendations(movieId)
        : await _remoteDataSource.getMovieRecommendations(movieId);
    final list = response.results.take(10).toList();
    entry.similarMovies = list;
    return list;
  }

  Future<List<WatchProviderModel>> getWatchProviders(
    int movieId, {
    MediaType mediaType = MediaType.movie,
  }) async {
    final entry = _entryFor(movieId, mediaType: mediaType);
    if (entry.watchProviders != null) return entry.watchProviders!;
    final json = mediaType == MediaType.tv
        ? await _remoteDataSource.getTvWatchProvidersJson(movieId)
        : await _remoteDataSource.getMovieWatchProvidersJson(movieId);
    final results = json['results'];
    if (results is! Map || results.isEmpty) {
      entry.watchProviders = const [];
      return const [];
    }

    Map<String, dynamic>? regionData;
    if (results['US'] is Map) {
      regionData = Map<String, dynamic>.from(results['US'] as Map);
    } else {
      final firstEntry = results.values.whereType<Map>().firstOrNull;
      if (firstEntry != null) {
        regionData = Map<String, dynamic>.from(firstEntry);
      }
    }
    if (regionData == null) {
      entry.watchProviders = const [];
      return const [];
    }

    final providers = <WatchProviderModel>[];
    final seenIds = <int>{};

    void addFromKey(String key, WatchProviderType type) {
      final raw = regionData?[key];
      if (raw is! List) return;
      for (final item in raw.whereType<Map>()) {
        final model = WatchProviderModel.fromJson(
          Map<String, dynamic>.from(item),
          type: type,
        );
        if (model.providerId > 0 && seenIds.add(model.providerId)) {
          providers.add(model);
        }
      }
    }

    addFromKey('flatrate', WatchProviderType.stream);
    addFromKey('rent', WatchProviderType.rent);
    addFromKey('buy', WatchProviderType.buy);

    final capped = providers.take(10).toList();
    entry.watchProviders = capped;
    return capped;
  }

  Future<PersonDetailsModel> getPersonDetails(int personId) async {
    final json = await _remoteDataSource.getPersonDetailsJson(personId);
    return PersonDetailsModel.fromJson(json);
  }

  Future<List<MovieModel>> getPersonFilmography(int personId) async {
    final json = await _remoteDataSource.getPersonMovieCreditsJson(personId);
    final rawCast = json['cast'];
    final rawCrew = json['crew'];
    final list = <Map<String, dynamic>>[
      if (rawCast is List)
        ...rawCast.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
      if (rawCast is! List || rawCast.isEmpty)
        if (rawCrew is List)
          ...rawCrew.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
    ];

    final seenIds = <int>{};
    final movies = <MovieModel>[];
    for (final item in list) {
      final movie = MovieModel.fromJson(item);
      if (movie.id > 0 && seenIds.add(movie.id)) {
        movies.add(movie);
      }
    }
    movies.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
    return movies.take(15).toList();
  }
}

class _MovieDetailsCacheEntry {
  _MovieDetailsCacheEntry({required this.expiresAt});

  final DateTime expiresAt;
  MovieDetailsModel? details;
  List<CastMemberModel>? cast;
  bool hasTrailer = false;
  MovieVideoModel? trailer;
  List<MovieModel>? similarMovies;
  List<WatchProviderModel>? watchProviders;
}
