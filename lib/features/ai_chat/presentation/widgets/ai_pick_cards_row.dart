import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/routing/movie_details_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../../../shared/widgets/movie_poster.dart';
import '../../../discover/data/repositories/discover_repository.dart';
import '../../../watchlist/presentation/cubit/watchlist_cubit.dart';

class AiRecommendedPick {
  const AiRecommendedPick({required this.title, this.year});

  final String title;
  final String? year;

  String get cacheKey => '${title.toLowerCase()}|${year ?? ''}';
}

/// Resolves AI-recommended titles to TMDB cards with one-tap Watchlist,
/// Up Next, and Save as Collection actions.
class AiPickCardsRow extends StatefulWidget {
  const AiPickCardsRow({super.key, required this.picks});

  final List<AiRecommendedPick> picks;

  @override
  State<AiPickCardsRow> createState() => _AiPickCardsRowState();
}

class _AiPickCardsRowState extends State<AiPickCardsRow> {
  static final Map<String, MovieSummary> _cache = {};

  final List<MovieSummary> _resolved = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _resolveAll();
  }

  @override
  void didUpdateWidget(covariant AiPickCardsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.picks.length != widget.picks.length) {
      _resolveAll();
    }
  }

  Future<void> _resolveAll() async {
    final results = <MovieSummary>[];
    final seenIds = <int>{};
    final repo = sl<DiscoverRepository>();

    for (final pick in widget.picks.take(6)) {
      final cached = _cache[pick.cacheKey];
      if (cached != null) {
        if (seenIds.add(cached.id)) results.add(cached);
        continue;
      }
      try {
        final response = await repo.searchMovies(query: pick.title);
        if (response.results.isEmpty) continue;
        var match = response.results.first;
        if (pick.year != null) {
          for (final candidate in response.results) {
            if ((candidate.releaseDate ?? '').startsWith(pick.year!)) {
              match = candidate;
              break;
            }
          }
        }
        _cache[pick.cacheKey] = match;
        if (seenIds.add(match.id)) results.add(match);
      } catch (_) {
        // Skip picks that fail to resolve.
      }
    }

    if (!mounted) return;
    setState(() {
      _resolved
        ..clear()
        ..addAll(results);
      _isLoading = false;
    });
  }

  Future<void> _saveAsCollection() async {
    if (_resolved.isEmpty) return;
    final controller = TextEditingController(text: 'AI Movie Picks');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Save as Collection',
          style: TextStyle(color: AppColors.khakiBeige, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          maxLength: 40,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Collection Name',
            hintText: 'e.g. 90s Neo-Noir Marathon',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name == null || name.isEmpty || !mounted) return;
    final res = await context.read<WatchlistCubit>().cloneCuratedList(
      title: name,
      movies: _resolved,
    );
    if (res != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Saved "${res.collectionName}" (${_resolved.length} movies) to Watchlist!',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: SizedBox(
          height: 22,
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.pacificBlue,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Loading movie cards...',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      );
    }

    if (_resolved.isEmpty) return const SizedBox.shrink();

    final watchlistState = context.watch<WatchlistCubit>().state;
    final watchlistCubit = context.read<WatchlistCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 184,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _resolved.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final movie = _resolved[index];
              final saved = watchlistState.findById(movie.id);
              final isSaved = saved != null;
              final isUpNext = saved?.isUpNext == true;

              return Container(
                width: 118,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => MovieDetailsRoute.push(
                        context,
                        movieId: movie.id,
                        initialMovie: movie,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: MoviePoster(
                        posterPath: movie.posterPath,
                        width: 102,
                        height: 98,
                        borderRadius: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      movie.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${Formatters.releaseYear(movie.releaseDate)} · ★ ${movie.voteAverage.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (isSaved) {
                                watchlistCubit.removeFromWatchlist(
                                  movie.id,
                                  title: movie.title,
                                );
                              } else {
                                watchlistCubit.addToWatchlist(movie);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: isSaved
                                    ? AppColors.pacificBlue.withValues(
                                        alpha: 0.18,
                                      )
                                    : AppColors.pacificBlue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                isSaved ? 'Saved ✓' : '+ Watchlist',
                                style: TextStyle(
                                  color: isSaved
                                      ? AppColors.pacificBlue
                                      : AppColors.black,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (isSaved && !saved.isWatched) ...[
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => watchlistCubit.toggleUpNext(saved),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isUpNext
                                    ? AppColors.khakiBeige.withValues(
                                        alpha: 0.22,
                                      )
                                    : AppColors.surfaceCard,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isUpNext
                                      ? AppColors.khakiBeige
                                      : AppColors.surfaceBorder,
                                ),
                              ),
                              child: Icon(
                                isUpNext
                                    ? Icons.push_pin_rounded
                                    : Icons.push_pin_outlined,
                                size: 13,
                                color: isUpNext
                                    ? AppColors.khakiBeige
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_resolved.length >= 2) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saveAsCollection,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.khakiBeige,
              side: BorderSide(
                color: AppColors.khakiBeige.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.playlist_add_rounded, size: 16),
            label: Text(
              'Save ${_resolved.length} Picks as Collection',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}
