import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/app_constants.dart';
import 'core/di/injection_container.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/ai_chat/presentation/cubit/ai_chat_cubit.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/auth/presentation/cubit/auth_state.dart';
import 'features/community/presentation/cubit/community_cubit.dart';
import 'features/discover/presentation/cubit/discover_cubit.dart';
import 'features/watchlist/presentation/cubit/watchlist_cubit.dart';

/// Root CineList widget wiring global Cubits and GoRouter navigation.
class CineListApp extends StatefulWidget {
  const CineListApp({super.key});

  @override
  State<CineListApp> createState() => _CineListAppState();
}

class _CineListAppState extends State<CineListApp> {
  late final AuthCubit _authCubit;
  late final DiscoverCubit _discoverCubit;
  late final WatchlistCubit _watchlistCubit;
  late final AiChatCubit _aiChatCubit;
  late final CommunityCubit _communityCubit;
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _authCubit = sl<AuthCubit>();
    _discoverCubit = sl<DiscoverCubit>()..loadInitial();
    _watchlistCubit = sl<WatchlistCubit>();
    _aiChatCubit = sl<AiChatCubit>();
    _communityCubit = sl<CommunityCubit>();
    _appRouter = AppRouter(
      authCubit: _authCubit,
      discoverCubit: _discoverCubit,
    );

    final currentUser = _authCubit.state.user;
    if (currentUser != null) {
      _watchlistCubit.bindUser(currentUser.uid);
      _communityCubit.bindUser(uid: currentUser.uid, email: currentUser.email);
    }
  }

  @override
  void dispose() {
    _appRouter.dispose();
    _authCubit.close();
    _discoverCubit.close();
    _watchlistCubit.close();
    _aiChatCubit.close();
    _communityCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: _authCubit),
        BlocProvider<DiscoverCubit>.value(value: _discoverCubit),
        BlocProvider<WatchlistCubit>.value(value: _watchlistCubit),
        BlocProvider<AiChatCubit>.value(value: _aiChatCubit),
        BlocProvider<CommunityCubit>.value(value: _communityCubit),
      ],
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (prev, curr) =>
            prev.status != curr.status || prev.user?.uid != curr.user?.uid,
        listener: (context, state) {
          _watchlistCubit.bindUser(state.user?.uid);
          _communityCubit.bindUser(
            uid: state.user?.uid,
            email: state.user?.email,
          );
        },
        child: MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          routerConfig: _appRouter.router,
        ),
      ),
    );
  }
}
