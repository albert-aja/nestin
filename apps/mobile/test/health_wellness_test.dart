import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/data/models/daily_health_activity.dart';
import 'package:nestin/data/models/sleep_log.dart';
import 'package:nestin/data/models/vital_log.dart';
import 'package:nestin/data/models/wearable_source.dart';
import 'package:nestin/data/models/wearable_sync_record.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/health_wellness_provider.dart';
import 'package:nestin/providers/hydration_provider.dart';
import 'package:nestin/ui/widgets/health_wellness_sheet.dart';
import 'package:nestin/ui/widgets/seren_wellness_summary_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => true,
    );
  });

  group('SleepLog Model Tests', () {
    test('Formats duration, cycles, efficiency and stages accurately', () {
      final wake = DateTime(2026, 11, 14, 6, 45);
      final bed = DateTime(2026, 11, 13, 23, 15);
      final stages = SleepLog.estimateSleepStages(450);

      expect(stages.deep + stages.rem + stages.light, equals(450));

      final log = SleepLog(
        id: 'sleep_1',
        dateKey: '2026-11-14',
        bedtime: bed,
        wakeTime: wake,
        durationMinutes: 450,
        deepMinutes: stages.deep,
        remMinutes: stages.rem,
        lightMinutes: stages.light,
        awakeMinutes: 15,
        qualityScore: 89,
        qualityRating: SleepQualityRating.restorative,
        factors: const ['Wind-Down Audio', 'Low Screen'],
        notes: 'Slept deeply after rain sound',
        createdAt: wake,
      );

      expect(log.formattedDuration, equals('7h 30m'));
      expect(log.completedCycles, equals(5));
      expect(log.meetsTarget(450), isTrue);
      expect(log.sleepDebtMinutes(480), equals(30));
      expect(log.sleepEfficiencyPercent, equals(97));
    });

    test('JSON serialization roundtrip preserves SleepLog fields', () {
      final now = DateTime(2026, 11, 14, 7, 0);
      final bed = now.subtract(const Duration(hours: 8));
      final original = SleepLog(
        id: 's_json',
        dateKey: '2026-11-14',
        bedtime: bed,
        wakeTime: now,
        durationMinutes: 480,
        deepMinutes: 96,
        remMinutes: 120,
        lightMinutes: 264,
        awakeMinutes: 10,
        qualityScore: 93,
        qualityRating: SleepQualityRating.excellent,
        factors: const ['No Late Caffeine'],
        notes: 'Woke up refreshed',
        fromWearable: true,
        createdAt: now,
      );

      final restored = SleepLog.fromJson(original.toJson());
      expect(restored.id, equals(original.id));
      expect(restored.durationMinutes, equals(480));
      expect(restored.deepMinutes, equals(96));
      expect(restored.remMinutes, equals(120));
      expect(restored.lightMinutes, equals(264));
      expect(restored.qualityRating, equals(SleepQualityRating.excellent));
      expect(restored.factors, contains('No Late Caffeine'));
      expect(restored.fromWearable, isTrue);
    });
  });

  group('DailyHealthActivity & VitalLog Model Tests', () {
    test('Step distance, active calories and goal progress compute accurately',
        () {
      final act = DailyHealthActivity(
        dateKey: '2026-11-14',
        steps: 8000,
        stepGoal: 8000,
        activeMinutes: 35,
        activeMinutesGoal: 30,
        mindfulMinutes: 5,
        mindfulMinutesGoal: 10,
        updatedAt: DateTime.now(),
      );

      expect(act.isStepGoalMet, isTrue);
      expect(act.stepProgress, equals(1.0));
      expect(act.remainingSteps, equals(0));
      expect(act.distanceKm, closeTo(6.096, 0.001));
      expect(act.estimatedActiveCalories, equals((8000 * 0.04).round() + 35 * 4));
      expect(act.isActiveGoalMet, isTrue);
      expect(act.mindfulProgress, closeTo(0.5, 0.001));
    });

    test('Zero division guards on DailyHealthActivity', () {
      final zeroAct = DailyHealthActivity(
        dateKey: '2026-11-14',
        steps: 0,
        stepGoal: 0,
        activeMinutesGoal: 0,
        mindfulMinutesGoal: 0,
        updatedAt: DateTime.now(),
      );

      expect(zeroAct.stepProgress, equals(0.0));
      expect(zeroAct.activeMinutesProgress, equals(0.0));
      expect(zeroAct.mindfulProgress, equals(0.0));
      expect(zeroAct.distanceKm, equals(0.0));
    });

    test('VitalLog formats readings and status labels properly', () {
      final now = DateTime.now();
      final hr = VitalLog(
        id: 'v1',
        type: VitalType.heartRate,
        primaryValue: 62,
        recordedAt: now,
      );
      expect(hr.formattedValue, equals('62 bpm'));
      expect(hr.statusLabel, equals('Normal Resting'));

      final bp = VitalLog(
        id: 'v2',
        type: VitalType.bloodPressure,
        primaryValue: 116,
        secondaryValue: 74,
        recordedAt: now,
      );
      expect(bp.formattedValue, equals('116/74 mmHg'));
      expect(bp.statusLabel, equals('Normal'));

      final spo2 = VitalLog(
        id: 'v3',
        type: VitalType.bloodOxygen,
        primaryValue: 98,
        recordedAt: now,
      );
      expect(spo2.formattedValue, equals('98 %'));
      expect(spo2.statusLabel, equals('Optimal SpO2'));

      final wt = VitalLog(
        id: 'v4',
        type: VitalType.bodyWeight,
        primaryValue: 68.4,
        recordedAt: now,
      );
      expect(wt.formattedValue, equals('68.4 kg'));

      final restoredBp = VitalLog.fromJson(bp.toJson());
      expect(restoredBp.primaryValue, equals(116));
      expect(restoredBp.secondaryValue, equals(74));
    });
  });

  group('HealthWellnessProvider State, Sync & Analytics Tests', () {
    late StorageService storage;
    late NotificationService notif;
    late HealthWellnessProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = StorageService(prefs);
      notif = NotificationService();
      provider = HealthWellnessProvider(storage, notif);
    });

    test('Step additions, custom steps, and multi-day streaks work cleanly',
        () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      await provider.setStepsForDate(8500, date: twoDaysAgo);
      await provider.setStepsForDate(9100, date: yesterday);
      // Today still 0 -> streak from yesterday should stay 2
      expect(provider.stepStreakDays, equals(2));

      await provider.addSteps(1000);
      expect(provider.todayActivity.steps, equals(1000));
      expect(provider.todayActivity.activeMinutes, equals(9)); // 1000 ~/ 110

      await provider.addSteps(7500);
      expect(provider.todayActivity.steps, equals(8500));
      expect(provider.todayActivity.isStepGoalMet, isTrue);
      expect(provider.stepStreakDays, equals(3));
    });

    test('Sleep logging handles midnight crossing, sleep debt and deletion',
        () async {
      final wake = DateTime.now();
      final bed = wake.subtract(const Duration(hours: 6, minutes: 30)); // 390m

      final logged = await provider.logSleepSession(
        bedtime: bed,
        wakeTime: wake,
        qualityRating: SleepQualityRating.good,
        factors: const ['Evening Walk'],
        notes: 'Quiet night',
      );

      expect(logged.durationMinutes, equals(390));
      expect(logged.deepMinutes + logged.remMinutes + logged.lightMinutes,
          equals(390));
      expect(provider.latestSleepLog?.id, equals(logged.id));
      expect(provider.weeklyAverageSleepMinutes, equals(390));
      // Target is 450m -> 60m debt
      expect(provider.weeklySleepDebtMinutes, equals(60));

      await provider.deleteSleepLog(logged.id);
      expect(provider.sleepLogs, isEmpty);
    });

    test('Vitals logging updates activity cache and computes Wellness Score',
        () async {
      await provider.logVital(
        type: VitalType.heartRate,
        primaryValue: 60,
        note: 'Morning pulse',
      );
      expect(provider.todayActivity.restingHeartRate, equals(60));

      await provider.addSteps(8000);
      await provider.addActiveMinutes(30);
      await provider.addMindfulMinutes(10);

      final wake = DateTime.now();
      await provider.logSleepSession(
        bedtime: wake.subtract(const Duration(hours: 7, minutes: 30)),
        wakeTime: wake,
      );

      final fullScore =
          provider.computeDailyWellnessScore(hydrationFraction: 1.0);
      expect(fullScore, equals(100));
    });

    test('Wearable ingestion updates steps, sleep, and deduplicates recent HR',
        () async {
      final now = DateTime.now();
      final record = WearableSyncRecord(
        platform: WearablePlatform.appleHealth,
        syncedAt: now,
        sleepStartTime: now.subtract(const Duration(hours: 8)),
        sleepEndTime: now,
        sleepMinutes: 480,
        sleepQualityPercent: 91,
        stepCount: 6420,
        restingHeartRate: 59,
      );

      await provider.ingestWearableRecord(record);
      await provider.ingestWearableRecord(record); // Repeated sync within 60m

      expect(provider.todayActivity.steps, equals(6420));
      expect(provider.todayActivity.syncedFromWearable, isTrue);
      expect(provider.todayActivity.restingHeartRate, equals(59));
      expect(provider.sleepLogs.length, equals(1));
      expect(provider.sleepLogs.first.fromWearable, isTrue);
      expect(provider.vitalLogs.length, equals(1));
    });

    test('Full JSON backup export and restore preserves Seren health data',
        () async {
      await provider.addSteps(4200);
      await provider.logVital(type: VitalType.bloodOxygen, primaryValue: 99);
      final wake = DateTime.now();
      await provider.logSleepSession(
        bedtime: wake.subtract(const Duration(hours: 7)),
        wakeTime: wake,
      );
      await provider.updateGoals(
        const HealthGoalsConfig(dailyStepGoal: 10000, sleepTargetMinutes: 480),
      );

      final backupJson = storage.exportFullBackupJson();
      expect(backupJson, contains('"sleepLogs"'));
      expect(backupJson, contains('"dailyHealthActivities"'));
      expect(backupJson, contains('"vitalLogs"'));
      expect(backupJson, contains('"healthGoals"'));

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final freshStorage = StorageService(prefs);
      expect(freshStorage.loadSleepLogs(), isEmpty);

      final ok = await freshStorage.restoreFullBackupJson(backupJson);
      expect(ok, isTrue);

      final restoredProvider = HealthWellnessProvider(freshStorage, notif);
      expect(restoredProvider.todayActivity.steps, equals(4200));
      expect(restoredProvider.sleepLogs.length, equals(1));
      expect(restoredProvider.vitalLogs.length, equals(1));
      expect(restoredProvider.goals.dailyStepGoal, equals(10000));
    });
  });

  group('Seren Health Widget Tests', () {
    late StorageService storage;
    late NotificationService notif;
    late HealthWellnessProvider healthProvider;
    late HydrationProvider hydrationProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = StorageService(prefs);
      notif = NotificationService();
      healthProvider = HealthWellnessProvider(storage, notif);
      hydrationProvider = HydrationProvider(storage, notif);
    });

    testWidgets('SerenWellnessSummaryCard shows metrics and increments steps',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<HealthWellnessProvider>.value(
                  value: healthProvider,
                ),
                ChangeNotifierProvider<HydrationProvider>.value(
                  value: hydrationProvider,
                ),
              ],
              child: const SingleChildScrollView(
                child: SerenWellnessSummaryCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Seren Health & Activity'), findsOneWidget);
      expect(find.text('Daily Steps'), findsOneWidget);
      expect(find.text('Last Sleep'), findsOneWidget);
      expect(find.text('Vitals & Calm'), findsOneWidget);

      await tester.tap(find.text('+1,000 Steps'));
      await tester.pumpAndSettle();

      expect(healthProvider.todayActivity.steps, equals(1000));
      expect(find.text('1,000'), findsOneWidget);
    });

    testWidgets('HealthWellnessSheet switches tabs and updates all modules',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<HealthWellnessProvider>.value(
                  value: healthProvider,
                ),
                ChangeNotifierProvider<HydrationProvider>.value(
                  value: hydrationProvider,
                ),
              ],
              child: const HealthWellnessSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Seren Health Sanctuary'), findsOneWidget);

      // Tab 1: Steps quick increment
      await tester.tap(find.text('+500 Steps'));
      await tester.pumpAndSettle();
      expect(healthProvider.todayActivity.steps, equals(500));

      // Tab 2: Sleep empty prompt
      await tester.tap(find.text('Sleep'));
      await tester.pumpAndSettle();
      expect(find.text('No sleep sessions recorded yet'), findsOneWidget);

      // Tab 3: Vitals energy selector & record dialog
      await tester.tap(find.text('Vitals'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('⚡ Good'));
      await tester.pumpAndSettle();
      expect(healthProvider.todayActivity.energyScore, equals(4));

      await tester.tap(find.text('Record Vital Reading'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();
      expect(healthProvider.vitalLogs.length, equals(1));
      expect(find.text('64 bpm'), findsWidgets);

      // Tab 4: Breathe mode & mindful quick log
      await tester.tap(find.text('Breathe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Guided Breathing'));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Stop & Save Mindful Minutes'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('+5m Calm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+5m Calm'));
      await tester.pumpAndSettle();
      expect(healthProvider.todayActivity.mindfulMinutes, equals(5));
    });
  });
}

