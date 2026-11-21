import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/routing/movie_details_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/auth_gate.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/profile_drawer_button.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../../../shared/widgets/movie_poster.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../watchlist/data/models/watchlist_movie_model.dart';
import '../../../watchlist/presentation/cubit/watchlist_cubit.dart';
import '../../data/models/curated_list_model.dart';
import '../../data/models/movie_review_model.dart';
import '../../data/repositories/community_repository.dart';
import '../bloc/community_bloc.dart';
import '../widgets/community_review_card.dart';
import '../widgets/report_review_dialog.dart';
import '../widgets/review_replies_sheet.dart';
import '../widgets/user_avatar_widget.dart';
import '../widgets/user_profile_dialog.dart';

sealed class _FeedEntry {
  const _FeedEntry(this.timestamp);

  final DateTime timestamp;
}

class _ReviewFeedEntry extends _FeedEntry {
  _ReviewFeedEntry(this.review) : super(review.createdAt);

  final MovieReviewModel review;
}

class _ListFeedEntry extends _FeedEntry {
  _ListFeedEntry(this.list) : super(list.createdAt);

  final CuratedListModel list;
}

class _OverlapMovie {
  const _OverlapMovie({
    required this.movieId,
    required this.title,
    this.posterPath,
    required this.count,
  });

  final int movieId;
  final String title;
  final String? posterPath;
  final int count;
}

/// Dedicated activity feed for critics and friends the user follows (`/feed`).
class FollowingFeedScreen extends StatelessWidget {
  const FollowingFeedScreen({super.key, this.onExploreCommunity});

  final VoidCallback? onExploreCommunity;

