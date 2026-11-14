import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/l10n/app_language.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/alarm.dart';
import 'package:nestin/data/models/caffeine_data.dart';
import 'package:nestin/data/services/ambient_sound_service.dart';
import 'package:nestin/data/services/audio_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/domain/sleep/caffeine_calculator.dart';
import 'package:nestin/providers/alarm_provider.dart';
import 'package:nestin/providers/caffeine_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/providers/sleep_wellness_provider.dart';
import 'package:nestin/ui/widgets/caffeine_summary_card.dart';
import 'package:nestin/ui/widgets/caffeine_tracker_sheet.dart';
import 'package:nestin/ui/widgets/sleep_cycle_sheet.dart';

class ScheduledWellnessCall {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledDate;
  final String? payload;

  ScheduledWellnessCall({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledDate,
    this.payload,
  });
}

class ShownWellnessCall {
  final int id;
  final String title;
  final String body;
  final String? payload;

  ShownWellnessCall({
    required this.id,
    required this.title,
    required this.body,
    this.payload,
  });
}

class RecordingNotificationService extends NotificationService {
  final List<ScheduledWellnessCall> scheduledCalls = [];
  final List<ShownWellnessCall> shownCalls = [];
  final List<int> cancelledIds = [];

  @override
  Future<void> scheduleWellnessNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    scheduledCalls.add(
      ScheduledWellnessCall(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        payload: payload,
      ),
    );
  }

  @override
  Future<void> showWellnessNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    shownCalls.add(
      ShownWellnessCall(
        id: id,
        title: title,
        body: body,
        payload: payload,
      ),
    );
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
  }
}

class _FakeAmbientSoundService extends AmbientSoundService {
  @override
  AmbientSoundType get currentType => AmbientSoundType.none;

  @override
  double get volume => 0.5;

  @override
  bool get isPlaying => false;

  @override
  Future<void> play(AmbientSoundType type, {double? volume}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setVolume(double vol) async {}

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dexterous.com/flutter/local_notifications'),
    (call) async => true,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    (call) async => 1,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (call) async => 1,
  );

