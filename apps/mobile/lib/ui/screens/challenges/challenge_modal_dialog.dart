import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/challenge_profile.dart';
import 'math_challenge_widget.dart';
import 'memory_challenge_widget.dart';
import 'typing_challenge_widget.dart';

class ChallengeModalDialog extends StatelessWidget {
  final WakeUpChallengeProfile challenge;
  final VoidCallback onDismissAlarm;
  final VoidCallback? onSnooze;

  const ChallengeModalDialog({
    super.key,
    required this.challenge,
    required this.onDismissAlarm,
    this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    final accentInk = AppColors.adaptive(
      context,
      dark: AppColors.accent,
      light: const Color(0xFFB45309),
    );
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: AppColors.sheetSurface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppColors.border(context)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.psychology_rounded,
                      color: accentInk,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Wake-Up Challenge',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${challenge.typeLabel} • ${challenge.difficultyLabel}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Challenge Body
              if (challenge.type == ChallengeType.math)
                MathChallengeWidget(
                  difficulty: challenge.difficulty,
                  totalQuestions: challenge.questionsCount,
                  onCompleted: () {
                    Navigator.of(context).pop();
                    onDismissAlarm();
                  },
                )
              else if (challenge.type == ChallengeType.memory)
                MemoryChallengeWidget(
                  difficulty: challenge.difficulty,
                  onCompleted: () {
                    Navigator.of(context).pop();
                    onDismissAlarm();
                  },
                )
              else
                TypingChallengeWidget(
                  difficulty: challenge.difficulty,
                  onCompleted: () {
                    Navigator.of(context).pop();
                    onDismissAlarm();
                  },
                ),

              if (challenge.allowSnoozeDuringChallenge && onSnooze != null) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onSnooze!();
                  },
                  icon: const Icon(Icons.snooze_rounded, size: 18),
                  label: const Text('Snooze for a few minutes'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

