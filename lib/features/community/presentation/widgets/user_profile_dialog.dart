import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../profile/presentation/screens/public_user_profile_screen.dart';
import '../../../watchlist/presentation/cubit/watchlist_cubit.dart';
import '../bloc/community_bloc.dart';

/// Entry point for opening another user's full-screen public profile.
class UserProfileDialog {
  const UserProfileDialog._();

  static Future<void> show(
    BuildContext context, {
    required String uid,
    required String fallbackName,
    required String fallbackAvatarKey,
  }) {
    final communityBloc = context.read<CommunityBloc>();
    final watchlistCubit = context.read<WatchlistCubit>();
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider<CommunityBloc>.value(value: communityBloc),
            BlocProvider<WatchlistCubit>.value(value: watchlistCubit),
          ],
          child: PublicUserProfileScreen(
            uid: uid,
            fallbackName: fallbackName,
            fallbackAvatarKey: fallbackAvatarKey,
          ),
        ),
      ),
    );
  }
}
