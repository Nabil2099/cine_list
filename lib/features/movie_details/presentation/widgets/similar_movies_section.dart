import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/movie_details_route.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../../../shared/widgets/movie_card.dart';

/// Horizontal "More Like This" recommendations carousel on Movie Details.
class SimilarMoviesSection extends StatelessWidget {
  const SimilarMoviesSection({super.key, required this.movies});

  final List<MovieSummary> movies;

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();
    final isWide =
        MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('More Like This', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        SizedBox(
          height: isWide ? 235 : 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            separatorBuilder: (_, _) => SizedBox(width: isWide ? 14 : 10),
            itemBuilder: (context, index) {
              final movie = movies[index];
              final heroTag = 'similar-${movie.id}-$index';
              return MovieCard(
                movie: movie,
                width: isWide ? 132 : 108,
                heroTag: heroTag,
                onTap: () {
                  MovieDetailsRoute.push(
                    context,
                    movieId: movie.id,
                    initialMovie: movie,
                    heroTag: heroTag,
                    mediaType: movie.mediaType,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
