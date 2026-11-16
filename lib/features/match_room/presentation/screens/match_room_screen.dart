import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/routing/movie_details_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../../../shared/widgets/movie_poster.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../community/presentation/cubit/community_cubit.dart';
import '../../../watchlist/presentation/cubit/watchlist_cubit.dart';
import '../cubit/match_room_cubit.dart';
import '../cubit/match_room_state.dart';
import '../widgets/match_celebration_dialog.dart';

/// Real-time multiplayer Movie Night Match Room screen (`/match` & `/match/:code`).
class MatchRoomScreen extends StatelessWidget {
  const MatchRoomScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MatchRoomCubit>(
      create: (_) {
        final cubit = sl<MatchRoomCubit>();
        final code = initialCode?.trim();
        if (code != null && code.isNotEmpty) {
          final authUser = context.read<AuthCubit>().state.user;
          final profileName = context
              .read<CommunityCubit>()
              .state
              .profile
              ?.displayName;
          final uid = authUser?.uid;
          if (uid != null) {
            final name = (profileName != null && profileName.trim().isNotEmpty)
                ? profileName.trim()
                : (authUser?.displayName?.trim().isNotEmpty == true
                      ? authUser!.displayName!.trim()
                      : Formatters.greetingName(authUser?.email));
            cubit.joinRoom(code: code, uid: uid, displayName: name);
          }
        }
        return cubit;
      },
      child: _MatchRoomView(initialCode: initialCode),
    );
  }
}

class _MatchRoomView extends StatefulWidget {
  const _MatchRoomView({this.initialCode});

  final String? initialCode;

  @override
  State<_MatchRoomView> createState() => _MatchRoomViewState();
}

