class BedtimeWindDownConfig {
  final bool enabled;
  final bool syncWithNextAlarm;
  final int targetWakeHour; // Default 7 (7:00 AM)
  final int targetWakeMinute; // Default 0
  final int targetSleepCycles; // Default 5 cycles (7.5 hours)
  final int windDownLeadMinutes; // Default 30 minutes before bedtime
  final int fallAsleepMinutes; // Default 14 minutes latency

  const BedtimeWindDownConfig({
    this.enabled = true,
    this.syncWithNextAlarm = true,
    this.targetWakeHour = 7,
    this.targetWakeMinute = 0,
    this.targetSleepCycles = 5,
    this.windDownLeadMinutes = 30,
    this.fallAsleepMinutes = 14,
  });

  /// Computes target bedtime given target wake up time
  DateTime calculateTargetBedtime(DateTime wakeUpTime) {
    final totalSleepMinutes =
        (targetSleepCycles * 90) + fallAsleepMinutes;
    return wakeUpTime.subtract(Duration(minutes: totalSleepMinutes));
  }

  /// Computes exact wind-down alert time (lead time prior to bedtime)
  DateTime calculateWindDownAlertTime(DateTime wakeUpTime) {
    final bedtime = calculateTargetBedtime(wakeUpTime);
    return bedtime.subtract(Duration(minutes: windDownLeadMinutes));
  }

  /// Resolves effective wake up time given current time and optional next alarm
  DateTime resolveEffectiveWakeUpTime({
    DateTime? currentTime,
    DateTime? nextAlarmTime,
  }) {
    final now = currentTime ?? DateTime.now();

    if (syncWithNextAlarm && nextAlarmTime != null) {
      return nextAlarmTime;
    }

    // Otherwise use configured custom target wake time
    var target = DateTime(
      now.year,
      now.month,
      now.day,
      targetWakeHour,
      targetWakeMinute,
    );

    // If target wake time for today already passed, target tomorrow
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }

    return target;
  }

  BedtimeWindDownConfig copyWith({
    bool? enabled,
    bool? syncWithNextAlarm,
    int? targetWakeHour,
    int? targetWakeMinute,
    int? targetSleepCycles,
    int? windDownLeadMinutes,
    int? fallAsleepMinutes,
  }) {
    return BedtimeWindDownConfig(
      enabled: enabled ?? this.enabled,
      syncWithNextAlarm: syncWithNextAlarm ?? this.syncWithNextAlarm,
      targetWakeHour: targetWakeHour ?? this.targetWakeHour,
      targetWakeMinute: targetWakeMinute ?? this.targetWakeMinute,
      targetSleepCycles: targetSleepCycles ?? this.targetSleepCycles,
      windDownLeadMinutes: windDownLeadMinutes ?? this.windDownLeadMinutes,
      fallAsleepMinutes: fallAsleepMinutes ?? this.fallAsleepMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'syncWithNextAlarm': syncWithNextAlarm,
      'targetWakeHour': targetWakeHour,
      'targetWakeMinute': targetWakeMinute,
      'targetSleepCycles': targetSleepCycles,
      'windDownLeadMinutes': windDownLeadMinutes,
      'fallAsleepMinutes': fallAsleepMinutes,
    };
  }

  factory BedtimeWindDownConfig.fromJson(Map<String, dynamic> json) {
    return BedtimeWindDownConfig(
      enabled: json['enabled'] as bool? ?? true,
      syncWithNextAlarm: json['syncWithNextAlarm'] as bool? ?? true,
      targetWakeHour: (json['targetWakeHour'] as num?)?.toInt() ?? 7,
      targetWakeMinute: (json['targetWakeMinute'] as num?)?.toInt() ?? 0,
      targetSleepCycles: (json['targetSleepCycles'] as num?)?.toInt() ?? 5,
      windDownLeadMinutes: (json['windDownLeadMinutes'] as num?)?.toInt() ?? 30,
      fallAsleepMinutes: (json['fallAsleepMinutes'] as num?)?.toInt() ?? 14,
    );
  }

  factory BedtimeWindDownConfig.initial() {
    return const BedtimeWindDownConfig();
  }
}
