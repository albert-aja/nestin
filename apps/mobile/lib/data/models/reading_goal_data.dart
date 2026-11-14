class ReadingGoalData {
  static const int minDailyGoal = 1;
  static const int maxDailyGoal = 500;

  final int dailyPageGoal;
  final bool eveningReminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final Map<String, int> dailyPagesHistory;

  const ReadingGoalData({
    this.dailyPageGoal = 15,
    this.eveningReminderEnabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.dailyPagesHistory = const {},
  });

  factory ReadingGoalData.initial() => const ReadingGoalData();

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime? parseDateKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  String get formattedReminderTime {
    final h = reminderHour.clamp(0, 23).toString().padLeft(2, '0');
    final m = reminderMinute.clamp(0, 59).toString().padLeft(2, '0');
    return '$h:$m';
  }

  int pagesReadOn(DateTime date) => dailyPagesHistory[dateKey(date)] ?? 0;

  int todayPages([DateTime? referenceDate]) =>
      pagesReadOn(referenceDate ?? DateTime.now());

  bool isGoalMetOn(DateTime date) =>
      dailyPageGoal > 0 && pagesReadOn(date) >= dailyPageGoal;

  bool isTodayGoalMet([DateTime? referenceDate]) =>
      isGoalMetOn(referenceDate ?? DateTime.now());

  double todayProgressFraction([DateTime? referenceDate]) {
    if (dailyPageGoal <= 0) return 0.0;
    return (todayPages(referenceDate) / dailyPageGoal).clamp(0.0, 1.0);
  }

  int pagesRemainingToday([DateTime? referenceDate]) =>
      (dailyPageGoal - todayPages(referenceDate)).clamp(0, dailyPageGoal);

  /// Returns [days] consecutive local dates ending on [referenceDate] (oldest -> newest).
  List<DateTime> getWeeklyDates([DateTime? referenceDate, int days = 7]) {
    final ref = referenceDate ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    return List.generate(
      days,
      (i) => today.subtract(Duration(days: (days - 1) - i)),
    );
  }

  /// Returns pages read for each of the last [days] days ending on [referenceDate].
  List<int> getWeeklyPages([DateTime? referenceDate, int days = 7]) {
    return getWeeklyDates(referenceDate, days)
        .map(pagesReadOn)
        .toList(growable: false);
  }

  int getWeeklyTotalPages([DateTime? referenceDate, int days = 7]) {
    return getWeeklyPages(referenceDate, days)
        .fold<int>(0, (sum, pages) => sum + pages);
  }

  int getWeeklyDaysMetCount([DateTime? referenceDate, int days = 7]) {
    if (dailyPageGoal <= 0) return 0;
    return getWeeklyPages(referenceDate, days)
        .where((pages) => pages >= dailyPageGoal)
        .length;
  }

  double getWeeklyAveragePages([DateTime? referenceDate, int days = 7]) {
    if (days <= 0) return 0.0;
    return getWeeklyTotalPages(referenceDate, days) / days;
  }

  /// Consecutive days meeting [dailyPageGoal].
  ///
  /// If today's goal is not met yet, yesterday's active streak remains intact
  /// until the day ends; once today's goal is reached, today adds +1 to it.
  int getCurrentStreak([DateTime? referenceDate]) {
    if (dailyPageGoal <= 0 || dailyPagesHistory.isEmpty) return 0;
    final ref = referenceDate ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);

    var cursor = isGoalMetOn(today)
        ? today
        : today.subtract(const Duration(days: 1));

    var streak = 0;
    while (isGoalMetOn(cursor) && streak < 3660) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Longest consecutive run of days meeting [dailyPageGoal] across recorded history.
  int getBestStreak() {
    if (dailyPageGoal <= 0 || dailyPagesHistory.isEmpty) return 0;

    final metDates = <DateTime>[];
    for (final entry in dailyPagesHistory.entries) {
      if (entry.value >= dailyPageGoal) {
        final parsed = parseDateKey(entry.key);
        if (parsed != null) metDates.add(parsed);
      }
    }
    if (metDates.isEmpty) return 0;

    metDates.sort();
    var best = 1;
    var current = 1;
    for (var i = 1; i < metDates.length; i++) {
      final diffDays = metDates[i].difference(metDates[i - 1]).inDays;
      if (diffDays == 0) continue;
      if (diffDays == 1) {
        current++;
        if (current > best) best = current;
      } else {
        current = 1;
      }
    }
    return best;
  }

  ReadingGoalData copyWith({
    int? dailyPageGoal,
    bool? eveningReminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    Map<String, int>? dailyPagesHistory,
  }) {
    return ReadingGoalData(
      dailyPageGoal:
          (dailyPageGoal ?? this.dailyPageGoal).clamp(minDailyGoal, maxDailyGoal),
      eveningReminderEnabled:
          eveningReminderEnabled ?? this.eveningReminderEnabled,
      reminderHour: (reminderHour ?? this.reminderHour).clamp(0, 23),
      reminderMinute: (reminderMinute ?? this.reminderMinute).clamp(0, 59),
      dailyPagesHistory: dailyPagesHistory ?? this.dailyPagesHistory,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dailyPageGoal': dailyPageGoal,
      'eveningReminderEnabled': eveningReminderEnabled,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      'dailyPagesHistory': dailyPagesHistory,
    };
  }

  factory ReadingGoalData.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['dailyPagesHistory'] as Map<String, dynamic>?;
    final history = <String, int>{};
    if (rawHistory != null) {
      for (final entry in rawHistory.entries) {
        final val = entry.value;
        if (val is num && val > 0) {
          history[entry.key] = val.toInt();
        }
      }
    }

    return ReadingGoalData(
      dailyPageGoal: ((json['dailyPageGoal'] as num?)?.toInt() ?? 15)
          .clamp(minDailyGoal, maxDailyGoal),
      eveningReminderEnabled: json['eveningReminderEnabled'] as bool? ?? false,
      reminderHour: ((json['reminderHour'] as num?)?.toInt() ?? 20).clamp(0, 23),
      reminderMinute:
          ((json['reminderMinute'] as num?)?.toInt() ?? 0).clamp(0, 59),
      dailyPagesHistory: history,
    );
  }
}
