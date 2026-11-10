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
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: const Color(0xFF16171C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF2C2F3A)),
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
                      color: AppColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      color: AppColors.accent,
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9E9EA7),
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
                    foregroundColor: const Color(0xFF8E929E),
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

