import 'interactive_experience_models.dart';
import 'saved_place.dart';

/// Time-window tiers supported by Scout's Weekend Generator (`weekend_generator_v1`).
enum WeekendTimeWindow {
  micro2h,
  halfDay,
  fullWeekend,
}

extension WeekendTimeWindowExt on WeekendTimeWindow {
  String get id {
    switch (this) {
      case WeekendTimeWindow.micro2h:
        return 'micro_2h';
      case WeekendTimeWindow.halfDay:
        return 'half_day';
      case WeekendTimeWindow.fullWeekend:
        return 'full_weekend';
    }
  }

  String get titleKey {
    switch (this) {
      case WeekendTimeWindow.micro2h:
        return 'wg_opt_time_micro';
      case WeekendTimeWindow.halfDay:
        return 'wg_opt_time_half';
      case WeekendTimeWindow.fullWeekend:
        return 'wg_opt_time_full';
    }
  }

  double get nominalHours {
    switch (this) {
      case WeekendTimeWindow.micro2h:
        return 2.0;
      case WeekendTimeWindow.halfDay:
        return 4.5;
      case WeekendTimeWindow.fullWeekend:
        return 8.0;
    }
  }
}

/// Curated offline micro-itinerary template matched deterministically by [InteractiveExperienceEngine].
class WeekendItineraryProfile {
  final String id;
  final String titleKey;
  final String categoryKey;
  final String descriptionKey;
  final String iconEmoji;
  final String colorHex;
  final Map<String, double> tagAffinities;
  final WeekendTimeWindow timeWindow;
  final double durationHours;
  final bool isOutdoor;
  final bool rainFriendly;
  final ExperienceBudgetTier budgetTier;
  final int estimatedPocketBudgetUsd;
  final int defaultStartHour;
  final int defaultStartMinute;
  final String suggestedPlaceNameKey;
  final PlaceCategory placeCategory;
  final List<String> checklistItemKeys;
  final List<String> timelineStepKeys;

  const WeekendItineraryProfile({
    required this.id,
    required this.titleKey,
    required this.categoryKey,
    required this.descriptionKey,
    required this.iconEmoji,
    required this.colorHex,
    required this.tagAffinities,
    required this.timeWindow,
    required this.durationHours,
    required this.isOutdoor,
    required this.rainFriendly,
    required this.budgetTier,
    required this.estimatedPocketBudgetUsd,
    required this.defaultStartHour,
    required this.defaultStartMinute,
    required this.suggestedPlaceNameKey,
    required this.placeCategory,
    required this.checklistItemKeys,
    required this.timelineStepKeys,
  });
}

/// Static catalog & 6-step questionnaire definition for Scout's Weekend Generator (`weekend_generator_v1`).
class WeekendGeneratorCatalog {
  WeekendGeneratorCatalog._();

  static const String weekendGeneratorId = 'weekend_generator_v1';

