import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/movie_details_route.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../data/models/movie_review_model.dart';
import '../cubit/community_cubit.dart';
import '../cubit/community_state.dart';
import '../widgets/community_review_card.dart';
import '../widgets/report_review_dialog.dart';
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
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent Reviews',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                '${state.reviews.length} reviews',
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
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverList.separated(
                        itemCount: state.reviews.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final review = state.reviews[index];
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
