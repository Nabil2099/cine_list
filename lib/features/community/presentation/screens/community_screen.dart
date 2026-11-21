import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/routing/movie_details_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/auth_gate.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/profile_drawer_button.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../../../shared/widgets/movie_poster.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../watchlist/data/models/watchlist_movie_model.dart';
import '../../../watchlist/presentation/cubit/watchlist_cubit.dart';
import '../../data/models/community_poll_model.dart';
import '../../data/models/curated_list_model.dart';
import '../../data/models/movie_review_model.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/models/weekly_challenge_model.dart';
import '../../data/repositories/community_repository.dart';
import '../bloc/community_bloc.dart';
import '../widgets/community_review_card.dart';
import '../widgets/report_review_dialog.dart';
import '../widgets/review_replies_sheet.dart';
import '../widgets/user_avatar_widget.dart';
import '../widgets/user_profile_dialog.dart';

enum _CommunitySubview { reviews, lists, leaderboard }

/// Community tab displaying Reviews, Curated Lists, and Leaderboard subviews.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  _CommunitySubview _subview = _CommunitySubview.reviews;

  void _openMovie(BuildContext context, MovieReviewModel review) {
    MovieDetailsRoute.push(
      context,
      movieId: review.movieId,
      initialMovie: MovieSummary(
        id: review.movieId,
        title: review.movieTitle,
        posterPath: review.posterPath,
      ),
    );
  }

  String _sectionTitle(CommunityState state) {
    if (state.searchQuery.trim().isNotEmpty) return 'Matching Reviews';
    if (state.followingOnly) return 'Following Reviews';
    return switch (state.sortOption) {
      CommunitySortOption.curated => 'Curated Reviews',
      CommunitySortOption.mostHelpful => 'Most Helpful Reviews',
      CommunitySortOption.highestRated => 'Highest Rated Reviews',
      CommunitySortOption.latest => 'Recent Reviews',
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = context.select<AuthCubit, String?>(
      (c) => c.state.user?.uid,
    );
    final watchlistMovies = context
        .select<WatchlistCubit, List<WatchlistMovieModel>>(
          (w) => w.state.movies,
        );
    final savedMovieIds = {for (final m in watchlistMovies) m.movieId};
    final isWideWeb =
        kIsWeb &&
        MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;

    return ColoredBox(
      color: AppColors.black,
      child: SafeArea(
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppConstants.maxContentWidth,
          ),
          child: BlocConsumer<CommunityBloc, CommunityState>(
            listenWhen: (prev, curr) =>
                (prev.feedbackMessage != curr.feedbackMessage &&
                    curr.feedbackMessage != null) ||
                (prev.errorMessage != curr.errorMessage &&
                    curr.errorMessage != null &&
                    curr.status == CommunityStatus.loaded),
            listener: (context, state) {
              final msg = state.feedbackMessage ?? state.errorMessage;
              if (msg != null) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(msg)));
                context.read<CommunityBloc>().add(
                  const CommunityFeedbackCleared(),
                );
              }
            },
            builder: (context, state) {
              final bloc = context.read<CommunityBloc>();
              final reviews = state.filteredReviews;
              final showSpotlightSections =
                  _subview == _CommunitySubview.reviews &&
                  !state.requiresSignInToRead &&
                  state.searchQuery.trim().isEmpty &&
                  !state.followingOnly;
              final featured =
                  showSpotlightSections && state.reviews.length >= 3
                  ? state.featuredReviews
                  : const <MovieReviewModel>[];
              final hiddenRawCount = state.hiddenRawReviewsCount;

              return RefreshIndicator(
                color: AppColors.pacificBlue,
                backgroundColor: AppColors.surfaceElevated,
                onRefresh: () async {
                  bloc.add(const CommunityRefreshed());
                  await Future<void>.delayed(const Duration(milliseconds: 450));
                },
                child: CustomScrollView(
                  scrollCacheExtent: const ScrollCacheExtent.pixels(600),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (!isWideWeb) ...[
                                  const ProfileDrawerButton(),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Community',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineMedium,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Curated reviews, polls & cinema lists',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _PollsHeaderButton(
                                  pinnedPoll: state.pinnedPoll,
                                  currentUid: currentUid,
                                  onTap: () => context.push('/polls'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _CommunitySubviewSwitcher(
                              selected: _subview,
                              listsCount: state.curatedLists.length,
                              leaderboardCount: state.leaderboard.length,
                              onSelect: (subview) =>
                                  setState(() => _subview = subview),
                            ),
                            if (_subview == _CommunitySubview.reviews &&
                                !state.requiresSignInToRead) ...[
                              if (featured.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _FeaturedReviewsStrip(
                                  reviews: featured,
                                  state: state,
                                  onTapReview: (r) => _openMovie(context, r),
                                ),
                              ],
                              if (state.activeChallenge != null) ...[
                                const SizedBox(height: 14),
                                _WeeklyChallengeBanner(
                                  challenge: state.activeChallenge!,
                                  isCompleted: state.activeChallenge!
                                      .isCompletedBy(currentUid),
                                  onOpenMovie: () {
                                    final c = state.activeChallenge!;
                                    MovieDetailsRoute.push(
                                      context,
                                      movieId: c.movieId,
                                      initialMovie: c.toMovieSummary(),
                                    );
                                  },
                                  onComplete: () async {
                                    final allowed = await AuthGate.requireAuth(
                                      context,
                                      actionLabel: 'join the Watch Party',
                                    );
                                    if (!allowed || !context.mounted) return;
                                    bloc.add(
                                      CommunityChallengeCompleted(
                                        state.activeChallenge!.id,
                                      ),
                                    );
                                  },
                                ),
                              ],
                              const SizedBox(height: 14),
                              _CommunitySearchBar(
                                query: state.searchQuery,
                                onChanged: (q) =>
                                    bloc.add(CommunitySearchQueryChanged(q)),
                              ),
                              const SizedBox(height: 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final option
                                        in CommunitySortOption.values) ...[
                                      ChoiceChip(
                                        label: Text(option.label),
                                        selected: state.sortOption == option,
                                        onSelected: (_) => bloc.add(
                                          CommunitySortChanged(option),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        selectedColor: AppColors.pacificBlue
                                            .withValues(alpha: 0.22),
                                        backgroundColor: AppColors.surfaceCard,
                                        side: BorderSide(
                                          color: state.sortOption == option
                                              ? AppColors.pacificBlue
                                              : AppColors.surfaceBorder,
                                        ),
                                        labelStyle: TextStyle(
                                          color: state.sortOption == option
                                              ? AppColors.pacificBlue
                                              : AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        showCheckmark: false,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _sectionTitle(state),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  if (hiddenRawCount > 0)
                                    TextButton(
                                      onPressed: () => bloc.add(
                                        const CommunitySortChanged(
                                          CommunitySortOption.latest,
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Show all (${state.reviews.length})',
                                        style: const TextStyle(
                                          color: AppColors.pacificBlue,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      '${reviews.length} ${reviews.length == 1 ? 'review' : 'reviews'}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ] else ...[
                              const SizedBox(height: 14),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (state.requiresSignInToRead)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: GuestPromptView(
                          icon: Icons.groups_rounded,
                          title: 'Join the CineList Community',
                          message:
                              'Sign in to browse community movie reviews, curated lists, and top critics.',
                        ),
                      )
                    else if (_subview == _CommunitySubview.leaderboard)
                      _LeaderboardSliver(
                        state: state,
                        currentUid: currentUid,
                        onToggleFollow: (uid) async {
                          final allowed = await AuthGate.requireAuth(
                            context,
                            actionLabel: 'follow critics',
                          );
                          if (!allowed || !context.mounted) return;
                          bloc.add(CommunityFollowToggled(uid));
                        },
                      )
                    else if (_subview == _CommunitySubview.lists)
                      _CuratedListsSliver(
                        state: state,
                        currentUid: currentUid,
                        savedMovieIds: savedMovieIds,
                        onToggleLike: (list) async {
                          final allowed = await AuthGate.requireAuth(
                            context,
                            actionLabel: 'upvote curated lists',
                          );
                          if (!allowed || !context.mounted) return;
                          bloc.add(CommunityCuratedListLikeToggled(list));
                        },
                        onDelete: (listId) =>
                            bloc.add(CommunityCuratedListDeleted(listId)),
                        onSaveAll: (movies) async {
                          final allowed = await AuthGate.requireAuth(
                            context,
                            actionLabel: 'save movies to your Watchlist',
                          );
                          if (!allowed || !context.mounted) return;
                          final watchlist = context.read<WatchlistCubit>();
                          var added = 0;
                          for (final m in movies) {
                            if (!savedMovieIds.contains(m.movieId)) {
                              await watchlist.addToWatchlist(
                                m.toMovieSummary(),
                              );
                              added++;
                            }
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    added > 0
                                        ? 'Added $added movies to your Watchlist!'
                                        : 'All movies are already in your Watchlist.',
                                  ),
                                ),
                              );
                          }
                        },
                        onCloneList: (list) async {
                          final allowed = await AuthGate.requireAuth(
                            context,
                            actionLabel: 'clone this list to your Watchlist',
                          );
                          if (!allowed || !context.mounted) return;
                          final res = await context
                              .read<WatchlistCubit>()
                              .cloneCuratedList(
                                title: list.title,
                                movies: list.movies
                                    .map((m) => m.toMovieSummary())
                                    .toList(),
                              );
                          if (res != null && context.mounted) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    res.addedCount > 0
                                        ? 'Cloned "${res.collectionName}" (${res.addedCount} new movies added)!'
                                        : 'Cloned "${res.collectionName}" to your Watchlist collections!',
                                  ),
                                ),
                              );
                          }
                        },
                        onOpenMovie: (movie) {
                          MovieDetailsRoute.push(
                            context,
                            movieId: movie.movieId,
                            initialMovie: movie.toMovieSummary(),
                          );
                        },
                      )
                    else if (state.status == CommunityStatus.loading &&
                        state.reviews.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: LoadingView(message: 'Loading community...'),
                      )
                    else if (state.status == CommunityStatus.error &&
                        state.reviews.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: ErrorView(
                          title: 'Community Unavailable',
                          message:
                              state.errorMessage ??
                              'Could not load community reviews.',
                        ),
                      )
                    else if (state.reviews.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyStateView(
                          icon: Icons.rate_review_outlined,
                          title: 'No community reviews yet',
                          message: 'Open any movie and tap "Write a Review" to start the conversation.',
                        ),
                      )
                    else if (reviews.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyStateView(
                          icon: Icons.filter_list_off_rounded,
                          title: 'No matching reviews',
                          message: state.followingOnly
                              ? 'Follow critics or turn off the Following filter to see more reviews.'
                              : 'Try another movie title, reviewer name, or keyword.',
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        sliver: SliverList.separated(
                          itemCount: reviews.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final review = reviews[index];
                            final authorProfile =
                                state.userProfilesByUid[review.uid];
                            final isAuthorAdmin = state.adminUids.contains(
                              review.uid,
                            );
                            final isAuthorMod = state.moderatorUids.contains(
                              review.uid,
                            );

                            return CommunityReviewCard(
                              review: review,
                              isOwner: review.uid == currentUid,
                              isLiked: review.isLikedBy(currentUid),
                              isDisliked: review.isDislikedBy(currentUid),
                              authorPhotoBase64: authorProfile?.photoBase64,
                              authorReputation: authorProfile?.reputation ?? 0,
                              isAuthorAdmin: isAuthorAdmin,
                              isAuthorModerator: isAuthorMod,
                              isInWatchlist: savedMovieIds.contains(
                                review.movieId,
                              ),
                              onMovieTap: () => _openMovie(context, review),
                              onToggleWatchlist: () async {
                                final allowed = await AuthGate.requireAuth(
                                  context,
                                  actionLabel: 'save movies to your Watchlist',
                                );
                                if (!allowed || !context.mounted) return;
                                final watchlist = context
                                    .read<WatchlistCubit>();
                                final isSaved = savedMovieIds.contains(
                                  review.movieId,
                                );
                                if (isSaved) {
                                  await watchlist.removeFromWatchlist(
                                    review.movieId,
                                    title: review.movieTitle,
                                  );
                                } else {
                                  await watchlist.addToWatchlist(
                                    MovieSummary(
                                      id: review.movieId,
                                      title: review.movieTitle,
                                      posterPath: review.posterPath,
                                    ),
                                  );
                                }
                              },
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
                                  CommunityReactionToggled(
                                    review: review,
                                    isLike: true,
                                  ),
                                );
                              },
                              onToggleDislike: () async {
                                final allowed = await AuthGate.requireAuth(
                                  context,
                                  actionLabel: 'react to reviews',
                                );
                                if (!allowed || !context.mounted) return;
                                bloc.add(
                                  CommunityReactionToggled(
                                    review: review,
                                    isLike: false,
                                  ),
                                );
                              },
                              onReply: () => ReviewRepliesSheet.show(
                                context,
                                review: review,
                                repository: sl<CommunityRepository>(),
                              ),
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
                              onDelete: () =>
                                  bloc.add(CommunityReviewDeleted(review.id)),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
    );
  }
}

class _CommunitySearchBar extends StatefulWidget {
  const _CommunitySearchBar({required this.query, required this.onChanged});

  final String query;
  final ValueChanged<String> onChanged;

  @override
  State<_CommunitySearchBar> createState() => _CommunitySearchBarState();
}

class _CommunitySearchBarState extends State<_CommunitySearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _CommunitySearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text && widget.query.isEmpty) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: (value) {
        setState(() {});
        widget.onChanged(value);
      },
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search reviews by movie, reviewer, or keyword...',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textMuted,
          size: 20,
        ),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                },
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
                tooltip: 'Clear search',
              )
            : null,
        isDense: true,
      ),
    );
  }
}

