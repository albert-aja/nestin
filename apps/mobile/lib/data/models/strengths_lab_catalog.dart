import 'interactive_experience_models.dart';

/// Non-clinical everyday personal strength archetype surfaced by Echo's
/// Strengths & Quiet Life Skills Lab (`strengths_life_skills_v1`).
class StrengthProfile {
  final String id;
  final String titleKey;
  final String subtitleKey;
  final String descriptionKey;
  final String quietSkillPracticeKey;
  final String keepsakeQuoteKey;
  final String iconEmoji;
  final String colorHex;
  final Map<String, double> tagAffinities;

  const StrengthProfile({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.descriptionKey,
    required this.quietSkillPracticeKey,
    required this.keepsakeQuoteKey,
    required this.iconEmoji,
    required this.colorHex,
    required this.tagAffinities,
  });
}

/// Catalog for Echo's Strengths & Quiet Life Skills Lab (`strengths_life_skills_v1`).
class StrengthsLabCatalog {
  static const String strengthsLifeSkillsId = 'strengths_life_skills_v1';

  static const ExperienceDefinition definition = ExperienceDefinition(
    id: strengthsLifeSkillsId,
    version: 1,
    titleKey: 'exp_strengths_lab_title',
    subtitleKey: 'exp_strengths_lab_subtitle',
    primaryBird: 'echo',
    supportingBirds: [],
    grouping: DiscoverGrouping.discoverYourself,
    status: ExperienceCandidateStatus.referenceImplemented,
    questions: questions,
    hobbyProfiles: [],
  );

  static const List<StrengthProfile> profiles = [
    StrengthProfile(
      id: 'calm_anchor',
      titleKey: 'exp_strength_calm_anchor_title',
      subtitleKey: 'exp_strength_calm_anchor_sub',
      descriptionKey: 'exp_strength_calm_anchor_desc',
      quietSkillPracticeKey: 'exp_strength_calm_anchor_practice',
      keepsakeQuoteKey: 'exp_strength_calm_anchor_quote',
      iconEmoji: '⚓',
      colorHex: '#0EA5E9',
      tagAffinities: {
        'boundaries': 3.2,
        'calm': 3.0,
        'reset': 2.2,
        'clarity': 1.8,
      },
    ),
    StrengthProfile(
      id: 'patient_builder',
      titleKey: 'exp_strength_patient_builder_title',
      subtitleKey: 'exp_strength_patient_builder_sub',
      descriptionKey: 'exp_strength_patient_builder_desc',
      quietSkillPracticeKey: 'exp_strength_patient_builder_practice',
      keepsakeQuoteKey: 'exp_strength_patient_builder_quote',
      iconEmoji: '🧱',
      colorHex: '#10B981',
      tagAffinities: {
        'pacing': 3.2,
        'prioritize': 2.8,
        'reset': 2.4,
        'steady': 2.6,
      },
    ),
    StrengthProfile(
      id: 'thoughtful_listener',
      titleKey: 'exp_strength_thoughtful_listener_title',
      subtitleKey: 'exp_strength_thoughtful_listener_sub',
      descriptionKey: 'exp_strength_thoughtful_listener_desc',
      quietSkillPracticeKey: 'exp_strength_thoughtful_listener_practice',
      keepsakeQuoteKey: 'exp_strength_thoughtful_listener_quote',
      iconEmoji: '🌿',
      colorHex: '#8B5CF6',
      tagAffinities: {
        'empathy': 3.4,
        'calm': 2.4,
        'presence': 3.0,
        'boundaries': 1.6,
      },
    ),
    StrengthProfile(
      id: 'quiet_navigator',
      titleKey: 'exp_strength_quiet_navigator_title',
      subtitleKey: 'exp_strength_quiet_navigator_sub',
      descriptionKey: 'exp_strength_quiet_navigator_desc',
      quietSkillPracticeKey: 'exp_strength_quiet_navigator_practice',
      keepsakeQuoteKey: 'exp_strength_quiet_navigator_quote',
      iconEmoji: '🧭',
      colorHex: '#F59E0B',
      tagAffinities: {
        'clarity': 3.2,
        'prioritize': 3.0,
        'adaptable': 2.8,
        'boundaries': 2.2,
      },
    ),
  ];

