import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/auth_gate.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/genre_chip.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/rating_badge.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../../../shared/widgets/movie_poster.dart';
import '../../../ai_chat/data/repositories/ai_chat_repository.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../community/data/models/movie_review_model.dart';
import '../../../community/presentation/bloc/community_bloc.dart';
import '../../../community/presentation/screens/rate_review_screen.dart';
import '../../../community/presentation/widgets/community_review_card.dart';
import '../../../community/presentation/widgets/report_review_dialog.dart';
import '../../../community/presentation/widgets/user_profile_dialog.dart';
import '../../../watchlist/data/models/watchlist_movie_model.dart';
import '../../../watchlist/presentation/cubit/watchlist_cubit.dart';
import '../../../watchlist/presentation/cubit/watchlist_state.dart';
import '../../data/models/cast_member_model.dart';
import '../../data/models/movie_details_model.dart';
import '../../data/models/movie_video_model.dart';
import '../../data/models/watch_provider_model.dart';
import '../cubit/movie_details_cubit.dart';
import '../cubit/movie_details_state.dart';
import '../widgets/cast_filmography_sheet.dart';
import '../widgets/cast_section.dart';
import '../widgets/details_action_bar.dart';
import '../widgets/similar_movies_section.dart';
import '../widgets/trailer_section.dart';
import '../widgets/watch_providers_section.dart';

Future<void> _openUnifiedRateReview(
  BuildContext context, {
  required MovieSummary movie,
  int? runtimeMinutes,
  required bool defaultPublishToCommunity,
}) async {
  final allowed = await AuthGate.requireAuth(
    context,
    actionLabel: 'rate and review movies',
  );
  if (!allowed || !context.mounted) return;

  final savedItem = context.read<WatchlistCubit>().state.findById(movie.id);
  final currentUid = context.read<AuthCubit>().state.user?.uid;
  final movieReviews = context.read<CommunityBloc>().state.reviewsForMovie(
    movie.id,
  );
  MovieReviewModel? myReview;
  if (currentUid != null) {
    for (final r in movieReviews) {
      if (r.uid == currentUid) {
        myReview = r;
        break;
      }
    }
  }

  final result = await RateReviewScreen.open(
    context,
    movie: movie,
    initialRating: savedItem?.userRating ?? myReview?.rating,
    initialText: myReview?.comment ?? savedItem?.userNote,
    initialPublishToCommunity: myReview != null || defaultPublishToCommunity,
    initialHasSpoilers: myReview?.hasSpoilers ?? false,
    isEditingExistingCommunityReview: myReview != null,
  );

  if (result == null || !context.mounted) return;

  await context.read<WatchlistCubit>().logWatchedMovie(
    movie,
    runtimeMinutes: runtimeMinutes,
    userRating: result.rating,
    userNote: result.reviewText,
    updateReviewFields: true,
  );

  if (result.publishToCommunity &&
      result.rating != null &&
      result.reviewText.trim().length >= 5 &&
      context.mounted) {
    context.read<CommunityBloc>().add(
      CommunityReviewSubmitted(
        movie: movie,
        rating: result.rating!,
        comment: result.reviewText.trim(),
        hasSpoilers: result.hasSpoilers,
        isVerifiedWatch: true,
      ),
    );
  }
}

/// Movie Details screen pushed onto Navigator from Discover or Watchlist.
class MovieDetailsScreen extends StatelessWidget {
  const MovieDetailsScreen({
    super.key,
    required this.movieId,
    this.initialMovie,
    this.heroTag,
  });

  final int movieId;
  final MovieSummary? initialMovie;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MovieDetailsCubit>(
      create: (_) => sl<MovieDetailsCubit>()..loadMovie(movieId),
      child: _MovieDetailsView(
        movieId: movieId,
        initialMovie: initialMovie,
        heroTag: heroTag,
      ),
    );
  }
}

