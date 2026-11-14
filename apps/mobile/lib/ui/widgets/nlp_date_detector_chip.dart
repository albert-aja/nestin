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

    final accent = AppColors.adaptive(
      context,
      dark: AppColors.accent,
      light: const Color(0xFFB45309),
    );

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: AppColors.isDark(context) ? 0.16 : 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 14,
            color: accent,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Detected: ${result.formattedSummary()}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onCleanTitle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                'Clean Title',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDismiss,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