  static const ExperienceDefinition definition = ExperienceDefinition(
    id: weekendGeneratorId,
    version: 1,
    titleKey: 'wg_title',
    subtitleKey: 'wg_subtitle',
    primaryBird: 'Scout',
    supportingBirds: ['Roo', 'Twill', 'Pippin'],
    grouping: DiscoverGrouping.exploreTheWorld,
    status: ExperienceCandidateStatus.referenceImplemented,
    hobbyProfiles: [],
    questions: [
      ExperienceQuestion(
        id: 'wg_q_mood',
        titleKey: 'wg_q_mood_title',
        subtitleKey: 'wg_q_mood_sub',
        type: ExperienceQuestionType.singleChoice,
        options: [
          ExperienceOption(
            id: 'wg_opt_mood_outdoor',
            labelKey: 'wg_opt_mood_outdoor',
            emoji: '🌿',
            tagWeights: {
              'outdoor': 3.5,
              'nature': 3.0,
              'scenic': 2.5,
            },
          ),
          ExperienceOption(
            id: 'wg_opt_mood_cozy',
            labelKey: 'wg_opt_mood_cozy',
            emoji: '☕',
            tagWeights: {
              'cozy': 3.5,
              'calm': 3.0,
              'indoor': 2.0,
            },
          ),
          ExperienceOption(
            id: 'wg_opt_mood_creative',
            labelKey: 'wg_opt_mood_creative',
            emoji: '📷',
            tagWeights: {
              'creative': 3.5,
              'curious': 2.5,
              'scenic': 1.5,
            },
          ),
          ExperienceOption(
            id: 'wg_opt_mood_social',
            labelKey: 'wg_opt_mood_social',
            emoji: '🥐',
            tagWeights: {
              'social': 3.5,
              'local_flavor': 3.0,
            },
          ),
          ExperienceOption(
            id: 'wg_opt_mood_recovery',
            labelKey: 'wg_opt_mood_recovery',
            emoji: '🧘',
            tagWeights: {
              'recovery': 3.5,
              'calm': 3.0,
              'cozy': 2.0,
            },
          ),
        ],
      ),
      ExperienceQuestion(
        id: 'wg_q_energy',
        titleKey: 'wg_q_energy_title',
        subtitleKey: 'wg_q_energy_sub',
        type: ExperienceQuestionType.singleChoice,
        options: [
          ExperienceOption(
            id: 'wg_opt_energy_low',
            labelKey: 'wg_opt_energy_low',
            emoji: '🪴',
            tagWeights: {
              'calm': 3.0,
              'recovery': 2.5,
              'low_effort': 3.0,
            },
          ),
          ExperienceOption(
            id: 'wg_opt_energy_mid',
            labelKey: 'wg_opt_energy_mid',
            emoji: '🚶',
            tagWeights: {
              'moderate_pace': 2.5,
              'curious': 1.5,
              'local_flavor': 1.5,
            },
          ),
          ExperienceOption(
            id: 'wg_opt_energy_high',
            labelKey: 'wg_opt_energy_high',
            emoji: '🥾',
            tagWeights: {
              'active': 3.5,
              'outdoor': 2.5,
              'scenic': 2.0,
            },
          ),
        ],
      ),
      ExperienceQuestion(
        id: 'wg_q_time_window',
        titleKey: 'wg_q_time_title',
        subtitleKey: 'wg_q_time_sub',
        type: ExperienceQuestionType.singleChoice,
        options: [
          ExperienceOption(
            id: 'wg_opt_time_micro',
            labelKey: 'wg_opt_time_micro',
            emoji: '⏱️',
            tagWeights: {'short_escape': 2.0},
          ),
          ExperienceOption(
            id: 'wg_opt_time_half',
            labelKey: 'wg_opt_time_half',
            emoji: '🌤️',
            tagWeights: {'moderate_pace': 2.0},
          ),
          ExperienceOption(
            id: 'wg_opt_time_full',
            labelKey: 'wg_opt_time_full',
            emoji: '🏕️',
            tagWeights: {'immersive': 2.5, 'scenic': 1.5},
          ),
        ],
      ),
      ExperienceQuestion(
        id: 'wg_q_weather_pref',
        titleKey: 'wg_q_weather_pref_title',
        subtitleKey: 'wg_q_weather_pref_sub',
        type: ExperienceQuestionType.singleChoice,
        options: [
          ExperienceOption(
            id: 'wg_opt_pref_outdoor',
            labelKey: 'wg_opt_pref_outdoor',
            emoji: '☀️',
            tagWeights: {'outdoor': 3.0, 'nature': 2.0},
          ),
          ExperienceOption(
            id: 'wg_opt_pref_indoor',
            labelKey: 'wg_opt_pref_indoor',
            emoji: '🏛️',
            tagWeights: {'indoor': 3.5, 'cozy': 2.0},
          ),
          ExperienceOption(
            id: 'wg_opt_pref_adaptive',
            labelKey: 'wg_opt_pref_adaptive',
            emoji: '🌦️',
            tagWeights: {'flexible_setting': 2.0},
          ),
        ],
      ),
      ExperienceQuestion(
        id: 'wg_q_company',
        titleKey: 'wg_q_company_title',
        subtitleKey: 'wg_q_company_sub',
        type: ExperienceQuestionType.singleChoice,
        options: [
          ExperienceOption(
            id: 'wg_opt_comp_solo',
            labelKey: 'wg_opt_comp_solo',
            emoji: '🎧',
            tagWeights: {'solo': 3.0, 'calm': 1.5},
          ),
          ExperienceOption(
            id: 'wg_opt_comp_group',
            labelKey: 'wg_opt_comp_group',
            emoji: '🧺',
            tagWeights: {'social': 3.0, 'local_flavor': 1.5},
          ),
          ExperienceOption(
            id: 'wg_opt_comp_either',
            labelKey: 'wg_opt_comp_either',
            emoji: '🕊️',
            tagWeights: {'flexible_company': 1.5},
          ),
        ],
      ),
      ExperienceQuestion(
        id: 'wg_q_budget',
        titleKey: 'wg_q_budget_title',
        subtitleKey: 'wg_q_budget_sub',
        type: ExperienceQuestionType.singleChoice,
        options: [
          ExperienceOption(
            id: 'wg_opt_budget_zero',
            labelKey: 'wg_opt_budget_zero',
            emoji: '🌱',
            tagWeights: {'budget_zero': 2.0},
            budgetTier: ExperienceBudgetTier.low,
          ),
          ExperienceOption(
            id: 'wg_opt_budget_low',
            labelKey: 'wg_opt_budget_low',
            emoji: '🧋',
            tagWeights: {'budget_low': 2.0},
            budgetTier: ExperienceBudgetTier.low,
          ),
          ExperienceOption(
            id: 'wg_opt_budget_mid',
            labelKey: 'wg_opt_budget_mid',
            emoji: '🎟️',
            tagWeights: {'budget_mid': 2.0},
            budgetTier: ExperienceBudgetTier.mid,
          ),
          ExperienceOption(
            id: 'wg_opt_budget_high',
            labelKey: 'wg_opt_budget_high',
            emoji: '🚆',
            tagWeights: {'budget_high': 2.0},
            budgetTier: ExperienceBudgetTier.high,
          ),
        ],
      ),
    ],
  );

