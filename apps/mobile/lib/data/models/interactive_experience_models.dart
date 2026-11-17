import 'package:uuid/uuid.dart';
import 'book_matcher_catalog.dart';
import 'weekend_generator_catalog.dart';
export 'book_matcher_catalog.dart';
export 'weekend_generator_catalog.dart';

/// Conceptual groupings in Nestin Discover (Section 7 of Interactive Experiences Blueprint).
enum DiscoverGrouping {
  discoverYourself,
  exploreTheWorld,
  learnSomething,
  makeSomething,
}

extension DiscoverGroupingExt on DiscoverGrouping {
  String get titleKey {
    switch (this) {
      case DiscoverGrouping.discoverYourself:
        return 'exp_group_discover_yourself';
      case DiscoverGrouping.exploreTheWorld:
        return 'exp_group_explore_world';
      case DiscoverGrouping.learnSomething:
        return 'exp_group_learn_something';
      case DiscoverGrouping.makeSomething:
        return 'exp_group_make_something';
    }
  }

  String get descriptionKey {
    switch (this) {
      case DiscoverGrouping.discoverYourself:
        return 'exp_group_discover_yourself_desc';
      case DiscoverGrouping.exploreTheWorld:
        return 'exp_group_explore_world_desc';
      case DiscoverGrouping.learnSomething:
        return 'exp_group_learn_something_desc';
      case DiscoverGrouping.makeSomething:
        return 'exp_group_make_something_desc';
    }
  }

  String get iconEmoji {
    switch (this) {
      case DiscoverGrouping.discoverYourself:
        return '🧭';
      case DiscoverGrouping.exploreTheWorld:
        return '🌍';
      case DiscoverGrouping.learnSomething:
        return '🦉';
      case DiscoverGrouping.makeSomething:
        return '🎨';
    }
  }
}

/// Lifecycle & product-audit classification for interactive experience candidates.
enum ExperienceCandidateStatus {
  referenceImplemented,
  priorityCandidate,
  exploratoryCandidate,
  integratedPractical,
  deferredOrRejected,
}

extension ExperienceCandidateStatusExt on ExperienceCandidateStatus {
  String get badgeKey {
    switch (this) {
      case ExperienceCandidateStatus.referenceImplemented:
        return 'exp_status_reference_live';
      case ExperienceCandidateStatus.priorityCandidate:
        return 'exp_status_priority_backlog';
      case ExperienceCandidateStatus.exploratoryCandidate:
        return 'exp_status_exploratory_backlog';
      case ExperienceCandidateStatus.integratedPractical:
        return 'exp_status_integrated_practical';
      case ExperienceCandidateStatus.deferredOrRejected:
        return 'exp_optional_tag';
    }
  }
}

/// Supported deterministic question types in the Shared Questionnaire Engine.
enum ExperienceQuestionType {
  singleChoice,
  multipleChoice,
  ranking,
  slider,
  visualSelection,
  numericInput,
}

enum ExperienceBudgetTier {
  low,
  mid,
  high,
}

enum ExperienceEnvironmentType {
  cozyDesk,
  kitchenStudio,
  outdoorRoam,
}

class ExperienceOption {
  final String id;
  final String labelKey;
  final String emoji;
  final Map<String, double> tagWeights;
  final ExperienceBudgetTier? budgetTier;
  final ExperienceEnvironmentType? environmentType;

  const ExperienceOption({
    required this.id,
    required this.labelKey,
    required this.emoji,
    this.tagWeights = const {},
    this.budgetTier,
    this.environmentType,
  });
}

class ExperienceQuestion {
  final String id;
  final String titleKey;
  final String subtitleKey;
  final ExperienceQuestionType type;
  final List<ExperienceOption> options;
  final int maxSelections;
  final double minValue;
  final double maxValue;
  final double defaultValue;
  final bool isOptional;
  final String? showIfQuestionId;
  final List<String> showIfOptionIds;

  const ExperienceQuestion({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.type,
    this.options = const [],
    this.maxSelections = 1,
    this.minValue = 1.0,
    this.maxValue = 10.0,
    this.defaultValue = 3.0,
    this.isOptional = false,
    this.showIfQuestionId,
    this.showIfOptionIds = const [],
  });
}

/// Rich outcome profile for Pippin's Hobby Finder with connected multi-bird handoff data.
class HobbyRecommendationProfile {
  final String id;
  final String titleKey;
  final String categoryKey;
  final String descriptionKey;
  final String whyItFitsKey;
  final String iconEmoji;
  final String colorHex;
  final Map<String, double> tagAffinities;
  final double minHoursPerWeek;
  final int recommendedTargetHours;
  final ExperienceBudgetTier budgetTier;
  final int estimatedStarterCostUsd;
  final List<ExperienceEnvironmentType> preferredEnvironments;
  final List<String> starterChecklistItems;
  final String firstSessionTaskTitle;
  final String pairedSerenSoundId;

  const HobbyRecommendationProfile({
    required this.id,
    required this.titleKey,
    required this.categoryKey,
    required this.descriptionKey,
    required this.whyItFitsKey,
    required this.iconEmoji,
    required this.colorHex,
    required this.tagAffinities,
    required this.minHoursPerWeek,
    required this.recommendedTargetHours,
    required this.budgetTier,
    required this.estimatedStarterCostUsd,
    required this.preferredEnvironments,
    required this.starterChecklistItems,
    required this.firstSessionTaskTitle,
    required this.pairedSerenSoundId,
  });
}

/// 10-Criteria Evaluation Record from Section 3 of the Interactive Experiences Blueprint.
class ExperienceCandidateAudit {
  final String id;
  final String titleKey;
  final String descriptionKey;
  final String iconEmoji;
  final String primaryBird;
  final List<String> supportingBirds;
  final DiscoverGrouping grouping;
  final ExperienceCandidateStatus status;
  final List<String> reusedNestinModules;
  final List<String> followUpActionsCreated;
  final bool deterministicWithoutAi;

  const ExperienceCandidateAudit({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.iconEmoji,
    required this.primaryBird,
    required this.supportingBirds,
    required this.grouping,
    required this.status,
    required this.reusedNestinModules,
    required this.followUpActionsCreated,
    this.deterministicWithoutAi = true,
  });
}

class ExperienceDefinition {
  final String id;
  final int version;
  final String titleKey;
  final String subtitleKey;
  final String primaryBird;
  final List<String> supportingBirds;
  final DiscoverGrouping grouping;
  final ExperienceCandidateStatus status;
  final List<ExperienceQuestion> questions;
  final List<HobbyRecommendationProfile> hobbyProfiles;

  const ExperienceDefinition({
    required this.id,
    required this.version,
    required this.titleKey,
    required this.subtitleKey,
    required this.primaryBird,
    required this.supportingBirds,
    required this.grouping,
    required this.status,
    required this.questions,
    required this.hobbyProfiles,
  });
}

/// Persisted draft state so users can pause and resume an interactive session at any time.
class ExperienceSessionDraft {
  final String experienceId;
  final int definitionVersion;
  final int currentQuestionIndex;
  final Map<String, List<String>> selectedOptionIdsByQuestion;
  final Map<String, double> numericValueByQuestion;
  final List<String> skippedQuestionIds;
  final DateTime startedAt;
  final DateTime updatedAt;

  const ExperienceSessionDraft({
    required this.experienceId,
    required this.definitionVersion,
    this.currentQuestionIndex = 0,
    this.selectedOptionIdsByQuestion = const {},
    this.numericValueByQuestion = const {},
    this.skippedQuestionIds = const [],
    required this.startedAt,
    required this.updatedAt,
  });

  int get answeredCount =>
      selectedOptionIdsByQuestion.entries
          .where((e) => e.value.isNotEmpty)
          .length +
      numericValueByQuestion.length;

