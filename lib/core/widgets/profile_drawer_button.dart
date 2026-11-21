import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/auth_state.dart';
import '../../features/community/presentation/bloc/community_bloc.dart';
import '../../features/community/presentation/widgets/user_avatar_widget.dart';
import '../theme/app_colors.dart';

/// Compact 1-tap Profile & Account drawer trigger shown on mobile tab headers.
class ProfileDrawerButton extends StatelessWidget {
  const ProfileDrawerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isSignedIn = context.select<AuthCubit, bool>(
      (c) => c.state.status == AuthStatus.authenticated,
    );

    return IconButton(
      tooltip: isSignedIn ? 'Profile & Settings' : 'Guest Menu & Sign In',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
      icon: isSignedIn
          ? Builder(
              builder: (context) {
                final avatarKey = context.select<CommunityBloc, String>(
                  (b) => b.state.profile?.avatarKey ?? 'cinema',
                );
                final photoBase64 = context.select<CommunityBloc, String?>(
                  (b) => b.state.profile?.photoBase64,
                );
                final reputation = context.select<CommunityBloc, int>(
                  (b) => b.state.profile?.reputation ?? 0,
                );
                final isAdmin = context.select<CommunityBloc, bool>(
                  (b) => b.state.isAdmin,
                );
                final isModerator = context.select<CommunityBloc, bool>(
                  (b) => b.state.isModerator,
                );
                return UserAvatar(
                  avatarKey: avatarKey,
                  photoBase64: photoBase64,
                  reputation: reputation,
                  isAdmin: isAdmin,
                  isModerator: isModerator,
                  showRankBadge: false,
                  radius: 17,
                );
              },
            )
          : Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: AppColors.khakiBeige,
                size: 20,
              ),
            ),
    );
  }
}
