import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/data/models/hydration_data.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/providers/hydration_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock notifications channel so plugin calls succeed in test environment
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dexterous.com/flutter/local_notifications'),
    (call) async => true,
  );

  late StorageService storageService;
  late NotificationService notificationService;
  late HydrationProvider hydrationProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
    notificationService = NotificationService();
    hydrationProvider = HydrationProvider(storageService, notificationService);
  });

  group('HydrationData Model Tests', () {
    test('Default values initialize to 8 glasses, 90m interval, 8 AM to 9 PM', () {
      final data = HydrationData.initial(DateTime(2026, 11, 12, 10, 0));
      expect(data.glassesConsumed, 0);
      expect(data.dailyGoalGlasses, 8);
      expect(data.remindersEnabled, true);
      expect(data.reminderIntervalMinutes, 90);
      expect(data.startHour, 8);
      expect(data.endHour, 21);
      expect(data.currentMilliliters, 0);
      expect(data.targetMilliliters, 2000);
      expect(data.isGoalMet, false);
      expect(data.progressFraction, 0.0);
    });

    test('Progress calculations accurately clamp and report goal completion', () {
      final data = HydrationData(
        glassesConsumed: 4,
        dailyGoalGlasses: 8,
        lastLoggedDate: '2026-11-12',
      );
      expect(data.currentMilliliters, 1000);
      expect(data.progressFraction, 0.5);
      expect(data.isGoalMet, false);

      final fullData = data.copyWith(glassesConsumed: 8);
      expect(fullData.currentMilliliters, 2000);
      expect(fullData.progressFraction, 1.0);
      expect(fullData.isGoalMet, true);

      final overData = data.copyWith(glassesConsumed: 10);
      expect(overData.progressFraction, 1.0);
      expect(overData.isGoalMet, true);
    });

    test('JSON serialization roundtrip preserves all hydration settings', () {
      final original = HydrationData(
        glassesConsumed: 5,
        dailyGoalGlasses: 10,
        remindersEnabled: true,
        reminderIntervalMinutes: 60,
        startHour: 7,
        endHour: 22,
        lastLoggedDate: '2026-11-12',
      );

      final json = original.toJson();
      final restored = HydrationData.fromJson(json);

      expect(restored.glassesConsumed, original.glassesConsumed);
      expect(restored.dailyGoalGlasses, original.dailyGoalGlasses);
      expect(restored.remindersEnabled, original.remindersEnabled);
      expect(restored.reminderIntervalMinutes, original.reminderIntervalMinutes);
      expect(restored.startHour, original.startHour);
      expect(restored.endHour, original.endHour);
      expect(restored.lastLoggedDate, original.lastLoggedDate);
    });
  });

  group('Hydration Reminder Schedule Calculation Tests', () {
    test('Calculates exact 9 reminder slots between 8:00 AM and 9:00 PM for 90m interval', () {
      final testDay = DateTime(2026, 11, 12, 7, 0); // 7:00 AM
      final slots = hydrationProvider.calculateReminderSlots(testDay);

      expect(slots.length, 9);
      expect(slots[0], DateTime(2026, 11, 12, 8, 0));
      expect(slots[1], DateTime(2026, 11, 12, 9, 30));
      expect(slots[2], DateTime(2026, 11, 12, 11, 0));
      expect(slots[3], DateTime(2026, 11, 12, 12, 30));
      expect(slots[4], DateTime(2026, 11, 12, 14, 0));
      expect(slots[5], DateTime(2026, 11, 12, 15, 30));
      expect(slots[6], DateTime(2026, 11, 12, 17, 0));
      expect(slots[7], DateTime(2026, 11, 12, 18, 30));
      expect(slots[8], DateTime(2026, 11, 12, 20, 0));
    });

    test('Upcoming reminder slots filter out past time slots', () {
      final midDay = DateTime(2026, 11, 12, 13, 0); // 1:00 PM
      final upcoming = hydrationProvider.getUpcomingReminderSlots(midDay);

      // Remaining slots should be 14:00, 15:30, 17:00, 18:30, 20:00 (5 slots)
      expect(upcoming.length, 5);
      expect(upcoming.first, DateTime(2026, 11, 12, 14, 0));
      expect(upcoming.last, DateTime(2026, 11, 12, 20, 0));
    });

    test('Upcoming slots return empty when daily goal is reached', () async {
      await hydrationProvider.addGlass(8);
      expect(hydrationProvider.isGoalMet, true);

      final midDay = DateTime(2026, 11, 12, 13, 0);
      final upcoming = hydrationProvider.getUpcomingReminderSlots(midDay);
      expect(upcoming, isEmpty);
    });

    test('Upcoming slots return empty when reminders are disabled', () async {
      await hydrationProvider.toggleReminders(false);
      expect(hydrationProvider.remindersEnabled, false);

      final midDay = DateTime(2026, 11, 12, 13, 0);
      final upcoming = hydrationProvider.getUpcomingReminderSlots(midDay);
      expect(upcoming, isEmpty);
    });
  });

  group('HydrationProvider State & Persistence Tests', () {
    test('Add glass increments consumed count and persists to storage', () async {
      expect(hydrationProvider.glassesConsumed, 0);
      await hydrationProvider.addGlass();
      expect(hydrationProvider.glassesConsumed, 1);
      expect(hydrationProvider.currentMilliliters, 250);

      // Verify persistence
      final reloaded = storageService.loadHydrationData();
      expect(reloaded.glassesConsumed, 1);
    });

    test('Remove glass decrements count and clamps at zero', () async {
      await hydrationProvider.addGlass(2);
      expect(hydrationProvider.glassesConsumed, 2);

      await hydrationProvider.removeGlass(1);
      expect(hydrationProvider.glassesConsumed, 1);

      await hydrationProvider.removeGlass(5);
      expect(hydrationProvider.glassesConsumed, 0);
    });

    test('Daily rollover resets glasses count on new date', () {
      hydrationProvider.addGlass(4);
      expect(hydrationProvider.glassesConsumed, 4);

      // Simulate next day
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final didRollover = hydrationProvider.checkDailyRollover(tomorrow);

      expect(didRollover, true);
      expect(hydrationProvider.glassesConsumed, 0);
      expect(hydrationProvider.isGoalMet, false);
      expect(hydrationProvider.dailyHistory.isNotEmpty, true);
    });

    test('7-Day Sparkline weekly intake and consistency calculations work accurately', () async {
      final now = DateTime(2026, 11, 13);
      final data = HydrationData(
        glassesConsumed: 8,
        dailyGoalGlasses: 8,
        lastLoggedDate: '2026-11-13',
        dailyHistory: {
          '2026-11-07': 8, // Met
          '2026-11-08': 6, // Below
          '2026-11-09': 8, // Met
          '2026-11-10': 10, // Met
          '2026-11-11': 4, // Below
          '2026-11-12': 8, // Met
          '2026-11-13': 8, // Met
        },
      );

      final weeklyDates = data.getWeeklyDates(now);
      expect(weeklyDates.length, 7);
      expect(weeklyDates.last.day, 13);
      expect(weeklyDates.first.day, 7);

      final weeklyGlasses = data.getWeeklyGlasses(now);
      expect(weeklyGlasses, [8, 6, 8, 10, 4, 8, 8]);

      final weeklyMl = data.getWeeklyMilliliters(now);
      expect(weeklyMl, [2000, 1500, 2000, 2500, 1000, 2000, 2000]);

      // 5 of 7 days met (Nov 7, 9, 10, 12, 13)
      final daysMet = data.getWeeklyDaysMetCount(now);
      expect(daysMet, 5);

      final consistencyPct = data.getWeeklyConsistencyPercentage(now);
      expect(consistencyPct.round(), 71);

      final avgMl = data.getWeeklyAverageMilliliters(now);
      expect(avgMl, (13000 / 7).round());

      expect(data.getWeeklyConsistencyLabel(now), contains('Good Consistency'));
      expect(data.getWeeklyInsight(now), contains('Outstanding hydration habit'));
    });

    test('Full JSON backup and restore includes hydration data', () async {
      await hydrationProvider.addGlass(6);
      await hydrationProvider.setDailyGoal(10);
      await hydrationProvider.updateSchedule(intervalMinutes: 120);

      final backupJson = storageService.exportFullBackupJson();
      expect(backupJson.contains('hydrationData'), true);
      expect(backupJson.contains('"glassesConsumed":6'), true);
      expect(backupJson.contains('"dailyGoalGlasses":10'), true);
      expect(backupJson.contains('"reminderIntervalMinutes":120'), true);

      // Reset prefs and restore
      SharedPreferences.setMockInitialValues({});
      final newPrefs = await SharedPreferences.getInstance();
      final newStorage = StorageService(newPrefs);

      final success = await newStorage.restoreFullBackupJson(backupJson);
      expect(success, true);

      final restoredData = newStorage.loadHydrationData();
      expect(restoredData.glassesConsumed, 6);
      expect(restoredData.dailyGoalGlasses, 10);
      expect(restoredData.reminderIntervalMinutes, 120);
    });
  });
}

