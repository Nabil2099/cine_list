import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/rating_badge.dart';
import '../../../../shared/widgets/movie_poster.dart';
import '../../data/models/watchlist_movie_model.dart';

/// Reusable watchlist card matching the reference Watchlist screen.
class WatchlistMovieTile extends StatelessWidget {
  const WatchlistMovieTile({
    super.key,
    required this.movie,
    required this.onTap,
    required this.onToggleStatus,
    required this.onRemove,
    this.onRateAndNote,
    this.onManageCollections,
    this.isMutating = false,
    this.heroTag,
  });

  final WatchlistMovieModel movie;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;
  final VoidCallback onRemove;
  final VoidCallback? onRateAndNote;
  final VoidCallback? onManageCollections;
  final bool isMutating;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final isWatched = movie.isWatched;
    final hasReview =
        movie.userRating != null ||
        (movie.userNote != null && movie.userNote!.trim().isNotEmpty);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfaceCard,
              AppColors.dustyLavender.withValues(alpha: 0.14),
            ],
          ),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            MoviePoster(
              posterPath: movie.posterPath,
              width: 68,
              height: 98,
              borderRadius: 12,
              heroTag: heroTag,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        Formatters.releaseYear(movie.releaseDate),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      RatingBadge(
                        rating: movie.voteAverage,
                        fontSize: 12.5,
                        iconSize: 14,
                      ),
                      if (movie.userRating != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          'My ★ ${movie.userRating}/5',
                          style: const TextStyle(
                            color: AppColors.pacificBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (hasReview &&
                      movie.userNote != null &&
                      movie.userNote!.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      '"${movie.userNote!.trim()}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isWatched
                          ? AppColors.pacificBlue.withValues(alpha: 0.16)
                          : AppColors.softPeriwinkle.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isWatched
                            ? AppColors.pacificBlue.withValues(alpha: 0.45)
                            : AppColors.softPeriwinkle.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      isWatched ? 'Watched' : 'Want to Watch',
                      style: TextStyle(
                        color: isWatched
                            ? AppColors.pacificBlue
                            : AppColors.softPeriwinkle,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                PopupMenuButton<String>(
                  enabled: !isMutating,
                  color: AppColors.surfaceElevated,
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onSelected: (value) {
                    if (value == 'toggle') {
                      onToggleStatus();
                    } else if (value == 'review') {
                      onRateAndNote?.call();
                    } else if (value == 'collections') {
                      onManageCollections?.call();
                    } else if (value == 'remove') {
                      onRemove();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            isWatched
                                ? Icons.bookmark_outline_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 18,
                            color: AppColors.pacificBlue,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isWatched
                                ? 'Move to Want to Watch'
                                : 'Mark as Watched',
                          ),
                        ],
                      ),
                    ),
                    if (isWatched && onRateAndNote != null)
                      const PopupMenuItem<String>(
                        value: 'review',
                        child: Row(
                          children: [
                            Icon(
                              Icons.rate_review_outlined,
                              size: 18,
                              color: AppColors.khakiBeige,
                            ),
                            SizedBox(width: 10),
                            Text('Rate & Note'),
                          ],
                        ),
                      ),
                    if (onManageCollections != null)
                      const PopupMenuItem<String>(
                        value: 'collections',
                        child: Row(
                          children: [
                            Icon(
                              Icons.collections_bookmark_outlined,
                              size: 18,
                              color: AppColors.softPeriwinkle,
                            ),
                            SizedBox(width: 10),
                            Text('Add to Collection'),
                          ],
                        ),
                      ),
                    const PopupMenuItem<String>(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Remove from Watchlist',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (isMutating)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.pacificBlue,
                    ),
                  )
                else
                  IconButton(
                    onPressed: onToggleStatus,
                    tooltip: isWatched
                        ? 'Move to Want to Watch'
                        : 'Mark as Watched',
                    icon: Icon(
                      isWatched
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isWatched
                          ? AppColors.pacificBlue
                          : AppColors.textMuted,
                      size: 24,
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
