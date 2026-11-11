import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/nlp/natural_language_date_parser.dart';

class NlpDateDetectorChip extends StatelessWidget {
  final ParsedDateResult result;
  final VoidCallback onCleanTitle;
  final VoidCallback onDismiss;

  const NlpDateDetectorChip({
    super.key,
    required this.result,
    required this.onCleanTitle,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (!result.hasMatch) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 14,
            color: AppColors.accent,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Detected: ${result.formattedSummary()}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onCleanTitle,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                'Clean Title',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDismiss,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: Color(0xFF8E929E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