  late StorageService storageService;
  late RecordingNotificationService notificationService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
    notificationService = RecordingNotificationService();
  });

  group('CaffeineCalculator half-life decay math', () {
    test('exact ~5-hour half-life decay at 0h, 5h, 10h, and 15h', () {
      final t0 = DateTime(2026, 11, 14, 9, 0);
      final entry = CaffeineEntry(
        id: 'e1',
        type: StimulantType.custom,
        label: 'Test Dose',
        caffeineMg: 100,
        consumedAt: t0,
      );

      expect(
        CaffeineCalculator.residualFromEntryAt(entry: entry, targetTime: t0),
        closeTo(100.0, 0.01),
      );
      expect(
        CaffeineCalculator.residualFromEntryAt(
          entry: entry,
          targetTime: t0.add(const Duration(hours: 5)),
        ),
        closeTo(50.0, 0.01),
      );
      expect(
        CaffeineCalculator.residualFromEntryAt(
          entry: entry,
          targetTime: t0.add(const Duration(hours: 10)),
        ),
        closeTo(25.0, 0.01),
      );
      expect(
        CaffeineCalculator.residualFromEntryAt(
          entry: entry,
          targetTime: t0.add(const Duration(hours: 15)),
        ),
        closeTo(12.5, 0.01),
      );
      // Future consumption contributes zero prior to intake
      expect(
        CaffeineCalculator.residualFromEntryAt(
          entry: entry,
          targetTime: t0.subtract(const Duration(minutes: 10)),
        ),
        0.0,
      );
    });

    test('superposition of multiple drinks and clearance ETA', () {
      final morningCoffee = CaffeineEntry(
        id: 'c1',
        type: StimulantType.coffee,
        label: 'Coffee',
        caffeineMg: 95,
        consumedAt: DateTime(2026, 11, 14, 8, 0),
      );
      final afternoonMatcha = CaffeineEntry(
        id: 'm1',
        type: StimulantType.matcha,
        label: 'Matcha',
        caffeineMg: 70,
        consumedAt: DateTime(2026, 11, 14, 13, 0),
      );

      final bedtime = DateTime(2026, 11, 14, 22, 30);
      // Elapsed: coffee = 14.5h, matcha = 9.5h
      final residual = CaffeineCalculator.totalResidualAt(
        entries: [morningCoffee, afternoonMatcha],
        targetTime: bedtime,
      );

      // 95 * 0.5^(14.5/5) + 70 * 0.5^(9.5/5) ~= 12.73 + 18.75 = 31.48 mg
      expect(residual, closeTo(31.48, 0.5));
      expect(
        CaffeineCalculator.evaluateImpact(residual),
        CaffeineSleepImpact.mild,
      );

      final clearAt = CaffeineCalculator.estimateClearTime(
        entries: [morningCoffee, afternoonMatcha],
        fromTime: DateTime(2026, 11, 14, 14, 0),
        targetThresholdMg: 25.0,
      );
      expect(clearAt, isNotNull);
      expect(clearAt!.isAfter(bedtime), isTrue);
    });

    test('curfew resolution supports fixed time and sleep-relative lead hours', () {
      const fixedCfg = CaffeineConfig(
        curfewEnabled: true,
        curfewHour: 14,
        curfewMinute: 30,
        syncCurfewWithBedtime: false,
      );
      final ref = DateTime(2026, 11, 14, 10, 0);
      final fixedCurfew = CaffeineCalculator.resolveCurfewTimeForDate(
        config: fixedCfg,
        referenceDate: ref,
      );
      expect(fixedCurfew, DateTime(2026, 11, 14, 14, 30));

      final syncedCfg = fixedCfg.copyWith(
        syncCurfewWithBedtime: true,
        bedtimeCutOffLeadHours: 8,
      );
      final bedtime = DateTime(2026, 11, 14, 22, 15);
      final syncedCurfew = CaffeineCalculator.resolveCurfewTimeForDate(
        config: syncedCfg,
        referenceDate: ref,
        targetBedtime: bedtime,
      );
      expect(syncedCurfew, DateTime(2026, 11, 14, 14, 15));
    });
  });

  group('StorageService persistence & full backup roundtrip', () {
    test('saves, loads, exports, and restores caffeine entries and config', () async {
      final entry = CaffeineEntry(
        id: 'caf_1',
        type: StimulantType.espresso,
        label: 'Espresso',
        caffeineMg: 63,
        consumedAt: DateTime(2026, 11, 14, 9, 15),
      );
      const config = CaffeineConfig(
        curfewEnabled: true,
        curfewHour: 13,
        curfewMinute: 45,
        dailyLimitMg: 300,
        halfLifeHours: 5.0,
      );

      await storageService.saveCaffeineEntries([entry]);
      await storageService.saveCaffeineConfig(config);

      final backupJson = storageService.exportFullBackupJson();

      // Clear prefs and restore backup
      SharedPreferences.setMockInitialValues({});
      final freshPrefs = await SharedPreferences.getInstance();
      final freshStorage = StorageService(freshPrefs);
      expect(freshStorage.loadCaffeineEntries(), isEmpty);

      final ok = await freshStorage.restoreFullBackupJson(backupJson);
      expect(ok, isTrue);

      final restoredEntries = freshStorage.loadCaffeineEntries();
      final restoredConfig = freshStorage.loadCaffeineConfig();
      expect(restoredEntries.length, 1);
      expect(restoredEntries.first.id, 'caf_1');
      expect(restoredEntries.first.type, StimulantType.espresso);
      expect(restoredEntries.first.caffeineMg, 63);
      expect(restoredConfig.curfewHour, 13);
      expect(restoredConfig.curfewMinute, 45);
      expect(restoredConfig.dailyLimitMg, 300);
    });
  });

  group('CaffeineProvider state & curfew scheduling', () {
    test('quick-log, delete, residual calculation, and curfew notification sync', () async {
      final provider = CaffeineProvider(storageService, notificationService);

      await provider.logDrink(
        type: StimulantType.coffee,
        consumedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      await provider.logDrink(
        type: StimulantType.tea,
        consumedAt: DateTime.now(),
      );

      expect(provider.todayEntries.length, 2);
      expect(provider.todayTotalMg, 95 + 45);
      expect(provider.residualNow(), greaterThan(100.0));

      final bedtime = DateTime.now().add(const Duration(hours: 8));
      expect(provider.residualAt(bedtime), lessThan(provider.residualNow()));

      // Update curfew and ensure notification ID 7280 is scheduled
      notificationService.scheduledCalls.clear();
      notificationService.cancelledIds.clear();
      await provider.updateConfig(
        provider.config.copyWith(curfewEnabled: true, curfewHour: 15, curfewMinute: 0),
        targetBedtime: bedtime,
      );
      expect(notificationService.cancelledIds, contains(CaffeineProvider.curfewNotificationId));
      expect(notificationService.scheduledCalls.length, 1);
      expect(
        notificationService.scheduledCalls.single.id,
        CaffeineProvider.curfewNotificationId,
      );
      expect(notificationService.scheduledCalls.single.scheduledDate.hour, 15);

      // Disable curfew cancels notification without rescheduling
      notificationService.scheduledCalls.clear();
      await provider.toggleCurfewEnabled(false);
      expect(notificationService.scheduledCalls, isEmpty);

      // Delete first entry
      final toDelete = provider.todayEntries.first.id;
      await provider.deleteEntry(toDelete);
      expect(provider.todayEntries.length, 1);

      // Instant test nudge uses wellness notification channel
      await provider.testCurfewNudge(targetBedtime: bedtime);
      expect(notificationService.shownCalls.length, 1);
      expect(
        notificationService.shownCalls.single.id,
        CaffeineProvider.curfewNotificationId,
      );
    });
  });

  group('Caffeine Tracker Widget Integration & Bilingual UI', () {
    Future<Widget> buildTestHarness({
      required Widget child,
      AppLanguage language = AppLanguage.en,
      ThemeMode themeMode = ThemeMode.dark,
      List<Alarm> alarms = const [],
    }) async {
      final caffeineProvider =
          CaffeineProvider(storageService, notificationService);
      final sleepWellnessProvider = SleepWellnessProvider(
        storageService,
        notificationService,
        _FakeAmbientSoundService(),
      );
      final settingsProvider = SettingsProvider(storageService);
      await settingsProvider.setLanguage(language);
      await settingsProvider.setThemeMode(themeMode);

      if (alarms.isNotEmpty) {
        await storageService.saveAlarms(alarms);
      }

      return MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>(
            create: (_) => settingsProvider,
          ),
          ChangeNotifierProvider<CaffeineProvider>(
            create: (_) => caffeineProvider,
          ),
          ChangeNotifierProvider<SleepWellnessProvider>(
            create: (_) => sleepWellnessProvider,
          ),
          ChangeNotifierProvider<AlarmProvider>(
            create: (_) =>
                AlarmProvider(storageService, AudioService(), notificationService),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          locale: language.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('CaffeineSummaryCard quick-logs Matcha and switches cleanly to Indonesian', (tester) async {
      final app = await buildTestHarness(
        language: AppLanguage.id,
        themeMode: ThemeMode.light,
        child: const SingleChildScrollView(child: CaffeineSummaryCard()),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(find.text('Kafein & Batas Sore'), findsOneWidget);
      expect(find.text('Hari ini: 0mg'), findsOneWidget);

      await tester.tap(find.text('Matcha 70'));
      await tester.pumpAndSettle();

      expect(find.text('Hari ini: 70mg'), findsOneWidget);
    });

    testWidgets('CaffeineTrackerSheet logs drink with -1h offset and configures 8h curfew', (tester) async {
      final app = await buildTestHarness(
        language: AppLanguage.en,
        themeMode: ThemeMode.light,
        child: const CaffeineTrackerSheet(),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(find.text('Caffeine & Cutoff Tracker'), findsOneWidget);
      expect(find.text('Half-Life Decay Curve'), findsOneWidget);

      // Pick -1h time offset and log Espresso
      await tester.ensureVisible(find.text('-1h'));
      await tester.tap(find.text('-1h'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Espresso • 63mg'));
      await tester.tap(find.text('Espresso • 63mg'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text("Today's Drinks (1)"));
      expect(find.text("Today's Drinks (1)"), findsOneWidget);

      // Enable bedtime-synced 8h cutoff preset
      await tester.ensureVisible(find.text('8h Before Bed'));
      await tester.tap(find.text('8h Before Bed'));
      await tester.pumpAndSettle();
      expect(find.textContaining('8h before bed'), findsOneWidget);
    });

    testWidgets('SleepCycleSheet displays live CaffeineBedtimeBanner', (tester) async {
      final now = DateTime.now();
      final caffeine = CaffeineProvider(storageService, notificationService);
      await caffeine.logDrink(
        type: StimulantType.coffee,
        caffeineMg: 95,
        consumedAt: now.subtract(const Duration(hours: 1)),
      );

      final sleepWellness = SleepWellnessProvider(
        storageService,
        notificationService,
        _FakeAmbientSoundService(),
      );
      final settingsProvider = SettingsProvider(storageService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>(create: (_) => settingsProvider),
            ChangeNotifierProvider<CaffeineProvider>(create: (_) => caffeine),
            ChangeNotifierProvider<SleepWellnessProvider>(
                create: (_) => sleepWellness),
            ChangeNotifierProvider<AlarmProvider>(
              create: (_) =>
                  AlarmProvider(storageService, AudioService(), notificationService),
            ),
          ],
          child: const MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(body: SleepCycleSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Caffeine at Bedtime'), findsOneWidget);
      expect(find.textContaining('95mg logged today'), findsOneWidget);
    });
  });
}
