import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/alarm.dart';

/// Displays a concise floating snackbar showing when an enabled or saved
/// [alarm] will next ring (e.g. "Rings in 7h 14m").
void showAlarmNextRingSnackBar(
  BuildContext context,
  Alarm alarm, {
  DateTime? now,
}) {
  if (!alarm.isEnabled) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final l10n = context.l10n;
  final message = alarm.formatRingsIn(
    now ?? DateTime.now(),
    isIndonesian: l10n.isIndonesian,
  );

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.adaptive(
          context,
          dark: const Color(0xFF1F222B),
          light: AppColors.lightTextPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
        content: Row(
          children: [
            const Icon(
              Icons.alarm_on_rounded,
              color: AppColors.accent,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
