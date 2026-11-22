import 'interactive_experience_models.dart';

/// Four low-pressure creative mediums in Pippin's Daily Creative Prompt.
enum CreativePromptMedium {
  sketching,
  microPoetry,
  observationJournaling,
  shadowPhotography,
}

extension CreativePromptMediumExt on CreativePromptMedium {
  String get id => switch (this) {
        CreativePromptMedium.sketching => 'sketching',
        CreativePromptMedium.microPoetry => 'micro_poetry',
        CreativePromptMedium.observationJournaling => 'observation_journaling',
        CreativePromptMedium.shadowPhotography => 'shadow_photography',
      };

  String get titleKey => switch (this) {
        CreativePromptMedium.sketching => 'exp_dcp_med_sketching',
        CreativePromptMedium.microPoetry => 'exp_dcp_med_poetry',
        CreativePromptMedium.observationJournaling => 'exp_dcp_med_observation',
        CreativePromptMedium.shadowPhotography => 'exp_dcp_med_shadow_photo',
      };

  String get emoji => switch (this) {
        CreativePromptMedium.sketching => '✏️',
        CreativePromptMedium.microPoetry => '🪶',
        CreativePromptMedium.observationJournaling => '🔍',
        CreativePromptMedium.shadowPhotography => '📷',
      };

  String get colorHex => switch (this) {
        CreativePromptMedium.sketching => '#10B981',
        CreativePromptMedium.microPoetry => '#8B5CF6',
        CreativePromptMedium.observationJournaling => '#F59E0B',
        CreativePromptMedium.shadowPhotography => '#0EA5E9',
      };

  String get hobbyCategory => switch (this) {
        CreativePromptMedium.sketching => 'Art',
        CreativePromptMedium.microPoetry => 'Writing',
        CreativePromptMedium.observationJournaling => 'Writing',
        CreativePromptMedium.shadowPhotography => 'Art',
      };

  String get defaultHobbyNameKey => switch (this) {
        CreativePromptMedium.sketching => 'exp_dcp_hobby_sketching',
        CreativePromptMedium.microPoetry => 'exp_dcp_hobby_poetry',
        CreativePromptMedium.observationJournaling => 'exp_dcp_hobby_observation',
        CreativePromptMedium.shadowPhotography => 'exp_dcp_hobby_shadow_photo',
      };

  String get journalTag => switch (this) {
        CreativePromptMedium.sketching => 'Sketching',
        CreativePromptMedium.microPoetry => 'MicroPoetry',
        CreativePromptMedium.observationJournaling => 'Observation',
        CreativePromptMedium.shadowPhotography => 'ShadowPhoto',
      };
}

/// Single 10-minute low-pressure creative invitation.
class DailyCreativePromptItem {
  final String id;
  final CreativePromptMedium medium;
  final String titleKey;
  final String promptKey;
  final String gentleTipKey;
  final int suggestedDurationMinutes;

  const DailyCreativePromptItem({
    required this.id,
    required this.medium,
    required this.titleKey,
    required this.promptKey,
    required this.gentleTipKey,
    this.suggestedDurationMinutes = 10,
  });
}

/// Curated offline catalog for Pippin's Daily Creative Prompt (`daily_creative_prompt_v1`).
class DailyCreativePromptCatalog {
  static const String experienceId = 'daily_creative_prompt_v1';

  static const ExperienceDefinition definition = ExperienceDefinition(
    id: experienceId,
    version: 1,
    titleKey: 'exp_dcp_title',
    subtitleKey: 'exp_dcp_subtitle',
    primaryBird: 'pippin',
    supportingBirds: ['echo'],
    grouping: DiscoverGrouping.makeSomething,
    status: ExperienceCandidateStatus.referenceImplemented,
    questions: [],
    hobbyProfiles: [],
  );

