import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/movie_poster.dart';
import '../../data/models/movie_review_model.dart';
import 'user_avatar_widget.dart';

/// Card displaying a community movie review with author avatar, rating, and movie link.
class CommunityReviewCard extends StatelessWidget {
  const CommunityReviewCard({
    super.key,
    required this.review,
    required this.isOwner,
    this.isLiked = false,
    this.isDisliked = false,
    this.authorPhotoBase64,
    this.authorReputation = 0,
    this.isAuthorAdmin = false,
    this.isAuthorModerator = false,
    this.showMovieHeader = true,
    this.onMovieTap,
    this.onAuthorTap,
    this.onToggleLike,
    this.onToggleDislike,
    this.onReport,
    this.onShare,
    this.onDelete,
  });

  final MovieReviewModel review;
  final bool isOwner;
  final bool isLiked;
  final bool isDisliked;
  final String? authorPhotoBase64;
  final int authorReputation;
  final bool isAuthorAdmin;
  final bool isAuthorModerator;
  final bool showMovieHeader;
  final VoidCallback? onMovieTap;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onToggleLike;
  final VoidCallback? onToggleDislike;
  final VoidCallback? onReport;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

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
              Expanded(
                child: InkWell(
                  onTap: onAuthorTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        UserAvatar(
                          avatarKey: review.authorAvatarKey,
                          photoBase64: authorPhotoBase64,
                          reputation: authorReputation,
                          isAdmin: isAuthorAdmin,
                          isModerator: isAuthorModerator,
                          radius: 19,
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
                                      review.authorName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (isAuthorAdmin) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.khakiBeige.withValues(
                                          alpha: 0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: AppColors.khakiBeige
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                      child: const Text(
                                        'Admin',
                                        style: TextStyle(
                                          color: AppColors.khakiBeige,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ] else if (isAuthorModerator) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.pacificBlue.withValues(
                                          alpha: 0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: AppColors.pacificBlue
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                      child: const Text(
                                        'Mod',
                                        style: TextStyle(
                                          color: AppColors.pacificBlue,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                _formatDate(review.createdAt),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 15,
                    color: i < review.rating
                        ? AppColors.starAmber
                        : AppColors.textMuted,
                  ),
                ),
              ),
              if (isOwner && onDelete != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppColors.error,
                  ),
                  tooltip: 'Delete review',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          if (showMovieHeader) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: onMovieTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  children: [
                    MoviePoster(
                      posterPath: review.posterPath,
                      width: 38,
                      height: 54,
                      borderRadius: 8,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        review.movieTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.khakiBeige,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            review.comment,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              InkWell(
                onTap: onToggleLike,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isLiked
                        ? AppColors.khakiBeige.withValues(alpha: 0.16)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isLiked
                          ? AppColors.khakiBeige.withValues(alpha: 0.5)
                          : AppColors.surfaceBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLiked
                            ? Icons.thumb_up_rounded
                            : Icons.thumb_up_outlined,
                        size: 14,
                        color: isLiked
                            ? AppColors.khakiBeige
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        review.likedBy.isEmpty
                            ? 'Helpful'
                            : 'Helpful (${review.likedBy.length})',
                        style: TextStyle(
                          color: isLiked
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
              const SizedBox(width: 8),
              InkWell(
                onTap: onToggleDislike,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDisliked
                        ? AppColors.error.withValues(alpha: 0.16)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDisliked
                          ? AppColors.error.withValues(alpha: 0.5)
                          : AppColors.surfaceBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDisliked
                            ? Icons.thumb_down_rounded
                            : Icons.thumb_down_outlined,
                        size: 14,
                        color: isDisliked
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                      if (review.dislikedBy.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${review.dislikedBy.length}',
                          style: TextStyle(
                            color: isDisliked
                                ? AppColors.error
                                : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (!isOwner && onReport != null)
                IconButton(
                  onPressed: onReport,
                  icon: const Icon(
                    Icons.flag_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Report review',
                  visualDensity: VisualDensity.compact,
                ),
              if (onShare != null)
                IconButton(
                  onPressed: onShare,
                  icon: const Icon(
                    Icons.share_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Share review',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
