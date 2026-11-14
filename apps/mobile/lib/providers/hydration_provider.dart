import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/models/hydration_data.dart';
import '../data/services/storage_service.dart';
import '../data/services/notification_service.dart';

class HydrationProvider extends ChangeNotifier {
  final StorageService _storageService;
  final NotificationService _notificationService;

  late HydrationData _data;
  HydrationData get data => _data;

  // Base notification ID range for hydration schedule (7100 - 7125)
  static const int baseNotificationId = 7100;
  static const int maxSlots = 20;

  HydrationProvider(this._storageService, this._notificationService) {
    _load();
  }

  void _load() {
    _data = _storageService.loadHydrationData();
    checkDailyRollover();
    _syncReminderSchedule();
  }

  // Getters for convenient UI access
  int get glassesConsumed => _data.glassesConsumed;
  int get dailyGoalGlasses => _data.dailyGoalGlasses;
  int get currentMilliliters => _data.currentMilliliters;
  int get targetMilliliters => _data.targetMilliliters;
  bool get remindersEnabled => _data.remindersEnabled;
  int get reminderIntervalMinutes => _data.reminderIntervalMinutes;
  int get startHour => _data.startHour;
  int get endHour => _data.endHour;
  bool get isGoalMet => _data.isGoalMet;
  double get progressFraction => _data.progressFraction;
  Map<String, int> get dailyHistory => _data.dailyHistory;

  // 7-Day Sparkline Analytics Getters
  List<DateTime> get weeklyDates => _data.getWeeklyDates();
  List<int> get weeklyGlasses => _data.getWeeklyGlasses();
  List<int> get weeklyMilliliters => _data.getWeeklyMilliliters();
  int get weeklyDaysMetCount => _data.getWeeklyDaysMetCount();
  double get weeklyConsistencyPercentage =>
      _data.getWeeklyConsistencyPercentage();
  int get weeklyAverageMilliliters => _data.getWeeklyAverageMilliliters();
  String get weeklyConsistencyLabel => _data.getWeeklyConsistencyLabel();
  String get weeklyInsight => _data.getWeeklyInsight();

