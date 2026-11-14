import 'package:flutter/foundation.dart';
import '../data/models/caffeine_data.dart';
import '../data/services/notification_service.dart';
import '../data/services/storage_service.dart';
import '../domain/sleep/caffeine_calculator.dart';

/// Seren Wellness provider tracking daily caffeine & stimulant intake,
/// ~5-hour half-life pharmacokinetic decay to tonight's target bedtime,
/// and customizable afternoon curfew nudges.
class CaffeineProvider extends ChangeNotifier {
  static const int curfewNotificationId = 7280;
  static const int _retentionDays = 14;

  final StorageService _storageService;
  final NotificationService _notificationService;

  List<CaffeineEntry> _entries = [];
  CaffeineConfig _config = CaffeineConfig.initial();
  DateTime? _lastScheduledCurfew;

  CaffeineProvider(this._storageService, this._notificationService) {
    _load();
  }

  List<CaffeineEntry> get entries => List.unmodifiable(_entries);
  CaffeineConfig get config => _config;
  DateTime? get lastScheduledCurfew => _lastScheduledCurfew;

  bool get curfewEnabled => _config.curfewEnabled;
  double get halfLifeHours => _config.halfLifeHours;
  int get dailyLimitMg => _config.dailyLimitMg;
  int get bedtimeSafeThresholdMg => _config.bedtimeSafeThresholdMg;

  void _load() {
    _entries = _storageService.loadCaffeineEntries()
      ..sort((a, b) => b.consumedAt.compareTo(a.consumedAt));
    _config = _storageService.loadCaffeineConfig();
    if (_config.curfewEnabled) {
      syncCurfewNotification();
    }
    notifyListeners();
  }

  /// Entries consumed today (local calendar day), sorted newest first.
  List<CaffeineEntry> entriesForDay(DateTime day) =>
      CaffeineCalculator.entriesForDay(entries: _entries, day: day);

  List<CaffeineEntry> get todayEntries => entriesForDay(DateTime.now());

  /// Total raw caffeine (mg) logged on [day].
  int totalConsumedForDay(DateTime day) =>
      CaffeineCalculator.totalConsumedForDay(entries: _entries, day: day);

  int get todayTotalMg => totalConsumedForDay(DateTime.now());

  /// Fraction of [dailyLimitMg] consumed today (0.0 to 1.0+).
  double get todayLimitRatio =>
      _config.dailyLimitMg > 0 ? todayTotalMg / _config.dailyLimitMg : 0.0;

  /// Active residual caffeine (mg) in body at [targetTime].
  double residualAt(DateTime targetTime) => CaffeineCalculator.totalResidualAt(
        entries: _entries,
        targetTime: targetTime,
        halfLifeHours: _config.halfLifeHours,
      );

  double residualNow({DateTime? now}) => residualAt(now ?? DateTime.now());

  /// Qualitative sleep-impact bucket at [targetTime].
  CaffeineSleepImpact impactAt(DateTime targetTime) =>
      CaffeineCalculator.evaluateImpact(
        residualAt(targetTime),
        safeThresholdMg: _config.bedtimeSafeThresholdMg,
      );

  /// Estimated timestamp when active caffeine drops below [thresholdMg] (default 25 mg).
  DateTime? estimatedClearTime({
    DateTime? fromTime,
    double thresholdMg = 25.0,
  }) {
    return CaffeineCalculator.estimateClearTime(
      entries: _entries,
      fromTime: fromTime ?? DateTime.now(),
      targetThresholdMg: thresholdMg,
      halfLifeHours: _config.halfLifeHours,
    );
  }

  /// Builds decay projection points from [startTime] through [endTime].
  List<CaffeineProjectionPoint> buildDecayCurve({
    required DateTime startTime,
    required DateTime endTime,
    Duration step = const Duration(hours: 1),
  }) {
    return CaffeineCalculator.buildDecayCurve(
      entries: _entries,
      startTime: startTime,
      endTime: endTime,
      step: step,
      halfLifeHours: _config.halfLifeHours,
    );
  }

  /// Resolves the active afternoon curfew cutoff timestamp for [referenceDate].
  DateTime resolvedCurfewTime({
    DateTime? referenceDate,
    DateTime? targetBedtime,
  }) {
    return CaffeineCalculator.resolveCurfewTimeForDate(
      config: _config,
      referenceDate: referenceDate ?? DateTime.now(),
      targetBedtime: targetBedtime,
    );
  }

  bool isPastCurfew({DateTime? now, DateTime? targetBedtime}) =>
      CaffeineCalculator.isPastCurfew(
        config: _config,
        now: now ?? DateTime.now(),
        targetBedtime: targetBedtime,
      );

