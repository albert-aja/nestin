import 'bucket_list_item.dart';
import 'interactive_experience_models.dart';

/// Curiosity spark profile uncovered by Pippin's Interest Explorer
/// (`interest_explorer_v1`) with data for 1-tap Bucket List, Reading Queue,
/// and Hobby + Twill "Start Something New" starter kit handoffs.
class InterestSparkProfile {
  final String id;
  final String titleKey;
  final String subtitleKey;
  final String descriptionKey;
  final String iconEmoji;
  final String colorHex;
  final Map<String, double> tagAffinities;

  // 1. Pippin Bucket List Dream Handoff
  final String bucketTitleKey;
  final String bucketNoteKey;
  final BucketCategory bucketCategory;
  final BucketTargetSeason bucketSeason;

  // 2. Pippin Reading Queue Handoff
  final String bookTitleKey;
  final String bookAuthor;
  final String bookCategory;
  final int bookPages;
  final String bookNoteKey;

  // 3. Pippin Hobby + Twill "Start Something New" Starter Kit Handoff
  final String hobbyTitleKey;
  final String hobbyCategory;
  final int recommendedTargetHours;
  final List<String> starterChecklistItemKeys;

  const InterestSparkProfile({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.descriptionKey,
    required this.iconEmoji,
    required this.colorHex,
    required this.tagAffinities,
    required this.bucketTitleKey,
    required this.bucketNoteKey,
    required this.bucketCategory,
    required this.bucketSeason,
    required this.bookTitleKey,
    required this.bookAuthor,
    required this.bookCategory,
    required this.bookPages,
    required this.bookNoteKey,
    required this.hobbyTitleKey,
    required this.hobbyCategory,
    required this.recommendedTargetHours,
    required this.starterChecklistItemKeys,
  });
}

/// Catalog for Pippin's Interest Explorer ("This or That" Scenarios, `interest_explorer_v1`).
class InterestExplorerCatalog {
  static const String interestExplorerId = 'interest_explorer_v1';

  static const ExperienceDefinition definition = ExperienceDefinition(
    id: interestExplorerId,
    version: 1,
    titleKey: 'exp_ie_title',
    subtitleKey: 'exp_ie_subtitle',
    primaryBird: 'pippin',
    supportingBirds: ['twill'],
    grouping: DiscoverGrouping.discoverYourself,
    status: ExperienceCandidateStatus.referenceImplemented,
    questions: questions,
    hobbyProfiles: [],
  );

