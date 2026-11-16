import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../../../shared/widgets/movie_poster.dart';

/// Celebration dialog shown the instant 2+ participants like the same movie.
class MatchCelebrationDialog extends StatelessWidget {
  const MatchCelebrationDialog({
    super.key,
    required this.movie,
    required this.onOpenDetails,
  });

  final MovieSummary movie;
  final VoidCallback onOpenDetails;

  static Future<void> show(
    BuildContext context, {
    required MovieSummary movie,
    required VoidCallback onOpenDetails,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          MatchCelebrationDialog(movie: movie, onOpenDetails: onOpenDetails),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: AppColors.pacificBlue.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      title: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.celebration_rounded,
            color: AppColors.khakiBeige,
            size: 26,
          ),
          SizedBox(width: 8),
          Text(
            'It\'s a Match!',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'You both picked this film for movie night!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          MoviePoster(
            posterPath: movie.posterPath,
            width: 132,
            height: 194,
            borderRadius: 16,
          ),
          const SizedBox(height: 14),
          Text(
            movie.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${Formatters.releaseYear(movie.releaseDate)}  •  ${movie.voteAverage.toStringAsFixed(1)}★',
            style: const TextStyle(
              color: AppColors.khakiBeige,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Keep Swiping'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            onOpenDetails();
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Trailer & Details'),
        ),
      ],
    );
  }
}
