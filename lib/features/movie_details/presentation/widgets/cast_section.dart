import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/cast_member_model.dart';

/// Horizontal cast list shown on Movie Details when credits are available.
class CastSection extends StatelessWidget {
  const CastSection({super.key, required this.cast, this.onCastTap});

  final List<CastMemberModel> cast;
  final ValueChanged<CastMemberModel>? onCastTap;

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cast', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cast.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final member = cast[index];
              final profileUrl = ApiConstants.profileUrl(member.profilePath);

              return InkWell(
                onTap: onCastTap == null ? null : () => onCastTap!(member),
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 78,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.surfaceCard,
                        backgroundImage: profileUrl != null
                            ? CachedNetworkImageProvider(profileUrl)
                            : null,
                        child: profileUrl == null
                            ? const Icon(
                                Icons.person_outline_rounded,
                                color: AppColors.textMuted,
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (member.character.isNotEmpty)
                        Text(
                          member.character,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
