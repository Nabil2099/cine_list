import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/routing/movie_details_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/auth_gate.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../../../shared/widgets/movie_poster.dart';
import '../../../discover/data/repositories/discover_repository.dart';
import '../../../watchlist/presentation/cubit/watchlist_cubit.dart';
import '../../data/models/cinema_dna_model.dart';
import '../../data/repositories/ai_chat_repository.dart';
import '../cubit/cinema_dna_cubit.dart';

/// Interactive "Cinema DNA & Blind-Spot Analyzer" sheet/dialog.
class CinemaDnaSheet extends StatelessWidget {
  const CinemaDnaSheet({super.key, required this.onExplorePrompt});

  final ValueChanged<String> onExplorePrompt;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<String> onExplorePrompt,
  }) async {
    final watchlist = context.read<WatchlistCubit>().state.movies;
    final isWide =
        MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;

    final child = BlocProvider<CinemaDnaCubit>(
      create: (_) {
        final cubit = CinemaDnaCubit(
          sl<AiChatRepository>(),
          sl<DiscoverRepository>(),
        );
        if (watchlist.length >= 2) {
          cubit.analyze(watchlist);
        }
        return cubit;
      },
      child: CinemaDnaSheet(onExplorePrompt: onExplorePrompt),
    );

    if (isWide) {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.surfaceBorder),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
            child: child,
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.86,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, _) => child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final watchlist = context.watch<WatchlistCubit>().state.movies;

    if (watchlist.length < 2) {
      return _EmptyWatchlistDnaView(
        savedCount: watchlist.length,
        onStarterPicks: () {
          Navigator.of(context).pop();
          onExplorePrompt(
            'Suggest 5 iconic starter movies across different genres so I can build my Cinema DNA.',
          );
        },
      );
    }

    return BlocBuilder<CinemaDnaCubit, CinemaDnaState>(
      builder: (context, state) {
        if (state.status == CinemaDnaStatus.loading ||
            state.status == CinemaDnaStatus.initial) {
          return const _CinemaDnaLoadingView();
        }

        if (state.status == CinemaDnaStatus.error || state.profile == null) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorView(
              title: 'Cinema DNA Unavailable',
              message:
                  state.errorMessage ??
                  'Could not analyze your Cinema DNA right now.',
              onRetry: () => context.read<CinemaDnaCubit>().analyze(watchlist),
            ),
          );
        }

        final profile = state.profile!;
        return _CinemaDnaContent(
          profile: profile,
          onRefresh: () => context.read<CinemaDnaCubit>().analyze(watchlist),
          onExploreInChat: () {
            Navigator.of(context).pop();
            onExplorePrompt(
              'Based on my Cinema DNA ("${profile.archetype}"), give me 4 deeper recommendations I have not seen yet.',
            );
          },
        );
      },
    );
  }
}

class _EmptyWatchlistDnaView extends StatelessWidget {
  const _EmptyWatchlistDnaView({
    required this.savedCount,
    required this.onStarterPicks,
  });

