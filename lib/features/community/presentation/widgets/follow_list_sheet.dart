import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../watchlist/presentation/cubit/watchlist_cubit.dart';
import '../../data/models/user_profile_model.dart';
import '../bloc/community_bloc.dart';
import 'user_avatar_widget.dart';
import 'user_profile_dialog.dart';

/// Reusable modal bottom sheet displaying a user's Followers or Following list.
class FollowListSheet extends StatelessWidget {
  const FollowListSheet({
    super.key,
    required this.title,
    required this.uids,
  });

  final String title;
  final List<String> uids;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<String> uids,
  }) {
    final communityBloc = context.read<CommunityBloc>();
    final watchlistCubit = context.read<WatchlistCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider<CommunityBloc>.value(value: communityBloc),
          BlocProvider<WatchlistCubit>.value(value: watchlistCubit),
        ],
        child: FollowListSheet(title: title, uids: uids),
      ),
    );
  }

  /// Helper returning all UIDs that follow [targetUid] from [allUsersByUid].
  static List<String> followersOf(
    String targetUid,
    Map<String, UserProfileModel> allUsersByUid,
  ) {
    return allUsersByUid.values
        .where((u) => u.uid != targetUid && u.followingUids.contains(targetUid))
        .map((u) => u.uid)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CommunityBloc>().state;
    final bloc = context.read<CommunityBloc>();
    final currentUid = bloc.currentUid;
    final myFollowing =
        state.profile?.followingUids.toSet() ?? const <String>{};

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.88,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$title (${uids.length})',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.surfaceBorder),
            Expanded(
              child: uids.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          title == 'Followers'
                              ? 'No followers yet.'
                              : 'Not following anyone yet.',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(14),
                      itemCount: uids.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final targetUid = uids[index];
                        final user = state.userProfilesByUid[targetUid];
                        final name = user?.displayName ?? 'Movie Fan';
                        final avatarKey = user?.avatarKey ?? 'cinema';
                        final isMe = targetUid == currentUid;
                        final isFollowing = myFollowing.contains(targetUid);

                        return InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            UserProfileDialog.show(
                              context,
                              uid: targetUid,
                              fallbackName: name,
                              fallbackAvatarKey: avatarKey,
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.surfaceBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                UserAvatar(
                                  avatarKey: avatarKey,
                                  photoBase64: user?.photoBase64,
                                  reputation: user?.reputation ?? 0,
                                  isAdmin: state.adminUids.contains(targetUid),
                                  isModerator: state.moderatorUids.contains(
                                    targetUid,
                                  ),
                                  radius: 19,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (user != null &&
                                          user.bio.trim().isNotEmpty)
                                        Text(
                                          user.bio.trim(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (!isMe && currentUid != null) ...[
                                  const SizedBox(width: 8),
                                  isFollowing
                                      ? OutlinedButton(
                                          onPressed: () => bloc.add(
                                            CommunityFollowToggled(targetUid),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                AppColors.textSecondary,
                                            side: const BorderSide(
                                              color: AppColors.surfaceBorder,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: const Text(
                                            'Following',
                                            style: TextStyle(fontSize: 11.5),
                                          ),
                                        )
                                      : FilledButton(
                                          onPressed: () => bloc.add(
                                            CommunityFollowToggled(targetUid),
                                          ),
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                AppColors.pacificBlue,
                                            foregroundColor: AppColors.black,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: const Text(
                                            'Follow',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Compact tappable Followers / Following count row used in profiles and edit dialog.
class FollowCountsRow extends StatelessWidget {
  const FollowCountsRow({
    super.key,
    required this.followerUids,
    required this.followingUids,
  });

  final List<String> followerUids;
  final List<String> followingUids;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CountPill(
          count: followerUids.length,
          label: 'Followers',
          onTap: () => FollowListSheet.show(
            context,
            title: 'Followers',
            uids: followerUids,
          ),
        ),
        const SizedBox(width: 12),
        _CountPill(
          count: followingUids.length,
          label: 'Following',
          onTap: () => FollowListSheet.show(
            context,
            title: 'Following',
            uids: followingUids,
          ),
        ),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.count,
    required this.label,
    required this.onTap,
  });

  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