  /// Logs a caffeine serving using a preset [StimulantType] or custom dose.
  Future<CaffeineEntry> logDrink({
    required StimulantType type,
    int? caffeineMg,
    String? label,
    DateTime? consumedAt,
    String? note,
    bool isIndonesian = false,
  }) async {
    final timestamp = consumedAt ?? DateTime.now();
    final safeMg = (caffeineMg ?? type.defaultMg).clamp(1, 1000);
    final entry = CaffeineEntry(
      id: 'caf_${timestamp.microsecondsSinceEpoch}_${_entries.length}',
      type: type,
      label: (label != null && label.trim().isNotEmpty)
          ? label.trim()
          : type.localizedName(isIndonesian: isIndonesian),
      caffeineMg: safeMg,
      consumedAt: timestamp,
      note: note?.trim().isEmpty ?? true ? null : note?.trim(),
    );

    _entries.insert(0, entry);
    _sortAndPrune();
    await _storageService.saveCaffeineEntries(_entries);
    notifyListeners();
    return entry;
  }

  Future<void> updateEntry(CaffeineEntry updated) async {
    final idx = _entries.indexWhere((e) => e.id == updated.id);
    if (idx == -1) return;
    _entries[idx] = updated;
    _sortAndPrune();
    await _storageService.saveCaffeineEntries(_entries);
    notifyListeners();
  }

  Future<void> deleteEntry(String id) async {
    final before = _entries.length;
    _entries.removeWhere((e) => e.id == id);
    if (_entries.length == before) return;
    await _storageService.saveCaffeineEntries(_entries);
    notifyListeners();
  }

  Future<void> clearDayEntries(DateTime day) async {
    _entries.removeWhere(
      (e) =>
          e.consumedAt.year == day.year &&
          e.consumedAt.month == day.month &&
          e.consumedAt.day == day.day,
    );
    await _storageService.saveCaffeineEntries(_entries);
    notifyListeners();
  }

  Future<void> updateConfig(
    CaffeineConfig newConfig, {
    DateTime? targetBedtime,
  }) async {
    _config = newConfig;
    await _storageService.saveCaffeineConfig(_config);
    await syncCurfewNotification(targetBedtime: targetBedtime);
    notifyListeners();
  }

  Future<void> toggleCurfewEnabled(
    bool enabled, {
    DateTime? targetBedtime,
  }) async {
    await updateConfig(
      _config.copyWith(curfewEnabled: enabled),
      targetBedtime: targetBedtime,
    );
  }

  /// Schedules or cancels the daily Seren caffeine curfew notification.
  Future<void> syncCurfewNotification({
    DateTime? targetBedtime,
    DateTime? nowOverride,
  }) async {
    await _notificationService.cancel(curfewNotificationId);
    if (!_config.curfewEnabled) {
      _lastScheduledCurfew = null;
      return;
    }

    final now = nowOverride ?? DateTime.now();
    var candidate = CaffeineCalculator.resolveCurfewTimeForDate(
      config: _config,
      referenceDate: now,
      targetBedtime: targetBedtime,
    );

    if (!candidate.isAfter(now)) {
      final tomorrow = now.add(const Duration(days: 1));
      final nextBedtime = targetBedtime != null && targetBedtime.isAfter(now)
          ? targetBedtime.add(const Duration(days: 1))
          : null;
      candidate = CaffeineCalculator.resolveCurfewTimeForDate(
        config: _config,
        referenceDate: tomorrow,
        targetBedtime: nextBedtime,
      );
    }

    final hh = candidate.hour.toString().padLeft(2, '0');
    final mm = candidate.minute.toString().padLeft(2, '0');
    final activeMg = residualAt(now).round();

    _lastScheduledCurfew = candidate;
    await _notificationService.scheduleWellnessNotification(
      id: curfewNotificationId,
      title: '☕ Seren: Caffeine Curfew ($hh:$mm)',
      body: activeMg > 0
          ? 'Switch to water or herbal tea now (~${activeMg}mg active) so tonight\'s sleep stays deep.'
          : 'Afternoon stimulant cutoff reached! Stick to water or decaf for restful sleep tonight.',
      scheduledDate: candidate,
      payload: 'caffeine_curfew',
    );
  }

  Future<void> testCurfewNudge({DateTime? targetBedtime}) async {
    final now = DateTime.now();
    final activeMg = residualNow(now: now).round();
    final bedResidual = targetBedtime != null
        ? residualAt(targetBedtime).round()
        : activeMg;

    await _notificationService.showWellnessNotification(
      id: curfewNotificationId,
      title: '☕ Seren: Afternoon Caffeine Cutoff',
      body: targetBedtime != null
          ? 'Estimated ~${bedResidual}mg at tonight\'s bedtime (${_config.halfLifeHours.toStringAsFixed(1)}h half-life). Switch to water or decaf!'
          : 'Curfew at ${_config.formattedCurfewTime} active (~${activeMg}mg in system). Protect tonight\'s REM sleep!',
      payload: 'caffeine_curfew',
    );
  }

  void _sortAndPrune() {
    final cutoff = DateTime.now().subtract(const Duration(days: _retentionDays));
    _entries.removeWhere((e) => e.consumedAt.isBefore(cutoff));
    _entries.sort((a, b) => b.consumedAt.compareTo(a.consumedAt));
  }
}
