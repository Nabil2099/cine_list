import 'package:cine_list/core/theme/app_colors.dart';
import 'package:cine_list/features/community/data/models/user_profile_model.dart';
import 'package:cine_list/features/community/presentation/cubit/community_cubit.dart';
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
    final cubit = context.read<CommunityCubit>();
    return showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
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
    final future = context.read<CommunityCubit>().fetchUserProfile(uid);

    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      content: FutureBuilder<UserProfileModel?>(
        future: future,
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final displayName = (profile?.displayName.trim().isNotEmpty ?? false)
              ? profile!.displayName
              : fallbackName;
          final avatarKey = (profile?.avatarKey.trim().isNotEmpty ?? false)
              ? profile!.avatarKey
              : fallbackAvatarKey;
          final bio = profile?.bio.trim() ?? '';

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(avatarKey: avatarKey, radius: 34),
              const SizedBox(height: 12),
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