  List<_OverlapMovie> _computeOverlap(
    Set<String> followingUids,
    List<MovieReviewModel> reviews,
    List<CuratedListModel> lists,
  ) {
    final map = <int, ({String title, String? poster, Set<String> uids})>{};

    for (final r in reviews) {
      if (!followingUids.contains(r.uid)) continue;
      final existing = map[r.movieId];
      if (existing == null) {
        map[r.movieId] = (
          title: r.movieTitle,
          poster: r.posterPath,
          uids: {r.uid},
        );
      } else {
        existing.uids.add(r.uid);
      }
    }

    for (final l in lists) {
      if (!followingUids.contains(l.authorUid)) continue;
      for (final m in l.movies) {
        final existing = map[m.movieId];
        if (existing == null) {
          map[m.movieId] = (
            title: m.title,
            poster: m.posterPath,
            uids: {l.authorUid},
          );
        } else {
          existing.uids.add(l.authorUid);
        }
      }
    }

    final items = map.entries
        .map(
          (e) => _OverlapMovie(
            movieId: e.key,
            title: e.value.title,
            posterPath: e.value.poster,
            count: e.value.uids.length,
          ),
        )
        .toList();

    items.sort((a, b) => b.count.compareTo(a.count));
    return items.take(12).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = context.select<AuthCubit, bool>(
      (c) => c.state.status == AuthStatus.authenticated,
    );
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

    if (!isSignedIn) {
      return ColoredBox(
        color: AppColors.black,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppConstants.maxContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        if (!isWideWeb) ...[
                          const ProfileDrawerButton(),
                          const SizedBox(width: 12),
                        ],
                        Text(
                          'Following Feed',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GuestPromptView(
                      icon: Icons.dynamic_feed_rounded,
                      title: 'Your Following Feed',
                      message:
                          'Sign in and follow critics in Community to see their latest reviews, curated lists, and movie overlap here.',
                      secondaryLabel: onExploreCommunity != null
                          ? 'Explore Community'
                          : null,
                      onSecondaryTap: onExploreCommunity,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: AppColors.black,
      child: SafeArea(
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppConstants.maxContentWidth,
          ),
          child: BlocBuilder<CommunityBloc, CommunityState>(
            builder: (context, state) {
              final bloc = context.read<CommunityBloc>();
              final following =
                  state.profile?.followingUids.toSet() ?? const <String>{};

              if (following.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isWideWeb)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Row(
                          children: [
                            const ProfileDrawerButton(),
                            const SizedBox(width: 12),
                            Text(
                              'Following Feed',
                              style: Theme.of(
                                context,
                              ).textTheme.headlineMedium,
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: EmptyStateView(
                          icon: Icons.dynamic_feed_rounded,
                          title: 'Your Following Feed is empty',
                          message:
                              'Follow critics in Community to see their latest reviews, curated lists, and movie overlap here.',
                          actionLabel: onExploreCommunity != null
                              ? 'Explore Community'
                              : null,
                          onAction: onExploreCommunity,
                        ),
                      ),
                    ),
                  ],
                );
              }

              final followedReviews = state.reviews
                  .where((r) => following.contains(r.uid))
                  .toList();
              final followedLists = state.curatedLists
                  .where((l) => following.contains(l.authorUid))
                  .toList();

              final entries = <_FeedEntry>[
                ...followedReviews.map(_ReviewFeedEntry.new),
                ...followedLists.map(_ListFeedEntry.new),
              ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

              final overlap = _computeOverlap(
                following,
                followedReviews,
                followedLists,
              );

              final challenge = state.activeChallenge;
              final followedParticipants = challenge == null
                  ? const <String>[]
                  : challenge.participantUids
                        .where((uid) => following.contains(uid))
                        .toList();

              return RefreshIndicator(
                color: AppColors.pacificBlue,
                backgroundColor: AppColors.surfaceElevated,
                onRefresh: () async {
                  bloc.add(const CommunityRefreshed());
                  await Future<void>.delayed(const Duration(milliseconds: 400));
                },
                child: CustomScrollView(
                  scrollCacheExtent: const ScrollCacheExtent.pixels(600),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                                        'Following Feed',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineMedium,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Activity from ${following.length} ${following.length == 1 ? 'critic' : 'critics'} you follow',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (followedParticipants.isNotEmpty &&
                                challenge != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceCard,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.khakiBeige.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.local_fire_department_rounded,
                                      color: AppColors.khakiBeige,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${followedParticipants.length} ${followedParticipants.length == 1 ? 'person' : 'people'} you follow joined "${challenge.movieTitle}" Watch Party!',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => MovieDetailsRoute.push(
                                        context,
                                        movieId: challenge.movieId,
                                        initialMovie:
                                            challenge.toMovieSummary(),
                                      ),
                                      child: const Text('Open'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (overlap.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Friends\' Spotlight',
                                style: TextStyle(
                                  color: AppColors.khakiBeige,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 148,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: overlap.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (context, idx) {
                                    final item = overlap[idx];
                                    return InkWell(
                                      onTap: () => MovieDetailsRoute.push(
                                        context,
                                        movieId: item.movieId,
                                        initialMovie: MovieSummary(
                                          id: item.movieId,
                                          title: item.title,
                                          posterPath: item.posterPath,
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        width: 82,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            MoviePoster(
                                              posterPath: item.posterPath,
                                              width: 82,
                                              height: 116,
                                              borderRadius: 10,
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              '${item.count} ${item.count == 1 ? 'friend' : 'friends'}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (entries.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyStateView(
                          icon: Icons.hourglass_empty_rounded,
                          title: 'No recent activity yet',
                          message:
                              'Reviews and curated lists from people you follow will show up here.',
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        sliver: SliverList.separated(
                          itemCount: entries.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            if (entry is _ReviewFeedEntry) {
                              final review = entry.review;
                              final authorProfile =
                                  state.userProfilesByUid[review.uid];
                              return CommunityReviewCard(
                                review: review,
                                isOwner: review.uid == currentUid,
                                isLiked: review.isLikedBy(currentUid),
                                isDisliked: review.isDislikedBy(currentUid),
                                authorPhotoBase64: authorProfile?.photoBase64,
                                authorReputation:
                                    authorProfile?.reputation ?? 0,
                                isAuthorAdmin: state.adminUids.contains(
                                  review.uid,
                                ),
                                isAuthorModerator: state.moderatorUids.contains(
                                  review.uid,
                                ),
                                isInWatchlist: savedMovieIds.contains(
                                  review.movieId,
                                ),
                                onMovieTap: () => MovieDetailsRoute.push(
                                  context,
                                  movieId: review.movieId,
                                  initialMovie: MovieSummary(
                                    id: review.movieId,
                                    title: review.movieTitle,
                                    posterPath: review.posterPath,
                                  ),
                                ),
                                onToggleWatchlist: () async {
                                  final watchlist = context
                                      .read<WatchlistCubit>();
                                  if (savedMovieIds.contains(review.movieId)) {
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
                                onReply: () => ReviewRepliesSheet.show(
                                  context,
                                  review: review,
                                  repository: sl<CommunityRepository>(),
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
                              );
                            }

                            final list = (entry as _ListFeedEntry).list;
                            final authorProfile =
                                state.userProfilesByUid[list.authorUid];
                            return _FollowedListCard(
                              list: list,
                              authorName:
                                  authorProfile?.displayName ?? list.authorName,
                              authorAvatarKey:
                                  authorProfile?.avatarKey ??
                                  list.authorAvatarKey,
                              authorPhotoBase64: authorProfile?.photoBase64,
                              authorReputation: authorProfile?.reputation ?? 0,
                              onClone: () async {
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
                                          'Cloned "${res.collectionName}" to Watchlist!',
                                        ),
                                      ),
                                    );
                                }
                              },
                              onOpenMovie: (m) => MovieDetailsRoute.push(
                                context,
                                movieId: m.movieId,
                                initialMovie: m.toMovieSummary(),
                              ),
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

class _FollowedListCard extends StatelessWidget {
  const _FollowedListCard({
    required this.list,
    required this.authorName,
    required this.authorAvatarKey,
    this.authorPhotoBase64,
    this.authorReputation = 0,
    required this.onClone,
    required this.onOpenMovie,
  });

  final CuratedListModel list;
  final String authorName;
  final String authorAvatarKey;
  final String? authorPhotoBase64;
  final int authorReputation;
  final VoidCallback onClone;
  final ValueChanged<CuratedListMovie> onOpenMovie;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                avatarKey: authorAvatarKey,
                photoBase64: authorPhotoBase64,
                reputation: authorReputation,
                radius: 17,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$authorName published a list',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
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
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: onClone,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.softPeriwinkle,
                  side: BorderSide(
                    color: AppColors.softPeriwinkle.withValues(alpha: 0.45),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.copy_all_rounded, size: 14),
                label: const Text(
                  'Clone',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: list.movies.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final m = list.movies[idx];
                return InkWell(
                  onTap: () => onOpenMovie(m),
                  borderRadius: BorderRadius.circular(8),
                  child: MoviePoster(
                    posterPath: m.posterPath,
                    width: 58,
                    height: 86,
                    borderRadius: 8,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
