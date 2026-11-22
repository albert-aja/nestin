import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/l10n/app_language.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/before_you_go.dart';
import 'package:nestin/data/models/location_reminder.dart';
import 'package:nestin/data/models/medication_item.dart';
import 'package:nestin/data/models/money_category.dart';
import 'package:nestin/data/models/reading_item.dart';
import 'package:nestin/data/models/routine_item.dart';
import 'package:nestin/data/models/saved_place.dart';
import 'package:nestin/data/models/vital_log.dart';
import 'package:nestin/data/services/ambient_sound_service.dart';
import 'package:nestin/data/services/audio_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/data/services/weather_service.dart';
import 'package:nestin/data/services/widget_sync_service.dart';
import 'package:nestin/domain/money/money_amount.dart';
import 'package:nestin/providers/alarm_provider.dart';
import 'package:nestin/providers/before_you_go_provider.dart';
import 'package:nestin/providers/caffeine_provider.dart';
import 'package:nestin/providers/calendar_provider.dart';
import 'package:nestin/providers/geofence_provider.dart';
import 'package:nestin/providers/health_wellness_provider.dart';
import 'package:nestin/providers/hobby_provider.dart';
import 'package:nestin/providers/hydration_provider.dart';
import 'package:nestin/providers/medication_provider.dart';
import 'package:nestin/providers/money_provider.dart';
import 'package:nestin/providers/reading_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/providers/sleep_wellness_provider.dart';
import 'package:nestin/ui/screens/organize/money/money_budgets_recurring_reports_views.dart';
import 'package:nestin/ui/screens/organize/money/money_transactions_accounts_views.dart';
import 'package:nestin/ui/widgets/before_you_go_sheet.dart';
import 'package:nestin/ui/widgets/health_wellness_sheet.dart';
import 'package:nestin/ui/widgets/hobby_practice_sheet.dart';
import 'package:nestin/ui/widgets/location_reminders_sheet.dart';
import 'package:nestin/ui/widgets/medication_tracker_sheet.dart';
import 'package:nestin/ui/widgets/reading_tracker_sheet.dart';
import 'package:nestin/ui/widgets/sleep_cycle_sheet.dart';

class _FakeAmbientSoundService extends AmbientSoundService {
  AmbientSoundType _type = AmbientSoundType.none;
  double _vol = 0.5;
  bool _playing = false;

  @override
  AmbientSoundType get currentType => _type;

  @override
  double get volume => _vol;

  @override
  bool get isPlaying => _playing;

  @override
  Future<void> play(AmbientSoundType type, {double? volume}) async {
    if (volume != null) _vol = volume;
    _type = type;
    _playing = type != AmbientSoundType.none;
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _type = AmbientSoundType.none;
  }

  @override
  Future<void> setVolume(double vol) async {
    _vol = vol.clamp(0.0, 1.0);
  }

  @override
  void dispose() {}
}

class _DeepL10nEnv {
  final StorageService storage;
  final NotificationService notifications;
  final SettingsProvider settings;
  final SleepWellnessProvider sleepWellness;
  final AlarmProvider alarm;
  final MedicationProvider medication;
  final HobbyProvider hobby;
  final HealthWellnessProvider health;
  final ReadingProvider reading;
  final GeofenceProvider geofence;
  final BeforeYouGoProvider beforeYouGo;
  final MoneyProvider money;
  final CaffeineProvider caffeine;
  final CalendarProvider calendar;
  final HydrationProvider hydration;

  _DeepL10nEnv({
    required this.storage,
    required this.notifications,
    required this.settings,
    required this.sleepWellness,
    required this.alarm,
    required this.medication,
    required this.hobby,
    required this.health,
    required this.reading,
    required this.geofence,
    required this.beforeYouGo,
    required this.money,
    required this.caffeine,
    required this.calendar,
    required this.hydration,
  });