class _MovieDetailsView extends StatelessWidget {
  const _MovieDetailsView({
    required this.movieId,
    this.initialMovie,
    this.heroTag,
  });

  final int movieId;
  final MovieSummary? initialMovie;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    return BlocListener<WatchlistCubit, WatchlistState>(
      listenWhen: (prev, curr) =>
          (prev.feedbackMessage != curr.feedbackMessage &&
              curr.feedbackMessage != null) ||
          (prev.errorMessage != curr.errorMessage && curr.errorMessage != null),
      listener: (context, state) {
        final msg = state.feedbackMessage ?? state.errorMessage;
        if (msg != null) {
          final isAddFeedback =
              state.feedbackMessage != null && !msg.startsWith('Removed');
          final router = GoRouter.of(context);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(msg),
                action: isAddFeedback
                    ? SnackBarAction(
                        label: 'Watchlist',
                        textColor: AppColors.pacificBlue,
                        onPressed: () => router.go('/watchlist'),
                      )
                    : null,
              ),
            );
          context.read<WatchlistCubit>().clearFeedback();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: BlocBuilder<MovieDetailsCubit, MovieDetailsState>(
          builder: (context, detailsState) {
            final isLoading =
                detailsState.status == MovieDetailsStatus.loading ||
                detailsState.status == MovieDetailsStatus.initial;

            if (isLoading && initialMovie == null) {
              return const LoadingView(message: 'Loading movie details...');
            }

            if (detailsState.status == MovieDetailsStatus.error) {
              return SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ErrorView(
                        title: 'Could Not Load Details',
                        message:
                            detailsState.errorMessage ??
                            'Unable to load movie information.',
                        onRetry: () => context
                            .read<MovieDetailsCubit>()
                            .loadMovie(movieId),
                      ),
                    ),
                  ],
                ),
              );
            }

            return _DetailsContent(
              details: detailsState.details,
              cast: detailsState.cast,
              trailer: detailsState.trailer,
              similarMovies: detailsState.similarMovies,
              watchProviders: detailsState.watchProviders,
              fallbackSummary: initialMovie,
              isLoadingDetails: isLoading,
              heroTag: heroTag,
            );
          },
        ),
        bottomNavigationBar: BlocBuilder<MovieDetailsCubit, MovieDetailsState>(
          builder: (context, detailsState) {
            final summary =
                detailsState.details?.toMovieSummary() ?? initialMovie;
            if (summary == null) return const SizedBox.shrink();

            return BlocBuilder<WatchlistCubit, WatchlistState>(
              builder: (context, watchlistState) {
                final savedItem = watchlistState.findById(summary.id);
                final isMutating = watchlistState.isMutating(summary.id);
                final watchlistCubit = context.read<WatchlistCubit>();

                return DetailsActionBar(
                  savedItem: savedItem,
                  isMutating: isMutating,
                  onAddToWatchlist: () async {
                    final allowed = await AuthGate.requireAuth(
                      context,
                      actionLabel: 'save movies to your Watchlist',
                    );
                    if (!allowed || !context.mounted) return;
                    watchlistCubit.addToWatchlist(summary);
                  },
                  onMarkWatched: () async {
                    final allowed = await AuthGate.requireAuth(
                      context,
                      actionLabel: 'log watched movies',
                    );
                    if (!allowed || !context.mounted) return;
                    await watchlistCubit.logWatchedMovie(
                      summary,
                      runtimeMinutes: detailsState.details?.runtime,
                    );
                    if (context.mounted) {
                      await _openUnifiedRateReview(
                        context,
                        movie: summary,
                        runtimeMinutes: detailsState.details?.runtime,
                        defaultPublishToCommunity: false,
                      );
                    }
                  },
                  onRateAndReview: () => _openUnifiedRateReview(
                    context,
                    movie: summary,
                    runtimeMinutes: detailsState.details?.runtime,
                    defaultPublishToCommunity: false,
                  ),
                  onUnwatch: () {
                    if (savedItem != null) {
                      watchlistCubit.toggleWatchedStatus(savedItem);
                    }
                  },
                  onRemove: () => watchlistCubit.removeFromWatchlist(
                    summary.id,
                    title: summary.title,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _DetailsContent extends StatelessWidget {
  const _DetailsContent({
    required this.details,
    required this.cast,
    required this.isLoadingDetails,
    this.trailer,
    this.similarMovies = const [],
    this.watchProviders = const [],
    this.fallbackSummary,
    this.heroTag,
  });

  final MovieDetailsModel? details;
  final List<CastMemberModel> cast;
  final MovieVideoModel? trailer;
  final List<MovieSummary> similarMovies;
  final List<WatchProviderModel> watchProviders;
  final bool isLoadingDetails;
  final MovieSummary? fallbackSummary;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= AppConstants.tabletBreakpoint;
    final backdropHeight = isWide ? 360.0 : 235.0;

    final movieId = details?.id ?? fallbackSummary?.id ?? 0;
    final title = details?.title ?? fallbackSummary?.title ?? 'Untitled';
    final posterPath = details?.posterPath ?? fallbackSummary?.posterPath;
    final backdropPath = details?.backdropPath ?? fallbackSummary?.backdropPath;
    final releaseDate = details?.releaseDate ?? fallbackSummary?.releaseDate;
    final voteAverage =
        details?.voteAverage ?? fallbackSummary?.voteAverage ?? 0.0;
    final summaryForBookmark = details?.toMovieSummary() ?? fallbackSummary!;

    final backdropUrl =
        ApiConstants.backdropUrl(backdropPath) ??
        ApiConstants.posterUrl(posterPath);

    final runtimeText = Formatters.runtime(details?.runtime);
    final yearText = Formatters.releaseYear(releaseDate);
    final metaLine = runtimeText.isNotEmpty
        ? '$yearText  •  $runtimeText'
        : yearText;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: backdropHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (backdropUrl != null)
                  CachedNetworkImage(
                    imageUrl: backdropUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Container(color: AppColors.surfaceCard),
                    errorWidget: (_, _, _) =>
                        Container(color: AppColors.surfaceCard),
                  )
                else
                  Container(color: AppColors.surfaceCard),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.45, 1.0],
                      colors: [
                        AppColors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                        AppColors.black,
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CircleIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          tooltip: 'Back',
                          onTap: () => context.canPop()
                              ? context.pop()
                              : context.go('/discover'),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _CircleIconButton(
                              icon: Icons.share_outlined,
                              tooltip: 'Share movie',
                              onTap: () => SharePlus.instance.share(
                                ShareParams(
                                  text:
                                      'Check out "$title" ($yearText) on CineList — TMDB ${voteAverage.toStringAsFixed(1)}★\nhttps://www.themoviedb.org/movie/$movieId',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            BlocBuilder<WatchlistCubit, WatchlistState>(
                              builder: (context, watchlistState) {
                                final savedItem = watchlistState.findById(
                                  movieId,
                                );
                                final isSaved = savedItem != null;
                                final isMutating = watchlistState.isMutating(
                                  movieId,
                                );
                                final watchlistCubit = context
                                    .read<WatchlistCubit>();

                                return _CircleIconButton(
                                  icon: isSaved
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_border_rounded,
                                  iconColor: isSaved
                                      ? AppColors.pacificBlue
                                      : AppColors.textPrimary,
                                  tooltip: isSaved
                                      ? 'Remove from Watchlist'
                                      : 'Add to Watchlist',
                                  onTap: isMutating
                                      ? null
                                      : () async {
                                          final allowed =
                                              await AuthGate.requireAuth(
                                                context,
                                                actionLabel:
                                                    'save movies to your Watchlist',
                                              );
                                          if (!allowed || !context.mounted) {
                                            return;
                                          }
                                          if (isSaved) {
                                            watchlistCubit.removeFromWatchlist(
                                              movieId,
                                              title: title,
                                            );
                                          } else {
                                            watchlistCubit.addToWatchlist(
                                              summaryForBookmark,
                                            );
                                          }
                                        },
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 20 : 16,
                  0,
                  isWide ? 20 : 16,
                  28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MoviePoster(
                          posterPath: posterPath,
                          width: isWide ? 132 : 88,
                          height: isWide ? 196 : 130,
                          borderRadius: isWide ? 16 : 13,
                          heroTag: heroTag,
                          highRes: true,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                metaLine,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 10),
                              RatingBadge(
                                rating: voteAverage,
                                fontSize: 14,
                                iconSize: 17,
                                filled: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: isLoadingDetails || details == null
                          ? const MovieDetailsSkeleton(
                              key: ValueKey('details-skeleton'),
                            )
                          : _LoadedBody(
                              key: ValueKey('details-loaded-${details!.id}'),
                              details: details!,
                              cast: cast,
                              trailer: trailer,
                              similarMovies: similarMovies,
                              watchProviders: watchProviders,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({
    super.key,
    required this.details,
    required this.cast,
    this.trailer,
    this.similarMovies = const [],
    this.watchProviders = const [],
  });

  final MovieDetailsModel details;
  final List<CastMemberModel> cast;
  final MovieVideoModel? trailer;
  final List<MovieSummary> similarMovies;
  final List<WatchProviderModel> watchProviders;

  @override
  Widget build(BuildContext context) {
    final savedItem = context.select<WatchlistCubit, WatchlistMovieModel?>(
      (c) => c.state.findById(details.id),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          if (details.genres.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: details.genres.map((g) => GenreChip(label: g)).toList(),
            ),
            const SizedBox(height: 24),
          ],
          if (savedItem != null && savedItem.isWatched) ...[
            _PersonalReviewCard(
              savedItem: savedItem,
              onEdit: () => _openUnifiedRateReview(
                context,
                movie: details.toMovieSummary(),
                runtimeMinutes: details.runtime,
                defaultPublishToCommunity: false,
              ),
            ),
            const SizedBox(height: 22),
          ],
          Text('Overview', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            details.overview.trim().isNotEmpty
                ? details.overview
                : 'No overview available for this title.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (watchProviders.isNotEmpty) ...[
            const SizedBox(height: 26),
            WatchProvidersSection(providers: watchProviders),
          ],
          if (trailer != null) ...[
            const SizedBox(height: 26),
            TrailerSection(trailer: trailer!),
          ],
          if (cast.isNotEmpty) ...[
            const SizedBox(height: 26),
            CastSection(
              cast: cast,
              onCastTap: (member) =>
                  CastFilmographySheet.show(context, castMember: member),
            ),
          ],
          if (similarMovies.isNotEmpty) ...[
            const SizedBox(height: 26),
            SimilarMoviesSection(movies: similarMovies),
          ],
          const SizedBox(height: 26),
          _MovieCommunityReviewsSection(details: details),
        ],
      );
  }
}

class _MovieCommunityReviewsSection extends StatefulWidget {
  const _MovieCommunityReviewsSection({required this.details});

  final MovieDetailsModel details;

  @override
  State<_MovieCommunityReviewsSection> createState() =>
      _MovieCommunityReviewsSectionState();
}

class _MovieCommunityReviewsSectionState
    extends State<_MovieCommunityReviewsSection> {
  bool _sortByCurated = true;

  @override
  Widget build(BuildContext context) {
    final details = widget.details;
    final currentUid = context.select<AuthCubit, String?>(
      (c) => c.state.user?.uid,
    );
    final movieReviews = context.select<CommunityBloc, List<MovieReviewModel>>(
      (b) => b.state.reviewsForMovie(details.id, sortByCurated: _sortByCurated),
    );
    final communityState = context.watch<CommunityBloc>().state;
    MovieReviewModel? myReview;
    for (final r in movieReviews) {
      if (r.uid == currentUid) {
        myReview = r;
        break;
      }
    }
    final avgCommunityRating = movieReviews.isEmpty
        ? null
        : movieReviews.fold<int>(0, (sum, r) => sum + r.rating) /
              movieReviews.length;

    return BlocListener<CommunityBloc, CommunityState>(
      listenWhen: (prev, curr) =>
          (prev.feedbackMessage != curr.feedbackMessage &&
              curr.feedbackMessage != null) ||
          (prev.errorMessage != curr.errorMessage && curr.errorMessage != null),
      listener: (context, state) {
        final msg = state.feedbackMessage ?? state.errorMessage;
        if (msg != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(msg)));
          context.read<CommunityBloc>().add(const CommunityFeedbackCleared());
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Community Reviews (${movieReviews.length})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (avgCommunityRating != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.starAmber.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.starAmber.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          '★ ${avgCommunityRating.toStringAsFixed(1)}',
                          style: const TextStyle(
                            color: AppColors.starAmber,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _openUnifiedRateReview(
                  context,
                  movie: details.toMovieSummary(),
                  runtimeMinutes: details.runtime,
                  defaultPublishToCommunity: true,
                ),
                icon: Icon(
                  myReview != null
                      ? Icons.edit_outlined
                      : Icons.rate_review_outlined,
                  size: 17,
                  color: AppColors.pacificBlue,
                ),
                label: Text(
                  myReview != null ? 'Edit Review' : 'Write Review',
                  style: const TextStyle(
                    color: AppColors.pacificBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (movieReviews.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _ReviewSortPill(
                  label: 'Top Reviews',
                  selected: _sortByCurated,
                  onTap: () => setState(() => _sortByCurated = true),
                ),
                const SizedBox(width: 8),
                _ReviewSortPill(
                  label: 'Recent',
                  selected: !_sortByCurated,
                  onTap: () => setState(() => _sortByCurated = false),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          if (movieReviews.length >= 3) ...[
            _CommunityConsensusCard(
              movieTitle: details.title,
              reviews: movieReviews,
            ),
            const SizedBox(height: 10),
          ],
          if (communityState.requiresSignInToRead && movieReviews.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Sign in to read community reviews for this film.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () => AuthGate.openAuth(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.pacificBlue,
                      foregroundColor: AppColors.black,
                    ),
                    child: const Text('Sign In'),
                  ),
                ],
              ),
            )
          else if (movieReviews.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: const Text(
                'No community reviews yet. Be the first to share your thoughts!',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                ),
              ),
            )
          else
            Column(
              children: movieReviews.map((review) {
                final authorProfile =
                    communityState.userProfilesByUid[review.uid];
                final isAuthorAdmin = communityState.adminUids.contains(
                  review.uid,
                );
                final isAuthorMod = communityState.moderatorUids.contains(
                  review.uid,
                );
                final bloc = context.read<CommunityBloc>();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CommunityReviewCard(
                    review: review,
                    isOwner: review.uid == currentUid,
                    isLiked: review.isLikedBy(currentUid),
                    isDisliked: review.isDislikedBy(currentUid),
                    authorPhotoBase64: authorProfile?.photoBase64,
                    authorReputation: authorProfile?.reputation ?? 0,
                    isAuthorAdmin: isAuthorAdmin,
                    isAuthorModerator: isAuthorMod,
                    showMovieHeader: false,
                    onAuthorTap: () => UserProfileDialog.show(
                      context,
                      uid: review.uid,
                      fallbackName: review.authorName,
                      fallbackAvatarKey: review.authorAvatarKey,
                    ),
                    onToggleLike: () async {
                      final allowed = await AuthGate.requireAuth(
                        context,
                        actionLabel: 'react to reviews',
                      );
                      if (!allowed || !context.mounted) return;
                      bloc.add(
                        CommunityReactionToggled(review: review, isLike: true),
                      );
                    },
                    onToggleDislike: () async {
                      final allowed = await AuthGate.requireAuth(
                        context,
                        actionLabel: 'react to reviews',
                      );
                      if (!allowed || !context.mounted) return;
                      bloc.add(
                        CommunityReactionToggled(review: review, isLike: false),
                      );
                    },
                    onReport: () async {
                      final allowed = await AuthGate.requireAuth(
                        context,
                        actionLabel: 'report a review',
                      );
                      if (!allowed || !context.mounted) return;
                      final res = await ReportReviewDialog.show(
                        context,
                        authorName: review.authorName,
                      );
                      if (res != null && context.mounted) {
                        bloc.add(
                          CommunityReviewReported(
                            review: review,
                            reason: res.reason,
                            details: res.details,
                          ),
                        );
                      }
                    },
                    onShare: () => SharePlus.instance.share(
                      ShareParams(
                        text:
                            '${review.authorName} rated "${review.movieTitle}" ${review.rating}/5 on CineList:\n\n"${review.comment}"\n\nhttps://www.themoviedb.org/movie/${review.movieId}',
                      ),
                    ),
                    onDelete: () => bloc.add(CommunityReviewDeleted(review.id)),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _ReviewSortPill extends StatelessWidget {
  const _ReviewSortPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.pacificBlue.withValues(alpha: 0.18)
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.pacificBlue : AppColors.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.pacificBlue : AppColors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PersonalReviewCard extends StatelessWidget {
  const _PersonalReviewCard({required this.savedItem, required this.onEdit});

  final WatchlistMovieModel savedItem;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasNote =
        savedItem.userNote != null && savedItem.userNote!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.pacificBlue.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.rate_review_outlined,
            color: AppColors.pacificBlue,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  savedItem.userRating != null
                      ? 'Your Rating: ★ ${savedItem.userRating}/5'
                      : 'Add Your Rating & Note',
                  style: const TextStyle(
                    color: AppColors.khakiBeige,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hasNote) ...[
                  const SizedBox(height: 4),
                  Text(
                    savedItem.userNote!.trim(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            child: Text(savedItem.userRating != null ? 'Edit' : 'Rate'),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.iconColor = AppColors.textPrimary,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.black.withValues(alpha: 0.58),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.surfaceBorder.withValues(alpha: 0.9),
            ),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }
}

class _CommunityConsensusCard extends StatefulWidget {
  const _CommunityConsensusCard({
    required this.movieTitle,
    required this.reviews,
  });

  final String movieTitle;
  final List<MovieReviewModel> reviews;

  @override
  State<_CommunityConsensusCard> createState() =>
      _CommunityConsensusCardState();
}

class _CommunityConsensusCardState extends State<_CommunityConsensusCard> {
  String? _summary;
  String? _error;
  bool _isLoading = false;

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await sl<AiChatRepository>().summarizeCommunityReviews(
        movieTitle: widget.movieTitle,
        reviews: widget.reviews,
      );
      if (!mounted) return;
      setState(() {
        _summary = result;
        _isLoading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not generate AI consensus right now.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_summary == null && !_isLoading && _error == null) {
      return OutlinedButton.icon(
        onPressed: _generate,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.pacificBlue,
          side: BorderSide(color: AppColors.pacificBlue.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.auto_awesome_rounded, size: 17),
        label: const Text('AI Community Consensus (Spoiler-Free)'),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pacificBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.pacificBlue.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.pacificBlue,
                size: 16,
              ),
              const SizedBox(width: 6),
              const Text(
                'AI Community Consensus',
                style: TextStyle(
                  color: AppColors.pacificBlue,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (!_isLoading)
                InkWell(
                  onTap: _generate,
                  child: const Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoading)
            const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Summarizing community reviews...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            )
          else if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 12.5),
            )
          else
            Text(
              _summary!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
        ],
      ),
    );
  }
}
