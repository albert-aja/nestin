import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/app_restriction.dart';
import '../../../providers/device_control_provider.dart';

/// Shared Nestin intervention modal displaying Roo Digital Discipline's resolved
/// restriction decision, coexisting rule reasons, honest capability state, and
/// mode-appropriate actions (no "Continue Anyway" during Strict Mode).
class WellbeingInterventionDialog {
  static Future<void> show(
    BuildContext context,
    DeviceControlProvider provider,
    RestrictionDecision decision,
  ) {
    final l10n = context.l10n;
    final winner = decision.winningRule;
    final isStrict = decision.effectiveStrength == RestrictionStrength.strict;
    final accent = isStrict ? AppColors.primary : AppColors.accent;

    return showDialog<void>(
      context: context,
      barrierDismissible: !isStrict,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: accent.withValues(alpha: 0.45)),
        ),
        title: Row(
          children: [
            Icon(
              isStrict ? Icons.gpp_maybe_rounded : Icons.pause_circle_rounded,
              color: accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${decision.appName} · ${decision.effectiveStrength.label}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
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
                winner?.title ?? l10n.tr('roo_intervention_active'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                decision.explanation,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary(ctx),
                ),
              ),
              if (winner?.motivation != null &&
                  winner!.motivation!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '“${winner.motivation!}”',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              if (decision.activeRules.length > 1) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.tr('all_coexisting_restrictions', {'decision_length': decision.activeRules.length}),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ...decision.activeRules.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 6,
                          color: r.strength == RestrictionStrength.strict
                              ? AppColors.primary
                              : AppColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${r.sourceType.label} (${r.strength.label}): ${r.reason}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(ctx),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface(ctx),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Platform Status: ${decision.platformSupport.label}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary(ctx),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (decision.canProceedAnyway)
            TextButton(
              onPressed: () {
                provider.recordReminderContinueAnyway(decision.packageName);
                Navigator.of(ctx).pop();
              },
              child: Text(
                l10n.tr('continue_5_min'),
              ),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: accent),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              l10n.tr('stay_focused_in_nestin'),
            ),
          ),
        ],
      ),
    );
  }
}
