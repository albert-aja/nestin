import 'package:uuid/uuid.dart';
import 'device_capability.dart';

enum PhoneModePreset {
  sleep,
  work,
  study,
  relax,
  custom,
}

enum PhoneModeActionType {
  setDnd,
  setScreenBrightness,
  setScreenTimeoutSeconds,
  applyAppRestrictions,
  openSystemModesFallback,
}

class PhoneModeActionOutcome {
  final PhoneModeActionType actionType;
  final String targetValue;
  final ActionExecutionSupport support;
  final bool succeeded;
  final String message;
  final int? previousRawValue;
  final int? appliedRawValue;
  final DateTime executedAt;

  PhoneModeActionOutcome({
    required this.actionType,
    required this.targetValue,
    required this.support,
    required this.succeeded,
    required this.message,
    this.previousRawValue,
    this.appliedRawValue,
    DateTime? executedAt,
  }) : executedAt = executedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'actionType': actionType.name,
        'targetValue': targetValue,
        'support': support.name,
        'succeeded': succeeded,
        'message': message,
        'previousRawValue': previousRawValue,
        'appliedRawValue': appliedRawValue,
        'executedAt': executedAt.toIso8601String(),
      };
}

class PhoneModeProfile {
  final String id;
  final String name;
  final PhoneModePreset preset;
  final String iconKey;
  final int colorValue;
  final String description;
  final bool enableDnd;
  final int? targetBrightnessPercent; // 1..100 when managed
  final int? targetScreenTimeoutSeconds; // e.g. 15, 30, 60, 120, 600
  final List<String> restrictedAppRuleIds;
  final bool enforceStrictAppShield;
  final String? scheduledStart; // 'HH:mm'
  final String? scheduledEnd; // 'HH:mm'
  final List<int> activeDays; // 1=Mon .. 7=Sun
  final int? durationMinutes;
  final bool autoRestoreOnEnd;

  PhoneModeProfile({
    String? id,
    required this.name,
    required this.preset,
    this.iconKey = 'tune',
    this.colorValue = 0xFF64B5F6,
    this.description = '',
    this.enableDnd = false,
    this.targetBrightnessPercent,
    this.targetScreenTimeoutSeconds,
    this.restrictedAppRuleIds = const [],
    this.enforceStrictAppShield = false,
    this.scheduledStart,
    this.scheduledEnd,
    this.activeDays = const [1, 2, 3, 4, 5, 6, 7],
    this.durationMinutes,
    this.autoRestoreOnEnd = true,
  }) : id = id ?? const Uuid().v4();

