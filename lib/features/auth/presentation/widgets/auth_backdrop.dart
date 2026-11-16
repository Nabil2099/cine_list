import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Decorative cinematic header backdrop inspired by the CineList reference.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.dustyLavender.withValues(alpha: 0.45),
                  AppColors.softPeriwinkle.withValues(alpha: 0.2),
                  AppColors.pacificBlue.withValues(alpha: 0.14),
                  AppColors.black,
                ],
              ),
            ),
          ),
          // Angled film-frame tiles mimicking the diagonal poster collage
          Positioned(
            top: -28,
            left: -20,
            right: -20,
            child: Transform.rotate(
              angle: -0.18,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _FilmTile(
                    icon: Icons.theaters_rounded,
                    tint: AppColors.dustyLavender,
                  ),
                  SizedBox(width: 12),
                  _FilmTile(
                    icon: Icons.movie_creation_outlined,
                    tint: AppColors.softPeriwinkle,
                  ),
                  SizedBox(width: 12),
                  _FilmTile(
                    icon: Icons.local_movies_rounded,
                    tint: AppColors.pacificBlue,
                  ),
                  SizedBox(width: 12),
                  _FilmTile(
                    icon: Icons.star_rounded,
                    tint: AppColors.khakiBeige,
                  ),
                ],
              ),
            ),
          ),
          // Smooth dark fade into main background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.55, 1.0],
                colors: [Color(0x44000505), Color(0xCC000505), AppColors.black],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilmTile extends StatelessWidget {
  const _FilmTile({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 132,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tint.withValues(alpha: 0.35),
            AppColors.surfaceCard.withValues(alpha: 0.85),
          ],
        ),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, size: 32, color: tint.withValues(alpha: 0.65)),
    );
  }
}