  static const List<InterestSparkProfile> profiles = [
    InterestSparkProfile(
      id: 'cartography_slow_atlas',
      titleKey: 'exp_ie_prof_atlas_title',
      subtitleKey: 'exp_ie_prof_atlas_sub',
      descriptionKey: 'exp_ie_prof_atlas_desc',
      iconEmoji: '🗺️',
      colorHex: '#0EA5E9',
      tagAffinities: {
        'cartography': 3.5,
        'reading': 3.0,
        'observational': 2.4,
        'artisan_ritual': 1.8,
      },
      bucketTitleKey: 'exp_ie_prof_atlas_bucket_title',
      bucketNoteKey: 'exp_ie_prof_atlas_bucket_note',
      bucketCategory: BucketCategory.cultureLearning,
      bucketSeason: BucketTargetSeason.autumn,
      bookTitleKey: 'exp_ie_prof_atlas_book_title',
      bookAuthor: 'Judith Schalansky',
      bookCategory: 'Geography & Lore',
      bookPages: 240,
      bookNoteKey: 'exp_ie_prof_atlas_book_note',
      hobbyTitleKey: 'exp_ie_prof_atlas_hobby_title',
      hobbyCategory: 'Art',
      recommendedTargetHours: 25,
      starterChecklistItemKeys: [
        'exp_ie_prof_atlas_kit_1',
        'exp_ie_prof_atlas_kit_2',
        'exp_ie_prof_atlas_kit_3',
        'exp_ie_prof_atlas_kit_4',
      ],
    ),
    InterestSparkProfile(
      id: 'acoustic_tactile_studio',
      titleKey: 'exp_ie_prof_acoustic_title',
      subtitleKey: 'exp_ie_prof_acoustic_sub',
      descriptionKey: 'exp_ie_prof_acoustic_desc',
      iconEmoji: '🎸',
      colorHex: '#8B5CF6',
      tagAffinities: {
        'acoustic_craft': 3.6,
        'tactile_studio': 3.0,
        'rhythmic': 2.6,
      },
      bucketTitleKey: 'exp_ie_prof_acoustic_bucket_title',
      bucketNoteKey: 'exp_ie_prof_acoustic_bucket_note',
      bucketCategory: BucketCategory.creativeMilestones,
      bucketSeason: BucketTargetSeason.anytime,
      bookTitleKey: 'exp_ie_prof_acoustic_book_title',
      bookAuthor: 'Rick Rubin',
      bookCategory: 'Creativity & Craft',
      bookPages: 320,
      bookNoteKey: 'exp_ie_prof_acoustic_book_note',
      hobbyTitleKey: 'exp_ie_prof_acoustic_hobby_title',
      hobbyCategory: 'Music',
      recommendedTargetHours: 40,
      starterChecklistItemKeys: [
        'exp_ie_prof_acoustic_kit_1',
        'exp_ie_prof_acoustic_kit_2',
        'exp_ie_prof_acoustic_kit_3',
        'exp_ie_prof_acoustic_kit_4',
      ],
    ),
    InterestSparkProfile(
      id: 'botanical_naturalist',
      titleKey: 'exp_ie_prof_botanical_title',
      subtitleKey: 'exp_ie_prof_botanical_sub',
      descriptionKey: 'exp_ie_prof_botanical_desc',
      iconEmoji: '🌿',
      colorHex: '#10B981',
      tagAffinities: {
        'botanical': 3.6,
        'observational': 2.8,
        'tactile_studio': 2.2,
      },
      bucketTitleKey: 'exp_ie_prof_botanical_bucket_title',
      bucketNoteKey: 'exp_ie_prof_botanical_bucket_note',
      bucketCategory: BucketCategory.natureOutdoors,
      bucketSeason: BucketTargetSeason.spring,
      bookTitleKey: 'exp_ie_prof_botanical_book_title',
      bookAuthor: 'Robin Wall Kimmerer',
      bookCategory: 'Nature & Botany',
      bookPages: 390,
      bookNoteKey: 'exp_ie_prof_botanical_book_note',
      hobbyTitleKey: 'exp_ie_prof_botanical_hobby_title',
      hobbyCategory: 'Craft',
      recommendedTargetHours: 25,
      starterChecklistItemKeys: [
        'exp_ie_prof_botanical_kit_1',
        'exp_ie_prof_botanical_kit_2',
        'exp_ie_prof_botanical_kit_3',
        'exp_ie_prof_botanical_kit_4',
      ],
    ),
    InterestSparkProfile(
      id: 'artisan_tea_ink_ritual',
      titleKey: 'exp_ie_prof_artisan_title',
      subtitleKey: 'exp_ie_prof_artisan_sub',
      descriptionKey: 'exp_ie_prof_artisan_desc',
      iconEmoji: '🍵',
      colorHex: '#F59E0B',
      tagAffinities: {
        'artisan_ritual': 3.6,
        'tactile_studio': 2.6,
        'reading': 2.2,
        'sensory': 2.4,
      },
      bucketTitleKey: 'exp_ie_prof_artisan_bucket_title',
      bucketNoteKey: 'exp_ie_prof_artisan_bucket_note',
      bucketCategory: BucketCategory.cafesFood,
      bucketSeason: BucketTargetSeason.anytime,
      bookTitleKey: 'exp_ie_prof_artisan_book_title',
      bookAuthor: 'Kakuzo Okakura',
      bookCategory: 'Philosophy & Ritual',
      bookPages: 160,
      bookNoteKey: 'exp_ie_prof_artisan_book_note',
      hobbyTitleKey: 'exp_ie_prof_artisan_hobby_title',
      hobbyCategory: 'Writing',
      recommendedTargetHours: 20,
      starterChecklistItemKeys: [
        'exp_ie_prof_artisan_kit_1',
        'exp_ie_prof_artisan_kit_2',
        'exp_ie_prof_artisan_kit_3',
        'exp_ie_prof_artisan_kit_4',
      ],
    ),
  ];

