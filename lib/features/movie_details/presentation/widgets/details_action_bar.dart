import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../watchlist/data/models/watchlist_movie_model.dart';

/// Bottom sticky action bar for adding, removing, or toggling watched status.
class DetailsActionBar extends StatelessWidget {
  const DetailsActionBar({
    super.key,
    required this.savedItem,
    required this.isMutating,
    required this.onAdd,
    required this.onToggleWatched,
    required this.onRemove,
  });

  final WatchlistMovieModel? savedItem;
  final bool isMutating;
  final VoidCallback onAdd;
  final VoidCallback onToggleWatched;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isSaved = savedItem != null;
    final isWatched = savedItem?.isWatched ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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
                ? PrimaryButton(
                    label: 'Add to Watchlist',
                    icon: Icons.bookmark_add_outlined,
                    isLoading: isMutating,
                    onPressed: onAdd,
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: PrimaryButton(
                          label: isWatched ? 'Watched' : 'Mark Watched',
                          icon: isWatched
                              ? Icons.check_circle_rounded
                              : Icons.check_circle_outline_rounded,
                          backgroundColor: isWatched
                              ? AppColors.dustyLavender
                              : AppColors.pacificBlue,
                          foregroundColor: isWatched
                              ? AppColors.textPrimary
                              : AppColors.black,
                          isLoading: isMutating,
                          onPressed: onToggleWatched,
                        ),
                      ),
                      const SizedBox(width: 12),
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
                  ),
          ),
        ),
      ),
    );
  }
}
