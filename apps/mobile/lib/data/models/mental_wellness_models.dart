import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../domain/security/diary_lock_helper.dart';

/// Non-clinical felt-state doors (`EFA-01`) welcoming users without requiring
/// mood ratings or forced explanations.
enum FeltStateType {
  overwhelmed,
  anxious,
  difficultDay,
  racingThoughts,
  lonely,
  needComfort,
  justNeedAMoment,
}

extension FeltStateTypeExt on FeltStateType {
  String get titleKey {
    switch (this) {
      case FeltStateType.overwhelmed:
        return 'mw_felt_overwhelmed_title';
      case FeltStateType.anxious:
        return 'mw_felt_anxious_title';
      case FeltStateType.difficultDay:
        return 'mw_felt_difficult_title';
      case FeltStateType.racingThoughts:
        return 'mw_felt_racing_title';
      case FeltStateType.lonely:
        return 'mw_felt_lonely_title';
      case FeltStateType.needComfort:
        return 'mw_felt_comfort_title';
      case FeltStateType.justNeedAMoment:
        return 'mw_felt_moment_title';
    }
  }

  String get subtitleKey {
    switch (this) {
      case FeltStateType.overwhelmed:
        return 'mw_felt_overwhelmed_sub';
      case FeltStateType.anxious:
        return 'mw_felt_anxious_sub';
      case FeltStateType.difficultDay:
        return 'mw_felt_difficult_sub';
      case FeltStateType.racingThoughts:
        return 'mw_felt_racing_sub';
      case FeltStateType.lonely:
        return 'mw_felt_lonely_sub';
      case FeltStateType.needComfort:
        return 'mw_felt_comfort_sub';
      case FeltStateType.justNeedAMoment:
        return 'mw_felt_moment_sub';
    }
  }

  /// Grounded, non-toxic acknowledgement (`EFA-02`, `EFA-08`).
  String get acknowledgementKey {
    switch (this) {
      case FeltStateType.overwhelmed:
        return 'mw_ack_overwhelmed';
      case FeltStateType.anxious:
        return 'mw_ack_anxious';
      case FeltStateType.difficultDay:
        return 'mw_ack_difficult';
      case FeltStateType.racingThoughts:
        return 'mw_ack_racing';
      case FeltStateType.lonely:
        return 'mw_ack_lonely';
      case FeltStateType.needComfort:
        return 'mw_ack_comfort';
      case FeltStateType.justNeedAMoment:
        return 'mw_ack_moment';
    }
  }

  /// Realistic, non-platitude encouragement message (`EFA-08`).
  String get encouragementKey {
    switch (this) {
      case FeltStateType.overwhelmed:
        return 'mw_enc_overwhelmed';
      case FeltStateType.anxious:
        return 'mw_enc_anxious';
      case FeltStateType.difficultDay:
        return 'mw_enc_difficult';
      case FeltStateType.racingThoughts:
        return 'mw_enc_racing';
      case FeltStateType.lonely:
        return 'mw_enc_lonely';
      case FeltStateType.needComfort:
        return 'mw_enc_comfort';
      case FeltStateType.justNeedAMoment:
        return 'mw_enc_moment';
    }
  }

  IconData get icon {
    switch (this) {
      case FeltStateType.overwhelmed:
        return Icons.waves_rounded;
      case FeltStateType.anxious:
        return Icons.air_rounded;
      case FeltStateType.difficultDay:
        return Icons.cloudy_snowing;
      case FeltStateType.racingThoughts:
        return Icons.blur_on_rounded;
      case FeltStateType.lonely:
        return Icons.nights_stay_rounded;
      case FeltStateType.needComfort:
        return Icons.local_cafe_rounded;
      case FeltStateType.justNeedAMoment:
        return Icons.pause_circle_outline_rounded;
    }
  }
}

/// Practical guided response buckets shown after selecting a felt state (`EFA-02`).
enum EfaResponseBucket {
  calmBody,
  quietSurroundings,
  outOfHead,
  smallNextStep,
}

extension EfaResponseBucketExt on EfaResponseBucket {
  String get titleKey {
    switch (this) {
      case EfaResponseBucket.calmBody:
        return 'mw_bucket_calm_body_title';
      case EfaResponseBucket.quietSurroundings:
        return 'mw_bucket_quiet_surroundings_title';
      case EfaResponseBucket.outOfHead:
        return 'mw_bucket_out_of_head_title';
      case EfaResponseBucket.smallNextStep:
        return 'mw_bucket_small_step_title';
    }
  }

  String get subtitleKey {
    switch (this) {
      case EfaResponseBucket.calmBody:
        return 'mw_bucket_calm_body_sub';
      case EfaResponseBucket.quietSurroundings:
        return 'mw_bucket_quiet_surroundings_sub';
      case EfaResponseBucket.outOfHead:
        return 'mw_bucket_out_of_head_sub';
      case EfaResponseBucket.smallNextStep:
        return 'mw_bucket_small_step_sub';
    }
  }

  IconData get icon {
    switch (this) {
      case EfaResponseBucket.calmBody:
        return Icons.self_improvement_rounded;
      case EfaResponseBucket.quietSurroundings:
        return Icons.surround_sound_rounded;
      case EfaResponseBucket.outOfHead:
        return Icons.edit_note_rounded;
      case EfaResponseBucket.smallNextStep:
        return Icons.directions_walk_rounded;
    }
  }
}

/// Step definition for interactive 5-4-3-2-1 sensory grounding (`EFA-03`).
class GroundingStepSpec {
  final int count;
  final String titleKey;
  final String instructionKey;
  final String examplesKey;
  final IconData icon;

  const GroundingStepSpec({
    required this.count,
    required this.titleKey,
    required this.instructionKey,
    required this.examplesKey,
    required this.icon,
  });

  static const List<GroundingStepSpec> steps54321 = [
    GroundingStepSpec(
      count: 5,
      titleKey: 'mw_ground_5_title',
      instructionKey: 'mw_ground_5_inst',
      examplesKey: 'mw_ground_5_ex',
      icon: Icons.visibility_outlined,
    ),
    GroundingStepSpec(
      count: 4,
      titleKey: 'mw_ground_4_title',
      instructionKey: 'mw_ground_4_inst',
      examplesKey: 'mw_ground_4_ex',
      icon: Icons.touch_app_outlined,
    ),
    GroundingStepSpec(
      count: 3,
      titleKey: 'mw_ground_3_title',
      instructionKey: 'mw_ground_3_inst',
      examplesKey: 'mw_ground_3_ex',
      icon: Icons.hearing_outlined,
    ),
    GroundingStepSpec(
      count: 2,
      titleKey: 'mw_ground_2_title',
      instructionKey: 'mw_ground_2_inst',
      examplesKey: 'mw_ground_2_ex',
      icon: Icons.air_outlined,
    ),
    GroundingStepSpec(
      count: 1,
      titleKey: 'mw_ground_1_title',
      instructionKey: 'mw_ground_1_inst',
      examplesKey: 'mw_ground_1_ex',
      icon: Icons.favorite_border_rounded,
    ),
  ];
}

/// Concrete low-friction micro-action option (`EFA-06`).
class SmallNextStepOption {
  final String id;
  final String titleKey;
  final String subtitleKey;
  final IconData icon;
  final bool logsHydrationGlass;

  const SmallNextStepOption({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
    this.logsHydrationGlass = false,
  });

  static const List<SmallNextStepOption> catalog = [
    SmallNextStepOption(
      id: 'drink_water',
      titleKey: 'mw_step_water_title',
      subtitleKey: 'mw_step_water_sub',
      icon: Icons.water_drop_outlined,
      logsHydrationGlass: true,
    ),
    SmallNextStepOption(
      id: 'step_outside',
      titleKey: 'mw_step_outside_title',
      subtitleKey: 'mw_step_outside_sub',
      icon: Icons.wb_sunny_outlined,
    ),
    SmallNextStepOption(
      id: 'short_walk',
      titleKey: 'mw_step_walk_title',
      subtitleKey: 'mw_step_walk_sub',
      icon: Icons.directions_walk_rounded,
    ),
    SmallNextStepOption(
      id: 'tidy_corner',
      titleKey: 'mw_step_tidy_title',
      subtitleKey: 'mw_step_tidy_sub',
      icon: Icons.cleaning_services_outlined,
    ),
    SmallNextStepOption(
      id: 'write_one_concern',
      titleKey: 'mw_step_write_title',
      subtitleKey: 'mw_step_write_sub',
      icon: Icons.edit_outlined,
    ),
    SmallNextStepOption(
      id: 'gentle_stretch',
      titleKey: 'mw_step_stretch_title',
      subtitleKey: 'mw_step_stretch_sub',
      icon: Icons.accessibility_new_rounded,
    ),
    SmallNextStepOption(
      id: 'rest_without_guilt',
      titleKey: 'mw_step_rest_title',
      subtitleKey: 'mw_step_rest_sub',
      icon: Icons.bedtime_outlined,
    ),
  ];
}

/// Kind of item pinned inside Seren's Comfort Kit (`EFA-07`).
enum ComfortKitItemKind {
  soundscape,
  breathing,
  grounding,
  encouragementNote,
  gratitudePebble,
  reading,
  echoMemory,
  comfortPhoto,
  externalBookmark,
}

/// User-curated calming item or note on the Comfort Kit shelf (`EFA-07`, `EFA-08`).
class ComfortKitItem {
  final String id;
  final ComfortKitItemKind kind;
  final String title;
  final String subtitle;
  final String? referenceId;
  final bool isPinned;
  final bool isCustomNote;
  final DateTime createdAt;

