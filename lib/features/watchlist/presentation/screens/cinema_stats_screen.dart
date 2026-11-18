import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/movie_details_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/movie_poster.dart';
import '../../../community/presentation/bloc/community_bloc.dart';
import '../../data/models/watchlist_movie_model.dart';
import '../cubit/watchlist_cubit.dart';

class MonthlyWatchCount {
  const MonthlyWatchCount({required this.label, required this.count});

  final String label;
  final int count;
}

/// Pure analytics summary computed from the user's watchlist.
class CinemaStatsSummary {
  const CinemaStatsSummary({
    required this.totalWatched,
    required this.totalWatchesWithRewatches,
    required this.totalHours,
    required this.averageRating,
    required this.ratingCounts,
    required this.monthlyCounts,
    required this.currentMonthStreak,
    required this.topFavorites,
    required this.mostRewatched,
  });

  factory CinemaStatsSummary.fromMovies(
    List<WatchlistMovieModel> movies, {
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    final watched = movies.where((m) => m.isWatched).toList();

    var totalWatches = 0;
    var totalMinutes = 0;
    var ratingSum = 0;
    var ratedCount = 0;
    final ratingCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    for (final m in watched) {
      final watches = 1 + m.rewatchCount;
      totalWatches += watches;
      totalMinutes += (m.runtimeMinutes ?? 120) * watches;
      final r = m.userRating;
      if (r != null && r >= 1 && r <= 5) {
        ratingCounts[r] = (ratingCounts[r] ?? 0) + 1;
        ratingSum += r;
        ratedCount++;
      }
    }

    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final monthlyCounts = <MonthlyWatchCount>[];
    final activeMonths = <String>{};
    for (final m in watched) {
      final dt = m.watchedAt ?? m.addedAt;
      activeMonths.add('${dt.year}-${dt.month}');
    }

    for (var offset = 5; offset >= 0; offset--) {
      final target = DateTime(referenceNow.year, referenceNow.month - offset, 1);
      final count = watched.where((m) {
        final dt = m.watchedAt ?? m.addedAt;
        return dt.year == target.year && dt.month == target.month;
      }).length;
      monthlyCounts.add(
        MonthlyWatchCount(label: monthNames[target.month - 1], count: count),
      );
    }

    var streak = 0;
    for (var offset = 0; offset < 24; offset++) {
      final target = DateTime(referenceNow.year, referenceNow.month - offset, 1);
      if (activeMonths.contains('${target.year}-${target.month}')) {
        streak++;
      } else if (offset > 0) {
        break;
      }
    }

    final topFavorites =
        watched.where((m) => (m.userRating ?? 0) >= 4).toList()..sort(
          (a, b) => (b.userRating ?? 0).compareTo(a.userRating ?? 0),
        );

    final mostRewatched = watched.where((m) => m.rewatchCount > 0).toList()
      ..sort((a, b) => b.rewatchCount.compareTo(a.rewatchCount));

    return CinemaStatsSummary(
      totalWatched: watched.length,
      totalWatchesWithRewatches: totalWatches,
      totalHours: totalMinutes / 60,
      averageRating: ratedCount > 0 ? ratingSum / ratedCount : null,
      ratingCounts: ratingCounts,
      monthlyCounts: monthlyCounts,
      currentMonthStreak: streak,
      topFavorites: topFavorites.take(10).toList(),
      mostRewatched: mostRewatched.take(10).toList(),
    );
  }

  final int totalWatched;
  final int totalWatchesWithRewatches;
  final double totalHours;
  final double? averageRating;
  final Map<int, int> ratingCounts;
  final List<MonthlyWatchCount> monthlyCounts;
  final int currentMonthStreak;
  final List<WatchlistMovieModel> topFavorites;
  final List<WatchlistMovieModel> mostRewatched;
}

/// Cinema Stats / "Wrapped" screen (`/stats`).
class CinemaStatsScreen extends StatelessWidget {
  const CinemaStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final watchlistState = context.watch<WatchlistCubit>().state;
    final reviewsCount = context.select<CommunityBloc, int>(
      (b) => b.state.reviews
          .where((r) => r.uid == b.currentUid)
          .length,
    );
    final summary = CinemaStatsSummary.fromMovies(watchlistState.movies);
    final maxMonthly = summary.monthlyCounts.fold<int>(
      1,
      (max, m) => m.count > max ? m.count : max,
    );
    final maxRatingCount = summary.ratingCounts.values.fold<int>(
      1,
      (max, c) => c > max ? c : max,
    );

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/watchlist'),
        ),
        title: const Text(
          'Cinema Wrapped',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Share Cinema Card',
            icon: const Icon(Icons.share_rounded, color: AppColors.pacificBlue),
            onPressed: () {
              final avg = summary.averageRating != null
                  ? '${summary.averageRating!.toStringAsFixed(1)}/5 ★'
                  : 'N/A';
              final topTitle = summary.topFavorites.isNotEmpty
                  ? summary.topFavorites.first.title
                  : 'None yet';
              SharePlus.instance.share(
                ShareParams(
                  text:
                      '🎬 My CineList Wrapped:\n'
                      '• ${summary.totalWatched} films watched (${summary.totalHours.toStringAsFixed(1)}h)\n'
                      '• Average rating: $avg\n'
                      '• Active streak: ${summary.currentMonthStreak} mo\n'
                      '• Top pick: $topTitle\n'
                      '• Community reviews: $reviewsCount',
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppConstants.maxContentWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.pacificBlue.withValues(alpha: 0.2),
                        AppColors.surfaceCard,
                        AppColors.khakiBeige.withValues(alpha: 0.14),
                      ],
                    ),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      _HeroStat(
                        label: 'Films',
                        value: '${summary.totalWatched}',
                        color: AppColors.pacificBlue,
                      ),
                      _HeroStat(
                        label: 'Hours',
                        value: '${summary.totalHours.toStringAsFixed(1)}h',
                        color: AppColors.khakiBeige,
                      ),
                      _HeroStat(
                        label: 'Streak',
                        value: '${summary.currentMonthStreak}m',
                        color: AppColors.softPeriwinkle,
                      ),
                      _HeroStat(
                        label: 'Avg',
                        value: summary.averageRating != null
                            ? '★ ${summary.averageRating!.toStringAsFixed(1)}'
                            : '—',
                        color: AppColors.starAmber,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Last 6 Months',
                  child: SizedBox(
                    height: 132,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: summary.monthlyCounts.map((m) {
                        final ratio = m.count / maxMonthly;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '${m.count}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: (ratio * 72).clamp(6, 72),
                                  decoration: BoxDecoration(
                                    color: m.count > 0
                                        ? AppColors.pacificBlue
                                        : AppColors.surfaceBorder,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  m.label,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Rating Distribution',
                  child: Column(
                    children: [5, 4, 3, 2, 1].map((star) {
                      final count = summary.ratingCounts[star] ?? 0;
                      final ratio = count / maxRatingCount;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 34,
                              child: Text(
                                '$star ★',
                                style: const TextStyle(
                                  color: AppColors.starAmber,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: count == 0 ? 0 : ratio,
                                  minHeight: 10,
                                  backgroundColor: AppColors.surfaceElevated,
                                  color: AppColors.pacificBlue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 24,
                              child: Text(
                                '$count',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (summary.topFavorites.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Top Rated Favorites',
                    child: SizedBox(
                      height: 136,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: summary.topFavorites.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, idx) {
                          final movie = summary.topFavorites[idx];
                          return InkWell(
                            onTap: () => MovieDetailsRoute.push(
                              context,
                              movieId: movie.movieId,
                              initialMovie: movie.toMovieSummary(),
                            ),
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 78,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MoviePoster(
                                    posterPath: movie.posterPath,
                                    width: 78,
                                    height: 110,
                                    borderRadius: 10,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '★ ${movie.userRating}/5',
                                    style: const TextStyle(
                                      color: AppColors.starAmber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                if (summary.mostRewatched.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Most Rewatched',
                    child: SizedBox(
                      height: 136,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: summary.mostRewatched.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, idx) {
                          final movie = summary.mostRewatched[idx];
                          return InkWell(
                            onTap: () => MovieDetailsRoute.push(
                              context,
                              movieId: movie.movieId,
                              initialMovie: movie.toMovieSummary(),
                            ),
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 78,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MoviePoster(
                                    posterPath: movie.posterPath,
                                    width: 78,
                                    height: 110,
                                    borderRadius: 10,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '×${movie.rewatchCount} rewatch',
                                    style: const TextStyle(
                                      color: AppColors.pacificBlue,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.khakiBeige,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
