import 'package:cine_list/core/theme/app_colors.dart';
import 'package:cine_list/features/community/data/models/user_profile_model.dart';
import 'package:cine_list/features/community/presentation/bloc/community_bloc.dart';
import 'package:cine_list/features/community/presentation/widgets/user_avatar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UserProfileDialog extends StatelessWidget {
  const UserProfileDialog({
    super.key,
    required this.uid,
    required this.fallbackName,
    required this.fallbackAvatarKey,
  });

  final String uid;
  final String fallbackName;
  final String fallbackAvatarKey;

  static Future<void> show(
    BuildContext context, {
    required String uid,
    required String fallbackName,
    required String fallbackAvatarKey,
  }) {
    final bloc = context.read<CommunityBloc>();
    return showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: UserProfileDialog(
          uid: uid,
          fallbackName: fallbackName,
          fallbackAvatarKey: fallbackAvatarKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CommunityBloc>();
    final viewerUid = bloc.currentUid;
    final canFollow = viewerUid != null && viewerUid != uid;
    final isFollowing = context.select<CommunityBloc, bool>(
      (b) => b.state.profile?.isFollowing(uid) ?? false,
    );
    final future = Future.wait([
      bloc.fetchUserProfile(uid),
      bloc.checkIsAdmin(uid),
      bloc.checkIsModerator(uid),
    ]);

    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      content: FutureBuilder<List<dynamic>>(
        future: future,
        builder: (context, snapshot) {
          final profile = snapshot.data?[0] as UserProfileModel?;
          final isAdmin = (snapshot.data?[1] as bool?) ?? false;
          final isModerator = (snapshot.data?[2] as bool?) ?? false;
          final displayName = (profile?.displayName.trim().isNotEmpty ?? false)
              ? profile!.displayName
              : fallbackName;
          final avatarKey = (profile?.avatarKey.trim().isNotEmpty ?? false)
              ? profile!.avatarKey
              : fallbackAvatarKey;
          final bio = profile?.bio.trim() ?? '';
          final reputation = profile?.reputation ?? 0;
          final tier = ReputationTier.fromPoints(reputation);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(
                avatarKey: avatarKey,
                photoBase64: profile?.photoBase64,
                reputation: reputation,
                isAdmin: isAdmin,
                isModerator: isModerator,
                radius: 34,
              ),
              const SizedBox(height: 12),
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  if (isAdmin)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.khakiBeige.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.khakiBeige.withValues(alpha: 0.65),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            size: 14,
                            color: AppColors.khakiBeige,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Admin',
                            style: TextStyle(
                              color: AppColors.khakiBeige,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (isModerator)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.pacificBlue.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.pacificBlue.withValues(alpha: 0.65),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.gavel_rounded,
                            size: 14,
                            color: AppColors.pacificBlue,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Moderator',
                            style: TextStyle(
                              color: AppColors.pacificBlue,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tier.color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: tier.color.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tier.icon, size: 14, color: tier.color),
                        const SizedBox(width: 5),
                        Text(
                          '${tier.label} · $reputation pts',
                          style: TextStyle(
                            color: tier.color,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Text(
                  bio.isEmpty ? 'No bio added yet.' : bio,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: bio.isEmpty
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
            ],
          );
        },
      ),
      actions: [
        if (canFollow)
          FilledButton.icon(
            onPressed: () => bloc.add(CommunityFollowToggled(uid)),
            style: FilledButton.styleFrom(
              backgroundColor: isFollowing
                  ? AppColors.surfaceElevated
                  : AppColors.pacificBlue,
              foregroundColor: isFollowing
                  ? AppColors.textPrimary
                  : AppColors.black,
            ),
            icon: Icon(
              isFollowing ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
              size: 16,
            ),
            label: Text(isFollowing ? 'Following' : 'Follow'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
