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
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../data/models/movie_review_model.dart';
import '../../data/models/user_profile_model.dart';
import '../bloc/community_bloc.dart';
import '../widgets/community_review_card.dart';
import '../widgets/report_review_dialog.dart';
import '../widgets/user_avatar_widget.dart';
import '../widgets/user_profile_dialog.dart';

/// Community tab displaying the public movie reviews feed and full leaderboard subview.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  bool _showLeaderboard = false;

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

              return CustomScrollView(
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
                            showLeaderboard: _showLeaderboard,
                            leaderboardCount: state.leaderboard.length,
                            onSelect: (showLeaderboard) =>
                                setState(() => _showLeaderboard = showLeaderboard),
                          ),
                          if (!_showLeaderboard) ...[
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Recent Reviews',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(
                                  '${reviews.length} reviews',
                                  style: Theme.of(context).textTheme.bodySmall,
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
                  if (_showLeaderboard)
                    _LeaderboardSliver(
                      state: state,
                      currentUid: currentUid,
                      onToggleFollow: (uid) =>
                          bloc.add(CommunityFollowToggled(uid)),
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
                        message:
                            'Open any movie and tap "Write a Review" to start the conversation.',
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
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                            onMovieTap: () => _openMovie(context, review),
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
    required this.showLeaderboard,
    required this.leaderboardCount,
    required this.onSelect,
  });

  final bool showLeaderboard;
  final int leaderboardCount;
  final ValueChanged<bool> onSelect;

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
              label: 'Reviews Feed',
              selected: !showLeaderboard,
              onTap: () => onSelect(false),
            ),
          ),
          Expanded(
            child: _SubviewTabButton(
              icon: Icons.leaderboard_rounded,
              label: leaderboardCount > 0
                  ? 'Leaderboard ($leaderboardCount)'
                  : 'Leaderboard',
              selected: showLeaderboard,
              onTap: () => onSelect(true),
            ),
          ),
        ],
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
                            color: (isAdmin
                                    ? AppColors.khakiBeige
                                    : AppColors.pacificBlue)
                                .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isAdmin ? 'Admin' : 'Mod',
                            style: TextStyle(
                              color: isAdmin
                                  ? AppColors.khakiBeige
                                  : AppColors.pacificBlue,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
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