  static const List<WeekendItineraryProfile> itineraries = [
    WeekendItineraryProfile(
      id: 'botanical_dawn_stroll',
      titleKey: 'wg_it_botanical_title',
      categoryKey: 'wg_it_botanical_cat',
      descriptionKey: 'wg_it_botanical_desc',
      iconEmoji: '🌳',
      colorHex: '#10B981',
      tagAffinities: {
        'outdoor': 4.0,
        'nature': 4.0,
        'calm': 2.5,
        'recovery': 2.0,
        'solo': 2.5,
        'moderate_pace': 2.5,
        'short_escape': 2.5,
      },
      timeWindow: WeekendTimeWindow.micro2h,
      durationHours: 2.0,
      isOutdoor: true,
      rainFriendly: false,
      budgetTier: ExperienceBudgetTier.low,
      estimatedPocketBudgetUsd: 0,
      defaultStartHour: 7,
      defaultStartMinute: 30,
      suggestedPlaceNameKey: 'wg_it_botanical_place',
      placeCategory: PlaceCategory.custom,
      checklistItemKeys: [
        'wg_gear_water_bottle',
        'wg_gear_comfy_shoes',
        'wg_gear_sunscreen_cap',
        'wg_gear_notebook_pen',
      ],
      timelineStepKeys: [
        'wg_it_botanical_step1',
        'wg_it_botanical_step2',
        'wg_it_botanical_step3',
      ],
    ),
    WeekendItineraryProfile(
      id: 'sunny_park_picnic_sketch',
      titleKey: 'wg_it_picnic_title',
      categoryKey: 'wg_it_picnic_cat',
      descriptionKey: 'wg_it_picnic_desc',
      iconEmoji: '🧺',
      colorHex: '#F59E0B',
      tagAffinities: {
        'outdoor': 3.5,
        'nature': 2.5,
        'creative': 3.0,
        'social': 3.5,
        'local_flavor': 2.0,
        'moderate_pace': 2.5,
      },
      timeWindow: WeekendTimeWindow.halfDay,
      durationHours: 4.5,
      isOutdoor: true,
      rainFriendly: false,
      budgetTier: ExperienceBudgetTier.low,
      estimatedPocketBudgetUsd: 12,
      defaultStartHour: 10,
      defaultStartMinute: 0,
      suggestedPlaceNameKey: 'wg_it_picnic_place',
      placeCategory: PlaceCategory.custom,
      checklistItemKeys: [
        'wg_gear_picnic_mat',
        'wg_gear_thermos_snacks',
        'wg_gear_sketchbook',
        'wg_gear_wet_wipes',
      ],
      timelineStepKeys: [
        'wg_it_picnic_step1',
        'wg_it_picnic_step2',
        'wg_it_picnic_step3',
      ],
    ),
    WeekendItineraryProfile(
      id: 'coastal_cycle_picnic',
      titleKey: 'wg_it_cycle_title',
      categoryKey: 'wg_it_cycle_cat',
      descriptionKey: 'wg_it_cycle_desc',
      iconEmoji: '🚲',
      colorHex: '#0EA5E9',
      tagAffinities: {
        'outdoor': 4.0,
        'active': 4.0,
        'scenic': 3.5,
        'immersive': 2.0,
        'social': 2.0,
      },
      timeWindow: WeekendTimeWindow.halfDay,
      durationHours: 4.0,
      isOutdoor: true,
      rainFriendly: false,
      budgetTier: ExperienceBudgetTier.low,
      estimatedPocketBudgetUsd: 14,
      defaultStartHour: 6,
      defaultStartMinute: 45,
      suggestedPlaceNameKey: 'wg_it_cycle_place',
      placeCategory: PlaceCategory.custom,
      checklistItemKeys: [
        'wg_gear_helmet_lights',
        'wg_gear_water_bottle',
        'wg_gear_windbreaker',
        'wg_gear_powerbank',
      ],
      timelineStepKeys: [
        'wg_it_cycle_step1',
        'wg_it_cycle_step2',
        'wg_it_cycle_step3',
      ],
    ),
    WeekendItineraryProfile(
      id: 'neighborhood_cafe_book_crawl',
      titleKey: 'wg_it_cafebooks_title',
      categoryKey: 'wg_it_cafebooks_cat',
      descriptionKey: 'wg_it_cafebooks_desc',
      iconEmoji: '📚',
      colorHex: '#D97706',
      tagAffinities: {
        'cozy': 4.0,
        'indoor': 3.5,
        'calm': 3.0,
        'solo': 3.5,
        'creative': 2.0,
        'local_flavor': 2.0,
        'short_escape': 2.0,
      },
      timeWindow: WeekendTimeWindow.micro2h,
      durationHours: 2.5,
      isOutdoor: false,
      rainFriendly: true,
      budgetTier: ExperienceBudgetTier.low,
      estimatedPocketBudgetUsd: 12,
      defaultStartHour: 14,
      defaultStartMinute: 0,
      suggestedPlaceNameKey: 'wg_it_cafebooks_place',
      placeCategory: PlaceCategory.store,
      checklistItemKeys: [
        'wg_gear_current_book',
        'wg_gear_earbuds',
        'wg_gear_tote_bag',
        'wg_gear_compact_umbrella',
      ],
      timelineStepKeys: [
        'wg_it_cafebooks_step1',
        'wg_it_cafebooks_step2',
        'wg_it_cafebooks_step3',
      ],
    ),
    WeekendItineraryProfile(
      id: 'rainy_day_museum_drift',
      titleKey: 'wg_it_museum_title',
      categoryKey: 'wg_it_museum_cat',
      descriptionKey: 'wg_it_museum_desc',
      iconEmoji: '🏛️',
      colorHex: '#6366F1',
      tagAffinities: {
        'indoor': 4.0,
        'curious': 3.5,
        'creative': 3.0,
        'moderate_pace': 2.5,
        'solo': 2.0,
        'social': 2.0,
      },
      timeWindow: WeekendTimeWindow.halfDay,
      durationHours: 4.0,
      isOutdoor: false,
      rainFriendly: true,
      budgetTier: ExperienceBudgetTier.mid,
      estimatedPocketBudgetUsd: 25,
      defaultStartHour: 10,
      defaultStartMinute: 30,
      suggestedPlaceNameKey: 'wg_it_museum_place',
      placeCategory: PlaceCategory.custom,
      checklistItemKeys: [
        'wg_gear_comfy_shoes',
        'wg_gear_compact_umbrella',
        'wg_gear_notebook_pen',
        'wg_gear_light_cardigan',
      ],
      timelineStepKeys: [
        'wg_it_museum_step1',
        'wg_it_museum_step2',
        'wg_it_museum_step3',
      ],
    ),
    WeekendItineraryProfile(
      id: 'farmers_market_slow_kitchen',
      titleKey: 'wg_it_market_title',
      categoryKey: 'wg_it_market_cat',
      descriptionKey: 'wg_it_market_desc',
      iconEmoji: '🥐',
      colorHex: '#F97316',
      tagAffinities: {
        'social': 3.5,
        'local_flavor': 4.0,
        'cozy': 2.5,
        'creative': 2.0,
        'moderate_pace': 2.5,
      },
      timeWindow: WeekendTimeWindow.halfDay,
      durationHours: 4.5,
      isOutdoor: false,
      rainFriendly: true,
      budgetTier: ExperienceBudgetTier.mid,
      estimatedPocketBudgetUsd: 30,
      defaultStartHour: 8,
      defaultStartMinute: 0,
      suggestedPlaceNameKey: 'wg_it_market_place',
      placeCategory: PlaceCategory.store,
      checklistItemKeys: [
        'wg_gear_tote_bag',
        'wg_gear_cash_envelopes',
        'wg_gear_reusable_containers',
        'wg_gear_compact_umbrella',
      ],
      timelineStepKeys: [
        'wg_it_market_step1',
        'wg_it_market_step2',
        'wg_it_market_step3',
      ],
    ),
    WeekendItineraryProfile(
      id: 'analog_home_spa_sanctuary',
      titleKey: 'wg_it_homespa_title',
      categoryKey: 'wg_it_homespa_cat',
      descriptionKey: 'wg_it_homespa_desc',
      iconEmoji: '🕯️',
      colorHex: '#8B5CF6',
      tagAffinities: {
        'recovery': 4.0,
        'calm': 4.0,
        'cozy': 3.5,
        'indoor': 4.0,
        'low_effort': 3.5,
        'solo': 3.5,
        'short_escape': 2.0,
      },
      timeWindow: WeekendTimeWindow.micro2h,
      durationHours: 2.5,
      isOutdoor: false,
      rainFriendly: true,
      budgetTier: ExperienceBudgetTier.low,
      estimatedPocketBudgetUsd: 0,
      defaultStartHour: 16,
      defaultStartMinute: 0,
      suggestedPlaceNameKey: 'wg_it_homespa_place',
      placeCategory: PlaceCategory.home,
      checklistItemKeys: [
        'wg_gear_herbal_tea',
        'wg_gear_earbuds',
        'wg_gear_current_book',
        'wg_gear_warm_socks',
      ],
      timelineStepKeys: [
        'wg_it_homespa_step1',
        'wg_it_homespa_step2',
        'wg_it_homespa_step3',
      ],
    ),
    WeekendItineraryProfile(
      id: 'twilight_ridge_stargaze',
      titleKey: 'wg_it_stargaze_title',
      categoryKey: 'wg_it_stargaze_cat',
      descriptionKey: 'wg_it_stargaze_desc',
      iconEmoji: '🌌',
      colorHex: '#3B82F6',
      tagAffinities: {
        'outdoor': 3.5,
        'scenic': 4.0,
        'calm': 3.0,
        'nature': 3.5,
        'solo': 2.0,
        'social': 2.5,
      },
      timeWindow: WeekendTimeWindow.halfDay,
      durationHours: 3.5,
      isOutdoor: true,
      rainFriendly: false,
      budgetTier: ExperienceBudgetTier.low,
      estimatedPocketBudgetUsd: 10,
      defaultStartHour: 17,
      defaultStartMinute: 0,
      suggestedPlaceNameKey: 'wg_it_stargaze_place',
      placeCategory: PlaceCategory.custom,
      checklistItemKeys: [
        'wg_gear_warm_jacket',
        'wg_gear_flashlight',
        'wg_gear_thermos_snacks',
        'wg_gear_picnic_mat',
      ],
      timelineStepKeys: [
        'wg_it_stargaze_step1',
        'wg_it_stargaze_step2',
        'wg_it_stargaze_step3',
      ],
    ),
    WeekendItineraryProfile(
      id: 'indie_cinema_noodle_walk',
      titleKey: 'wg_it_cinema_title',
      categoryKey: 'wg_it_cinema_cat',
      descriptionKey: 'wg_it_cinema_desc',
      iconEmoji: '🎞️',
      colorHex: '#EC4899',
      tagAffinities: {
        'indoor': 3.5,
        'cozy': 3.0,
        'local_flavor': 3.0,
        'social': 3.0,
        'solo': 2.5,
        'low_effort': 2.0,
      },
      timeWindow: WeekendTimeWindow.halfDay,
      durationHours: 4.0,
      isOutdoor: false,
      rainFriendly: true,
      budgetTier: ExperienceBudgetTier.mid,
      estimatedPocketBudgetUsd: 24,
      defaultStartHour: 15,
      defaultStartMinute: 0,
      suggestedPlaceNameKey: 'wg_it_cinema_place',
      placeCategory: PlaceCategory.store,
      checklistItemKeys: [
        'wg_gear_light_cardigan',
        'wg_gear_compact_umbrella',
        'wg_gear_water_bottle',
        'wg_gear_powerbank',
      ],
      timelineStepKeys: [
        'wg_it_cinema_step1',
        'wg_it_cinema_step2',
        'wg_it_cinema_step3',
      ],
    ),
    WeekendItineraryProfile(
      id: 'sunset_heritage_photo_walk',
      titleKey: 'wg_it_photowalk_title',
      categoryKey: 'wg_it_photowalk_cat',
      descriptionKey: 'wg_it_photowalk_desc',
      iconEmoji: '📸',
      colorHex: '#14B8A6',
      tagAffinities: {
        'creative': 4.0,
        'curious': 3.0,
        'scenic': 3.0,
        'outdoor': 2.5,
        'solo': 2.5,
        'short_escape': 2.5,
      },
      timeWindow: WeekendTimeWindow.micro2h,
      durationHours: 2.5,
      isOutdoor: true,
      rainFriendly: true,
      budgetTier: ExperienceBudgetTier.low,
      estimatedPocketBudgetUsd: 0,
      defaultStartHour: 16,
      defaultStartMinute: 15,
      suggestedPlaceNameKey: 'wg_it_photowalk_place',
      placeCategory: PlaceCategory.custom,
      checklistItemKeys: [
        'wg_gear_camera_phone',
        'wg_gear_comfy_shoes',
        'wg_gear_powerbank',
        'wg_gear_compact_umbrella',
      ],
      timelineStepKeys: [
        'wg_it_photowalk_step1',
        'wg_it_photowalk_step2',
        'wg_it_photowalk_step3',
      ],
    ),
    WeekendItineraryProfile(
      id: 'boardgame_tea_salon',
      titleKey: 'wg_it_salon_title',
      categoryKey: 'wg_it_salon_cat',
      descriptionKey: 'wg_it_salon_desc',
      iconEmoji: '🎲',
      colorHex: '#E04A3A',
      tagAffinities: {
        'social': 4.0,
        'indoor': 4.0,
        'cozy': 3.0,
        'local_flavor': 2.5,
        'low_effort': 2.0,
      },
      timeWindow: WeekendTimeWindow.halfDay,
      durationHours: 4.0,
      isOutdoor: false,
      rainFriendly: true,
      budgetTier: ExperienceBudgetTier.low,
      estimatedPocketBudgetUsd: 15,
      defaultStartHour: 14,
      defaultStartMinute: 30,
      suggestedPlaceNameKey: 'wg_it_salon_place',
      placeCategory: PlaceCategory.home,
      checklistItemKeys: [
        'wg_gear_herbal_tea',
        'wg_gear_thermos_snacks',
        'wg_gear_notebook_pen',
        'wg_gear_warm_socks',
      ],
      timelineStepKeys: [
        'wg_it_salon_step1',
        'wg_it_salon_step2',
        'wg_it_salon_step3',
      ],
    ),
    WeekendItineraryProfile(
      id: 'full_weekend_nature_camp_loop',
      titleKey: 'wg_it_camp_title',
      categoryKey: 'wg_it_camp_cat',
      descriptionKey: 'wg_it_camp_desc',
      iconEmoji: '⛺',
      colorHex: '#059669',
      tagAffinities: {
        'outdoor': 4.0,
        'nature': 4.0,
        'active': 3.5,
        'scenic': 4.0,
        'immersive': 4.0,
        'social': 2.5,
        'recovery': 2.0,
      },
      timeWindow: WeekendTimeWindow.fullWeekend,
      durationHours: 8.0,
      isOutdoor: true,
      rainFriendly: false,
      budgetTier: ExperienceBudgetTier.high,
      estimatedPocketBudgetUsd: 55,
      defaultStartHour: 7,
      defaultStartMinute: 0,
      suggestedPlaceNameKey: 'wg_it_camp_place',
      placeCategory: PlaceCategory.custom,
      checklistItemKeys: [
        'wg_gear_warm_jacket',
        'wg_gear_flashlight',
        'wg_gear_comfy_shoes',
        'wg_gear_powerbank',
      ],
      timelineStepKeys: [
        'wg_it_camp_step1',
        'wg_it_camp_step2',
        'wg_it_camp_step3',
      ],
    ),
  ];

  static WeekendItineraryProfile? findById(String id) {
    for (final it in itineraries) {
      if (it.id == id) return it;
    }
    return null;
  }
}
