import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/watchlist_movie_model.dart';
import '../cubit/watchlist_cubit.dart';
import '../cubit/watchlist_state.dart';

/// Dialog to create a new custom watchlist collection.
class CreateCollectionDialog {
  static Future<void> show(BuildContext context) async {
    final cubit = context.read<WatchlistCubit>();

    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CreateCollectionDialog(),
    );

    if (name != null && name.isNotEmpty) {
      await cubit.createCollection(name);
    }
  }
}

class _CreateCollectionDialog extends StatefulWidget {
  const _CreateCollectionDialog();

  @override
  State<_CreateCollectionDialog> createState() =>
      _CreateCollectionDialogState();
}

class _CreateCollectionDialogState extends State<_CreateCollectionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.surfaceBorder),
      ),
      title: const Text(
        'New Collection',
        style: TextStyle(color: AppColors.khakiBeige),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'e.g. Date Night, Sci-Fi Classics',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

/// Modal bottom sheet to add or remove a movie across custom collections.
class CollectionPickerSheet extends StatelessWidget {
  const CollectionPickerSheet({super.key, required this.movie});

  final WatchlistMovieModel movie;

  static Future<void> show(
    BuildContext context, {
    required WatchlistMovieModel movie,
  }) {
    final cubit = context.read<WatchlistCubit>();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: CollectionPickerSheet(movie: movie),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: BlocBuilder<WatchlistCubit, WatchlistState>(
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Collections for "${movie.title}"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => CreateCollectionDialog.show(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (state.collections.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No collections yet. Tap "+ New" to create one.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: state.collections.length,
                      itemBuilder: (context, index) {
                        final col = state.collections[index];
                        final checked = col.containsMovie(movie.movieId);
                        return CheckboxListTile(
                          value: checked,
                          activeColor: AppColors.pacificBlue,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            col.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${col.movieIds.length} ${col.movieIds.length == 1 ? 'movie' : 'movies'}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          onChanged: (_) => context
                              .read<WatchlistCubit>()
                              .toggleMovieInCollection(col, movie),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