class _CommunitySubviewSwitcher extends StatelessWidget {
  const _CommunitySubviewSwitcher({
    required this.selected,
    required this.listsCount,
    required this.leaderboardCount,
    required this.onSelect,
  });

  final _CommunitySubview selected;
  final int listsCount;
  final int leaderboardCount;
  final ValueChanged<_CommunitySubview> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SubviewTabButton(
              icon: Icons.rate_review_outlined,
              label: 'Reviews',
              selected: selected == _CommunitySubview.reviews,
              onTap: () => onSelect(_CommunitySubview.reviews),
            ),
          ),
          Expanded(
            child: _SubviewTabButton(
              icon: Icons.collections_bookmark_outlined,
              label: listsCount > 0 ? 'Lists ($listsCount)' : 'Lists',
              selected: selected == _CommunitySubview.lists,
              onTap: () => onSelect(_CommunitySubview.lists),
            ),
          ),
          Expanded(
            child: _SubviewTabButton(
              icon: Icons.leaderboard_rounded,
              label: leaderboardCount > 0
                  ? 'Ranks ($leaderboardCount)'
                  : 'Ranks',
              selected: selected == _CommunitySubview.leaderboard,
              onTap: () => onSelect(_CommunitySubview.leaderboard),
            ),
          ),
        ],
      ),
    );
  }
}

