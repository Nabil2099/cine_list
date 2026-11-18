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

/// Community tab displaying the public movie reviews feed and staff moderation link.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

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
              final topCritics = state.topCritics;
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
                          if (topCritics.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Text(
                              'Top Critics',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 118,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: topCritics.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final critic = topCritics[index];
                                  return _TopCriticCard(
                                    profile: critic,
                                    isAdmin: state.adminUids.contains(
                                      critic.uid,
                                    ),
                                    isModerator: state.moderatorUids.contains(
                                      critic.uid,
                                    ),
                                    onTap: () => UserProfileDialog.show(
                                      context,
                                      uid: critic.uid,
                                      fallbackName: critic.displayName,
                                      fallbackAvatarKey: critic.avatarKey,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          _CommunitySearchBar(
                            query: state.searchQuery,
                            onChanged: (q) =>
                                bloc.add(CommunitySearchQueryChanged(q)),
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final option
                                    in CommunitySortOption.values) ...[
                                  ChoiceChip(
                                    label: Text(option.label),
                                    selected: state.sortOption == option,
                                    onSelected: (_) =>
                                        bloc.add(CommunitySortChanged(option)),
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
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    showCheckmark: false,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                FilterChip(
                                  avatar: Icon(
                                    Icons.people_alt_outlined,
                                    size: 16,
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
                                    fontSize: 12.5,
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
                        ],
                      ),
                    ),
                  ),
                  if (state.status == CommunityStatus.loading &&
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

class _TopCriticCard extends StatelessWidget {
  const _TopCriticCard({
    required this.profile,
    required this.isAdmin,
    required this.isModerator,
    required this.onTap,
  });

  final UserProfileModel profile;
  final bool isAdmin;
  final bool isModerator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tier = ReputationTier.fromPoints(profile.reputation);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 118,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            UserAvatar(
              avatarKey: profile.avatarKey,
              photoBase64: profile.photoBase64,
              reputation: profile.reputation,
              isAdmin: isAdmin,
              isModerator: isModerator,
              radius: 20,
            ),
            const SizedBox(height: 6),
            Text(
              profile.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tier.icon, size: 11, color: tier.color),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    '${profile.reputation} pts',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tier.color,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
