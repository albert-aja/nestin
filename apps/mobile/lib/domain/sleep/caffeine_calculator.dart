import 'dart:math' as math;
import '../../data/models/caffeine_data.dart';

/// Qualitative sleep-impact bucket for residual caffeine at target bedtime.
enum CaffeineSleepImpact {
  clear,
  mild,
  moderate,
  elevated,
}

/// Single point on the pharmacokinetic caffeine clearance curve.
class CaffeineProjectionPoint {
  final DateTime time;
  final double residualMg;

  const CaffeineProjectionPoint({
    required this.time,
    required this.residualMg,
  });
}

/// Pure pharmacokinetic calculator modeling first-order ~5-hour caffeine half-life decay.
class CaffeineCalculator {
  static const double defaultHalfLifeHours = 5.0;
  static const int maxDecayHorizonHours = 48;

  /// Computes remaining caffeine (mg) from a single [entry] at [targetTime].
  ///
  /// Uses first-order decay: `C(t) = C0 * 0.5 ^ (elapsedHours / halfLifeHours)`.
  /// Entries consumed after [targetTime] contribute 0.0 mg, and entries older
  /// than [maxDecayHorizonHours] are treated as negligible (0.0 mg).
  static double residualFromEntryAt({
    required CaffeineEntry entry,
    required DateTime targetTime,
    double halfLifeHours = defaultHalfLifeHours,
  }) {
    if (entry.caffeineMg <= 0) return 0.0;
    if (targetTime.isBefore(entry.consumedAt)) return 0.0;

    final elapsedSeconds = targetTime.difference(entry.consumedAt).inSeconds;
    if (elapsedSeconds == 0) return entry.caffeineMg.toDouble();

    final elapsedHours = elapsedSeconds / 3600.0;
    if (elapsedHours >= maxDecayHorizonHours) return 0.0;

    final safeHalfLife = halfLifeHours <= 0 ? defaultHalfLifeHours : halfLifeHours;
    return (entry.caffeineMg * math.pow(0.5, elapsedHours / safeHalfLife))
        .toDouble();
  }

  /// Sums remaining caffeine (mg) across all [entries] at [targetTime].
  static double totalResidualAt({
    required Iterable<CaffeineEntry> entries,
    required DateTime targetTime,
    double halfLifeHours = defaultHalfLifeHours,
  }) {
    var total = 0.0;
    for (final entry in entries) {
      total += residualFromEntryAt(
        entry: entry,
        targetTime: targetTime,
        halfLifeHours: halfLifeHours,
      );
    }
    return total;
  }

  /// Returns entries consumed on the local calendar date matching [day],
  /// sorted newest first.
  static List<CaffeineEntry> entriesForDay({
    required Iterable<CaffeineEntry> entries,
    required DateTime day,
  }) {
    final result = entries.where((e) {
      return e.consumedAt.year == day.year &&
          e.consumedAt.month == day.month &&
          e.consumedAt.day == day.day;
    }).toList();
    result.sort((a, b) => b.consumedAt.compareTo(a.consumedAt));
    return result;
  }

  /// Sums raw intake mg logged on the calendar date matching [day].
  static int totalConsumedForDay({
    required Iterable<CaffeineEntry> entries,
    required DateTime day,
  }) {
    var total = 0;
    for (final entry in entries) {
      if (entry.consumedAt.year == day.year &&
          entry.consumedAt.month == day.month &&
          entry.consumedAt.day == day.day) {
        total += entry.caffeineMg;
      }
    }
    return total;
  }

  /// Estimates the first timestamp at or after [fromTime] when residual caffeine
  /// drops to or below [targetThresholdMg].
  ///
  /// Returns `null` if residual caffeine is already at or below [targetThresholdMg].
  static DateTime? estimateClearTime({
    required Iterable<CaffeineEntry> entries,
    required DateTime fromTime,
    double targetThresholdMg = 25.0,
    double halfLifeHours = defaultHalfLifeHours,
  }) {
    final activeNow = totalResidualAt(
      entries: entries,
      targetTime: fromTime,
      halfLifeHours: halfLifeHours,
    );
    if (activeNow <= targetThresholdMg) return null;

    const step = Duration(minutes: 15);
    final maxSteps = maxDecayHorizonHours * 4;
    var cursor = fromTime;
    for (var i = 1; i <= maxSteps; i++) {
      cursor = fromTime.add(step * i);
      final residual = totalResidualAt(
        entries: entries,
        targetTime: cursor,
        halfLifeHours: halfLifeHours,
      );
      if (residual <= targetThresholdMg) {
        return cursor;
      }
    }
    return cursor;
  }

  /// Builds evenly spaced decay projection points between [startTime] and [endTime].
  static List<CaffeineProjectionPoint> buildDecayCurve({
    required Iterable<CaffeineEntry> entries,
    required DateTime startTime,
    required DateTime endTime,
    Duration step = const Duration(hours: 1),
    double halfLifeHours = defaultHalfLifeHours,
  }) {
    if (endTime.isBefore(startTime)) return const [];
    final safeStep = step.inMinutes <= 0 ? const Duration(hours: 1) : step;
    final points = <CaffeineProjectionPoint>[];

    var cursor = startTime;
    while (!cursor.isAfter(endTime)) {
      points.add(
        CaffeineProjectionPoint(
          time: cursor,
          residualMg: totalResidualAt(
            entries: entries,
            targetTime: cursor,
            halfLifeHours: halfLifeHours,
          ),
        ),
      );
      cursor = cursor.add(safeStep);
    }

    if (points.isEmpty || points.last.time.isBefore(endTime)) {
      points.add(
        CaffeineProjectionPoint(
          time: endTime,
          residualMg: totalResidualAt(
            entries: entries,
            targetTime: endTime,
            halfLifeHours: halfLifeHours,
          ),
        ),
      );
    }
    return points;
  }

  /// Resolves the afternoon curfew cutoff time for [referenceDate].
  ///
  /// When [CaffeineConfig.syncCurfewWithBedtime] is enabled and [targetBedtime]
  /// is supplied, places the curfew [CaffeineConfig.bedtimeCutOffLeadHours] before
  /// [targetBedtime]; otherwise uses [config.curfewHour]:[config.curfewMinute].
  static DateTime resolveCurfewTimeForDate({
    required CaffeineConfig config,
    required DateTime referenceDate,
    DateTime? targetBedtime,
  }) {
    if (config.syncCurfewWithBedtime && targetBedtime != null) {
      return targetBedtime.subtract(
        Duration(hours: config.bedtimeCutOffLeadHours),
      );
    }
    return DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
      config.curfewHour,
      config.curfewMinute,
    );
  }

  /// Evaluates whether residual caffeine at bedtime is sleep-friendly.
  static CaffeineSleepImpact evaluateImpact(
    double residualMg, {
    int safeThresholdMg = 50,
  }) {
    if (residualMg < 25.0) return CaffeineSleepImpact.clear;
    if (residualMg <= safeThresholdMg) return CaffeineSleepImpact.mild;
    if (residualMg <= math.max(100.0, safeThresholdMg * 2.0)) {
      return CaffeineSleepImpact.moderate;
    }
    return CaffeineSleepImpact.elevated;
  }

  /// Returns whether [now] is currently at or past today's curfew cutoff.
  static bool isPastCurfew({
    required CaffeineConfig config,
    required DateTime now,
    DateTime? targetBedtime,
  }) {
    final curfew = resolveCurfewTimeForDate(
      config: config,
      referenceDate: now,
      targetBedtime: targetBedtime,
    );
    return !now.isBefore(curfew);
  }
}
