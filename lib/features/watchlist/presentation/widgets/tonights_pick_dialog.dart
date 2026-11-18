import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/movie_poster.dart';
import '../../data/models/watchlist_movie_model.dart';

/// Animated randomizer dialog with quick filters that picks a movie for tonight.
class TonightsPickDialog extends StatefulWidget {
  const TonightsPickDialog({
    super.key,
    required this.allCandidates,
    this.collectionCandidates,
    this.collectionName,
    required this.onOpenDetails,
  });

  final List<WatchlistMovieModel> allCandidates;
  final List<WatchlistMovieModel>? collectionCandidates;
  final String? collectionName;
  final ValueChanged<WatchlistMovieModel> onOpenDetails;

  static Future<void> show(
    BuildContext context, {
    required List<WatchlistMovieModel> allCandidates,
    List<WatchlistMovieModel>? collectionCandidates,
    String? collectionName,
    required ValueChanged<WatchlistMovieModel> onOpenDetails,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => TonightsPickDialog(
        allCandidates: allCandidates,
        collectionCandidates: collectionCandidates,
        collectionName: collectionName,
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
  WatchlistMovieModel? _current;
  bool _isShuffling = true;

  bool _useCollectionOnly = false;
  int? _maxRuntimeMinutes;
  double? _minRating;

  bool get _hasCollectionOption =>
      widget.collectionName != null &&
      widget.collectionCandidates != null &&
      widget.collectionCandidates!.isNotEmpty;

  List<WatchlistMovieModel> get _filteredCandidates {
    final base = _useCollectionOnly && _hasCollectionOption
        ? widget.collectionCandidates!
        : widget.allCandidates;
    return base.where((m) {
      if (_maxRuntimeMinutes != null) {
        if (m.runtimeMinutes == null || m.runtimeMinutes! > _maxRuntimeMinutes!) {
          return false;
        }
      }
      if (_minRating != null && m.voteAverage < _minRating!) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _useCollectionOnly = _hasCollectionOption;
    _startShuffle();
  }

  void _startShuffle() {
    _timer?.cancel();
    final pool = _filteredCandidates;
    if (pool.isEmpty) {
      setState(() {
        _current = null;
        _isShuffling = false;
      });
      return;
    }

    _current = pool[_random.nextInt(pool.length)];
    if (pool.length == 1) {
      setState(() => _isShuffling = false);
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
      final currentPool = _filteredCandidates;
      if (currentPool.isEmpty) {
        timer.cancel();
        setState(() {
          _current = null;
          _isShuffling = false;
        });
        return;
      }
      setState(() {
        _current = currentPool[_random.nextInt(currentPool.length)];
        if (ticks >= 10) {
          _isShuffling = false;
          timer.cancel();
        }
      });
    });
  }

  void _resetFilters() {
    setState(() {
      _useCollectionOnly = false;
      _maxRuntimeMinutes = null;
      _minRating = null;
    });
    _startShuffle();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pool = _filteredCandidates;

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
          Expanded(
            child: Text(
              _isShuffling ? 'Picking Tonight\'s Film...' : 'Tonight\'s Pick',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_hasCollectionOption)
                  _FilterChip(
                    label: widget.collectionName!,
                    selected: _useCollectionOnly,
                    onTap: () {
                      setState(() => _useCollectionOnly = !_useCollectionOnly);
                      _startShuffle();
                    },
                  ),
                _FilterChip(
                  label: '≤ 100m',
                  selected: _maxRuntimeMinutes == 100,
                  onTap: () {
                    setState(() {
                      _maxRuntimeMinutes =
                          _maxRuntimeMinutes == 100 ? null : 100;
                    });
                    _startShuffle();
                  },
                ),
                _FilterChip(
                  label: '≤ 2h',
                  selected: _maxRuntimeMinutes == 120,
                  onTap: () {
                    setState(() {
                      _maxRuntimeMinutes =
                          _maxRuntimeMinutes == 120 ? null : 120;
                    });
                    _startShuffle();
                  },
                ),
                _FilterChip(
                  label: '7.5+ ★',
                  selected: _minRating == 7.5,
                  onTap: () {
                    setState(() {
                      _minRating = _minRating == 7.5 ? null : 7.5;
                    });
                    _startShuffle();
                  },
                ),
                _FilterChip(
                  label: '8.0+ ★',
                  selected: _minRating == 8.0,
                  onTap: () {
                    setState(() {
                      _minRating = _minRating == 8.0 ? null : 8.0;
                    });
                    _startShuffle();
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_current == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.filter_alt_off_rounded,
                      color: AppColors.textMuted,
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No movies match those filters.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _resetFilters,
                      child: const Text('Reset Filters'),
                    ),
                  ],
                ),
              )
            else
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 120),
                child: Column(
                  key: ValueKey(_current!.movieId),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MoviePoster(
                      posterPath: _current!.posterPath,
                      width: 126,
                      height: 186,
                      borderRadius: 16,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _current!.title,
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
                      '${Formatters.releaseYear(_current!.releaseDate)}  •  ${_current!.voteAverage.toStringAsFixed(1)}★'
                      '${_current!.runtimeMinutes != null ? '  •  ${_current!.runtimeMinutes}m' : ''}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (pool.length > 1)
          TextButton.icon(
            onPressed: _isShuffling ? null : _startShuffle,
            icon: const Icon(Icons.shuffle_rounded, size: 18),
            label: const Text('Shuffle'),
          ),
        FilledButton(
          onPressed: _isShuffling || _current == null
              ? null
              : () {
                  final picked = _current!;
                  Navigator.of(context).pop();
                  widget.onOpenDetails(picked);
                },
          child: const Text('Open Details'),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      selectedColor: AppColors.pacificBlue.withValues(alpha: 0.22),
      backgroundColor: AppColors.surfaceElevated,
      side: BorderSide(
        color: selected ? AppColors.pacificBlue : AppColors.surfaceBorder,
      ),
      labelStyle: TextStyle(
        color: selected ? AppColors.pacificBlue : AppColors.textSecondary,
        fontSize: 11.5,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}
