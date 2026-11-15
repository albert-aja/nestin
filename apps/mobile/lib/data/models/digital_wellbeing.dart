import 'package:uuid/uuid.dart';

/// Graduated intervention ladder for Roo Digital Discipline & App Control.
/// Nestin never claims unbreakable OS-level locks when permissions are absent.
enum WellbeingInterventionLevel {
  trackOnly,
  preLimitWarning,
  timedSoftPause,
  blockingSchedule,
  strictModeGuard,
}

extension WellbeingInterventionLevelExt on WellbeingInterventionLevel {
  String get label {
    switch (this) {
      case WellbeingInterventionLevel.trackOnly:
        return 'Track Only';
      case WellbeingInterventionLevel.preLimitWarning:
        return 'Pre-Limit Warning';
      case WellbeingInterventionLevel.timedSoftPause:
        return 'Timed Soft Pause';
      case WellbeingInterventionLevel.blockingSchedule:
        return 'Blocking Schedule';
      case WellbeingInterventionLevel.strictModeGuard:
        return 'Strict Guard';
    }
  }

  String get description {
    switch (this) {
      case WellbeingInterventionLevel.trackOnly:
        return 'Silently tracks daily time and launch count without interrupting.';
      case WellbeingInterventionLevel.preLimitWarning:
        return 'Sends a proactive warning when usage reaches your threshold (e.g. 80%).';
      case WellbeingInterventionLevel.timedSoftPause:
        return 'Triggers a mindful pause prompt and 10-second reflection delay.';
      case WellbeingInterventionLevel.blockingSchedule:
        return 'Applies schedule-based Focus/Bedtime guards with notification or shield.';
      case WellbeingInterventionLevel.strictModeGuard:
        return 'Uses strongest supported platform guard (Overlay/Accessibility or Focus delegation).';
    }
  }
}

/// Action applied once a daily usage allowance is reached.
enum UsageLimitAction {
  warningOnly,
  reminderPause,
  strictBlock,
}

extension UsageLimitActionExt on UsageLimitAction {
  String get label {
    switch (this) {
      case UsageLimitAction.warningOnly:
        return 'Warning Only';
      case UsageLimitAction.reminderPause:
        return 'Reminder Overlay';
      case UsageLimitAction.strictBlock:
        return 'Strict Restriction';
    }
  }
}

class TrackedAppRule {
  final String id;
  final String displayName;
  final String packageName;
  final String? iosBundleHint;
  final String category;
  final int dailyLimitMinutes;
  final int? weekdayLimitMinutes;
  final int? weekendLimitMinutes;
  final int warningThresholdPercent;
  final WellbeingInterventionLevel interventionLevel;
  final UsageLimitAction? limitReachedAction;
  final int dailyResetHour;
  final int dailyResetMinute;
  final String? blockedScheduleStart; // 'HH:mm'
  final String? blockedScheduleEnd; // 'HH:mm'
  final bool isEnabled;
  final bool isPreset;

  TrackedAppRule({
    String? id,
    required this.displayName,
    required this.packageName,
    this.iosBundleHint,
    this.category = 'social',
    this.dailyLimitMinutes = 45,
    this.weekdayLimitMinutes,
    this.weekendLimitMinutes,
    this.warningThresholdPercent = 80,
    this.interventionLevel = WellbeingInterventionLevel.preLimitWarning,
    this.limitReachedAction,
    this.dailyResetHour = 0,
    this.dailyResetMinute = 0,
    this.blockedScheduleStart,
    this.blockedScheduleEnd,
    this.isEnabled = true,
    this.isPreset = false,
  }) : id = id ?? const Uuid().v4();

  /// Effective limit in minutes for [now], respecting optional weekday/weekend
  /// overrides before falling back to [dailyLimitMinutes].
  int effectiveLimitMinutesFor(DateTime now) {
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    if (isWeekend && weekendLimitMinutes != null) {
      return weekendLimitMinutes!;
    }
    if (!isWeekend && weekdayLimitMinutes != null) {
      return weekdayLimitMinutes!;
    }
    return dailyLimitMinutes;
  }