  PhoneModeProfile copyWith({
    String? name,
    PhoneModePreset? preset,
    String? iconKey,
    int? colorValue,
    String? description,
    bool? enableDnd,
    int? targetBrightnessPercent,
    bool clearBrightness = false,
    int? targetScreenTimeoutSeconds,
    bool clearTimeout = false,
    List<String>? restrictedAppRuleIds,
    bool? enforceStrictAppShield,
    String? scheduledStart,
    String? scheduledEnd,
    List<int>? activeDays,
    int? durationMinutes,
    bool? autoRestoreOnEnd,
  }) {
    return PhoneModeProfile(
      id: id,
      name: name ?? this.name,
      preset: preset ?? this.preset,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      description: description ?? this.description,
      enableDnd: enableDnd ?? this.enableDnd,
      targetBrightnessPercent: clearBrightness
          ? null
          : (targetBrightnessPercent ?? this.targetBrightnessPercent),
      targetScreenTimeoutSeconds: clearTimeout
          ? null
          : (targetScreenTimeoutSeconds ?? this.targetScreenTimeoutSeconds),
      restrictedAppRuleIds:
          restrictedAppRuleIds ?? List<String>.from(this.restrictedAppRuleIds),
      enforceStrictAppShield:
          enforceStrictAppShield ?? this.enforceStrictAppShield,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      activeDays: activeDays ?? List<int>.from(this.activeDays),
      durationMinutes: durationMinutes ?? this.durationMinutes,
      autoRestoreOnEnd: autoRestoreOnEnd ?? this.autoRestoreOnEnd,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'preset': preset.name,
        'iconKey': iconKey,
        'colorValue': colorValue,
        'description': description,
        'enableDnd': enableDnd,
        'targetBrightnessPercent': targetBrightnessPercent,
        'targetScreenTimeoutSeconds': targetScreenTimeoutSeconds,
        'restrictedAppRuleIds': restrictedAppRuleIds,
        'enforceStrictAppShield': enforceStrictAppShield,
        'scheduledStart': scheduledStart,
        'scheduledEnd': scheduledEnd,
        'activeDays': activeDays,
        'durationMinutes': durationMinutes,
        'autoRestoreOnEnd': autoRestoreOnEnd,
      };

  factory PhoneModeProfile.fromJson(Map<String, dynamic> json) {
    return PhoneModeProfile(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Custom Mode',
      preset: PhoneModePreset.values.firstWhere(
        (e) => e.name == json['preset'],
        orElse: () => PhoneModePreset.custom,
      ),
      iconKey: json['iconKey'] as String? ?? 'tune',
      colorValue: json['colorValue'] as int? ?? 0xFF64B5F6,
      description: json['description'] as String? ?? '',
      enableDnd: json['enableDnd'] as bool? ?? false,
      targetBrightnessPercent: json['targetBrightnessPercent'] as int?,
      targetScreenTimeoutSeconds: json['targetScreenTimeoutSeconds'] as int?,
      restrictedAppRuleIds:
          (json['restrictedAppRuleIds'] as List<dynamic>?)?.cast<String>() ??
              const [],
      enforceStrictAppShield: json['enforceStrictAppShield'] as bool? ?? false,
      scheduledStart: json['scheduledStart'] as String?,
      scheduledEnd: json['scheduledEnd'] as String?,
      activeDays: (json['activeDays'] as List<dynamic>?)?.cast<int>() ??
          const [1, 2, 3, 4, 5, 6, 7],
      durationMinutes: json['durationMinutes'] as int?,
      autoRestoreOnEnd: json['autoRestoreOnEnd'] as bool? ?? true,
    );
  }

  static List<PhoneModeProfile> defaultProfiles() => [
        PhoneModeProfile(
          id: 'mode_sleep',
          name: 'Sleep Mode',
          preset: PhoneModePreset.sleep,
          iconKey: 'bedtime',
          colorValue: 0xFF9C8CE8,
          description:
              'Enables Do Not Disturb, dims brightness to 15%, and shields distracting apps at bedtime.',
          enableDnd: true,
          targetBrightnessPercent: 15,
          targetScreenTimeoutSeconds: 15,
          restrictedAppRuleIds: const ['preset_instagram', 'preset_tiktok'],
          scheduledStart: '22:30',
          scheduledEnd: '07:00',
          durationMinutes: 480,
          autoRestoreOnEnd: true,
        ),
        PhoneModeProfile(
          id: 'mode_work',
          name: 'Work Focus',
          preset: PhoneModePreset.work,
          iconKey: 'work',
          colorValue: 0xFF64B5F6,
          description:
              'Silences distractions with DND and strengthens limits on social feeds during deep work.',
          enableDnd: true,
          targetBrightnessPercent: 60,
          targetScreenTimeoutSeconds: 60,
          restrictedAppRuleIds: const [
            'preset_instagram',
            'preset_tiktok',
            'preset_youtube',
          ],
          durationMinutes: 90,
          autoRestoreOnEnd: true,
        ),
        PhoneModeProfile(
          id: 'mode_study',
          name: 'Study Session',
          preset: PhoneModePreset.study,
          iconKey: 'menu_book',
          colorValue: 0xFF4ECDC4,
          description:
              'Keeps screen responsive for reading while muting non-essential alerts and limiting video apps.',
          enableDnd: true,
          targetBrightnessPercent: 70,
          targetScreenTimeoutSeconds: 120,
          restrictedAppRuleIds: const ['preset_tiktok', 'preset_youtube'],
          durationMinutes: 60,
          autoRestoreOnEnd: true,
        ),
        PhoneModeProfile(
          id: 'mode_relax',
          name: 'Evening Relax',
          preset: PhoneModePreset.relax,
          iconKey: 'self_improvement',
          colorValue: 0xFF81C784,
          description:
              'Softens brightness to 35% for calmer evening winding down without strict blocking.',
          enableDnd: false,
          targetBrightnessPercent: 35,
          targetScreenTimeoutSeconds: 30,
          durationMinutes: 60,
          autoRestoreOnEnd: true,
        ),
      ];
}

/// Captures pre-mode system settings so ending or recovering from a mode
/// safely restores ONLY settings that Nestin modified AND the user did not
/// manually override mid-session.
class StateRestorationSnapshot {
  final String snapshotId;
  final String modeId;
  final String modeName;
  final DateTime capturedAt;
  final DateTime? expiresAt;
  final int? previousDndFilter;
  final int? appliedDndFilter;
  final bool dndModifiedByNestin;
  final int? previousBrightnessRaw; // 0..255 (Android) or 0..100 (normalized)
  final int? appliedBrightnessRaw;
  final bool brightnessModifiedByNestin;
  final int? previousScreenTimeoutMs;
  final int? appliedScreenTimeoutMs;
  final bool timeoutModifiedByNestin;
  final bool wasRestored;
  final DateTime? restoredAt;
  final List<String> restorationNotes;

