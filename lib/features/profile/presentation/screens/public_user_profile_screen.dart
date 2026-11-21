import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/movie_details_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/auth_gate.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../../../shared/widgets/movie_poster.dart';
import '../../../community/data/models/curated_list_model.dart';
import '../../../community/data/models/movie_review_model.dart';
import '../../../community/data/models/user_profile_model.dart';
import '../../../community/presentation/bloc/community_bloc.dart';
import '../../../community/presentation/widgets/follow_list_sheet.dart';
import '../../../community/presentation/widgets/user_avatar_widget.dart';
import '../../../watchlist/presentation/cubit/watchlist_cubit.dart';

/// Full-screen public profile for viewing another CineList user.
class PublicUserProfileScreen extends StatefulWidget {
  const PublicUserProfileScreen({
    super.key,
    required this.uid,
    required this.fallbackName,
    required this.fallbackAvatarKey,
  });

  final String uid;
  final String fallbackName;
  final String fallbackAvatarKey;

  @override
  State<PublicUserProfileScreen> createState() =>
      _PublicUserProfileScreenState();
}

class _PublicUserProfileScreenState extends State<PublicUserProfileScreen> {
  late Future<List<dynamic>> _loadFuture;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<CommunityBloc>();
    _loadFuture = Future.wait([
      bloc.fetchUserProfile(widget.uid),
      bloc.checkIsAdmin(widget.uid),
      bloc.checkIsModerator(widget.uid),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final communityState = context.watch<CommunityBloc>().state;
    final bloc = context.read<CommunityBloc>();
    final viewerUid = bloc.currentUid;
    final isSelf = viewerUid != null && viewerUid == widget.uid;
    final isFollowing =
        communityState.profile?.isFollowing(widget.uid) ?? false;

    final userReviews = communityState.reviews
        .where((r) => r.uid == widget.uid)
        .toList();
    final userLists = communityState.curatedLists
        .where((l) => l.authorUid == widget.uid)
        .toList();
    final avgRating = userReviews.isEmpty
        ? null
        : userReviews.fold<int>(0, (sum, r) => sum + r.rating) /
              userReviews.length;

    return FutureBuilder<List<dynamic>>(
      future: _loadFuture,
      builder: (context, snapshot) {
        final fetchedProfile = snapshot.data?[0] as UserProfileModel?;
        final cachedProfile = communityState.userProfilesByUid[widget.uid];
        final profile = fetchedProfile ?? cachedProfile;

        final isAdmin =
            (snapshot.data?[1] as bool?) ??
            communityState.adminUids.contains(widget.uid);
        final isModerator =
            (snapshot.data?[2] as bool?) ??
            communityState.moderatorUids.contains(widget.uid);

        final displayName = (profile?.displayName.trim().isNotEmpty ?? false)
            ? profile!.displayName
            : widget.fallbackName;
        final avatarKey = (profile?.avatarKey.trim().isNotEmpty ?? false)
            ? profile!.avatarKey
            : widget.fallbackAvatarKey;
        final bio = profile?.bio.trim() ?? '';
        final reputation = profile?.reputation ?? 0;
        final tier = ReputationTier.fromPoints(reputation);
        final nextTier = tier.nextTier;
        final progress = tier.progressToNext(reputation);

        return Scaffold(
          backgroundColor: AppColors.black,
          appBar: AppBar(
            backgroundColor: AppColors.black,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            actions: [
              if (isSelf)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/profile');
                  },
                  child: const Text('My Profile'),
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
                    // Hero Card matching ProfileScreen
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            (isAdmin
                                    ? AppColors.creatorEmerald
                                    : isModerator
                                    ? AppColors.pacificBlue
                                    : tier.color)
                                .withValues(alpha: 0.16),
                            AppColors.surfaceCard,
                            AppColors.softPeriwinkle.withValues(alpha: 0.1),
                          ],
                        ),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Column(
                        children: [
                          UserAvatar(
                            avatarKey: avatarKey,
                            photoBase64: profile?.photoBase64,
                            reputation: reputation,
                            isAdmin: isAdmin,
                            isModerator: isModerator,
                            showRankBadge: true,
                            radius: 44,
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (isAdmin)
                                _RolePill(
                                  label: 'Creator',
                                  color: AppColors.creatorEmerald,
                                  customIcon: const CreatorEmblemIcon(size: 13),
                                )
                              else if (isModerator)
                                const _RolePill(
                                  label: 'Moderator',
                                  color: AppColors.pacificBlue,
                                  icon: Icons.gavel_rounded,
                                ),
                              _RolePill(
                                label: tier.label,
                                color: tier.color,
                                icon: tier.icon,
                              ),
                            ],
                          ),
                          if (bio.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              bio,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13.5,
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          FollowCountsRow(
                            followerUids: FollowListSheet.followersOf(
                              widget.uid,
                              communityState.userProfilesByUid,
                            ),
                            followingUids: profile?.followingUids ?? const [],
                          ),
                          if (!isSelf) ...[
                            const SizedBox(height: 16),
                            isFollowing
                                ? OutlinedButton.icon(
                                    onPressed: () async {
                                      final allowed =
                                          await AuthGate.requireAuth(
                                            context,
                                            actionLabel: 'follow $displayName',
                                          );
                                      if (!allowed || !context.mounted) return;
                                      bloc.add(
                                        CommunityFollowToggled(widget.uid),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.textPrimary,
                                      side: const BorderSide(
                                        color: AppColors.surfaceBorder,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Following'),
                                  )
                                : FilledButton.icon(
                                    onPressed: () async {
                                      final allowed =
                                          await AuthGate.requireAuth(
                                            context,
                                            actionLabel: 'follow $displayName',
                                          );
                                      if (!allowed || !context.mounted) return;
                                      bloc.add(
                                        CommunityFollowToggled(widget.uid),
                                      );
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.pacificBlue,
                                      foregroundColor: AppColors.black,
                                    ),
                                    icon: const Icon(
                                      Icons.person_add_alt_1_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Follow'),
                                  ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Rank & Karma Progress Card
                    Container(
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
                              Icon(tier.icon, size: 18, color: tier.color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Rank: ${tier.label}',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '$reputation Karma',
                                style: const TextStyle(
                                  color: AppColors.khakiBeige,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: AppColors.surfaceElevated,
                              color: tier.color,
                            ),
                          ),
                          if (nextTier != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${nextTier.minPoints - reputation} pts to ${nextTier.label}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Stats Row
                    Row(
                      children: [
                        _StatTile(
                          value: '${userReviews.length}',
                          label: 'Reviews',
                          color: AppColors.pacificBlue,
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          value: '${userLists.length}',
                          label: 'Lists',
                          color: AppColors.khakiBeige,
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          value: '${profile?.followingUids.length ?? 0}',
                          label: 'Following',
                          color: AppColors.softPeriwinkle,
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          value: avgRating != null
                              ? '★ ${avgRating.toStringAsFixed(1)}'
                              : '—',
                          label: 'Avg',
                          color: AppColors.starAmber,
                        ),
                      ],
                    ),
                    if (userLists.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Text(
                        'Curated Lists',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      ...userLists.map(
                        (list) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PublicListCard(
                            list: list,
                            onClone: () async {
                              final allowed = await AuthGate.requireAuth(
                                context,
                                actionLabel:
                                    'clone this list to your Watchlist',
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
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Text(
                      'Recent Reviews',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (userReviews.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: const Text(
                          'No public reviews yet.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    else
                      ...userReviews.map(
                        (review) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PublicReviewTile(
                            review: review,
                            onTap: () => MovieDetailsRoute.push(
                              context,
                              movieId: review.movieId,
                              initialMovie: MovieSummary(
                                id: review.movieId,
                                title: review.movieTitle,
                                posterPath: review.posterPath,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({
    required this.label,
    required this.color,
    this.icon,
    this.customIcon,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final Widget? customIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (customIcon != null)
            customIcon!
          else if (icon != null)
            Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicListCard extends StatelessWidget {
  const _PublicListCard({
    required this.list,
    required this.onClone,
    required this.onOpenMovie,
  });

  final CuratedListModel list;
  final VoidCallback onClone;
  final ValueChanged<CuratedListMovie> onOpenMovie;

  @override
  Widget build(BuildContext context) {
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
              Expanded(
                child: Text(
                  '${list.title} (${list.movies.length})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.khakiBeige,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
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
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.copy_all_rounded, size: 14),
                label: const Text('Clone', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 82,
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
                    width: 54,
                    height: 82,
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

class _PublicReviewTile extends StatelessWidget {
  const _PublicReviewTile({required this.review, required this.onTap});

  final MovieReviewModel review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MoviePoster(
              posterPath: review.posterPath,
              width: 48,
              height: 70,
              borderRadius: 8,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          review.movieTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '★ ${review.rating}/5',
                        style: const TextStyle(
                          color: AppColors.starAmber,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    review.hasSpoilers
                        ? 'Contains spoilers · Tap to open movie'
                        : review.comment,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: review.hasSpoilers
                          ? AppColors.khakiBeige
                          : AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
