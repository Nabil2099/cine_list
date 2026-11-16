import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/app_constants.dart';
import 'core/di/injection_container.dart';
import 'core/routing/app_shell.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/splash_screen.dart';
import 'features/ai_chat/presentation/cubit/ai_chat_cubit.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/auth/presentation/cubit/auth_state.dart';
import 'features/auth/presentation/screens/auth_screen.dart';
import 'features/community/presentation/cubit/community_cubit.dart';
import 'features/discover/presentation/cubit/discover_cubit.dart';
import 'features/discover/presentation/cubit/discover_state.dart';
import 'features/watchlist/presentation/cubit/watchlist_cubit.dart';

/// Root CineList widget wiring global Cubits and auth-gated navigation.
class CineListApp extends StatelessWidget {
  const CineListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(create: (_) => sl<AuthCubit>()),
        BlocProvider<DiscoverCubit>(
          create: (_) => sl<DiscoverCubit>()..loadInitial(),
        ),
        BlocProvider<WatchlistCubit>(create: (_) => sl<WatchlistCubit>()),
        BlocProvider<AiChatCubit>(create: (_) => sl<AiChatCubit>()),
        BlocProvider<CommunityCubit>(create: (_) => sl<CommunityCubit>()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  Timer? _minSplashTimer;
  Timer? _maxWaitTimer;
  bool _minDurationElapsed = false;
  bool _maxWaitElapsed = false;

  @override
  void initState() {
    super.initState();
    _minSplashTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _minDurationElapsed = true);
      }
    });
    _maxWaitTimer = Timer(const Duration(milliseconds: 4500), () {
      if (mounted) {
        setState(() => _maxWaitElapsed = true);
      }
    });
  }

  @override
  void dispose() {
    _minSplashTimer?.cancel();
    _maxWaitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discoverStatus = context.select<DiscoverCubit, DiscoverStatus>(
      (cubit) => cubit.state.status,
    );

    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status || prev.user?.uid != curr.user?.uid,
      listener: (context, state) {
        context.read<WatchlistCubit>().bindUser(state.user?.uid);
        context.read<CommunityCubit>().bindUser(
          uid: state.user?.uid,
          email: state.user?.email,
        );
      },
      builder: (context, state) {
        final isAuthResolved = state.status != AuthStatus.initial;
        final isDiscoverReady =
            state.status != AuthStatus.authenticated ||
            (discoverStatus != DiscoverStatus.initial &&
                discoverStatus != DiscoverStatus.loading);
        final showSplash =
            !isAuthResolved ||
            !_minDurationElapsed ||
            (!isDiscoverReady && !_maxWaitElapsed);

        final Widget child;
        if (showSplash) {
          child = const AnimatedSplashScreen(key: ValueKey('splash'));
        } else if (state.status == AuthStatus.authenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            context.read<WatchlistCubit>().bindUser(state.user?.uid);
            context.read<CommunityCubit>().bindUser(
              uid: state.user?.uid,
              email: state.user?.email,
            );
          });
          child = const AppShell(key: ValueKey('shell'));
        } else {
          child = const AuthScreen(key: ValueKey('auth'));
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: child,
        );
      },
    );
  }
}
