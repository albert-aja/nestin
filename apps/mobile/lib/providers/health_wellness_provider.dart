import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/models/daily_health_activity.dart';
import '../data/models/sleep_log.dart';
import '../data/models/vital_log.dart';
import '../data/models/wearable_source.dart';
import '../data/models/wearable_sync_record.dart';
import '../data/services/notification_service.dart';
import '../data/services/storage_service.dart';

class HealthWellnessProvider extends ChangeNotifier {
  final StorageService _storageService;
  final NotificationService? _notificationService;

  static const int moveReminderNotificationId = 7250;

  List<SleepLog> _sleepLogs = [];
  Map<String, DailyHealthActivity> _activities = {};
  List<VitalLog> _vitalLogs = [];
  HealthGoalsConfig _goals = const HealthGoalsConfig();

  HealthWellnessProvider(
    this._storageService, [
    this._notificationService,
  ]) {
    _loadFromStorage();
  }

  List<SleepLog> get sleepLogs => List.unmodifiable(_sleepLogs);
  List<VitalLog> get vitalLogs => List.unmodifiable(_vitalLogs);
  HealthGoalsConfig get goals => _goals;

  SleepLog? get latestSleepLog =>
      _sleepLogs.isNotEmpty ? _sleepLogs.first : null;

  DailyHealthActivity get todayActivity => activityForDate(DateTime.now());

