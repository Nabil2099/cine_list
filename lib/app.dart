import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/app_constants.dart';
import 'core/di/injection_container.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/ai_chat/presentation/cubit/ai_chat_cubit.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/auth/presentation/cubit/auth_state.dart';
import 'features/community/data/models/curated_list_model.dart';
import 'features/community/presentation/bloc/community_bloc.dart';
import 'features/discover/presentation/bloc/discover_bloc.dart';
import 'features/watchlist/presentation/cubit/watchlist_cubit.dart';
import 'features/watchlist/presentation/cubit/watchlist_state.dart';

/// Root CineList widget wiring global BLoCs/Cubits and GoRouter navigation.
class CineListApp extends StatefulWidget {
  const CineListApp({super.key});

  @override
  State<CineListApp> createState() => _CineListAppState();
}

class _CineListAppState extends State<CineListApp> {
  late final AuthCubit _authCubit;
  late final DiscoverBloc _discoverBloc;
  late final WatchlistCubit _watchlistCubit;
  late final AiChatCubit _aiChatCubit;
  late final CommunityBloc _communityBloc;
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _authCubit = sl<AuthCubit>();
    _discoverBloc = sl<DiscoverBloc>()..add(const DiscoverInitialLoaded());
    _watchlistCubit = sl<WatchlistCubit>();
    _aiChatCubit = sl<AiChatCubit>();
    _communityBloc = sl<CommunityBloc>();
    _appRouter = AppRouter(authCubit: _authCubit, discoverBloc: _discoverBloc);

    final currentUser = _authCubit.state.user;
    if (currentUser != null) {
      _watchlistCubit.bindUser(currentUser.uid);
    }
    _communityBloc.add(
      CommunityUserBound(
        uid: currentUser?.uid,
        email: currentUser?.email,
        displayName: currentUser?.displayName,
      ),
    );
  }

  @override
  void dispose() {
    _appRouter.dispose();
    _authCubit.close();
    _discoverBloc.close();
    _watchlistCubit.close();
    _aiChatCubit.close();
    _communityBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: _authCubit),
        BlocProvider<DiscoverBloc>.value(value: _discoverBloc),
        BlocProvider<WatchlistCubit>.value(value: _watchlistCubit),
        BlocProvider<AiChatCubit>.value(value: _aiChatCubit),
        BlocProvider<CommunityBloc>.value(value: _communityBloc),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<AuthCubit, AuthState>(
            listenWhen: (prev, curr) =>
                prev.status != curr.status ||
                prev.user?.uid != curr.user?.uid ||
                prev.user?.displayName != curr.user?.displayName,
            listener: (context, state) {
              _watchlistCubit.bindUser(state.user?.uid);
              _communityBloc.add(
                CommunityUserBound(
                  uid: state.user?.uid,
                  email: state.user?.email,
                  displayName: state.user?.displayName,
                ),
              );
            },
          ),
          BlocListener<WatchlistCubit, WatchlistState>(
            listenWhen: (prev, curr) =>
                prev.collections != curr.collections ||
                prev.movies != curr.movies,
            listener: (context, watchlistState) {
              final uid = _communityBloc.currentUid;
              if (uid == null) return;

              final moviesById = {
                for (final m in watchlistState.movies) m.movieId: m,
              };
              final collectionsById = {
                for (final c in watchlistState.collections) c.id: c,
              };

              for (final published in _communityBloc.state.curatedLists) {
                if (published.authorUid != uid ||
                    published.collectionId == null) {
                  continue;
                }
                final col = collectionsById[published.collectionId];
                if (col == null) continue;

                final syncedMovies = col.movieIds
                    .map((id) => moviesById[id])
                    .where((m) => m != null)
                    .map(
                      (m) => CuratedListMovie(
                        movieId: m!.movieId,
                        title: m.title,
                        posterPath: m.posterPath,
                      ),
                    )
                    .toList();

                if (syncedMovies.isNotEmpty &&
                    syncedMovies != published.movies) {
                  _communityBloc.add(
                    CommunityCuratedListMoviesSynced(
                      listId: published.id,
                      movies: syncedMovies,
                    ),
                  );
                }
              }
            },
          ),
        ],
        child: MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          scrollBehavior: const AppScrollBehavior(),
          routerConfig: _appRouter.router,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final isMobile = mediaQuery.size.width < 600;
            if (!isMobile || child == null) {
              return child ?? const SizedBox.shrink();
            }
            final currentScale = mediaQuery.textScaler.scale(1.0);
            final scaled = (currentScale * 0.90).clamp(0.85, 1.15);
            return MediaQuery(
              data: mediaQuery.copyWith(textScaler: TextScaler.linear(scaled)),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

/// Enables smooth mouse, trackpad, stylus, and touch drag scrolling on Web & Desktop.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };
}
