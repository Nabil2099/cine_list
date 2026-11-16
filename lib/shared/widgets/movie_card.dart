import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/rating_badge.dart';
import '../models/movie_summary.dart';
import 'movie_poster.dart';

/// Reusable poster card used in horizontal carousels and responsive grids.
class MovieCard extends StatefulWidget {
  const MovieCard({
    super.key,
    required this.movie,
    required this.onTap,
    this.width,
    this.heroTag,
    this.isSaved,
    this.onToggleSave,
  });

  final MovieSummary movie;
  final VoidCallback onTap;
  final double? width;
  final String? heroTag;
  final bool? isSaved;
  final VoidCallback? onToggleSave;

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _pressed = false;

  String? _upcomingBadgeText(String? releaseDate) {
    if (releaseDate == null || releaseDate.isEmpty) return null;
    final parsed = DateTime.tryParse(releaseDate);
    if (parsed == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final releaseDay = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = releaseDay.difference(today).inDays;
    if (diff <= 0) return null;
    if (diff <= 30) return 'In ${diff}d';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.day}';
  }

  @override
  Widget build(BuildContext context) {
    final saved = widget.isSaved ?? false;

    final card = AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (value) => setState(() => _pressed = value),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MoviePoster(
                    posterPath: widget.movie.posterPath,
                    borderRadius: 16,
                    heroTag: widget.heroTag,
                  ),
                  if (widget.onToggleSave != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: GestureDetector(
                        onTap: widget.onToggleSave,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.black.withValues(alpha: 0.72),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: saved
                                  ? AppColors.pacificBlue
                                  : AppColors.surfaceBorder.withValues(
                                      alpha: 0.8,
                                    ),
                            ),
                          ),
                          child: Icon(
                            saved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            size: 16,
                            color: saved
                                ? AppColors.pacificBlue
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: RatingBadge(
                      rating: widget.movie.voteAverage,
                      filled: true,
                    ),
                  ),
                  if (_upcomingBadgeText(widget.movie.releaseDate)
                      case final badge?)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.black.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.khakiBeige.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: AppColors.khakiBeige,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.movie.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                RatingBadge(
                  rating: widget.movie.voteAverage,
                  fontSize: 11.5,
                  iconSize: 13,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Formatters.releaseYear(widget.movie.releaseDate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (widget.width != null) {
      return SizedBox(width: widget.width, child: card);
    }
    return card;
  }
}
