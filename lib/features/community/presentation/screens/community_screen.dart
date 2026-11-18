import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/movie_details_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../../../shared/widgets/movie_poster.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../watchlist/presentation/cubit/watchlist_cubit.dart';
import '../../data/models/community_poll_model.dart';
import '../../data/models/curated_list_model.dart';
import '../../data/models/movie_review_model.dart';
import '../../data/models/user_profile_model.dart';
import '../bloc/community_bloc.dart';
import '../widgets/community_review_card.dart';
import '../widgets/report_review_dialog.dart';
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

  @override
  Widget build(BuildContext context) {
    final currentUid = context.select<AuthCubit, String?>(
      (c) => c.state.user?.uid,
    );
    final savedMovieIds = context.select<WatchlistCubit, Set<int>>(
      (w) => w.state.movies.map((m) => m.movieId).toSet(),
    );

    return SafeArea(
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
              final followingCount = state.profile?.followingUids.length ?? 0;

              return RefreshIndicator(
                color: AppColors.pacificBlue,
                backgroundColor: AppColors.surfaceElevated,
                onRefresh: () async {
                  bloc.add(const CommunityRefreshed());
                  await Future<void>.delayed(const Duration(milliseconds: 450));
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Community',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'See what movie lovers are reviewing',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 14),
                            _CommunitySubviewSwitcher(
                              selected: _subview,
                              listsCount: state.curatedLists.length,
                              leaderboardCount: state.leaderboard.length,
                              onSelect: (subview) =>
                                  setState(() => _subview = subview),
                            ),
                            if (_subview == _CommunitySubview.reviews) ...[
                              if (state.pinnedPoll != null) ...[
                                const SizedBox(height: 14),
                                _PinnedPollCard(
                                  poll: state.pinnedPoll!,
                                  currentUid: currentUid,
                                  onVote: (optionIndex) => bloc.add(
                                    CommunityPollVoted(
                                      pollId: state.pinnedPoll!.id,
                                      optionIndex: optionIndex,
                                    ),
                                  ),
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
                                    FilterChip(
                                      avatar: Icon(
                                        Icons.people_alt_outlined,
                                        size: 15,
                                        color: state.followingOnly
                                            ? AppColors.khakiBeige
                                            : AppColors.textSecondary,
                                      ),
                                      label: Text(
                                        followingCount > 0
                                            ? 'Following ($followingCount)'
                                            : 'Following',
                                      ),
                                      selected: state.followingOnly,
                                      onSelected: (_) => bloc.add(
                                        const CommunityFollowingFilterToggled(),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      selectedColor: AppColors.khakiBeige
                                          .withValues(alpha: 0.2),
                                      backgroundColor: AppColors.surfaceCard,
                                      side: BorderSide(
                                        color: state.followingOnly
                                            ? AppColors.khakiBeige
                                            : AppColors.surfaceBorder,
                                      ),
                                      labelStyle: TextStyle(
                                        color: state.followingOnly
                                            ? AppColors.khakiBeige
                                            : AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      showCheckmark: false,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Recent Reviews',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  Text(
                                    '${reviews.length} reviews',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
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
                    if (_subview == _CommunitySubview.leaderboard)
                      _LeaderboardSliver(
                        state: state,
                        currentUid: currentUid,
                        onToggleFollow: (uid) =>
                            bloc.add(CommunityFollowToggled(uid)),
                      )
                    else if (_subview == _CommunitySubview.lists)
                      _CuratedListsSliver(
                        state: state,
                        currentUid: currentUid,
                        savedMovieIds: savedMovieIds,
                        onToggleLike: (list) =>
                            bloc.add(CommunityCuratedListLikeToggled(list)),
                        onDelete: (listId) =>
                            bloc.add(CommunityCuratedListDeleted(listId)),
                        onSaveAll: (movies) async {
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
                              onToggleLike: () => bloc.add(
                                CommunityReactionToggled(
                                  review: review,
                                  isLike: true,
                                ),
                              ),
                              onToggleDislike: () => bloc.add(
                                CommunityReactionToggled(
                                  review: review,
                                  isLike: false,
                                ),
                              ),
                              onReport: () async {
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

class _PinnedPollCard extends StatelessWidget {
  const _PinnedPollCard({
    required this.poll,
    required this.currentUid,
    required this.onVote,
  });

  final CommunityPollModel poll;
  final String? currentUid;
  final ValueChanged<int> onVote;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = poll.selectedOptionFor(currentUid);
    final totalVotes = poll.totalVotes;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
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
                Icons.poll_rounded,
                size: 16,
                color: AppColors.pacificBlue,
              ),
              const SizedBox(width: 6),
              const Text(
                'Weekly Poll',
                style: TextStyle(
                  color: AppColors.pacificBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            poll.question,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < poll.options.length; i++) ...[
            _PollOptionTile(
              label: poll.options[i],
              percentage: poll.percentageForOption(i),
              votes: poll.votesForOption(i),
              selected: selectedIndex == i,
              showResults: selectedIndex != null,
              onTap: () => onVote(i),
            ),
            if (i < poll.options.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _PollOptionTile extends StatelessWidget {
  const _PollOptionTile({
    required this.label,
    required this.percentage,
    required this.votes,
    required this.selected,
    required this.showResults,
    required this.onTap,
  });

  final String label;
  final double percentage;
  final int votes;
  final bool selected;
  final bool showResults;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pctLabel = '${(percentage * 100).round()}%';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.pacificBlue : AppColors.surfaceBorder,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (showResults)
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: percentage.clamp(0.0, 1.0),
                  child: Container(
                    color:
                        (selected ? AppColors.pacificBlue : AppColors.textMuted)
                            .withValues(alpha: selected ? 0.22 : 0.12),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  if (selected) ...[
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 15,
                      color: AppColors.pacificBlue,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (showResults) ...[
                    const SizedBox(width: 8),
                    Text(
                      '$pctLabel ($votes)',
                      style: TextStyle(
                        color: selected
                            ? AppColors.pacificBlue
                            : AppColors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
    required this.onOpenMovie,
  });

  final CommunityState state;
  final String? currentUid;
  final Set<int> savedMovieIds;
  final ValueChanged<CuratedListModel> onToggleLike;
  final ValueChanged<String> onDelete;
  final Future<void> Function(List<CuratedListMovie> movies) onSaveAll;
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
            onToggleFollow: (currentUid == null || isSelf)
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
