import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

/// Reusable loading indicator or animated shimmer skeleton placeholder.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message, this.useSkeleton = false});

  final String? message;
  final bool useSkeleton;

  @override
  Widget build(BuildContext context) {
    if (useSkeleton) {
      return const _DiscoverSkeleton();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppColors.pacificBlue,
              strokeWidth: 2.8,
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Animated shimmer skeleton for the Movie Details body while TMDB loads.
class MovieDetailsSkeleton extends StatelessWidget {
  const MovieDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceCard,
      highlightColor: AppColors.dustyLavender.withValues(alpha: 0.32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _SkeletonBox(height: 28, width: 76, radius: 18),
              _SkeletonBox(height: 28, width: 92, radius: 18),
              _SkeletonBox(height: 28, width: 68, radius: 18),
            ],
          ),
          const SizedBox(height: 24),
          const _SkeletonBox(height: 20, width: 110, radius: 8),
          const SizedBox(height: 12),
          const _SkeletonBox(height: 14, width: double.infinity, radius: 6),
          const SizedBox(height: 8),
          const _SkeletonBox(height: 14, width: double.infinity, radius: 6),
          const SizedBox(height: 8),
          const _SkeletonBox(height: 14, width: 220, radius: 6),
          const SizedBox(height: 26),
          const _SkeletonBox(height: 20, width: 72, radius: 8),
          const SizedBox(height: 14),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, _) => const Column(
                children: [
                  _SkeletonBox(height: 60, width: 60, radius: 30),
                  SizedBox(height: 8),
                  _SkeletonBox(height: 10, width: 58, radius: 5),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverSkeleton extends StatelessWidget {
  const _DiscoverSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceCard,
      highlightColor: AppColors.dustyLavender.withValues(alpha: 0.32),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: const [
          _SkeletonBox(height: 205, width: double.infinity, radius: 22),
          SizedBox(height: 22),
          _SkeletonBox(height: 20, width: 150, radius: 8),
          SizedBox(height: 14),
          SizedBox(
            height: 210,
            child: Row(
              children: [
                Expanded(child: _SkeletonBox(radius: 16)),
                SizedBox(width: 12),
                Expanded(child: _SkeletonBox(radius: 16)),
                SizedBox(width: 12),
                Expanded(child: _SkeletonBox(radius: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer skeleton row shown at the bottom of Discover's grid while lazy-loading.
class DiscoverGridLazyRowSkeleton extends StatelessWidget {
  const DiscoverGridLazyRowSkeleton({
    super.key,
    required this.columns,
    required this.spacing,
    required this.aspectRatio,
  });

  final int columns;
  final double spacing;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final count = columns.clamp(2, 5);
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceCard,
      highlightColor: AppColors.dustyLavender.withValues(alpha: 0.32),
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            Expanded(
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Expanded(child: _SkeletonBox(radius: 14)),
                    SizedBox(height: 8),
                    _SkeletonBox(height: 11, width: double.infinity, radius: 5),
                    SizedBox(height: 5),
                    _SkeletonBox(height: 10, width: 52, radius: 5),
                  ],
                ),
              ),
            ),
            if (i < count - 1) SizedBox(width: spacing),
          ],
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.height, this.width, required this.radius});

  final double? height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