  static const List<DailyCreativePromptItem> prompts = [
    // Sketching (3)
    DailyCreativePromptItem(
      id: 'dcp_sketch_1',
      medium: CreativePromptMedium.sketching,
      titleKey: 'exp_dcp_sketch_1_title',
      promptKey: 'exp_dcp_sketch_1_prompt',
      gentleTipKey: 'exp_dcp_sketch_1_tip',
    ),
    DailyCreativePromptItem(
      id: 'dcp_sketch_2',
      medium: CreativePromptMedium.sketching,
      titleKey: 'exp_dcp_sketch_2_title',
      promptKey: 'exp_dcp_sketch_2_prompt',
      gentleTipKey: 'exp_dcp_sketch_2_tip',
    ),
    DailyCreativePromptItem(
      id: 'dcp_sketch_3',
      medium: CreativePromptMedium.sketching,
      titleKey: 'exp_dcp_sketch_3_title',
      promptKey: 'exp_dcp_sketch_3_prompt',
      gentleTipKey: 'exp_dcp_sketch_3_tip',
    ),
    // Micro-Poetry (3)
    DailyCreativePromptItem(
      id: 'dcp_poetry_1',
      medium: CreativePromptMedium.microPoetry,
      titleKey: 'exp_dcp_poetry_1_title',
      promptKey: 'exp_dcp_poetry_1_prompt',
      gentleTipKey: 'exp_dcp_poetry_1_tip',
    ),
    DailyCreativePromptItem(
      id: 'dcp_poetry_2',
      medium: CreativePromptMedium.microPoetry,
      titleKey: 'exp_dcp_poetry_2_title',
      promptKey: 'exp_dcp_poetry_2_prompt',
      gentleTipKey: 'exp_dcp_poetry_2_tip',
    ),
    DailyCreativePromptItem(
      id: 'dcp_poetry_3',
      medium: CreativePromptMedium.microPoetry,
      titleKey: 'exp_dcp_poetry_3_title',
      promptKey: 'exp_dcp_poetry_3_prompt',
      gentleTipKey: 'exp_dcp_poetry_3_tip',
    ),
    // Observation Journaling (3)
    DailyCreativePromptItem(
      id: 'dcp_obs_1',
      medium: CreativePromptMedium.observationJournaling,
      titleKey: 'exp_dcp_obs_1_title',
      promptKey: 'exp_dcp_obs_1_prompt',
      gentleTipKey: 'exp_dcp_obs_1_tip',
    ),
    DailyCreativePromptItem(
      id: 'dcp_obs_2',
      medium: CreativePromptMedium.observationJournaling,
      titleKey: 'exp_dcp_obs_2_title',
      promptKey: 'exp_dcp_obs_2_prompt',
      gentleTipKey: 'exp_dcp_obs_2_tip',
    ),
    DailyCreativePromptItem(
      id: 'dcp_obs_3',
      medium: CreativePromptMedium.observationJournaling,
      titleKey: 'exp_dcp_obs_3_title',
      promptKey: 'exp_dcp_obs_3_prompt',
      gentleTipKey: 'exp_dcp_obs_3_tip',
    ),
    // Shadow Photography (3)
    DailyCreativePromptItem(
      id: 'dcp_shadow_1',
      medium: CreativePromptMedium.shadowPhotography,
      titleKey: 'exp_dcp_shadow_1_title',
      promptKey: 'exp_dcp_shadow_1_prompt',
      gentleTipKey: 'exp_dcp_shadow_1_tip',
    ),
    DailyCreativePromptItem(
      id: 'dcp_shadow_2',
      medium: CreativePromptMedium.shadowPhotography,
      titleKey: 'exp_dcp_shadow_2_title',
      promptKey: 'exp_dcp_shadow_2_prompt',
      gentleTipKey: 'exp_dcp_shadow_2_tip',
    ),
    DailyCreativePromptItem(
      id: 'dcp_shadow_3',
      medium: CreativePromptMedium.shadowPhotography,
      titleKey: 'exp_dcp_shadow_3_title',
      promptKey: 'exp_dcp_shadow_3_prompt',
      gentleTipKey: 'exp_dcp_shadow_3_tip',
    ),
  ];

  static List<DailyCreativePromptItem> promptsForMedium(
    CreativePromptMedium? medium,
  ) {
    if (medium == null) return prompts;
    return prompts.where((p) => p.medium == medium).toList();
  }

  /// Deterministically resolves the prompt of the day for [date].
  static DailyCreativePromptItem promptForDay(
    DateTime date, {
    CreativePromptMedium? medium,
  }) {
    final pool = promptsForMedium(medium);
    final dayEpoch = DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    final index = dayEpoch.abs() % pool.length;
    return pool[index];
  }

  static DailyCreativePromptItem nextPrompt(
    String currentId, {
    CreativePromptMedium? medium,
  }) {
    final pool = promptsForMedium(medium);
    final currentIdx = pool.indexWhere((p) => p.id == currentId);
    if (currentIdx == -1) return pool.first;
    return pool[(currentIdx + 1) % pool.length];
  }

  static DailyCreativePromptItem? findById(String id) {
    for (final p in prompts) {
      if (p.id == id) return p;
    }
    return null;
  }
}
