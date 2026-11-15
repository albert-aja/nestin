import 'package:uuid/uuid.dart';

/// Platform capability levels communicated honestly in Roo Digital Discipline.
enum PlatformSupportLevel {
  supported,
  supportedWithPermission,
  supportedWithEntitlement,
  limitedSupport,
  unsupported,
}

extension PlatformSupportLevelExt on PlatformSupportLevel {
  String get label {
    switch (this) {
      case PlatformSupportLevel.supported:
        return 'Supported';
      case PlatformSupportLevel.supportedWithPermission:
        return 'Supported with Permission';
      case PlatformSupportLevel.supportedWithEntitlement:
        return 'Supported with Entitlement';
      case PlatformSupportLevel.limitedSupport:
        return 'Limited Support';
      case PlatformSupportLevel.unsupported:
        return 'Unsupported';
    }
  }
}

/// Enforcement behavior shared across App Fast, Focus Lock, and Usage Limits.
enum RestrictionEnforcementMode {
  reminder,
  strict,
}

extension RestrictionEnforcementModeExt on RestrictionEnforcementMode {
  String get label {
    switch (this) {
      case RestrictionEnforcementMode.reminder:
        return 'Reminder Mode';
      case RestrictionEnforcementMode.strict:
        return 'Strict Mode';
    }
  }

  String get description {
    switch (this) {
      case RestrictionEnforcementMode.reminder:
        return 'Detects launch and shows a mindful reminder where you can return to Nestin or continue.';
      case RestrictionEnforcementMode.strict:
        return 'Applies strongest supported platform shield until expiration or explicit config change.';
    }
  }
}

/// Monotonic restriction strength resolved by [RestrictionEngine].
/// Ordering is strictly ascending by severity:
/// none (0) < warning (1) < reminder (2) < strict (3).
enum RestrictionStrength {
  none,
  warning,
  reminder,
  strict,
}

extension RestrictionStrengthExt on RestrictionStrength {
  int get severityOrder {
    switch (this) {
      case RestrictionStrength.none:
        return 0;
      case RestrictionStrength.warning:
        return 1;
      case RestrictionStrength.reminder:
        return 2;
      case RestrictionStrength.strict:
        return 3;
    }
  }

  String get label {
    switch (this) {
      case RestrictionStrength.none:
        return 'None';
      case RestrictionStrength.warning:
        return 'Warning';
      case RestrictionStrength.reminder:
        return 'Reminder';
      case RestrictionStrength.strict:
        return 'Strict Guard';
    }
  }
}

/// Source domain contributing an active rule to the Shared Restriction Engine.
enum RestrictionSourceType {
  appFast,
  focusLock,
  usageLimit,
  scheduledBlock,
  automation,
  custom,
}

extension RestrictionSourceTypeExt on RestrictionSourceType {
  /// Priority used when two rules share identical [RestrictionStrength].
  int get sourcePriority {
    switch (this) {
      case RestrictionSourceType.appFast:
        return 60;
      case RestrictionSourceType.focusLock:
        return 50;
      case RestrictionSourceType.usageLimit:
        return 40;
      case RestrictionSourceType.scheduledBlock:
        return 30;
      case RestrictionSourceType.automation:
        return 20;
      case RestrictionSourceType.custom:
        return 10;
    }
  }

  String get label {
    switch (this) {
      case RestrictionSourceType.appFast:
        return 'App Fast';
      case RestrictionSourceType.focusLock:
        return 'Focus Lock';
      case RestrictionSourceType.usageLimit:
        return 'Usage Limit';
      case RestrictionSourceType.scheduledBlock:
        return 'Scheduled Block';
      case RestrictionSourceType.automation:
        return 'Automation';
      case RestrictionSourceType.custom:
        return 'Custom Rule';
    }
  }
}

/// Native/discovered installed application descriptor.
class InstalledAppInfo {
  final String packageName;
  final String appName;
  final String category;
  final bool isSystemApp;
  final String? iosBundleHint;