  final int savedCount;
  final VoidCallback onStarterPicks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceBorder,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.pacificBlue.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.pacificBlue.withValues(alpha: 0.45),
              ),
            ),
            child: const Icon(
              Icons.fingerprint_rounded,
              size: 40,
              color: AppColors.pacificBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Unlock Your Cinema DNA',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Save at least 2 movies to your Watchlist (you currently have $savedCount) so CineList AI can decode your taste archetype, vibe traits, and blind-spot recommendations.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStarterPicks,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.pacificBlue,
                foregroundColor: AppColors.black,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text(
                'Get 5 Starter Picks in Chat',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CinemaDnaLoadingView extends StatelessWidget {
  const _CinemaDnaLoadingView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Shimmer.fromColors(
        baseColor: AppColors.surfaceCard,
        highlightColor: AppColors.dustyLavender.withValues(alpha: 0.35),
        child: ListView(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 112,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < 4; i++) ...[
              Container(
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Decoding your Cinema DNA & blind spots...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CinemaDnaContent extends StatelessWidget {
  const _CinemaDnaContent({
    required this.profile,
    required this.onRefresh,
    required this.onExploreInChat,
  });

  final CinemaDnaProfile profile;
  final VoidCallback onRefresh;
  final VoidCallback onExploreInChat;

  @override
  Widget build(BuildContext context) {
    final watchlistState = context.watch<WatchlistCubit>().state;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceBorder,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.pacificBlue.withValues(alpha: 0.22),
                AppColors.surfaceCard,
                AppColors.khakiBeige.withValues(alpha: 0.14),
              ],
            ),
            border: Border.all(
              color: AppColors.pacificBlue.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.fingerprint_rounded,
                    color: AppColors.pacificBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'YOUR CINEMA DNA',
                    style: TextStyle(
                      color: AppColors.pacificBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onRefresh,
                    tooltip: 'Re-analyze DNA',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                profile.archetype,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.khakiBeige,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                profile.tagline,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatPill(label: '${profile.totalMovies} Saved'),
                  _StatPill(label: '${profile.watchedCount} Watched'),
                  if (profile.averageRating != null)
                    _StatPill(
                      label: 'Avg ${profile.averageRating!.toStringAsFixed(1)}★',
                    ),
                  if (profile.topDecade != null)
                    _StatPill(label: 'Era: ${profile.topDecade}'),
                ],
              ),
            ],
          ),
        ),
        if (profile.traits.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Taste Signature',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final trait in profile.traits) ...[
            _TraitBar(trait: trait),
            const SizedBox(height: 10),
          ],
        ],
        if (profile.blindSpots.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Your Blind-Spot Picks',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.khakiBeige,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Unseen films tailored to expand your Cinema DNA:',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          for (final spot in profile.blindSpots) ...[
            _BlindSpotTile(
              spot: spot,
              isSaved:
                  spot.movie != null &&
                  watchlistState.findById(spot.movie!.id) != null,
              onOpenMovie: spot.movie == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      MovieDetailsRoute.push(
                        context,
                        movieId: spot.movie!.id,
                        initialMovie: spot.movie,
                        mediaType: spot.movie!.mediaType,
                      );
                    },
              onSave: spot.movie == null
                  ? null
                  : () async {
                      final allowed = await AuthGate.requireAuth(
                        context,
                        actionLabel: 'save movies to your Watchlist',
                      );
                      if (!allowed || !context.mounted) return;
                      await context.read<WatchlistCubit>().addToWatchlist(
                        spot.movie!,
                      );
                    },
            ),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onExploreInChat,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.pacificBlue,
              foregroundColor: AppColors.black,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text(
              'Explore More in AI Chat',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TraitBar extends StatelessWidget {
  const _TraitBar({required this.trait});

  final CinemaDnaTrait trait;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              trait.label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${trait.score}%',
              style: const TextStyle(
                color: AppColors.pacificBlue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: trait.score / 100.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (_, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 7,
              backgroundColor: AppColors.surfaceCard,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.pacificBlue,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BlindSpotTile extends StatelessWidget {
  const _BlindSpotTile({
    required this.spot,
    required this.isSaved,
    this.onOpenMovie,
    this.onSave,
  });

  final CinemaDnaBlindSpot spot;
  final bool isSaved;
  final VoidCallback? onOpenMovie;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final MovieSummary? movie = spot.movie;

    return InkWell(
      onTap: onOpenMovie,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MoviePoster(
              posterPath: movie?.posterPath,
              width: 54,
              height: 80,
              borderRadius: 9,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie?.title ?? spot.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (spot.year != null || (movie?.voteAverage ?? 0) > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (spot.year != null) spot.year!,
                        if ((movie?.voteAverage ?? 0) > 0)
                          '★ ${movie!.voteAverage.toStringAsFixed(1)}',
                      ].join(' · '),
                      style: const TextStyle(
                        color: AppColors.khakiBeige,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (spot.reason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      spot.reason,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onSave != null) ...[
              const SizedBox(width: 6),
              IconButton(
                onPressed: isSaved ? null : onSave,
                tooltip: isSaved ? 'In Watchlist' : 'Add to Watchlist',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_add_outlined,
                  color: isSaved
                      ? AppColors.pacificBlue
                      : AppColors.khakiBeige,
                  size: 20,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
