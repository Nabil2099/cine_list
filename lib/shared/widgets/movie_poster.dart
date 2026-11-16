import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_colors.dart';

/// Reusable movie poster widget with CachedNetworkImage, fallback, and optional Hero.
class MoviePoster extends StatelessWidget {
  const MoviePoster({
    super.key,
    required this.posterPath,
    this.width,
    this.height,
    this.borderRadius = 14,
    this.aspectRatio = 2 / 3,
    this.fit = BoxFit.cover,
    this.heroTag,
  });

  final String? posterPath;
  final double? width;
  final double? height;
  final double borderRadius;
  final double aspectRatio;
  final BoxFit fit;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final url = ApiConstants.posterUrl(posterPath);

    Widget image;
    if (url == null) {
      image = const _PosterFallback();
    } else {
      image = CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        placeholder: (_, _) => const _PosterPlaceholder(),
        errorWidget: (_, _, _) => const _PosterFallback(),
      );
    }

    Widget result = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: image,
    );

    if (heroTag != null) {
      result = Hero(tag: heroTag!, child: result);
    }

    if (width != null || height != null) {
      return SizedBox(width: width, height: height, child: result);
    }

    return AspectRatio(aspectRatio: aspectRatio, child: result);
  }
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceCard,
            AppColors.dustyLavender.withValues(alpha: 0.25),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.movie_outlined, color: AppColors.textMuted, size: 28),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceCard,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_movies_outlined,
              color: AppColors.textMuted,
              size: 30,
            ),
            SizedBox(height: 6),
            Text(
              'No Poster',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
