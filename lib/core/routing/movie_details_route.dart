import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/movie_details/presentation/screens/movie_details_screen.dart';
import '../../shared/models/movie_summary.dart';

/// Optional route extras passed when navigating to Movie Details.
class MovieDetailsExtra {
  const MovieDetailsExtra({
    this.initialMovie,
    this.heroTag,
    this.mediaType = MediaType.movie,
  });

  final MovieSummary? initialMovie;
  final String? heroTag;
  final MediaType mediaType;
}

/// Cinematic fade + subtle slide transition for opening Movie Details via GoRouter.
abstract final class MovieDetailsRoute {
  static String path(int movieId, {MediaType mediaType = MediaType.movie}) =>
      mediaType == MediaType.tv ? '/movie/$movieId?type=tv' : '/movie/$movieId';

  static void push(
    BuildContext context, {
    required int movieId,
    MovieSummary? initialMovie,
    String? heroTag,
    MediaType? mediaType,
  }) {
    final resolvedType =
        mediaType ?? initialMovie?.mediaType ?? MediaType.movie;
    context.push(
      path(movieId, mediaType: resolvedType),
      extra: MovieDetailsExtra(
        initialMovie: initialMovie,
        heroTag: heroTag,
        mediaType: resolvedType,
      ),
    );
  }

  static CustomTransitionPage<void> buildPage(GoRouterState state) {
    final movieId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
    final queryType = state.uri.queryParameters['type'];
    final extra = state.extra;
    MovieSummary? initialMovie;
    String? heroTag;
    MediaType mediaType = MediaType.fromString(queryType);

    if (extra is MovieDetailsExtra) {
      initialMovie = extra.initialMovie;
      heroTag = extra.heroTag;
      if (queryType == null) {
        mediaType = extra.mediaType;
      }
    } else if (extra is MovieSummary) {
      initialMovie = extra;
      if (queryType == null) {
        mediaType = extra.mediaType;
      }
    }

    return CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      child: MovieDetailsScreen(
        movieId: movieId,
        initialMovie: initialMovie,
        heroTag: heroTag,
        mediaType: mediaType,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