class _PollsHeaderButton extends StatelessWidget {
  const _PollsHeaderButton({
    required this.pinnedPoll,
    required this.currentUid,
    required this.onTap,
  });

  final CommunityPollModel? pinnedPoll;
  final String? currentUid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasUnvotedPoll =
        pinnedPoll != null && pinnedPoll!.selectedOptionFor(currentUid) == null;

    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.pacificBlue,
        backgroundColor: AppColors.pacificBlue.withValues(alpha: 0.1),
        side: BorderSide(
          color: AppColors.pacificBlue.withValues(alpha: 0.45),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.poll_rounded, size: 17),
          if (hasUnvotedPoll)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.khakiBeige,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      label: const Text(
        'Polls',
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CuratedListsSliver extends StatelessWidget {
  const _CuratedListsSliver({
    required this.state,
    required this.currentUid,
    required this.savedMovieIds,
    required this.onToggleLike,
    required this.onDelete,
    required this.onSaveAll,
    required this.onCloneList,
    required this.onOpenMovie,
  });

  final CommunityState state;
  final String? currentUid;
  final Set<int> savedMovieIds;
  final ValueChanged<CuratedListModel> onToggleLike;
  final ValueChanged<String> onDelete;
  final Future<void> Function(List<CuratedListMovie> movies) onSaveAll;
  final Future<void> Function(CuratedListModel list) onCloneList;
  final ValueChanged<CuratedListMovie> onOpenMovie;

  @override
  Widget build(BuildContext context) {
    final lists = state.curatedLists;
    if (lists.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyStateView(
          icon: Icons.collections_bookmark_outlined,
          title: 'No curated lists yet',
          message: 'Select a custom collection in Watchlist and tap "Share to Community" to publish your first list!',
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      sliver: SliverList.separated(
        itemCount: lists.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final list = lists[index];
          final authorProfile = state.userProfilesByUid[list.authorUid];
          final isOwner = list.authorUid == currentUid;
          final canDelete = isOwner || state.isStaff;
          final unsavedCount = list.movies
              .where((m) => !savedMovieIds.contains(m.movieId))
              .length;

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UserAvatar(
                      avatarKey:
                          authorProfile?.avatarKey ?? list.authorAvatarKey,
                      photoBase64: authorProfile?.photoBase64,
                      reputation: authorProfile?.reputation ?? 0,
                      isAdmin: state.adminUids.contains(list.authorUid),
                      isModerator: state.moderatorUids.contains(list.authorUid),
                      radius: 17,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            list.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.khakiBeige,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'by ${authorProfile?.displayName ?? list.authorName} · ${list.movies.length} movies',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canDelete)
                      IconButton(
                        onPressed: () => onDelete(list.id),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        tooltip: 'Delete list',
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                if (list.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    list.description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: list.movies.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, mIdx) {
                      final movie = list.movies[mIdx];
                      return InkWell(
                        onTap: () => onOpenMovie(movie),
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 60,
                          child: MoviePoster(
                            posterPath: movie.posterPath,
                            width: 60,
                            height: 90,
                            borderRadius: 8,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    InkWell(
                      onTap: () => onToggleLike(list),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: list.isLikedBy(currentUid)
                              ? AppColors.khakiBeige.withValues(alpha: 0.16)
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: list.isLikedBy(currentUid)
                                ? AppColors.khakiBeige.withValues(alpha: 0.5)
                                : AppColors.surfaceBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              list.isLikedBy(currentUid)
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 14,
                              color: list.isLikedBy(currentUid)
                                  ? AppColors.khakiBeige
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${list.likedBy.length}',
                              style: TextStyle(
                                color: list.isLikedBy(currentUid)
                                    ? AppColors.khakiBeige
                                    : AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => onCloneList(list),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.softPeriwinkle,
                        side: BorderSide(
                          color: AppColors.softPeriwinkle.withValues(
                            alpha: 0.45,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(
                        Icons.copy_all_rounded,
                        size: 14,
                      ),
                      label: const Text(
                        'Clone List',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: unsavedCount > 0
                          ? () => onSaveAll(list.movies)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.pacificBlue,
                        foregroundColor: AppColors.black,
                        disabledBackgroundColor: AppColors.surfaceElevated,
                        disabledForegroundColor: AppColors.textMuted,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(
                        unsavedCount > 0
                            ? Icons.bookmark_add_outlined
                            : Icons.check_rounded,
                        size: 15,
                      ),
                      label: Text(
                        unsavedCount > 0
                            ? 'Save All ($unsavedCount)'
                            : 'All Saved',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SubviewTabButton extends StatelessWidget {
  const _SubviewTabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.pacificBlue.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected
                ? AppColors.pacificBlue.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.pacificBlue : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? AppColors.pacificBlue
                      : AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardSliver extends StatelessWidget {
  const _LeaderboardSliver({
    required this.state,
    required this.currentUid,
    required this.onToggleFollow,
  });

  final CommunityState state;
  final String? currentUid;
  final ValueChanged<String> onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final leaderboard = state.leaderboard;
    if (leaderboard.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyStateView(
          icon: Icons.leaderboard_outlined,
          title: 'No ranked users yet',
          message: 'Members will appear here as soon as profiles load.',
        ),
      );
    }

    final reviewCounts = <String, int>{};
    for (final review in state.reviews) {
      reviewCounts.update(review.uid, (c) => c + 1, ifAbsent: () => 1);
    }

    final myIndex = currentUid == null
        ? -1
        : leaderboard.indexWhere((u) => u.uid == currentUid);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      sliver: SliverList.separated(
        itemCount: leaderboard.length + (myIndex >= 0 ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (myIndex >= 0 && index == 0) {
            final me = leaderboard[myIndex];
            final myTier = me.tier;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.pacificBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.pacificBlue.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  Icon(myTier.icon, color: AppColors.pacificBlue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your Rank: #${myIndex + 1} · ${myTier.label}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${me.reputation} pts',
                    style: const TextStyle(
                      color: AppColors.pacificBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          }

          final userIndex = myIndex >= 0 ? index - 1 : index;
          final user = leaderboard[userIndex];
          final rank = userIndex + 1;
          final isSelf = user.uid == currentUid;
          final isFollowing = state.profile?.isFollowing(user.uid) ?? false;

          return _LeaderboardRow(
            rank: rank,
            profile: user,
            reviewCount: reviewCounts[user.uid] ?? 0,
            isSelf: isSelf,
            isAdmin: state.adminUids.contains(user.uid),
            isModerator: state.moderatorUids.contains(user.uid),
            isFollowing: isFollowing,
            onToggleFollow: isSelf
                ? null
                : () => onToggleFollow(user.uid),
            onTap: () => UserProfileDialog.show(
              context,
              uid: user.uid,
              fallbackName: user.displayName,
              fallbackAvatarKey: user.avatarKey,
            ),
          );
        },
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.profile,
    required this.reviewCount,
    required this.isSelf,
    required this.isAdmin,
    required this.isModerator,
    required this.isFollowing,
    required this.onToggleFollow,
    required this.onTap,
  });

  final int rank;
  final UserProfileModel profile;
  final int reviewCount;
  final bool isSelf;
  final bool isAdmin;
  final bool isModerator;
  final bool isFollowing;
  final VoidCallback? onToggleFollow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tier = ReputationTier.fromPoints(profile.reputation);
    final isTopThree = rank <= 3;
    final rankTint = switch (rank) {
      1 => AppColors.starAmber,
      2 => const Color(0xFFC0C7D1),
      3 => const Color(0xFFCD8B5B),
      _ => AppColors.textMuted,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: rank == 1
                ? rankTint.withValues(alpha: 0.5)
                : AppColors.surfaceBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isTopThree
                    ? rankTint.withValues(alpha: 0.18)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isTopThree
                      ? rankTint.withValues(alpha: 0.65)
                      : AppColors.surfaceBorder,
                ),
              ),
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: isTopThree ? rankTint : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            UserAvatar(
              avatarKey: profile.avatarKey,
              photoBase64: profile.photoBase64,
              reputation: profile.reputation,
              isAdmin: isAdmin,
              isModerator: isModerator,
              radius: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.pacificBlue.withValues(
                              alpha: 0.16,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(
                              color: AppColors.pacificBlue,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      if (isAdmin || isModerator) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isAdmin
                                        ? AppColors.creatorEmerald
                                        : AppColors.pacificBlue)
                                    .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isAdmin) ...[
                                const CreatorEmblemIcon(size: 11),
                                const SizedBox(width: 3),
                              ],
                              Text(
                                isAdmin ? 'Creator' : 'Mod',
                                style: TextStyle(
                                  color: isAdmin
                                      ? AppColors.creatorEmerald
                                      : AppColors.pacificBlue,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(tier.icon, size: 12, color: tier.color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${tier.label} · ${profile.reputation} pts · $reviewCount ${reviewCount == 1 ? 'review' : 'reviews'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tier.color,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onToggleFollow != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: onToggleFollow,
                tooltip: isFollowing ? 'Unfollow' : 'Follow',
                icon: Icon(
                  isFollowing
                      ? Icons.check_circle_rounded
                      : Icons.person_add_alt_1_rounded,
                  color: isFollowing
                      ? AppColors.pacificBlue
                      : AppColors.textSecondary,
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeeklyChallengeBanner extends StatelessWidget {
  const _WeeklyChallengeBanner({
    required this.challenge,
    required this.isCompleted,
    required this.onOpenMovie,
    required this.onComplete,
  });

  final WeeklyChallengeModel challenge;
  final bool isCompleted;
  final VoidCallback onOpenMovie;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceCard,
            AppColors.khakiBeige.withValues(alpha: 0.14),
          ],
        ),
        border: Border.all(
          color: AppColors.khakiBeige.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpenMovie,
            borderRadius: BorderRadius.circular(10),
            child: MoviePoster(
              posterPath: challenge.posterPath,
              width: 58,
              height: 86,
              borderRadius: 10,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: AppColors.khakiBeige,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        challenge.title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.khakiBeige,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.pacificBlue.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '+${challenge.bonusPoints} Rep',
                        style: const TextStyle(
                          color: AppColors.pacificBlue,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: onOpenMovie,
                  child: Text(
                    challenge.movieTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (challenge.prompt.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    challenge.prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${challenge.participantUids.length} joined',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: onOpenMovie,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Reviews',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.icon(
                      onPressed: isCompleted ? null : onComplete,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.khakiBeige,
                        foregroundColor: AppColors.black,
                        disabledBackgroundColor: AppColors.pacificBlue
                            .withValues(alpha: 0.18),
                        disabledForegroundColor: AppColors.pacificBlue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(
                        isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.play_circle_outline_rounded,
                        size: 14,
                      ),
                      label: Text(
                        isCompleted ? 'Completed' : 'Watched It',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedReviewsStrip extends StatelessWidget {
  const _FeaturedReviewsStrip({
    required this.reviews,
    required this.state,
    required this.onTapReview,
  });

  final List<MovieReviewModel> reviews;
  final CommunityState state;
  final ValueChanged<MovieReviewModel> onTapReview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Featured Reviews',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.khakiBeige,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 138,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: reviews.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final review = reviews[index];
              final authorProfile = state.userProfilesByUid[review.uid];
              final isAdmin = state.adminUids.contains(review.uid);
              final isMod = state.moderatorUids.contains(review.uid);

              return RepaintBoundary(
                child: InkWell(
                  onTap: () => onTapReview(review),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 280,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.surfaceCard,
                          AppColors.pacificBlue.withValues(alpha: 0.08),
                        ],
                      ),
                      border: Border.all(
                        color: AppColors.pacificBlue.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MoviePoster(
                          posterPath: review.posterPath,
                          width: 60,
                          height: 92,
                          borderRadius: 10,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                review.movieTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.khakiBeige,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  UserAvatar(
                                    avatarKey: review.authorAvatarKey,
                                    photoBase64: authorProfile?.photoBase64,
                                    reputation: authorProfile?.reputation ?? 0,
                                    isAdmin: isAdmin,
                                    isModerator: isMod,
                                    showRankBadge: false,
                                    radius: 9,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      review.authorName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 13,
                                    color: AppColors.starAmber,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${review.rating}',
                                    style: const TextStyle(
                                      color: AppColors.starAmber,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: Text(
                                  review.hasSpoilers
                                      ? 'Contains spoilers · Tap to read'
                                      : review.comment,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: review.hasSpoilers
                                        ? AppColors.khakiBeige
                                        : AppColors.textPrimary,
                                    fontSize: 12,
                                    height: 1.32,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.thumb_up_outlined,
                                    size: 11.5,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${review.likedBy.length}',
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 11.5,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${review.replyCount}',
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