  const InstalledAppInfo({
    required this.packageName,
    required this.appName,
    this.category = 'other',
    this.isSystemApp = false,
    this.iosBundleHint,
  });

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'appName': appName,
        'category': category,
        'isSystemApp': isSystemApp,
        'iosBundleHint': iosBundleHint,
      };

  factory InstalledAppInfo.fromJson(Map<String, dynamic> json) {
    return InstalledAppInfo(
      packageName: json['packageName'] as String? ?? '',
      appName: json['appName'] as String? ?? 'App',
      category: json['category'] as String? ?? 'other',
      isSystemApp: json['isSystemApp'] as bool? ?? false,
      iosBundleHint: json['iosBundleHint'] as String?,
    );
  }
}

enum AppFastStatus {
  scheduled,
  active,
  completed,
  cancelled,
  failed,
}

/// Long-term intentional avoidance commitment (App Fast).
class AppFastCommitment {
  final String id;
  final String title;
  final List<String> targetPackages;
  final Map<String, String> targetAppNames;
  final Map<String, int> initialUsedMinutes;
  final DateTime startAt;
  final DateTime endAt;
  final RestrictionEnforcementMode mode;
  final String? motivation;
  final String? interventionMessage;
  final AppFastStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? cancelledAt;
  final DateTime? failedAt;
  final String? failureReason;

  AppFastCommitment({
    String? id,
    required this.title,
    required this.targetPackages,
    Map<String, String>? targetAppNames,
    Map<String, int>? initialUsedMinutes,
    required this.startAt,
    required this.endAt,
    this.mode = RestrictionEnforcementMode.reminder,
    this.motivation,
    this.interventionMessage,
    this.status = AppFastStatus.active,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.cancelledAt,
    this.failedAt,
    this.failureReason,
  })  : id = id ?? const Uuid().v4(),
        targetAppNames = Map.unmodifiable(targetAppNames ?? const {}),
        initialUsedMinutes = Map.unmodifiable(initialUsedMinutes ?? const {}),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Resolves true lifecycle state at [now] without mutating stored records.
  AppFastStatus resolvedStatusAt(DateTime now) {
    if (status == AppFastStatus.cancelled) return AppFastStatus.cancelled;
    if (status == AppFastStatus.failed) return AppFastStatus.failed;
    if (status == AppFastStatus.completed || !now.isBefore(endAt)) {
      return AppFastStatus.completed;
    }
    if (now.isBefore(startAt)) return AppFastStatus.scheduled;
    return AppFastStatus.active;
  }

  bool isActiveAt(DateTime now) => resolvedStatusAt(now) == AppFastStatus.active;

  Duration remainingDurationAt(DateTime now) {
    final rem = endAt.difference(now);
    return rem.isNegative ? Duration.zero : rem;
  }

