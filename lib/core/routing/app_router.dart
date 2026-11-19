import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/screens/admin_screen.dart';
import '../../features/ai_chat/presentation/screens/ai_chat_screen.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/auth_state.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/community/presentation/screens/community_screen.dart';
import '../../features/community/presentation/screens/following_feed_screen.dart';
import '../../features/community/presentation/screens/notifications_screen.dart';
import '../../features/discover/presentation/bloc/discover_bloc.dart';
import '../../features/discover/presentation/screens/discover_screen.dart';
import '../../features/landing/presentation/screens/web_landing_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/watchlist/presentation/screens/cinema_stats_screen.dart';
import '../../features/watchlist/presentation/screens/watchlist_screen.dart';
import '../widgets/splash_screen.dart';
import 'app_shell.dart';
import 'movie_details_route.dart';

/// Application GoRouter configuration with auth, splash, and shell branches.
class AppRouter {
  AppRouter({required this.authCubit, required this.discoverBloc}) {
    _minSplashTimer = Timer(const Duration(milliseconds: 1800), () {
      _minDurationElapsed = true;
      _refreshNotifier.trigger();
    });
    _maxWaitTimer = Timer(const Duration(milliseconds: 4500), () {
      _maxWaitElapsed = true;
      _refreshNotifier.trigger();
    });

    _authSub = authCubit.stream.listen((_) => _refreshNotifier.trigger());
    _discoverSub = discoverBloc.stream.listen(
      (_) => _refreshNotifier.trigger(),
    );
  }

  final AuthCubit authCubit;
  final DiscoverBloc discoverBloc;
  final _refreshNotifier = _RouterRefreshNotifier();

  late final Timer _minSplashTimer;
  late final Timer _maxWaitTimer;
  late final StreamSubscription<AuthState> _authSub;
  late final StreamSubscription<DiscoverState> _discoverSub;

  bool _minDurationElapsed = false;
  bool _maxWaitElapsed = false;

  late final GoRouter router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: _refreshNotifier,
    redirect: (context, state) {
      final authStatus = authCubit.state.status;
      final discoverStatus = discoverBloc.state.status;
      final location = state.matchedLocation;

      final isAuthResolved = authStatus != AuthStatus.initial;
      final isDiscoverReady =
          authStatus != AuthStatus.authenticated ||
          (discoverStatus != DiscoverStatus.initial &&
              discoverStatus != DiscoverStatus.loading);
      final showSplash =
          !isAuthResolved ||
          !_minDurationElapsed ||
          (!isDiscoverReady && !_maxWaitElapsed);

      if (showSplash) {
        return location == '/splash' ? null : '/splash';
      }

      if (authStatus == AuthStatus.authenticated) {
        if (location == '/' ||
            location == '/splash' ||
            location == '/welcome' ||
            location == '/auth' ||
            location == '/verify-email') {
          return '/discover';
        }
        return null;
      }

      if (authStatus == AuthStatus.unverified) {
        return location == '/verify-email' ? null : '/verify-email';
      }

      // Unauthenticated
      if (kIsWeb) {
        if (location == '/welcome' || location == '/auth') {
          return null;
        }
        return '/welcome';
      } else {
        if (location == '/auth') {
          return null;
        }
        return '/auth';
      }
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const AnimatedSplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => WebLandingScreen(
          onSignIn: () {
            final authCubit = context.read<AuthCubit>();
            if (authCubit.state.isRegisterMode) {
              authCubit.toggleMode();
            }
            context.go('/auth');
          },
          onGetStarted: () {
            final authCubit = context.read<AuthCubit>();
            if (!authCubit.state.isRegisterMode) {
              authCubit.toggleMode();
            }
            context.go('/auth');
          },
        ),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => AuthScreen(
          onBackToLanding: kIsWeb ? () => context.go('/welcome') : null,
        ),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                builder: (context, state) => const DiscoverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/watchlist',
                builder: (context, state) => WatchlistScreen(
                  onExploreMovies: () =>
                      StatefulNavigationShell.of(context).goBranch(0),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ai',
                builder: (context, state) => const AiChatScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                builder: (context, state) => FollowingFeedScreen(
                  onExploreCommunity: () =>
                      StatefulNavigationShell.of(context).goBranch(4),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/community',
                builder: (context, state) => const CommunityScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/movie/:id',
        pageBuilder: (context, state) => MovieDetailsRoute.buildPage(state),
      ),
      GoRoute(
        path: '/stats',
        builder: (context, state) => const CinemaStatsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );

  void dispose() {
    _minSplashTimer.cancel();
    _maxWaitTimer.cancel();
    _authSub.cancel();
    _discoverSub.cancel();
    _refreshNotifier.dispose();
    router.dispose();
  }
}

class _RouterRefreshNotifier extends ChangeNotifier {
  void trigger() => notifyListeners();
}