  static String dateKeyFor(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _loadFromStorage() {
    _sleepLogs = _storageService.loadSleepLogs()
      ..sort((a, b) => b.wakeTime.compareTo(a.wakeTime));
    _activities = _storageService.loadDailyHealthActivities();
    _vitalLogs = _storageService.loadVitalLogs()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    _goals = _storageService.loadHealthGoals();
  }

  Future<void> _saveSleep() async {
    await _storageService.saveSleepLogs(_sleepLogs);
    notifyListeners();
  }

  Future<void> _saveActivities() async {
    await _storageService.saveDailyHealthActivities(_activities);
    notifyListeners();
  }

  Future<void> _saveVitals() async {
    await _storageService.saveVitalLogs(_vitalLogs);
    notifyListeners();
  }

  DailyHealthActivity activityForDate(DateTime date) {
    final key = dateKeyFor(date);
    return _activities[key] ?? DailyHealthActivity.emptyForDate(key, _goals);
  }

  Future<void> _updateActivity(
    DateTime date,
    DailyHealthActivity Function(DailyHealthActivity current) transform,
  ) async {
    final key = dateKeyFor(date);
    final current =
        _activities[key] ?? DailyHealthActivity.emptyForDate(key, _goals);
    _activities[key] = transform(current).copyWith(updatedAt: DateTime.now());
    await _saveActivities();
  }

  // --- Step & Movement Tracking ---

  Future<void> addSteps(
    int deltaSteps, {
    int? activeMinutesDelta,
    DateTime? date,
  }) async {
    if (deltaSteps == 0) return;
    final targetDate = date ?? DateTime.now();
    final inferredActiveMins =
        activeMinutesDelta ?? (deltaSteps > 0 ? deltaSteps ~/ 110 : 0);

    await _updateActivity(targetDate, (current) {
      final nextSteps = (current.steps + deltaSteps).clamp(0, 500000);
      final nextActive =
          (current.activeMinutes + inferredActiveMins).clamp(0, 1440);
      return current.copyWith(
        steps: nextSteps,
        activeMinutes: nextActive,
        stepGoal: _goals.dailyStepGoal,
        activeMinutesGoal: _goals.dailyActiveMinutesGoal,
        mindfulMinutesGoal: _goals.dailyMindfulMinutesGoal,
      );
    });
  }

  Future<void> setStepsForDate(int steps, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    await _updateActivity(
      targetDate,
      (current) => current.copyWith(
        steps: steps.clamp(0, 500000),
        stepGoal: _goals.dailyStepGoal,
      ),
    );
  }

  Future<void> addActiveMinutes(int minutes, {DateTime? date}) async {
    if (minutes == 0) return;
    final targetDate = date ?? DateTime.now();
    await _updateActivity(
      targetDate,
      (current) => current.copyWith(
        activeMinutes: (current.activeMinutes + minutes).clamp(0, 1440),
        activeMinutesGoal: _goals.dailyActiveMinutesGoal,
      ),
    );
  }

  Future<void> addMindfulMinutes(int minutes, {DateTime? date}) async {
    if (minutes <= 0) return;
    final targetDate = date ?? DateTime.now();
    await _updateActivity(
      targetDate,
      (current) => current.copyWith(
        mindfulMinutes: (current.mindfulMinutes + minutes).clamp(0, 1440),
        mindfulMinutesGoal: _goals.dailyMindfulMinutesGoal,
      ),
    );
  }

  Future<void> setEnergyScore(int score, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    await _updateActivity(
      targetDate,
      (current) => current.copyWith(energyScore: score.clamp(1, 5)),
    );
  }

  // --- Sleep Tracking ---

  SleepLog? sleepLogForDate(DateTime date) {
    final key = dateKeyFor(date);
    for (final log in _sleepLogs) {
      if (log.dateKey == key) return log;
    }
    return null;
  }

  Future<SleepLog> logSleepSession({
    required DateTime bedtime,
    required DateTime wakeTime,
    SleepQualityRating? qualityRating,
    int? qualityScore,
    int? deepMinutes,
    int? remMinutes,
    int? lightMinutes,
    int awakeMinutes = 0,
    List<String> factors = const [],
    String? notes,
    bool fromWearable = false,
  }) async {
    final normalizedWake = wakeTime.isAfter(bedtime)
        ? wakeTime
        : wakeTime.add(const Duration(days: 1));
    final durationMinutes =
        normalizedWake.difference(bedtime).inMinutes.clamp(1, 1440);

    final estimated = SleepLog.estimateSleepStages(durationMinutes);
    final resolvedDeep = deepMinutes ?? estimated.deep;
    final resolvedRem = remMinutes ?? estimated.rem;
    final resolvedLight = lightMinutes ?? estimated.light;

    final computedScore = qualityScore ??
        SleepLog.computeQualityScore(
          durationMinutes: durationMinutes,
          targetMinutes: _goals.sleepTargetMinutes,
          awakeMinutes: awakeMinutes,
          rating: qualityRating,
        );

    final resolvedRating =
        qualityRating ?? SleepQualityRating.fromScore(computedScore);
    final key = dateKeyFor(normalizedWake);

    final entry = SleepLog(
      id: 'sleep_${const Uuid().v4().substring(0, 8)}',
      dateKey: key,
      bedtime: bedtime,
      wakeTime: normalizedWake,
      durationMinutes: durationMinutes,
      deepMinutes: resolvedDeep,
      remMinutes: resolvedRem,
      lightMinutes: resolvedLight,
      awakeMinutes: awakeMinutes,
      qualityScore: computedScore,
      qualityRating: resolvedRating,
      factors: List<String>.from(factors),
      notes: notes?.trim().isNotEmpty == true ? notes!.trim() : null,
      fromWearable: fromWearable,
      createdAt: DateTime.now(),
    );

    if (fromWearable) {
      _sleepLogs.removeWhere((s) => s.dateKey == key && s.fromWearable);
    }

    _sleepLogs.insert(0, entry);
    _sleepLogs.sort((a, b) => b.wakeTime.compareTo(a.wakeTime));
    await _saveSleep();
    return entry;
  }

  Future<void> deleteSleepLog(String id) async {
    _sleepLogs.removeWhere((s) => s.id == id);
    await _saveSleep();
  }

  // --- Vitals Tracking ---

  VitalLog? latestVitalOfType(VitalType type) {
    for (final v in _vitalLogs) {
      if (v.type == type) return v;
    }
    return null;
  }

  Future<VitalLog> logVital({
    required VitalType type,
    required double primaryValue,
    double? secondaryValue,
    String? note,
    bool fromWearable = false,
    DateTime? recordedAt,
  }) async {
    final timestamp = recordedAt ?? DateTime.now();
    final entry = VitalLog(
      id: 'vital_${const Uuid().v4().substring(0, 8)}',
      type: type,
      primaryValue: primaryValue,
      secondaryValue: secondaryValue,
      note: note?.trim().isNotEmpty == true ? note!.trim() : null,
      fromWearable: fromWearable,
      recordedAt: timestamp,
    );

    _vitalLogs.insert(0, entry);
    _vitalLogs.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    await _saveVitals();

    if (type == VitalType.heartRate) {
      await _updateActivity(
        timestamp,
        (current) => current.copyWith(restingHeartRate: primaryValue.round()),
      );
    } else if (type == VitalType.bloodOxygen) {
      await _updateActivity(
        timestamp,
        (current) =>
            current.copyWith(bloodOxygenPercent: primaryValue.round()),
      );
    }

    return entry;
  }

  Future<void> deleteVitalLog(String id) async {
    _vitalLogs.removeWhere((v) => v.id == id);
    await _saveVitals();
  }

  // --- Goals & Move Reminders ---

  Future<void> updateGoals(HealthGoalsConfig newGoals) async {
    _goals = newGoals;
    await _storageService.saveHealthGoals(_goals);

    final todayKey = dateKeyFor(DateTime.now());
    if (_activities.containsKey(todayKey)) {
      _activities[todayKey] = _activities[todayKey]!.copyWith(
        stepGoal: _goals.dailyStepGoal,
        activeMinutesGoal: _goals.dailyActiveMinutesGoal,
        mindfulMinutesGoal: _goals.dailyMindfulMinutesGoal,
        updatedAt: DateTime.now(),
      );
      await _storageService.saveDailyHealthActivities(_activities);
    }

    await _syncMoveReminder();
    notifyListeners();
  }

  Future<void> _syncMoveReminder() async {
    final notif = _notificationService;
    if (notif == null) return;

    await notif.cancel(moveReminderNotificationId);
    if (!_goals.moveReminderEnabled) return;

    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, 15, 0);
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }

