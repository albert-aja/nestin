class HydrationData {
  final int glassesConsumed; // 1 glass = 250ml
  final int dailyGoalGlasses; // Default 8 glasses (2000ml)
  final bool remindersEnabled; // Default true
  final int reminderIntervalMinutes; // Default 90 minutes
  final int startHour; // Default 8 (8:00 AM)
  final int endHour; // Default 21 (9:00 PM)
  final String lastLoggedDate; // YYYY-MM-DD for midnight rollover
  final Map<String, int> dailyHistory; // YYYY-MM-DD -> glassesConsumed

  const HydrationData({
    this.glassesConsumed = 0,
    this.dailyGoalGlasses = 8,
    this.remindersEnabled = true,
    this.reminderIntervalMinutes = 90,
    this.startHour = 8,
    this.endHour = 21,
    required this.lastLoggedDate,
    this.dailyHistory = const {},
  });

  int get currentMilliliters => glassesConsumed * 250;
  int get targetMilliliters => dailyGoalGlasses * 250;
  bool get isGoalMet => glassesConsumed >= dailyGoalGlasses;
  double get progressFraction =>
      dailyGoalGlasses > 0 ? (glassesConsumed / dailyGoalGlasses).clamp(0.0, 1.0) : 0.0;

  HydrationData copyWith({
    int? glassesConsumed,
    int? dailyGoalGlasses,
    bool? remindersEnabled,
    int? reminderIntervalMinutes,
    int? startHour,
    int? endHour,
    String? lastLoggedDate,
    Map<String, int>? dailyHistory,
  }) {
    return HydrationData(
      glassesConsumed: glassesConsumed ?? this.glassesConsumed,
      dailyGoalGlasses: dailyGoalGlasses ?? this.dailyGoalGlasses,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderIntervalMinutes: reminderIntervalMinutes ?? this.reminderIntervalMinutes,
      startHour: startHour ?? this.startHour,
      endHour: endHour ?? this.endHour,
      lastLoggedDate: lastLoggedDate ?? this.lastLoggedDate,
      dailyHistory: dailyHistory ?? this.dailyHistory,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'glassesConsumed': glassesConsumed,
      'dailyGoalGlasses': dailyGoalGlasses,
      'remindersEnabled': remindersEnabled,
      'reminderIntervalMinutes': reminderIntervalMinutes,
      'startHour': startHour,
      'endHour': endHour,
      'lastLoggedDate': lastLoggedDate,
      'dailyHistory': dailyHistory,
    };
  }

  factory HydrationData.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['dailyHistory'] as Map<String, dynamic>?;
    final historyMap = <String, int>{};
    if (rawHistory != null) {
      for (final entry in rawHistory.entries) {
        if (entry.value is num) {
          historyMap[entry.key] = (entry.value as num).toInt();
        }
      }
    }

    return HydrationData(
      glassesConsumed: (json['glassesConsumed'] as num?)?.toInt() ?? 0,
      dailyGoalGlasses: (json['dailyGoalGlasses'] as num?)?.toInt() ?? 8,
      remindersEnabled: json['remindersEnabled'] as bool? ?? true,
      reminderIntervalMinutes: (json['reminderIntervalMinutes'] as num?)?.toInt() ?? 90,
      startHour: (json['startHour'] as num?)?.toInt() ?? 8,
      endHour: (json['endHour'] as num?)?.toInt() ?? 21,
      lastLoggedDate: json['lastLoggedDate'] as String? ??
          DateTime.now().toIso8601String().substring(0, 10),
      dailyHistory: historyMap,
    );
  }

  factory HydrationData.initial([DateTime? date]) {
    final now = date ?? DateTime.now();
    return HydrationData(
      glassesConsumed: 0,
      dailyGoalGlasses: 8,
      remindersEnabled: true,
      reminderIntervalMinutes: 90,
      startHour: 8,
      endHour: 21,
      lastLoggedDate: now.toIso8601String().substring(0, 10),
      dailyHistory: const {},
    );
  }

  // --- 7-Day Sparkline & Consistency Analytics ---

  /// Returns 7 consecutive days ending on [referenceDate] (or now)
  List<DateTime> getWeeklyDates([DateTime? referenceDate]) {
    final ref = referenceDate ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
  }

  /// Returns glasses consumed for each of the 7 days
  List<int> getWeeklyGlasses([DateTime? referenceDate]) {
    final dates = getWeeklyDates(referenceDate);
    final todayKey = (referenceDate ?? DateTime.now()).toIso8601String().substring(0, 10);

    return dates.map((d) {
      final key = d.toIso8601String().substring(0, 10);
      if (key == todayKey && key == lastLoggedDate) {
        return glassesConsumed;
      }
      return dailyHistory[key] ?? (key == lastLoggedDate ? glassesConsumed : 0);
    }).toList();
  }

  /// Returns milliliters consumed for each of the 7 days (1 glass = 250ml)
  List<int> getWeeklyMilliliters([DateTime? referenceDate]) {
    return getWeeklyGlasses(referenceDate).map((g) => g * 250).toList();
  }

  /// Count of days where intake reached or exceeded dailyGoalGlasses
  int getWeeklyDaysMetCount([DateTime? referenceDate]) {
    return getWeeklyGlasses(referenceDate)
        .where((glasses) => glasses >= dailyGoalGlasses)
        .length;
  }

  /// Weekly consistency percentage (0.0 to 100.0)
  double getWeeklyConsistencyPercentage([DateTime? referenceDate]) {
    return (getWeeklyDaysMetCount(referenceDate) / 7.0) * 100.0;
  }

  /// Average daily milliliters consumed across the 7 days
  int getWeeklyAverageMilliliters([DateTime? referenceDate]) {
    final weekly = getWeeklyMilliliters(referenceDate);
    final total = weekly.fold<int>(0, (sum, ml) => sum + ml);
    return (total / 7.0).round();
  }

  /// Consistency label summary
  String getWeeklyConsistencyLabel([DateTime? referenceDate]) {
    final count = getWeeklyDaysMetCount(referenceDate);
    final pct = getWeeklyConsistencyPercentage(referenceDate).round();

    if (count >= 6) {
      return 'Optimal Consistency 💧 ($count/7 days • $pct%)';
    } else if (count >= 4) {
      return 'Good Consistency 🌿 ($count/7 days • $pct%)';
    } else if (count >= 2) {
      return 'Building Momentum ⚡ ($count/7 days • $pct%)';
    } else {
      return 'Hydration Target Needed ⚠️ ($count/7 days • $pct%)';
    }
  }

  /// Detailed consistency insight message
  String getWeeklyInsight([DateTime? referenceDate]) {
    final avgMl = getWeeklyAverageMilliliters(referenceDate);
    final count = getWeeklyDaysMetCount(referenceDate);

    if (count >= 5) {
      return 'Outstanding hydration habit! Averaging ${avgMl}ml daily, consistently hitting your ${targetMilliliters}ml goal.';
    } else if (count >= 3) {
      return 'Solid hydration baseline averaging ${avgMl}ml/day. Try drinking one extra glass in the afternoon.';
    } else {
      return 'Averaging ${avgMl}ml/day. Keep your water bottle nearby to reach your ${targetMilliliters}ml target.';
    }
  }
}
