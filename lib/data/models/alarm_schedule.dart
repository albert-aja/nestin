enum ScheduleType {
  oneTime,
  daily,
  weekdays,
  weekends,
  customDays,
}

class AlarmSchedule {
  final ScheduleType type;
  /// 1 = Monday, 2 = Tuesday, ..., 7 = Sunday (matching DateTime.weekday)
  final Set<int> selectedDays;
  final DateTime? oneTimeDate;

  const AlarmSchedule({
    required this.type,
    this.selectedDays = const {},
    this.oneTimeDate,
  });

  factory AlarmSchedule.oneTime([DateTime? date]) {
    return AlarmSchedule(
      type: ScheduleType.oneTime,
      oneTimeDate: date,
    );
  }

  factory AlarmSchedule.daily() {
    return const AlarmSchedule(
      type: ScheduleType.daily,
      selectedDays: {1, 2, 3, 4, 5, 6, 7},
    );
  }

  factory AlarmSchedule.weekdays() {
    return const AlarmSchedule(
      type: ScheduleType.weekdays,
      selectedDays: {1, 2, 3, 4, 5},
    );
  }

  factory AlarmSchedule.weekends() {
    return const AlarmSchedule(
      type: ScheduleType.weekends,
      selectedDays: {6, 7},
    );
  }

  factory AlarmSchedule.customDays(Set<int> days) {
    return AlarmSchedule(
      type: ScheduleType.customDays,
      selectedDays: Set.unmodifiable(days),
    );
  }

  bool get isRecurring => type != ScheduleType.oneTime;

  bool isDayActive(int day) {
    if (type == ScheduleType.daily) return true;
    if (type == ScheduleType.weekdays) return day >= 1 && day <= 5;
    if (type == ScheduleType.weekends) return day == 6 || day == 7;
    if (type == ScheduleType.customDays) return selectedDays.contains(day);
    return false;
  }

  /// Calculates the next occurrence strictly after `now` for an alarm set at [targetHour]:[targetMinute].
  DateTime calculateNextOccurrence(DateTime now, int targetHour, int targetMinute) {
    if (type == ScheduleType.oneTime) {
      if (oneTimeDate != null) {
        final candidate = DateTime(
          oneTimeDate!.year,
          oneTimeDate!.month,
          oneTimeDate!.day,
          targetHour,
          targetMinute,
        );
        if (candidate.isAfter(now)) {
          return candidate;
        }
      }
      // If today target time is in future, use today
      final todayCandidate = DateTime(
        now.year,
        now.month,
        now.day,
        targetHour,
        targetMinute,
      );
      if (todayCandidate.isAfter(now)) {
        return todayCandidate;
      }
      // Otherwise tomorrow
      return todayCandidate.add(const Duration(days: 1));
    }

    // Recurring alarms: check up to 8 days ahead
    for (int offset = 0; offset <= 7; offset++) {
      final candidateDate = now.add(Duration(days: offset));
      final candidateTime = DateTime(
        candidateDate.year,
        candidateDate.month,
        candidateDate.day,
        targetHour,
        targetMinute,
      );

      if (candidateTime.isAfter(now) && isDayActive(candidateDate.weekday)) {
        return candidateTime;
      }
    }

    // Fallback tomorrow same time
    return DateTime(now.year, now.month, now.day + 1, targetHour, targetMinute);
  }

  String getDisplayText() {
    switch (type) {
      case ScheduleType.oneTime:
        return 'Once';
      case ScheduleType.daily:
        return 'Every day';
      case ScheduleType.weekdays:
        return 'Mon - Fri';
      case ScheduleType.weekends:
        return 'Sat, Sun';
      case ScheduleType.customDays:
        if (selectedDays.isEmpty) return 'No days selected';
        if (selectedDays.length == 7) return 'Every day';
        if (selectedDays.length == 5 &&
            selectedDays.contains(1) &&
            selectedDays.contains(2) &&
            selectedDays.contains(3) &&
            selectedDays.contains(4) &&
            selectedDays.contains(5)) {
          return 'Mon - Fri';
        }
        const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final sorted = selectedDays.toList()..sort();
        return sorted.map((d) => dayNames[d - 1]).join(', ');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'selectedDays': selectedDays.toList(),
      'oneTimeDate': oneTimeDate?.toIso8601String(),
    };
  }

  factory AlarmSchedule.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'daily';
    final type = ScheduleType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => ScheduleType.daily,
    );
    final daysList = (json['selectedDays'] as List<dynamic>?)?.map((e) => e as int).toSet() ?? {};
    final oneTimeStr = json['oneTimeDate'] as String?;
    return AlarmSchedule(
      type: type,
      selectedDays: daysList,
      oneTimeDate: oneTimeStr != null ? DateTime.tryParse(oneTimeStr) : null,
    );
  }

  AlarmSchedule copyWith({
    ScheduleType? type,
    Set<int>? selectedDays,
    DateTime? oneTimeDate,
  }) {
    return AlarmSchedule(
      type: type ?? this.type,
      selectedDays: selectedDays ?? this.selectedDays,
      oneTimeDate: oneTimeDate ?? this.oneTimeDate,
    );
  }
}