  /// Check if calendar date changed since last log; if so, reset daily count
  bool checkDailyRollover([DateTime? currentTime]) {
    final now = currentTime ?? DateTime.now();
    final todayStr = now.toIso8601String().substring(0, 10);

    if (_data.lastLoggedDate != todayStr) {
      final updatedHistory = Map<String, int>.from(_data.dailyHistory);
      updatedHistory[_data.lastLoggedDate] = _data.glassesConsumed;
      updatedHistory.putIfAbsent(todayStr, () => 0);

      _data = _data.copyWith(
        glassesConsumed: 0,
        lastLoggedDate: todayStr,
        dailyHistory: updatedHistory,
      );
      _storageService.saveHydrationData(_data);
      _syncReminderSchedule(now);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Increment consumed glasses (1 glass = 250ml)
  Future<void> addGlass([int count = 1]) async {
    checkDailyRollover();
    final updatedGlasses = _data.glassesConsumed + count;
    final previouslyMet = _data.isGoalMet;
    final updatedHistory = Map<String, int>.from(_data.dailyHistory);
    updatedHistory[_data.lastLoggedDate] = updatedGlasses;

    _data = _data.copyWith(
      glassesConsumed: updatedGlasses,
      dailyHistory: updatedHistory,
    );
    await _storageService.saveHydrationData(_data);

    // If goal newly reached, cancel remaining reminder notifications for today
    if (!previouslyMet && _data.isGoalMet) {
      await cancelAllReminders();
    }

    notifyListeners();
  }

  /// Decrement consumed glasses (min 0)
  Future<void> removeGlass([int count = 1]) async {
    checkDailyRollover();
    final updatedGlasses = max(0, _data.glassesConsumed - count);
    final previouslyMet = _data.isGoalMet;
    final updatedHistory = Map<String, int>.from(_data.dailyHistory);
    updatedHistory[_data.lastLoggedDate] = updatedGlasses;

    _data = _data.copyWith(
      glassesConsumed: updatedGlasses,
      dailyHistory: updatedHistory,
    );
    await _storageService.saveHydrationData(_data);

    // If dropped back below goal and reminders enabled, restore schedule
    if (previouslyMet && !_data.isGoalMet && _data.remindersEnabled) {
      await _syncReminderSchedule();
    }

    notifyListeners();
  }

  /// Record specific historical date intake (for testing / manual adjustments)
  Future<void> recordHistoricalIntake(String dateStr, int glasses) async {
    final updatedHistory = Map<String, int>.from(_data.dailyHistory);
    updatedHistory[dateStr] = max(0, glasses);
    _data = _data.copyWith(dailyHistory: updatedHistory);
    await _storageService.saveHydrationData(_data);
    notifyListeners();
  }

  /// Update daily target (glasses, e.g. 6 to 16)
  Future<void> setDailyGoal(int goalGlasses) async {
    final clamped = goalGlasses.clamp(1, 20);
    _data = _data.copyWith(dailyGoalGlasses: clamped);
    await _storageService.saveHydrationData(_data);
    await _syncReminderSchedule();
    notifyListeners();
  }

  /// Toggle scheduled periodic reminders
  Future<void> toggleReminders(bool enabled) async {
    _data = _data.copyWith(remindersEnabled: enabled);
    await _storageService.saveHydrationData(_data);

    if (enabled && !_data.isGoalMet) {
      await _syncReminderSchedule();
    } else {
      await cancelAllReminders();
    }

    notifyListeners();
  }

  /// Update reminder timing parameters (interval, start hour, end hour)
  Future<void> updateSchedule({
    int? intervalMinutes,
    int? startHour,
    int? endHour,
  }) async {
    _data = _data.copyWith(
      reminderIntervalMinutes: intervalMinutes ?? _data.reminderIntervalMinutes,
      startHour: startHour ?? _data.startHour,
      endHour: endHour ?? _data.endHour,
    );
    await _storageService.saveHydrationData(_data);
    await _syncReminderSchedule();
    notifyListeners();
  }

  /// Calculate all reminder time slots between startHour and endHour
  List<DateTime> calculateReminderSlots([DateTime? baseDate]) {
    final now = baseDate ?? DateTime.now();
    final List<DateTime> slots = [];

    DateTime current = DateTime(
      now.year,
      now.month,
      now.day,
      _data.startHour,
      0,
    );

    final endLimit = DateTime(
      now.year,
      now.month,
      now.day,
      _data.endHour,
      0,
    );

    while (!current.isAfter(endLimit)) {
      slots.add(current);
      current = current.add(Duration(minutes: _data.reminderIntervalMinutes));
    }

    return slots;
  }

  /// Get list of upcoming reminder slots remaining today
  List<DateTime> getUpcomingReminderSlots([DateTime? baseDate]) {
    if (!_data.remindersEnabled || _data.isGoalMet) return [];
    final now = baseDate ?? DateTime.now();
    return calculateReminderSlots(now).where((slot) => slot.isAfter(now)).toList();
  }

  /// Earliest upcoming reminder slot today, or null if goal met or no more slots today
  DateTime? get nextReminderTime {
    final upcoming = getUpcomingReminderSlots();
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  /// Cancel all scheduled hydration notifications
  Future<void> cancelAllReminders() async {
    for (int i = 0; i < maxSlots; i++) {
      await _notificationService.cancel(baseNotificationId + i);
    }
  }

  /// Synchronize scheduled notifications based on current goal progress & time
  Future<void> _syncReminderSchedule([DateTime? currentTime]) async {
    final now = currentTime ?? DateTime.now();

    // If disabled or goal met, cancel everything
    if (!_data.remindersEnabled || _data.isGoalMet) {
      await cancelAllReminders();
      return;
    }

    // Cancel old slots first to avoid stale notifications
    await cancelAllReminders();

    final allSlots = calculateReminderSlots(now);
    int slotIndex = 0;

    for (final slot in allSlots) {
      if (slot.isAfter(now) && slotIndex < maxSlots) {
        await _notificationService.scheduleWellnessNotification(
          id: baseNotificationId + slotIndex,
          title: '💧 Seren — Hydration Reminder',
          body:
              'Time for a sip! Drink a fresh glass of water (250ml) to stay refreshed. Progress: ${_data.glassesConsumed}/${_data.dailyGoalGlasses} glasses.',
          scheduledDate: slot,
        );
        slotIndex++;
      }
    }
  }

  /// Test instant notification preview for user
  Future<void> testSendReminderNow() async {
    await _notificationService.showWellnessNotification(
      id: 7099,
      title: '💧 Seren — Hydration Reminder',
      body:
          'Time for a sip! Drink a fresh glass of water (250ml) to stay refreshed. Progress: ${_data.glassesConsumed}/${_data.dailyGoalGlasses} glasses.',
    );
  }
}

