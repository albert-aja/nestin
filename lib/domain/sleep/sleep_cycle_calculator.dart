class SleepCycleOption {
  final int cycles;
  final Duration sleepDuration;
  final DateTime targetTime;
  final bool isRecommended;
  final String label;

  const SleepCycleOption({
    required this.cycles,
    required this.sleepDuration,
    required this.targetTime,
    required this.isRecommended,
    required this.label,
  });
}

class SleepCycleCalculator {
  static const int cycleMinutes = 90;
  static const int fallAsleepMinutes = 14;

  /// Given a target wake-up time, calculates recommended bedtimes
  static List<SleepCycleOption> calculateBedtimes(DateTime wakeUpTime) {
    final options = <SleepCycleOption>[];

    final cycleCounts = [6, 5, 4, 3];
    for (final cycles in cycleCounts) {
      final totalMinutes = (cycles * cycleMinutes) + fallAsleepMinutes;
      final bedtime = wakeUpTime.subtract(Duration(minutes: totalMinutes));

      String label = '$cycles Cycles (${(cycles * 1.5).toStringAsFixed(1)} hrs)';
      if (cycles == 5) label += ' • Optimal Sweet Spot';

      options.add(
        SleepCycleOption(
          cycles: cycles,
          sleepDuration: Duration(minutes: cycles * cycleMinutes),
          targetTime: bedtime,
          isRecommended: cycles == 5,
          label: label,
        ),
      );
    }

    return options;
  }

  /// Given a bedtime (or right now), calculates recommended wake-up times
  static List<SleepCycleOption> calculateWakeUpTimes(DateTime sleepTime) {
    final options = <SleepCycleOption>[];

    final cycleCounts = [3, 4, 5, 6];
    for (final cycles in cycleCounts) {
      final totalMinutes = (cycles * cycleMinutes) + fallAsleepMinutes;
      final wakeTime = sleepTime.add(Duration(minutes: totalMinutes));

      String label = '$cycles Cycles (${(cycles * 1.5).toStringAsFixed(1)} hrs)';
      if (cycles == 5) label += ' • Optimal Sweet Spot';

      options.add(
        SleepCycleOption(
          cycles: cycles,
          sleepDuration: Duration(minutes: cycles * cycleMinutes),
          targetTime: wakeTime,
          isRecommended: cycles == 5,
          label: label,
        ),
      );
    }

    return options;
  }
}