  /// Resolves the active limit-reached action from [limitReachedAction] or
  /// the graduated [interventionLevel].
  UsageLimitAction get resolvedLimitAction {
    if (limitReachedAction != null) return limitReachedAction!;
    switch (interventionLevel) {
      case WellbeingInterventionLevel.trackOnly:
      case WellbeingInterventionLevel.preLimitWarning:
        return UsageLimitAction.warningOnly;
      case WellbeingInterventionLevel.timedSoftPause:
        return UsageLimitAction.reminderPause;
      case WellbeingInterventionLevel.blockingSchedule:
      case WellbeingInterventionLevel.strictModeGuard:
        return UsageLimitAction.strictBlock;
    }
  }

  /// Computes a timezone/date-safe logical day key based on [dailyResetHour]
  /// and [dailyResetMinute].
  String currentResetWindowKey(DateTime now) {
    final boundary = DateTime(
      now.year,
      now.month,
      now.day,
      dailyResetHour.clamp(0, 23),
      dailyResetMinute.clamp(0, 59),
    );
    final effectiveDay = now.isBefore(boundary)
        ? now.subtract(const Duration(days: 1))
        : now;
    final y = effectiveDay.year.toString().padLeft(4, '0');
    final m = effectiveDay.month.toString().padLeft(2, '0');
    final d = effectiveDay.day.toString().padLeft(2, '0');
    return '$y-$m-$d@${dailyResetHour.toString().padLeft(2, '0')}:${dailyResetMinute.toString().padLeft(2, '0')}';
  }

  int warningMinutesFor(DateTime now) =>
      ((effectiveLimitMinutesFor(now) * warningThresholdPercent) / 100).round();

  int get warningMinutes =>
      ((dailyLimitMinutes * warningThresholdPercent) / 100).round();

  bool isWithinBlockedWindow(DateTime now) {
    if (blockedScheduleStart == null || blockedScheduleEnd == null) {
      return false;
    }
    final startParts = blockedScheduleStart!.split(':');
    final endParts = blockedScheduleEnd!.split(':');
    if (startParts.length != 2 || endParts.length != 2) return false;
    final startMin =
        (int.tryParse(startParts[0]) ?? 0) * 60 + (int.tryParse(startParts[1]) ?? 0);
    final endMin =
        (int.tryParse(endParts[0]) ?? 0) * 60 + (int.tryParse(endParts[1]) ?? 0);
    final nowMin = now.hour * 60 + now.minute;
    if (startMin <= endMin) {
      return nowMin >= startMin && nowMin < endMin;
    }
    // Overnight schedule (e.g. 22:00 to 07:00)
    return nowMin >= startMin || nowMin < endMin;
  }

