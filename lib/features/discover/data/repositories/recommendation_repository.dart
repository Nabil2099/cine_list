import 'dart:math';

import '../../../../shared/models/movie_summary.dart';
import '../../../ai_chat/data/repositories/ai_chat_repository.dart';
import '../../../watchlist/data/models/watchlist_movie_model.dart';
import '../datasources/tmdb_remote_data_source.dart';

/// Result returned by [RecommendationRepository] for the Discover
/// "Recommended For You" slide.
class PersonalizedRecommendationsResult {
  const PersonalizedRecommendationsResult({
    required this.movies,
    required this.usedAi,
    required this.basedOnWatchlist,
  });

  final List<MovieSummary> movies;
  final bool usedAi;
  final bool basedOnWatchlist;
}

/// Hybrid AI (Gemini) + algorithmic TMDB collaborative-taste recommendation
/// engine grounded in the user's watchlist.
class RecommendationRepository {
  RecommendationRepository(
    this._remoteDataSource,
    this._aiRepository, {
    Random? random,
  }) : _random = random ?? Random();

  final TmdbRemoteDataSource _remoteDataSource;
  final AiChatRepository _aiRepository;
  final Random _random;

  Future<PersonalizedRecommendationsResult> getRecommendations({
    required List<WatchlistMovieModel> watchlist,
    Set<int> excludeIds = const {},
    bool shuffle = false,
    int limit = 5,
  }) async {
    final watchlistIds = {for (final m in watchlist) m.movieId};
    final blockedIds = {...watchlistIds, ...excludeIds};

    if (watchlist.isEmpty) {
      final page = shuffle ? (_random.nextInt(3) + 1) : 1;
      final response = await _remoteDataSource.getTrendingMovies(page: page);
      final candidates = response.results
          .where((m) => m.id > 0 && !blockedIds.contains(m.id))
          .toList();
      if (shuffle) {
        candidates.shuffle(_random);
      }
      final picks = candidates.take(limit).toList();
      if (picks.length < limit) {
        final fallback = response.results
            .where((m) => !picks.any((p) => p.id == m.id))
            .take(limit - picks.length);
        picks.addAll(fallback);
      }
      return PersonalizedRecommendationsResult(
        movies: picks,
        usedAi: false,
        basedOnWatchlist: false,
      );
    }

    // Rank watchlist items to pick strong taste anchors.
    final rankedSeeds = List<WatchlistMovieModel>.from(watchlist)
      ..sort((a, b) => _seedScore(b).compareTo(_seedScore(a)));
    final topSeedPool = rankedSeeds.take(6).toList();
    if (shuffle) {
      topSeedPool.shuffle(_random);
    }
    final selectedSeeds = topSeedPool.take(3).toList();

    final aiFuture = _aiRepository.recommendMovieTitles(
      watchlist: watchlist,
      count: 8,
    );
    final tmdbSeedsFuture = Future.wait(
      selectedSeeds.map((seed) async {
        try {
          final resp = seed.mediaType == MediaType.tv
              ? await _remoteDataSource.getTvRecommendations(seed.movieId)
              : await _remoteDataSource.getMovieRecommendations(seed.movieId);
          return resp.results;
        } catch (_) {
          return const <MovieSummary>[];
        }
      }),
    );

    final aiSuggestions = await aiFuture;
    final tmdbSeedLists = await tmdbSeedsFuture;

    // Resolve AI-suggested titles to real TMDB entries concurrently.
    final aiResolved = <MovieSummary>[];
    if (aiSuggestions.isNotEmpty) {
      final searchResults = await Future.wait(
        aiSuggestions.take(7).map((pick) async {
          try {
            final res = await _remoteDataSource.searchMovies(
              query: pick.title,
              page: 1,
            );
            if (res.results.isEmpty) return null;
            if (pick.year != null) {
              final yearMatch = res.results.where(
                (m) => (m.releaseDate ?? '').startsWith(pick.year!),
              );
              if (yearMatch.isNotEmpty) return yearMatch.first;
            }
            return res.results.first;
          } catch (_) {
            return null;
          }
        }),
      );
      for (final item in searchResults) {
        if (item != null &&
            item.id > 0 &&
            !blockedIds.contains(item.id) &&
            !aiResolved.any((m) => m.id == item.id)) {
          aiResolved.add(item);
        }
      }
    }

    // Score algorithmic TMDB candidates by overlap across seeds + voteAverage.
    final candidateMap = <int, MovieSummary>{};
    final candidateScores = <int, double>{};
    for (final list in tmdbSeedLists) {
      for (final item in list) {
        if (item.id <= 0 || blockedIds.contains(item.id)) continue;
        candidateMap[item.id] = item;
        final jitter = shuffle ? _random.nextDouble() * 3.0 : 0.0;
        candidateScores[item.id] =
            (candidateScores[item.id] ?? item.voteAverage + jitter) + 4.5;
      }
    }

    final algoSorted = candidateMap.values.toList()
      ..sort(
        (a, b) =>
            (candidateScores[b.id] ?? 0).compareTo(candidateScores[a.id] ?? 0),
      );

    // Blend AI picks and algorithmic TMDB picks into 5 unique recommendations.
    final blended = <MovieSummary>[];
    final seenIds = <int>{};
    var aiIdx = 0;
    var algoIdx = 0;
    while (blended.length < limit &&
        (aiIdx < aiResolved.length || algoIdx < algoSorted.length)) {
      if (aiIdx < aiResolved.length) {
        final pick = aiResolved[aiIdx++];
        if (seenIds.add(pick.id)) {
          blended.add(pick);
          if (blended.length >= limit) break;
        }
      }
      if (algoIdx < algoSorted.length) {
        final pick = algoSorted[algoIdx++];
        if (seenIds.add(pick.id)) {
          blended.add(pick);
        }
      }
    }

    // Fallback to trending if seed recommendations + AI didn't yield 5 items.
    if (blended.length < limit) {
      try {
        final trending = await _remoteDataSource.getTrendingMovies(page: 1);
        final extras = trending.results
            .where((m) => !blockedIds.contains(m.id) && seenIds.add(m.id))
            .toList();
        if (shuffle) extras.shuffle(_random);
        blended.addAll(extras.take(limit - blended.length));
      } catch (_) {}
    }

    return PersonalizedRecommendationsResult(
      movies: blended.take(limit).toList(),
      usedAi: aiResolved.isNotEmpty,
      basedOnWatchlist: true,
    );
  }

  static double _seedScore(WatchlistMovieModel item) {
    final ratingScore = (item.userRating ?? 3) * 3.0;
    final upNextBonus = item.isUpNext ? 4.0 : 0.0;
    final watchedBonus = item.isWatched ? 1.5 : 1.0;
    return ratingScore + upNextBonus + watchedBonus + (item.voteAverage * 0.4);
  }
}