  double progressRatioAt(DateTime now) {
    final total = endAt.difference(startAt).inSeconds;
    if (total <= 0) return 1.0;
    final elapsed = now.difference(startAt).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  String displayNameForPackage(String packageName) =>
      targetAppNames[packageName] ?? packageName;

  AppFastCommitment copyWith({
    String? title,
    List<String>? targetPackages,
    Map<String, String>? targetAppNames,
    Map<String, int>? initialUsedMinutes,
    DateTime? startAt,
    DateTime? endAt,
    RestrictionEnforcementMode? mode,
    String? motivation,
    bool clearMotivation = false,
    String? interventionMessage,
    bool clearInterventionMessage = false,
    AppFastStatus? status,
    DateTime? updatedAt,
    DateTime? cancelledAt,
    DateTime? failedAt,
    String? failureReason,
  }) {
    return AppFastCommitment(
      id: id,
      title: title ?? this.title,
      targetPackages: targetPackages ?? this.targetPackages,
      targetAppNames: targetAppNames ?? this.targetAppNames,
      initialUsedMinutes: initialUsedMinutes ?? this.initialUsedMinutes,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      mode: mode ?? this.mode,
      motivation: clearMotivation ? null : (motivation ?? this.motivation),
      interventionMessage: clearInterventionMessage
          ? null
          : (interventionMessage ?? this.interventionMessage),
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      cancelledAt: cancelledAt ?? this.cancelledAt,
      failedAt: failedAt ?? this.failedAt,
      failureReason: failureReason ?? this.failureReason,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'targetPackages': targetPackages,
        'targetAppNames': targetAppNames,
        'initialUsedMinutes': initialUsedMinutes,
        'startAt': startAt.toIso8601String(),
        'endAt': endAt.toIso8601String(),
        'mode': mode.name,
        'motivation': motivation,
        'interventionMessage': interventionMessage,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'cancelledAt': cancelledAt?.toIso8601String(),
        'failedAt': failedAt?.toIso8601String(),
        'failureReason': failureReason,
      };

  factory AppFastCommitment.fromJson(Map<String, dynamic> json) {
    final namesRaw = json['targetAppNames'];
    final names = <String, String>{};
    if (namesRaw is Map) {
      for (final entry in namesRaw.entries) {
        names[entry.key.toString()] = entry.value.toString();
      }
    }
    final initialMinutesRaw = json['initialUsedMinutes'];
    final initialMinutes = <String, int>{};
    if (initialMinutesRaw is Map) {
      for (final entry in initialMinutesRaw.entries) {
        final val = int.tryParse(entry.value.toString()) ?? 0;
        initialMinutes[entry.key.toString()] = val;
      }
    }
    return AppFastCommitment(
      id: json['id'] as String?,
      title: json['title'] as String? ?? 'App Fast',
      targetPackages: (json['targetPackages'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      targetAppNames: names,
      initialUsedMinutes: initialMinutes,
      startAt: DateTime.tryParse(json['startAt'] as String? ?? '') ??
          DateTime.now(),
      endAt: DateTime.tryParse(json['endAt'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 7)),
      mode: RestrictionEnforcementMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => RestrictionEnforcementMode.reminder,
      ),
      motivation: json['motivation'] as String?,
      interventionMessage: json['interventionMessage'] as String?,
      status: AppFastStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => AppFastStatus.active,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.tryParse(json['cancelledAt'] as String)
          : null,
      failedAt: json['failedAt'] != null
          ? DateTime.tryParse(json['failedAt'] as String)
          : null,
      failureReason: json['failureReason'] as String?,
    );
  }
}

/// User configuration owned by Scout for Pomodoro / Focus Lock.
class FocusLockConfig {
  final bool enabled;
  final List<String> restrictedPackages;
  final Map<String, String> restrictedAppNames;
  final List<String> allowedPackages;
  final bool restrictDuringBreaks;
  final bool allowManualEnd;
  final RestrictionEnforcementMode enforcementMode;
  final String? customMessage;

  const FocusLockConfig({
    this.enabled = true,
    this.restrictedPackages = const [
      'com.instagram.android',
      'com.zhiliaoapp.musically',
      'com.google.android.youtube',
    ],
    this.restrictedAppNames = const {
      'com.instagram.android': 'Instagram',
      'com.zhiliaoapp.musically': 'TikTok',
      'com.google.android.youtube': 'YouTube',
    },
    this.allowedPackages = const [],
    this.restrictDuringBreaks = false,
    this.allowManualEnd = true,
    this.enforcementMode = RestrictionEnforcementMode.reminder,
    this.customMessage,
  });

  FocusLockConfig copyWith({
    bool? enabled,
    List<String>? restrictedPackages,
    Map<String, String>? restrictedAppNames,
    List<String>? allowedPackages,
    bool? restrictDuringBreaks,
    bool? allowManualEnd,
    RestrictionEnforcementMode? enforcementMode,
    String? customMessage,
    bool clearCustomMessage = false,
  }) {
    return FocusLockConfig(
      enabled: enabled ?? this.enabled,
      restrictedPackages: restrictedPackages ?? this.restrictedPackages,
      restrictedAppNames: restrictedAppNames ?? this.restrictedAppNames,
      allowedPackages: allowedPackages ?? this.allowedPackages,
      restrictDuringBreaks: restrictDuringBreaks ?? this.restrictDuringBreaks,
      allowManualEnd: allowManualEnd ?? this.allowManualEnd,
      enforcementMode: enforcementMode ?? this.enforcementMode,
      customMessage:
          clearCustomMessage ? null : (customMessage ?? this.customMessage),
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'restrictedPackages': restrictedPackages,
        'restrictedAppNames': restrictedAppNames,
        'allowedPackages': allowedPackages,
        'restrictDuringBreaks': restrictDuringBreaks,
        'allowManualEnd': allowManualEnd,
        'enforcementMode': enforcementMode.name,
        'customMessage': customMessage,
      };

  factory FocusLockConfig.fromJson(Map<String, dynamic> json) {
    final namesRaw = json['restrictedAppNames'];
    final names = <String, String>{};
    if (namesRaw is Map) {
      for (final e in namesRaw.entries) {
        names[e.key.toString()] = e.value.toString();
      }
    }
    return FocusLockConfig(
      enabled: json['enabled'] as bool? ?? true,
      restrictedPackages: (json['restrictedPackages'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [
            'com.instagram.android',
            'com.zhiliaoapp.musically',
            'com.google.android.youtube',
          ],
      restrictedAppNames: names.isEmpty
          ? const {
              'com.instagram.android': 'Instagram',
              'com.zhiliaoapp.musically': 'TikTok',
              'com.google.android.youtube': 'YouTube',
            }
          : names,
      allowedPackages: (json['allowedPackages'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      restrictDuringBreaks: json['restrictDuringBreaks'] as bool? ?? false,
      allowManualEnd: json['allowManualEnd'] as bool? ?? true,
      enforcementMode: RestrictionEnforcementMode.values.firstWhere(
        (m) => m.name == json['enforcementMode'],
        orElse: () => RestrictionEnforcementMode.reminder,
      ),
      customMessage: json['customMessage'] as String?,
    );
  }
}

/// Active Focus Lock session state persisted for crash/reboot safety.
class FocusLockSession {
  final String id;
  final String source; // 'roo_pomodoro' | 'roo_manual' | 'automation'
  final String taskLabel;
  final String phase; // 'work' | 'shortBreak' | 'longBreak'
  final List<String> restrictedPackages;
  final List<String> allowedPackages;
  final bool restrictDuringBreaks;
  final bool allowManualEnd;
  final RestrictionEnforcementMode enforcementMode;
  final String? customMessage;
  final DateTime startedAt;
  final DateTime expectedEndAt;
  final bool isPaused;
  final DateTime? pausedAt;

  FocusLockSession({
    String? id,
    required this.source,
    required this.taskLabel,
    required this.phase,
    required this.restrictedPackages,
    this.allowedPackages = const [],
    this.restrictDuringBreaks = false,
    this.allowManualEnd = true,
    this.enforcementMode = RestrictionEnforcementMode.reminder,
    this.customMessage,
    required this.startedAt,
    required this.expectedEndAt,
    this.isPaused = false,
    this.pausedAt,
  }) : id = id ?? const Uuid().v4();

  bool isExpiredAt(DateTime now) => !isPaused && !now.isBefore(expectedEndAt);

  bool isRestrictingPhaseNow(DateTime now) {
    if (isExpiredAt(now)) return false;
    if (phase == 'work') return true;
    return restrictDuringBreaks;
  }

  FocusLockSession copyWith({
    String? phase,
    List<String>? restrictedPackages,
    List<String>? allowedPackages,
    bool? restrictDuringBreaks,
    bool? allowManualEnd,
    RestrictionEnforcementMode? enforcementMode,
    String? customMessage,
    DateTime? expectedEndAt,
    bool? isPaused,
    DateTime? pausedAt,
    bool clearPausedAt = false,
  }) {
    return FocusLockSession(
      id: id,
      source: source,
      taskLabel: taskLabel,
      phase: phase ?? this.phase,
      restrictedPackages: restrictedPackages ?? this.restrictedPackages,
      allowedPackages: allowedPackages ?? this.allowedPackages,
      restrictDuringBreaks: restrictDuringBreaks ?? this.restrictDuringBreaks,
      allowManualEnd: allowManualEnd ?? this.allowManualEnd,
      enforcementMode: enforcementMode ?? this.enforcementMode,
      customMessage: customMessage ?? this.customMessage,
      startedAt: startedAt,
      expectedEndAt: expectedEndAt ?? this.expectedEndAt,
      isPaused: isPaused ?? this.isPaused,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'taskLabel': taskLabel,
        'phase': phase,
        'restrictedPackages': restrictedPackages,
        'allowedPackages': allowedPackages,
        'restrictDuringBreaks': restrictDuringBreaks,
        'allowManualEnd': allowManualEnd,
        'enforcementMode': enforcementMode.name,
        'customMessage': customMessage,
        'startedAt': startedAt.toIso8601String(),
        'expectedEndAt': expectedEndAt.toIso8601String(),
        'isPaused': isPaused,
        'pausedAt': pausedAt?.toIso8601String(),
      };

  factory FocusLockSession.fromJson(Map<String, dynamic> json) {
    return FocusLockSession(
      id: json['id'] as String?,
      source: json['source'] as String? ?? 'roo_pomodoro',
      taskLabel: json['taskLabel'] as String? ?? 'Focus Sprint',
      phase: json['phase'] as String? ?? 'work',
      restrictedPackages: (json['restrictedPackages'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      allowedPackages: (json['allowedPackages'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      restrictDuringBreaks: json['restrictDuringBreaks'] as bool? ?? false,
      allowManualEnd: json['allowManualEnd'] as bool? ?? true,
      enforcementMode: RestrictionEnforcementMode.values.firstWhere(
        (m) => m.name == json['enforcementMode'],
        orElse: () => RestrictionEnforcementMode.reminder,
      ),
      customMessage: json['customMessage'] as String?,
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
      expectedEndAt: DateTime.tryParse(json['expectedEndAt'] as String? ?? '') ??
          DateTime.now().add(const Duration(minutes: 25)),
      isPaused: json['isPaused'] as bool? ?? false,
      pausedAt: json['pausedAt'] != null
          ? DateTime.tryParse(json['pausedAt'] as String)
          : null,
    );
  }
}

/// Modular rule unit consumed by [RestrictionEngine].
class RestrictionRule {
  final String id;
  final RestrictionSourceType sourceType;
  final String sourceId;
  final String title;
  final String packageName;
  final String appName;
  final RestrictionStrength strength;
  final String reason;
  final String? motivation;
  final DateTime? expiresAt;
  final bool isEnabled;

  const RestrictionRule({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.title,
    required this.packageName,
    required this.appName,
    required this.strength,
    required this.reason,
    this.motivation,
    this.expiresAt,
    this.isEnabled = true,
  });

  bool isActiveAt(DateTime now) {
    if (!isEnabled) return false;
    if (expiresAt != null && !now.isBefore(expiresAt!)) return false;
    return strength != RestrictionStrength.none;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceType': sourceType.name,
        'sourceId': sourceId,
        'title': title,
        'packageName': packageName,
        'appName': appName,
        'strength': strength.name,
        'reason': reason,
        'motivation': motivation,
        'expiresAt': expiresAt?.toIso8601String(),
        'isEnabled': isEnabled,
      };

  factory RestrictionRule.fromJson(Map<String, dynamic> json) {
    return RestrictionRule(
      id: json['id'] as String? ?? const Uuid().v4(),
      sourceType: RestrictionSourceType.values.firstWhere(
        (e) => e.name == json['sourceType'],
        orElse: () => RestrictionSourceType.custom,
      ),
      sourceId: json['sourceId'] as String? ?? '',
      title: json['title'] as String? ?? 'Restriction',
      packageName: json['packageName'] as String? ?? '',
      appName: json['appName'] as String? ?? 'App',
      strength: RestrictionStrength.values.firstWhere(
        (e) => e.name == json['strength'],
        orElse: () => RestrictionStrength.reminder,
      ),
      reason: json['reason'] as String? ?? '',
      motivation: json['motivation'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }
}

enum RestrictionExecutionOutcome {
  none,
  allowedEssential,
  warningNotificationOnly,
  reminderOverlayShown,
  enforcedViaShield,
  delegatedToSystemSettings,
  unsupported,
  userContinuedInReminder,
}

/// Complete conflict-resolved evaluation decision for one package at a moment in time.
class RestrictionDecision {
  final String packageName;
  final String appName;
  final RestrictionStrength effectiveStrength;
  final RestrictionRule? winningRule;
  final List<RestrictionRule> activeRules;
  final RestrictionExecutionOutcome outcome;
  final PlatformSupportLevel platformSupport;
  final bool canProceedAnyway;
  final String explanation;
  final DateTime evaluatedAt;

  const RestrictionDecision({
    required this.packageName,
    required this.appName,
    required this.effectiveStrength,
    required this.winningRule,
    required this.activeRules,
    required this.outcome,
    required this.platformSupport,
    required this.canProceedAnyway,
    required this.explanation,
    required this.evaluatedAt,
  });

  bool get isRestricted =>
      effectiveStrength == RestrictionStrength.reminder ||
      effectiveStrength == RestrictionStrength.strict;
}

class RestrictionAuditLog {
  final String id;
  final String packageName;
  final String appName;
  final RestrictionStrength effectiveStrength;
  final RestrictionSourceType? winningSource;
  final List<RestrictionSourceType> coexistingSources;
  final RestrictionExecutionOutcome outcome;
  final PlatformSupportLevel platformSupport;
  final String detail;
  final DateTime timestamp;

  RestrictionAuditLog({
    String? id,
    required this.packageName,
    required this.appName,
    required this.effectiveStrength,
    required this.winningSource,
    required this.coexistingSources,
    required this.outcome,
    required this.platformSupport,
    required this.detail,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'packageName': packageName,
        'appName': appName,
        'effectiveStrength': effectiveStrength.name,
        'winningSource': winningSource?.name,
        'coexistingSources': coexistingSources.map((e) => e.name).toList(),
        'outcome': outcome.name,
        'platformSupport': platformSupport.name,
        'detail': detail,
        'timestamp': timestamp.toIso8601String(),
      };

  factory RestrictionAuditLog.fromJson(Map<String, dynamic> json) {
    return RestrictionAuditLog(
      id: json['id'] as String?,
      packageName: json['packageName'] as String? ?? '',
      appName: json['appName'] as String? ?? 'App',
      effectiveStrength: RestrictionStrength.values.firstWhere(
        (e) => e.name == json['effectiveStrength'],
        orElse: () => RestrictionStrength.none,
      ),
      winningSource: json['winningSource'] != null
          ? RestrictionSourceType.values.firstWhere(
              (e) => e.name == json['winningSource'],
              orElse: () => RestrictionSourceType.custom,
            )
          : null,
      coexistingSources: (json['coexistingSources'] as List?)
              ?.map(
                (s) => RestrictionSourceType.values.firstWhere(
                  (e) => e.name == s,
                  orElse: () => RestrictionSourceType.custom,
                ),
              )
              .toList() ??
          const [],
      outcome: RestrictionExecutionOutcome.values.firstWhere(
        (e) => e.name == json['outcome'],
        orElse: () => RestrictionExecutionOutcome.none,
      ),
      platformSupport: PlatformSupportLevel.values.firstWhere(
        (e) => e.name == json['platformSupport'],
        orElse: () => PlatformSupportLevel.limitedSupport,
      ),
      detail: json['detail'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? ''),
    );
  }
}