  ExperienceSessionDraft copyWith({
    int? currentQuestionIndex,
    Map<String, List<String>>? selectedOptionIdsByQuestion,
    Map<String, double>? numericValueByQuestion,
    List<String>? skippedQuestionIds,
    DateTime? updatedAt,
  }) {
    return ExperienceSessionDraft(
      experienceId: experienceId,
      definitionVersion: definitionVersion,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      selectedOptionIdsByQuestion:
          selectedOptionIdsByQuestion ?? this.selectedOptionIdsByQuestion,
      numericValueByQuestion:
          numericValueByQuestion ?? this.numericValueByQuestion,
      skippedQuestionIds: skippedQuestionIds ?? this.skippedQuestionIds,
      startedAt: startedAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'experienceId': experienceId,
        'definitionVersion': definitionVersion,
        'currentQuestionIndex': currentQuestionIndex,
        'selectedOptionIdsByQuestion': selectedOptionIdsByQuestion,
        'numericValueByQuestion': numericValueByQuestion,
        'skippedQuestionIds': skippedQuestionIds,
        'startedAt': startedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ExperienceSessionDraft.fromJson(Map<String, dynamic> json) {
    final rawSelected =
        json['selectedOptionIdsByQuestion'] as Map<String, dynamic>? ?? {};
    final parsedSelected = <String, List<String>>{};
    rawSelected.forEach((key, value) {
      if (value is List) {
        parsedSelected[key] = value.map((e) => e.toString()).toList();
      }
    });

    final rawNumeric =
        json['numericValueByQuestion'] as Map<String, dynamic>? ?? {};
    final parsedNumeric = <String, double>{};
    rawNumeric.forEach((key, value) {
      if (value is num) {
        parsedNumeric[key] = value.toDouble();
      }
    });

    return ExperienceSessionDraft(
      experienceId: json['experienceId'] as String? ?? 'hobby_finder_v1',
      definitionVersion: (json['definitionVersion'] as num?)?.toInt() ?? 1,
      currentQuestionIndex:
          (json['currentQuestionIndex'] as num?)?.toInt() ?? 0,
      selectedOptionIdsByQuestion: parsedSelected,
      numericValueByQuestion: parsedNumeric,
      skippedQuestionIds: (json['skippedQuestionIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Explainable scored recommendation output for a single matched profile.
class ExperienceMatchedOutcome {
  final String profileId;
  final int matchPercentage;
  final double rawScore;
  final List<String> reasonKeys;
  final Map<String, Map<String, dynamic>> reasonParamsByKey;

  const ExperienceMatchedOutcome({
    required this.profileId,
    required this.matchPercentage,
    required this.rawScore,
    required this.reasonKeys,
    this.reasonParamsByKey = const {},
  });

  Map<String, dynamic> toJson() => {
        'profileId': profileId,
        'matchPercentage': matchPercentage,
        'rawScore': rawScore,
        'reasonKeys': reasonKeys,
        'reasonParamsByKey': reasonParamsByKey,
      };

  factory ExperienceMatchedOutcome.fromJson(Map<String, dynamic> json) {
    final rawParams =
        json['reasonParamsByKey'] as Map<String, dynamic>? ?? const {};
    final parsedParams = <String, Map<String, dynamic>>{};
    rawParams.forEach((k, v) {
      if (v is Map) {
        parsedParams[k] = Map<String, dynamic>.from(v);
      }
    });

    return ExperienceMatchedOutcome(
      profileId: json['profileId'] as String? ?? '',
      matchPercentage: (json['matchPercentage'] as num?)?.toInt() ?? 80,
      rawScore: (json['rawScore'] as num?)?.toDouble() ?? 0.0,
      reasonKeys: (json['reasonKeys'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      reasonParamsByKey: parsedParams,
    );
  }
}

/// Version-pinned completed experience result record so updates to definitions
/// never corrupt historical user results.
class ExperienceResultRecord {
  final String id;
  final String experienceId;
  final int definitionVersion;
  final DateTime completedAt;
  final List<ExperienceMatchedOutcome> topMatches;
  final Map<String, dynamic> answersSnapshot;
  final String? addedToPippinHobbyId;
  final String? addedToPippinBookId;
  final String? createdTwillChecklistId;
  final String? createdTwillWishlistId;
  final String? createdRooTaskId;
  final String? createdRooRoutineId;
  final String? playedSerenSoundId;
  final String? createdScoutPresetId;
  final String? createdScoutPlaceId;
  final String? createdRooCalendarEventId;
  final String? createdTwillBudgetId;

  ExperienceResultRecord({
    String? id,
    required this.experienceId,
    required this.definitionVersion,
    DateTime? completedAt,
    required this.topMatches,
    this.answersSnapshot = const {},
    this.addedToPippinHobbyId,
    this.addedToPippinBookId,
    this.createdTwillChecklistId,
    this.createdTwillWishlistId,
    this.createdRooTaskId,
    this.createdRooRoutineId,
    this.playedSerenSoundId,
    this.createdScoutPresetId,
    this.createdScoutPlaceId,
    this.createdRooCalendarEventId,
    this.createdTwillBudgetId,
  })  : id = id ?? const Uuid().v4(),
        completedAt = completedAt ?? DateTime.now();

  ExperienceResultRecord copyWith({
    String? addedToPippinHobbyId,
    String? addedToPippinBookId,
    String? createdTwillChecklistId,
    String? createdTwillWishlistId,
    String? createdRooTaskId,
    String? createdRooRoutineId,
    String? playedSerenSoundId,
    String? createdScoutPresetId,
    String? createdScoutPlaceId,
    String? createdRooCalendarEventId,
    String? createdTwillBudgetId,
  }) {
    return ExperienceResultRecord(
      id: id,
      experienceId: experienceId,
      definitionVersion: definitionVersion,
      completedAt: completedAt,
      topMatches: topMatches,
      answersSnapshot: answersSnapshot,
      addedToPippinHobbyId: addedToPippinHobbyId ?? this.addedToPippinHobbyId,
      addedToPippinBookId: addedToPippinBookId ?? this.addedToPippinBookId,
      createdTwillChecklistId:
          createdTwillChecklistId ?? this.createdTwillChecklistId,
      createdTwillWishlistId:
          createdTwillWishlistId ?? this.createdTwillWishlistId,
      createdRooTaskId: createdRooTaskId ?? this.createdRooTaskId,
      createdRooRoutineId: createdRooRoutineId ?? this.createdRooRoutineId,
      playedSerenSoundId: playedSerenSoundId ?? this.playedSerenSoundId,
      createdScoutPresetId: createdScoutPresetId ?? this.createdScoutPresetId,
      createdScoutPlaceId: createdScoutPlaceId ?? this.createdScoutPlaceId,
      createdRooCalendarEventId:
          createdRooCalendarEventId ?? this.createdRooCalendarEventId,
      createdTwillBudgetId: createdTwillBudgetId ?? this.createdTwillBudgetId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'experienceId': experienceId,
        'definitionVersion': definitionVersion,
        'completedAt': completedAt.toIso8601String(),
        'topMatches': topMatches.map((m) => m.toJson()).toList(),
        'answersSnapshot': answersSnapshot,
        'addedToPippinHobbyId': addedToPippinHobbyId,
        'addedToPippinBookId': addedToPippinBookId,
        'createdTwillChecklistId': createdTwillChecklistId,
        'createdTwillWishlistId': createdTwillWishlistId,
        'createdRooTaskId': createdRooTaskId,
        'createdRooRoutineId': createdRooRoutineId,
        'playedSerenSoundId': playedSerenSoundId,
        'createdScoutPresetId': createdScoutPresetId,
        'createdScoutPlaceId': createdScoutPlaceId,
        'createdRooCalendarEventId': createdRooCalendarEventId,
        'createdTwillBudgetId': createdTwillBudgetId,
      };

  factory ExperienceResultRecord.fromJson(Map<String, dynamic> json) {
    return ExperienceResultRecord(
      id: json['id'] as String?,
      experienceId: json['experienceId'] as String? ?? 'hobby_finder_v1',
      definitionVersion: (json['definitionVersion'] as num?)?.toInt() ?? 1,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      topMatches: (json['topMatches'] as List?)
              ?.map((e) => ExperienceMatchedOutcome.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      answersSnapshot: json['answersSnapshot'] is Map
          ? Map<String, dynamic>.from(json['answersSnapshot'] as Map)
          : const {},
      addedToPippinHobbyId: json['addedToPippinHobbyId'] as String?,
      addedToPippinBookId: json['addedToPippinBookId'] as String?,
      createdTwillChecklistId: json['createdTwillChecklistId'] as String?,
      createdTwillWishlistId: json['createdTwillWishlistId'] as String?,
      createdRooTaskId: json['createdRooTaskId'] as String?,
      createdRooRoutineId: json['createdRooRoutineId'] as String?,
      playedSerenSoundId: json['playedSerenSoundId'] as String?,
      createdScoutPresetId: json['createdScoutPresetId'] as String?,
      createdScoutPlaceId: json['createdScoutPlaceId'] as String?,
      createdRooCalendarEventId: json['createdRooCalendarEventId'] as String?,
      createdTwillBudgetId: json['createdTwillBudgetId'] as String?,
    );
  }
}

/// Curated, deterministic catalog for Nestin Discover & Pippin's Hobby Finder.
class ExperienceCatalog {
  static const String hobbyFinderId = 'hobby_finder_v1';
  static const String bookMatcherId = BookMatcherCatalog.bookMatcherId;
  static const ExperienceDefinition bookMatcherV1 =
      BookMatcherCatalog.definition;
  static const String weekendGeneratorId =
      WeekendGeneratorCatalog.weekendGeneratorId;
  static const ExperienceDefinition weekendGeneratorV1 =
      WeekendGeneratorCatalog.definition;
  static List<BookRecommendationProfile> get curatedBooks =>
      BookMatcherCatalog.curatedBooks;

  static const List<HobbyRecommendationProfile> hobbyProfiles = [
    HobbyRecommendationProfile(
      id: 'aquascaping',
      titleKey: 'exp_hobby_aquascaping_title',
      categoryKey: 'exp_hobby_aquascaping_cat',
      descriptionKey: 'exp_hobby_aquascaping_desc',
      whyItFitsKey: 'exp_hobby_aquascaping_why',
      iconEmoji: '🐠',
      colorHex: '#0EA5E9',
      tagAffinities: {
        'nature': 3.5,
        'aquatic': 4.0,
        'tactile': 2.0,
        'evolving': 3.0,
        'zen_water': 3.5,
        'observational': 2.0,
      },
      minHoursPerWeek: 2.0,
      recommendedTargetHours: 40,
      budgetTier: ExperienceBudgetTier.high,
      estimatedStarterCostUsd: 115,
      preferredEnvironments: [
        ExperienceEnvironmentType.cozyDesk,
        ExperienceEnvironmentType.kitchenStudio,
      ],
      starterChecklistItems: [
        'Rimless 5–10 gallon glass nano tank & leveling mat',
        'Aquasoil substrate, Seiryu stones & Spider driftwood hardscape',
        'Easy epiphytes: Anubias nana petite, Java fern & Bucephalandra',
        'Clip-on planted LED light & quiet sponge/hang-on-back filter',
        'Liquid water conditioner & weekly 30% water-change siphon',
      ],
      firstSessionTaskTitle:
          'Sketch nano tank hardscape layout & rinse driftwood/stones (30 min)',
      pairedSerenSoundId: 'forest_stream',
    ),
    HobbyRecommendationProfile(
      id: 'urban_sketching',
      titleKey: 'exp_hobby_urbansketch_title',
      categoryKey: 'exp_hobby_urbansketch_cat',
      descriptionKey: 'exp_hobby_urbansketch_desc',
      whyItFitsKey: 'exp_hobby_urbansketch_why',
      iconEmoji: '🎨',
      colorHex: '#F59E0B',
      tagAffinities: {
        'expressive': 3.5,
        'ink_paper': 3.5,
        'instant': 2.5,
        'observational': 2.5,
        'experiment': 2.0,
      },
      minHoursPerWeek: 1.0,
      recommendedTargetHours: 30,
      budgetTier: ExperienceBudgetTier.low,
      estimatedStarterCostUsd: 28,
      preferredEnvironments: [
        ExperienceEnvironmentType.outdoorRoam,
        ExperienceEnvironmentType.cozyDesk,
      ],
      starterChecklistItems: [
        'A5 or pocket 300gsm cold-press watercolor sketchbook',
        'Waterproof pigment fineliner pen (0.3mm) or fountain pen',
        'Compact 12-half-pan travel watercolor tin',
        'Refillable water brush pen & cotton blotter cloth',
      ],
      firstSessionTaskTitle:
          'Draw a 20-minute continuous-line ink & wash sketch of a mug or window view',
      pairedSerenSoundId: 'gentle_rain',
    ),
    HobbyRecommendationProfile(
      id: 'fingerstyle_guitar',
      titleKey: 'exp_hobby_guitar_title',
      categoryKey: 'exp_hobby_guitar_cat',
      descriptionKey: 'exp_hobby_guitar_desc',
      whyItFitsKey: 'exp_hobby_guitar_why',
      iconEmoji: '🎸',
      colorHex: '#8B5CF6',
      tagAffinities: {
        'expressive': 3.0,
        'warm_strings': 4.0,
        'skill': 3.5,
        'step_by_step': 2.5,
      },
      minHoursPerWeek: 2.0,
      recommendedTargetHours: 50,
      budgetTier: ExperienceBudgetTier.high,
      estimatedStarterCostUsd: 120,
      preferredEnvironments: [
        ExperienceEnvironmentType.cozyDesk,
      ],
      starterChecklistItems: [
        'Parlor or classical nylon-string acoustic guitar',
        'Clip-on chromatic headstock tuner',
        'Ergonomic footstool or guitar posture strap',
        '3 beginner Travis-picking chord progression tabs',
      ],
      firstSessionTaskTitle:
          'Tune nylon strings & practice slow C–Am–Em–G right-hand arpeggio pattern (25 min)',
      pairedSerenSoundId: 'nylon_guitar',
    ),
    HobbyRecommendationProfile(
      id: 'glass_terrarium',
      titleKey: 'exp_hobby_terrarium_title',
      categoryKey: 'exp_hobby_terrarium_cat',
      descriptionKey: 'exp_hobby_terrarium_desc',
      whyItFitsKey: 'exp_hobby_terrarium_why',
      iconEmoji: '🌿',
      colorHex: '#10B981',
      tagAffinities: {
        'nature': 3.5,
        'moss': 4.0,
        'tactile': 3.0,
        'zen_water': 2.5,
        'evolving': 2.5,
      },
      minHoursPerWeek: 1.0,
      recommendedTargetHours: 20,
      budgetTier: ExperienceBudgetTier.low,
      estimatedStarterCostUsd: 32,
      preferredEnvironments: [
        ExperienceEnvironmentType.cozyDesk,
        ExperienceEnvironmentType.kitchenStudio,
      ],
      starterChecklistItems: [
        'Clear lidded apothecary jar or repurposed glass vessel',
        'False-bottom drainage pebbles, mesh screen & activated charcoal',
        'Terrarium soil blend (coco coir, worm castings, orchid bark)',
        'Live cushion moss, nerve plant (Fittonia) & long aquascaping tweezers',
      ],
      firstSessionTaskTitle:
          'Layer drainage pebbles, charcoal & moss substrate in your first closed jar (30 min)',
      pairedSerenSoundId: 'soft_kalimba',
    ),
    HobbyRecommendationProfile(
      id: 'matcha_tea_craft',
      titleKey: 'exp_hobby_matcha_title',
      categoryKey: 'exp_hobby_matcha_cat',
      descriptionKey: 'exp_hobby_matcha_desc',
      whyItFitsKey: 'exp_hobby_matcha_why',
      iconEmoji: '🍵',
      colorHex: '#059669',
      tagAffinities: {
        'ritual': 4.0,
        'artisan_aroma': 4.0,
        'instant': 3.0,
        'observational': 2.0,
      },
      minHoursPerWeek: 1.0,
      recommendedTargetHours: 20,
      budgetTier: ExperienceBudgetTier.mid,
      estimatedStarterCostUsd: 55,
      preferredEnvironments: [
        ExperienceEnvironmentType.kitchenStudio,
        ExperienceEnvironmentType.cozyDesk,
      ],
      starterChecklistItems: [
        '80-prong bamboo whisk (Chasen) & ceramic whisk holder',
        'Wide-bottom ceramic tea bowl (Chawan) & bamboo scoop (Chashaku)',
        'Fine stainless mesh sifter & 75°C–80°C temperature kettle/thermometer',
        '30g tin of ceremonial first-harvest Uji or Yame matcha',
      ],
      firstSessionTaskTitle:
          'Sift 2g matcha, heat water to 78°C, and practice W-motion microfoam whisking',
      pairedSerenSoundId: 'singing_bowls',
    ),
    HobbyRecommendationProfile(
      id: 'hand_bookbinding',
      titleKey: 'exp_hobby_bookbinding_title',
      categoryKey: 'exp_hobby_bookbinding_cat',
      descriptionKey: 'exp_hobby_bookbinding_desc',
      whyItFitsKey: 'exp_hobby_bookbinding_why',
      iconEmoji: '📓',
      colorHex: '#EC4899',
      tagAffinities: {
        'tactile': 4.0,
        'ink_paper': 3.5,
        'step_by_step': 3.0,
        'instant': 2.0,
      },
      minHoursPerWeek: 1.5,
      recommendedTargetHours: 25,
      budgetTier: ExperienceBudgetTier.low,
      estimatedStarterCostUsd: 30,
      preferredEnvironments: [
        ExperienceEnvironmentType.cozyDesk,
      ],
      starterChecklistItems: [
        'Bone folder, piercing awl & self-healing cutting mat',
        'Waxed linen bookbinding thread & blunt tapestry needles',
        '24 sheets of folded 120gsm acid-free paper signatures',
        '2mm greyboard covers & decorative Lokta or marbled cover paper',
      ],
      firstSessionTaskTitle:
          'Fold 4 paper signatures & stitch a 5-hole pamphlet-bound pocket notebook (30 min)',
      pairedSerenSoundId: 'warm_piano',
    ),
    HobbyRecommendationProfile(
      id: 'street_photography',
      titleKey: 'exp_hobby_photography_title',
      categoryKey: 'exp_hobby_photography_cat',
      descriptionKey: 'exp_hobby_photography_desc',
      whyItFitsKey: 'exp_hobby_photography_why',
      iconEmoji: '📷',
      colorHex: '#6366F1',
      tagAffinities: {
        'expressive': 3.5,
        'observational': 3.5,
        'instant': 2.5,
        'experiment': 2.5,
      },
      minHoursPerWeek: 1.5,
      recommendedTargetHours: 35,
      budgetTier: ExperienceBudgetTier.mid,
      estimatedStarterCostUsd: 45,
      preferredEnvironments: [
        ExperienceEnvironmentType.outdoorRoam,
      ],
      starterChecklistItems: [
        'Phone manual-exposure grid setup or compact prime camera',
        'Pocket lens microfiber cloth & wrist strap',
        'Golden-hour shadow & leading-lines prompt card list',
        'Curated 12-frame monthly photo zine folder',
      ],
      firstSessionTaskTitle:
          'Take a 25-minute golden-hour walk capturing 5 high-contrast shadow & reflection frames',
      pairedSerenSoundId: 'night_ambience',
    ),
    HobbyRecommendationProfile(
      id: 'artisan_sourdough',
      titleKey: 'exp_hobby_sourdough_title',
      categoryKey: 'exp_hobby_sourdough_cat',
      descriptionKey: 'exp_hobby_sourdough_desc',
      whyItFitsKey: 'exp_hobby_sourdough_why',
      iconEmoji: '🥖',
      colorHex: '#D97706',
      tagAffinities: {
        'ritual': 3.5,
        'tactile': 3.0,
        'artisan_aroma': 3.5,
        'evolving': 3.0,
        'step_by_step': 2.5,
      },
      minHoursPerWeek: 2.5,
      recommendedTargetHours: 35,
      budgetTier: ExperienceBudgetTier.mid,
      estimatedStarterCostUsd: 60,
      preferredEnvironments: [
        ExperienceEnvironmentType.kitchenStudio,
      ],
      starterChecklistItems: [
        'Digital kitchen gram scale & straight-sided glass starter jar',
        'Unbleached bread flour, whole rye flour & fine sea salt',
        'Bench scraper, rattan proofing banneton & scoring lame',
        'Heavy Dutch oven or baking steel for oven-spring steam',
      ],
      firstSessionTaskTitle:
          'Mix Day-1 wild sourdough starter (50g whole grain flour + 50g warm water) & mark jar band',
      pairedSerenSoundId: 'cello_drone',
    ),
  ];

  static const ExperienceDefinition hobbyFinderV1 = ExperienceDefinition(
    id: hobbyFinderId,
    version: 1,
    titleKey: 'exp_hobby_finder_title',
    subtitleKey: 'exp_hobby_finder_subtitle',
    primaryBird: 'Pippin',
    supportingBirds: ['Twill', 'Roo', 'Seren', 'Echo'],
    grouping: DiscoverGrouping.discoverYourself,
    status: ExperienceCandidateStatus.referenceImplemented,
    hobbyProfiles: hobbyProfiles,
    questions: [
      ExperienceQuestion(
        id: 'q_flow_state',
        titleKey: 'exp_q_flow_title',
        subtitleKey: 'exp_q_flow_sub',
        type: ExperienceQuestionType.multipleChoice,
        maxSelections: 2,
        options: [
          ExperienceOption(
            id: 'opt_flow_tactile',
            labelKey: 'exp_opt_flow_tactile',
            emoji: '🛠️',
            tagWeights: {'tactile': 3.0, 'ink_paper': 1.5},
          ),
          ExperienceOption(
            id: 'opt_flow_nature',
            labelKey: 'exp_opt_flow_nature',
            emoji: '🌱',
            tagWeights: {'nature': 3.5, 'evolving': 1.5},
          ),
          ExperienceOption(
            id: 'opt_flow_expressive',
            labelKey: 'exp_opt_flow_expressive',
            emoji: '🎭',
            tagWeights: {'expressive': 3.5, 'warm_strings': 1.5},
          ),
          ExperienceOption(
            id: 'opt_flow_ritual',
            labelKey: 'exp_opt_flow_ritual',
            emoji: '🍵',
            tagWeights: {'ritual': 3.5, 'artisan_aroma': 2.0},
          ),
        ],
      ),
      // Conditional follow-up question: only shown when 'opt_flow_nature' is selected in 'q_flow_state'
      ExperienceQuestion(
        id: 'q_living_water_branch',
        titleKey: 'exp_q_living_water_title',
        subtitleKey: 'exp_q_living_water_sub',
        type: ExperienceQuestionType.singleChoice,
        showIfQuestionId: 'q_flow_state',
        showIfOptionIds: ['opt_flow_nature'],
        options: [
          ExperienceOption(
            id: 'opt_living_aquatic',
            labelKey: 'exp_opt_living_aquatic',
            emoji: '🐠',
            tagWeights: {'aquatic': 4.5, 'zen_water': 2.5},
          ),
          ExperienceOption(
            id: 'opt_living_moss',
            labelKey: 'exp_opt_living_moss',
            emoji: '🌿',
            tagWeights: {'moss': 4.5, 'tactile': 1.5},
          ),
        ],
      ),
      ExperienceQuestion(
        id: 'q_environment',
        titleKey: 'exp_q_env_title',
        subtitleKey: 'exp_q_env_sub',
        type: ExperienceQuestionType.singleChoice,
        options: [
          ExperienceOption(
            id: 'opt_env_cozy_desk',
            labelKey: 'exp_opt_env_cozy_desk',
            emoji: '🪴',
            environmentType: ExperienceEnvironmentType.cozyDesk,
            tagWeights: {'ink_paper': 1.0, 'warm_strings': 1.0},
          ),
          ExperienceOption(
            id: 'opt_env_kitchen_studio',
            labelKey: 'exp_opt_env_kitchen_studio',
            emoji: '🥣',
            environmentType: ExperienceEnvironmentType.kitchenStudio,
            tagWeights: {'ritual': 1.5, 'artisan_aroma': 1.5},
          ),
          ExperienceOption(
            id: 'opt_env_outdoor_roam',
            labelKey: 'exp_opt_env_outdoor_roam',
            emoji: '🚶',
            environmentType: ExperienceEnvironmentType.outdoorRoam,
            tagWeights: {'observational': 2.0, 'expressive': 1.5},
          ),
        ],
      ),
      ExperienceQuestion(
        id: 'q_weekly_hours',
        titleKey: 'exp_q_time_title',
        subtitleKey: 'exp_q_time_sub',
        type: ExperienceQuestionType.slider,
        minValue: 1.0,
        maxValue: 8.0,
        defaultValue: 3.0,
      ),
      ExperienceQuestion(
        id: 'q_budget_tier',
        titleKey: 'exp_q_budget_title',
        subtitleKey: 'exp_q_budget_sub',
        type: ExperienceQuestionType.singleChoice,
        options: [
          ExperienceOption(
            id: 'opt_budget_low',
            labelKey: 'exp_opt_budget_low',
            emoji: '🪙',
            budgetTier: ExperienceBudgetTier.low,
          ),
          ExperienceOption(
            id: 'opt_budget_mid',
            labelKey: 'exp_opt_budget_mid',
            emoji: '🎒',
            budgetTier: ExperienceBudgetTier.mid,
          ),
          ExperienceOption(
            id: 'opt_budget_high',
            labelKey: 'exp_opt_budget_high',
            emoji: '✨',
            budgetTier: ExperienceBudgetTier.high,
          ),
        ],
      ),
      ExperienceQuestion(
        id: 'q_visual_vibe',
        titleKey: 'exp_q_visual_vibe_title',
        subtitleKey: 'exp_q_visual_vibe_sub',
        type: ExperienceQuestionType.visualSelection,
        options: [
          ExperienceOption(
            id: 'opt_vibe_zen_water',
            labelKey: 'exp_opt_vibe_zen_water',
            emoji: '🌊',
            tagWeights: {'zen_water': 3.5, 'nature': 2.0, 'aquatic': 2.0},
          ),
          ExperienceOption(
            id: 'opt_vibe_ink_paper',
            labelKey: 'exp_opt_vibe_ink_paper',
            emoji: '🖋️',
            tagWeights: {'ink_paper': 3.5, 'expressive': 2.0},
          ),
          ExperienceOption(
            id: 'opt_vibe_warm_strings',
            labelKey: 'exp_opt_vibe_warm_strings',
            emoji: '🎶',
            tagWeights: {'warm_strings': 4.0, 'skill': 2.0},
          ),
          ExperienceOption(
            id: 'opt_vibe_artisan_aroma',
            labelKey: 'exp_opt_vibe_artisan_aroma',
            emoji: '🍵',
            tagWeights: {'artisan_aroma': 3.5, 'ritual': 2.5},
          ),
        ],
      ),
      ExperienceQuestion(
        id: 'q_learning_style',
        titleKey: 'exp_q_learning_style_title',
        subtitleKey: 'exp_q_learning_style_sub',
        type: ExperienceQuestionType.ranking,
        isOptional: true,
        options: [
          ExperienceOption(
            id: 'opt_learn_step_by_step',
            labelKey: 'exp_opt_learn_step_by_step',
            emoji: '📋',
            tagWeights: {'step_by_step': 2.5},
          ),
          ExperienceOption(
            id: 'opt_learn_experiment',
            labelKey: 'exp_opt_learn_experiment',
            emoji: '🧪',
            tagWeights: {'experiment': 2.5},
          ),
          ExperienceOption(
            id: 'opt_learn_observational',
            labelKey: 'exp_opt_learn_observational',
            emoji: '🔍',
            tagWeights: {'observational': 2.5},
          ),
        ],
      ),
      ExperienceQuestion(
        id: 'q_patience_horizon',
        titleKey: 'exp_q_patience_title',
        subtitleKey: 'exp_q_patience_sub',
        type: ExperienceQuestionType.singleChoice,
        options: [
          ExperienceOption(
            id: 'opt_patience_instant',
            labelKey: 'exp_opt_patience_instant',
            emoji: '⚡',
            tagWeights: {'instant': 3.0},
          ),
          ExperienceOption(
            id: 'opt_patience_evolving',
            labelKey: 'exp_opt_patience_evolving',
            emoji: '🌳',
            tagWeights: {'evolving': 3.0, 'nature': 1.5},
          ),
          ExperienceOption(
            id: 'opt_patience_skill',
            labelKey: 'exp_opt_patience_skill',
            emoji: '🎯',
            tagWeights: {'skill': 3.0},
          ),
        ],
      ),
    ],
  );

  /// Complete backlog & 10-criteria audit registry (Section 2 & Phase 1 Audit).
  static const List<ExperienceCandidateAudit> candidateBacklog = [
    ExperienceCandidateAudit(
      id: hobbyFinderId,
      titleKey: 'exp_hobby_finder_title',
      descriptionKey: 'exp_hobby_finder_subtitle',
      iconEmoji: '🧭',
      primaryBird: 'Pippin',
      supportingBirds: ['Twill', 'Roo', 'Seren', 'Echo'],
      grouping: DiscoverGrouping.discoverYourself,
      status: ExperienceCandidateStatus.referenceImplemented,
      reusedNestinModules: [
        'HobbyProvider',
        'CollectionProvider',
        'TaskProvider',
        'SerenRelaxationProvider',
        'CrossModuleLinkProvider',
      ],
      followUpActionsCreated: [
        'HobbyItem',
        'CollectionItem (Starter Checklist)',
        'WishlistItem (Budget Estimate)',
        'TaskItem (First 30-Min Session)',
        'EntityLink',
      ],
    ),
    ExperienceCandidateAudit(
      id: 'book_matcher_v1',
      titleKey: 'bm_title',
      descriptionKey: 'bm_subtitle',
      iconEmoji: '📚',
      primaryBird: 'Pippin',
      supportingBirds: ['Seren', 'Roo', 'Echo'],
      grouping: DiscoverGrouping.discoverYourself,
      status: ExperienceCandidateStatus.referenceImplemented,
      reusedNestinModules: [
        'ReadingProvider',
        'SerenRelaxationProvider',
        'RoutineProvider',
        'TaskProvider',
        'CrossModuleLinkProvider',
      ],
      followUpActionsCreated: [
        'ReadingItem (Want to Read / Currently Reading)',
        'RoutineItem / TaskItem (20m Evening Reading Block)',
        'EntityLink',
      ],
    ),
    ExperienceCandidateAudit(
      id: 'interest_explorer',
      titleKey: 'exp_cand_interest_explorer_title',
      descriptionKey: 'exp_cand_interest_explorer_desc',
      iconEmoji: '✨',
      primaryBird: 'Pippin',
      supportingBirds: ['Echo', 'Roo'],
      grouping: DiscoverGrouping.discoverYourself,
      status: ExperienceCandidateStatus.priorityCandidate,
      reusedNestinModules: [
        'HobbyProvider',
        'ReadingProvider',
        'BucketListProvider',
        'JournalProvider',
      ],
      followUpActionsCreated: [
        'BucketListItem',
        'ReadingItem',
        'JournalEntry',
      ],
    ),
    ExperienceCandidateAudit(
      id: 'weekend_generator_v1',
      titleKey: 'exp_cand_weekend_gen_title',
      descriptionKey: 'exp_cand_weekend_gen_desc',
      iconEmoji: '⛺',
      primaryBird: 'Scout',
      supportingBirds: ['Roo', 'Twill', 'Pippin'],
      grouping: DiscoverGrouping.exploreTheWorld,
      status: ExperienceCandidateStatus.referenceImplemented,
      reusedNestinModules: [
        'BeforeYouGoProvider',
        'LocalWeatherService',
        'GeofenceProvider',
        'CalendarProvider',
        'CollectionProvider',
        'MoneyProvider',
      ],
      followUpActionsCreated: [
        'DeparturePreset',
        'SavedPlace / LocationReminder',
        'CalendarEvent',
        'CollectionItem',
        'MoneyBudget',
      ],
    ),
    ExperienceCandidateAudit(
      id: 'knowledge_arena_v1',
      titleKey: 'exp_cand_knowledge_arena_title',
      descriptionKey: 'exp_cand_knowledge_arena_desc',
      iconEmoji: '🏛️',
      primaryBird: 'Echo',
      supportingBirds: ['Pippin'],
      grouping: DiscoverGrouping.learnSomething,
      status: ExperienceCandidateStatus.referenceImplemented,
      reusedNestinModules: [
        'NoteProvider',
        'ReadingProvider',
        'CrossModuleLinkProvider',
      ],
      followUpActionsCreated: [
        'NoteItem (Saved Fact Card)',
        'ReadingItem',
        'EntityLink',
      ],
    ),
    ExperienceCandidateAudit(
      id: 'daily_creative_prompt',
      titleKey: 'exp_cand_creative_prompt_title',
      descriptionKey: 'exp_cand_creative_prompt_desc',
      iconEmoji: '🖌️',
      primaryBird: 'Pippin',
      supportingBirds: ['Echo', 'Roo'],
      grouping: DiscoverGrouping.makeSomething,
      status: ExperienceCandidateStatus.priorityCandidate,
      reusedNestinModules: [
        'HobbyProvider',
        'JournalProvider',
        'NoteProvider',
      ],
      followUpActionsCreated: [
        'HobbyPracticeSession',
        'JournalEntry',
      ],
    ),
    ExperienceCandidateAudit(
      id: 'brain_playground_v1',
      titleKey: 'exp_cand_brain_playground_title',
      descriptionKey: 'exp_cand_brain_playground_desc',
      iconEmoji: '🧩',
      primaryBird: 'Echo',
      supportingBirds: ['Roo'],
      grouping: DiscoverGrouping.learnSomething,
      status: ExperienceCandidateStatus.referenceImplemented,
      reusedNestinModules: [
        'TimerProvider',
        'NoteProvider',
      ],
      followUpActionsCreated: [
        'FocusSessionLog',
        'NoteItem (Reasoning Strategy)',
      ],
    ),
    ExperienceCandidateAudit(
      id: 'meal_idea_spinner',
      titleKey: 'exp_cand_meal_spinner_title',
      descriptionKey: 'exp_cand_meal_spinner_desc',
      iconEmoji: '🍲',
      primaryBird: 'Twill',
      supportingBirds: ['Roo'],
      grouping: DiscoverGrouping.makeSomething,
      status: ExperienceCandidateStatus.integratedPractical,
      reusedNestinModules: [
        'CollectionProvider',
        'MoneyProvider',
        'TaskProvider',
      ],
      followUpActionsCreated: [
        'CollectionItem (Grocery List)',
        'TaskItem',
      ],
    ),
    ExperienceCandidateAudit(
      id: 'mini_workout_generator',
      titleKey: 'exp_cand_workout_gen_title',
      descriptionKey: 'exp_cand_workout_gen_desc',
      iconEmoji: '🧘',
      primaryBird: 'Seren',
      supportingBirds: ['Roo'],
      grouping: DiscoverGrouping.discoverYourself,
      status: ExperienceCandidateStatus.integratedPractical,
      reusedNestinModules: [
        'HealthWellnessProvider',
        'TimerProvider',
      ],
      followUpActionsCreated: [
        'DailyHealthActivity',
      ],
    ),
    ExperienceCandidateAudit(
      id: 'declutter_challenge',
      titleKey: 'exp_cand_declutter_title',
      descriptionKey: 'exp_cand_declutter_desc',
      iconEmoji: '🧺',
      primaryBird: 'Twill',
      supportingBirds: ['Roo'],
      grouping: DiscoverGrouping.makeSomething,
      status: ExperienceCandidateStatus.integratedPractical,
      reusedNestinModules: [
        'CollectionProvider',
        'TaskProvider',
        'TimerProvider',
      ],
      followUpActionsCreated: [
        'CollectionItem',
        'TaskItem',
      ],
    ),
  ];

  static HobbyRecommendationProfile? findHobbyProfileById(String id) {
    for (final profile in hobbyProfiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  // ===========================================================================
  // ECHO'S KNOWLEDGE ARENA (knowledge_arena_v1)
  // ===========================================================================

  static const String knowledgeArenaId = 'knowledge_arena_v1';

  static const List<KnowledgeArenaCard> knowledgeArenaCards = [
    // 1. Science — Hexagonal Ice Lattice
    KnowledgeArenaCard(
      id: 'ka_sci_1',
      topic: KnowledgeArenaTopic.science,
      promptKey: 'ka_q_sci_1_prompt',
      factTitleKey: 'ka_q_sci_1_fact_title',
      explanationKey: 'ka_q_sci_1_explain',
      suggestedBookTitleKey: 'ka_q_sci_1_book_title',
      suggestedBookAuthorKey: 'ka_q_sci_1_book_author',
      suggestedBookPages: 240,
      options: [
        KnowledgeArenaOption(
          id: 'a',
          labelKey: 'ka_q_sci_1_opt_a',
          isCorrect: true,
        ),
        KnowledgeArenaOption(id: 'b', labelKey: 'ka_q_sci_1_opt_b'),
        KnowledgeArenaOption(id: 'c', labelKey: 'ka_q_sci_1_opt_c'),
        KnowledgeArenaOption(id: 'd', labelKey: 'ka_q_sci_1_opt_d'),
      ],
    ),
    // 2. Science — Sunlight 8m 20s travel
    KnowledgeArenaCard(
      id: 'ka_sci_2',
      topic: KnowledgeArenaTopic.science,
      promptKey: 'ka_q_sci_2_prompt',
      factTitleKey: 'ka_q_sci_2_fact_title',
      explanationKey: 'ka_q_sci_2_explain',
      suggestedBookTitleKey: 'ka_q_sci_2_book_title',
      suggestedBookAuthorKey: 'ka_q_sci_2_book_author',
      suggestedBookPages: 365,
      options: [
        KnowledgeArenaOption(
          id: 'a',
          labelKey: 'ka_q_sci_2_opt_a',
          isCorrect: true,
        ),
        KnowledgeArenaOption(id: 'b', labelKey: 'ka_q_sci_2_opt_b'),
        KnowledgeArenaOption(id: 'c', labelKey: 'ka_q_sci_2_opt_c'),
        KnowledgeArenaOption(id: 'd', labelKey: 'ka_q_sci_2_opt_d'),
      ],
    ),
    // 3. Nature — Mycorrhizal Wood Wide Web
    KnowledgeArenaCard(
      id: 'ka_nat_1',
      topic: KnowledgeArenaTopic.nature,
      promptKey: 'ka_q_nat_1_prompt',
      factTitleKey: 'ka_q_nat_1_fact_title',
      explanationKey: 'ka_q_nat_1_explain',
      suggestedBookTitleKey: 'ka_q_nat_1_book_title',
      suggestedBookAuthorKey: 'ka_q_nat_1_book_author',
      suggestedBookPages: 348,
      options: [
        KnowledgeArenaOption(
          id: 'a',
          labelKey: 'ka_q_nat_1_opt_a',
          isCorrect: true,
        ),
        KnowledgeArenaOption(id: 'b', labelKey: 'ka_q_nat_1_opt_b'),
        KnowledgeArenaOption(id: 'c', labelKey: 'ka_q_nat_1_opt_c'),
        KnowledgeArenaOption(id: 'd', labelKey: 'ka_q_nat_1_opt_d'),
      ],
    ),
    // 4. Nature — Dolphin Unihemispheric Sleep
    KnowledgeArenaCard(
      id: 'ka_nat_2',
      topic: KnowledgeArenaTopic.nature,
      promptKey: 'ka_q_nat_2_prompt',
      factTitleKey: 'ka_q_nat_2_fact_title',
      explanationKey: 'ka_q_nat_2_explain',
      suggestedBookTitleKey: 'ka_q_nat_2_book_title',
      suggestedBookAuthorKey: 'ka_q_nat_2_book_author',
      suggestedBookPages: 360,
      options: [
        KnowledgeArenaOption(
          id: 'a',
          labelKey: 'ka_q_nat_2_opt_a',
          isCorrect: true,
        ),
        KnowledgeArenaOption(id: 'b', labelKey: 'ka_q_nat_2_opt_b'),
        KnowledgeArenaOption(id: 'c', labelKey: 'ka_q_nat_2_opt_c'),
        KnowledgeArenaOption(id: 'd', labelKey: 'ka_q_nat_2_opt_d'),
      ],
    ),
    // 5. Geography — Wallace Line
    KnowledgeArenaCard(
      id: 'ka_geo_1',
      topic: KnowledgeArenaTopic.geography,
      promptKey: 'ka_q_geo_1_prompt',
      factTitleKey: 'ka_q_geo_1_fact_title',
      explanationKey: 'ka_q_geo_1_explain',
      suggestedBookTitleKey: 'ka_q_geo_1_book_title',
      suggestedBookAuthorKey: 'ka_q_geo_1_book_author',
      suggestedBookPages: 515,
      options: [
        KnowledgeArenaOption(
          id: 'a',
          labelKey: 'ka_q_geo_1_opt_a',
          isCorrect: true,
        ),
        KnowledgeArenaOption(id: 'b', labelKey: 'ka_q_geo_1_opt_b'),
        KnowledgeArenaOption(id: 'c', labelKey: 'ka_q_geo_1_opt_c'),
        KnowledgeArenaOption(id: 'd', labelKey: 'ka_q_geo_1_opt_d'),
      ],
    ),
    // 6. Geography — Mid-Ocean Ridge
    KnowledgeArenaCard(
      id: 'ka_geo_2',
      topic: KnowledgeArenaTopic.geography,
      promptKey: 'ka_q_geo_2_prompt',
      factTitleKey: 'ka_q_geo_2_fact_title',
      explanationKey: 'ka_q_geo_2_explain',
      suggestedBookTitleKey: 'ka_q_geo_2_book_title',
      suggestedBookAuthorKey: 'ka_q_geo_2_book_author',
      suggestedBookPages: 696,
      options: [
        KnowledgeArenaOption(
          id: 'a',
          labelKey: 'ka_q_geo_2_opt_a',
          isCorrect: true,
        ),
        KnowledgeArenaOption(id: 'b', labelKey: 'ka_q_geo_2_opt_b'),
        KnowledgeArenaOption(id: 'c', labelKey: 'ka_q_geo_2_opt_c'),
        KnowledgeArenaOption(id: 'd', labelKey: 'ka_q_geo_2_opt_d'),
      ],
    ),
    // 7. History — Mesopotamian Cuneiform Clay Tablets
    KnowledgeArenaCard(
      id: 'ka_hist_1',
      topic: KnowledgeArenaTopic.history,
      promptKey: 'ka_q_hist_1_prompt',
      factTitleKey: 'ka_q_hist_1_fact_title',
      explanationKey: 'ka_q_hist_1_explain',
      suggestedBookTitleKey: 'ka_q_hist_1_book_title',
      suggestedBookAuthorKey: 'ka_q_hist_1_book_author',
      suggestedBookPages: 443,
      options: [
        KnowledgeArenaOption(
          id: 'a',
          labelKey: 'ka_q_hist_1_opt_a',
          isCorrect: true,
        ),
        KnowledgeArenaOption(id: 'b', labelKey: 'ka_q_hist_1_opt_b'),
        KnowledgeArenaOption(id: 'c', labelKey: 'ka_q_hist_1_opt_c'),
        KnowledgeArenaOption(id: 'd', labelKey: 'ka_q_hist_1_opt_d'),
      ],
    ),
    // 8. History — Austronesian Star Compass & Swell Navigation
    KnowledgeArenaCard(
      id: 'ka_hist_2',
      topic: KnowledgeArenaTopic.history,
      promptKey: 'ka_q_hist_2_prompt',
      factTitleKey: 'ka_q_hist_2_fact_title',
      explanationKey: 'ka_q_hist_2_explain',
      suggestedBookTitleKey: 'ka_q_hist_2_book_title',
      suggestedBookAuthorKey: 'ka_q_hist_2_book_author',
      suggestedBookPages: 264,
      options: [
        KnowledgeArenaOption(
          id: 'a',
          labelKey: 'ka_q_hist_2_opt_a',
          isCorrect: true,
        ),
        KnowledgeArenaOption(id: 'b', labelKey: 'ka_q_hist_2_opt_b'),
        KnowledgeArenaOption(id: 'c', labelKey: 'ka_q_hist_2_opt_c'),
        KnowledgeArenaOption(id: 'd', labelKey: 'ka_q_hist_2_opt_d'),
      ],
    ),
    // 9. Culture — Indonesian Batik Canting
    KnowledgeArenaCard(
      id: 'ka_cult_1',
      topic: KnowledgeArenaTopic.culture,
      promptKey: 'ka_q_cult_1_prompt',
      factTitleKey: 'ka_q_cult_1_fact_title',
      explanationKey: 'ka_q_cult_1_explain',
      suggestedBookTitleKey: 'ka_q_cult_1_book_title',
      suggestedBookAuthorKey: 'ka_q_cult_1_book_author',
      suggestedBookPages: 220,
      options: [
        KnowledgeArenaOption(
          id: 'a',
          labelKey: 'ka_q_cult_1_opt_a',
          isCorrect: true,
        ),
        KnowledgeArenaOption(id: 'b', labelKey: 'ka_q_cult_1_opt_b'),
        KnowledgeArenaOption(id: 'c', labelKey: 'ka_q_cult_1_opt_c'),
        KnowledgeArenaOption(id: 'd', labelKey: 'ka_q_cult_1_opt_d'),
      ],
    ),
    // 10. Culture — Japanese Kintsugi Golden Joinery
    KnowledgeArenaCard(
      id: 'ka_cult_2',
      topic: KnowledgeArenaTopic.culture,
      promptKey: 'ka_q_cult_2_prompt',
      factTitleKey: 'ka_q_cult_2_fact_title',
      explanationKey: 'ka_q_cult_2_explain',
      suggestedBookTitleKey: 'ka_q_cult_2_book_title',
      suggestedBookAuthorKey: 'ka_q_cult_2_book_author',
      suggestedBookPages: 96,
      options: [
        KnowledgeArenaOption(
          id: 'a',
          labelKey: 'ka_q_cult_2_opt_a',
          isCorrect: true,
        ),
        KnowledgeArenaOption(id: 'b', labelKey: 'ka_q_cult_2_opt_b'),
        KnowledgeArenaOption(id: 'c', labelKey: 'ka_q_cult_2_opt_c'),
        KnowledgeArenaOption(id: 'd', labelKey: 'ka_q_cult_2_opt_d'),
      ],
    ),
  ];

  static List<KnowledgeArenaCard> cardsForTopic(KnowledgeArenaTopic? topic) {
    if (topic == null || topic == KnowledgeArenaTopic.all) {
      return knowledgeArenaCards;
    }
    return knowledgeArenaCards.where((c) => c.topic == topic).toList();
  }

  static KnowledgeArenaCard? findKnowledgeCardById(String id) {
    for (final c in knowledgeArenaCards) {
      if (c.id == id) return c;
    }
    return null;
  }

  // ===========================================================================
  // ECHO'S BRAIN PLAYGROUND (brain_playground_v1)
  // ===========================================================================

  static const String brainPlaygroundId = 'brain_playground_v1';

  static const List<BrainPlaygroundPuzzle> brainPlaygroundPuzzles = [
    // 1. Pattern Recognition — 90° Phase Rotation Cycle
    BrainPlaygroundPuzzle(
      id: 'bp_pat_1',
      category: BrainPlaygroundCategory.patternRecognition,
      titleKey: 'bp_p_pat_1_title',
      promptKey: 'bp_p_pat_1_prompt',
      explanationKey: 'bp_p_pat_1_explain',
      visualBanner: '◐   →   ◓   →   ◑   →   ?',
      options: [
        BrainPlaygroundOption(
          id: 'a',
          labelKey: 'bp_p_pat_1_opt_a',
          isCorrect: true,
        ),
        BrainPlaygroundOption(id: 'b', labelKey: 'bp_p_pat_1_opt_b'),
        BrainPlaygroundOption(id: 'c', labelKey: 'bp_p_pat_1_opt_c'),
        BrainPlaygroundOption(id: 'd', labelKey: 'bp_p_pat_1_opt_d'),
      ],
    ),
    // 2. Pattern Recognition — Matrix Symmetry & Fill Parity
    BrainPlaygroundPuzzle(
      id: 'bp_pat_2',
      category: BrainPlaygroundCategory.patternRecognition,
      titleKey: 'bp_p_pat_2_title',
      promptKey: 'bp_p_pat_2_prompt',
      explanationKey: 'bp_p_pat_2_explain',
      visualBanner: '△ ▲ △  |  ○ ● ○  |  □ ■ ?',
      options: [
        BrainPlaygroundOption(
          id: 'a',
          labelKey: 'bp_p_pat_2_opt_a',
          isCorrect: true,
        ),
        BrainPlaygroundOption(id: 'b', labelKey: 'bp_p_pat_2_opt_b'),
        BrainPlaygroundOption(id: 'c', labelKey: 'bp_p_pat_2_opt_c'),
        BrainPlaygroundOption(id: 'd', labelKey: 'bp_p_pat_2_opt_d'),
      ],
    ),
    // 3. Sequence Logic — Fibonacci Botanical Spiral Step
    BrainPlaygroundPuzzle(
      id: 'bp_seq_1',
      category: BrainPlaygroundCategory.sequenceLogic,
      titleKey: 'bp_p_seq_1_title',
      promptKey: 'bp_p_seq_1_prompt',
      explanationKey: 'bp_p_seq_1_explain',
      visualBanner: '1  •  1  •  2  •  3  •  5  •  8  •  13  •  ?',
      options: [
        BrainPlaygroundOption(
          id: 'a',
          labelKey: 'bp_p_seq_1_opt_a',
          isCorrect: true,
        ),
        BrainPlaygroundOption(id: 'b', labelKey: 'bp_p_seq_1_opt_b'),
        BrainPlaygroundOption(id: 'c', labelKey: 'bp_p_seq_1_opt_c'),
        BrainPlaygroundOption(id: 'd', labelKey: 'bp_p_seq_1_opt_d'),
      ],
    ),
    // 4. Sequence Logic — Triangular First-Difference Progression
    BrainPlaygroundPuzzle(
      id: 'bp_seq_2',
      category: BrainPlaygroundCategory.sequenceLogic,
      titleKey: 'bp_p_seq_2_title',
      promptKey: 'bp_p_seq_2_prompt',
      explanationKey: 'bp_p_seq_2_explain',
      visualBanner: '2  (+2)  4  (+3)  7  (+4)  11  (+5)  16  →  ?',
      options: [
        BrainPlaygroundOption(
          id: 'a',
          labelKey: 'bp_p_seq_2_opt_a',
          isCorrect: true,
        ),
        BrainPlaygroundOption(id: 'b', labelKey: 'bp_p_seq_2_opt_b'),
        BrainPlaygroundOption(id: 'c', labelKey: 'bp_p_seq_2_opt_c'),
        BrainPlaygroundOption(id: 'd', labelKey: 'bp_p_seq_2_opt_d'),
      ],
    ),
    // 5. Spatial Reasoning — 3D Cube Net Opposite-Face Folding
    BrainPlaygroundPuzzle(
      id: 'bp_spa_1',
      category: BrainPlaygroundCategory.spatialReasoning,
      titleKey: 'bp_p_spa_1_title',
      promptKey: 'bp_p_spa_1_prompt',
      explanationKey: 'bp_p_spa_1_explain',
      visualBanner: '[ ] [★] [ ] [●]',
      options: [
        BrainPlaygroundOption(
          id: 'a',
          labelKey: 'bp_p_spa_1_opt_a',
          isCorrect: true,
        ),
        BrainPlaygroundOption(id: 'b', labelKey: 'bp_p_spa_1_opt_b'),
        BrainPlaygroundOption(id: 'c', labelKey: 'bp_p_spa_1_opt_c'),
        BrainPlaygroundOption(id: 'd', labelKey: 'bp_p_spa_1_opt_d'),
      ],
    ),
    // 6. Spatial Reasoning — Horizontal Mirror Axis Reflection
    BrainPlaygroundPuzzle(
      id: 'bp_spa_2',
      category: BrainPlaygroundCategory.spatialReasoning,
      titleKey: 'bp_p_spa_2_title',
      promptKey: 'bp_p_spa_2_prompt',
      explanationKey: 'bp_p_spa_2_explain',
      visualBanner: '┗   ⋮   ?',
      options: [
        BrainPlaygroundOption(
          id: 'a',
          labelKey: 'bp_p_spa_2_opt_a',
          isCorrect: true,
        ),
        BrainPlaygroundOption(id: 'b', labelKey: 'bp_p_spa_2_opt_b'),
        BrainPlaygroundOption(id: 'c', labelKey: 'bp_p_spa_2_opt_c'),
        BrainPlaygroundOption(id: 'd', labelKey: 'bp_p_spa_2_opt_d'),
      ],
    ),
  ];

  static List<BrainPlaygroundPuzzle> puzzlesForCategory(
    BrainPlaygroundCategory? category,
  ) {
    if (category == null || category == BrainPlaygroundCategory.all) {
      return brainPlaygroundPuzzles;
    }
    return brainPlaygroundPuzzles
        .where((p) => p.category == category)
        .toList();
  }
}

/// Calm cognitive warm-up categories in Echo's Brain Playground.
enum BrainPlaygroundCategory {
  all,
  patternRecognition,
  sequenceLogic,
  spatialReasoning,
}

extension BrainPlaygroundCategoryExt on BrainPlaygroundCategory {
  String get titleKey {
    switch (this) {
      case BrainPlaygroundCategory.all:
        return 'bp_cat_all';
      case BrainPlaygroundCategory.patternRecognition:
        return 'bp_cat_pattern';
      case BrainPlaygroundCategory.sequenceLogic:
        return 'bp_cat_sequence';
      case BrainPlaygroundCategory.spatialReasoning:
        return 'bp_cat_spatial';
    }
  }

  String get iconEmoji {
    switch (this) {
      case BrainPlaygroundCategory.all:
        return '🧩';
      case BrainPlaygroundCategory.patternRecognition:
        return '💠';
      case BrainPlaygroundCategory.sequenceLogic:
        return '🔢';
      case BrainPlaygroundCategory.spatialReasoning:
        return '📐';
    }
  }
}

class BrainPlaygroundOption {
  final String id;
  final String labelKey;
  final bool isCorrect;

  const BrainPlaygroundOption({
    required this.id,
    required this.labelKey,
    this.isCorrect = false,
  });
}

class BrainPlaygroundPuzzle {
  final String id;
  final BrainPlaygroundCategory category;
  final String titleKey;
  final String promptKey;
  final String explanationKey;
  final String visualBanner;
  final List<BrainPlaygroundOption> options;

  const BrainPlaygroundPuzzle({
    required this.id,
    required this.category,
    required this.titleKey,
    required this.promptKey,
    required this.explanationKey,
    required this.visualBanner,
    required this.options,
  });

  String get correctOptionId =>
      options.firstWhere((o) => o.isCorrect, orElse: () => options.first).id;
}

/// Curated curiosity domains in Echo's Knowledge Arena.
enum KnowledgeArenaTopic {
  all,
  science,
  nature,
  geography,
  history,
  culture,
}

extension KnowledgeArenaTopicExt on KnowledgeArenaTopic {
  String get titleKey {
    switch (this) {
      case KnowledgeArenaTopic.all:
        return 'ka_topic_all';
      case KnowledgeArenaTopic.science:
        return 'ka_topic_science';
      case KnowledgeArenaTopic.nature:
        return 'ka_topic_nature';
      case KnowledgeArenaTopic.geography:
        return 'ka_topic_geography';
      case KnowledgeArenaTopic.history:
        return 'ka_topic_history';
      case KnowledgeArenaTopic.culture:
        return 'ka_topic_culture';
    }
  }

  String get iconEmoji {
    switch (this) {
      case KnowledgeArenaTopic.all:
        return '🏛️';
      case KnowledgeArenaTopic.science:
        return '🔬';
      case KnowledgeArenaTopic.nature:
        return '🌿';
      case KnowledgeArenaTopic.geography:
        return '🌍';
      case KnowledgeArenaTopic.history:
        return '🏺';
      case KnowledgeArenaTopic.culture:
        return '🎭';
    }
  }
}

class KnowledgeArenaOption {
  final String id;
  final String labelKey;
  final bool isCorrect;

  const KnowledgeArenaOption({
    required this.id,
    required this.labelKey,
    this.isCorrect = false,
  });
}

class KnowledgeArenaCard {
  final String id;
  final KnowledgeArenaTopic topic;
  final String promptKey;
  final List<KnowledgeArenaOption> options;
  final String factTitleKey;
  final String explanationKey;
  final String suggestedBookTitleKey;
  final String suggestedBookAuthorKey;
  final int suggestedBookPages;

  const KnowledgeArenaCard({
    required this.id,
    required this.topic,
    required this.promptKey,
    required this.options,
    required this.factTitleKey,
    required this.explanationKey,
    required this.suggestedBookTitleKey,
    required this.suggestedBookAuthorKey,
    required this.suggestedBookPages,
  });

  String get correctOptionId =>
      options.firstWhere((o) => o.isCorrect, orElse: () => options.first).id;
}