  TrackedAppRule copyWith({
    String? displayName,
    String? packageName,
    String? iosBundleHint,
    String? category,
    int? dailyLimitMinutes,
    int? weekdayLimitMinutes,
    bool clearWeekdayLimit = false,
    int? weekendLimitMinutes,
    bool clearWeekendLimit = false,
    int? warningThresholdPercent,
    WellbeingInterventionLevel? interventionLevel,
    UsageLimitAction? limitReachedAction,
    int? dailyResetHour,
    int? dailyResetMinute,
    String? blockedScheduleStart,
    bool clearScheduleStart = false,
    String? blockedScheduleEnd,
    bool clearScheduleEnd = false,
    bool? isEnabled,
    bool? isPreset,
  }) {
    return TrackedAppRule(
      id: id,
      displayName: displayName ?? this.displayName,
      packageName: packageName ?? this.packageName,
      iosBundleHint: iosBundleHint ?? this.iosBundleHint,
      category: category ?? this.category,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      weekdayLimitMinutes: clearWeekdayLimit
          ? null
          : (weekdayLimitMinutes ?? this.weekdayLimitMinutes),
      weekendLimitMinutes: clearWeekendLimit
          ? null
          : (weekendLimitMinutes ?? this.weekendLimitMinutes),
      warningThresholdPercent:
          warningThresholdPercent ?? this.warningThresholdPercent,
      interventionLevel: interventionLevel ?? this.interventionLevel,
      limitReachedAction: limitReachedAction ?? this.limitReachedAction,
      dailyResetHour: dailyResetHour ?? this.dailyResetHour,
      dailyResetMinute: dailyResetMinute ?? this.dailyResetMinute,
      blockedScheduleStart: clearScheduleStart
          ? null
          : (blockedScheduleStart ?? this.blockedScheduleStart),
      blockedScheduleEnd:
          clearScheduleEnd ? null : (blockedScheduleEnd ?? this.blockedScheduleEnd),
      isEnabled: isEnabled ?? this.isEnabled,
      isPreset: isPreset ?? this.isPreset,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'packageName': packageName,
        'iosBundleHint': iosBundleHint,
        'category': category,
        'dailyLimitMinutes': dailyLimitMinutes,
        'weekdayLimitMinutes': weekdayLimitMinutes,
        'weekendLimitMinutes': weekendLimitMinutes,
        'warningThresholdPercent': warningThresholdPercent,
        'interventionLevel': interventionLevel.name,
        'limitReachedAction': limitReachedAction?.name,
        'dailyResetHour': dailyResetHour,
        'dailyResetMinute': dailyResetMinute,
        'blockedScheduleStart': blockedScheduleStart,
        'blockedScheduleEnd': blockedScheduleEnd,
        'isEnabled': isEnabled,
        'isPreset': isPreset,
      };

  factory TrackedAppRule.fromJson(Map<String, dynamic> json) {
    return TrackedAppRule(
      id: json['id'] as String?,
      displayName: json['displayName'] as String? ?? 'App',
      packageName: json['packageName'] as String? ?? '',
      iosBundleHint: json['iosBundleHint'] as String?,
      category: json['category'] as String? ?? 'social',
      dailyLimitMinutes: json['dailyLimitMinutes'] as int? ?? 45,
      weekdayLimitMinutes: json['weekdayLimitMinutes'] as int?,
      weekendLimitMinutes: json['weekendLimitMinutes'] as int?,
      warningThresholdPercent: json['warningThresholdPercent'] as int? ?? 80,
      interventionLevel: WellbeingInterventionLevel.values.firstWhere(
        (e) => e.name == json['interventionLevel'],
        orElse: () => WellbeingInterventionLevel.preLimitWarning,
      ),
      limitReachedAction: json['limitReachedAction'] != null
          ? UsageLimitAction.values.firstWhere(
              (a) => a.name == json['limitReachedAction'],
              orElse: () => UsageLimitAction.warningOnly,
            )
          : null,
      dailyResetHour: json['dailyResetHour'] as int? ?? 0,
      dailyResetMinute: json['dailyResetMinute'] as int? ?? 0,
      blockedScheduleStart: json['blockedScheduleStart'] as String?,
      blockedScheduleEnd: json['blockedScheduleEnd'] as String?,
      isEnabled: json['isEnabled'] as bool? ?? true,
      isPreset: json['isPreset'] as bool? ?? false,
    );
  }

  static List<TrackedAppRule> defaultPresets() => [
        TrackedAppRule(
          id: 'preset_instagram',
          displayName: 'Instagram',
          packageName: 'com.instagram.android',
          iosBundleHint: 'com.burbn.instagram',
          category: 'social',
          dailyLimitMinutes: 45,
          warningThresholdPercent: 80,
          interventionLevel: WellbeingInterventionLevel.preLimitWarning,
          blockedScheduleStart: '22:30',
          blockedScheduleEnd: '07:00',
          isEnabled: true,
          isPreset: true,
        ),
        TrackedAppRule(
          id: 'preset_tiktok',
          displayName: 'TikTok',
          packageName: 'com.zhiliaoapp.musically',
          iosBundleHint: 'com.zhiliaoapp.musically',
          category: 'video',
          dailyLimitMinutes: 30,
          warningThresholdPercent: 80,
          interventionLevel: WellbeingInterventionLevel.timedSoftPause,
          blockedScheduleStart: '22:00',
          blockedScheduleEnd: '07:00',
          isEnabled: true,
          isPreset: true,
        ),
        TrackedAppRule(
          id: 'preset_youtube',
          displayName: 'YouTube',
          packageName: 'com.google.android.youtube',
          iosBundleHint: 'com.google.ios.youtube',
          category: 'video',
          dailyLimitMinutes: 60,
          warningThresholdPercent: 85,
          interventionLevel: WellbeingInterventionLevel.preLimitWarning,
          isEnabled: true,
          isPreset: true,
        ),
        TrackedAppRule(
          id: 'preset_facebook',
          displayName: 'Facebook',
          packageName: 'com.facebook.katana',
          iosBundleHint: 'com.facebook.Facebook',
          category: 'social',
          dailyLimitMinutes: 30,
          warningThresholdPercent: 80,
          interventionLevel: WellbeingInterventionLevel.trackOnly,
          isEnabled: false,
          isPreset: true,
        ),
        TrackedAppRule(
          id: 'preset_games',
          displayName: 'Mobile Games',
          packageName: 'com.nestin.category.games',
          category: 'gaming',
          dailyLimitMinutes: 60,
          warningThresholdPercent: 80,
          interventionLevel: WellbeingInterventionLevel.blockingSchedule,
          blockedScheduleStart: '23:00',
          blockedScheduleEnd: '07:00',
          isEnabled: false,
          isPreset: true,
        ),
      ];
}

class AppUsageRecord {
  final String packageName;
  final String appName;
  final int usedMinutesToday;
  final int launchCountToday;
  final DateTime? lastUsedAt;
  final String dateKey;
  final String dataSource; // 'usage_stats', 'manual_check_in', 'unavailable'

