import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/movie_details_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/auth_gate.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/profile_drawer_button.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../../../shared/widgets/movie_card.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../community/presentation/bloc/community_bloc.dart';
import '../../../watchlist/presentation/cubit/watchlist_cubit.dart';
import '../../data/repositories/discover_repository.dart';
import '../bloc/discover_bloc.dart';
import '../widgets/category_tabs.dart';
import '../widgets/featured_movie_card.dart';
import '../widgets/movie_search_bar.dart';

/// Primary Discover screen with greeting, search, categories, featured card,
/// horizontal poster carousel, and lazy native sliver grid.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 500) return;
    final bloc = context.read<DiscoverBloc>();
    final state = bloc.state;
    if (state.hasMore &&
        !state.isLoadingMore &&
        state.status == DiscoverStatus.loaded) {
      bloc.add(const DiscoverNextPageLoaded());
    }
  }

  void _maybeLoadMoreIfViewportShort() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _onScroll();
    });
  }

  void _openMovieDetails(MovieSummary movie, {String? heroTag}) {
    MovieDetailsRoute.push(
      context,
      movieId: movie.id,
      initialMovie: movie,
      heroTag: heroTag,
      mediaType: movie.mediaType,
    );
  }

  int _gridColumnsForWidth(double width) {
    if (width >= AppConstants.desktopBreakpoint) return 5;
    if (width >= AppConstants.tabletBreakpoint) return 4;
    if (width >= 360) return 3;
    return 2;
  }

  Future<void> _showGenreFilterSheet(
    BuildContext context, {
    required DiscoverCategory selectedCategory,
    required int? selectedGenreId,
  }) async {
    final bloc = context.read<DiscoverBloc>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.filter_alt_outlined,
                      color: AppColors.pacificBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filter by Genre',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Showing ${selectedCategory.label} movies',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selectedGenreId != null)
                      TextButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _searchController.clear();
                          bloc.add(const DiscoverGenreSelected(null));
                        },
                        child: const Text(
                          'Reset',
                          style: TextStyle(
                            color: AppColors.pacificBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: [
                    _GenreSheetChip(
                      label: 'All Genres',
                      selected: selectedGenreId == null,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _searchController.clear();
                        bloc.add(const DiscoverGenreSelected(null));
                      },
                    ),
                    for (final genre in DiscoverGenre.defaults)
                      _GenreSheetChip(
                        label: genre.label,
                        selected: selectedGenreId == genre.id,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _searchController.clear();
                          bloc.add(DiscoverGenreSelected(genre.id));
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = context.select<AuthCubit, bool>(
      (cubit) => cubit.state.status == AuthStatus.authenticated,
    );
    final userEmail = context.select<AuthCubit, String?>(
      (cubit) => cubit.state.user?.email,
    );
    final authDisplayName = context.select<AuthCubit, String?>(
      (cubit) => cubit.state.user?.displayName,
    );
    final profileDisplayName = context.select<CommunityBloc, String?>(
      (bloc) => bloc.state.profile?.displayName,
    );
    final greetingName =
        (profileDisplayName != null && profileDisplayName.trim().isNotEmpty)
        ? profileDisplayName.trim()
        : (authDisplayName != null && authDisplayName.trim().isNotEmpty)
        ? authDisplayName.trim()
        : Formatters.greetingName(userEmail);

    final viewportWidth = MediaQuery.sizeOf(context).width;
    final isWideWeb = kIsWeb && viewportWidth >= AppConstants.tabletBreakpoint;
    final horizontalPad = viewportWidth >= AppConstants.tabletBreakpoint
        ? 20.0
        : 14.0;

    return BlocListener<DiscoverBloc, DiscoverState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.movies.length != curr.movies.length,
      listener: (context, discoverState) {
        if (discoverState.status == DiscoverStatus.loaded) {
          _maybeLoadMoreIfViewportShort();
        }
      },
      child: ColoredBox(
        color: AppColors.black,
        child: SafeArea(
            bottom: false,
            child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppConstants.maxContentWidth,
          ),
          child: RefreshIndicator(
            color: AppColors.pacificBlue,
            backgroundColor: AppColors.surfaceElevated,
            onRefresh: () async {
              final bloc = context.read<DiscoverBloc>();
              bloc.add(const DiscoverRetried());
              await bloc.stream.firstWhere(
                (s) => s.status != DiscoverStatus.loading,
              );
            },
            child: CustomScrollView(
              controller: _scrollController,
              scrollCacheExtent: const ScrollCacheExtent.pixels(600),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    12,
                    horizontalPad,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _DiscoverHeader(
                      isSignedIn: isSignedIn,
                      greetingName: greetingName,
                      showDrawerButton: !isWideWeb,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    14,
                    horizontalPad,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: BlocBuilder<DiscoverBloc, DiscoverState>(
                      buildWhen: (prev, curr) =>
                          prev.searchQuery != curr.searchQuery ||
                          prev.selectedCategory != curr.selectedCategory ||
                          prev.selectedGenreId != curr.selectedGenreId ||
                          prev.animeFilter != curr.animeFilter,
                      builder: (context, state) {
                        if (state.searchQuery.isEmpty &&
                            _searchController.text.isNotEmpty) {
                          _searchController.clear();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CategoryTabs(
                              selectedCategory: state.selectedCategory,
                              isSearchActive: state.isSearching,
                              onSelected: (cat) {
                                _searchController.clear();
                                context.read<DiscoverBloc>().add(
                                  DiscoverCategorySelected(cat),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: MovieSearchBar(
                                    controller: _searchController,
                                    hasText: state.searchQuery.isNotEmpty,
                                    onChanged: (q) => context
                                        .read<DiscoverBloc>()
                                        .add(DiscoverSearchChanged(q)),
                                    onClear: () {
                                      _searchController.clear();
                                      context.read<DiscoverBloc>().add(
                                        const DiscoverSearchCleared(),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _GenreSortButton(
                                  selectedGenreId: state.selectedGenreId,
                                  onTap: () => _showGenreFilterSheet(
                                    context,
                                    selectedCategory: state.selectedCategory,
                                    selectedGenreId: state.selectedGenreId,
                                  ),
                                ),
                              ],
                            ),
                            if (state.selectedCategory ==
                                    DiscoverCategory.anime &&
                                !state.isSearching) ...[
                              const SizedBox(height: 10),
                              _AnimeMediaFilterBar(
                                selected: state.animeFilter,
                                onSelected: (filter) => context
                                    .read<DiscoverBloc>()
                                    .add(DiscoverAnimeFilterSelected(filter)),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
                BlocBuilder<DiscoverBloc, DiscoverState>(
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
                          onRetry: () => context.read<DiscoverBloc>().add(
                            const DiscoverRetried(),
                          ),
                        ),
                      );
                    }

                    if (state.status == DiscoverStatus.empty) {
                      final hasGenreFilter = state.selectedGenreId != null;
                      final isArabicAnime =
                          state.selectedCategory == DiscoverCategory.anime &&
                          state.selectedGenreId == DiscoverGenre.arabicGenreId;
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyStateView(
                          icon: Icons.search_off_rounded,
                          title: state.isSearching
                              ? 'No results found'
                              : hasGenreFilter
                              ? 'No ${state.selectedCategory.label} found'
                              : 'No movies available',
                          message: state.isSearching
                              ? 'We could not find any movies matching "${state.searchQuery.trim()}".'
                              : isArabicAnime
                              ? 'Japanese Anime is not available with the Arabic language filter. Choose another genre or reset the filter.'
                              : hasGenreFilter
                              ? 'No ${state.selectedCategory.label} titles matched this genre filter.'
                              : 'Try refreshing or switching to another category.',
                          actionLabel: state.isSearching
                              ? 'Clear Search'
                              : hasGenreFilter
                              ? 'Reset Filter'
                              : null,
                          onAction: state.isSearching
                              ? () {
                                  _searchController.clear();
                                  context.read<DiscoverBloc>().add(
                                    const DiscoverSearchCleared(),
                                  );
                                }
                              : hasGenreFilter
                              ? () => context.read<DiscoverBloc>().add(
                                  const DiscoverGenreSelected(null),
                                )
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
    ),
    ),
    );
  }
}

class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader({
    required this.isSignedIn,
    required this.greetingName,
    required this.showDrawerButton,
  });

  final bool isSignedIn;
  final String greetingName;
  final bool showDrawerButton;

  @override
  Widget build(BuildContext context) {
    final displayGreeting = isSignedIn ? greetingName : 'Guest';

    return Row(
      children: [
        if (showDrawerButton) ...[
          const ProfileDrawerButton(),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, $displayGreeting 👋',
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
        const SizedBox(width: 8),
        Builder(
          builder: (context) {
            final unreadCount = context.select<CommunityBloc, int>(
              (b) => b.state.unreadNotificationCount,
            );
            return IconButton(
              tooltip: 'Notifications',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () async {
                final allowed = await AuthGate.requireAuth(
                  context,
                  actionLabel: 'view notifications',
                );
                if (!allowed || !context.mounted) return;
                context.push('/notifications');
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: unreadCount > 0
                            ? AppColors.error.withValues(alpha: 0.6)
                            : AppColors.surfaceBorder,
                      ),
                    ),
                    child: Icon(
                      unreadCount > 0
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: unreadCount > 0
                          ? AppColors.error
                          : AppColors.khakiBeige,
                      size: 20,
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.black,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _GenreSortButton extends StatelessWidget {
  const _GenreSortButton({
    required this.selectedGenreId,
    required this.onTap,
  });

  final int? selectedGenreId;
  final VoidCallback onTap;

  String _label() {
    if (selectedGenreId == null) return 'Sort';
    for (final g in DiscoverGenre.defaults) {
      if (g.id == selectedGenreId) return g.label;
    }
    return 'Sort';
  }

  @override
  Widget build(BuildContext context) {
    final hasGenre = selectedGenreId != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.pacificBlue.withValues(
              alpha: hasGenre ? 0.24 : 0.14,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.pacificBlue.withValues(
                alpha: hasGenre ? 0.85 : 0.65,
              ),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_outlined,
                size: 19,
                color: hasGenre
                    ? AppColors.pacificBlue
                    : AppColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                _label(),
                style: TextStyle(
                  color: hasGenre
                      ? AppColors.pacificBlue
                      : AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimeMediaFilterBar extends StatelessWidget {
  const _AnimeMediaFilterBar({
    required this.selected,
    required this.onSelected,
  });

  final AnimeMediaFilter selected;
  final ValueChanged<AnimeMediaFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Japanese Anime:',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        for (final filter in AnimeMediaFilter.values) ...[
          ChoiceChip(
            label: Text(filter.label),
            selected: selected == filter,
            onSelected: (_) => onSelected(filter),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            selectedColor: AppColors.pacificBlue.withValues(alpha: 0.2),
            backgroundColor: AppColors.surfaceCard,
            side: BorderSide(
              color: selected == filter
                  ? AppColors.pacificBlue
                  : AppColors.surfaceBorder,
            ),
            labelStyle: TextStyle(
              color: selected == filter
                  ? AppColors.pacificBlue
                  : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            showCheckmark: false,
          ),
          const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _GenreSheetChip extends StatelessWidget {
  const _GenreSheetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.pacificBlue
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.pacificBlue
                : AppColors.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.black : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final movies = state.movies;
    final showFeaturedAndCarousel =
        !state.isSearching && movies.length > 4;

    final featuredMovie = showFeaturedAndCarousel ? movies.first : null;
    final carouselMovies = showFeaturedAndCarousel
        ? movies.skip(1).take(5).toList()
        : const <MovieSummary>[];
    final gridMovies = showFeaturedAndCarousel
        ? movies.skip(6).toList()
        : movies;

    String? activeGenreLabel;
    if (state.selectedGenreId != null) {
      for (final g in DiscoverGenre.defaults) {
        if (g.id == state.selectedGenreId) {
          activeGenreLabel = g.label;
          break;
        }
      }
    }
    final baseHeading = state.selectedCategory == DiscoverCategory.anime
        ? (state.animeFilter == AnimeMediaFilter.all
              ? 'Popular Anime'
              : 'Anime ${state.animeFilter.label}')
        : '${state.selectedCategory.label} Now';
    final carouselHeading = activeGenreLabel != null
        ? '$baseHeading · $activeGenreLabel'
        : baseHeading;

    final isWide =
        MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;
    final horizontalPad = isWide ? 20.0 : 14.0;
    final bottomPad = MediaQuery.paddingOf(context).bottom + 16;

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(horizontalPad, 16, horizontalPad, bottomPad),
      sliver: SliverMainAxisGroup(
        slivers: [
          if (featuredMovie != null || carouselMovies.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (featuredMovie != null) ...[
                    RepaintBoundary(
                      child: FeaturedMovieCard(
                        movie: featuredMovie,
                        height: isWide ? 270 : 176,
                        onTap: () => onMovieTap(featuredMovie),
                      ),
                    ),
                    SizedBox(height: isWide ? 24 : 18),
                  ],
                  if (carouselMovies.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            carouselHeading,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Top ${carouselMovies.length} · ${movies.length} titles',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: isWide ? 235 : 196,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: carouselMovies.length,
                        separatorBuilder: (_, _) =>
                            SizedBox(width: isWide ? 14 : 10),
                        itemBuilder: (context, index) {
                          final movie = carouselMovies[index];
                          final heroTag = 'discover-carousel-${movie.id}';
                          return _WatchlistAwareMovieCard(
                            movie: movie,
                            width: isWide ? 132 : 108,
                            heroTag: heroTag,
                            onTap: () => onMovieTap(movie, heroTag: heroTag),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: isWide ? 24 : 18),
                  ],
                ],
              ),
            ),
          if (gridMovies.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      state.isSearching
                          ? 'Search Results (${movies.length})'
                          : 'Explore More',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (!state.isSearching)
                      Text(
                        'Highest Rated',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.khakiBeige,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = gridColumnsForWidth(
                  constraints.crossAxisExtent,
                );
                return SliverGrid.builder(
                  itemCount: gridMovies.length,
                  addAutomaticKeepAlives: false,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: isWide ? 14 : 10,
                    mainAxisSpacing: isWide ? 18 : 14,
                    childAspectRatio: isWide ? 0.57 : 0.55,
                  ),
                  itemBuilder: (context, index) {
                    final movie = gridMovies[index];
                    final heroTag = 'discover-grid-${movie.id}';
                    return _WatchlistAwareMovieCard(
                      movie: movie,
                      heroTag: heroTag,
                      onTap: () => onMovieTap(movie, heroTag: heroTag),
                    );
                  },
                );
              },
            ),
          ],
          if ((state.errorMessage != null && movies.isNotEmpty) ||
              state.isLoadingMore)
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final columns = gridColumnsForWidth(
                  constraints.crossAxisExtent,
                );
                return SliverToBoxAdapter(
                  child: Column(
                    children: [
                      if (state.errorMessage != null && movies.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          state.errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => context.read<DiscoverBloc>().add(
                            const DiscoverNextPageLoaded(),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.pacificBlue,
                            side: const BorderSide(
                              color: AppColors.pacificBlue,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Retry Loading More'),
                        ),
                      ],
                      if (state.isLoadingMore) ...[
                        const SizedBox(height: 18),
                        DiscoverGridLazyRowSkeleton(
                          columns: columns,
                          spacing: isWide ? 14 : 10,
                          aspectRatio: isWide ? 0.57 : 0.55,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _WatchlistAwareMovieCard extends StatelessWidget {
  const _WatchlistAwareMovieCard({
    required this.movie,
    required this.heroTag,
    required this.onTap,
    this.width,
  });

  final MovieSummary movie;
  final String heroTag;
  final VoidCallback onTap;
  final double? width;

  Future<void> _toggleQuickSave(BuildContext context, bool isSaved) async {
    final allowed = await AuthGate.requireAuth(
      context,
      actionLabel: 'save movies to your Watchlist',
    );
    if (!allowed || !context.mounted) return;

    final watchlistCubit = context.read<WatchlistCubit>();
    if (isSaved) {
      await watchlistCubit.removeFromWatchlist(movie.id, title: movie.title);
    } else {
      await watchlistCubit.addToWatchlist(movie);
      if (context.mounted) {
        final router = GoRouter.of(context);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Added "${movie.title}" to Watchlist.'),
              action: SnackBarAction(
                label: 'Watchlist',
                textColor: AppColors.pacificBlue,
                onPressed: () => router.go('/watchlist'),
              ),
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaved = context.select<WatchlistCubit, bool>(
      (c) => c.state.findById(movie.id) != null,
    );
    return MovieCard(
      movie: movie,
      width: width,
      heroTag: heroTag,
      isSaved: isSaved,
      onToggleSave: () => _toggleQuickSave(context, isSaved),
      onTap: onTap,
    );
  }
}
