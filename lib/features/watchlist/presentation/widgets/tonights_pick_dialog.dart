import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/movie_poster.dart';
import '../../data/models/watchlist_movie_model.dart';

/// Animated randomizer dialog that picks a movie for tonight from the watchlist.
class TonightsPickDialog extends StatefulWidget {
  const TonightsPickDialog({
    super.key,
    required this.candidates,
    required this.onOpenDetails,
  });

  final List<WatchlistMovieModel> candidates;
  final ValueChanged<WatchlistMovieModel> onOpenDetails;

  static Future<void> show(
    BuildContext context, {
    required List<WatchlistMovieModel> candidates,
    required ValueChanged<WatchlistMovieModel> onOpenDetails,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => TonightsPickDialog(
        candidates: candidates,
        onOpenDetails: onOpenDetails,
      ),
    );
  }

  @override
  State<TonightsPickDialog> createState() => _TonightsPickDialogState();
}

class _TonightsPickDialogState extends State<TonightsPickDialog> {
  final _random = Random();
  Timer? _timer;
  late WatchlistMovieModel _current;
  bool _isShuffling = true;

  @override
  void initState() {
    super.initState();
    _current = widget.candidates[_random.nextInt(widget.candidates.length)];
    _startShuffle();
  }

  void _startShuffle() {
    _timer?.cancel();
    if (widget.candidates.length == 1) {
      setState(() {
        _current = widget.candidates.first;
        _isShuffling = false;
      });
      return;
    }

    setState(() => _isShuffling = true);
    var ticks = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 85), (timer) {
      ticks++;
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _current = widget.candidates[_random.nextInt(widget.candidates.length)];
        if (ticks >= 10) {
          _isShuffling = false;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.surfaceBorder),
      ),
      title: Row(
        children: [
          Icon(
            Icons.casino_rounded,
            color: _isShuffling ? AppColors.pacificBlue : AppColors.khakiBeige,
          ),
          const SizedBox(width: 8),
          Text(
            _isShuffling ? 'Picking Tonight\'s Film...' : 'Tonight\'s Pick',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: AnimatedSwitcher(
        duration: const Duration(milliseconds: 120),
        child: Column(
          key: ValueKey(_current.movieId),
          mainAxisSize: MainAxisSize.min,
          children: [
            MoviePoster(
              posterPath: _current.posterPath,
              width: 126,
              height: 186,
              borderRadius: 16,
            ),
            const SizedBox(height: 14),
            Text(
              _current.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${Formatters.releaseYear(_current.releaseDate)}  •  ${_current.voteAverage.toStringAsFixed(1)}★',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.candidates.length > 1)
          TextButton.icon(
            onPressed: _isShuffling ? null : _startShuffle,
            icon: const Icon(Icons.shuffle_rounded, size: 18),
            label: const Text('Shuffle'),
          ),
        FilledButton(
          onPressed: _isShuffling
              ? null
              : () {
                  Navigator.of(context).pop();
                  widget.onOpenDetails(_current);
                },
          child: const Text('Open Details'),
        ),
      ],
    );
  }
}
