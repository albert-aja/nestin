class HealthGoalsConfig {
  final int dailyStepGoal;
  final int sleepTargetMinutes;
  final int dailyActiveMinutesGoal;
  final int dailyMindfulMinutesGoal;
  final double strideLengthMeters;
  final bool moveReminderEnabled;

  const HealthGoalsConfig({
    this.dailyStepGoal = 8000,
    this.sleepTargetMinutes = 450, // 7h 30m (5 optimal 90m REM cycles)
    this.dailyActiveMinutesGoal = 30,
    this.dailyMindfulMinutesGoal = 10,
    this.strideLengthMeters = 0.762,
    this.moveReminderEnabled = false,
  });

  String get formattedSleepTarget {
    final hrs = sleepTargetMinutes ~/ 60;
    final mins = sleepTargetMinutes % 60;
    if (mins == 0) return '${hrs}h';
    return '${hrs}h ${mins}m';
  }

  HealthGoalsConfig copyWith({
    int? dailyStepGoal,
    int? sleepTargetMinutes,
    int? dailyActiveMinutesGoal,
    int? dailyMindfulMinutesGoal,
    double? strideLengthMeters,
    bool? moveReminderEnabled,
  }) {
    return HealthGoalsConfig(
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      sleepTargetMinutes: sleepTargetMinutes ?? this.sleepTargetMinutes,
      dailyActiveMinutesGoal:
          dailyActiveMinutesGoal ?? this.dailyActiveMinutesGoal,
      dailyMindfulMinutesGoal:
          dailyMindfulMinutesGoal ?? this.dailyMindfulMinutesGoal,
      strideLengthMeters: strideLengthMeters ?? this.strideLengthMeters,
      moveReminderEnabled: moveReminderEnabled ?? this.moveReminderEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'dailyStepGoal': dailyStepGoal,
        'sleepTargetMinutes': sleepTargetMinutes,
        'dailyActiveMinutesGoal': dailyActiveMinutesGoal,
        'dailyMindfulMinutesGoal': dailyMindfulMinutesGoal,
        'strideLengthMeters': strideLengthMeters,
        'moveReminderEnabled': moveReminderEnabled,
      };

  factory HealthGoalsConfig.fromJson(Map<String, dynamic> json) {
    return HealthGoalsConfig(
      dailyStepGoal: (json['dailyStepGoal'] as num?)?.toInt() ?? 8000,
      sleepTargetMinutes:
          (json['sleepTargetMinutes'] as num?)?.toInt() ?? 450,
      dailyActiveMinutesGoal:
          (json['dailyActiveMinutesGoal'] as num?)?.toInt() ?? 30,
      dailyMindfulMinutesGoal:
          (json['dailyMindfulMinutesGoal'] as num?)?.toInt() ?? 10,
      strideLengthMeters:
          (json['strideLengthMeters'] as num?)?.toDouble() ?? 0.762,
      moveReminderEnabled: json['moveReminderEnabled'] as bool? ?? false,
    );
  }
}

class DailyHealthActivity {
  final String dateKey; // YYYY-MM-DD
  final int steps;
  final int stepGoal;
  final int activeMinutes;
  final int activeMinutesGoal;
  final int mindfulMinutes;
  final int mindfulMinutesGoal;
  final int? restingHeartRate;
  final int? bloodOxygenPercent;
  final int? energyScore; // 1-5 subjective vitality rating
  final bool syncedFromWearable;
  final DateTime updatedAt;

  const DailyHealthActivity({
    required this.dateKey,
    this.steps = 0,
    this.stepGoal = 8000,
    this.activeMinutes = 0,
    this.activeMinutesGoal = 30,
    this.mindfulMinutes = 0,
    this.mindfulMinutesGoal = 10,
    this.restingHeartRate,
    this.bloodOxygenPercent,
    this.energyScore,
    this.syncedFromWearable = false,
    required this.updatedAt,
  });

  factory DailyHealthActivity.emptyForDate(
    String dateKey, [
    HealthGoalsConfig goals = const HealthGoalsConfig(),
  ]) {
    return DailyHealthActivity(
      dateKey: dateKey,
      steps: 0,
      stepGoal: goals.dailyStepGoal,
      activeMinutes: 0,
      activeMinutesGoal: goals.dailyActiveMinutesGoal,
      mindfulMinutes: 0,
      mindfulMinutesGoal: goals.dailyMindfulMinutesGoal,
      updatedAt: DateTime.now(),
    );
  }

  double distanceKmWithStride([double strideMeters = 0.762]) {
    if (steps <= 0 || strideMeters <= 0) return 0.0;
    return (steps * strideMeters) / 1000.0;
  }

  double get distanceKm => distanceKmWithStride();

  int get estimatedActiveCalories {
    return (steps * 0.04).round() + (activeMinutes * 4);
  }

  double get stepProgress =>
      stepGoal > 0 ? (steps / stepGoal).clamp(0.0, 1.0) : 0.0;

  int get remainingSteps => (stepGoal - steps).clamp(0, stepGoal);

  bool get isStepGoalMet => stepGoal > 0 && steps >= stepGoal;

  double get activeMinutesProgress => activeMinutesGoal > 0
      ? (activeMinutes / activeMinutesGoal).clamp(0.0, 1.0)
      : 0.0;

  bool get isActiveGoalMet =>
      activeMinutesGoal > 0 && activeMinutes >= activeMinutesGoal;

  double get mindfulProgress => mindfulMinutesGoal > 0
      ? (mindfulMinutes / mindfulMinutesGoal).clamp(0.0, 1.0)
      : 0.0;

  bool get isMindfulGoalMet =>
      mindfulMinutesGoal > 0 && mindfulMinutes >= mindfulMinutesGoal;

  DailyHealthActivity copyWith({
    String? dateKey,
    int? steps,
    int? stepGoal,
    int? activeMinutes,
    int? activeMinutesGoal,
    int? mindfulMinutes,
    int? mindfulMinutesGoal,
    int? restingHeartRate,
    int? bloodOxygenPercent,
    int? energyScore,
    bool? syncedFromWearable,
    DateTime? updatedAt,
  }) {
    return DailyHealthActivity(
      dateKey: dateKey ?? this.dateKey,
      steps: steps ?? this.steps,
      stepGoal: stepGoal ?? this.stepGoal,
      activeMinutes: activeMinutes ?? this.activeMinutes,
      activeMinutesGoal: activeMinutesGoal ?? this.activeMinutesGoal,
      mindfulMinutes: mindfulMinutes ?? this.mindfulMinutes,
      mindfulMinutesGoal: mindfulMinutesGoal ?? this.mindfulMinutesGoal,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      bloodOxygenPercent: bloodOxygenPercent ?? this.bloodOxygenPercent,
      energyScore: energyScore ?? this.energyScore,
      syncedFromWearable: syncedFromWearable ?? this.syncedFromWearable,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'steps': steps,
        'stepGoal': stepGoal,
        'activeMinutes': activeMinutes,
        'activeMinutesGoal': activeMinutesGoal,
        'mindfulMinutes': mindfulMinutes,
        'mindfulMinutesGoal': mindfulMinutesGoal,
        'restingHeartRate': restingHeartRate,
        'bloodOxygenPercent': bloodOxygenPercent,
        'energyScore': energyScore,
        'syncedFromWearable': syncedFromWearable,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory DailyHealthActivity.fromJson(Map<String, dynamic> json) {
    return DailyHealthActivity(
      dateKey: json['dateKey'] as String? ?? '',
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      stepGoal: (json['stepGoal'] as num?)?.toInt() ?? 8000,
      activeMinutes: (json['activeMinutes'] as num?)?.toInt() ?? 0,
      activeMinutesGoal: (json['activeMinutesGoal'] as num?)?.toInt() ?? 30,
      mindfulMinutes: (json['mindfulMinutes'] as num?)?.toInt() ?? 0,
      mindfulMinutesGoal: (json['mindfulMinutesGoal'] as num?)?.toInt() ?? 10,
      restingHeartRate: (json['restingHeartRate'] as num?)?.toInt(),
      bloodOxygenPercent: (json['bloodOxygenPercent'] as num?)?.toInt(),
      energyScore: (json['energyScore'] as num?)?.toInt(),
      syncedFromWearable: json['syncedFromWearable'] as bool? ?? false,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

