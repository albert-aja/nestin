import 'package:flutter/material.dart';
import '../../core/l10n/app_localizations.dart';
export 'interactive_experience_models.dart';

/// Time-of-day lens for Seren Relaxation recommendations.
/// Users always retain full access to the entire library in every mode.
enum RelaxationTimeOfDayMode {
  anytime,
  morning,
  evening,
}

extension RelaxationTimeOfDayModeExt on RelaxationTimeOfDayMode {
  String get translationKey {
    switch (this) {
      case RelaxationTimeOfDayMode.anytime:
        return 'seren_mode_anytime';
      case RelaxationTimeOfDayMode.morning:
        return 'seren_mode_morning';
      case RelaxationTimeOfDayMode.evening:
        return 'seren_mode_evening';
    }
  }

  String get label => AppLocalizations.current.tr(translationKey);

  IconData get icon {
    switch (this) {
      case RelaxationTimeOfDayMode.anytime:
        return Icons.spa_rounded;
      case RelaxationTimeOfDayMode.morning:
        return Icons.wb_sunny_rounded;
      case RelaxationTimeOfDayMode.evening:
        return Icons.nightlight_round;
    }
  }
}

/// Three relaxation playback modes (Feature F: Audio + Visual Pairing).
enum RelaxationPlaybackMode {
  audioOnly,
  visualOnly,
  audioAndVisual,
}

extension RelaxationPlaybackModeExt on RelaxationPlaybackMode {
  String get translationKey {
    switch (this) {
      case RelaxationPlaybackMode.audioOnly:
        return 'seren_playback_audio_only';
      case RelaxationPlaybackMode.visualOnly:
        return 'seren_playback_visual_only';
      case RelaxationPlaybackMode.audioAndVisual:
        return 'seren_playback_audio_visual';
    }
  }

  String get label => AppLocalizations.current.tr(translationKey);

  IconData get icon {
    switch (this) {
      case RelaxationPlaybackMode.audioOnly:
        return Icons.headphones_rounded;
      case RelaxationPlaybackMode.visualOnly:
        return Icons.visibility_rounded;
      case RelaxationPlaybackMode.audioAndVisual:
        return Icons.surround_sound_rounded;
    }
  }
}

/// Four core ambient sound categories (Feature A).
enum AmbientSoundCategory {
  nature,
  indoorCozy,
  sleep,
  music,
}

extension AmbientSoundCategoryExt on AmbientSoundCategory {
  String get translationKey {
    switch (this) {
      case AmbientSoundCategory.nature:
        return 'seren_cat_nature';
      case AmbientSoundCategory.indoorCozy:
        return 'seren_cat_indoor_cozy';
      case AmbientSoundCategory.sleep:
        return 'seren_cat_sleep';
      case AmbientSoundCategory.music:
        return 'seren_cat_music';
    }
  }

  String get label => AppLocalizations.current.tr(translationKey);

  IconData get icon {
    switch (this) {
      case AmbientSoundCategory.nature:
        return Icons.park_rounded;
      case AmbientSoundCategory.indoorCozy:
        return Icons.fireplace_rounded;
      case AmbientSoundCategory.sleep:
        return Icons.bedtime_rounded;
      case AmbientSoundCategory.music:
        return Icons.music_note_rounded;
    }
  }
}

/// Perceived spatial distance setting for each mixer track (Feature B 5.2).
/// Adjusts high-frequency low-pass filtering, early spatial reflections, and
/// natural acoustic attenuation rather than merely duplicating the volume slider.
enum SoundDistance {
  near,
  balanced,
  far,
}

extension SoundDistanceExt on SoundDistance {
  String get translationKey {
    switch (this) {
      case SoundDistance.near:
        return 'seren_distance_near';
      case SoundDistance.balanced:
        return 'seren_distance_balanced';
      case SoundDistance.far:
        return 'seren_distance_far';
    }
  }

  String get label => AppLocalizations.current.tr(translationKey);

  /// Low-pass filter alpha (1.0 = full brightness, lower = warmer/muffled high frequencies).
  double get lowPassAlpha {
    switch (this) {
      case SoundDistance.near:
        return 0.94;
      case SoundDistance.balanced:
        return 0.48;
      case SoundDistance.far:
        return 0.19;
    }
  }

  /// Spatial reflection wet mix ratio (0.0 = dry/close, higher = distant room/horizon reverb).
  double get spatialReverbMix {
    switch (this) {
      case SoundDistance.near:
        return 0.06;
      case SoundDistance.balanced:
        return 0.22;
      case SoundDistance.far:
        return 0.44;
    }
  }

  /// Acoustic distance gain factor combined with filter & reflection shaping.
  double get acousticAttenuation {
    switch (this) {
      case SoundDistance.near:
        return 1.0;
      case SoundDistance.balanced:
        return 0.82;
      case SoundDistance.far:
        return 0.62;
    }
  }
}

/// Optional simple stereo positioning for mixer tracks (Feature B 5.3).
enum StereoPosition {
  left,
  center,
  right,
}

extension StereoPositionExt on StereoPosition {
  String get translationKey {
    switch (this) {
      case StereoPosition.left:
        return 'seren_stereo_left';
      case StereoPosition.center:
        return 'seren_stereo_center';
      case StereoPosition.right:
        return 'seren_stereo_right';
    }
  }

  String get label => AppLocalizations.current.tr(translationKey);

  double get leftGain {
    switch (this) {
      case StereoPosition.left:
        return 0.98;
      case StereoPosition.center:
        return 0.85;
      case StereoPosition.right:
        return 0.35;
    }
  }

  double get rightGain {
    switch (this) {
      case StereoPosition.left:
        return 0.35;
      case StereoPosition.center:
        return 0.85;
      case StereoPosition.right:
        return 0.98;
    }
  }

  double get balanceValue {
    switch (this) {
      case StereoPosition.left:
        return -0.65;
      case StereoPosition.center:
        return 0.0;
      case StereoPosition.right:
        return 0.65;
    }
  }
}

/// Metadata for a single ambient sound in Seren's library.
class AmbientSoundItem {
  final String id;
  final String titleKey;
  final String descriptionKey;
  final AmbientSoundCategory category;
  final IconData icon;
  final Color accentColor;
  final SoundDistance defaultDistance;
  final RelaxationTimeOfDayMode recommendedFor;
  final String? pairedVisualId;

  const AmbientSoundItem({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.category,
    required this.icon,
    required this.accentColor,
    this.defaultDistance = SoundDistance.balanced,
    this.recommendedFor = RelaxationTimeOfDayMode.anytime,
    this.pairedVisualId,
  });

  String get title => AppLocalizations.current.tr(titleKey);
  String get description => AppLocalizations.current.tr(descriptionKey);
  String get subtitle => description;
}

/// Configuration for one active track inside the Multi-Track Sound Mixer.
class SoundMixerTrackConfig {
  final String soundId;
  final double volume;
  final SoundDistance distance;
  final StereoPosition stereoPosition;
  final double toneWarmth; // -1.0 (Warm/Soft) .. 0.0 (Balanced) .. +1.0 (Bright/Crisp)
  final bool isMuted;

  const SoundMixerTrackConfig({
    required this.soundId,
    this.volume = 0.65,
    this.distance = SoundDistance.balanced,
    this.stereoPosition = StereoPosition.center,
    this.toneWarmth = 0.0,
    this.isMuted = false,
  });

  /// Discrete -10..+10 bucket used for stable WAV variant caching.
  int get toneWarmthBucket => (toneWarmth.clamp(-1.0, 1.0) * 10).round();

  String get toneLabelKey {
    if (toneWarmth <= -0.18) return 'seren_tone_warm';
    if (toneWarmth >= 0.18) return 'seren_tone_bright';
    return 'seren_tone_neutral';
  }

  String get toneLabel => AppLocalizations.current.tr(toneLabelKey);

  SoundMixerTrackConfig copyWith({
    String? soundId,
    double? volume,
    SoundDistance? distance,
    StereoPosition? stereoPosition,
    double? toneWarmth,
    bool? isMuted,
  }) {
    return SoundMixerTrackConfig(
      soundId: soundId ?? this.soundId,
      volume: (volume ?? this.volume).clamp(0.0, 1.0),
      distance: distance ?? this.distance,
      stereoPosition: stereoPosition ?? this.stereoPosition,
      toneWarmth: (toneWarmth ?? this.toneWarmth).clamp(-1.0, 1.0),
      isMuted: isMuted ?? this.isMuted,
    );
  }

  Map<String, dynamic> toJson() => {
        'soundId': soundId,
        'volume': volume,
        'distance': distance.name,
        'stereoPosition': stereoPosition.name,
        'toneWarmth': toneWarmth,
        'isMuted': isMuted,
      };

  factory SoundMixerTrackConfig.fromJson(Map<String, dynamic> json) {
    final distName = json['distance'] as String? ?? 'balanced';
    final posName = json['stereoPosition'] as String? ?? 'center';
    return SoundMixerTrackConfig(
      soundId: json['soundId'] as String? ?? 'rain',
      volume: ((json['volume'] as num?)?.toDouble() ?? 0.65).clamp(0.0, 1.0),
      distance: SoundDistance.values.firstWhere(
        (d) => d.name == distName,
        orElse: () => SoundDistance.balanced,
      ),
      stereoPosition: StereoPosition.values.firstWhere(
        (p) => p.name == posName,
        orElse: () => StereoPosition.center,
      ),
      toneWarmth:
          ((json['toneWarmth'] as num?)?.toDouble() ?? 0.0).clamp(-1.0, 1.0),
      isMuted: json['isMuted'] as bool? ?? false,
    );
  }
}