  static const List<ExperienceQuestion> questions = [
    ExperienceQuestion(
      id: 'sl_boundary',
      titleKey: 'exp_sl_q_boundary',
      subtitleKey: 'exp_strengths_lab_subtitle',
      type: ExperienceQuestionType.singleChoice,
      options: [
        ExperienceOption(
          id: 'kind_no',
          labelKey: 'exp_sl_opt_kind_no',
          emoji: '🛡️',
          tagWeights: {'boundaries': 3.0, 'calm': 2.0, 'clarity': 1.5},
        ),
        ExperienceOption(
          id: 'scope_tradeoff',
          labelKey: 'exp_sl_opt_scope_tradeoff',
          emoji: '⚖️',
          tagWeights: {'prioritize': 2.8, 'clarity': 2.2, 'steady': 1.5},
        ),
        ExperienceOption(
          id: 'check_in_first',
          labelKey: 'exp_sl_opt_check_in_first',
          emoji: '💬',
          tagWeights: {'empathy': 2.8, 'presence': 2.2, 'calm': 1.4},
        ),
      ],
    ),
    ExperienceQuestion(
      id: 'sl_reset',
      titleKey: 'exp_sl_q_reset',
      subtitleKey: 'exp_strengths_lab_subtitle',
      type: ExperienceQuestionType.singleChoice,
      options: [
        ExperienceOption(
          id: 'unplugged_morning',
          labelKey: 'exp_sl_opt_unplugged_morning',
          emoji: '☕',
          tagWeights: {'reset': 3.0, 'calm': 2.6, 'boundaries': 1.8},
        ),
        ExperienceOption(
          id: 'gentle_tidy',
          labelKey: 'exp_sl_opt_gentle_tidy',
          emoji: '🧺',
          tagWeights: {'pacing': 2.8, 'steady': 2.4, 'reset': 2.0},
        ),
        ExperienceOption(
          id: 'walk_and_reflect',
          labelKey: 'exp_sl_opt_walk_and_reflect',
          emoji: '🚶',
          tagWeights: {'presence': 2.6, 'clarity': 2.4, 'reset': 2.0},
        ),
      ],
    ),
    ExperienceQuestion(
      id: 'sl_prioritize',
      titleKey: 'exp_sl_q_prioritize',
      subtitleKey: 'exp_strengths_lab_subtitle',
      type: ExperienceQuestionType.singleChoice,
      options: [
        ExperienceOption(
          id: 'one_anchor_task',
          labelKey: 'exp_sl_opt_one_anchor_task',
          emoji: '🎯',
          tagWeights: {'prioritize': 3.2, 'clarity': 2.4, 'pacing': 1.8},
        ),
        ExperienceOption(
          id: 'small_chunks',
          labelKey: 'exp_sl_opt_small_chunks',
          emoji: '🪜',
          tagWeights: {'steady': 3.0, 'pacing': 2.8, 'calm': 1.4},
        ),
        ExperienceOption(
          id: 'protect_personal_promise',
          labelKey: 'exp_sl_opt_protect_promise',
          emoji: '🌱',
          tagWeights: {'boundaries': 2.8, 'empathy': 2.0, 'calm': 2.2},
        ),
      ],
    ),
    ExperienceQuestion(
      id: 'sl_listening',
      titleKey: 'exp_sl_q_listening',
      subtitleKey: 'exp_strengths_lab_subtitle',
      type: ExperienceQuestionType.singleChoice,
      options: [
        ExperienceOption(
          id: 'hold_space',
          labelKey: 'exp_sl_opt_hold_space',
          emoji: '🫶',
          tagWeights: {'empathy': 3.2, 'presence': 3.0, 'calm': 1.8},
        ),
        ExperienceOption(
          id: 'ask_gentle_question',
          labelKey: 'exp_sl_opt_ask_gentle',
          emoji: '🔍',
          tagWeights: {'clarity': 2.6, 'empathy': 2.2, 'presence': 2.0},
        ),
        ExperienceOption(
          id: 'offer_steady_next_step',
          labelKey: 'exp_sl_opt_steady_next',
          emoji: '🤝',
          tagWeights: {'steady': 2.6, 'pacing': 2.2, 'calm': 2.0},
        ),
      ],
    ),
    ExperienceQuestion(
      id: 'sl_detour',
      titleKey: 'exp_sl_q_detour',
      subtitleKey: 'exp_strengths_lab_subtitle',
      type: ExperienceQuestionType.singleChoice,
      options: [
        ExperienceOption(
          id: 'breathe_and_reframe',
          labelKey: 'exp_sl_opt_breathe_reframe',
          emoji: '🌬️',
          tagWeights: {'calm': 3.0, 'adaptable': 2.6, 'boundaries': 1.5},
        ),
        ExperienceOption(
          id: 'pivot_plan_b',
          labelKey: 'exp_sl_opt_pivot_plan_b',
          emoji: '🗺️',
          tagWeights: {'adaptable': 3.2, 'clarity': 2.8, 'prioritize': 1.8},
        ),
        ExperienceOption(
          id: 'keep_one_small_win',
          labelKey: 'exp_sl_opt_small_win',
          emoji: '✨',
          tagWeights: {'pacing': 2.6, 'steady': 2.6, 'adaptable': 2.0},
        ),
      ],
    ),
  ];

  static StrengthProfile findById(String id) {
    return profiles.firstWhere(
      (p) => p.id == id,
      orElse: () => profiles.first,
    );
  }
}