  StateRestorationSnapshot({
    String? snapshotId,
    required this.modeId,
    required this.modeName,
    DateTime? capturedAt,
    this.expiresAt,
    this.previousDndFilter,
    this.appliedDndFilter,
    this.dndModifiedByNestin = false,
    this.previousBrightnessRaw,
    this.appliedBrightnessRaw,
    this.brightnessModifiedByNestin = false,
    this.previousScreenTimeoutMs,
    this.appliedScreenTimeoutMs,
    this.timeoutModifiedByNestin = false,
    this.wasRestored = false,
    this.restoredAt,
    this.restorationNotes = const [],
  })  : snapshotId = snapshotId ?? const Uuid().v4(),
        capturedAt = capturedAt ?? DateTime.now();

  bool get hasAnyModifiedSetting =>
      dndModifiedByNestin ||
      brightnessModifiedByNestin ||
      timeoutModifiedByNestin;

  StateRestorationSnapshot copyWith({
    bool? dndModifiedByNestin,
    int? appliedDndFilter,
    bool? brightnessModifiedByNestin,
    int? appliedBrightnessRaw,
    bool? timeoutModifiedByNestin,
    int? appliedScreenTimeoutMs,
    bool? wasRestored,
    DateTime? restoredAt,
    List<String>? restorationNotes,
  }) {
    return StateRestorationSnapshot(
      snapshotId: snapshotId,
      modeId: modeId,
      modeName: modeName,
      capturedAt: capturedAt,
      expiresAt: expiresAt,
      previousDndFilter: previousDndFilter,
      appliedDndFilter: appliedDndFilter ?? this.appliedDndFilter,
      dndModifiedByNestin: dndModifiedByNestin ?? this.dndModifiedByNestin,
      previousBrightnessRaw: previousBrightnessRaw,
      appliedBrightnessRaw: appliedBrightnessRaw ?? this.appliedBrightnessRaw,
      brightnessModifiedByNestin:
          brightnessModifiedByNestin ?? this.brightnessModifiedByNestin,
      previousScreenTimeoutMs: previousScreenTimeoutMs,
      appliedScreenTimeoutMs:
          appliedScreenTimeoutMs ?? this.appliedScreenTimeoutMs,
      timeoutModifiedByNestin:
          timeoutModifiedByNestin ?? this.timeoutModifiedByNestin,
      wasRestored: wasRestored ?? this.wasRestored,
      restoredAt: restoredAt ?? this.restoredAt,
      restorationNotes: restorationNotes ?? this.restorationNotes,
    );
  }

  Map<String, dynamic> toJson() => {
        'snapshotId': snapshotId,
        'modeId': modeId,
        'modeName': modeName,
        'capturedAt': capturedAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'previousDndFilter': previousDndFilter,
        'appliedDndFilter': appliedDndFilter,
        'dndModifiedByNestin': dndModifiedByNestin,
        'previousBrightnessRaw': previousBrightnessRaw,
        'appliedBrightnessRaw': appliedBrightnessRaw,
        'brightnessModifiedByNestin': brightnessModifiedByNestin,
        'previousScreenTimeoutMs': previousScreenTimeoutMs,
        'appliedScreenTimeoutMs': appliedScreenTimeoutMs,
        'timeoutModifiedByNestin': timeoutModifiedByNestin,
        'wasRestored': wasRestored,
        'restoredAt': restoredAt?.toIso8601String(),
        'restorationNotes': restorationNotes,
      };

  factory StateRestorationSnapshot.fromJson(Map<String, dynamic> json) {
    return StateRestorationSnapshot(
      snapshotId: json['snapshotId'] as String?,
      modeId: json['modeId'] as String? ?? '',
      modeName: json['modeName'] as String? ?? '',
      capturedAt: json['capturedAt'] != null
          ? (DateTime.tryParse(json['capturedAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      previousDndFilter: json['previousDndFilter'] as int?,
      appliedDndFilter: json['appliedDndFilter'] as int?,
      dndModifiedByNestin: json['dndModifiedByNestin'] as bool? ?? false,
      previousBrightnessRaw: json['previousBrightnessRaw'] as int?,
      appliedBrightnessRaw: json['appliedBrightnessRaw'] as int?,
      brightnessModifiedByNestin:
          json['brightnessModifiedByNestin'] as bool? ?? false,
      previousScreenTimeoutMs: json['previousScreenTimeoutMs'] as int?,
      appliedScreenTimeoutMs: json['appliedScreenTimeoutMs'] as int?,
      timeoutModifiedByNestin:
          json['timeoutModifiedByNestin'] as bool? ?? false,
      wasRestored: json['wasRestored'] as bool? ?? false,
      restoredAt: json['restoredAt'] != null
          ? DateTime.tryParse(json['restoredAt'] as String)
          : null,
      restorationNotes:
          (json['restorationNotes'] as List<dynamic>?)?.cast<String>() ??
              const [],
    );
  }
}