/// Curated or user-saved multi-track soundscape preset (Feature B 5.4).
class SavedSoundscape {
  final String id;
  final String name;
  final String? nameKey;
  final String? descriptionKey;
  final List<SoundMixerTrackConfig> tracks;
  final double masterVolume;
  final String? pairedVisualId;
  final RelaxationTimeOfDayMode recommendedFor;
  final bool isPreset;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavedSoundscape({
    required this.id,
    required this.name,
    this.nameKey,
    this.descriptionKey,
    required this.tracks,
    this.masterVolume = 0.8,
    this.pairedVisualId,
    this.recommendedFor = RelaxationTimeOfDayMode.anytime,
    this.isPreset = false,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName {
    if (nameKey != null && nameKey!.isNotEmpty) {
      return AppLocalizations.current.tr(nameKey!);
    }
    return name;
  }

  String get displayDescription {
    if (descriptionKey != null && descriptionKey!.isNotEmpty) {
      return AppLocalizations.current.tr(descriptionKey!);
    }
    return '';
  }

  SavedSoundscape copyWith({
    String? id,
    String? name,
    String? nameKey,
    bool clearNameKey = false,
    String? descriptionKey,
    List<SoundMixerTrackConfig>? tracks,
    double? masterVolume,
    String? pairedVisualId,
    RelaxationTimeOfDayMode? recommendedFor,
    bool? isPreset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedSoundscape(
      id: id ?? this.id,
      name: name ?? this.name,
      nameKey: clearNameKey ? null : (nameKey ?? this.nameKey),
      descriptionKey: descriptionKey ?? this.descriptionKey,
      tracks: tracks ?? this.tracks,
      masterVolume: (masterVolume ?? this.masterVolume).clamp(0.0, 1.0),
      pairedVisualId: pairedVisualId ?? this.pairedVisualId,
      recommendedFor: recommendedFor ?? this.recommendedFor,
      isPreset: isPreset ?? this.isPreset,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nameKey': nameKey,
        'descriptionKey': descriptionKey,
        'tracks': tracks.map((t) => t.toJson()).toList(),
        'masterVolume': masterVolume,
        'pairedVisualId': pairedVisualId,
        'recommendedFor': recommendedFor.name,
        'isPreset': isPreset,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SavedSoundscape.fromJson(Map<String, dynamic> json) {
    final rawTracks = (json['tracks'] as List<dynamic>?)
            ?.map((e) =>
                SoundMixerTrackConfig.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final recName = json['recommendedFor'] as String? ?? 'anytime';
    final now = DateTime.now();
    return SavedSoundscape(
      id: json['id'] as String? ?? 'custom',
      name: json['name'] as String? ?? 'Custom Soundscape',
      nameKey: json['nameKey'] as String?,
      descriptionKey: json['descriptionKey'] as String?,
      tracks: rawTracks,
      masterVolume:
          ((json['masterVolume'] as num?)?.toDouble() ?? 0.8).clamp(0.0, 1.0),
      pairedVisualId: json['pairedVisualId'] as String?,
      recommendedFor: RelaxationTimeOfDayMode.values.firstWhere(
        (m) => m.name == recName,
        orElse: () => RelaxationTimeOfDayMode.anytime,
      ),
      isPreset: json['isPreset'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? now
          : now,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? now
          : now,
    );
  }
}

/// Guided relaxation category (Feature C).
enum GuidedRelaxationCategory {
  breathing,
  relaxation,
}

extension GuidedRelaxationCategoryExt on GuidedRelaxationCategory {
  String get translationKey {
    switch (this) {
      case GuidedRelaxationCategory.breathing:
        return 'seren_guided_cat_breathing';
      case GuidedRelaxationCategory.relaxation:
        return 'seren_guided_cat_relaxation';
    }
  }

  String get label => AppLocalizations.current.tr(translationKey);
}

/// Configurable breathing step within a guided session.
class BreathingPhaseStep {
  final String instructionKey;
  final int seconds;
  final double targetScale;

  const BreathingPhaseStep({
    required this.instructionKey,
    required this.seconds,
    required this.targetScale,
  });

  String get instruction => AppLocalizations.current.tr(instructionKey);
  String get label => instruction;
}

/// Configurable guided relaxation / breathing session (Feature C).
class GuidedRelaxationSession {
  final String id;
  final String titleKey;
  final String subtitleKey;
  final GuidedRelaxationCategory category;
  final RelaxationTimeOfDayMode recommendedFor;
  final List<int> availableDurationsMinutes;
  final int defaultDurationMinutes;
  final List<BreathingPhaseStep> breathingSteps;
  final List<String> narrationPromptKeys;
  final String? recommendedSoundId;
  final IconData icon;
  final Color accentColor;

  const GuidedRelaxationSession({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.category,
    this.recommendedFor = RelaxationTimeOfDayMode.anytime,
    this.availableDurationsMinutes = const [2, 3, 5, 10],
    this.defaultDurationMinutes = 3,
    required this.breathingSteps,
    required this.narrationPromptKeys,
    this.recommendedSoundId,
    required this.icon,
    required this.accentColor,
  });

  String get title => AppLocalizations.current.tr(titleKey);
  String get subtitle => AppLocalizations.current.tr(subtitleKey);
  List<String> get localizedPrompts =>
      narrationPromptKeys.map((k) => AppLocalizations.current.tr(k)).toList();
}

/// Visual environment category (Feature E).
enum VisualEnvironmentCategory {
  nature,
  night,
  daytime,
  underwater,
}

extension VisualEnvironmentCategoryExt on VisualEnvironmentCategory {
  String get translationKey {
    switch (this) {
      case VisualEnvironmentCategory.nature:
        return 'seren_visual_cat_nature';
      case VisualEnvironmentCategory.night:
        return 'seren_visual_cat_night';
      case VisualEnvironmentCategory.daytime:
        return 'seren_visual_cat_daytime';
      case VisualEnvironmentCategory.underwater:
        return 'seren_visual_cat_underwater';
    }
  }

  String get label => AppLocalizations.current.tr(translationKey);
}

/// Passive calming visual scene metadata (Feature E & F).
class VisualEnvironmentScene {
  final String id;
  final String titleKey;
  final String subtitleKey;
  final VisualEnvironmentCategory category;
  final RelaxationTimeOfDayMode recommendedFor;
  final String pairedSoundId;
  final List<Color> gradientColors;
  final Color accentParticleColor;
  final IconData icon;

  const VisualEnvironmentScene({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.category,
    this.recommendedFor = RelaxationTimeOfDayMode.anytime,
    required this.pairedSoundId,
    required this.gradientColors,
    required this.accentParticleColor,
    required this.icon,
  });

  String get title => AppLocalizations.current.tr(titleKey);
  String get subtitle => AppLocalizations.current.tr(subtitleKey);
}

/// Categories for Bedtime Stories & Relaxation Reading (Feature G).
enum RelaxationReadingCategory {
  bedtimeStories,
  natureStories,
  fictionalJourneys,
  slowTravelogues,
  seasonalEssays,
  reflectiveReadings,
  natureFacts,
  morningReadings,
  positiveThoughts,
}

extension RelaxationReadingCategoryExt on RelaxationReadingCategory {
  String get translationKey {
    switch (this) {
      case RelaxationReadingCategory.bedtimeStories:
        return 'seren_read_cat_bedtime';
      case RelaxationReadingCategory.natureStories:
        return 'seren_read_cat_nature';
      case RelaxationReadingCategory.fictionalJourneys:
        return 'seren_read_cat_journeys';
      case RelaxationReadingCategory.slowTravelogues:
        return 'seren_read_cat_travelogues';
      case RelaxationReadingCategory.seasonalEssays:
        return 'seren_read_cat_seasonal';
      case RelaxationReadingCategory.reflectiveReadings:
        return 'seren_read_cat_reflective';
      case RelaxationReadingCategory.natureFacts:
        return 'seren_read_cat_facts';
      case RelaxationReadingCategory.morningReadings:
        return 'seren_read_cat_morning';
      case RelaxationReadingCategory.positiveThoughts:
        return 'seren_read_cat_positive';
    }
  }

  String get label => AppLocalizations.current.tr(translationKey);

  IconData get icon {
    switch (this) {
      case RelaxationReadingCategory.bedtimeStories:
        return Icons.bedtime_rounded;
      case RelaxationReadingCategory.natureStories:
        return Icons.park_rounded;
      case RelaxationReadingCategory.fictionalJourneys:
        return Icons.explore_rounded;
      case RelaxationReadingCategory.slowTravelogues:
        return Icons.train_rounded;
      case RelaxationReadingCategory.seasonalEssays:
        return Icons.forest_rounded;
      case RelaxationReadingCategory.reflectiveReadings:
        return Icons.self_improvement_rounded;
      case RelaxationReadingCategory.natureFacts:
        return Icons.eco_rounded;
      case RelaxationReadingCategory.morningReadings:
        return Icons.wb_sunny_rounded;
      case RelaxationReadingCategory.positiveThoughts:
        return Icons.favorite_border_rounded;
    }
  }
}

/// Optional seasonal or thematic tag for long-form Seren anthology readings.
enum ReadingSeasonTag {
  spring,
  summer,
  autumn,
  winter,
  monsoon,
  nightSky,
  botanical,
}

extension ReadingSeasonTagExt on ReadingSeasonTag {
  String get translationKey {
    switch (this) {
      case ReadingSeasonTag.spring:
        return 'seren_season_spring';
      case ReadingSeasonTag.summer:
        return 'seren_season_summer';
      case ReadingSeasonTag.autumn:
        return 'seren_season_autumn';
      case ReadingSeasonTag.winter:
        return 'seren_season_winter';
      case ReadingSeasonTag.monsoon:
        return 'seren_season_monsoon';
      case ReadingSeasonTag.nightSky:
        return 'seren_season_night_sky';
      case ReadingSeasonTag.botanical:
        return 'seren_season_botanical';
    }
  }

  String get label => AppLocalizations.current.tr(translationKey);

  IconData get icon {
    switch (this) {
      case ReadingSeasonTag.spring:
        return Icons.local_florist_rounded;
      case ReadingSeasonTag.summer:
        return Icons.wb_twilight_rounded;
      case ReadingSeasonTag.autumn:
        return Icons.park_rounded;
      case ReadingSeasonTag.winter:
        return Icons.ac_unit_rounded;
      case ReadingSeasonTag.monsoon:
        return Icons.water_drop_rounded;
      case ReadingSeasonTag.nightSky:
        return Icons.nights_stay_rounded;
      case ReadingSeasonTag.botanical:
        return Icons.spa_rounded;
    }
  }
}

/// A discrete chapter inside a long-form relaxation reading or travelogue.
class ReadingChapter {
  final String id;
  final String titleKey;
  final List<String> paragraphKeys;

  const ReadingChapter({
    required this.id,
    required this.titleKey,
    required this.paragraphKeys,
  });

  String get title => AppLocalizations.current.tr(titleKey);
  List<String> get paragraphs =>
      paragraphKeys.map((k) => AppLocalizations.current.tr(k)).toList();
}

/// Calming story or reading item supporting single-part or multi-chapter reading and TTS narration.
class RelaxationReadingItem {
  final String id;
  final String titleKey;
  final String subtitleKey;
  final RelaxationReadingCategory category;
  final RelaxationTimeOfDayMode recommendedFor;
  final int estimatedMinutes;
  final String pairedSoundId;
  final String? pairedVisualId;
  final List<String> paragraphKeys;
  final List<ReadingChapter> chapters;
  final ReadingSeasonTag? seasonTag;
  final IconData icon;

  const RelaxationReadingItem({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.category,
    this.recommendedFor = RelaxationTimeOfDayMode.anytime,
    required this.estimatedMinutes,
    required this.pairedSoundId,
    this.pairedVisualId,
    this.paragraphKeys = const [],
    this.chapters = const [],
    this.seasonTag,
    required this.icon,
  });

  String get title => AppLocalizations.current.tr(titleKey);
  String get subtitle => AppLocalizations.current.tr(subtitleKey);
  bool get isMultiChapter => chapters.isNotEmpty;
  int get chapterCount => chapters.isNotEmpty ? chapters.length : 1;

  List<String> get effectiveParagraphKeys => chapters.isNotEmpty
      ? [for (final chapter in chapters) ...chapter.paragraphKeys]
      : paragraphKeys;

  List<String> get paragraphs =>
      effectiveParagraphKeys.map((k) => AppLocalizations.current.tr(k)).toList();

  /// Returns the zero-based chapter index containing [paragraphIndex].
  int chapterIndexForParagraph(int paragraphIndex) {
    if (chapters.isEmpty || paragraphIndex <= 0) return 0;
    var offset = 0;
    for (var i = 0; i < chapters.length; i++) {
      final len = chapters[i].paragraphKeys.length;
      if (paragraphIndex < offset + len) {
        return i;
      }
      offset += len;
    }
    return chapters.length - 1;
  }

  /// Returns the flattened global paragraph index where [chapterIndex] starts.
  int startParagraphIndexForChapter(int chapterIndex) {
    if (chapters.isEmpty || chapterIndex <= 0) return 0;
    final clamped = chapterIndex >= chapters.length ? chapters.length - 1 : chapterIndex;
    var offset = 0;
    for (var i = 0; i < clamped; i++) {
      offset += chapters[i].paragraphKeys.length;
    }
    return offset;
  }

  /// Returns the [ReadingChapter] matching [paragraphIndex], or null if single-chapter.
  ReadingChapter? chapterForParagraph(int paragraphIndex) {
    if (chapters.isEmpty) return null;
    return chapters[chapterIndexForParagraph(paragraphIndex)];
  }
}

/// Lightweight, zero-pressure Mindful Activity prompt (Feature H).
class MindfulActivityPrompt {
  final String id;
  final String titleKey;
  final String promptKey;
  final String placeholderKey;
  final RelaxationTimeOfDayMode recommendedFor;
  final String journalTag;
  final bool storesGratitudePebble;
  final IconData icon;

  const MindfulActivityPrompt({
    required this.id,
    required this.titleKey,
    required this.promptKey,
    required this.placeholderKey,
    this.recommendedFor = RelaxationTimeOfDayMode.anytime,
    required this.journalTag,
    this.storesGratitudePebble = false,
    required this.icon,
  });

  String get title => AppLocalizations.current.tr(titleKey);
  String get prompt => AppLocalizations.current.tr(promptKey);
  String get promptText => prompt;
  String get placeholder => AppLocalizations.current.tr(placeholderKey);
}

/// Persisted personalization & user state for Seren Relaxation (Feature 13).
class SerenRelaxationPreferences {
  final RelaxationPlaybackMode defaultPlaybackMode;
  final int defaultTimerMinutes;
  final bool autoFadeOut;
  final bool lowMotionVisuals;
  final double masterVolume;
  final double narrationVolume;
  final bool duckAmbientDuringNarration;
  final double ttsSpeechRate;
  final String ttsLanguageCode;
  final SoundDistance defaultDistance;
  final String preferredVisualId;
  final List<String> favoriteSoundIds;
  final List<String> recentSoundIds;
  final List<SavedSoundscape> customSoundscapes;
  final List<String> bookmarkedReadingIds;
  final List<String> favoriteReadingIds;
  final List<String> readingHistoryIds;
  final Map<String, int> readingLastParagraphIndex;
  final bool morningGentleReminderEnabled;
  final bool eveningUnwindReminderEnabled;

  const SerenRelaxationPreferences({
    this.defaultPlaybackMode = RelaxationPlaybackMode.audioAndVisual,
    this.defaultTimerMinutes = 30,
    this.autoFadeOut = true,
    this.lowMotionVisuals = false,
    this.masterVolume = 0.75,
    this.narrationVolume = 0.90,
    this.duckAmbientDuringNarration = true,
    this.ttsSpeechRate = 0.85,
    this.ttsLanguageCode = 'auto',
    this.defaultDistance = SoundDistance.balanced,
    this.preferredVisualId = 'rainyWindow',
    this.favoriteSoundIds = const ['rain', 'oceanWaves', 'gentlePiano'],
    this.recentSoundIds = const ['rain', 'forest'],
    this.customSoundscapes = const [],
    this.bookmarkedReadingIds = const [],
    this.favoriteReadingIds = const ['story_lantern_cove'],
    this.readingHistoryIds = const [],
    this.readingLastParagraphIndex = const {},
    this.morningGentleReminderEnabled = false,
    this.eveningUnwindReminderEnabled = false,
  });

  SerenRelaxationPreferences copyWith({
    RelaxationPlaybackMode? defaultPlaybackMode,
    int? defaultTimerMinutes,
    bool? autoFadeOut,
    bool? lowMotionVisuals,
    double? masterVolume,
    double? narrationVolume,
    bool? duckAmbientDuringNarration,
    double? ttsSpeechRate,
    String? ttsLanguageCode,
    SoundDistance? defaultDistance,
    String? preferredVisualId,
    List<String>? favoriteSoundIds,
    List<String>? recentSoundIds,
    List<SavedSoundscape>? customSoundscapes,
    List<String>? bookmarkedReadingIds,
    List<String>? favoriteReadingIds,
    List<String>? readingHistoryIds,
    Map<String, int>? readingLastParagraphIndex,
    bool? morningGentleReminderEnabled,
    bool? eveningUnwindReminderEnabled,
  }) {
    return SerenRelaxationPreferences(
      defaultPlaybackMode: defaultPlaybackMode ?? this.defaultPlaybackMode,
      defaultTimerMinutes: defaultTimerMinutes ?? this.defaultTimerMinutes,
      autoFadeOut: autoFadeOut ?? this.autoFadeOut,
      lowMotionVisuals: lowMotionVisuals ?? this.lowMotionVisuals,
      masterVolume: (masterVolume ?? this.masterVolume).clamp(0.0, 1.0),
      narrationVolume:
          (narrationVolume ?? this.narrationVolume).clamp(0.0, 1.0),
      duckAmbientDuringNarration:
          duckAmbientDuringNarration ?? this.duckAmbientDuringNarration,
      ttsSpeechRate: (ttsSpeechRate ?? this.ttsSpeechRate).clamp(0.5, 1.5),
      ttsLanguageCode: ttsLanguageCode ?? this.ttsLanguageCode,
      defaultDistance: defaultDistance ?? this.defaultDistance,
      preferredVisualId: preferredVisualId ?? this.preferredVisualId,
      favoriteSoundIds: favoriteSoundIds ?? this.favoriteSoundIds,
      recentSoundIds: recentSoundIds ?? this.recentSoundIds,
      customSoundscapes: customSoundscapes ?? this.customSoundscapes,
      bookmarkedReadingIds: bookmarkedReadingIds ?? this.bookmarkedReadingIds,
      favoriteReadingIds: favoriteReadingIds ?? this.favoriteReadingIds,
      readingHistoryIds: readingHistoryIds ?? this.readingHistoryIds,
      readingLastParagraphIndex:
          readingLastParagraphIndex ?? this.readingLastParagraphIndex,
      morningGentleReminderEnabled:
          morningGentleReminderEnabled ?? this.morningGentleReminderEnabled,
      eveningUnwindReminderEnabled:
          eveningUnwindReminderEnabled ?? this.eveningUnwindReminderEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'defaultPlaybackMode': defaultPlaybackMode.name,
        'defaultTimerMinutes': defaultTimerMinutes,
        'autoFadeOut': autoFadeOut,
        'lowMotionVisuals': lowMotionVisuals,
        'masterVolume': masterVolume,
        'narrationVolume': narrationVolume,
        'duckAmbientDuringNarration': duckAmbientDuringNarration,
        'ttsSpeechRate': ttsSpeechRate,
        'ttsLanguageCode': ttsLanguageCode,
        'defaultDistance': defaultDistance.name,
        'preferredVisualId': preferredVisualId,
        'favoriteSoundIds': favoriteSoundIds,
        'recentSoundIds': recentSoundIds,
        'customSoundscapes': customSoundscapes.map((s) => s.toJson()).toList(),
        'bookmarkedReadingIds': bookmarkedReadingIds,
        'favoriteReadingIds': favoriteReadingIds,
        'readingHistoryIds': readingHistoryIds,
        'readingLastParagraphIndex': readingLastParagraphIndex,
        'morningGentleReminderEnabled': morningGentleReminderEnabled,
        'eveningUnwindReminderEnabled': eveningUnwindReminderEnabled,
      };

  factory SerenRelaxationPreferences.fromJson(Map<String, dynamic> json) {
    final modeName = json['defaultPlaybackMode'] as String? ?? 'audioAndVisual';
    final distName = json['defaultDistance'] as String? ?? 'balanced';
    final rawParagraphMap =
        json['readingLastParagraphIndex'] as Map<String, dynamic>? ?? {};
    return SerenRelaxationPreferences(
      defaultPlaybackMode: RelaxationPlaybackMode.values.firstWhere(
        (m) => m.name == modeName,
        orElse: () => RelaxationPlaybackMode.audioAndVisual,
      ),
      defaultTimerMinutes:
          ((json['defaultTimerMinutes'] as num?)?.toInt() ?? 30).clamp(5, 240),
      autoFadeOut: json['autoFadeOut'] as bool? ?? true,
      lowMotionVisuals: json['lowMotionVisuals'] as bool? ?? false,
      masterVolume:
          ((json['masterVolume'] as num?)?.toDouble() ?? 0.75).clamp(0.0, 1.0),
      narrationVolume: ((json['narrationVolume'] as num?)?.toDouble() ?? 0.90)
          .clamp(0.0, 1.0),
      duckAmbientDuringNarration:
          json['duckAmbientDuringNarration'] as bool? ?? true,
      ttsSpeechRate:
          ((json['ttsSpeechRate'] as num?)?.toDouble() ?? 0.85).clamp(0.5, 1.5),
      ttsLanguageCode: json['ttsLanguageCode'] as String? ?? 'auto',
      defaultDistance: SoundDistance.values.firstWhere(
        (d) => d.name == distName,
        orElse: () => SoundDistance.balanced,
      ),
      preferredVisualId: json['preferredVisualId'] as String? ?? 'rainyWindow',
      favoriteSoundIds: (json['favoriteSoundIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['rain', 'oceanWaves', 'gentlePiano'],
      recentSoundIds: (json['recentSoundIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['rain', 'forest'],
      customSoundscapes: (json['customSoundscapes'] as List<dynamic>?)
              ?.map((e) =>
                  SavedSoundscape.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      bookmarkedReadingIds: (json['bookmarkedReadingIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      favoriteReadingIds: (json['favoriteReadingIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['story_lantern_cove'],
      readingHistoryIds: (json['readingHistoryIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      readingLastParagraphIndex: rawParagraphMap.map(
        (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
      ),
      morningGentleReminderEnabled:
          json['morningGentleReminderEnabled'] as bool? ?? false,
      eveningUnwindReminderEnabled:
          json['eveningUnwindReminderEnabled'] as bool? ?? false,
    );
  }
}

/// Built-in catalog of Seren Ambient Sounds, Presets, Guided Sessions,
/// Calming Visual Scenes, Bedtime Stories/Readings, and Mindful Activities.
class SerenRelaxationCatalog {
  static const List<AmbientSoundItem> sounds = [
    // --- NATURE (8 sounds) ---
    AmbientSoundItem(
      id: 'rain',
      titleKey: 'seren_sound_rain_title',
      descriptionKey: 'seren_sound_rain_desc',
      category: AmbientSoundCategory.nature,
      icon: Icons.water_drop_rounded,
      accentColor: Color(0xFF38BDF8),
      defaultDistance: SoundDistance.balanced,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      pairedVisualId: 'rainyWindow',
    ),
    AmbientSoundItem(
      id: 'thunderstorm',
      titleKey: 'seren_sound_thunder_title',
      descriptionKey: 'seren_sound_thunder_desc',
      category: AmbientSoundCategory.nature,
      icon: Icons.thunderstorm_rounded,
      accentColor: Color(0xFF818CF8),
      defaultDistance: SoundDistance.far,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      pairedVisualId: 'rainyWindow',
    ),
    AmbientSoundItem(
      id: 'oceanWaves',
      titleKey: 'seren_sound_ocean_title',
      descriptionKey: 'seren_sound_ocean_desc',
      category: AmbientSoundCategory.nature,
      icon: Icons.waves_rounded,
      accentColor: Color(0xFF0EA5E9),
      defaultDistance: SoundDistance.balanced,
      recommendedFor: RelaxationTimeOfDayMode.anytime,
      pairedVisualId: 'oceanSunset',
    ),
    AmbientSoundItem(
      id: 'riverStream',
      titleKey: 'seren_sound_river_title',
      descriptionKey: 'seren_sound_river_desc',
      category: AmbientSoundCategory.nature,
      icon: Icons.water_rounded,
      accentColor: Color(0xFF2DD4BF),
      defaultDistance: SoundDistance.near,
      recommendedFor: RelaxationTimeOfDayMode.morning,
      pairedVisualId: 'underwaterSanctuary',
    ),
    AmbientSoundItem(
      id: 'forest',
      titleKey: 'seren_sound_forest_title',
      descriptionKey: 'seren_sound_forest_desc',
      category: AmbientSoundCategory.nature,
      icon: Icons.park_rounded,
      accentColor: Color(0xFF34D399),
      defaultDistance: SoundDistance.balanced,
      recommendedFor: RelaxationTimeOfDayMode.morning,
      pairedVisualId: 'forestBreeze',
    ),
    AmbientSoundItem(
      id: 'birdsSinging',
      titleKey: 'seren_sound_birds_title',
      descriptionKey: 'seren_sound_birds_desc',
      category: AmbientSoundCategory.nature,
      icon: Icons.flutter_dash_rounded,
      accentColor: Color(0xFFFBBF24),
      defaultDistance: SoundDistance.balanced,
      recommendedFor: RelaxationTimeOfDayMode.morning,
      pairedVisualId: 'morningSunrise',
    ),
    AmbientSoundItem(
      id: 'gentleWind',
      titleKey: 'seren_sound_wind_title',
      descriptionKey: 'seren_sound_wind_desc',
      category: AmbientSoundCategory.nature,
      icon: Icons.air_rounded,
      accentColor: Color(0xFF60A5FA),
      defaultDistance: SoundDistance.far,
      recommendedFor: RelaxationTimeOfDayMode.anytime,
      pairedVisualId: 'driftingClouds',
    ),
    AmbientSoundItem(
      id: 'nightInsects',
      titleKey: 'seren_sound_insects_title',
      descriptionKey: 'seren_sound_insects_desc',
      category: AmbientSoundCategory.nature,
      icon: Icons.nights_stay_rounded,
      accentColor: Color(0xFFA78BFA),
      defaultDistance: SoundDistance.far,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      pairedVisualId: 'forestFireflies',
    ),

    // --- INDOOR / COZY (5 sounds) ---
    AmbientSoundItem(
      id: 'fireplace',
      titleKey: 'seren_sound_fireplace_title',
      descriptionKey: 'seren_sound_fireplace_desc',
      category: AmbientSoundCategory.indoorCozy,
      icon: Icons.fireplace_rounded,
      accentColor: Color(0xFFF97316),
      defaultDistance: SoundDistance.near,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      pairedVisualId: 'moonlitLake',
    ),
    AmbientSoundItem(
      id: 'rainWindow',
      titleKey: 'seren_sound_rain_window_title',
      descriptionKey: 'seren_sound_rain_window_desc',
      category: AmbientSoundCategory.indoorCozy,
      icon: Icons.window_rounded,
      accentColor: Color(0xFF38BDF8),
      defaultDistance: SoundDistance.near,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      pairedVisualId: 'rainyWindow',
    ),
    AmbientSoundItem(
      id: 'coffeeShop',
      titleKey: 'seren_sound_cafe_title',
      descriptionKey: 'seren_sound_cafe_desc',
      category: AmbientSoundCategory.indoorCozy,
      icon: Icons.local_cafe_rounded,
      accentColor: Color(0xFFD97706),
      defaultDistance: SoundDistance.balanced,
      recommendedFor: RelaxationTimeOfDayMode.morning,
      pairedVisualId: 'sunlitCanopy',
    ),
    AmbientSoundItem(
      id: 'roomAmbience',
      titleKey: 'seren_sound_room_title',
      descriptionKey: 'seren_sound_room_desc',
      category: AmbientSoundCategory.indoorCozy,
      icon: Icons.weekend_rounded,
      accentColor: Color(0xFF94A3B8),
      defaultDistance: SoundDistance.near,
      recommendedFor: RelaxationTimeOfDayMode.anytime,
      pairedVisualId: 'driftingClouds',
    ),
    AmbientSoundItem(
      id: 'quietLibrary',
      titleKey: 'seren_sound_library_title',
      descriptionKey: 'seren_sound_library_desc',
      category: AmbientSoundCategory.indoorCozy,
      icon: Icons.menu_book_rounded,
      accentColor: Color(0xFFC084FC),
      defaultDistance: SoundDistance.balanced,
      recommendedFor: RelaxationTimeOfDayMode.anytime,
      pairedVisualId: 'rainyWindow',
    ),

    // --- SLEEP (4 sounds) ---
    AmbientSoundItem(
      id: 'whiteNoise',
      titleKey: 'seren_sound_white_noise_title',
      descriptionKey: 'seren_sound_white_noise_desc',
      category: AmbientSoundCategory.sleep,
      icon: Icons.blur_on_rounded,
      accentColor: Color(0xFFE2E8F0),
      defaultDistance: SoundDistance.balanced,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      pairedVisualId: 'starrySky',
    ),
    AmbientSoundItem(
      id: 'pinkNoise',
      titleKey: 'seren_sound_pink_noise_title',
      descriptionKey: 'seren_sound_pink_noise_desc',
      category: AmbientSoundCategory.sleep,
      icon: Icons.graphic_eq_rounded,
      accentColor: Color(0xFFF472B6),
      defaultDistance: SoundDistance.balanced,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      pairedVisualId: 'starrySky',
    ),
    AmbientSoundItem(
      id: 'brownNoise',
      titleKey: 'seren_sound_brown_noise_title',
      descriptionKey: 'seren_sound_brown_noise_desc',
      category: AmbientSoundCategory.sleep,
      icon: Icons.equalizer_rounded,
      accentColor: Color(0xFFB45309),
      defaultDistance: SoundDistance.far,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      pairedVisualId: 'moonlitLake',
    ),
    AmbientSoundItem(
      id: 'nightAmbience',
      titleKey: 'seren_sound_night_ambience_title',
      descriptionKey: 'seren_sound_night_ambience_desc',
      category: AmbientSoundCategory.sleep,
      icon: Icons.bedtime_rounded,
      accentColor: Color(0xFF6366F1),
      defaultDistance: SoundDistance.far,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      pairedVisualId: 'starrySky',
    ),

    // --- MUSIC (8 sounds) ---
    AmbientSoundItem(
      id: 'calmInstrumental',
      titleKey: 'seren_sound_instrumental_title',
      descriptionKey: 'seren_sound_instrumental_desc',
      category: AmbientSoundCategory.music,
      icon: Icons.music_note_rounded,
      accentColor: Color(0xFF8B5CF6),
      defaultDistance: SoundDistance.balanced,
      recommendedFor: RelaxationTimeOfDayMode.anytime,
      pairedVisualId: 'oceanSunset',
    ),
    AmbientSoundItem(
      id: 'gentlePiano',
      titleKey: 'seren_sound_piano_title',
      descriptionKey: 'seren_sound_piano_desc',
      category: AmbientSoundCategory.music,
      icon: Icons.piano_rounded,
      accentColor: Color(0xFFA78BFA),
      defaultDistance: SoundDistance.near,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      pairedVisualId: 'rainyWindow',
    ),
    AmbientSoundItem(
      id: 'ambientPad',
      titleKey: 'seren_sound_ambient_pad_title',
      descriptionKey: 'seren_sound_ambient_pad_desc',
      category: AmbientSoundCategory.music,
      icon: Icons.surround_sound_rounded,
      accentColor: Color(0xFF14B8A6),
      defaultDistance: SoundDistance.far,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      pairedVisualId: 'underwaterSanctuary',
    ),
    AmbientSoundItem(
      id: 'morningMelody',
      titleKey: 'seren_sound_morning_music_title',
      descriptionKey: 'seren_sound_morning_music_desc',
      category: AmbientSoundCategory.music,
      icon: Icons.wb_twilight_rounded,
      accentColor: Color(0xFFF59E0B),
      defaultDistance: SoundDistance.balanced,
      recommendedFor: RelaxationTimeOfDayMode.morning,
      pairedVisualId: 'morningSunrise',
    ),
    AmbientSoundItem(
      id: 'singingBowls',
      titleKey: 'seren_sound_singing_bowls_title',
      descriptionKey: 'seren_sound_singing_bowls_desc',
      category: AmbientSoundCategory.music,
      icon: Icons.self_improvement_rounded,
      accentColor: Color(0xFFFBBF24),
      defaultDistance: SoundDistance.far,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      pairedVisualId: 'moonlitLake',
    ),
    AmbientSoundItem(
      id: 'softKalimba',
      titleKey: 'seren_sound_soft_kalimba_title',
      descriptionKey: 'seren_sound_soft_kalimba_desc',
      category: AmbientSoundCategory.music,
      icon: Icons.queue_music_rounded,
      accentColor: Color(0xFF34D399),
      defaultDistance: SoundDistance.near,
      recommendedFor: RelaxationTimeOfDayMode.morning,
      pairedVisualId: 'sunlitCanopy',
    ),
    AmbientSoundItem(
      id: 'warmCelloDrone',
      titleKey: 'seren_sound_warm_cello_title',
      descriptionKey: 'seren_sound_warm_cello_desc',
      category: AmbientSoundCategory.music,
      icon: Icons.multitrack_audio_rounded,
      accentColor: Color(0xFFD97706),
      defaultDistance: SoundDistance.balanced,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      pairedVisualId: 'starrySky',
    ),
    AmbientSoundItem(
      id: 'nylonAcousticGuitar',
      titleKey: 'seren_sound_nylon_guitar_title',
      descriptionKey: 'seren_sound_nylon_guitar_desc',
      category: AmbientSoundCategory.music,
      icon: Icons.library_music_rounded,
      accentColor: Color(0xFFEC4899),
      defaultDistance: SoundDistance.near,
      recommendedFor: RelaxationTimeOfDayMode.anytime,
      pairedVisualId: 'oceanSunset',
    ),
  ];

  static AmbientSoundItem soundById(String id) {
    return sounds.firstWhere(
      (s) => s.id == id,
      orElse: () => sounds.first,
    );
  }

  /// Curated starter soundscape presets (Feature B).
  static List<SavedSoundscape> get curatedPresets {
    final epoch = DateTime(2026, 1, 1);
    return [
      SavedSoundscape(
        id: 'preset_rain_thunder',
        name: 'Rain + Thunder',
        nameKey: 'seren_preset_rain_thunder_name',
        descriptionKey: 'seren_preset_rain_thunder_desc',
        tracks: const [
          SoundMixerTrackConfig(
            soundId: 'rainWindow',
            volume: 0.75,
            distance: SoundDistance.near,
            stereoPosition: StereoPosition.center,
          ),
          SoundMixerTrackConfig(
            soundId: 'thunderstorm',
            volume: 0.50,
            distance: SoundDistance.far,
            stereoPosition: StereoPosition.right,
          ),
        ],
        masterVolume: 0.80,
        pairedVisualId: 'rainyWindow',
        recommendedFor: RelaxationTimeOfDayMode.evening,
        isPreset: true,
        createdAt: epoch,
        updatedAt: epoch,
      ),
      SavedSoundscape(
        id: 'preset_rain_fireplace',
        name: 'Rain + Fireplace',
        nameKey: 'seren_preset_rain_fireplace_name',
        descriptionKey: 'seren_preset_rain_fireplace_desc',
        tracks: const [
          SoundMixerTrackConfig(
            soundId: 'rain',
            volume: 0.65,
            distance: SoundDistance.balanced,
            stereoPosition: StereoPosition.left,
          ),
          SoundMixerTrackConfig(
            soundId: 'fireplace',
            volume: 0.72,
            distance: SoundDistance.near,
            stereoPosition: StereoPosition.right,
          ),
        ],
        masterVolume: 0.80,
        pairedVisualId: 'rainyWindow',
        recommendedFor: RelaxationTimeOfDayMode.evening,
        isPreset: true,
        createdAt: epoch,
        updatedAt: epoch,
      ),
      SavedSoundscape(
        id: 'preset_ocean_wind',
        name: 'Ocean + Wind',
        nameKey: 'seren_preset_ocean_wind_name',
        descriptionKey: 'seren_preset_ocean_wind_desc',
        tracks: const [
          SoundMixerTrackConfig(
            soundId: 'oceanWaves',
            volume: 0.75,
            distance: SoundDistance.balanced,
            stereoPosition: StereoPosition.center,
          ),
          SoundMixerTrackConfig(
            soundId: 'gentleWind',
            volume: 0.45,
            distance: SoundDistance.far,
            stereoPosition: StereoPosition.left,
          ),
        ],
        masterVolume: 0.80,
        pairedVisualId: 'oceanSunset',
        recommendedFor: RelaxationTimeOfDayMode.anytime,
        isPreset: true,
        createdAt: epoch,
        updatedAt: epoch,
      ),
      SavedSoundscape(
        id: 'preset_forest_birds',
        name: 'Forest + Birds',
        nameKey: 'seren_preset_forest_birds_name',
        descriptionKey: 'seren_preset_forest_birds_desc',
        tracks: const [
          SoundMixerTrackConfig(
            soundId: 'forest',
            volume: 0.70,
            distance: SoundDistance.balanced,
            stereoPosition: StereoPosition.center,
          ),
          SoundMixerTrackConfig(
            soundId: 'birdsSinging',
            volume: 0.55,
            distance: SoundDistance.near,
            stereoPosition: StereoPosition.right,
          ),
        ],
        masterVolume: 0.78,
        pairedVisualId: 'morningSunrise',
        recommendedFor: RelaxationTimeOfDayMode.morning,
        isPreset: true,
        createdAt: epoch,
        updatedAt: epoch,
      ),
      SavedSoundscape(
        id: 'preset_night_insects_wind',
        name: 'Night Insects + Gentle Wind',
        nameKey: 'seren_preset_night_insects_wind_name',
        descriptionKey: 'seren_preset_night_insects_wind_desc',
        tracks: const [
          SoundMixerTrackConfig(
            soundId: 'nightInsects',
            volume: 0.65,
            distance: SoundDistance.balanced,
            stereoPosition: StereoPosition.center,
          ),
          SoundMixerTrackConfig(
            soundId: 'gentleWind',
            volume: 0.45,
            distance: SoundDistance.far,
            stereoPosition: StereoPosition.left,
          ),
        ],
        masterVolume: 0.75,
        pairedVisualId: 'forestFireflies',
        recommendedFor: RelaxationTimeOfDayMode.evening,
        isPreset: true,
        createdAt: epoch,
        updatedAt: epoch,
      ),
      SavedSoundscape(
        id: 'preset_storm_hearth',
        name: 'Rain + Distant Thunder + Fireplace',
        nameKey: 'seren_preset_storm_hearth_name',
        descriptionKey: 'seren_preset_storm_hearth_desc',
        tracks: const [
          SoundMixerTrackConfig(
            soundId: 'rainWindow',
            volume: 0.70,
            distance: SoundDistance.near,
            stereoPosition: StereoPosition.left,
          ),
          SoundMixerTrackConfig(
            soundId: 'thunderstorm',
            volume: 0.42,
            distance: SoundDistance.far,
            stereoPosition: StereoPosition.center,
          ),
          SoundMixerTrackConfig(
            soundId: 'fireplace',
            volume: 0.68,
            distance: SoundDistance.near,
            stereoPosition: StereoPosition.right,
          ),
        ],
        masterVolume: 0.82,
        pairedVisualId: 'rainyWindow',
        recommendedFor: RelaxationTimeOfDayMode.evening,
        isPreset: true,
        createdAt: epoch,
        updatedAt: epoch,
      ),
      SavedSoundscape(
        id: 'preset_peaceful_morning',
        name: 'Peaceful Morning Sanctuary',
        nameKey: 'seren_preset_peaceful_morning_name',
        descriptionKey: 'seren_preset_peaceful_morning_desc',
        tracks: const [
          SoundMixerTrackConfig(
            soundId: 'morningMelody',
            volume: 0.60,
            distance: SoundDistance.balanced,
            stereoPosition: StereoPosition.center,
          ),
          SoundMixerTrackConfig(
            soundId: 'birdsSinging',
            volume: 0.45,
            distance: SoundDistance.far,
            stereoPosition: StereoPosition.left,
          ),
          SoundMixerTrackConfig(
            soundId: 'riverStream',
            volume: 0.48,
            distance: SoundDistance.balanced,
            stereoPosition: StereoPosition.right,
          ),
        ],
        masterVolume: 0.76,
        pairedVisualId: 'morningSunrise',
        recommendedFor: RelaxationTimeOfDayMode.morning,
        isPreset: true,
        createdAt: epoch,
        updatedAt: epoch,
      ),
      SavedSoundscape(
        id: 'preset_kalimba_forest_stream',
        name: 'Soft Kalimba + Forest Stream',
        nameKey: 'seren_preset_kalimba_forest_stream_name',
        descriptionKey: 'seren_preset_kalimba_forest_stream_desc',
        tracks: const [
          SoundMixerTrackConfig(
            soundId: 'softKalimba',
            volume: 0.62,
            distance: SoundDistance.near,
            stereoPosition: StereoPosition.center,
          ),
          SoundMixerTrackConfig(
            soundId: 'forest',
            volume: 0.55,
            distance: SoundDistance.balanced,
            stereoPosition: StereoPosition.left,
          ),
          SoundMixerTrackConfig(
            soundId: 'riverStream',
            volume: 0.48,
            distance: SoundDistance.far,
            stereoPosition: StereoPosition.right,
          ),
        ],
        masterVolume: 0.78,
        pairedVisualId: 'sunlitCanopy',
        recommendedFor: RelaxationTimeOfDayMode.morning,
        isPreset: true,
        createdAt: epoch,
        updatedAt: epoch,
      ),
      SavedSoundscape(
        id: 'preset_bowls_cello_rain',
        name: 'Singing Bowls + Warm Cello + Rain',
        nameKey: 'seren_preset_bowls_cello_rain_name',
        descriptionKey: 'seren_preset_bowls_cello_rain_desc',
        tracks: const [
          SoundMixerTrackConfig(
            soundId: 'singingBowls',
            volume: 0.52,
            distance: SoundDistance.far,
            stereoPosition: StereoPosition.left,
          ),
          SoundMixerTrackConfig(
            soundId: 'warmCelloDrone',
            volume: 0.58,
            distance: SoundDistance.balanced,
            stereoPosition: StereoPosition.center,
          ),
          SoundMixerTrackConfig(
            soundId: 'rainWindow',
            volume: 0.65,
            distance: SoundDistance.near,
            stereoPosition: StereoPosition.right,
          ),
        ],
        masterVolume: 0.78,
        pairedVisualId: 'moonlitLake',
        recommendedFor: RelaxationTimeOfDayMode.evening,
        isPreset: true,
        createdAt: epoch,
        updatedAt: epoch,
      ),
    ];
  }

  /// Configurable Guided Breathing & Relaxation Sessions (Feature C).
  static const List<GuidedRelaxationSession> guidedSessions = [
    // Breathing exercises
    GuidedRelaxationSession(
      id: 'breath_slow',
      titleKey: 'seren_guided_slow_breath_title',
      subtitleKey: 'seren_guided_slow_breath_sub',
      category: GuidedRelaxationCategory.breathing,
      recommendedFor: RelaxationTimeOfDayMode.anytime,
      availableDurationsMinutes: [2, 3, 5, 10],
      defaultDurationMinutes: 3,
      breathingSteps: [
        BreathingPhaseStep(
          instructionKey: 'inhale_gently',
          seconds: 5,
          targetScale: 1.25,
        ),
        BreathingPhaseStep(
          instructionKey: 'exhale_slowly',
          seconds: 5,
          targetScale: 0.80,
        ),
      ],
      narrationPromptKeys: [
        'seren_prompt_settle_posture',
        'seren_prompt_slow_inhale_exhale',
        'seren_prompt_stop_if_uncomfortable',
      ],
      recommendedSoundId: 'oceanWaves',
      icon: Icons.air_rounded,
      accentColor: Color(0xFF38BDF8),
    ),
    GuidedRelaxationSession(
      id: 'breath_box',
      titleKey: 'seren_guided_box_breath_title',
      subtitleKey: 'seren_guided_box_breath_sub',
      category: GuidedRelaxationCategory.breathing,
      recommendedFor: RelaxationTimeOfDayMode.morning,
      availableDurationsMinutes: [2, 3, 5, 10],
      defaultDurationMinutes: 3,
      breathingSteps: [
        BreathingPhaseStep(
          instructionKey: 'inhale_gently',
          seconds: 4,
          targetScale: 1.25,
        ),
        BreathingPhaseStep(
          instructionKey: 'hold_softly',
          seconds: 4,
          targetScale: 1.25,
        ),
        BreathingPhaseStep(
          instructionKey: 'exhale_slowly',
          seconds: 4,
          targetScale: 0.80,
        ),
        BreathingPhaseStep(
          instructionKey: 'rest_calmly',
          seconds: 4,
          targetScale: 0.80,
        ),
      ],
      narrationPromptKeys: [
        'seren_prompt_box_intro',
        'seren_prompt_box_rhythm',
        'seren_prompt_stop_if_uncomfortable',
      ],
      recommendedSoundId: 'forest',
      icon: Icons.crop_square_rounded,
      accentColor: Color(0xFF10B981),
    ),
    GuidedRelaxationSession(
      id: 'breath_478',
      titleKey: 'seren_guided_478_breath_title',
      subtitleKey: 'seren_guided_478_breath_sub',
      category: GuidedRelaxationCategory.breathing,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      availableDurationsMinutes: [2, 3, 5, 8],
      defaultDurationMinutes: 3,
      breathingSteps: [
        BreathingPhaseStep(
          instructionKey: 'inhale_nose',
          seconds: 4,
          targetScale: 1.25,
        ),
        BreathingPhaseStep(
          instructionKey: 'hold_breath',
          seconds: 7,
          targetScale: 1.25,
        ),
        BreathingPhaseStep(
          instructionKey: 'exhale_mouth',
          seconds: 8,
          targetScale: 0.80,
        ),
      ],
      narrationPromptKeys: [
        'seren_prompt_478_intro',
        'seren_prompt_478_exhale_release',
        'seren_prompt_stop_if_uncomfortable',
      ],
      recommendedSoundId: 'rain',
      icon: Icons.nightlight_round,
      accentColor: Color(0xFF8B5CF6),
    ),
    GuidedRelaxationSession(
      id: 'breath_gentle_morning',
      titleKey: 'seren_guided_morning_breath_title',
      subtitleKey: 'seren_guided_morning_breath_sub',
      category: GuidedRelaxationCategory.breathing,
      recommendedFor: RelaxationTimeOfDayMode.morning,
      availableDurationsMinutes: [2, 3, 5],
      defaultDurationMinutes: 2,
      breathingSteps: [
        BreathingPhaseStep(
          instructionKey: 'inhale_gently',
          seconds: 4,
          targetScale: 1.22,
        ),
        BreathingPhaseStep(
          instructionKey: 'hold_softly',
          seconds: 2,
          targetScale: 1.22,
        ),
        BreathingPhaseStep(
          instructionKey: 'exhale_slowly',
          seconds: 4,
          targetScale: 0.82,
        ),
      ],
      narrationPromptKeys: [
        'seren_prompt_morning_awaken',
        'seren_prompt_morning_fresh_air',
      ],
      recommendedSoundId: 'birdsSinging',
      icon: Icons.wb_sunny_rounded,
      accentColor: Color(0xFFF59E0B),
    ),

    // Guided Relaxation exercises
    GuidedRelaxationSession(
      id: 'relax_pmr',
      titleKey: 'seren_guided_pmr_title',
      subtitleKey: 'seren_guided_pmr_sub',
      category: GuidedRelaxationCategory.relaxation,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      availableDurationsMinutes: [3, 5, 10],
      defaultDurationMinutes: 5,
      breathingSteps: [
        BreathingPhaseStep(
          instructionKey: 'inhale_gently',
          seconds: 4,
          targetScale: 1.20,
        ),
        BreathingPhaseStep(
          instructionKey: 'exhale_slowly',
          seconds: 6,
          targetScale: 0.82,
        ),
      ],
      narrationPromptKeys: [
        'seren_prompt_pmr_shoulders',
        'seren_prompt_pmr_hands',
        'seren_prompt_pmr_jaw_forehead',
        'seren_prompt_pmr_legs_feet',
      ],
      recommendedSoundId: 'rainWindow',
      icon: Icons.accessibility_new_rounded,
      accentColor: Color(0xFFA78BFA),
    ),
    GuidedRelaxationSession(
      id: 'relax_body_scan',
      titleKey: 'seren_guided_body_scan_title',
      subtitleKey: 'seren_guided_body_scan_sub',
      category: GuidedRelaxationCategory.relaxation,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      availableDurationsMinutes: [3, 5, 10],
      defaultDurationMinutes: 5,
      breathingSteps: [
        BreathingPhaseStep(
          instructionKey: 'inhale_gently',
          seconds: 5,
          targetScale: 1.20,
        ),
        BreathingPhaseStep(
          instructionKey: 'exhale_slowly',
          seconds: 5,
          targetScale: 0.82,
        ),
      ],
      narrationPromptKeys: [
        'seren_prompt_scan_crown',
        'seren_prompt_scan_chest',
        'seren_prompt_scan_resting_weight',
      ],
      recommendedSoundId: 'nightAmbience',
      icon: Icons.self_improvement_rounded,
      accentColor: Color(0xFF6366F1),
    ),
    GuidedRelaxationSession(
      id: 'relax_morning_peace',
      titleKey: 'seren_guided_morning_relax_title',
      subtitleKey: 'seren_guided_morning_relax_sub',
      category: GuidedRelaxationCategory.relaxation,
      recommendedFor: RelaxationTimeOfDayMode.morning,
      availableDurationsMinutes: [2, 3, 5],
      defaultDurationMinutes: 3,
      breathingSteps: [
        BreathingPhaseStep(
          instructionKey: 'inhale_gently',
          seconds: 4,
          targetScale: 1.20,
        ),
        BreathingPhaseStep(
          instructionKey: 'exhale_slowly',
          seconds: 4,
          targetScale: 0.84,
        ),
      ],
      narrationPromptKeys: [
        'seren_prompt_morning_stillness',
        'seren_prompt_morning_unhurried_pace',
      ],
      recommendedSoundId: 'morningMelody',
      icon: Icons.wb_twilight_rounded,
      accentColor: Color(0xFFFBBF24),
    ),
    GuidedRelaxationSession(
      id: 'relax_evening_decompress',
      titleKey: 'seren_guided_evening_let_go_title',
      subtitleKey: 'seren_guided_evening_let_go_sub',
      category: GuidedRelaxationCategory.relaxation,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      availableDurationsMinutes: [3, 5, 10],
      defaultDurationMinutes: 5,
      breathingSteps: [
        BreathingPhaseStep(
          instructionKey: 'inhale_gently',
          seconds: 4,
          targetScale: 1.20,
        ),
        BreathingPhaseStep(
          instructionKey: 'exhale_slowly',
          seconds: 6,
          targetScale: 0.80,
        ),
      ],
      narrationPromptKeys: [
        'seren_prompt_evening_set_aside_tasks',
        'seren_prompt_evening_quiet_sanctuary',
        'seren_prompt_evening_sleep_ready',
      ],
      recommendedSoundId: 'fireplace',
      icon: Icons.bedtime_rounded,
      accentColor: Color(0xFF8B5CF6),
    ),
  ];

  /// Calming Visual Environments (Feature E & F).
  static const List<VisualEnvironmentScene> visualScenes = [
    VisualEnvironmentScene(
      id: 'rainyWindow',
      titleKey: 'seren_visual_rainy_window_title',
      subtitleKey: 'seren_visual_rainy_window_sub',
      category: VisualEnvironmentCategory.nature,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      pairedSoundId: 'rain',
      gradientColors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
      accentParticleColor: Color(0xFF38BDF8),
      icon: Icons.water_drop_rounded,
    ),
    VisualEnvironmentScene(
      id: 'oceanSunset',
      titleKey: 'seren_visual_ocean_sunset_title',
      subtitleKey: 'seren_visual_ocean_sunset_sub',
      category: VisualEnvironmentCategory.nature,
      recommendedFor: RelaxationTimeOfDayMode.anytime,
      pairedSoundId: 'oceanWaves',
      gradientColors: [Color(0xFF1E1B4B), Color(0xFF4C1D95), Color(0xFF0284C7)],
      accentParticleColor: Color(0xFFFBBF24),
      icon: Icons.waves_rounded,
    ),
    VisualEnvironmentScene(
      id: 'forestBreeze',
      titleKey: 'seren_visual_forest_breeze_title',
      subtitleKey: 'seren_visual_forest_breeze_sub',
      category: VisualEnvironmentCategory.nature,
      recommendedFor: RelaxationTimeOfDayMode.morning,
      pairedSoundId: 'forest',
      gradientColors: [Color(0xFF064E3B), Color(0xFF065F46), Color(0xFF115E59)],
      accentParticleColor: Color(0xFF6EE7B7),
      icon: Icons.park_rounded,
    ),
    VisualEnvironmentScene(
      id: 'driftingClouds',
      titleKey: 'seren_visual_drifting_clouds_title',
      subtitleKey: 'seren_visual_drifting_clouds_sub',
      category: VisualEnvironmentCategory.nature,
      recommendedFor: RelaxationTimeOfDayMode.anytime,
      pairedSoundId: 'gentleWind',
      gradientColors: [Color(0xFF1E293B), Color(0xFF3B4252), Color(0xFF475569)],
      accentParticleColor: Color(0xFFE2E8F0),
      icon: Icons.cloud_queue_rounded,
    ),
    VisualEnvironmentScene(
      id: 'starrySky',
      titleKey: 'seren_visual_starry_sky_title',
      subtitleKey: 'seren_visual_starry_sky_sub',
      category: VisualEnvironmentCategory.night,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      pairedSoundId: 'nightAmbience',
      gradientColors: [Color(0xFF090A0F), Color(0xFF1B2735), Color(0xFF1E1B4B)],
      accentParticleColor: Color(0xFFE0E7FF),
      icon: Icons.auto_awesome_rounded,
    ),
    VisualEnvironmentScene(
      id: 'forestFireflies',
      titleKey: 'seren_visual_fireflies_title',
      subtitleKey: 'seren_visual_fireflies_sub',
      category: VisualEnvironmentCategory.night,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      pairedSoundId: 'nightInsects',
      gradientColors: [Color(0xFF052E16), Color(0xFF14532D), Color(0xFF0F172A)],
      accentParticleColor: Color(0xFFFDE047),
      icon: Icons.nights_stay_rounded,
    ),
    VisualEnvironmentScene(
      id: 'moonlitLake',
      titleKey: 'seren_visual_moonlit_lake_title',
      subtitleKey: 'seren_visual_moonlit_lake_sub',
      category: VisualEnvironmentCategory.night,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      pairedSoundId: 'fireplace',
      gradientColors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
      accentParticleColor: Color(0xFFC7D2FE),
      icon: Icons.brightness_3_rounded,
    ),
    VisualEnvironmentScene(
      id: 'morningSunrise',
      titleKey: 'seren_visual_morning_sunrise_title',
      subtitleKey: 'seren_visual_morning_sunrise_sub',
      category: VisualEnvironmentCategory.daytime,
      recommendedFor: RelaxationTimeOfDayMode.morning,
      pairedSoundId: 'birdsSinging',
      gradientColors: [Color(0xFF31102F), Color(0xFF7C2D12), Color(0xFFD97706)],
      accentParticleColor: Color(0xFFFDE68A),
      icon: Icons.wb_twilight_rounded,
    ),
    VisualEnvironmentScene(
      id: 'sunlitCanopy',
      titleKey: 'seren_visual_sunlit_canopy_title',
      subtitleKey: 'seren_visual_sunlit_canopy_sub',
      category: VisualEnvironmentCategory.daytime,
      recommendedFor: RelaxationTimeOfDayMode.morning,
      pairedSoundId: 'riverStream',
      gradientColors: [Color(0xFF064E3B), Color(0xFF0F766E), Color(0xFF0369A1)],
      accentParticleColor: Color(0xFFA7F3D0),
      icon: Icons.wb_sunny_rounded,
    ),
    VisualEnvironmentScene(
      id: 'underwaterSanctuary',
      titleKey: 'seren_visual_underwater_title',
      subtitleKey: 'seren_visual_underwater_sub',
      category: VisualEnvironmentCategory.underwater,
      recommendedFor: RelaxationTimeOfDayMode.anytime,
      pairedSoundId: 'riverStream',
      gradientColors: [Color(0xFF042F2E), Color(0xFF0F766E), Color(0xFF0C4A6E)],
      accentParticleColor: Color(0xFF5EEAD4),
      icon: Icons.bubble_chart_rounded,
    ),
  ];

  static List<VisualEnvironmentScene> get visuals => visualScenes;

  static VisualEnvironmentScene visualById(String id) {
    return visualScenes.firstWhere(
      (v) => v.id == id,
      orElse: () => visualScenes.first,
    );
  }

  /// Bedtime Stories & Relaxation Readings with TTS support (Feature G).
  static const List<RelaxationReadingItem> readings = [
    RelaxationReadingItem(
      id: 'story_lantern_cove',
      titleKey: 'seren_story_lantern_cove_title',
      subtitleKey: 'seren_story_lantern_cove_sub',
      category: RelaxationReadingCategory.bedtimeStories,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 5,
      pairedSoundId: 'oceanWaves',
      pairedVisualId: 'oceanSunset',
      paragraphKeys: [
        'seren_story_lantern_cove_p1',
        'seren_story_lantern_cove_p2',
        'seren_story_lantern_cove_p3',
        'seren_story_lantern_cove_p4',
      ],
      icon: Icons.light_rounded,
    ),
    RelaxationReadingItem(
      id: 'story_pine_valley_train',
      titleKey: 'seren_story_pine_train_title',
      subtitleKey: 'seren_story_pine_train_sub',
      category: RelaxationReadingCategory.bedtimeStories,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 6,
      pairedSoundId: 'rainWindow',
      pairedVisualId: 'rainyWindow',
      paragraphKeys: [
        'seren_story_pine_train_p1',
        'seren_story_pine_train_p2',
        'seren_story_pine_train_p3',
        'seren_story_pine_train_p4',
      ],
      icon: Icons.train_rounded,
    ),
    RelaxationReadingItem(
      id: 'story_mossy_roof_rain',
      titleKey: 'seren_story_mossy_roof_title',
      subtitleKey: 'seren_story_mossy_roof_sub',
      category: RelaxationReadingCategory.natureStories,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 4,
      pairedSoundId: 'rain',
      pairedVisualId: 'forestBreeze',
      paragraphKeys: [
        'seren_story_mossy_roof_p1',
        'seren_story_mossy_roof_p2',
        'seren_story_mossy_roof_p3',
      ],
      icon: Icons.park_rounded,
    ),
    RelaxationReadingItem(
      id: 'story_cloud_observatory',
      titleKey: 'seren_story_cloud_obs_title',
      subtitleKey: 'seren_story_cloud_obs_sub',
      category: RelaxationReadingCategory.fictionalJourneys,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 5,
      pairedSoundId: 'gentleWind',
      pairedVisualId: 'starrySky',
      paragraphKeys: [
        'seren_story_cloud_obs_p1',
        'seren_story_cloud_obs_p2',
        'seren_story_cloud_obs_p3',
      ],
      icon: Icons.cloud_rounded,
    ),
    RelaxationReadingItem(
      id: 'reading_forest_dusk_facts',
      titleKey: 'seren_reading_forest_facts_title',
      subtitleKey: 'seren_reading_forest_facts_sub',
      category: RelaxationReadingCategory.natureFacts,
      recommendedFor: RelaxationTimeOfDayMode.anytime,
      estimatedMinutes: 3,
      pairedSoundId: 'forest',
      pairedVisualId: 'forestFireflies',
      paragraphKeys: [
        'seren_reading_forest_facts_p1',
        'seren_reading_forest_facts_p2',
        'seren_reading_forest_facts_p3',
      ],
      icon: Icons.eco_rounded,
    ),
    RelaxationReadingItem(
      id: 'reading_evening_stillness',
      titleKey: 'seren_reading_evening_stillness_title',
      subtitleKey: 'seren_reading_evening_stillness_sub',
      category: RelaxationReadingCategory.reflectiveReadings,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 3,
      pairedSoundId: 'gentlePiano',
      pairedVisualId: 'moonlitLake',
      paragraphKeys: [
        'seren_reading_evening_stillness_p1',
        'seren_reading_evening_stillness_p2',
        'seren_reading_evening_stillness_p3',
      ],
      icon: Icons.auto_stories_rounded,
    ),
    RelaxationReadingItem(
      id: 'reading_morning_first_light',
      titleKey: 'seren_reading_morning_light_title',
      subtitleKey: 'seren_reading_morning_light_sub',
      category: RelaxationReadingCategory.morningReadings,
      recommendedFor: RelaxationTimeOfDayMode.morning,
      estimatedMinutes: 3,
      pairedSoundId: 'birdsSinging',
      pairedVisualId: 'morningSunrise',
      paragraphKeys: [
        'seren_reading_morning_light_p1',
        'seren_reading_morning_light_p2',
        'seren_reading_morning_light_p3',
      ],
      icon: Icons.wb_sunny_rounded,
    ),
    RelaxationReadingItem(
      id: 'reading_positive_beginning',
      titleKey: 'seren_reading_positive_thought_title',
      subtitleKey: 'seren_reading_positive_thought_sub',
      category: RelaxationReadingCategory.positiveThoughts,
      recommendedFor: RelaxationTimeOfDayMode.morning,
      estimatedMinutes: 2,
      pairedSoundId: 'morningMelody',
      pairedVisualId: 'sunlitCanopy',
      paragraphKeys: [
        'seren_reading_positive_thought_p1',
        'seren_reading_positive_thought_p2',
        'seren_reading_positive_thought_p3',
      ],
      icon: Icons.favorite_border_rounded,
    ),
    // -------------------------------------------------------------------------
    // EXTENDED MULTI-CHAPTER BEDTIME STORY ANTHOLOGY (6 STORIES)
    // -------------------------------------------------------------------------
    RelaxationReadingItem(
      id: 'anthology_clockmaker_harbor',
      titleKey: 'seren_anth_clockmaker_harbor_title',
      subtitleKey: 'seren_anth_clockmaker_harbor_sub',
      category: RelaxationReadingCategory.bedtimeStories,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 14,
      pairedSoundId: 'oceanWaves',
      pairedVisualId: 'oceanSunset',
      seasonTag: ReadingSeasonTag.autumn,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_clockmaker_harbor_c1_title',
          paragraphKeys: [
            'seren_anth_clockmaker_harbor_c1_p1',
            'seren_anth_clockmaker_harbor_c1_p2',
            'seren_anth_clockmaker_harbor_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_clockmaker_harbor_c2_title',
          paragraphKeys: [
            'seren_anth_clockmaker_harbor_c2_p1',
            'seren_anth_clockmaker_harbor_c2_p2',
            'seren_anth_clockmaker_harbor_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_clockmaker_harbor_c3_title',
          paragraphKeys: [
            'seren_anth_clockmaker_harbor_c3_p1',
            'seren_anth_clockmaker_harbor_c3_p2',
            'seren_anth_clockmaker_harbor_c3_p3',
          ],
        ),
      ],
      icon: Icons.anchor_rounded,
    ),
    RelaxationReadingItem(
      id: 'anthology_paper_owl_library',
      titleKey: 'seren_anth_paper_owl_library_title',
      subtitleKey: 'seren_anth_paper_owl_library_sub',
      category: RelaxationReadingCategory.bedtimeStories,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 15,
      pairedSoundId: 'rainWindow',
      pairedVisualId: 'rainyWindow',
      seasonTag: ReadingSeasonTag.winter,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_paper_owl_library_c1_title',
          paragraphKeys: [
            'seren_anth_paper_owl_library_c1_p1',
            'seren_anth_paper_owl_library_c1_p2',
            'seren_anth_paper_owl_library_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_paper_owl_library_c2_title',
          paragraphKeys: [
            'seren_anth_paper_owl_library_c2_p1',
            'seren_anth_paper_owl_library_c2_p2',
            'seren_anth_paper_owl_library_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_paper_owl_library_c3_title',
          paragraphKeys: [
            'seren_anth_paper_owl_library_c3_p1',
            'seren_anth_paper_owl_library_c3_p2',
            'seren_anth_paper_owl_library_c3_p3',
          ],
        ),
      ],
      icon: Icons.menu_book_rounded,
    ),
    RelaxationReadingItem(
      id: 'anthology_floating_bakery',
      titleKey: 'seren_anth_floating_bakery_title',
      subtitleKey: 'seren_anth_floating_bakery_sub',
      category: RelaxationReadingCategory.bedtimeStories,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 12,
      pairedSoundId: 'riverStream',
      pairedVisualId: 'moonlitLake',
      seasonTag: ReadingSeasonTag.spring,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_floating_bakery_c1_title',
          paragraphKeys: [
            'seren_anth_floating_bakery_c1_p1',
            'seren_anth_floating_bakery_c1_p2',
            'seren_anth_floating_bakery_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_floating_bakery_c2_title',
          paragraphKeys: [
            'seren_anth_floating_bakery_c2_p1',
            'seren_anth_floating_bakery_c2_p2',
            'seren_anth_floating_bakery_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_floating_bakery_c3_title',
          paragraphKeys: [
            'seren_anth_floating_bakery_c3_p1',
            'seren_anth_floating_bakery_c3_p2',
            'seren_anth_floating_bakery_c3_p3',
          ],
        ),
      ],
      icon: Icons.bakery_dining_rounded,
    ),
    RelaxationReadingItem(
      id: 'anthology_glass_conservatory',
      titleKey: 'seren_anth_glass_conservatory_title',
      subtitleKey: 'seren_anth_glass_conservatory_sub',
      category: RelaxationReadingCategory.bedtimeStories,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 16,
      pairedSoundId: 'rain',
      pairedVisualId: 'forestBreeze',
      seasonTag: ReadingSeasonTag.botanical,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_glass_conservatory_c1_title',
          paragraphKeys: [
            'seren_anth_glass_conservatory_c1_p1',
            'seren_anth_glass_conservatory_c1_p2',
            'seren_anth_glass_conservatory_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_glass_conservatory_c2_title',
          paragraphKeys: [
            'seren_anth_glass_conservatory_c2_p1',
            'seren_anth_glass_conservatory_c2_p2',
            'seren_anth_glass_conservatory_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_glass_conservatory_c3_title',
          paragraphKeys: [
            'seren_anth_glass_conservatory_c3_p1',
            'seren_anth_glass_conservatory_c3_p2',
            'seren_anth_glass_conservatory_c3_p3',
          ],
        ),
      ],
      icon: Icons.spa_rounded,
    ),
    RelaxationReadingItem(
      id: 'anthology_lighthouse_notebook',
      titleKey: 'seren_anth_lighthouse_notebook_title',
      subtitleKey: 'seren_anth_lighthouse_notebook_sub',
      category: RelaxationReadingCategory.bedtimeStories,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 18,
      pairedSoundId: 'nightAmbience',
      pairedVisualId: 'starrySky',
      seasonTag: ReadingSeasonTag.nightSky,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_lighthouse_notebook_c1_title',
          paragraphKeys: [
            'seren_anth_lighthouse_notebook_c1_p1',
            'seren_anth_lighthouse_notebook_c1_p2',
            'seren_anth_lighthouse_notebook_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_lighthouse_notebook_c2_title',
          paragraphKeys: [
            'seren_anth_lighthouse_notebook_c2_p1',
            'seren_anth_lighthouse_notebook_c2_p2',
            'seren_anth_lighthouse_notebook_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_lighthouse_notebook_c3_title',
          paragraphKeys: [
            'seren_anth_lighthouse_notebook_c3_p1',
            'seren_anth_lighthouse_notebook_c3_p2',
            'seren_anth_lighthouse_notebook_c3_p3',
          ],
        ),
      ],
      icon: Icons.brightness_3_rounded,
    ),
    RelaxationReadingItem(
      id: 'anthology_silk_quilt_attic',
      titleKey: 'seren_anth_silk_quilt_attic_title',
      subtitleKey: 'seren_anth_silk_quilt_attic_sub',
      category: RelaxationReadingCategory.bedtimeStories,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 12,
      pairedSoundId: 'fireplace',
      pairedVisualId: 'driftingClouds',
      seasonTag: ReadingSeasonTag.winter,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_silk_quilt_attic_c1_title',
          paragraphKeys: [
            'seren_anth_silk_quilt_attic_c1_p1',
            'seren_anth_silk_quilt_attic_c1_p2',
            'seren_anth_silk_quilt_attic_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_silk_quilt_attic_c2_title',
          paragraphKeys: [
            'seren_anth_silk_quilt_attic_c2_p1',
            'seren_anth_silk_quilt_attic_c2_p2',
            'seren_anth_silk_quilt_attic_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_silk_quilt_attic_c3_title',
          paragraphKeys: [
            'seren_anth_silk_quilt_attic_c3_p1',
            'seren_anth_silk_quilt_attic_c3_p2',
            'seren_anth_silk_quilt_attic_c3_p3',
          ],
        ),
      ],
      icon: Icons.bedtime_rounded,
    ),
    // -------------------------------------------------------------------------
    // SLOW TRAIN, FERRY & CANAL TRAVELOGUES (6 TRAVELOGUES)
    // -------------------------------------------------------------------------
    RelaxationReadingItem(
      id: 'travelogue_java_night_express',
      titleKey: 'seren_anth_java_night_express_title',
      subtitleKey: 'seren_anth_java_night_express_sub',
      category: RelaxationReadingCategory.slowTravelogues,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 16,
      pairedSoundId: 'rainWindow',
      pairedVisualId: 'rainyWindow',
      seasonTag: ReadingSeasonTag.monsoon,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_java_night_express_c1_title',
          paragraphKeys: [
            'seren_anth_java_night_express_c1_p1',
            'seren_anth_java_night_express_c1_p2',
            'seren_anth_java_night_express_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_java_night_express_c2_title',
          paragraphKeys: [
            'seren_anth_java_night_express_c2_p1',
            'seren_anth_java_night_express_c2_p2',
            'seren_anth_java_night_express_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_java_night_express_c3_title',
          paragraphKeys: [
            'seren_anth_java_night_express_c3_p1',
            'seren_anth_java_night_express_c3_p2',
            'seren_anth_java_night_express_c3_p3',
          ],
        ),
      ],
      icon: Icons.train_rounded,
    ),
    RelaxationReadingItem(
      id: 'travelogue_fjord_mail_steamer',
      titleKey: 'seren_anth_fjord_mail_steamer_title',
      subtitleKey: 'seren_anth_fjord_mail_steamer_sub',
      category: RelaxationReadingCategory.slowTravelogues,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 18,
      pairedSoundId: 'oceanWaves',
      pairedVisualId: 'moonlitLake',
      seasonTag: ReadingSeasonTag.winter,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_fjord_mail_steamer_c1_title',
          paragraphKeys: [
            'seren_anth_fjord_mail_steamer_c1_p1',
            'seren_anth_fjord_mail_steamer_c1_p2',
            'seren_anth_fjord_mail_steamer_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_fjord_mail_steamer_c2_title',
          paragraphKeys: [
            'seren_anth_fjord_mail_steamer_c2_p1',
            'seren_anth_fjord_mail_steamer_c2_p2',
            'seren_anth_fjord_mail_steamer_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_fjord_mail_steamer_c3_title',
          paragraphKeys: [
            'seren_anth_fjord_mail_steamer_c3_p1',
            'seren_anth_fjord_mail_steamer_c3_p2',
            'seren_anth_fjord_mail_steamer_c3_p3',
          ],
        ),
      ],
      icon: Icons.directions_boat_rounded,
    ),
    RelaxationReadingItem(
      id: 'travelogue_kyoto_canal_boat',
      titleKey: 'seren_anth_kyoto_canal_boat_title',
      subtitleKey: 'seren_anth_kyoto_canal_boat_sub',
      category: RelaxationReadingCategory.slowTravelogues,
      recommendedFor: RelaxationTimeOfDayMode.anytime,
      estimatedMinutes: 14,
      pairedSoundId: 'riverStream',
      pairedVisualId: 'sunlitCanopy',
      seasonTag: ReadingSeasonTag.autumn,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_kyoto_canal_boat_c1_title',
          paragraphKeys: [
            'seren_anth_kyoto_canal_boat_c1_p1',
            'seren_anth_kyoto_canal_boat_c1_p2',
            'seren_anth_kyoto_canal_boat_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_kyoto_canal_boat_c2_title',
          paragraphKeys: [
            'seren_anth_kyoto_canal_boat_c2_p1',
            'seren_anth_kyoto_canal_boat_c2_p2',
            'seren_anth_kyoto_canal_boat_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_kyoto_canal_boat_c3_title',
          paragraphKeys: [
            'seren_anth_kyoto_canal_boat_c3_p1',
            'seren_anth_kyoto_canal_boat_c3_p2',
            'seren_anth_kyoto_canal_boat_c3_p3',
          ],
        ),
      ],
      icon: Icons.kayaking_rounded,
    ),
    RelaxationReadingItem(
      id: 'travelogue_alpine_cogwheel',
      titleKey: 'seren_anth_alpine_cogwheel_title',
      subtitleKey: 'seren_anth_alpine_cogwheel_sub',
      category: RelaxationReadingCategory.slowTravelogues,
      recommendedFor: RelaxationTimeOfDayMode.anytime,
      estimatedMinutes: 15,
      pairedSoundId: 'gentleWind',
      pairedVisualId: 'driftingClouds',
      seasonTag: ReadingSeasonTag.summer,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_alpine_cogwheel_c1_title',
          paragraphKeys: [
            'seren_anth_alpine_cogwheel_c1_p1',
            'seren_anth_alpine_cogwheel_c1_p2',
            'seren_anth_alpine_cogwheel_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_alpine_cogwheel_c2_title',
          paragraphKeys: [
            'seren_anth_alpine_cogwheel_c2_p1',
            'seren_anth_alpine_cogwheel_c2_p2',
            'seren_anth_alpine_cogwheel_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_alpine_cogwheel_c3_title',
          paragraphKeys: [
            'seren_anth_alpine_cogwheel_c3_p1',
            'seren_anth_alpine_cogwheel_c3_p2',
            'seren_anth_alpine_cogwheel_c3_p3',
          ],
        ),
      ],
      icon: Icons.landscape_rounded,
    ),
    RelaxationReadingItem(
      id: 'travelogue_archipelago_schooner',
      titleKey: 'seren_anth_archipelago_schooner_title',
      subtitleKey: 'seren_anth_archipelago_schooner_sub',
      category: RelaxationReadingCategory.slowTravelogues,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 20,
      pairedSoundId: 'nightInsects',
      pairedVisualId: 'oceanSunset',
      seasonTag: ReadingSeasonTag.monsoon,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_archipelago_schooner_c1_title',
          paragraphKeys: [
            'seren_anth_archipelago_schooner_c1_p1',
            'seren_anth_archipelago_schooner_c1_p2',
            'seren_anth_archipelago_schooner_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_archipelago_schooner_c2_title',
          paragraphKeys: [
            'seren_anth_archipelago_schooner_c2_p1',
            'seren_anth_archipelago_schooner_c2_p2',
            'seren_anth_archipelago_schooner_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_archipelago_schooner_c3_title',
          paragraphKeys: [
            'seren_anth_archipelago_schooner_c3_p1',
            'seren_anth_archipelago_schooner_c3_p2',
            'seren_anth_archipelago_schooner_c3_p3',
          ],
        ),
      ],
      icon: Icons.sailing_rounded,
    ),
    RelaxationReadingItem(
      id: 'travelogue_canal_narrowboat',
      titleKey: 'seren_anth_canal_narrowboat_title',
      subtitleKey: 'seren_anth_canal_narrowboat_sub',
      category: RelaxationReadingCategory.slowTravelogues,
      recommendedFor: RelaxationTimeOfDayMode.morning,
      estimatedMinutes: 13,
      pairedSoundId: 'birdsSinging',
      pairedVisualId: 'forestBreeze',
      seasonTag: ReadingSeasonTag.spring,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_canal_narrowboat_c1_title',
          paragraphKeys: [
            'seren_anth_canal_narrowboat_c1_p1',
            'seren_anth_canal_narrowboat_c1_p2',
            'seren_anth_canal_narrowboat_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_canal_narrowboat_c2_title',
          paragraphKeys: [
            'seren_anth_canal_narrowboat_c2_p1',
            'seren_anth_canal_narrowboat_c2_p2',
            'seren_anth_canal_narrowboat_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_canal_narrowboat_c3_title',
          paragraphKeys: [
            'seren_anth_canal_narrowboat_c3_p1',
            'seren_anth_canal_narrowboat_c3_p2',
            'seren_anth_canal_narrowboat_c3_p3',
          ],
        ),
      ],
      icon: Icons.directions_ferry_rounded,
    ),
    // -------------------------------------------------------------------------
    // SEASONAL NATURE ESSAYS (6 ESSAYS)
    // -------------------------------------------------------------------------
    RelaxationReadingItem(
      id: 'essay_first_monsoon_earth',
      titleKey: 'seren_anth_first_monsoon_earth_title',
      subtitleKey: 'seren_anth_first_monsoon_earth_sub',
      category: RelaxationReadingCategory.seasonalEssays,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 12,
      pairedSoundId: 'rain',
      pairedVisualId: 'rainyWindow',
      seasonTag: ReadingSeasonTag.monsoon,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_first_monsoon_earth_c1_title',
          paragraphKeys: [
            'seren_anth_first_monsoon_earth_c1_p1',
            'seren_anth_first_monsoon_earth_c1_p2',
            'seren_anth_first_monsoon_earth_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_first_monsoon_earth_c2_title',
          paragraphKeys: [
            'seren_anth_first_monsoon_earth_c2_p1',
            'seren_anth_first_monsoon_earth_c2_p2',
            'seren_anth_first_monsoon_earth_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_first_monsoon_earth_c3_title',
          paragraphKeys: [
            'seren_anth_first_monsoon_earth_c3_p1',
            'seren_anth_first_monsoon_earth_c3_p2',
            'seren_anth_first_monsoon_earth_c3_p3',
          ],
        ),
      ],
      icon: Icons.water_drop_rounded,
    ),
    RelaxationReadingItem(
      id: 'essay_autumn_beechwood',
      titleKey: 'seren_anth_autumn_beechwood_title',
      subtitleKey: 'seren_anth_autumn_beechwood_sub',
      category: RelaxationReadingCategory.seasonalEssays,
      recommendedFor: RelaxationTimeOfDayMode.anytime,
      estimatedMinutes: 14,
      pairedSoundId: 'forest',
      pairedVisualId: 'forestBreeze',
      seasonTag: ReadingSeasonTag.autumn,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_autumn_beechwood_c1_title',
          paragraphKeys: [
            'seren_anth_autumn_beechwood_c1_p1',
            'seren_anth_autumn_beechwood_c1_p2',
            'seren_anth_autumn_beechwood_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_autumn_beechwood_c2_title',
          paragraphKeys: [
            'seren_anth_autumn_beechwood_c2_p1',
            'seren_anth_autumn_beechwood_c2_p2',
            'seren_anth_autumn_beechwood_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_autumn_beechwood_c3_title',
          paragraphKeys: [
            'seren_anth_autumn_beechwood_c3_p1',
            'seren_anth_autumn_beechwood_c3_p2',
            'seren_anth_autumn_beechwood_c3_p3',
          ],
        ),
      ],
      icon: Icons.park_rounded,
    ),
    RelaxationReadingItem(
      id: 'essay_winter_solstice_pond',
      titleKey: 'seren_anth_winter_solstice_pond_title',
      subtitleKey: 'seren_anth_winter_solstice_pond_sub',
      category: RelaxationReadingCategory.seasonalEssays,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 11,
      pairedSoundId: 'quietLibrary',
      pairedVisualId: 'moonlitLake',
      seasonTag: ReadingSeasonTag.winter,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_winter_solstice_pond_c1_title',
          paragraphKeys: [
            'seren_anth_winter_solstice_pond_c1_p1',
            'seren_anth_winter_solstice_pond_c1_p2',
            'seren_anth_winter_solstice_pond_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_winter_solstice_pond_c2_title',
          paragraphKeys: [
            'seren_anth_winter_solstice_pond_c2_p1',
            'seren_anth_winter_solstice_pond_c2_p2',
            'seren_anth_winter_solstice_pond_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_winter_solstice_pond_c3_title',
          paragraphKeys: [
            'seren_anth_winter_solstice_pond_c3_p1',
            'seren_anth_winter_solstice_pond_c3_p2',
            'seren_anth_winter_solstice_pond_c3_p3',
          ],
        ),
      ],
      icon: Icons.ac_unit_rounded,
    ),
    RelaxationReadingItem(
      id: 'essay_spring_thaw_orchestra',
      titleKey: 'seren_anth_spring_thaw_orchestra_title',
      subtitleKey: 'seren_anth_spring_thaw_orchestra_sub',
      category: RelaxationReadingCategory.seasonalEssays,
      recommendedFor: RelaxationTimeOfDayMode.morning,
      estimatedMinutes: 11,
      pairedSoundId: 'riverStream',
      pairedVisualId: 'morningSunrise',
      seasonTag: ReadingSeasonTag.spring,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_spring_thaw_orchestra_c1_title',
          paragraphKeys: [
            'seren_anth_spring_thaw_orchestra_c1_p1',
            'seren_anth_spring_thaw_orchestra_c1_p2',
            'seren_anth_spring_thaw_orchestra_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_spring_thaw_orchestra_c2_title',
          paragraphKeys: [
            'seren_anth_spring_thaw_orchestra_c2_p1',
            'seren_anth_spring_thaw_orchestra_c2_p2',
            'seren_anth_spring_thaw_orchestra_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_spring_thaw_orchestra_c3_title',
          paragraphKeys: [
            'seren_anth_spring_thaw_orchestra_c3_p1',
            'seren_anth_spring_thaw_orchestra_c3_p2',
            'seren_anth_spring_thaw_orchestra_c3_p3',
          ],
        ),
      ],
      icon: Icons.local_florist_rounded,
    ),
    RelaxationReadingItem(
      id: 'essay_high_summer_dusk',
      titleKey: 'seren_anth_high_summer_dusk_title',
      subtitleKey: 'seren_anth_high_summer_dusk_sub',
      category: RelaxationReadingCategory.seasonalEssays,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 13,
      pairedSoundId: 'nightInsects',
      pairedVisualId: 'forestFireflies',
      seasonTag: ReadingSeasonTag.summer,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_high_summer_dusk_c1_title',
          paragraphKeys: [
            'seren_anth_high_summer_dusk_c1_p1',
            'seren_anth_high_summer_dusk_c1_p2',
            'seren_anth_high_summer_dusk_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_high_summer_dusk_c2_title',
          paragraphKeys: [
            'seren_anth_high_summer_dusk_c2_p1',
            'seren_anth_high_summer_dusk_c2_p2',
            'seren_anth_high_summer_dusk_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_high_summer_dusk_c3_title',
          paragraphKeys: [
            'seren_anth_high_summer_dusk_c3_p1',
            'seren_anth_high_summer_dusk_c3_p2',
            'seren_anth_high_summer_dusk_c3_p3',
          ],
        ),
      ],
      icon: Icons.wb_twilight_rounded,
    ),
    RelaxationReadingItem(
      id: 'essay_cloud_forest_canopy',
      titleKey: 'seren_anth_cloud_forest_canopy_title',
      subtitleKey: 'seren_anth_cloud_forest_canopy_sub',
      category: RelaxationReadingCategory.seasonalEssays,
      recommendedFor: RelaxationTimeOfDayMode.morning,
      estimatedMinutes: 15,
      pairedSoundId: 'forest',
      pairedVisualId: 'sunlitCanopy',
      seasonTag: ReadingSeasonTag.monsoon,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_cloud_forest_canopy_c1_title',
          paragraphKeys: [
            'seren_anth_cloud_forest_canopy_c1_p1',
            'seren_anth_cloud_forest_canopy_c1_p2',
            'seren_anth_cloud_forest_canopy_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_cloud_forest_canopy_c2_title',
          paragraphKeys: [
            'seren_anth_cloud_forest_canopy_c2_p1',
            'seren_anth_cloud_forest_canopy_c2_p2',
            'seren_anth_cloud_forest_canopy_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_cloud_forest_canopy_c3_title',
          paragraphKeys: [
            'seren_anth_cloud_forest_canopy_c3_p1',
            'seren_anth_cloud_forest_canopy_c3_p2',
            'seren_anth_cloud_forest_canopy_c3_p3',
          ],
        ),
      ],
      icon: Icons.forest_rounded,
    ),
    // -------------------------------------------------------------------------
    // BOTANICAL & ASTRONOMY EVENING READINGS (4 READINGS)
    // -------------------------------------------------------------------------
    RelaxationReadingItem(
      id: 'astro_lunar_seas_atlas',
      titleKey: 'seren_anth_lunar_seas_atlas_title',
      subtitleKey: 'seren_anth_lunar_seas_atlas_sub',
      category: RelaxationReadingCategory.natureFacts,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 15,
      pairedSoundId: 'nightAmbience',
      pairedVisualId: 'starrySky',
      seasonTag: ReadingSeasonTag.nightSky,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_lunar_seas_atlas_c1_title',
          paragraphKeys: [
            'seren_anth_lunar_seas_atlas_c1_p1',
            'seren_anth_lunar_seas_atlas_c1_p2',
            'seren_anth_lunar_seas_atlas_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_lunar_seas_atlas_c2_title',
          paragraphKeys: [
            'seren_anth_lunar_seas_atlas_c2_p1',
            'seren_anth_lunar_seas_atlas_c2_p2',
            'seren_anth_lunar_seas_atlas_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_lunar_seas_atlas_c3_title',
          paragraphKeys: [
            'seren_anth_lunar_seas_atlas_c3_p1',
            'seren_anth_lunar_seas_atlas_c3_p2',
            'seren_anth_lunar_seas_atlas_c3_p3',
          ],
        ),
      ],
      icon: Icons.nightlight_round,
    ),
    RelaxationReadingItem(
      id: 'botany_night_blooming_gardens',
      titleKey: 'seren_anth_night_blooming_gardens_title',
      subtitleKey: 'seren_anth_night_blooming_gardens_sub',
      category: RelaxationReadingCategory.natureFacts,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 13,
      pairedSoundId: 'gentlePiano',
      pairedVisualId: 'forestFireflies',
      seasonTag: ReadingSeasonTag.botanical,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_night_blooming_gardens_c1_title',
          paragraphKeys: [
            'seren_anth_night_blooming_gardens_c1_p1',
            'seren_anth_night_blooming_gardens_c1_p2',
            'seren_anth_night_blooming_gardens_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_night_blooming_gardens_c2_title',
          paragraphKeys: [
            'seren_anth_night_blooming_gardens_c2_p1',
            'seren_anth_night_blooming_gardens_c2_p2',
            'seren_anth_night_blooming_gardens_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_night_blooming_gardens_c3_title',
          paragraphKeys: [
            'seren_anth_night_blooming_gardens_c3_p1',
            'seren_anth_night_blooming_gardens_c3_p2',
            'seren_anth_night_blooming_gardens_c3_p3',
          ],
        ),
      ],
      icon: Icons.eco_rounded,
    ),
    RelaxationReadingItem(
      id: 'astro_milky_way_desert',
      titleKey: 'seren_anth_milky_way_desert_title',
      subtitleKey: 'seren_anth_milky_way_desert_sub',
      category: RelaxationReadingCategory.natureFacts,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 17,
      pairedSoundId: 'brownNoise',
      pairedVisualId: 'starrySky',
      seasonTag: ReadingSeasonTag.nightSky,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_milky_way_desert_c1_title',
          paragraphKeys: [
            'seren_anth_milky_way_desert_c1_p1',
            'seren_anth_milky_way_desert_c1_p2',
            'seren_anth_milky_way_desert_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_milky_way_desert_c2_title',
          paragraphKeys: [
            'seren_anth_milky_way_desert_c2_p1',
            'seren_anth_milky_way_desert_c2_p2',
            'seren_anth_milky_way_desert_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_milky_way_desert_c3_title',
          paragraphKeys: [
            'seren_anth_milky_way_desert_c3_p1',
            'seren_anth_milky_way_desert_c3_p2',
            'seren_anth_milky_way_desert_c3_p3',
          ],
        ),
      ],
      icon: Icons.auto_awesome_rounded,
    ),
    RelaxationReadingItem(
      id: 'botany_winter_dormancy_trees',
      titleKey: 'seren_anth_winter_dormancy_trees_title',
      subtitleKey: 'seren_anth_winter_dormancy_trees_sub',
      category: RelaxationReadingCategory.natureFacts,
      recommendedFor: RelaxationTimeOfDayMode.evening,
      estimatedMinutes: 14,
      pairedSoundId: 'calmInstrumental',
      pairedVisualId: 'moonlitLake',
      seasonTag: ReadingSeasonTag.botanical,
      chapters: [
        ReadingChapter(
          id: 'ch1',
          titleKey: 'seren_anth_winter_dormancy_trees_c1_title',
          paragraphKeys: [
            'seren_anth_winter_dormancy_trees_c1_p1',
            'seren_anth_winter_dormancy_trees_c1_p2',
            'seren_anth_winter_dormancy_trees_c1_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch2',
          titleKey: 'seren_anth_winter_dormancy_trees_c2_title',
          paragraphKeys: [
            'seren_anth_winter_dormancy_trees_c2_p1',
            'seren_anth_winter_dormancy_trees_c2_p2',
            'seren_anth_winter_dormancy_trees_c2_p3',
          ],
        ),
        ReadingChapter(
          id: 'ch3',
          titleKey: 'seren_anth_winter_dormancy_trees_c3_title',
          paragraphKeys: [
            'seren_anth_winter_dormancy_trees_c3_p1',
            'seren_anth_winter_dormancy_trees_c3_p2',
            'seren_anth_winter_dormancy_trees_c3_p3',
          ],
        ),
      ],
      icon: Icons.nature_rounded,
    ),
  ];

  static RelaxationReadingItem readingById(String id) {
    return readings.firstWhere(
      (r) => r.id == id,
      orElse: () => readings.first,
    );
  }

  /// Optional Mindful Activity prompts integrated with Echo's Journal (Feature H).
  static const List<MindfulActivityPrompt> mindfulPrompts = [
    MindfulActivityPrompt(
      id: 'mindful_morning_intention',
      titleKey: 'seren_mindful_morning_intention_title',
      promptKey: 'seren_mindful_morning_intention_prompt',
      placeholderKey: 'seren_mindful_morning_intention_hint',
      recommendedFor: RelaxationTimeOfDayMode.morning,
      journalTag: 'Morning Intention',
      storesGratitudePebble: false,
      icon: Icons.wb_twilight_rounded,
    ),
    MindfulActivityPrompt(
      id: 'mindful_morning_positive',
      titleKey: 'seren_mindful_morning_thought_title',
      promptKey: 'seren_mindful_morning_thought_prompt',
      placeholderKey: 'seren_mindful_morning_thought_hint',
      recommendedFor: RelaxationTimeOfDayMode.morning,
      journalTag: 'Positive Thought',
      storesGratitudePebble: true,
      icon: Icons.light_mode_rounded,
    ),
    MindfulActivityPrompt(
      id: 'mindful_daily_gratitude',
      titleKey: 'seren_mindful_gratitude_title',
      promptKey: 'seren_mindful_gratitude_prompt',
      placeholderKey: 'seren_mindful_gratitude_hint',
      recommendedFor: RelaxationTimeOfDayMode.anytime,
      journalTag: 'Gratitude',
      storesGratitudePebble: true,
      icon: Icons.favorite_rounded,
    ),
    MindfulActivityPrompt(
      id: 'mindful_one_good_thing',
      titleKey: 'seren_mindful_one_good_title',
      promptKey: 'seren_mindful_one_good_prompt',
      placeholderKey: 'seren_mindful_one_good_hint',
      recommendedFor: RelaxationTimeOfDayMode.evening,
      journalTag: 'One Good Thing',
      storesGratitudePebble: true,
      icon: Icons.auto_awesome_rounded,
    ),
    MindfulActivityPrompt(
      id: 'mindful_five_min_reflection',
      titleKey: 'seren_mindful_five_min_title',
      promptKey: 'seren_mindful_five_min_prompt',
      placeholderKey: 'seren_mindful_five_min_hint',
      recommendedFor: RelaxationTimeOfDayMode.evening,
      journalTag: 'Evening Unwind',
      storesGratitudePebble: false,
      icon: Icons.nights_stay_rounded,
    ),
    MindfulActivityPrompt(
      id: 'mindful_gentle_imagination',
      titleKey: 'seren_mindful_imagination_title',
      promptKey: 'seren_mindful_imagination_prompt',
      placeholderKey: 'seren_mindful_imagination_hint',
      recommendedFor: RelaxationTimeOfDayMode.anytime,
      journalTag: 'Sanctuary Note',
      storesGratitudePebble: false,
      icon: Icons.landscape_rounded,
    ),
  ];
}
