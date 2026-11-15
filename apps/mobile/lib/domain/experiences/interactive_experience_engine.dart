import '../../data/models/interactive_experience_models.dart';

/// Deterministic Shared Interactive Experience Engine (Phase 2).
///
/// Combines:
/// 1. Questionnaire Engine (conditional branching, optional questions, multi-type inputs)
/// 2. Scoring & Recommendation Engine (weighted tag scoring, constraint matching,
///    ranking multipliers, and explainable outcome generation)
class InteractiveExperienceEngine {
  const InteractiveExperienceEngine();

  /// Returns only the questions that should be visible given the current draft's answers.
  List<ExperienceQuestion> visibleQuestions(
    ExperienceDefinition definition,
    ExperienceSessionDraft draft,
  ) {
    final visible = <ExperienceQuestion>[];
    for (final q in definition.questions) {
      if (q.showIfQuestionId == null || q.showIfOptionIds.isEmpty) {
        visible.add(q);
        continue;
      }
      final parentSelected =
          draft.selectedOptionIdsByQuestion[q.showIfQuestionId!] ?? const [];
      final shouldShow =
          q.showIfOptionIds.any((optId) => parentSelected.contains(optId));
      if (shouldShow) {
        visible.add(q);
      }
    }
    return visible;
  }

  /// Checks whether the user has provided a valid answer (or skipped an optional question).
  bool isQuestionSatisfied(
    ExperienceQuestion question,
    ExperienceSessionDraft draft,
  ) {
    if (question.isOptional &&
        draft.skippedQuestionIds.contains(question.id)) {
      return true;
    }
    switch (question.type) {
      case ExperienceQuestionType.slider:
      case ExperienceQuestionType.numericInput:
        return true; // Slider/numeric always has a valid numeric value or defaultValue
      case ExperienceQuestionType.singleChoice:
      case ExperienceQuestionType.multipleChoice:
      case ExperienceQuestionType.visualSelection:
      case ExperienceQuestionType.ranking:
        final selected =
            draft.selectedOptionIdsByQuestion[question.id] ?? const [];
        return selected.isNotEmpty || question.isOptional;
    }
  }

  /// Evaluates a completed [ExperienceSessionDraft] against [definition] deterministically
  /// and returns an ordered list of top [ExperienceMatchedOutcome]s with explainable reasons.
  List<ExperienceMatchedOutcome> evaluateHobbyFinder({
    required ExperienceDefinition definition,
    required ExperienceSessionDraft draft,
    int maxResults = 3,
  }) {
    final visible = visibleQuestions(definition, draft);
    final accumulatedTags = <String, double>{};
    ExperienceBudgetTier? selectedBudgetTier;
    ExperienceEnvironmentType? selectedEnvironment;
    final weeklyHours = draft.numericValueByQuestion['q_weekly_hours'] ?? 3.0;

    for (final question in visible) {
      if (draft.skippedQuestionIds.contains(question.id)) {
        continue;
      }
      final selectedIds =
          draft.selectedOptionIdsByQuestion[question.id] ?? const [];
      for (var i = 0; i < selectedIds.length; i++) {
        final optId = selectedIds[i];
        ExperienceOption? option;
        for (final candidate in question.options) {
          if (candidate.id == optId) {
            option = candidate;
            break;
          }
        }
        if (option == null) continue;

        if (option.budgetTier != null) {
          selectedBudgetTier = option.budgetTier;
        }
        if (option.environmentType != null) {
          selectedEnvironment = option.environmentType;
        }

        // For ranking questions, earlier ranked choices receive a higher weight multiplier.
        final rankMultiplier =
            question.type == ExperienceQuestionType.ranking
                ? (1.0 - (i * 0.25)).clamp(0.4, 1.0)
                : 1.0;

        option.tagWeights.forEach((tag, weight) {
          accumulatedTags[tag] =
              (accumulatedTags[tag] ?? 0.0) + (weight * rankMultiplier);
        });
      }
    }

    final scoredOutcomes = <ExperienceMatchedOutcome>[];

    for (final profile in definition.hobbyProfiles) {
      var rawScore = 0.0;
      var maxPossibleTagScore = 0.0;

      profile.tagAffinities.forEach((tag, affinity) {
        maxPossibleTagScore += affinity * 3.5;
        final userTagScore = accumulatedTags[tag] ?? 0.0;
        rawScore += userTagScore * affinity;
      });

      final reasonKeys = <String>[profile.whyItFitsKey];
      final reasonParams = <String, Map<String, dynamic>>{};

      // Constraint 1: Weekly time availability
      if (weeklyHours >= profile.minHoursPerWeek) {
        rawScore += 6.0;
        reasonKeys.add('exp_reason_time_fit');
        reasonParams['exp_reason_time_fit'] = {
          'hours': weeklyHours.toStringAsFixed(0),
        };
      } else {
        rawScore -= (profile.minHoursPerWeek - weeklyHours) * 3.5;
      }

      // Constraint 2: Starter budget comfort
      if (selectedBudgetTier != null) {
        if (profile.budgetTier.index <= selectedBudgetTier.index) {
          rawScore += 6.5;
          reasonKeys.add('exp_reason_budget_fit');
          reasonParams['exp_reason_budget_fit'] = {
            'cost': profile.estimatedStarterCostUsd.toString(),
          };
        } else {
          final tierDiff = profile.budgetTier.index - selectedBudgetTier.index;
          rawScore -= tierDiff * 4.5;
        }
      }

      // Constraint 3: Environment & workspace fit
      if (selectedEnvironment != null) {
        if (profile.preferredEnvironments.contains(selectedEnvironment)) {
          rawScore += 6.0;
          reasonKeys.add('exp_reason_env_fit');
        } else {
          rawScore -= 2.5;
        }
      }

      final normalizedDenominator =
          (maxPossibleTagScore + 18.5).clamp(20.0, 120.0);
      final normalizedRatio =
          (rawScore / normalizedDenominator).clamp(0.15, 0.99);
      final matchPercentage = (58 + (normalizedRatio * 40)).round().clamp(55, 98);

      scoredOutcomes.add(
        ExperienceMatchedOutcome(
          profileId: profile.id,
          matchPercentage: matchPercentage,
          rawScore: rawScore,
          reasonKeys: reasonKeys,
          reasonParamsByKey: reasonParams,
        ),
      );
    }

    scoredOutcomes.sort((a, b) {
      final byScore = b.rawScore.compareTo(a.rawScore);
      if (byScore != 0) return byScore;
      return a.profileId.compareTo(b.profileId);
    });

    return scoredOutcomes.take(maxResults).toList();
  }
}
