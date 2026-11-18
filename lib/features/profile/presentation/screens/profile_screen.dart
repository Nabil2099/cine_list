import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/movie_details_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../community/data/models/movie_review_model.dart';
import '../../../community/data/models/user_profile_model.dart';
import '../../../community/presentation/bloc/community_bloc.dart';
import '../../../community/presentation/widgets/edit_profile_dialog.dart';
import '../../../community/presentation/widgets/user_avatar_widget.dart';
import '../../../watchlist/presentation/cubit/watchlist_cubit.dart';

/// Full user profile screen with photo upload, cinema stats, recent reviews,
/// and account/security actions.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editProfile(
    BuildContext context,
    UserProfileModel profile,
  ) async {
    final result = await EditProfileDialog.show(
      context,
      initialProfile: profile,
    );
    if (result != null && context.mounted) {
      context.read<CommunityBloc>().add(
        CommunityProfileUpdated(
          displayName: result.displayName,
          bio: result.bio,
          avatarKey: result.avatarKey,
          photoBase64: result.photoBase64,
          clearPhoto: result.clearPhoto,
        ),
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profile updated.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final communityState = context.watch<CommunityBloc>().state;
    final watchlistState = context.watch<WatchlistCubit>().state;

    final user = authState.user;
    final uid = user?.uid ?? '';
    final email = user?.email ?? '';
    final profile =
        communityState.profile ??
        UserProfileModel(
          uid: uid,
          displayName: user?.displayName?.trim().isNotEmpty == true
              ? user!.displayName!.trim()
              : 'Movie Fan',
        );

    final myReviews = communityState.reviews
        .where((r) => r.uid == uid)
        .toList();
    final hoursWatched = (watchlistState.totalMinutesWatched / 60)
        .toStringAsFixed(1);

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/discover'),
        ),
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _editProfile(context, profile),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
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
                // Profile Hero Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.pacificBlue.withValues(alpha: 0.16),
                        AppColors.surfaceCard,
                        AppColors.softPeriwinkle.withValues(alpha: 0.12),
                      ],
                    ),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _editProfile(context, profile),
                        child: Stack(
                          children: [
                            UserAvatar(
                              avatarKey: profile.avatarKey,
                              photoBase64: profile.photoBase64,
                              reputation: profile.reputation,
                              isAdmin: communityState.isAdmin,
                              isModerator: communityState.isModerator,
                              showRankBadge: false,
                              radius: 44,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.pacificBlue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.black,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 14,
                                  color: AppColors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            profile.displayName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (communityState.isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.khakiBeige.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColors.khakiBeige.withValues(
                                    alpha: 0.65,
                                  ),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_user_rounded,
                                    size: 13,
                                    color: AppColors.khakiBeige,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Admin',
                                    style: TextStyle(
                                      color: AppColors.khakiBeige,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (communityState.isModerator)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.pacificBlue.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColors.pacificBlue.withValues(
                                    alpha: 0.65,
                                  ),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.gavel_rounded,
                                    size: 13,
                                    color: AppColors.pacificBlue,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Moderator',
                                    style: TextStyle(
                                      color: AppColors.pacificBlue,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          email,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        profile.bio.isNotEmpty ? profile.bio : 'Tap Edit to upload a photo or add your cinema bio.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: profile.bio.isNotEmpty
                              ? AppColors.textSecondary
                              : AppColors.textMuted,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _editProfile(context, profile),
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: const Text('Change Photo & Profile'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                _KarmaRankCard(profile: profile),

                const SizedBox(height: 20),

                // Stats Grid
                Text(
                  'Your Cinema Stats',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatBox(
                      value: '${watchlistState.movies.length}',
                      label: 'Saved',
                      color: AppColors.pacificBlue,
                    ),
                    const SizedBox(width: 10),
                    _StatBox(
                      value: '${watchlistState.watchedMovies.length}',
                      label: 'Watched',
                      color: AppColors.khakiBeige,
                    ),
                    const SizedBox(width: 10),
                    _StatBox(
                      value: '${hoursWatched}h',
                      label: 'Hours',
                      color: AppColors.softPeriwinkle,
                    ),
                    const SizedBox(width: 10),
                    _StatBox(
                      value: '${myReviews.length}',
                      label: 'Reviews',
                      color: AppColors.success,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Recent Reviews by User
                Text(
                  'My Reviews',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                if (myReviews.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: const Text(
                      'You haven\'t published any community reviews yet.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  ...myReviews
                      .take(5)
                      .map(
                        (MovieReviewModel r) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            tileColor: AppColors.surfaceCard,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(
                                color: AppColors.surfaceBorder,
                              ),
                            ),
                            title: Text(
                              '${r.movieTitle}  ·  ${r.rating}★',
                              style: const TextStyle(
                                color: AppColors.khakiBeige,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              r.comment,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textMuted,
                            ),
                            onTap: () => MovieDetailsRoute.push(
                              context,
                              movieId: r.movieId,
                              initialMovie: MovieSummary(
                                id: r.movieId,
                                title: r.movieTitle,
                                posterPath: r.posterPath,
                              ),
                            ),
                          ),
                        ),
                      ),

                const SizedBox(height: 20),

                // Account & Security
                Text(
                  'Account & Security',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          user?.emailVerified == true
                              ? Icons.verified_user_rounded
                              : Icons.mark_email_unread_outlined,
                          color: user?.emailVerified == true
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                        title: const Text('Email Verification'),
                        subtitle: Text(
                          user?.emailVerified == true
                              ? 'Verified'
                              : 'Not verified',
                        ),
                      ),
                      if (email.isNotEmpty) ...[
                        const Divider(
                          height: 1,
                          color: AppColors.surfaceBorder,
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.lock_reset_rounded,
                            color: AppColors.khakiBeige,
                          ),
                          title: const Text('Reset Password'),
                          subtitle: Text('Send reset link to $email'),
                          onTap: () async {
                            await context.read<AuthCubit>().sendPasswordReset(
                              email,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Password reset link sent to $email.',
                                    ),
                                  ),
                                );
                            }
                          },
                        ),
                      ],
                      if (communityState.isStaff) ...[
                        const Divider(
                          height: 1,
                          color: AppColors.surfaceBorder,
                        ),
                        ListTile(
                          leading: Icon(
                            communityState.isAdmin
                                ? Icons.admin_panel_settings_outlined
                                : Icons.gavel_rounded,
                            color: communityState.isAdmin
                                ? AppColors.khakiBeige
                                : AppColors.pacificBlue,
                          ),
                          title: Text(
                            communityState.isAdmin
                                ? 'Admin Moderation Panel'
                                : 'Moderation Panel',
                          ),
                          subtitle: Text(
                            communityState.isAdmin
                                ? 'Manage moderators, reports, reviews & users'
                                : 'Review reports & delete offending reviews',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/admin'),
                        ),
                      ],
                      const Divider(height: 1, color: AppColors.surfaceBorder),
                      ListTile(
                        leading: const Icon(
                          Icons.logout_rounded,
                          color: AppColors.error,
                        ),
                        title: const Text(
                          'Sign Out',
                          style: TextStyle(color: AppColors.error),
                        ),
                        onTap: () => context.read<AuthCubit>().signOut(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
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
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KarmaRankCard extends StatelessWidget {
  const _KarmaRankCard({required this.profile});

  final UserProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final tier = profile.tier;
    final next = tier.nextTier;
    final progress = tier.progressToNext(profile.reputation);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tier.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tier.color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(tier.icon, color: tier.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rank: ${tier.label}',
                      style: TextStyle(
                        color: tier.color,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      next == null
                          ? 'Highest CineList rank unlocked!'
                          : '${next.minPoints - profile.reputation} pts to ${next.label}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Text(
                  '${profile.reputation} Karma',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.surfaceElevated,
              color: tier.color,
            ),
          ),
        ],
      ),
    );
  }
}
