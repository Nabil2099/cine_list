import 'package:flutter/material.dart';

import '../../features/movie_details/presentation/screens/movie_details_screen.dart';
import '../../shared/models/movie_summary.dart';

/// Cinematic fade + subtle slide transition for opening Movie Details.
abstract final class MovieDetailsRoute {
  static Route<void> build({
    required int movieId,
    MovieSummary? initialMovie,
    String? heroTag,
  }) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) =>
          MovieDetailsScreen(
            movieId: movieId,
            initialMovie: initialMovie,
            heroTag: heroTag,
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
