import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/movie_details_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../data/models/watchlist_movie_model.dart';
import '../cubit/watchlist_cubit.dart';
import '../cubit/watchlist_state.dart';
import '../widgets/collection_picker_sheet.dart';
import '../widgets/review_dialog.dart';
import '../widgets/tonights_pick_dialog.dart';
import '../widgets/watchlist_movie_tile.dart';
import '../widgets/watchlist_stats_card.dart';
import '../widgets/watchlist_tabs.dart';

/// My Watchlist screen displaying stats, search/sort, Want to Watch, and Watched.
class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key, this.onExploreMovies});

  final VoidCallback? onExploreMovies;

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WatchlistMovieModel movie,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Remove Movie',
          style: TextStyle(color: AppColors.khakiBeige),
        ),
        content: Text(
          'Remove "${movie.title}" from your watchlist?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<WatchlistCubit>().removeFromWatchlist(
        movie.movieId,
        title: movie.title,
      );
    }
  }

  Future<void> _openReviewDialog(
    BuildContext context,
    WatchlistMovieModel movie,
  ) async {
    final result = await ReviewDialog.show(
      context,
      movieTitle: movie.title,
      initialRating: movie.userRating,
      initialNote: movie.userNote,
    );
    if (result != null && context.mounted) {
      await context.read<WatchlistCubit>().updateReview(
        movieId: movie.movieId,
        title: movie.title,
        userRating: result.rating,
        userNote: result.note,
      );
    }
  }

  Future<void> _handleToggleStatus(
    BuildContext context,
    WatchlistMovieModel movie,
  ) async {
    final wasWatched = movie.isWatched;
    await context.read<WatchlistCubit>().toggleWatchedStatus(movie);
    if (!wasWatched && context.mounted) {
      await _openReviewDialog(context, movie);
    }
  }

  void _openDetails(
    BuildContext context,
    WatchlistMovieModel movie,
    String heroTag,
  ) {
    Navigator.of(context).push(
      MovieDetailsRoute.build(
        movieId: movie.movieId,
        initialMovie: movie.toMovieSummary(),
        heroTag: heroTag,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppConstants.maxContentWidth,
          ),
          child: BlocConsumer<WatchlistCubit, WatchlistState>(
            listenWhen: (prev, curr) =>
                (prev.feedbackMessage != curr.feedbackMessage &&
                    curr.feedbackMessage != null) ||
                (prev.errorMessage != curr.errorMessage &&
                    curr.errorMessage != null &&
                    curr.status == WatchlistLoadStatus.loaded),
            listener: (context, state) {
              final message = state.feedbackMessage ?? state.errorMessage;
              if (message != null) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(message)));
                context.read<WatchlistCubit>().clearFeedback();
              }
            },
            builder: (context, state) {
              final totalSaved = state.movies.length;
              final activeMovies = state.activeTabMovies;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'My Watchlist',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$totalSaved ${totalSaved == 1 ? 'movie' : 'movies'} saved',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            if (state.wantToWatchMovies.isNotEmpty ||
                                activeMovies.isNotEmpty) ...[
                              InkWell(
                                onTap: () {
                                  final candidates =
                                      state.wantToWatchMovies.isNotEmpty
                                      ? state.wantToWatchMovies
                                      : activeMovies;
                                  TonightsPickDialog.show(
                                    context,
                                    candidates: candidates,
                                    onOpenDetails: (picked) => _openDetails(
                                      context,
                                      picked,
                                      'pick-${picked.movieId}',
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.pacificBlue.withValues(
                                      alpha: 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.pacificBlue.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.casino_rounded,
                                        size: 17,
                                        color: AppColors.pacificBlue,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Surprise Me',
                                        style: TextStyle(
                                          color: AppColors.pacificBlue,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            PopupMenuButton<WatchlistSortOption>(
                              tooltip: 'Sort watchlist',
                              color: AppColors.surfaceElevated,
                              initialValue: state.sortOption,
                              onSelected: (opt) => context
                                  .read<WatchlistCubit>()
                                  .setSortOption(opt),
                              icon: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceCard,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.surfaceBorder,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.sort_rounded,
                                      size: 18,
                                      color: AppColors.khakiBeige,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Sort',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              itemBuilder: (_) => WatchlistSortOption.values
                                  .map(
                                    (opt) => PopupMenuItem<WatchlistSortOption>(
                                      value: opt,
                                      child: Row(
                                        children: [
                                          if (opt == state.sortOption)
                                            const Icon(
                                              Icons.check_rounded,
                                              size: 17,
                                              color: AppColors.pacificBlue,
                                            )
                                          else
                                            const SizedBox(width: 17),
                                          const SizedBox(width: 8),
                                          Text(opt.label),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                        if (totalSaved > 0) ...[
                          const SizedBox(height: 12),
                          WatchlistStatsCard(
                            totalMovies: totalSaved,
                            watchedCount: state.watchedMovies.length,
                            completionPercent: state.completionPercent,
                            totalMinutesWatched: state.totalMinutesWatched,
                            averagePersonalRating: state.averagePersonalRating,
                          ),
                        ],
                        const SizedBox(height: 12),
                        WatchlistTabs(
                          selectedTab: state.selectedTab,
                          wantToWatchCount: state.wantToWatchMovies.length,
                          watchedCount: state.watchedMovies.length,
                          onTabSelected: (tab) =>
                              context.read<WatchlistCubit>().selectTab(tab),
                        ),
                        if (totalSaved > 0 || state.collections.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _CollectionsBar(state: state),
                        ],
                        if (totalSaved > 2) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _searchController,
                            onChanged: (q) => context
                                .read<WatchlistCubit>()
                                .setSearchQuery(q),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13.5,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Filter your watchlist...',
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 19,
                              ),
                              suffixIcon: state.searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        context
                                            .read<WatchlistCubit>()
                                            .setSearchQuery('');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _buildBody(context, state, activeMovies)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WatchlistState state,
    List<WatchlistMovieModel> activeMovies,
  ) {
    if (state.status == WatchlistLoadStatus.loading ||
        state.status == WatchlistLoadStatus.initial) {
      return const LoadingView(message: 'Syncing your watchlist...');
    }

    if (state.status == WatchlistLoadStatus.error) {
      return ErrorView(
        title: 'Watchlist Unavailable',
        message: state.errorMessage ?? 'Could not load your saved movies.',
      );
    }

    if (activeMovies.isEmpty) {
      if (state.searchQuery.trim().isNotEmpty) {
        return EmptyStateView(
          icon: Icons.search_off_rounded,
          title: 'No matching movies',
          message:
              'No saved movies match "${state.searchQuery.trim()}" in this tab.',
          actionLabel: 'Clear Filter',
          onAction: () {
            _searchController.clear();
            context.read<WatchlistCubit>().setSearchQuery('');
          },
        );
      }

      final isWantToWatch =
          state.selectedTab == WatchlistFilterStatus.wantToWatch;
      return EmptyStateView(
        icon: isWantToWatch
            ? Icons.bookmark_add_outlined
            : Icons.check_circle_outline_rounded,
        title: isWantToWatch ? 'Nothing to watch yet' : 'No watched movies yet',
        message: isWantToWatch
            ? 'Save movies from Discover to build your personal watchlist.'
            : 'Mark movies as watched once you finish watching them.',
        actionLabel: isWantToWatch && widget.onExploreMovies != null
            ? 'Explore Discover'
            : null,
        onAction: isWantToWatch ? widget.onExploreMovies : null,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= AppConstants.tabletBreakpoint;
        if (isTablet) {
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            itemCount: activeMovies.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: 142,
            ),
            itemBuilder: (context, index) {
              final movie = activeMovies[index];
              final heroTag = 'watchlist-${movie.movieId}';
              return WatchlistMovieTile(
                movie: movie,
                heroTag: heroTag,
                isMutating: state.isMutating(movie.movieId),
                onTap: () => _openDetails(context, movie, heroTag),
                onToggleStatus: () => _handleToggleStatus(context, movie),
                onRateAndNote: () => _openReviewDialog(context, movie),
                onManageCollections: () =>
                    CollectionPickerSheet.show(context, movie: movie),
                onRemove: () => _confirmRemove(context, movie),
              );
            },
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: activeMovies.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final movie = activeMovies[index];
            final heroTag = 'watchlist-${movie.movieId}';
            return WatchlistMovieTile(
              movie: movie,
              heroTag: heroTag,
              isMutating: state.isMutating(movie.movieId),
              onTap: () => _openDetails(context, movie, heroTag),
              onToggleStatus: () => _handleToggleStatus(context, movie),
              onRateAndNote: () => _openReviewDialog(context, movie),
              onManageCollections: () =>
                  CollectionPickerSheet.show(context, movie: movie),
              onRemove: () => _confirmRemove(context, movie),
            );
          },
        );
      },
    );
  }
}

class _CollectionsBar extends StatelessWidget {
  const _CollectionsBar({required this.state});

  final WatchlistState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WatchlistCubit>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _CollectionChip(
            label: 'All',
            selected: state.selectedCollectionId == null,
            onTap: () => cubit.selectCollection(null),
          ),
          ...state.collections.map((col) {
            final selected = state.selectedCollectionId == col.id;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _CollectionChip(
                label: '${col.name} (${col.movieIds.length})',
                selected: selected,
                onTap: () => cubit.selectCollection(col.id),
                onLongPress: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Delete Collection'),
                      content: Text('Delete "${col.name}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dCtx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.error,
                          ),
                          onPressed: () => Navigator.of(dCtx).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await cubit.deleteCollection(col.id, name: col.name);
                  }
                },
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ActionChip(
              avatar: const Icon(
                Icons.add_rounded,
                size: 16,
                color: AppColors.pacificBlue,
              ),
              label: const Text('New List'),
              labelStyle: const TextStyle(
                color: AppColors.pacificBlue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: AppColors.surfaceCard,
              side: BorderSide(
                color: AppColors.pacificBlue.withValues(alpha: 0.4),
              ),
              onPressed: () => CreateCollectionDialog.show(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionChip extends StatelessWidget {
  const _CollectionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.softPeriwinkle.withValues(alpha: 0.22),
        backgroundColor: AppColors.surfaceCard,
        side: BorderSide(
          color: selected ? AppColors.softPeriwinkle : AppColors.surfaceBorder,
        ),
        labelStyle: TextStyle(
          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