class _MatchRoomViewState extends State<_MatchRoomView> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  ({String uid, String name})? _currentUserIdentity(BuildContext context) {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return null;
    final profileName = context
        .read<CommunityCubit>()
        .state
        .profile
        ?.displayName;
    final name = (profileName != null && profileName.trim().isNotEmpty)
        ? profileName.trim()
        : (user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : Formatters.greetingName(user.email));
    return (uid: user.uid, name: name);
  }

  void _createRoom(BuildContext context) {
    final identity = _currentUserIdentity(context);
    if (identity == null) return;
    final watchlist = context.read<WatchlistCubit>().state.wantToWatchMovies;
    final seed = watchlist.map((m) => m.toMovieSummary()).toList();
    context.read<MatchRoomCubit>().createRoom(
      uid: identity.uid,
      displayName: identity.name,
      seedMovies: seed,
    );
  }

  void _joinRoom(BuildContext context) {
    final identity = _currentUserIdentity(context);
    final code = _codeController.text.trim().toUpperCase();
    if (identity == null || code.isEmpty) return;
    FocusScope.of(context).unfocus();
    context.read<MatchRoomCubit>().joinRoom(
      code: code,
      uid: identity.uid,
      displayName: identity.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/discover'),
        ),
        title: const Text(
          'Movie Night Match',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: BlocConsumer<MatchRoomCubit, MatchRoomState>(
              listenWhen: (prev, curr) =>
                  (prev.latestMatch != curr.latestMatch &&
                      curr.latestMatch != null) ||
                  (prev.errorMessage != curr.errorMessage &&
                      curr.errorMessage != null),
              listener: (context, state) {
                if (state.errorMessage != null) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(content: Text(state.errorMessage!)),
                    );
                }
                final match = state.latestMatch;
                if (match != null) {
                  context.read<MatchRoomCubit>().dismissLatestMatch();
                  MatchCelebrationDialog.show(
                    context,
                    movie: match,
                    onOpenDetails: () => MovieDetailsRoute.push(
                      context,
                      movieId: match.id,
                      initialMovie: match,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state.status == MatchRoomStatus.loading) {
                  return const LoadingView(
                    message: 'Setting up your Match Room...',
                  );
                }

                final room = state.room;
                if (room == null || state.status == MatchRoomStatus.idle) {
                  return _LobbyView(
                    codeController: _codeController,
                    onCreateRoom: () => _createRoom(context),
                    onJoinRoom: () => _joinRoom(context),
                  );
                }

                return _ActiveRoomView(state: state);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LobbyView extends StatelessWidget {
  const _LobbyView({
    required this.codeController,
    required this.onCreateRoom,
    required this.onJoinRoom,
  });

  final TextEditingController codeController;
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinRoom;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.pacificBlue.withValues(alpha: 0.18),
                  AppColors.surfaceCard,
                  AppColors.softPeriwinkle.withValues(alpha: 0.14),
                ],
              ),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.pacificBlue.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.pacificBlue,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Can\'t Decide What to Watch?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start a live Match Room, share the 4-letter code or link with a friend, and swipe together until you match on tonight\'s movie.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onCreateRoom,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Start Match Room'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Have a Room Code?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          hintText: 'e.g. X9K2',
                          counterText: '',
                        ),
                        onSubmitted: (_) => onJoinRoom(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: onJoinRoom,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('Join'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveRoomView extends StatelessWidget {
  const _ActiveRoomView({required this.state});

  final MatchRoomState state;

  @override
  Widget build(BuildContext context) {
    final room = state.room!;
    final currentCard = state.currentCard;
    final matches = state.matchedMovies;
    final inviteUrl = '${AppConstants.webAppBaseUrl}/match/${room.code}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          // Room Header: Code + Share + Participants
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'ROOM ',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          room.code,
                          style: const TextStyle(
                            color: AppColors.khakiBeige,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      room.participantUids.length < 2
                          ? 'Waiting for a friend to join...'
                          : '${room.participantUids.length} friends: ${room.participantNames.values.join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Copy invite link',
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 19,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inviteUrl));
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(content: Text('Copied link: $inviteUrl')),
                      );
                  },
                ),
                IconButton(
                  tooltip: 'Share invite',
                  icon: const Icon(
                    Icons.share_rounded,
                    size: 19,
                    color: AppColors.pacificBlue,
                  ),
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text:
                          'Join my CineList Movie Night Match Room (${room.code})!\n$inviteUrl',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Swipe Card Deck
          Expanded(
            child: currentCard == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 52,
                          color: AppColors.pacificBlue,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'You\'ve voted on all movies in this deck!',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          matches.isEmpty
                              ? 'Waiting for your friend to finish voting.'
                              : 'You have ${matches.length} ${matches.length == 1 ? 'match' : 'matches'} below!',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : _SwipeMovieCard(
                    movie: currentCard,
                    onPass: () => context.read<MatchRoomCubit>().vote(
                      movieId: currentCard.id,
                      liked: false,
                    ),
                    onLike: () => context.read<MatchRoomCubit>().vote(
                      movieId: currentCard.id,
                      liked: true,
                    ),
                  ),
          ),

          // Matches Strip
          if (matches.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Matched (${matches.length})',
                style: const TextStyle(
                  color: AppColors.khakiBeige,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 66,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: matches.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final m = matches[index];
                  return InkWell(
                    onTap: () => MovieDetailsRoute.push(
                      context,
                      movieId: m.id,
                      initialMovie: m,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.pacificBlue.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MoviePoster(
                            posterPath: m.posterPath,
                            width: 36,
                            height: 52,
                            borderRadius: 8,
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(
                              m.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
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
        ],
      ),
    );
  }
}

class _SwipeMovieCard extends StatelessWidget {
  const _SwipeMovieCard({
    required this.movie,
    required this.onPass,
    required this.onLike,
  });

  final MovieSummary movie;
  final VoidCallback onPass;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Dismissible(
            key: ValueKey(movie.id),
            onDismissed: (direction) {
              if (direction == DismissDirection.startToEnd) {
                onLike();
              } else {
                onPass();
              }
            },
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 28),
              decoration: BoxDecoration(
                color: AppColors.pacificBlue.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.thumb_up_rounded,
                color: AppColors.pacificBlue,
                size: 42,
              ),
            ),
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 28),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.error,
                size: 42,
              ),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 2 / 3,
                        child: MoviePoster(
                          posterPath: movie.posterPath,
                          borderRadius: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${Formatters.releaseYear(movie.releaseDate)}  •  ${movie.voteAverage.toStringAsFixed(1)}★',
                    style: const TextStyle(
                      color: AppColors.khakiBeige,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (movie.overview.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      movie.overview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _VoteButton(
              icon: Icons.close_rounded,
              color: AppColors.error,
              label: 'Pass',
              onTap: onPass,
            ),
            const SizedBox(width: 28),
            _VoteButton(
              icon: Icons.thumb_up_rounded,
              color: AppColors.pacificBlue,
              label: 'Watch!',
              onTap: onLike,
            ),
          ],
        ),
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
