import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ReviewResult {
  const ReviewResult({this.rating, this.note});

  final int? rating;
  final String? note;
}

/// Modal dialog for leaving a 1-5 star personal rating and short note.
class ReviewDialog extends StatefulWidget {
  const ReviewDialog({
    super.key,
    required this.movieTitle,
    this.initialRating,
    this.initialNote,
  });

  final String movieTitle;
  final int? initialRating;
  final String? initialNote;

  static Future<ReviewResult?> show(
    BuildContext context, {
    required String movieTitle,
    int? initialRating,
    String? initialNote,
  }) {
    return showDialog<ReviewResult>(
      context: context,
      builder: (_) => ReviewDialog(
        movieTitle: movieTitle,
        initialRating: initialRating,
        initialNote: initialNote,
      ),
    );
  }

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  late int? _rating;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _noteController = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Rate "${widget.movieTitle}"',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.khakiBeige, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Rating',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              final filled = (_rating ?? 0) >= starValue;
              return IconButton(
                onPressed: () {
                  setState(() {
                    _rating = _rating == starValue ? null : starValue;
                  });
                },
                icon: Icon(
                  filled ? Icons.star_rounded : Icons.star_border_rounded,
                  color: filled ? AppColors.starAmber : AppColors.textMuted,
                  size: 32,
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3,
            maxLength: 300,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Add a quick note (optional)...',
              counterStyle: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.pacificBlue,
            foregroundColor: AppColors.black,
          ),
          onPressed: () => Navigator.of(context).pop(
            ReviewResult(rating: _rating, note: _noteController.text.trim()),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
