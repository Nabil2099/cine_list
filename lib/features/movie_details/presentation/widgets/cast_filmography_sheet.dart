import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/routing/movie_details_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/movie_card.dart';
import '../../../discover/data/models/movie_model.dart';
import '../../data/models/cast_member_model.dart';
import '../../data/models/person_details_model.dart';
import '../../data/repositories/movie_details_repository.dart';

/// Modal bottom sheet showing a cast member's bio and TMDB filmography.
class CastFilmographySheet extends StatefulWidget {
  const CastFilmographySheet({super.key, required this.castMember});

  final CastMemberModel castMember;

  static Future<void> show(
    BuildContext context, {
    required CastMemberModel castMember,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CastFilmographySheet(castMember: castMember),
    );
  }

  @override
  State<CastFilmographySheet> createState() => _CastFilmographySheetState();
}

class _CastFilmographySheetState extends State<CastFilmographySheet> {
  late final Future<({PersonDetailsModel? person, List<MovieModel> movies})>
  _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({PersonDetailsModel? person, List<MovieModel> movies})>
  _load() async {
    final repo = sl<MovieDetailsRepository>();
    final results = await Future.wait([
      repo
          .getPersonDetails(widget.castMember.id)
          .catchError(
            (_) => PersonDetailsModel(
              id: widget.castMember.id,
              name: widget.castMember.name,
              profilePath: widget.castMember.profilePath,
            ),
          ),
      repo
          .getPersonFilmography(widget.castMember.id)
          .catchError((_) => const <MovieModel>[]),
    ]);
    return (
      person: results[0] as PersonDetailsModel?,
      movies: results[1] as List<MovieModel>,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileUrl = ApiConstants.profileUrl(widget.castMember.profilePath);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return FutureBuilder<
          ({PersonDetailsModel? person, List<MovieModel> movies})
        >(
          future: _future,
          builder: (context, snapshot) {
            final person = snapshot.data?.person;
            final movies = snapshot.data?.movies ?? const <MovieModel>[];
            final bio = person?.biography ?? '';
            final dept = person?.knownForDepartment ?? '';

            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: AppColors.surfaceElevated,
                      backgroundImage: profileUrl != null
                          ? CachedNetworkImageProvider(profileUrl)
                          : null,
                      child: profileUrl == null
                          ? const Icon(
                              Icons.person_outline_rounded,
                              size: 30,
                              color: AppColors.textMuted,
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person?.name ?? widget.castMember.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (widget.castMember.character.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'as ${widget.castMember.character}',
                              style: const TextStyle(
                                color: AppColors.khakiBeige,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (dept.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              dept,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  Text(
                    'Biography',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bio.isNotEmpty ? bio : 'No biography available.',
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Known For',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (movies.isEmpty)
                    const Text(
                      'No movie credits found.',
                      style: TextStyle(color: AppColors.textMuted),
                    )
                  else
                    SizedBox(
                      height: 230,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: movies.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final movie = movies[index];
                          return MovieCard(
                            movie: movie,
                            width: 126,
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MovieDetailsRoute.build(
                                  movieId: movie.id,
                                  initialMovie: movie,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