    await notif.scheduleWellnessNotification(
      id: moveReminderNotificationId,
      title: '🌿 Seren — Gentle Movement Stretch',
      body:
          'Time for a mindful 5-minute walk! Check your daily step progress toward ${_goals.dailyStepGoal} steps.',
      scheduledDate: target,
      payload: 'seren_health_move',
    );
  }

  // --- Wearable Integration Bridge ---

  Future<void> ingestWearableRecord(WearableSyncRecord record) async {
    if (!record.isSyncSuccess) return;
    final syncDate = record.syncedAt;

    if (record.stepCount != null && record.stepCount! > 0) {
      await _updateActivity(syncDate, (current) {
        final mergedSteps = record.stepCount! > current.steps
            ? record.stepCount!
            : current.steps;
        final inferredActive = mergedSteps ~/ 180;
        final mergedActive = current.activeMinutes > inferredActive
            ? current.activeMinutes
            : inferredActive;
        return current.copyWith(
          steps: mergedSteps,
          activeMinutes: mergedActive,
          stepGoal: _goals.dailyStepGoal,
          restingHeartRate:
              record.restingHeartRate ?? current.restingHeartRate,
          syncedFromWearable: true,
        );
      });
    } else if (record.restingHeartRate != null) {
      await _updateActivity(
        syncDate,
        (current) => current.copyWith(
          restingHeartRate: record.restingHeartRate,
          syncedFromWearable: true,
        ),
      );
    }

    if (record.sleepMinutes != null && record.sleepMinutes! > 0) {
      final wake = record.sleepEndTime ?? syncDate;
      final bed = record.sleepStartTime ??
          wake.subtract(Duration(minutes: record.sleepMinutes!));
      await logSleepSession(
        bedtime: bed,
        wakeTime: wake,
        qualityScore: record.sleepQualityPercent,
        qualityRating: record.sleepQualityPercent != null
            ? SleepQualityRating.fromScore(record.sleepQualityPercent!)
            : null,
        notes: record.notes,
        fromWearable: true,
      );
    }

    if (record.restingHeartRate != null && record.restingHeartRate! > 0) {
      final latestHr = latestVitalOfType(VitalType.heartRate);
      final isDuplicateRecent = latestHr != null &&
          latestHr.fromWearable &&
          latestHr.primaryValue.round() == record.restingHeartRate &&
          syncDate.difference(latestHr.recordedAt).inMinutes.abs() < 60;
      if (!isDuplicateRecent) {
        await logVital(
          type: VitalType.heartRate,
          primaryValue: record.restingHeartRate!.toDouble(),
          note: 'Synced from ${record.platform.shortName}',
          fromWearable: true,
          recordedAt: syncDate,
        );
      }
    }
  }

  // --- 7-Day Trend Analytics ---

  List<DateTime> getWeeklyDates([DateTime? referenceDate]) {
    final ref = referenceDate ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
  }

  List<DailyHealthActivity> getWeeklyActivities([DateTime? referenceDate]) {
    return getWeeklyDates(referenceDate).map(activityForDate).toList();
  }

  int get weeklyTotalSteps =>
      getWeeklyActivities().fold(0, (sum, a) => sum + a.steps);

  int get weeklyAverageSteps => (weeklyTotalSteps / 7.0).round();

  int get weeklyStepGoalsMetCount =>
      getWeeklyActivities().where((a) => a.isStepGoalMet).length;

  int get stepStreakDays {
    int streak = 0;
    final today = DateTime.now();
    for (int i = 0; i < 60; i++) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: i));
      final activity = activityForDate(day);
      if (activity.isStepGoalMet) {
        streak++;
      } else if (i == 0) {
        // Today hasn't finished yet; preserve streak from yesterday onward
        continue;
      } else {
        break;
      }
    }
    return streak;
  }

  List<SleepLog?> getWeeklySleepLogs([DateTime? referenceDate]) {
    return getWeeklyDates(referenceDate).map(sleepLogForDate).toList();
  }

  int get weeklyAverageSleepMinutes {
    final logged = getWeeklySleepLogs().whereType<SleepLog>().toList();
    if (logged.isEmpty) return 0;
    final total = logged.fold(0, (sum, l) => sum + l.durationMinutes);
    return (total / logged.length).round();
  }

  int get weeklyAverageSleepScore {
    final logged = getWeeklySleepLogs().whereType<SleepLog>().toList();
    if (logged.isEmpty) return 0;
    final total = logged.fold(0, (sum, l) => sum + l.qualityScore);
    return (total / logged.length).round();
  }

  int get weeklySleepDebtMinutes {
    final logged = getWeeklySleepLogs().whereType<SleepLog>().toList();
    return logged.fold(
      0,
      (sum, l) => sum + l.sleepDebtMinutes(_goals.sleepTargetMinutes),
    );
  }

  int get sleepTargetStreakDays {
    int streak = 0;
    final today = DateTime.now();
    for (int i = 0; i < 60; i++) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: i));
      final log = sleepLogForDate(day);
      if (log != null && log.meetsTarget(_goals.sleepTargetMinutes)) {
        streak++;
      } else if (i == 0 && log == null) {
        continue;
      } else {
        break;
      }
    }
    return streak;
  }

  // --- Composite Seren Wellness Score (0 - 100) ---

  int computeDailyWellnessScore({
    double hydrationFraction = 0.0,
    DateTime? date,
  }) {
    final targetDate = date ?? DateTime.now();
    final activity = activityForDate(targetDate);
    final sleep = sleepLogForDate(targetDate);

    final stepsPts = activity.stepProgress * 35.0;
    final sleepFraction = sleep != null && _goals.sleepTargetMinutes > 0
        ? (sleep.durationMinutes / _goals.sleepTargetMinutes).clamp(0.0, 1.0)
        : 0.0;
    final sleepPts = sleepFraction * 35.0;
    final hydrationPts = hydrationFraction.clamp(0.0, 1.0) * 15.0;
    final movementPts = activity.activeMinutesProgress * 10.0;
    final mindfulPts = activity.mindfulProgress * 5.0;

    return (stepsPts + sleepPts + hydrationPts + movementPts + mindfulPts)
        .round()
        .clamp(0, 100);
  }

  String wellnessInsight({
    double hydrationFraction = 0.0,
    DateTime? date,
  }) {
    final targetDate = date ?? DateTime.now();
    final activity = activityForDate(targetDate);
    final sleep = sleepLogForDate(targetDate);

    if (sleep == null) {
      return 'Log last night\'s sleep so Seren can track your restorative REM cycles.';
    }
    if (sleep.sleepDebtMinutes(_goals.sleepTargetMinutes) > 60) {
      return 'You were ${sleep.sleepDebtMinutes(_goals.sleepTargetMinutes)}m shy of your sleep target. Consider an earlier 30m wind-down tonight.';
    }
    if (!activity.isStepGoalMet && activity.remainingSteps <= 1500) {
      return 'Only ${activity.remainingSteps} steps left to reach your ${_goals.dailyStepGoal} daily goal — a short walk will finish it!';
    }
    if (hydrationFraction < 0.5) {
      return 'Great movement pace! Pair your walk with a refreshing glass of water.';
    }
    if (activity.mindfulMinutes == 0) {
      return 'Take 2 minutes for Seren\'s 4-7-8 breathing exercise to calm your nervous system.';
    }
    return 'Balanced rhythm across sleep, steps, hydration, and calm today! 🌿';
  }
}
