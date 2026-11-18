import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Compact summary card showing completion rate, hours watched, and avg rating.
class WatchlistStatsCard extends StatelessWidget {
  const WatchlistStatsCard({
    super.key,
    required this.totalMovies,
    required this.watchedCount,
    required this.completionPercent,
    required this.totalMinutesWatched,
    this.averagePersonalRating,
    this.onTap,
  });

  final int totalMovies;
  final int watchedCount;
  final int completionPercent;
  final int totalMinutesWatched;
  final double? averagePersonalRating;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (totalMovies == 0) return const SizedBox.shrink();

    final hoursWatched = (totalMinutesWatched / 60).toStringAsFixed(1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
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
            _StatItem(
              label: 'Watched',
              value: '$watchedCount/$totalMovies',
              accent: AppColors.pacificBlue,
            ),
            _Divider(),
            _StatItem(
              label: 'Completion',
              value: '$completionPercent%',
              accent: AppColors.khakiBeige,
            ),
            _Divider(),
            _StatItem(
              label: 'Hours',
              value: '${hoursWatched}h',
              accent: AppColors.softPeriwinkle,
            ),
            if (averagePersonalRating != null) ...[
              _Divider(),
              _StatItem(
                label: 'My Avg',
                value: '★ ${averagePersonalRating!.toStringAsFixed(1)}',
                accent: AppColors.starAmber,
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 26, color: AppColors.surfaceBorder);
  }
}