  static const List<ExperienceQuestion> questions = [
    ExperienceQuestion(
      id: 'ie_rainy_afternoon',
      titleKey: 'exp_ie_q_rainy_afternoon',
      subtitleKey: 'exp_ie_this_or_that_badge',
      type: ExperienceQuestionType.singleChoice,
      options: [
        ExperienceOption(
          id: 'brew_tea_atlas',
          labelKey: 'exp_ie_opt_brew_tea_atlas',
          emoji: '🍵',
          tagWeights: {
            'cartography': 3.2,
            'artisan_ritual': 2.8,
            'reading': 2.4,
          },
        ),
        ExperienceOption(
          id: 'fingerstyle_chords',
          labelKey: 'exp_ie_opt_fingerstyle_chords',
          emoji: '🎸',
          tagWeights: {
            'acoustic_craft': 3.4,
            'tactile_studio': 2.6,
            'rhythmic': 2.2,
          },
        ),
      ],
    ),
    ExperienceQuestion(
      id: 'ie_golden_hour',
      titleKey: 'exp_ie_q_golden_hour',
      subtitleKey: 'exp_ie_this_or_that_badge',
      type: ExperienceQuestionType.singleChoice,
      options: [
        ExperienceOption(
          id: 'botanical_pressing',
          labelKey: 'exp_ie_opt_botanical_pressing',
          emoji: '🌿',
          tagWeights: {
            'botanical': 3.4,
            'tactile_studio': 2.2,
            'observational': 2.2,
          },
        ),
        ExperienceOption(
          id: 'film_walk_shadows',
          labelKey: 'exp_ie_opt_film_walk_shadows',
          emoji: '📷',
          tagWeights: {
            'observational': 3.2,
            'cartography': 2.6,
          },
        ),
      ],
    ),
    ExperienceQuestion(
      id: 'ie_cozy_desk',
      titleKey: 'exp_ie_q_cozy_desk',
      subtitleKey: 'exp_ie_this_or_that_badge',
      type: ExperienceQuestionType.singleChoice,
      options: [
        ExperienceOption(
          id: 'fountain_pen_ink',
          labelKey: 'exp_ie_opt_fountain_pen_ink',
          emoji: '🖋️',
          tagWeights: {
            'artisan_ritual': 3.0,
            'tactile_studio': 2.8,
            'reading': 2.4,
          },
        ),
        ExperienceOption(
          id: 'pour_over_roast',
          labelKey: 'exp_ie_opt_pour_over_roast',
          emoji: '☕',
          tagWeights: {
            'artisan_ritual': 3.4,
            'sensory': 2.6,
            'botanical': 1.8,
          },
        ),
      ],
    ),
    ExperienceQuestion(
      id: 'ie_night_sky',
      titleKey: 'exp_ie_q_night_sky',
      subtitleKey: 'exp_ie_this_or_that_badge',
      type: ExperienceQuestionType.singleChoice,
      options: [
        ExperienceOption(
          id: 'stargazing_constellations',
          labelKey: 'exp_ie_opt_stargazing_constellations',
          emoji: '🔭',
          tagWeights: {
            'cartography': 3.0,
            'observational': 3.2,
            'botanical': 1.8,
          },
        ),
        ExperienceOption(
          id: 'woodblock_origami',
          labelKey: 'exp_ie_opt_woodblock_origami',
          emoji: '🪵',
          tagWeights: {
            'tactile_studio': 3.4,
            'acoustic_craft': 2.4,
            'rhythmic': 2.0,
          },
        ),
      ],
    ),
    ExperienceQuestion(
      id: 'ie_saturday_detour',
      titleKey: 'exp_ie_q_saturday_detour',
      subtitleKey: 'exp_ie_this_or_that_badge',
      type: ExperienceQuestionType.singleChoice,
      options: [
        ExperienceOption(
          id: 'secondhand_bookshop',
          labelKey: 'exp_ie_opt_secondhand_bookshop',
          emoji: '📚',
          tagWeights: {
            'reading': 3.4,
            'cartography': 3.0,
            'observational': 1.8,
          },
        ),
        ExperienceOption(
          id: 'ceramic_luthiery_workshop',
          labelKey: 'exp_ie_opt_ceramic_luthiery_workshop',
          emoji: '🏺',
          tagWeights: {
            'acoustic_craft': 3.2,
            'tactile_studio': 3.0,
            'artisan_ritual': 2.2,
          },
        ),
      ],
    ),
  ];

  static InterestSparkProfile findById(String id) {
    return profiles.firstWhere(
      (p) => p.id == id,
      orElse: () => profiles.first,
    );
  }
}