  const ComfortKitItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.referenceId,
    this.isPinned = true,
    this.isCustomNote = false,
    required this.createdAt,
  });

  ComfortKitItem copyWith({
    String? id,
    ComfortKitItemKind? kind,
    String? title,
    String? subtitle,
    String? referenceId,
    bool? isPinned,
    bool? isCustomNote,
    DateTime? createdAt,
  }) {
    return ComfortKitItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      referenceId: referenceId ?? this.referenceId,
      isPinned: isPinned ?? this.isPinned,
      isCustomNote: isCustomNote ?? this.isCustomNote,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'subtitle': subtitle,
        'referenceId': referenceId,
        'isPinned': isPinned,
        'isCustomNote': isCustomNote,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ComfortKitItem.fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind'] as String? ?? ComfortKitItemKind.grounding.name;
    final kind = ComfortKitItemKind.values.firstWhere(
      (k) => k.name == rawKind,
      orElse: () => ComfortKitItemKind.grounding,
    );
    return ComfortKitItem(
      id: json['id'] as String? ?? '',
      kind: kind,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      referenceId: json['referenceId'] as String?,
      isPinned: json['isPinned'] as bool? ?? true,
      isCustomNote: json['isCustomNote'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static List<ComfortKitItem> defaultStarterItems({DateTime? now}) {
    final stamp = now ?? DateTime.now();
    return [
      ComfortKitItem(
        id: 'starter_rain',
        kind: ComfortKitItemKind.soundscape,
        title: 'mw_kit_starter_rain_title',
        subtitle: 'mw_kit_starter_rain_sub',
        referenceId: 'rain',
        isPinned: true,
        isCustomNote: false,
        createdAt: stamp,
      ),
      ComfortKitItem(
        id: 'starter_breath',
        kind: ComfortKitItemKind.breathing,
        title: 'mw_kit_starter_breath_title',
        subtitle: 'mw_kit_starter_breath_sub',
        referenceId: 'breath_478',
        isPinned: true,
        isCustomNote: false,
        createdAt: stamp,
      ),
      ComfortKitItem(
        id: 'starter_grounding',
        kind: ComfortKitItemKind.grounding,
        title: 'mw_kit_starter_ground_title',
        subtitle: 'mw_kit_starter_ground_sub',
        referenceId: '54321',
        isPinned: true,
        isCustomNote: false,
        createdAt: stamp,
      ),
      ComfortKitItem(
        id: 'starter_note_grounded',
        kind: ComfortKitItemKind.encouragementNote,
        title: 'mw_kit_starter_note_title',
        subtitle: 'mw_kit_starter_note_sub',
        isPinned: true,
        isCustomNote: false,
        createdAt: stamp,
      ),
    ];
  }
}

/// Private vs ephemeral free-writing modes (`SU-04`, `SU-05`).
enum EphemeralWritingMode {
  letItOut,
  unsentLetter,
}

extension EphemeralWritingModeExt on EphemeralWritingMode {
  String get titleKey => this == EphemeralWritingMode.letItOut
      ? 'mw_let_it_out_title'
      : 'mw_unsent_letter_title';

  String get subtitleKey => this == EphemeralWritingMode.letItOut
      ? 'mw_let_it_out_sub'
      : 'mw_unsent_letter_sub';

  String get hintKey => this == EphemeralWritingMode.letItOut
      ? 'mw_let_it_out_hint'
      : 'mw_unsent_letter_hint';

  String get journalTag =>
      this == EphemeralWritingMode.letItOut ? 'LetItOut' : 'UnsentLetter';
}

/// Intention framing for Break the Cycle personal change goals (`BTC-01`).
enum ChangeIntentionType {
  reduce,
  stop,
  manage,
  replace,
  understand,
}

extension ChangeIntentionTypeExt on ChangeIntentionType {
  String get translationKey => 'btc_intention_$name';
}

/// User-defined behavioral commitment + personal motivation ("My Why") (`BTC-01`).
/// Deliberately contains ZERO days-clean counters, abstinence streaks, or failure counts.
class PersonalCommitmentGoal {
  final String id;
  final String behaviorTitle;
  final ChangeIntentionType intention;
  final String myWhy;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PersonalCommitmentGoal({
    required this.id,
    required this.behaviorTitle,
    required this.intention,
    required this.myWhy,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  PersonalCommitmentGoal copyWith({
    String? id,
    String? behaviorTitle,
    ChangeIntentionType? intention,
    String? myWhy,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PersonalCommitmentGoal(
      id: id ?? this.id,
      behaviorTitle: behaviorTitle ?? this.behaviorTitle,
      intention: intention ?? this.intention,
      myWhy: myWhy ?? this.myWhy,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'behaviorTitle': behaviorTitle,
        'intention': intention.name,
        'myWhy': myWhy,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PersonalCommitmentGoal.fromJson(Map<String, dynamic> json) {
    final rawIntention =
        json['intention'] as String? ?? ChangeIntentionType.manage.name;
    final intention = ChangeIntentionType.values.firstWhere(
      (v) => v.name == rawIntention,
      orElse: () => ChangeIntentionType.manage,
    );
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    return PersonalCommitmentGoal(
      id: json['id'] as String? ?? '',
      behaviorTitle: json['behaviorTitle'] as String? ?? '',
      intention: intention,
      myWhy: json['myWhy'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }
}

/// Configuration for `BTC-02` Mindful App Pause (intention check without URL inspection).
class MindfulAppPauseConfig {
  final bool isEnabled;
  final List<String> monitoredPackages;
  final Map<String, String> monitoredAppNames;
  final int pauseDurationSeconds;
  final int cooldownGraceMinutes;
  final bool vulnerableHoursOnly;
  final int vulnerableStartHour;
  final int vulnerableEndHour;
  final DateTime? snoozedUntil;

  const MindfulAppPauseConfig({
    this.isEnabled = false,
    this.monitoredPackages = const [],
    this.monitoredAppNames = const {},
    this.pauseDurationSeconds = 4,
    this.cooldownGraceMinutes = 15,
    this.vulnerableHoursOnly = false,
    this.vulnerableStartHour = 22,
    this.vulnerableEndHour = 6,
    this.snoozedUntil,
  });

  /// Returns `true` when [now] falls inside the configured vulnerable window.
  /// Handles both cross-midnight ranges (e.g. `22..6`) and same-day ranges (`14..18`).
  bool isWithinVulnerableWindow(DateTime now) {
    final start = vulnerableStartHour.clamp(0, 23);
    final end = vulnerableEndHour.clamp(0, 23);
    final hour = now.hour;
    if (start == end) return true;
    if (start > end) {
      return hour >= start || hour < end;
    }
    return hour >= start && hour < end;
  }

  /// Returns `true` when intention checks are temporarily snoozed at [now].
  bool isSnoozedAt(DateTime now) =>
      snoozedUntil != null && snoozedUntil!.isAfter(now);

  MindfulAppPauseConfig copyWith({
    bool? isEnabled,
    List<String>? monitoredPackages,
    Map<String, String>? monitoredAppNames,
    int? pauseDurationSeconds,
    int? cooldownGraceMinutes,
    bool? vulnerableHoursOnly,
    int? vulnerableStartHour,
    int? vulnerableEndHour,
    DateTime? snoozedUntil,
    bool clearSnoozedUntil = false,
  }) {
    return MindfulAppPauseConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      monitoredPackages: monitoredPackages ?? this.monitoredPackages,
      monitoredAppNames: monitoredAppNames ?? this.monitoredAppNames,
      pauseDurationSeconds:
          (pauseDurationSeconds ?? this.pauseDurationSeconds).clamp(3, 5),
      cooldownGraceMinutes:
          (cooldownGraceMinutes ?? this.cooldownGraceMinutes).clamp(1, 180),
      vulnerableHoursOnly: vulnerableHoursOnly ?? this.vulnerableHoursOnly,
      vulnerableStartHour:
          (vulnerableStartHour ?? this.vulnerableStartHour).clamp(0, 23),
      vulnerableEndHour:
          (vulnerableEndHour ?? this.vulnerableEndHour).clamp(0, 23),
      snoozedUntil:
          clearSnoozedUntil ? null : (snoozedUntil ?? this.snoozedUntil),
    );
  }

  Map<String, dynamic> toJson() => {
        'isEnabled': isEnabled,
        'monitoredPackages': monitoredPackages,
        'monitoredAppNames': monitoredAppNames,
        'pauseDurationSeconds': pauseDurationSeconds,
        'cooldownGraceMinutes': cooldownGraceMinutes,
        'vulnerableHoursOnly': vulnerableHoursOnly,
        'vulnerableStartHour': vulnerableStartHour,
        'vulnerableEndHour': vulnerableEndHour,
        'snoozedUntil': snoozedUntil?.toIso8601String(),
      };

  factory MindfulAppPauseConfig.fromJson(Map<String, dynamic> json) {
    final rawNames = json['monitoredAppNames'];
    final names = <String, String>{};
    if (rawNames is Map) {
      for (final e in rawNames.entries) {
        names[e.key.toString()] = e.value.toString();
      }
    }
    return MindfulAppPauseConfig(
      isEnabled: json['isEnabled'] as bool? ?? false,
      monitoredPackages: (json['monitoredPackages'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      monitoredAppNames: names,
      pauseDurationSeconds:
          ((json['pauseDurationSeconds'] as num?)?.toInt() ?? 4).clamp(3, 5),
      cooldownGraceMinutes:
          ((json['cooldownGraceMinutes'] as num?)?.toInt() ?? 15).clamp(1, 180),
      vulnerableHoursOnly: json['vulnerableHoursOnly'] as bool? ?? false,
      vulnerableStartHour:
          ((json['vulnerableStartHour'] as num?)?.toInt() ?? 22).clamp(0, 23),
      vulnerableEndHour:
          ((json['vulnerableEndHour'] as num?)?.toInt() ?? 6).clamp(0, 23),
      snoozedUntil: json['snoozedUntil'] is String
          ? DateTime.tryParse(json['snoozedUntil'] as String)
          : null,
    );
  }
}

/// 5-step guided Urge Surfing observation flow (`BTC-03`).
class UrgeSurfingStepSpec {
  final int stepNumber;
  final String titleKey;
  final String guidanceKey;

  const UrgeSurfingStepSpec({
    required this.stepNumber,
    required this.titleKey,
    required this.guidanceKey,
  });

  static const List<UrgeSurfingStepSpec> steps = [
    UrgeSurfingStepSpec(
      stepNumber: 1,
      titleKey: 'btc_surf_1_title',
      guidanceKey: 'btc_surf_1_desc',
    ),
    UrgeSurfingStepSpec(
      stepNumber: 2,
      titleKey: 'btc_surf_2_title',
      guidanceKey: 'btc_surf_2_desc',
    ),
    UrgeSurfingStepSpec(
      stepNumber: 3,
      titleKey: 'btc_surf_3_title',
      guidanceKey: 'btc_surf_3_desc',
    ),
    UrgeSurfingStepSpec(
      stepNumber: 4,
      titleKey: 'btc_surf_4_title',
      guidanceKey: 'btc_surf_4_desc',
    ),
    UrgeSurfingStepSpec(
      stepNumber: 5,
      titleKey: 'btc_surf_5_title',
      guidanceKey: 'btc_surf_5_desc',
    ),
  ];
}

/// Voluntary circumstance & habit-pattern reflection (`BTC-04`, `BTC-05`).
class TriggerReflectionEntry {
  final String id;
  final String? commitmentId;
  final DateTime createdAt;
  final String locationLabel;
  final String currentActivity;
  final String emotionalState;
  final String environmentNote;
  final String whatHappenedBefore;
  final String whatINeeded;
  final String tryDifferentlyNextTime;
  final String? savedToEchoEntryId;

  const TriggerReflectionEntry({
    required this.id,
    this.commitmentId,
    required this.createdAt,
    this.locationLabel = '',
    this.currentActivity = '',
    this.emotionalState = '',
    this.environmentNote = '',
    this.whatHappenedBefore = '',
    this.whatINeeded = '',
    this.tryDifferentlyNextTime = '',
    this.savedToEchoEntryId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'commitmentId': commitmentId,
        'createdAt': createdAt.toIso8601String(),
        'locationLabel': locationLabel,
        'currentActivity': currentActivity,
        'emotionalState': emotionalState,
        'environmentNote': environmentNote,
        'whatHappenedBefore': whatHappenedBefore,
        'whatINeeded': whatINeeded,
        'tryDifferentlyNextTime': tryDifferentlyNextTime,
        'savedToEchoEntryId': savedToEchoEntryId,
      };

  factory TriggerReflectionEntry.fromJson(Map<String, dynamic> json) {
    return TriggerReflectionEntry(
      id: json['id'] as String? ?? '',
      commitmentId: json['commitmentId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      locationLabel: json['locationLabel'] as String? ?? '',
      currentActivity: json['currentActivity'] as String? ?? '',
      emotionalState: json['emotionalState'] as String? ?? '',
      environmentNote: json['environmentNote'] as String? ?? '',
      whatHappenedBefore: json['whatHappenedBefore'] as String? ?? '',
      whatINeeded: json['whatINeeded'] as String? ?? '',
      tryDifferentlyNextTime: json['tryDifferentlyNextTime'] as String? ?? '',
      savedToEchoEntryId: json['savedToEchoEntryId'] as String?,
    );
  }
}

/// Seven need-based categories for Healthy Alternatives (`BTC-06`, `HL-01`).
enum HealthyAlternativeCategory {
  stimulation,
  relaxation,
  movement,
  connection,
  mentalEscape,
  accomplishment,
  creativeExpression,
}

extension HealthyAlternativeCategoryExt on HealthyAlternativeCategory {
  String get translationKey => 'btc_alt_cat_$name';
}

class HealthyAlternativeSpec {
  final String id;
  final HealthyAlternativeCategory category;
  final String titleKey;
  final String subtitleKey;
  final String companionBird;
  final IconData icon;

  const HealthyAlternativeSpec({
    required this.id,
    required this.category,
    required this.titleKey,
    required this.subtitleKey,
    required this.companionBird,
    required this.icon,
  });

  static const List<HealthyAlternativeSpec> catalog = [
    HealthyAlternativeSpec(
      id: 'alt_soundscape',
      category: HealthyAlternativeCategory.relaxation,
      titleKey: 'btc_alt_soundscape_title',
      subtitleKey: 'btc_alt_soundscape_sub',
      companionBird: 'Seren',
      icon: Icons.surround_sound_rounded,
    ),
    HealthyAlternativeSpec(
      id: 'alt_short_walk',
      category: HealthyAlternativeCategory.movement,
      titleKey: 'btc_alt_walk_title',
      subtitleKey: 'btc_alt_walk_sub',
      companionBird: 'Seren',
      icon: Icons.directions_walk_rounded,
    ),
    HealthyAlternativeSpec(
      id: 'alt_stretch',
      category: HealthyAlternativeCategory.movement,
      titleKey: 'btc_alt_stretch_title',
      subtitleKey: 'btc_alt_stretch_sub',
      companionBird: 'Seren',
      icon: Icons.accessibility_new_rounded,
    ),
    HealthyAlternativeSpec(
      id: 'alt_read_pages',
      category: HealthyAlternativeCategory.mentalEscape,
      titleKey: 'btc_alt_read_title',
      subtitleKey: 'btc_alt_read_sub',
      companionBird: 'Pippin',
      icon: Icons.menu_book_rounded,
    ),
    HealthyAlternativeSpec(
      id: 'alt_sketch_hobby',
      category: HealthyAlternativeCategory.creativeExpression,
      titleKey: 'btc_alt_hobby_title',
      subtitleKey: 'btc_alt_hobby_sub',
      companionBird: 'Pippin',
      icon: Icons.brush_rounded,
    ),
    HealthyAlternativeSpec(
      id: 'alt_puzzle_spark',
      category: HealthyAlternativeCategory.stimulation,
      titleKey: 'btc_alt_puzzle_title',
      subtitleKey: 'btc_alt_puzzle_sub',
      companionBird: 'Pippin',
      icon: Icons.extension_outlined,
    ),
    HealthyAlternativeSpec(
      id: 'alt_small_task',
      category: HealthyAlternativeCategory.accomplishment,
      titleKey: 'btc_alt_task_title',
      subtitleKey: 'btc_alt_task_sub',
      companionBird: 'Roo',
      icon: Icons.check_circle_outline_rounded,
    ),
    HealthyAlternativeSpec(
      id: 'alt_message_friend',
      category: HealthyAlternativeCategory.connection,
      titleKey: 'btc_alt_connect_title',
      subtitleKey: 'btc_alt_connect_sub',
      companionBird: 'Echo',
      icon: Icons.chat_bubble_outline_rounded,
    ),
  ];
}

/// Immediate physical-space shift prompt (`BTC-07`).
class EnvironmentResetSpec {
  final String id;
  final String titleKey;
  final String subtitleKey;
  final IconData icon;

  const EnvironmentResetSpec({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
  });

  static const List<EnvironmentResetSpec> catalog = [
    EnvironmentResetSpec(
      id: 'leave_room',
      titleKey: 'btc_env_leave_room_title',
      subtitleKey: 'btc_env_leave_room_sub',
      icon: Icons.meeting_room_outlined,
    ),
    EnvironmentResetSpec(
      id: 'phone_another_room',
      titleKey: 'btc_env_phone_away_title',
      subtitleKey: 'btc_env_phone_away_sub',
      icon: Icons.phonelink_off_rounded,
    ),
    EnvironmentResetSpec(
      id: 'move_shared_space',
      titleKey: 'btc_env_shared_space_title',
      subtitleKey: 'btc_env_shared_space_sub',
      icon: Icons.weekend_outlined,
    ),
    EnvironmentResetSpec(
      id: 'short_outdoor_walk',
      titleKey: 'btc_env_outdoor_title',
      subtitleKey: 'btc_env_outdoor_sub',
      icon: Icons.park_outlined,
    ),
    EnvironmentResetSpec(
      id: 'cold_water_stretch',
      titleKey: 'btc_env_water_stretch_title',
      subtitleKey: 'btc_env_water_stretch_sub',
      icon: Icons.wash_outlined,
    ),
  ];
}

/// User-defined adjustable everyday boundary (`BTC-08`).
class PersonalBoundaryItem {
  final String id;
  final String title;
  final String categoryKey;
  final bool isActive;
  final bool linksToTwillBudget;

  const PersonalBoundaryItem({
    required this.id,
    required this.title,
    this.categoryKey = 'btc_boundary_cat_daily',
    this.isActive = true,
    this.linksToTwillBudget = false,
  });

  PersonalBoundaryItem copyWith({
    String? id,
    String? title,
    String? categoryKey,
    bool? isActive,
    bool? linksToTwillBudget,
  }) {
    return PersonalBoundaryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      categoryKey: categoryKey ?? this.categoryKey,
      isActive: isActive ?? this.isActive,
      linksToTwillBudget: linksToTwillBudget ?? this.linksToTwillBudget,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'categoryKey': categoryKey,
        'isActive': isActive,
        'linksToTwillBudget': linksToTwillBudget,
      };

  factory PersonalBoundaryItem.fromJson(Map<String, dynamic> json) {
    return PersonalBoundaryItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      categoryKey:
          json['categoryKey'] as String? ?? 'btc_boundary_cat_daily',
      isActive: json['isActive'] as bool? ?? true,
      linksToTwillBudget: json['linksToTwillBudget'] as bool? ?? false,
    );
  }

  static List<PersonalBoundaryItem> defaultBoundaries() => const [
        PersonalBoundaryItem(
          id: 'bound_no_phone_bed',
          title: 'btc_default_boundary_bed',
          categoryKey: 'btc_boundary_cat_sleep',
          isActive: true,
        ),
        PersonalBoundaryItem(
          id: 'bound_no_social_meals',
          title: 'btc_default_boundary_meals',
          categoryKey: 'btc_boundary_cat_daily',
          isActive: true,
        ),
        PersonalBoundaryItem(
          id: 'bound_twill_pause',
          title: 'btc_default_boundary_spend',
          categoryKey: 'btc_boundary_cat_spending',
          isActive: false,
          linksToTwillBudget: true,
        ),
        PersonalBoundaryItem(
          id: 'bound_gaming_cutoff',
          title: 'btc_default_boundary_gaming',
          categoryKey: 'btc_boundary_cat_evening',
          isActive: false,
        ),
      ];
}

/// Shame-free voluntary post-setback reflection (`BTC-09`).
/// Never resets progress or displays punitive failure messages.
class RecoveryReflectionEntry {
  final String id;
  final String? commitmentId;
  final DateTime createdAt;
  final String whatHappened;
  final String underlyingNeedOrFeeling;
  final String selfCompassionNote;
  final String nextSmallAdjustment;
  final String? savedToEchoEntryId;

  const RecoveryReflectionEntry({
    required this.id,
    this.commitmentId,
    required this.createdAt,
    this.whatHappened = '',
    this.underlyingNeedOrFeeling = '',
    this.selfCompassionNote = '',
    this.nextSmallAdjustment = '',
    this.savedToEchoEntryId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'commitmentId': commitmentId,
        'createdAt': createdAt.toIso8601String(),
        'whatHappened': whatHappened,
        'underlyingNeedOrFeeling': underlyingNeedOrFeeling,
        'selfCompassionNote': selfCompassionNote,
        'nextSmallAdjustment': nextSmallAdjustment,
        'savedToEchoEntryId': savedToEchoEntryId,
      };

  factory RecoveryReflectionEntry.fromJson(Map<String, dynamic> json) {
    return RecoveryReflectionEntry(
      id: json['id'] as String? ?? '',
      commitmentId: json['commitmentId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      whatHappened: json['whatHappened'] as String? ?? '',
      underlyingNeedOrFeeling:
          json['underlyingNeedOrFeeling'] as String? ?? '',
      selfCompassionNote: json['selfCompassionNote'] as String? ?? '',
      nextSmallAdjustment: json['nextSmallAdjustment'] as String? ?? '',
      savedToEchoEntryId: json['savedToEchoEntryId'] as String?,
    );
  }
}

/// Non-competitive qualitative change metrics (`BTC-10`).
/// Monotonic reflective counts—never decremented or reset on setbacks.
class QualitativeChangeProgress {
  final int reflectionsCompletedCount;
  final int strategiesTriedCount;
  final int goalsShapedCount;
  final int triggersUnderstoodCount;
  final int alternativesExploredCount;
  final int groundingSessionsCompletedCount;

  const QualitativeChangeProgress({
    this.reflectionsCompletedCount = 0,
    this.strategiesTriedCount = 0,
    this.goalsShapedCount = 0,
    this.triggersUnderstoodCount = 0,
    this.alternativesExploredCount = 0,
    this.groundingSessionsCompletedCount = 0,
  });

  QualitativeChangeProgress copyWith({
    int? reflectionsCompletedCount,
    int? strategiesTriedCount,
    int? goalsShapedCount,
    int? triggersUnderstoodCount,
    int? alternativesExploredCount,
    int? groundingSessionsCompletedCount,
  }) {
    return QualitativeChangeProgress(
      reflectionsCompletedCount:
          reflectionsCompletedCount ?? this.reflectionsCompletedCount,
      strategiesTriedCount: strategiesTriedCount ?? this.strategiesTriedCount,
      goalsShapedCount: goalsShapedCount ?? this.goalsShapedCount,
      triggersUnderstoodCount:
          triggersUnderstoodCount ?? this.triggersUnderstoodCount,
      alternativesExploredCount:
          alternativesExploredCount ?? this.alternativesExploredCount,
      groundingSessionsCompletedCount: groundingSessionsCompletedCount ??
          this.groundingSessionsCompletedCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'reflectionsCompletedCount': reflectionsCompletedCount,
        'strategiesTriedCount': strategiesTriedCount,
        'goalsShapedCount': goalsShapedCount,
        'triggersUnderstoodCount': triggersUnderstoodCount,
        'alternativesExploredCount': alternativesExploredCount,
        'groundingSessionsCompletedCount': groundingSessionsCompletedCount,
      };

  factory QualitativeChangeProgress.fromJson(Map<String, dynamic> json) {
    return QualitativeChangeProgress(
      reflectionsCompletedCount:
          (json['reflectionsCompletedCount'] as num?)?.toInt() ?? 0,
      strategiesTriedCount:
          (json['strategiesTriedCount'] as num?)?.toInt() ?? 0,
      goalsShapedCount: (json['goalsShapedCount'] as num?)?.toInt() ?? 0,
      triggersUnderstoodCount:
          (json['triggersUnderstoodCount'] as num?)?.toInt() ?? 0,
      alternativesExploredCount:
          (json['alternativesExploredCount'] as num?)?.toInt() ?? 0,
      groundingSessionsCompletedCount:
          (json['groundingSessionsCompletedCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Private user-authored relapse prevention & preparation plan (`BTC-11`).
class RelapsePreventionPlan {
  final String knownTriggers;
  final String vulnerableSituations;
  final String goToAlternatives;
  final String personalBoundariesSummary;
  final String trustedPersonNote;
  final String compassionatePostSetbackNote;
  final DateTime? updatedAt;

  const RelapsePreventionPlan({
    this.knownTriggers = '',
    this.vulnerableSituations = '',
    this.goToAlternatives = '',
    this.personalBoundariesSummary = '',
    this.trustedPersonNote = '',
    this.compassionatePostSetbackNote = '',
    this.updatedAt,
  });

  bool get hasContent =>
      knownTriggers.trim().isNotEmpty ||
      vulnerableSituations.trim().isNotEmpty ||
      goToAlternatives.trim().isNotEmpty ||
      personalBoundariesSummary.trim().isNotEmpty ||
      trustedPersonNote.trim().isNotEmpty ||
      compassionatePostSetbackNote.trim().isNotEmpty;

  RelapsePreventionPlan copyWith({
    String? knownTriggers,
    String? vulnerableSituations,
    String? goToAlternatives,
    String? personalBoundariesSummary,
    String? trustedPersonNote,
    String? compassionatePostSetbackNote,
    DateTime? updatedAt,
  }) {
    return RelapsePreventionPlan(
      knownTriggers: knownTriggers ?? this.knownTriggers,
      vulnerableSituations: vulnerableSituations ?? this.vulnerableSituations,
      goToAlternatives: goToAlternatives ?? this.goToAlternatives,
      personalBoundariesSummary:
          personalBoundariesSummary ?? this.personalBoundariesSummary,
      trustedPersonNote: trustedPersonNote ?? this.trustedPersonNote,
      compassionatePostSetbackNote:
          compassionatePostSetbackNote ?? this.compassionatePostSetbackNote,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'knownTriggers': knownTriggers,
        'vulnerableSituations': vulnerableSituations,
        'goToAlternatives': goToAlternatives,
        'personalBoundariesSummary': personalBoundariesSummary,
        'trustedPersonNote': trustedPersonNote,
        'compassionatePostSetbackNote': compassionatePostSetbackNote,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory RelapsePreventionPlan.fromJson(Map<String, dynamic> json) {
    return RelapsePreventionPlan(
      knownTriggers: json['knownTriggers'] as String? ?? '',
      vulnerableSituations: json['vulnerableSituations'] as String? ?? '',
      goToAlternatives: json['goToAlternatives'] as String? ?? '',
      personalBoundariesSummary:
          json['personalBoundariesSummary'] as String? ?? '',
      trustedPersonNote: json['trustedPersonNote'] as String? ?? '',
      compassionatePostSetbackNote:
          json['compassionatePostSetbackNote'] as String? ?? '',
      updatedAt: json['updatedAt'] is String
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}

/// Preferred contact launch channel for Trusted Contacts (`GS-01`, `GS-02`).
enum TrustedContactChannel {
  sms,
  whatsapp,
  call,
}

extension TrustedContactChannelExt on TrustedContactChannel {
  String get translationKey => 'gs_channel_$name';
}

/// Local-only Trusted Contact for stigma-free human support (`GS-01`, `GS-02`).
class TrustedContact {
  final String id;
  final String name;
  final String relationshipLabel;
  final String phoneOrHandle;
  final TrustedContactChannel preferredChannel;
  final String note;
  final bool isPrimary;
  final DateTime createdAt;

  const TrustedContact({
    required this.id,
    required this.name,
    this.relationshipLabel = '',
    required this.phoneOrHandle,
    this.preferredChannel = TrustedContactChannel.sms,
    this.note = '',
    this.isPrimary = false,
    required this.createdAt,
  });

  TrustedContact copyWith({
    String? id,
    String? name,
    String? relationshipLabel,
    String? phoneOrHandle,
    TrustedContactChannel? preferredChannel,
    String? note,
    bool? isPrimary,
    DateTime? createdAt,
  }) {
    return TrustedContact(
      id: id ?? this.id,
      name: name ?? this.name,
      relationshipLabel: relationshipLabel ?? this.relationshipLabel,
      phoneOrHandle: phoneOrHandle ?? this.phoneOrHandle,
      preferredChannel: preferredChannel ?? this.preferredChannel,
      note: note ?? this.note,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'relationshipLabel': relationshipLabel,
        'phoneOrHandle': phoneOrHandle,
        'preferredChannel': preferredChannel.name,
        'note': note,
        'isPrimary': isPrimary,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TrustedContact.fromJson(Map<String, dynamic> json) {
    final rawChannel =
        json['preferredChannel'] as String? ?? TrustedContactChannel.sms.name;
    final channel = TrustedContactChannel.values.firstWhere(
      (c) => c.name == rawChannel,
      orElse: () => TrustedContactChannel.sms,
    );
    return TrustedContact(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      relationshipLabel: json['relationshipLabel'] as String? ?? '',
      phoneOrHandle: json['phoneOrHandle'] as String? ?? '',
      preferredChannel: channel,
      note: json['note'] as String? ?? '',
      isPrimary: json['isPrimary'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Low-pressure starter or user-written message template (`GS-03`).
class SupportMessageTemplate {
  final String id;
  final String title;
  final String messageBody;
  final bool isCustom;
  final DateTime createdAt;

  const SupportMessageTemplate({
    required this.id,
    required this.title,
    required this.messageBody,
    this.isCustom = false,
    required this.createdAt,
  });

  SupportMessageTemplate copyWith({
    String? id,
    String? title,
    String? messageBody,
    bool? isCustom,
    DateTime? createdAt,
  }) {
    return SupportMessageTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      messageBody: messageBody ?? this.messageBody,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messageBody': messageBody,
        'isCustom': isCustom,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SupportMessageTemplate.fromJson(Map<String, dynamic> json) {
    return SupportMessageTemplate(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      messageBody: json['messageBody'] as String? ?? '',
      isCustom: json['isCustom'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static List<SupportMessageTemplate> defaultTemplates({DateTime? now}) {
    final stamp = now ?? DateTime.now();
    return [
      SupportMessageTemplate(
        id: 'tpl_difficult_day',
        title: 'gs_tpl_difficult_title',
        messageBody: 'gs_tpl_difficult_body',
        isCustom: false,
        createdAt: stamp,
      ),
      SupportMessageTemplate(
        id: 'tpl_just_listen',
        title: 'gs_tpl_listen_title',
        messageBody: 'gs_tpl_listen_body',
        isCustom: false,
        createdAt: stamp,
      ),
      SupportMessageTemplate(
        id: 'tpl_spend_time',
        title: 'gs_tpl_time_title',
        messageBody: 'gs_tpl_time_body',
        isCustom: false,
        createdAt: stamp,
      ),
      SupportMessageTemplate(
        id: 'tpl_need_help',
        title: 'gs_tpl_help_title',
        messageBody: 'gs_tpl_help_body',
        isCustom: false,
        createdAt: stamp,
      ),
    ];
  }
}

/// Private local Personal Support Plan (`GS-07`).
class PersonalSupportPlan {
  final List<String> trustedContactIds;
  final String preferredWaysToAskForHelp;
  final String personalCopingStrategies;
  final String helpfulResources;
  final String postSetbackOrEmergencySteps;
  final DateTime? updatedAt;

  const PersonalSupportPlan({
    this.trustedContactIds = const [],
    this.preferredWaysToAskForHelp = '',
    this.personalCopingStrategies = '',
    this.helpfulResources = '',
    this.postSetbackOrEmergencySteps = '',
    this.updatedAt,
  });

  bool get hasContent =>
      trustedContactIds.isNotEmpty ||
      preferredWaysToAskForHelp.trim().isNotEmpty ||
      personalCopingStrategies.trim().isNotEmpty ||
      helpfulResources.trim().isNotEmpty ||
      postSetbackOrEmergencySteps.trim().isNotEmpty;

  PersonalSupportPlan copyWith({
    List<String>? trustedContactIds,
    String? preferredWaysToAskForHelp,
    String? personalCopingStrategies,
    String? helpfulResources,
    String? postSetbackOrEmergencySteps,
    DateTime? updatedAt,
  }) {
    return PersonalSupportPlan(
      trustedContactIds: trustedContactIds ?? this.trustedContactIds,
      preferredWaysToAskForHelp:
          preferredWaysToAskForHelp ?? this.preferredWaysToAskForHelp,
      personalCopingStrategies:
          personalCopingStrategies ?? this.personalCopingStrategies,
      helpfulResources: helpfulResources ?? this.helpfulResources,
      postSetbackOrEmergencySteps:
          postSetbackOrEmergencySteps ?? this.postSetbackOrEmergencySteps,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'trustedContactIds': trustedContactIds,
        'preferredWaysToAskForHelp': preferredWaysToAskForHelp,
        'personalCopingStrategies': personalCopingStrategies,
        'helpfulResources': helpfulResources,
        'postSetbackOrEmergencySteps': postSetbackOrEmergencySteps,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory PersonalSupportPlan.fromJson(Map<String, dynamic> json) {
    return PersonalSupportPlan(
      trustedContactIds: (json['trustedContactIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      preferredWaysToAskForHelp:
          json['preferredWaysToAskForHelp'] as String? ?? '',
      personalCopingStrategies:
          json['personalCopingStrategies'] as String? ?? '',
      helpfulResources: json['helpfulResources'] as String? ?? '',
      postSetbackOrEmergencySteps:
          json['postSetbackOrEmergencySteps'] as String? ?? '',
      updatedAt: json['updatedAt'] is String
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}

/// Categories for Seren Level 3 curated offline Educational Library (`SU-08`, `GS-06`).
enum EducationalGuideCategory {
  emotions,
  stress,
  selfCompassion,
  boundaries,
  habitMechanics,
  copingStrategies,
  professionalSupport,
}

extension EducationalGuideCategoryExt on EducationalGuideCategory {
  String get translationKey => 'mw_l3_guide_cat_$name';
}

/// Offline-bundled plain-language non-clinical educational guide (`SU-08`, `GS-06`).
class EducationalGuideSpec {
  final String id;
  final EducationalGuideCategory category;
  final String titleKey;
  final String summaryKey;
  final List<String> sectionHeadingKeys;
  final List<String> sectionBodyKeys;
  final String nonClinicalNoteKey;
  final String reflectionPromptKey;
  final IconData icon;

  const EducationalGuideSpec({
    required this.id,
    required this.category,
    required this.titleKey,
    required this.summaryKey,
    required this.sectionHeadingKeys,
    required this.sectionBodyKeys,
    required this.nonClinicalNoteKey,
    required this.reflectionPromptKey,
    required this.icon,
  });

  static const List<EducationalGuideSpec> catalog = [
    EducationalGuideSpec(
      id: 'guide_emotions',
      category: EducationalGuideCategory.emotions,
      titleKey: 'su_guide_emotions_title',
      summaryKey: 'su_guide_emotions_summary',
      sectionHeadingKeys: [
        'su_guide_emotions_h1',
        'su_guide_emotions_h2',
        'su_guide_emotions_h3',
      ],
      sectionBodyKeys: [
        'su_guide_emotions_b1',
        'su_guide_emotions_b2',
        'su_guide_emotions_b3',
      ],
      nonClinicalNoteKey: 'mw_l3_nonclinical_disclaimer',
      reflectionPromptKey: 'su_guide_emotions_prompt',
      icon: Icons.water_drop_outlined,
    ),
    EducationalGuideSpec(
      id: 'guide_stress',
      category: EducationalGuideCategory.stress,
      titleKey: 'su_guide_stress_title',
      summaryKey: 'su_guide_stress_summary',
      sectionHeadingKeys: [
        'su_guide_stress_h1',
        'su_guide_stress_h2',
        'su_guide_stress_h3',
      ],
      sectionBodyKeys: [
        'su_guide_stress_b1',
        'su_guide_stress_b2',
        'su_guide_stress_b3',
      ],
      nonClinicalNoteKey: 'mw_l3_nonclinical_disclaimer',
      reflectionPromptKey: 'su_guide_stress_prompt',
      icon: Icons.speed_rounded,
    ),
    EducationalGuideSpec(
      id: 'guide_self_compassion',
      category: EducationalGuideCategory.selfCompassion,
      titleKey: 'su_guide_compassion_title',
      summaryKey: 'su_guide_compassion_summary',
      sectionHeadingKeys: [
        'su_guide_compassion_h1',
        'su_guide_compassion_h2',
        'su_guide_compassion_h3',
      ],
      sectionBodyKeys: [
        'su_guide_compassion_b1',
        'su_guide_compassion_b2',
        'su_guide_compassion_b3',
      ],
      nonClinicalNoteKey: 'mw_l3_nonclinical_disclaimer',
      reflectionPromptKey: 'su_guide_compassion_prompt',
      icon: Icons.volunteer_activism_outlined,
    ),
    EducationalGuideSpec(
      id: 'guide_boundaries',
      category: EducationalGuideCategory.boundaries,
      titleKey: 'su_guide_boundaries_title',
      summaryKey: 'su_guide_boundaries_summary',
      sectionHeadingKeys: [
        'su_guide_boundaries_h1',
        'su_guide_boundaries_h2',
        'su_guide_boundaries_h3',
      ],
      sectionBodyKeys: [
        'su_guide_boundaries_b1',
        'su_guide_boundaries_b2',
        'su_guide_boundaries_b3',
      ],
      nonClinicalNoteKey: 'mw_l3_nonclinical_disclaimer',
      reflectionPromptKey: 'su_guide_boundaries_prompt',
      icon: Icons.fence_outlined,
    ),
    EducationalGuideSpec(
      id: 'guide_habit_loop',
      category: EducationalGuideCategory.habitMechanics,
      titleKey: 'su_guide_habits_title',
      summaryKey: 'su_guide_habits_summary',
      sectionHeadingKeys: [
        'su_guide_habits_h1',
        'su_guide_habits_h2',
        'su_guide_habits_h3',
      ],
      sectionBodyKeys: [
        'su_guide_habits_b1',
        'su_guide_habits_b2',
        'su_guide_habits_b3',
      ],
      nonClinicalNoteKey: 'mw_l3_nonclinical_disclaimer',
      reflectionPromptKey: 'su_guide_habits_prompt',
      icon: Icons.loop_rounded,
    ),
    EducationalGuideSpec(
      id: 'guide_coping',
      category: EducationalGuideCategory.copingStrategies,
      titleKey: 'su_guide_coping_title',
      summaryKey: 'su_guide_coping_summary',
      sectionHeadingKeys: [
        'su_guide_coping_h1',
        'su_guide_coping_h2',
        'su_guide_coping_h3',
      ],
      sectionBodyKeys: [
        'su_guide_coping_b1',
        'su_guide_coping_b2',
        'su_guide_coping_b3',
      ],
      nonClinicalNoteKey: 'mw_l3_nonclinical_disclaimer',
      reflectionPromptKey: 'su_guide_coping_prompt',
      icon: Icons.shield_moon_outlined,
    ),
    EducationalGuideSpec(
      id: 'guide_professional_care',
      category: EducationalGuideCategory.professionalSupport,
      titleKey: 'su_guide_prof_title',
      summaryKey: 'su_guide_prof_summary',
      sectionHeadingKeys: [
        'su_guide_prof_h1',
        'su_guide_prof_h2',
        'su_guide_prof_h3',
      ],
      sectionBodyKeys: [
        'su_guide_prof_b1',
        'su_guide_prof_b2',
        'su_guide_prof_b3',
      ],
      nonClinicalNoteKey: 'mw_l3_nonclinical_disclaimer',
      reflectionPromptKey: 'su_guide_prof_prompt',
      icon: Icons.handshake_outlined,
    ),
  ];
}

/// User-authored Personal Insight observation (`SU-09`).
/// Strictly user-defined; zero automated diagnosis, scoring, or profiling.
class PersonalInsightNote {
  final String id;
  final String title;
  final String observation;
  final String? relatedGuideId;
  final DateTime createdAt;

  const PersonalInsightNote({
    required this.id,
    required this.title,
    required this.observation,
    this.relatedGuideId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'observation': observation,
        'relatedGuideId': relatedGuideId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PersonalInsightNote.fromJson(Map<String, dynamic> json) {
    return PersonalInsightNote(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      observation: json['observation'] as String? ?? '',
      relatedGuideId: json['relatedGuideId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Flexible, guilt-free Personal Well-being Goal (`HL-07`).
class PersonalWellbeingGoal {
  final String id;
  final String title;
  final String categoryKey;
  final bool isActive;
  final DateTime createdAt;

  const PersonalWellbeingGoal({
    required this.id,
    required this.title,
    this.categoryKey = 'mw_l3_goal_cat_balance',
    this.isActive = true,
    required this.createdAt,
  });

  PersonalWellbeingGoal copyWith({
    String? id,
    String? title,
    String? categoryKey,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return PersonalWellbeingGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      categoryKey: categoryKey ?? this.categoryKey,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'categoryKey': categoryKey,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PersonalWellbeingGoal.fromJson(Map<String, dynamic> json) {
    return PersonalWellbeingGoal(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      categoryKey:
          json['categoryKey'] as String? ?? 'mw_l3_goal_cat_balance',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static List<PersonalWellbeingGoal> defaultStarterGoals({DateTime? now}) {
    final stamp = now ?? DateTime.now();
    return [
      PersonalWellbeingGoal(
        id: 'hl_goal_outdoors',
        title: 'mw_l3_goal_outdoors',
        categoryKey: 'mw_l3_goal_cat_movement',
        isActive: false,
        createdAt: stamp,
      ),
      PersonalWellbeingGoal(
        id: 'hl_goal_evening_screens',
        title: 'mw_l3_goal_screens',
        categoryKey: 'mw_l3_goal_cat_rest',
        isActive: false,
        createdAt: stamp,
      ),
      PersonalWellbeingGoal(
        id: 'hl_goal_evening_calm',
        title: 'mw_l3_goal_wind_down',
        categoryKey: 'mw_l3_goal_cat_rest',
        isActive: false,
        createdAt: stamp,
      ),
      PersonalWellbeingGoal(
        id: 'hl_goal_creative_hobby',
        title: 'mw_l3_goal_hobby',
        categoryKey: 'mw_l3_goal_cat_balance',
        isActive: false,
        createdAt: stamp,
      ),
    ];
  }
}

/// Supported regions for Level 4 verified crisis & support directories (`GS-04`, `GS-05`).
enum SupportRegionFilter {
  id,
  us,
  global,
}

extension SupportRegionFilterExt on SupportRegionFilter {
  String get translationKey => 'mw_l4_region_$name';
}

/// Verified emergency crisis lifeline record (`GS-05`).
class CrisisResourceEntry {
  final String id;
  final SupportRegionFilter region;
  final String organizationName;
  final String roleKey;
  final String phoneOrShortcode;
  final String websiteUrl;
  final String hoursKey;
  final bool isEmergencyLifeline;
  final String verifiedSource;
  final String lastVerifiedDate;

  const CrisisResourceEntry({
    required this.id,
    required this.region,
    required this.organizationName,
    required this.roleKey,
    required this.phoneOrShortcode,
    this.websiteUrl = '',
    this.hoursKey = 'mw_l4_hours_24_7',
    this.isEmergencyLifeline = true,
    required this.verifiedSource,
    required this.lastVerifiedDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'region': region.name,
        'organizationName': organizationName,
        'roleKey': roleKey,
        'phoneOrShortcode': phoneOrShortcode,
        'websiteUrl': websiteUrl,
        'hoursKey': hoursKey,
        'isEmergencyLifeline': isEmergencyLifeline,
        'verifiedSource': verifiedSource,
        'lastVerifiedDate': lastVerifiedDate,
      };

  factory CrisisResourceEntry.fromJson(Map<String, dynamic> json) {
    final rawRegion = json['region'] as String? ?? SupportRegionFilter.global.name;
    final region = SupportRegionFilter.values.firstWhere(
      (r) => r.name == rawRegion,
      orElse: () => SupportRegionFilter.global,
    );
    return CrisisResourceEntry(
      id: json['id'] as String? ?? '',
      region: region,
      organizationName: json['organizationName'] as String? ?? '',
      roleKey: json['roleKey'] as String? ?? '',
      phoneOrShortcode: json['phoneOrShortcode'] as String? ?? '',
      websiteUrl: json['websiteUrl'] as String? ?? '',
      hoursKey: json['hoursKey'] as String? ?? 'mw_l4_hours_24_7',
      isEmergencyLifeline: json['isEmergencyLifeline'] as bool? ?? true,
      verifiedSource: json['verifiedSource'] as String? ?? '',
      lastVerifiedDate: json['lastVerifiedDate'] as String? ?? '',
    );
  }
}

/// Verified counselor, psychologist, or support directory entry (`GS-04`).
class SupportDirectoryEntry {
  final String id;
  final SupportRegionFilter region;
  final String organizationName;
  final String serviceTypeKey;
  final String descriptionKey;
  final String websiteUrl;
  final String phoneOrShortcode;
  final String verifiedSource;
  final String lastVerifiedDate;

  const SupportDirectoryEntry({
    required this.id,
    required this.region,
    required this.organizationName,
    required this.serviceTypeKey,
    required this.descriptionKey,
    required this.websiteUrl,
    this.phoneOrShortcode = '',
    required this.verifiedSource,
    required this.lastVerifiedDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'region': region.name,
        'organizationName': organizationName,
        'serviceTypeKey': serviceTypeKey,
        'descriptionKey': descriptionKey,
        'websiteUrl': websiteUrl,
        'phoneOrShortcode': phoneOrShortcode,
        'verifiedSource': verifiedSource,
        'lastVerifiedDate': lastVerifiedDate,
      };

  factory SupportDirectoryEntry.fromJson(Map<String, dynamic> json) {
    final rawRegion = json['region'] as String? ?? SupportRegionFilter.global.name;
    final region = SupportRegionFilter.values.firstWhere(
      (r) => r.name == rawRegion,
      orElse: () => SupportRegionFilter.global,
    );
    return SupportDirectoryEntry(
      id: json['id'] as String? ?? '',
      region: region,
      organizationName: json['organizationName'] as String? ?? '',
      serviceTypeKey: json['serviceTypeKey'] as String? ?? '',
      descriptionKey: json['descriptionKey'] as String? ?? '',
      websiteUrl: json['websiteUrl'] as String? ?? '',
      phoneOrShortcode: json['phoneOrShortcode'] as String? ?? '',
      verifiedSource: json['verifiedSource'] as String? ?? '',
      lastVerifiedDate: json['lastVerifiedDate'] as String? ?? '',
    );
  }
}

/// Level 4 verified crisis & support directory catalog (`GS-04`, `GS-05`).
/// Pairs bundled regional safety resources with NestJS/Supabase override parsing.
class CrisisAndSupportCatalog {
  CrisisAndSupportCatalog._();

  static const List<CrisisResourceEntry> defaultCrisisResources = [
    CrisisResourceEntry(
      id: 'crisis_id_sehat_jiwa',
      region: SupportRegionFilter.id,
      organizationName: 'Layanan Konseling SEJIWA / Healing119 (Kemenkes RI)',
      roleKey: 'mw_l4_crisis_id_sejiwa_role',
      phoneOrShortcode: '119',
      websiteUrl: 'https://healing119.id/',
      hoursKey: 'mw_l4_hours_varies',
      verifiedSource: 'Kementerian Kesehatan RI (Editorial Verified)',
      lastVerifiedDate: '2026-11-01',
    ),
    CrisisResourceEntry(
      id: 'crisis_id_emergency_112',
      region: SupportRegionFilter.id,
      organizationName: 'Layanan Darurat Nasional Indonesia (112)',
      roleKey: 'mw_l4_crisis_id_112_role',
      phoneOrShortcode: '112',
      hoursKey: 'mw_l4_hours_24_7',
      verifiedSource: 'Komdigi / Emergency 112',
      lastVerifiedDate: '2026-11-01',
    ),
    CrisisResourceEntry(
      id: 'crisis_us_988',
      region: SupportRegionFilter.us,
      organizationName: '988 Suicide & Crisis Lifeline',
      roleKey: 'mw_l4_crisis_us_988_role',
      phoneOrShortcode: '988',
      websiteUrl: 'https://988lifeline.org/',
      hoursKey: 'mw_l4_hours_24_7',
      verifiedSource: 'SAMHSA / 988 Lifeline',
      lastVerifiedDate: '2026-11-01',
    ),
    CrisisResourceEntry(
      id: 'crisis_us_911',
      region: SupportRegionFilter.us,
      organizationName: 'Emergency Services (911)',
      roleKey: 'mw_l4_crisis_us_911_role',
      phoneOrShortcode: '911',
      hoursKey: 'mw_l4_hours_24_7',
      verifiedSource: 'US National 911 Program',
      lastVerifiedDate: '2026-11-01',
    ),
    CrisisResourceEntry(
      id: 'crisis_global_findahelpline',
      region: SupportRegionFilter.global,
      organizationName: 'Find A Helpline (Worldwide Confidential Support)',
      roleKey: 'mw_l4_crisis_global_role',
      phoneOrShortcode: '',
      websiteUrl: 'https://findahelpline.com/',
      hoursKey: 'mw_l4_hours_24_7',
      isEmergencyLifeline: false,
      verifiedSource: 'ThroughLine / IASP Partner Network',
      lastVerifiedDate: '2026-11-01',
    ),
  ];

  static const List<SupportDirectoryEntry> defaultDirectoryEntries = [
    SupportDirectoryEntry(
      id: 'dir_id_himpsi',
      region: SupportRegionFilter.id,
      organizationName: 'HIMPSI & IPK Indonesia',
      serviceTypeKey: 'mw_l4_dir_psych_assoc',
      descriptionKey: 'mw_l4_dir_id_himpsi_desc',
      websiteUrl: 'https://ipkindonesia.or.id/',
      verifiedSource: 'Ikatan Psikolog Klinis Indonesia',
      lastVerifiedDate: '2026-11-01',
    ),
    SupportDirectoryEntry(
      id: 'dir_id_intothelight',
      region: SupportRegionFilter.id,
      organizationName: 'Into The Light Indonesia',
      serviceTypeKey: 'mw_l4_dir_community',
      descriptionKey: 'mw_l4_dir_id_itl_desc',
      websiteUrl: 'https://www.intothelightid.org/',
      verifiedSource: 'Into The Light Indonesia',
      lastVerifiedDate: '2026-11-01',
    ),
    SupportDirectoryEntry(
      id: 'dir_us_samhsa',
      region: SupportRegionFilter.us,
      organizationName: 'SAMHSA Treatment & Support Locator',
      serviceTypeKey: 'mw_l4_dir_public_health',
      descriptionKey: 'mw_l4_dir_us_samhsa_desc',
      websiteUrl: 'https://findtreatment.gov/',
      phoneOrShortcode: '1-800-662-4357',
      verifiedSource: 'US Dept. of Health & Human Services',
      lastVerifiedDate: '2026-11-01',
    ),
    SupportDirectoryEntry(
      id: 'dir_global_befrienders',
      region: SupportRegionFilter.global,
      organizationName: 'Befrienders Worldwide',
      serviceTypeKey: 'mw_l4_dir_listening',
      descriptionKey: 'mw_l4_dir_global_befrienders_desc',
      websiteUrl: 'https://www.befrienders.org/',
      verifiedSource: 'Befrienders Worldwide Directory',
      lastVerifiedDate: '2026-11-01',
    ),
  ];

  /// Parses an editorial backend payload (`{ "crisisResources": [...], "directoryEntries": [...] }`).
  static ({
    List<CrisisResourceEntry> crisisResources,
    List<SupportDirectoryEntry> directoryEntries,
  }) fromBackendPayload(Map<String, dynamic> payload) {
    final crisis = (payload['crisisResources'] as List?)
            ?.whereType<Map>()
            .map(
              (m) => CrisisResourceEntry.fromJson(
                Map<String, dynamic>.from(m),
              ),
            )
            .where((e) => e.organizationName.trim().isNotEmpty)
            .toList() ??
        const [];
    final directory = (payload['directoryEntries'] as List?)
            ?.whereType<Map>()
            .map(
              (m) => SupportDirectoryEntry.fromJson(
                Map<String, dynamic>.from(m),
              ),
            )
            .where((e) => e.organizationName.trim().isNotEmpty)
            .toList() ??
        const [];
    return (crisisResources: crisis, directoryEntries: directory);
  }
}

/// Pure-Dart passphrase-encrypted export/import helper for sensitive mental
/// wellness backups using salted SHA-256 keystream XOR + constant-time MAC.
class MentalWellnessCryptoHelper {
  MentalWellnessCryptoHelper._();

  static const String envelopeFormat = 'nestin_mw_encrypted_v1';

  static String encryptJsonPayload({
    required String plainJson,
    required String passphrase,
  }) {
    if (passphrase.trim().isEmpty) {
      throw ArgumentError('Passphrase cannot be empty');
    }
    final salt = DiaryLockHelper.generateSalt();
    final plainBytes = Uint8List.fromList(utf8.encode(plainJson));
    final cipherBytes = _xorWithKeystream(
      bytes: plainBytes,
      salt: salt,
      passphrase: passphrase,
    );
    final ciphertextB64 = base64Encode(cipherBytes);
    final mac = _computeMac(
      salt: salt,
      passphrase: passphrase,
      ciphertextBase64: ciphertextB64,
    );
    return jsonEncode({
      'format': envelopeFormat,
      'kdf': 'salted_sha256_ctr_v1',
      'salt': salt,
      'ciphertext': ciphertextB64,
      'mac': mac,
    });
  }

  static String? decryptJsonPayload({
    required String encryptedEnvelopeJson,
    required String passphrase,
  }) {
    if (passphrase.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(encryptedEnvelopeJson);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      if (map['format'] != envelopeFormat) return null;
      final salt = map['salt'] as String?;
      final ciphertextB64 = map['ciphertext'] as String?;
      final providedMac = map['mac'] as String?;
      if (salt == null ||
          salt.isEmpty ||
          ciphertextB64 == null ||
          ciphertextB64.isEmpty ||
          providedMac == null ||
          providedMac.isEmpty) {
        return null;
      }

      final expectedMac = _computeMac(
        salt: salt,
        passphrase: passphrase,
        ciphertextBase64: ciphertextB64,
      );
      if (!_constantTimeEquals(providedMac, expectedMac)) {
        return null;
      }

      final cipherBytes = base64Decode(ciphertextB64);
      final plainBytes = _xorWithKeystream(
        bytes: cipherBytes,
        salt: salt,
        passphrase: passphrase,
      );
      return utf8.decode(plainBytes);
    } catch (_) {
      return null;
    }
  }

  static Uint8List _xorWithKeystream({
    required Uint8List bytes,
    required String salt,
    required String passphrase,
  }) {
    final out = Uint8List(bytes.length);
    var offset = 0;
    var blockIndex = 0;
    while (offset < bytes.length) {
      final blockHex = DiaryLockHelper.sha256Hex(
        '$salt:$passphrase:enc_v1:$blockIndex',
      );
      for (var i = 0; i < 32 && offset < bytes.length; i++) {
        final keyByte = int.parse(blockHex.substring(i * 2, i * 2 + 2), radix: 16);
        out[offset] = bytes[offset] ^ keyByte;
        offset++;
      }
      blockIndex++;
    }
    return out;
  }

  static String _computeMac({
    required String salt,
    required String passphrase,
    required String ciphertextBase64,
  }) {
    final macKey = DiaryLockHelper.sha256Hex('$salt:$passphrase:mac_key_v1');
    return DiaryLockHelper.sha256Hex('$macKey:$salt:$ciphertextBase64');
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

/// Top-level local-first persistence container for Seren Mental Wellness Support.
class MentalWellnessStateData {
  final List<ComfortKitItem> comfortKitItems;
  final List<PersonalCommitmentGoal> commitments;
  final MindfulAppPauseConfig mindfulAppPauseConfig;
  final List<TriggerReflectionEntry> triggerReflections;
  final List<RecoveryReflectionEntry> recoveryReflections;
  final List<PersonalBoundaryItem> personalBoundaries;
  final RelapsePreventionPlan relapsePreventionPlan;
  final QualitativeChangeProgress qualitativeProgress;
  final List<TrustedContact> trustedContacts;
  final List<SupportMessageTemplate> messageTemplates;
  final PersonalSupportPlan personalSupportPlan;
  final List<String> bookmarkedGuideIds;
  final List<PersonalInsightNote> personalInsights;
  final List<PersonalWellbeingGoal> wellbeingGoals;
  final List<CrisisResourceEntry> remoteCrisisOverrides;
  final List<SupportDirectoryEntry> remoteDirectoryOverrides;

  const MentalWellnessStateData({
    this.comfortKitItems = const [],
    this.commitments = const [],
    this.mindfulAppPauseConfig = const MindfulAppPauseConfig(),
    this.triggerReflections = const [],
    this.recoveryReflections = const [],
    this.personalBoundaries = const [],
    this.relapsePreventionPlan = const RelapsePreventionPlan(),
    this.qualitativeProgress = const QualitativeChangeProgress(),
    this.trustedContacts = const [],
    this.messageTemplates = const [],
    this.personalSupportPlan = const PersonalSupportPlan(),
    this.bookmarkedGuideIds = const [],
    this.personalInsights = const [],
    this.wellbeingGoals = const [],
    this.remoteCrisisOverrides = const [],
    this.remoteDirectoryOverrides = const [],
  });

  MentalWellnessStateData copyWith({
    List<ComfortKitItem>? comfortKitItems,
    List<PersonalCommitmentGoal>? commitments,
    MindfulAppPauseConfig? mindfulAppPauseConfig,
    List<TriggerReflectionEntry>? triggerReflections,
    List<RecoveryReflectionEntry>? recoveryReflections,
    List<PersonalBoundaryItem>? personalBoundaries,
    RelapsePreventionPlan? relapsePreventionPlan,
    QualitativeChangeProgress? qualitativeProgress,
    List<TrustedContact>? trustedContacts,
    List<SupportMessageTemplate>? messageTemplates,
    PersonalSupportPlan? personalSupportPlan,
    List<String>? bookmarkedGuideIds,
    List<PersonalInsightNote>? personalInsights,
    List<PersonalWellbeingGoal>? wellbeingGoals,
    List<CrisisResourceEntry>? remoteCrisisOverrides,
    List<SupportDirectoryEntry>? remoteDirectoryOverrides,
  }) {
    return MentalWellnessStateData(
      comfortKitItems: comfortKitItems ?? this.comfortKitItems,
      commitments: commitments ?? this.commitments,
      mindfulAppPauseConfig:
          mindfulAppPauseConfig ?? this.mindfulAppPauseConfig,
      triggerReflections: triggerReflections ?? this.triggerReflections,
      recoveryReflections: recoveryReflections ?? this.recoveryReflections,
      personalBoundaries: personalBoundaries ?? this.personalBoundaries,
      relapsePreventionPlan:
          relapsePreventionPlan ?? this.relapsePreventionPlan,
      qualitativeProgress: qualitativeProgress ?? this.qualitativeProgress,
      trustedContacts: trustedContacts ?? this.trustedContacts,
      messageTemplates: messageTemplates ?? this.messageTemplates,
      personalSupportPlan: personalSupportPlan ?? this.personalSupportPlan,
      bookmarkedGuideIds: bookmarkedGuideIds ?? this.bookmarkedGuideIds,
      personalInsights: personalInsights ?? this.personalInsights,
      wellbeingGoals: wellbeingGoals ?? this.wellbeingGoals,
      remoteCrisisOverrides:
          remoteCrisisOverrides ?? this.remoteCrisisOverrides,
      remoteDirectoryOverrides:
          remoteDirectoryOverrides ?? this.remoteDirectoryOverrides,
    );
  }

  Map<String, dynamic> toJson() => {
        'comfortKitItems': comfortKitItems.map((e) => e.toJson()).toList(),
        'commitments': commitments.map((e) => e.toJson()).toList(),
        'mindfulAppPauseConfig': mindfulAppPauseConfig.toJson(),
        'triggerReflections':
            triggerReflections.map((e) => e.toJson()).toList(),
        'recoveryReflections':
            recoveryReflections.map((e) => e.toJson()).toList(),
        'personalBoundaries':
            personalBoundaries.map((e) => e.toJson()).toList(),
        'relapsePreventionPlan': relapsePreventionPlan.toJson(),
        'qualitativeProgress': qualitativeProgress.toJson(),
        'trustedContacts': trustedContacts.map((e) => e.toJson()).toList(),
        'messageTemplates': messageTemplates.map((e) => e.toJson()).toList(),
        'personalSupportPlan': personalSupportPlan.toJson(),
        'bookmarkedGuideIds': bookmarkedGuideIds,
        'personalInsights': personalInsights.map((e) => e.toJson()).toList(),
        'wellbeingGoals': wellbeingGoals.map((e) => e.toJson()).toList(),
        'remoteCrisisOverrides':
            remoteCrisisOverrides.map((e) => e.toJson()).toList(),
        'remoteDirectoryOverrides':
            remoteDirectoryOverrides.map((e) => e.toJson()).toList(),
      };

  factory MentalWellnessStateData.fromJson(Map<String, dynamic> json) {
    return MentalWellnessStateData(
      comfortKitItems: (json['comfortKitItems'] as List?)
              ?.whereType<Map>()
              .map((m) =>
                  ComfortKitItem.fromJson(Map<String, dynamic>.from(m)))
              .toList() ??
          const [],
      commitments: (json['commitments'] as List?)
              ?.whereType<Map>()
              .map((m) => PersonalCommitmentGoal.fromJson(
                  Map<String, dynamic>.from(m)))
              .toList() ??
          const [],
      mindfulAppPauseConfig: json['mindfulAppPauseConfig'] is Map
          ? MindfulAppPauseConfig.fromJson(
              Map<String, dynamic>.from(json['mindfulAppPauseConfig'] as Map))
          : const MindfulAppPauseConfig(),
      triggerReflections: (json['triggerReflections'] as List?)
              ?.whereType<Map>()
              .map((m) => TriggerReflectionEntry.fromJson(
                  Map<String, dynamic>.from(m)))
              .toList() ??
          const [],
      recoveryReflections: (json['recoveryReflections'] as List?)
              ?.whereType<Map>()
              .map((m) => RecoveryReflectionEntry.fromJson(
                  Map<String, dynamic>.from(m)))
              .toList() ??
          const [],
      personalBoundaries: (json['personalBoundaries'] as List?)
              ?.whereType<Map>()
              .map((m) => PersonalBoundaryItem.fromJson(
                  Map<String, dynamic>.from(m)))
              .toList() ??
          const [],
      relapsePreventionPlan: json['relapsePreventionPlan'] is Map
          ? RelapsePreventionPlan.fromJson(
              Map<String, dynamic>.from(json['relapsePreventionPlan'] as Map))
          : const RelapsePreventionPlan(),
      qualitativeProgress: json['qualitativeProgress'] is Map
          ? QualitativeChangeProgress.fromJson(
              Map<String, dynamic>.from(json['qualitativeProgress'] as Map))
          : const QualitativeChangeProgress(),
      trustedContacts: (json['trustedContacts'] as List?)
              ?.whereType<Map>()
              .map((m) =>
                  TrustedContact.fromJson(Map<String, dynamic>.from(m)))
              .toList() ??
          const [],
      messageTemplates: (json['messageTemplates'] as List?)
              ?.whereType<Map>()
              .map((m) => SupportMessageTemplate.fromJson(
                  Map<String, dynamic>.from(m)))
              .toList() ??
          const [],
      personalSupportPlan: json['personalSupportPlan'] is Map
          ? PersonalSupportPlan.fromJson(
              Map<String, dynamic>.from(json['personalSupportPlan'] as Map))
          : const PersonalSupportPlan(),
      bookmarkedGuideIds: (json['bookmarkedGuideIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      personalInsights: (json['personalInsights'] as List?)
              ?.whereType<Map>()
              .map((m) =>
                  PersonalInsightNote.fromJson(Map<String, dynamic>.from(m)))
              .toList() ??
          const [],
      wellbeingGoals: (json['wellbeingGoals'] as List?)
              ?.whereType<Map>()
              .map((m) =>
                  PersonalWellbeingGoal.fromJson(Map<String, dynamic>.from(m)))
              .toList() ??
          const [],
      remoteCrisisOverrides: (json['remoteCrisisOverrides'] as List?)
              ?.whereType<Map>()
              .map((m) =>
                  CrisisResourceEntry.fromJson(Map<String, dynamic>.from(m)))
              .toList() ??
          const [],
      remoteDirectoryOverrides: (json['remoteDirectoryOverrides'] as List?)
              ?.whereType<Map>()
              .map((m) => SupportDirectoryEntry.fromJson(
                  Map<String, dynamic>.from(m)))
              .toList() ??
          const [],
    );
  }
}
