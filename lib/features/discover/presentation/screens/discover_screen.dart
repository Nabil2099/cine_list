import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/movie_details_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../../../shared/widgets/movie_card.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../community/presentation/cubit/community_cubit.dart';
import '../../../community/presentation/widgets/user_avatar_widget.dart';
import '../../../watchlist/presentation/cubit/watchlist_cubit.dart';
import '../cubit/discover_cubit.dart';
import '../cubit/discover_state.dart';
import '../widgets/category_tabs.dart';
import '../widgets/featured_movie_card.dart';
import '../widgets/genre_filter_bar.dart';
import '../widgets/movie_search_bar.dart';

/// Primary Discover screen with greeting, search, categories, featured card,
/// horizontal poster carousel, and responsive movie grid.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openMovieDetails(MovieSummary movie, {String? heroTag}) {
    MovieDetailsRoute.push(
      context,
      movieId: movie.id,
      initialMovie: movie,
      heroTag: heroTag,
    );
  }

  int _gridColumnsForWidth(double width) {
    if (width >= AppConstants.desktopBreakpoint) return 4;
    if (width >= AppConstants.tabletBreakpoint) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = context.select<AuthCubit, String?>(
      (cubit) => cubit.state.user?.email,
    );
    final authDisplayName = context.select<AuthCubit, String?>(
      (cubit) => cubit.state.user?.displayName,
    );
    final profileDisplayName = context.select<CommunityCubit, String?>(
      (cubit) => cubit.state.profile?.displayName,
    );
    final greetingName =
        (profileDisplayName != null && profileDisplayName.trim().isNotEmpty)
        ? profileDisplayName.trim()
        : (authDisplayName != null && authDisplayName.trim().isNotEmpty)
        ? authDisplayName.trim()
        : Formatters.greetingName(userEmail);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppConstants.maxContentWidth,
          ),
          child: RefreshIndicator(
            color: AppColors.pacificBlue,
            backgroundColor: AppColors.surfaceElevated,
            onRefresh: () => context.read<DiscoverCubit>().retry(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _DiscoverHeader(
                      greetingName: greetingName,
                      userEmail: userEmail,
                      onSignOut: () => context.read<AuthCubit>().signOut(),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: BlocBuilder<DiscoverCubit, DiscoverState>(
                      buildWhen: (prev, curr) =>
                          prev.searchQuery != curr.searchQuery ||
                          prev.selectedCategory != curr.selectedCategory ||
                          prev.selectedGenreId != curr.selectedGenreId,
                      builder: (context, state) {
                        if (state.searchQuery.isEmpty &&
                            _searchController.text.isNotEmpty) {
                          _searchController.clear();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MovieSearchBar(
                              controller: _searchController,
                              hasText: state.searchQuery.isNotEmpty,
                              onChanged: (q) => context
                                  .read<DiscoverCubit>()
                                  .onSearchChanged(q),
                              onClear: () {
                                _searchController.clear();
                                context.read<DiscoverCubit>().clearSearch();
                              },
                            ),
                            const SizedBox(height: 14),
                            CategoryTabs(
                              selectedCategory: state.selectedCategory,
                              isSearchActive:
                                  state.isSearching ||
                                  state.selectedGenreId != null,
                              onSelected: (cat) {
                                _searchController.clear();
                                context.read<DiscoverCubit>().selectCategory(
                                  cat,
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            GenreFilterBar(
                              selectedGenreId: state.selectedGenreId,
                              isSearchActive: state.isSearching,
                              onSelected: (genreId) {
                                _searchController.clear();
                                context.read<DiscoverCubit>().selectGenre(
                                  genreId,
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                BlocBuilder<DiscoverCubit, DiscoverState>(
                  builder: (context, state) {
                    if (state.status == DiscoverStatus.loading ||
                        state.status == DiscoverStatus.initial) {
                      return const SliverPadding(
                        padding: EdgeInsets.only(top: 12),
                        sliver: SliverToBoxAdapter(
                          child: LoadingView(useSkeleton: true),
                        ),
                      );
                    }

                    if (state.status == DiscoverStatus.error) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: ErrorView(
                          title: state.isAuthConfigError
                              ? 'TMDB Configuration Needed'
                              : 'Could Not Load Movies',
                          message:
                              state.errorMessage ??
                              'Unable to fetch movies right now.',
                          onRetry: () => context.read<DiscoverCubit>().retry(),
                        ),
                      );
                    }

                    if (state.status == DiscoverStatus.empty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyStateView(
                          icon: Icons.search_off_rounded,
                          title: state.isSearching
                              ? 'No results found'
                              : 'No movies available',
                          message: state.isSearching
                              ? 'We could not find any movies matching "${state.searchQuery.trim()}".'
                              : 'Try refreshing or switching to another category.',
                          actionLabel: state.isSearching
                              ? 'Clear Search'
                              : null,
                          onAction: state.isSearching
                              ? () {
                                  _searchController.clear();
                                  context.read<DiscoverCubit>().clearSearch();
                                }
                              : null,
                        ),
                      );
                    }

                    return _DiscoverLoadedSlivers(
                      state: state,
                      gridColumnsForWidth: _gridColumnsForWidth,
                      onMovieTap: _openMovieDetails,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader({
    required this.greetingName,
    required this.userEmail,
    required this.onSignOut,
  });

  final String greetingName;
  final String? userEmail;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, $greetingName 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 2),
              Text(
                'What are we watching today?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        Builder(
          builder: (context) {
            final profile = context.select<CommunityCubit, ({String key, String? photo})>(
              (c) => (
                key: c.state.profile?.avatarKey ?? 'cinema',
                photo: c.state.profile?.photoBase64,
              ),
            );
            return InkWell(
              onTap: () => context.push('/profile'),
              borderRadius: BorderRadius.circular(24),
              child: Tooltip(
                message: 'My Profile',
                child: UserAvatar(
                  avatarKey: profile.key,
                  photoBase64: profile.photo,
                  radius: 19,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DiscoverLoadedSlivers extends StatelessWidget {
  const _DiscoverLoadedSlivers({
    required this.state,
    required this.gridColumnsForWidth,
    required this.onMovieTap,
  });

  final DiscoverState state;
  final int Function(double width) gridColumnsForWidth;
  final void Function(MovieSummary movie, {String? heroTag}) onMovieTap;

  void _toggleQuickSave(
    BuildContext context,
    MovieSummary movie,
    bool isSaved,
  ) {
    final watchlistCubit = context.read<WatchlistCubit>();
    if (isSaved) {
      watchlistCubit.removeFromWatchlist(movie.id, title: movie.title);
    } else {
      watchlistCubit.addToWatchlist(movie);
    }
  }

  @override
  Widget build(BuildContext context) {
    final movies = state.movies;
    final savedIds = context.select<WatchlistCubit, Set<int>>(
      (c) => c.state.movies.map((m) => m.movieId).toSet(),
    );
    final showFeaturedAndCarousel =
        !state.isSearching &&
        state.selectedGenreId == null &&
        movies.length > 4;

    final featuredMovie = showFeaturedAndCarousel ? movies.first : null;
    final carouselMovies = showFeaturedAndCarousel
        ? movies.skip(1).take(6).toList()
        : const <MovieSummary>[];
    final gridMovies = showFeaturedAndCarousel
        ? movies.skip(7).toList()
        : movies;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          if (featuredMovie != null) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide =
                    constraints.maxWidth >= AppConstants.tabletBreakpoint;
                return FeaturedMovieCard(
                  movie: featuredMovie,
                  height: isWide ? 270 : 205,
                  onTap: () => onMovieTap(featuredMovie),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
          if (carouselMovies.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${state.selectedCategory.label} Now',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${movies.length} titles',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 235,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: carouselMovies.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final movie = carouselMovies[index];
                  final heroTag = 'discover-carousel-${movie.id}';
                  final isSaved = savedIds.contains(movie.id);
                  return MovieCard(
                    movie: movie,
                    width: 132,
                    heroTag: heroTag,
                    isSaved: isSaved,
                    onToggleSave: () =>
                        _toggleQuickSave(context, movie, isSaved),
                    onTap: () => onMovieTap(movie, heroTag: heroTag),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (gridMovies.isNotEmpty) ...[
            Text(
              state.isSearching
                  ? 'Search Results (${movies.length})'
                  : 'Explore More',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = gridColumnsForWidth(
                  constraints.maxWidth,
                );
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: gridMovies.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 18,
                    childAspectRatio: 0.57,
                  ),
                  itemBuilder: (context, index) {
                    final movie = gridMovies[index];
                    final heroTag = 'discover-grid-${movie.id}';
                    final isSaved = savedIds.contains(movie.id);
                    return MovieCard(
                      movie: movie,
                      heroTag: heroTag,
                      isSaved: isSaved,
                      onToggleSave: () =>
                          _toggleQuickSave(context, movie, isSaved),
                      onTap: () => onMovieTap(movie, heroTag: heroTag),
                    );
                  },
                );
              },
            ),
          ],
          if (state.errorMessage != null && movies.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              state.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],
          if (state.hasMore) ...[
            const SizedBox(height: 22),
            Center(
              child: state.isLoadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        color: AppColors.pacificBlue,
                        strokeWidth: 2.5,
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => context.read<DiscoverCubit>().loadMore(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.pacificBlue,
                        side: const BorderSide(color: AppColors.pacificBlue),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      icon: const Icon(Icons.expand_more_rounded),
                      label: const Text(
                        'Load More Movies',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
            ),
          ],
        ]),
      ),
    );
  }
}
