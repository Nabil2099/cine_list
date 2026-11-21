import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../watchlist/data/models/watchlist_movie_model.dart';

/// Bottom sticky action bar supporting direct Mark Watched, Watchlist toggle,
/// and unified Rate & Review launch.
class DetailsActionBar extends StatelessWidget {
  const DetailsActionBar({
    super.key,
    required this.savedItem,
    required this.isMutating,
    required this.onAddToWatchlist,
    required this.onMarkWatched,
    required this.onRateAndReview,
    required this.onUnwatch,
    required this.onRemove,
  });

  final WatchlistMovieModel? savedItem;
  final bool isMutating;
  final VoidCallback onAddToWatchlist;
  final VoidCallback onMarkWatched;
  final VoidCallback onRateAndReview;
  final VoidCallback onUnwatch;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isSaved = savedItem != null;
    final isWatched = savedItem?.isWatched ?? false;
    final isCompact = MediaQuery.sizeOf(context).width < 650;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isCompact ? 14 : 16,
        isCompact ? 10 : 12,
        isCompact ? 14 : 16,
        isCompact ? 10 : 14,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 0.8),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: !isSaved
                ? Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: PrimaryButton(
                          label: 'Watchlist',
                          icon: Icons.bookmark_add_outlined,
                          isOutlined: true,
                          isLoading: isMutating,
                          onPressed: onAddToWatchlist,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: PrimaryButton(
                          label: 'Mark Watched',
                          icon: Icons.check_circle_outline_rounded,
                          isLoading: isMutating,
                          onPressed: onMarkWatched,
                        ),
                      ),
                    ],
                  )
                : !isWatched
                ? Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: PrimaryButton(
                          label: 'Mark Watched',
                          icon: Icons.check_circle_outline_rounded,
                          isLoading: isMutating,
                          onPressed: onMarkWatched,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: PrimaryButton(
                          label: 'Remove',
                          icon: Icons.delete_outline_rounded,
                          isOutlined: true,
                          backgroundColor: AppColors.error.withValues(
                            alpha: 0.65,
                          ),
                          foregroundColor: AppColors.error,
                          isLoading: isMutating,
                          onPressed: onRemove,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: savedItem!.userRating != null
                              ? '★ ${savedItem!.userRating}/5 · Edit Review'
                              : 'Rate & Review',
                          icon: Icons.rate_review_outlined,
                          isLoading: isMutating,
                          onPressed: onRateAndReview,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: PopupMenuButton<String>(
                          enabled: !isMutating,
                          color: AppColors.surfaceElevated,
                          tooltip: 'Watchlist options',
                          icon: const Icon(
                            Icons.more_horiz_rounded,
                            color: AppColors.textPrimary,
                          ),
                          onSelected: (value) {
                            if (value == 'unwatch') {
                              onUnwatch();
                            } else if (value == 'remove') {
                              onRemove();
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem<String>(
                              value: 'unwatch',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.bookmark_outline_rounded,
                                    size: 18,
                                    color: AppColors.pacificBlue,
                                  ),
                                  SizedBox(width: 10),
                                  Text('Move to Want to Watch'),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
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
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