  static Future<_DeepL10nEnv> create({
    AppLanguage language = AppLanguage.id,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await AppLocalizations.ensureDateFormatting();
    final storage = await StorageService.init();
    final settings = SettingsProvider(storage);
    await settings.setLanguage(language);
    final notifications = NotificationService();
    final audio = AudioService();
    return _DeepL10nEnv(
      storage: storage,
      notifications: notifications,
      settings: settings,
      sleepWellness: SleepWellnessProvider(
        storage,
        notifications,
        _FakeAmbientSoundService(),
      ),
      alarm: AlarmProvider(storage, audio, notifications),
      medication: MedicationProvider(storage, notifications),
      hobby: HobbyProvider(storage),
      health: HealthWellnessProvider(storage, notifications),
      reading: ReadingProvider(storage, notificationService: notifications),
      geofence: GeofenceProvider(
        storage,
        notifications,
        autoInitializeNative: false,
      ),
      beforeYouGo: BeforeYouGoProvider(storage, notifications),
      money: MoneyProvider(storage),
      caffeine: CaffeineProvider(storage, notifications),
      calendar: CalendarProvider(storage),
      hydration: HydrationProvider(storage, notifications),
    );
  }

  Widget wrap(Widget child) {
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        Provider<NotificationService>.value(value: notifications),
        Provider<WeatherProviderInterface>(
          create: (_) => LocalWeatherService(),
        ),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<SleepWellnessProvider>.value(
          value: sleepWellness,
        ),
        ChangeNotifierProvider<AlarmProvider>.value(value: alarm),
        ChangeNotifierProvider<MedicationProvider>.value(value: medication),
        ChangeNotifierProvider<HobbyProvider>.value(value: hobby),
        ChangeNotifierProvider<HealthWellnessProvider>.value(value: health),
        ChangeNotifierProvider<ReadingProvider>.value(value: reading),
        ChangeNotifierProvider<GeofenceProvider>.value(value: geofence),
        ChangeNotifierProvider<BeforeYouGoProvider>.value(value: beforeYouGo),
        ChangeNotifierProvider<MoneyProvider>.value(value: money),
        ChangeNotifierProvider<CaffeineProvider>.value(value: caffeine),
        ChangeNotifierProvider<CalendarProvider>.value(value: calendar),
        ChangeNotifierProvider<HydrationProvider>.value(value: hydration),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, s, _) => MaterialApp(
          locale: s.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: s.themeMode,
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  void dispose() {
    sleepWellness.dispose();
    alarm.dispose();
    medication.dispose();
    hobby.dispose();
    health.dispose();
    reading.dispose();
    geofence.dispose();
    beforeYouGo.dispose();
    money.dispose();
    caffeine.dispose();
    calendar.dispose();
    hydration.dispose();
    settings.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final recordedNotifCalls = <MethodCall>[];

  setUp(() {
    recordedNotifCalls.clear();
    WidgetSyncService.instance.methodInvoker = (_, _) async => true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async {
        recordedNotifCalls.add(call);
        return true;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (_) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (_) async => 1,
    );
  });

  tearDown(() {
    AppLocalizations.currentLanguage = AppLanguage.en;
    WidgetSyncService.instance.methodInvoker = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      null,
    );
  });

  group('Deep Localization — Models & Default Money Categories', () {
    test('MoneyCurrency & MoneyCategory translate defaults in ID while keeping canonical JSON intact', () {
      final now = DateTime(2026, 11, 14);
      final salary = MoneyCategory(
        id: 'default_inc_salary',
        name: 'Salary',
        type: MoneyCategoryType.income,
        iconCodePoint: 0,
        colorValue: 0xFF10B981,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      );
      final food = MoneyCategory(
        id: 'default_exp_food',
        name: 'Food & Drinks',
        type: MoneyCategoryType.expense,
        iconCodePoint: 0,
        colorValue: 0xFFF59E0B,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      );
      final custom = MoneyCategory(
        id: 'custom_1',
        name: 'Coffee Beans',
        type: MoneyCategoryType.expense,
        iconCodePoint: 0,
        colorValue: 0xFFF59E0B,
        isDefault: false,
        createdAt: now,
        updatedAt: now,
      );

      AppLocalizations.currentLanguage = AppLanguage.en;
      expect(MoneyCurrency.idr.localizedName, 'Indonesian Rupiah');
      expect(MoneyCurrency.usd.localizedName, 'US Dollar');
      expect(MoneyCategoryType.income.label, 'Income');
      expect(MoneyCategoryType.expense.label, 'Expense');
      expect(salary.displayName, 'Salary');
      expect(food.displayName, 'Food & Drinks');
      expect(custom.displayName, 'Coffee Beans');

      AppLocalizations.currentLanguage = AppLanguage.id;
      expect(MoneyCurrency.idr.localizedName, 'Rupiah Indonesia');
      expect(MoneyCurrency.usd.localizedName, 'Dolar AS');
      expect(MoneyCurrency.sgd.localizedName, 'Dolar Singapura');
      expect(MoneyCurrency.jpy.localizedName, 'Yen Jepang');
      expect(MoneyCurrency.idr.displayName, 'Indonesian Rupiah');
      expect(MoneyCategoryType.income.label, 'Pemasukan');
      expect(MoneyCategoryType.expense.label, 'Pengeluaran');
      expect(salary.displayName, 'Gaji');
      expect(food.displayName, 'Makan & Minum');
      expect(custom.displayName, 'Coffee Beans');
      expect(food.name, 'Food & Drinks');
      expect(food.toJson()['name'], 'Food & Drinks');
    });

    test('Wellness, Reading, Location, BeforeYouGo & Routine enum getters switch EN <-> ID', () {
      final now = DateTime(2026, 11, 14);
      final hrLog = VitalLog(
        id: 'v1',
        type: VitalType.heartRate,
        primaryValue: 68,
        recordedAt: now,
      );
      final routine = RoutineItem(
        id: 'r1',
        title: 'Stretch',
        type: RoutineType.morning,
        steps: const ['Neck roll'],
        createdAt: now,
      );

      AppLocalizations.currentLanguage = AppLanguage.en;
      expect(MealInstruction.beforeMeal.label, 'Before Food');
      expect(MealInstruction.afterMeal.shortLabel, 'After meal');
      expect(VitalType.heartRate.label, 'Heart Rate');
      expect(hrLog.statusLabel, 'Normal Resting');
      expect(ReadingStatus.wantToRead.label, 'Want to Read');
      expect(ReadingFormat.book.label, 'Book');
      expect(GeofenceTriggerType.arrive.displayName, 'On Arrival');
      expect(GeofenceTransitionEvent.exit.displayName, 'Departed');
      expect(PlaceCategory.work.displayName, 'Work');
      expect(DepartureRecurrenceType.weekdays.label, 'Mon–Fri');
      expect(routine.typeLabel, 'Morning Routine');

      AppLocalizations.currentLanguage = AppLanguage.id;
      expect(MealInstruction.beforeMeal.label, 'Sebelum Makan');
      expect(MealInstruction.afterMeal.shortLabel, 'Sesudah makan');
      expect(VitalType.heartRate.label, 'Detak Jantung');
      expect(VitalType.bloodPressure.label, 'Tekanan Darah');
      expect(hrLog.statusLabel, 'Istirahat Normal');
      expect(ReadingStatus.wantToRead.label, 'Ingin Dibaca');
      expect(ReadingStatus.currentlyReading.label, 'Sedang Dibaca');
      expect(ReadingFormat.book.label, 'Buku');
      expect(ReadingFormat.article.label, 'Artikel');
      expect(GeofenceTriggerType.arrive.displayName, 'Saat Tiba');
      expect(GeofenceTriggerType.leave.displayName, 'Saat Pergi');
      expect(GeofenceTransitionEvent.exit.displayName, 'Pergi');
      expect(PlaceCategory.home.displayName, 'Rumah');
      expect(PlaceCategory.work.displayName, 'Kantor');
      expect(DepartureRecurrenceType.weekdays.label, 'Sen–Jum');
      expect(DepartureRecurrenceType.oneTime.label, 'Sekali');
      expect(routine.typeLabel, 'Rutinitas Pagi');
    });
  });

  group('Deep Localization — Local Notifications EN <-> ID', () {
    test('Departure NotificationDetails localizes inline action labels', () {
      AppLocalizations.currentLanguage = AppLanguage.en;
      final enDetails =
          NotificationService.buildDepartureNotificationDetails();
      final enActions =
          enDetails.android?.actions?.map((a) => a.title).toList() ?? [];
      expect(enActions, containsAll(['Mark All Ready', 'Snooze 5m']));

      AppLocalizations.currentLanguage = AppLanguage.id;
      final idDetails =
          NotificationService.buildDepartureNotificationDetails();
      final idActions =
          idDetails.android?.actions?.map((a) => a.title).toList() ?? [];
      expect(idActions, containsAll(['Siap Semua', 'Tunda 5m']));
    });

    test('Hydration, Sleep Wind-Down, and Reading notifications emit Bahasa Indonesia bodies', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();

      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final settings = SettingsProvider(storage);
      await settings.setLanguage(AppLanguage.id);

      final notifications = NotificationService();
      final hydration = HydrationProvider(storage, notifications);
      final sleep = SleepWellnessProvider(
        storage,
        notifications,
        _FakeAmbientSoundService(),
      );
      final reading = ReadingProvider(
        storage,
        notificationService: notifications,
      );

      try {
        await hydration.testSendReminderNow();
        await sleep.testSendAlertNow();
        await reading.testSendEveningNudgeNow();

        final shows = recordedNotifCalls
            .where((c) => c.method == 'show')
            .map((c) => Map<String, dynamic>.from(c.arguments as Map))
            .toList();

        expect(shows.length, 3);
        expect(shows[0]['title'], '💧 Seren — Pengingat Minum');
        expect(shows[0]['body'].toString(), contains('Waktunya minum!'));
        expect(shows[1]['title'], '🌙 Seren — Persiapan Tidur (Uji)');
        expect(shows[1]['body'].toString(), contains('Waktunya bersantai!'));
        expect(shows[2]['title'], '🦜 Pippin — Pengingat Baca Harian');
        expect(shows[2]['body'].toString(), contains('Baca 15 halaman'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
        hydration.dispose();
        sleep.dispose();
        reading.dispose();
        settings.dispose();
      }
    });
  });

  group('Deep Localization — Secondary Modal Sheets & Money Views in ID', () {
    testWidgets('SleepCycleSheet, MedicationTrackerSheet, HobbyPracticeSheet render in ID', (tester) async {
      final env = await _DeepL10nEnv.create(language: AppLanguage.id);
      try {
        await tester.pumpWidget(env.wrap(const SleepCycleSheet()));
        await tester.pumpAndSettle();
        expect(find.text('Seren Tidur & Relaksasi'), findsOneWidget);
        expect(find.text('Pengingat Persiapan Tidur'), findsOneWidget);

        await tester.pumpWidget(env.wrap(const MedicationTrackerSheet()));
        await tester.pumpAndSettle();
        expect(find.text('Pelacak Obat & Vitamin'), findsOneWidget);

        await tester.pumpWidget(env.wrap(const HobbyPracticeSheet()));
        await tester.pumpAndSettle();
        expect(find.text('Ruang Latihan Hobi'), findsOneWidget);
        expect(find.text('Eksplorasi & Kemahiran Pippin'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        env.dispose();
      }
    });

    testWidgets('HealthWellnessSheet, ReadingTrackerSheet, LocationRemindersSheet, BeforeYouGoSheet render in ID', (tester) async {
      final env = await _DeepL10nEnv.create(language: AppLanguage.id);
      try {
        await tester.pumpWidget(env.wrap(const HealthWellnessSheet()));
        await tester.pumpAndSettle();
        expect(find.text('Langkah'), findsOneWidget);
        expect(find.text('Tidur'), findsOneWidget);
        expect(find.text('Vital'), findsOneWidget);
        expect(find.text('Napas'), findsOneWidget);
        expect(find.text('Tren Langkah 7 Hari'), findsOneWidget);

        await tester.pumpWidget(env.wrap(const ReadingTrackerSheet()));
        await tester.pumpAndSettle();
        expect(find.text('Pelacak Progres Bacaan'), findsOneWidget);

        await tester.pumpWidget(env.wrap(const LocationRemindersSheet()));
        await tester.pumpAndSettle();
        expect(find.text('Pengingat Lokasi Scout'), findsOneWidget);

        await tester.pumpWidget(env.wrap(const BeforeYouGoSheet()));
        await tester.pumpAndSettle();
        expect(
          find.text('Daftar cek khusus & pengingat berangkat cerdas'),
          findsOneWidget,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        env.dispose();
      }
    });

    testWidgets('MoneyTransactionsView & MoneyBudgetsView render Bahasa Indonesia cleanly', (tester) async {
      final env = await _DeepL10nEnv.create(language: AppLanguage.id);
      try {
        await tester.pumpWidget(env.wrap(const MoneyTransactionsView()));
        await tester.pumpAndSettle();
        expect(
          find.text('Cari deskripsi, kategori, dompet...'),
          findsOneWidget,
        );
        expect(find.text('Semua Jenis'), findsOneWidget);

        await tester.pumpWidget(env.wrap(const MoneyBudgetsView()));
        await tester.pumpAndSettle();
        expect(find.text('Batas Bulanan Keseluruhan'), findsOneWidget);
        expect(find.text('Anggaran per Kategori'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        env.dispose();
      }
    });
  });
}
