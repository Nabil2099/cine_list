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
  late String? _upcomingBadge;

  @override
  void initState() {
    super.initState();
    _upcomingBadge = _upcomingBadgeText(widget.movie.releaseDate);
  }

  @override
  void didUpdateWidget(covariant MovieCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movie.releaseDate != widget.movie.releaseDate) {
      _upcomingBadge = _upcomingBadgeText(widget.movie.releaseDate);
    }
  }

  static String? _upcomingBadgeText(String? releaseDate) {
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

  Widget _buildCardContent({required bool isCompact}) {
    final saved = widget.isSaved ?? false;
    final radius = isCompact ? 13.0 : 16.0;
    final inset = isCompact ? 6.0 : 8.0;
    final bookmarkSize = isCompact ? 26.0 : 30.0;

    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (value) {
          if (_pressed != value) {
            setState(() => _pressed = value);
          }
        },
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MoviePoster(
                    posterPath: widget.movie.posterPath,
                    width: widget.width,
                    borderRadius: radius,
                    heroTag: widget.heroTag,
                  ),
                  if (widget.onToggleSave != null)
                    Positioned(
                      top: inset,
                      left: inset,
                      child: GestureDetector(
                        onTap: widget.onToggleSave,
                        child: Container(
                          width: bookmarkSize,
                          height: bookmarkSize,
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
                            size: isCompact ? 14 : 16,
                            color: saved
                                ? AppColors.pacificBlue
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: inset,
                    right: inset,
                    child: RatingBadge(
                      rating: widget.movie.voteAverage,
                      fontSize: isCompact ? 10.5 : 12.0,
                      iconSize: isCompact ? 11.5 : 14.0,
                      filled: true,
                    ),
                  ),
                  if (_upcomingBadge case final badge?)
                    Positioned(
                      bottom: inset,
                      left: inset,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 5 : 7,
                          vertical: isCompact ? 2 : 3,
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
                          style: TextStyle(
                            color: AppColors.khakiBeige,
                            fontSize: isCompact ? 9 : 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: isCompact ? 6 : 8),
            Text(
              widget.movie.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: isCompact ? 12.2 : 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                RatingBadge(
                  rating: widget.movie.voteAverage,
                  fontSize: isCompact ? 10.5 : 11.5,
                  iconSize: isCompact ? 11.5 : 13,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    Formatters.releaseYear(widget.movie.releaseDate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: isCompact ? 10.5 : 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.width != null) {
      return RepaintBoundary(
        child: SizedBox(
          width: widget.width,
          child: _buildCardContent(isCompact: widget.width! < 120),
        ),
      );
    }

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact =
              constraints.maxWidth.isFinite && constraints.maxWidth < 120;
          return _buildCardContent(isCompact: isCompact);
        },
      ),
    );
  }
}
