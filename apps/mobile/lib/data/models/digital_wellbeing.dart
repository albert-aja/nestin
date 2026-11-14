import 'package:uuid/uuid.dart';

/// Graduated intervention ladder for Scout Digital Wellbeing & Phone Control.
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

class TrackedAppRule {
  final String id;
  final String displayName;
  final String packageName;
  final String? iosBundleHint;
  final String category;
  final int dailyLimitMinutes;
  final int warningThresholdPercent;
  final WellbeingInterventionLevel interventionLevel;
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
    this.warningThresholdPercent = 80,
    this.interventionLevel = WellbeingInterventionLevel.preLimitWarning,
    this.blockedScheduleStart,
    this.blockedScheduleEnd,
    this.isEnabled = true,
    this.isPreset = false,
  }) : id = id ?? const Uuid().v4();

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
    int? warningThresholdPercent,
    WellbeingInterventionLevel? interventionLevel,
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
      warningThresholdPercent:
          warningThresholdPercent ?? this.warningThresholdPercent,
      interventionLevel: interventionLevel ?? this.interventionLevel,
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
        'warningThresholdPercent': warningThresholdPercent,
        'interventionLevel': interventionLevel.name,
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
      warningThresholdPercent: json['warningThresholdPercent'] as int? ?? 80,
      interventionLevel: WellbeingInterventionLevel.values.firstWhere(
        (e) => e.name == json['interventionLevel'],
        orElse: () => WellbeingInterventionLevel.preLimitWarning,
      ),
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

  const WellbeingDailySnapshot({
    required this.dateKey,
    this.records = const [],
    required this.permissionGranted,
    this.honestBoundaryMessage = '',
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
