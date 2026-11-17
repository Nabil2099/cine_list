import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
import '../cubit/community_cubit.dart';
import '../cubit/community_state.dart';
import '../widgets/community_review_card.dart';
import '../widgets/edit_profile_dialog.dart';
import '../widgets/report_review_dialog.dart';
import '../widgets/user_avatar_widget.dart';
import '../widgets/user_profile_dialog.dart';

/// Community tab displaying the user's editable profile (avatar + bio) and
/// the public movie reviews feed.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  Future<void> _editProfile(
    BuildContext context,
    UserProfileModel profile,
  ) async {
    final result = await EditProfileDialog.show(
      context,
      initialProfile: profile,
    );
    if (result != null && context.mounted) {
      await context.read<CommunityCubit>().updateProfile(
        displayName: result.displayName,
        bio: result.bio,
        avatarKey: result.avatarKey,
      );
    }
  }

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
          child: BlocConsumer<CommunityCubit, CommunityState>(
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
                context.read<CommunityCubit>().clearFeedback();
              }
            },
            builder: (context, state) {
              final profile =
                  state.profile ??
                  UserProfileModel(
                    uid: currentUid ?? '',
                    displayName: 'Movie Fan',
                  );

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Community',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium,
                                ),
                              ),
                              if (state.isAdmin)
                                OutlinedButton.icon(
                                  onPressed: () => context.push('/admin'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.khakiBeige,
                                    side: BorderSide(
                                      color: AppColors.khakiBeige.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.admin_panel_settings_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Admin'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Share your taste, bio, and movie reviews',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          _ProfileCard(
                            profile: profile,
                            onEdit: () => _editProfile(context, profile),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent Reviews',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                '${state.reviews.length} posts',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  if (state.status == CommunityStatus.loading ||
                      state.status == CommunityStatus.initial)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: LoadingView(message: 'Loading community feed...'),
                    )
                  else if (state.status == CommunityStatus.error)
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
                        icon: Icons.forum_outlined,
                        title: 'No reviews yet',
                        message: 'Open any movie and tap "Write a Review" to start the conversation.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverList.separated(
                        itemCount: state.reviews.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final review = state.reviews[index];
                          return CommunityReviewCard(
                            review: review,
                            isOwner: review.uid == currentUid,
                            isLiked: review.isLikedBy(currentUid),
                            isDisliked: review.isDislikedBy(currentUid),
                            onMovieTap: () => _openMovie(context, review),
                            onAuthorTap: () => UserProfileDialog.show(
                              context,
                              uid: review.uid,
                              fallbackName: review.authorName,
                              fallbackAvatarKey: review.authorAvatarKey,
                            ),
                            onToggleLike: () => context
                                .read<CommunityCubit>()
                                .toggleLike(review),
                            onToggleDislike: () => context
                                .read<CommunityCubit>()
                                .toggleDislike(review),
                            onReport: () async {
                              final res = await ReportReviewDialog.show(
                                context,
                                authorName: review.authorName,
                              );
                              if (res != null && context.mounted) {
                                await context
                                    .read<CommunityCubit>()
                                    .reportReview(
                                      review: review,
                                      reason: res.reason,
                                      details: res.details,
                                    );
                              }
                            },
                            onShare: () => SharePlus.instance.share(
                              ShareParams(
                                text:
                                    '${review.authorName} rated "${review.movieTitle}" ${review.rating}/5 on CineList:\n\n"${review.comment}"\n\nhttps://www.themoviedb.org/movie/${review.movieId}',
                              ),
                            ),
                            onDelete: () => context
                                .read<CommunityCubit>()
                                .deleteReview(review.id),
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onEdit});

  final UserProfileModel profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceCard,
            AppColors.dustyLavender.withValues(alpha: 0.22),
          ],
        ),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          UserAvatar(avatarKey: profile.avatarKey, radius: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.khakiBeige,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.bio.trim().isNotEmpty ? profile.bio.trim() : 'Add a bio to tell the community what you love watching.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: profile.bio.trim().isNotEmpty
                        ? AppColors.textSecondary
                        : AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.pacificBlue,
              side: const BorderSide(color: AppColors.pacificBlue),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