  const AppUsageRecord({
    required this.packageName,
    required this.appName,
    required this.usedMinutesToday,
    this.launchCountToday = 0,
    this.lastUsedAt,
    required this.dateKey,
    this.dataSource = 'usage_stats',
  });

  double ratioForLimit(int dailyLimitMinutes) {
    if (dailyLimitMinutes <= 0) return 0;
    return usedMinutesToday / dailyLimitMinutes;
  }

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'appName': appName,
        'usedMinutesToday': usedMinutesToday,
        'launchCountToday': launchCountToday,
        'lastUsedAt': lastUsedAt?.toIso8601String(),
        'dateKey': dateKey,
        'dataSource': dataSource,
      };

  factory AppUsageRecord.fromJson(Map<String, dynamic> json) {
    return AppUsageRecord(
      packageName: json['packageName'] as String? ?? '',
      appName: json['appName'] as String? ?? '',
      usedMinutesToday: json['usedMinutesToday'] as int? ?? 0,
      launchCountToday: json['launchCountToday'] as int? ?? 0,
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.tryParse(json['lastUsedAt'] as String)
          : null,
      dateKey: json['dateKey'] as String? ?? '',
      dataSource: json['dataSource'] as String? ?? 'unavailable',
    );
  }
}

class AppInterventionLog {
  final String id;
  final String ruleId;
  final String appName;
  final String packageName;
  final WellbeingInterventionLevel level;
  final String reason;
  final String outcome;
  final DateTime timestamp;

  AppInterventionLog({
    String? id,
    required this.ruleId,
    required this.appName,
    required this.packageName,
    required this.level,
    required this.reason,
    required this.outcome,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'ruleId': ruleId,
        'appName': appName,
        'packageName': packageName,
        'level': level.name,
        'reason': reason,
        'outcome': outcome,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AppInterventionLog.fromJson(Map<String, dynamic> json) {
    return AppInterventionLog(
      id: json['id'] as String?,
      ruleId: json['ruleId'] as String? ?? '',
      appName: json['appName'] as String? ?? '',
      packageName: json['packageName'] as String? ?? '',
      level: WellbeingInterventionLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => WellbeingInterventionLevel.preLimitWarning,
      ),
      reason: json['reason'] as String? ?? '',
      outcome: json['outcome'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? (DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

class WellbeingDailySnapshot {
  final String dateKey;
  final List<AppUsageRecord> records;
  final bool permissionGranted;
  final String honestBoundaryMessage;
  final List<String> bypassedPackages;

  const WellbeingDailySnapshot({
    required this.dateKey,
    this.records = const [],
    required this.permissionGranted,
    this.honestBoundaryMessage = '',
    this.bypassedPackages = const [],
  });

  int get totalTrackedMinutes =>
      records.fold(0, (sum, r) => sum + r.usedMinutesToday);

  AppUsageRecord? recordForPackage(String packageName) {
    for (final r in records) {
      if (r.packageName == packageName) return r;
    }
    return null;
  }
}
