import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/review_report_model.dart';

/// Dialog allowing users to report a community review for safety violations.
class ReportReviewDialog extends StatefulWidget {
  const ReportReviewDialog({super.key, required this.authorName});

  final String authorName;

  static Future<({ReportReason reason, String details})?> show(
    BuildContext context, {
    required String authorName,
  }) {
    return showDialog<({ReportReason reason, String details})>(
      context: context,
      builder: (_) => ReportReviewDialog(authorName: authorName),
    );
  }

  @override
  State<ReportReviewDialog> createState() => _ReportReviewDialogState();
}

class _ReportReviewDialogState extends State<ReportReviewDialog> {
  ReportReason _selected = ReportReason.hateSpeech;
  final _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.surfaceBorder),
      ),
      title: const Row(
        children: [
          Icon(Icons.flag_rounded, color: AppColors.error, size: 22),
          SizedBox(width: 8),
          Text(
            'Report Review',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why are you reporting ${widget.authorName}\'s review?',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            RadioGroup<ReportReason>(
              groupValue: _selected,
              onChanged: (val) {
                if (val != null) setState(() => _selected = val);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: ReportReason.values
                    .map(
                      (reason) => RadioListTile<ReportReason>(
                        value: reason,
                        activeColor: AppColors.error,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          reason.label,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              maxLength: 250,
              decoration: const InputDecoration(
                hintText: 'Optional details for moderators...',
                counterText: '',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(context).pop((
            reason: _selected,
            details: _detailsController.text.trim(),
          )),
          child: const Text('Submit Report'),
        ),
      ],
    );
  }
}

