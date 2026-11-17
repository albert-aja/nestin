import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/l10n/app_translations.dart';
import 'package:nestin/data/models/entity_link.dart';
import 'package:nestin/data/models/interactive_experience_models.dart';
import 'package:nestin/data/models/location_reminder.dart';
import 'package:nestin/data/services/ambient_sound_service.dart';
import 'package:nestin/data/services/audio_service.dart';
import 'package:nestin/data/services/geofencing_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/data/services/weather_service.dart';
import 'package:nestin/domain/experiences/interactive_experience_engine.dart';
import 'package:nestin/providers/before_you_go_provider.dart';
import 'package:nestin/providers/calendar_provider.dart';
import 'package:nestin/providers/collection_provider.dart';
import 'package:nestin/providers/cross_module_link_provider.dart';
import 'package:nestin/providers/geofence_provider.dart';
import 'package:nestin/providers/hobby_provider.dart';
import 'package:nestin/providers/interactive_experience_provider.dart';
import 'package:nestin/providers/money_provider.dart';
import 'package:nestin/providers/note_provider.dart';
import 'package:nestin/providers/reading_provider.dart';
import 'package:nestin/providers/routine_provider.dart';
import 'package:nestin/providers/seren_relaxation_provider.dart';
import 'package:nestin/providers/task_provider.dart';
import 'package:nestin/providers/timer_provider.dart';
import 'package:nestin/ui/screens/explore/nestin_discover_screen.dart';

class _TestAudioService implements AudioService {
  @override
  bool get isPlaying => false;

  @override
  double get currentVolume => 0.0;

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TestNotificationService implements NotificationService {
  @override
  Stream<NotificationResponse> get actionResponseStream =>
      const Stream<NotificationResponse>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TestAmbientSoundService extends AmbientSoundService {
  @override
  Future<void> play(AmbientSoundType type, {double? volume}) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _FixedWeatherService implements WeatherProviderInterface {
  final WeatherInfo weather;
  _FixedWeatherService(this.weather);

  @override
  Future<WeatherInfo> getCurrentWeather() async => weather;
}

class _FakeGeofencingService implements GeofencingServiceInterface {
  @override
  Future<bool> isSupported() async => false;

  @override
  Future<LocationPermissionState> checkPermission() async =>
      LocationPermissionState.whileInUse;

  @override
  Future<LocationPermissionState> requestForegroundPermission() async =>
      LocationPermissionState.whileInUse;

  @override
  Future<LocationPermissionState> requestBackgroundPermission() async =>
      LocationPermissionState.whileInUse;

  @override
  Future<bool> openAppLocationSettings() async => false;

  @override
  Future<GeoCoordinate?> getCurrentLocation() async => null;

  @override
  Future<bool> syncGeofences(List<NativeGeofenceRegistration> regions) async =>
      true;

  @override
  Future<bool> removeGeofence(String id) async => true;

  @override
  Future<bool> clearAllGeofences() async => true;

  @override
  Future<List<NativeGeofenceEvent>> drainPendingEvents() async => const [];

  @override
  Stream<NativeGeofenceEvent> get eventStream => const Stream.empty();

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const rainyWeather = WeatherInfo(
    temperatureCelsius: 19.0,
    condition: 'Rain Showers',
    locationName: 'Jakarta',
    highTemp: 23.0,
    lowTemp: 18.0,
    rainChancePercent: 75,
    advice: 'Pack a compact umbrella and light jacket.',
  );

  const clearWarmWeather = WeatherInfo(
    temperatureCelsius: 27.0,
    condition: 'Sunny & Clear',
    locationName: 'Bandung',
    highTemp: 29.0,
    lowTemp: 20.0,
    rainChancePercent: 10,
    advice: 'Ideal day for trails and outdoor parks.',
  );

  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = StorageService(prefs);
  });

  group('Scout\'s Weekend Generator (weekend_generator_v1)', () {
    test('Localization parity: all wg_* keys exist in EN and ID', () {
      final enKeys = kNestinTranslations['en']!.keys
          .where((k) => k.startsWith('wg_'))
          .toSet();
      final idKeys = kNestinTranslations['id']!.keys
          .where((k) => k.startsWith('wg_'))
          .toSet();

      expect(enKeys.length, greaterThanOrEqualTo(60));
      expect(enKeys.difference(idKeys), isEmpty);
      expect(idKeys.difference(enKeys), isEmpty);
    });

    test('Weather-aware scoring adapts itineraries for clear vs rainy forecasts',
        () {
      const engine = InteractiveExperienceEngine();
      final draft = ExperienceSessionDraft(
        experienceId: ExperienceCatalog.weekendGeneratorId,
        definitionVersion: 1,
        selectedOptionIdsByQuestion: {
          'wg_q_mood': ['wg_opt_mood_outdoor'],
          'wg_q_energy': ['wg_opt_energy_mid'],
          'wg_q_time_window': ['wg_opt_time_half'],
          'wg_q_weather_pref': ['wg_opt_pref_adaptive'],
          'wg_q_company': ['wg_opt_comp_either'],
          'wg_q_budget': ['wg_opt_budget_mid'],
        },
        startedAt: DateTime(2026, 11, 17, 10),
        updatedAt: DateTime(2026, 11, 17, 10),
      );

      final clearMatches = engine.evaluateWeekendGenerator(
        draft: draft,
        currentWeather: clearWarmWeather,
      );
      expect(clearMatches.length, 3);
      final topClear =
          WeekendGeneratorCatalog.findById(clearMatches.first.profileId)!;
      expect(topClear.isOutdoor, isTrue);
      expect(
        clearMatches.first.reasonKeys,
        contains('wg_reason_weather_clear_boost'),
      );

      final rainyMatches = engine.evaluateWeekendGenerator(
        draft: draft,
        currentWeather: rainyWeather,
      );
      expect(rainyMatches.length, 3);
      final topRainy =
          WeekendGeneratorCatalog.findById(rainyMatches.first.profileId)!;
      expect(
        topRainy.rainFriendly || !topRainy.isOutdoor,
        isTrue,
      );
      expect(
        rainyMatches.first.reasonKeys,
        contains('wg_reason_weather_rain_adapt'),
      );
    });

    test('Zero-cost free budget prioritizes zero-spend itineraries', () {
      const engine = InteractiveExperienceEngine();
      final draft = ExperienceSessionDraft(
        experienceId: ExperienceCatalog.weekendGeneratorId,
        definitionVersion: 1,
        selectedOptionIdsByQuestion: {
          'wg_q_mood': ['wg_opt_mood_recovery'],
          'wg_q_energy': ['wg_opt_energy_low'],
          'wg_q_time_window': ['wg_opt_time_micro'],
          'wg_q_weather_pref': ['wg_opt_pref_indoor'],
          'wg_q_company': ['wg_opt_comp_solo'],
          'wg_q_budget': ['wg_opt_budget_zero'],
        },
        startedAt: DateTime(2026, 11, 17),
        updatedAt: DateTime(2026, 11, 17),
      );

      final matches = engine.evaluateWeekendGenerator(draft: draft);
      final top = WeekendGeneratorCatalog.findById(matches.first.profileId)!;
      expect(top.id, 'analog_home_spa_sanctuary');
      expect(top.estimatedPocketBudgetUsd, 0);
      expect(matches.first.reasonKeys, contains('wg_reason_budget_fit'));
    });

    test('Result record serialization preserves Scout, Roo, and Twill IDs', () {
      final record = ExperienceResultRecord(
        experienceId: ExperienceCatalog.weekendGeneratorId,
        definitionVersion: 1,
        topMatches: const [
          ExperienceMatchedOutcome(
            profileId: 'sunny_park_picnic_sketch',
            matchPercentage: 92,
            rawScore: 42.0,
            reasonKeys: ['wg_reason_budget_fit'],
          ),
        ],
        createdScoutPresetId: 'preset_abc',
        createdScoutPlaceId: 'place_def',
        createdRooCalendarEventId: 'evt_ghi',
        createdTwillChecklistId: 'col_jkl',
        createdTwillBudgetId: 'bdg_mno',
      );

      final decoded = ExperienceResultRecord.fromJson(record.toJson());
      expect(decoded.createdScoutPresetId, 'preset_abc');
      expect(decoded.createdScoutPlaceId, 'place_def');
      expect(decoded.createdRooCalendarEventId, 'evt_ghi');
      expect(decoded.createdTwillChecklistId, 'col_jkl');
      expect(decoded.createdTwillBudgetId, 'bdg_mno');
    });

    test(
        'Multi-bird handoffs wire BeforeYouGo + Geofence + Calendar + CrossModuleLink + Collection + MoneyBudget',
        () async {
      final expProvider = InteractiveExperienceProvider(storage);
      final bygProvider = BeforeYouGoProvider(
        storage,
        _TestNotificationService(),
        weatherService: _FixedWeatherService(rainyWeather),
      );
      await bygProvider.refreshWeatherPrompts();

      final geofenceProvider = GeofenceProvider(
        storage,
        _TestNotificationService(),
        geofencingService: _FakeGeofencingService(),
        seedDefaults: false,
        autoInitializeNative: false,
      );
      final calendarProvider = CalendarProvider(storage);
      final collectionProvider = CollectionProvider(storage);
      final moneyProvider = MoneyProvider(storage);
      final linkProvider = CrossModuleLinkProvider(storage);

      await expProvider.startFreshSession(ExperienceCatalog.weekendGeneratorV1);
      final record = await expProvider.completeWeekendGeneratorSession(
        currentWeather: rainyWeather,
      );
      expect(record.experienceId, ExperienceCatalog.weekendGeneratorId);
      expect(record.answersSnapshot['weatherSummary']['isRainy'], isTrue);

      final profile =
          WeekendGeneratorCatalog.findById('farmers_market_slow_kitchen')!;

      // 1. Scout Handoff: BeforeYouGo Preset (+ auto weather gear) & Geofence Place + Reminder
      final preset = await expProvider.launchWeekendInScoutBeforeYouGo(
        resultId: record.id,
        profile: profile,
        localizedTitle: 'Farmers Market & Slow Kitchen',
        localizedGearItems: ['Canvas tote', 'Cash envelope'],
        localizedPlaceName: 'Morning Produce Market',
        beforeYouGoProvider: bygProvider,
        geofenceProvider: geofenceProvider,
        linkProvider: linkProvider,
        includeGeofenceReminder: true,
      );
      expect(bygProvider.activePresetId, preset.id);
      expect(preset.items.length, greaterThanOrEqualTo(3));
      expect(geofenceProvider.places.length, 1);
      expect(geofenceProvider.reminders.length, 1);
      expect(geofenceProvider.reminders.first.checkDepartureChecklist, isTrue);

      // 2. Roo Handoff: CalendarEvent linked to Scout's DeparturePreset
      final event = await expProvider.scheduleWeekendBlockInRooCalendar(
        resultId: record.id,
        profile: profile,
        localizedTitle: 'Farmers Market & Slow Kitchen',
        localizedDescription: 'Fresh local produce run',
        localizedPlaceName: 'Morning Produce Market',
        calendarProvider: calendarProvider,
        linkProvider: linkProvider,
        targetWeekday: DateTime.sunday,
        referenceDate: DateTime(2026, 11, 17, 10),
      );
      expect(event.date.weekday, DateTime.sunday);
      expect(event.beforeYouGoPresetId, preset.id);
      expect(calendarProvider.events.any((e) => e.id == event.id), isTrue);
      final links = linkProvider.linksFor(
        LinkEntityType.calendarEvent,
        event.id,
      );
      expect(links.length, 1);
      expect(links.first.relationship, 'weekend_departure');

      // 3. Twill Handoff: Reusable Packing Checklist & Personal Monthly Pocket Cap
      final checklist = await expProvider.createWeekendPackAndBudgetInTwill(
        resultId: record.id,
        profile: profile,
        localizedTitle: 'Farmers Market & Slow Kitchen',
        localizedGearItems: ['Canvas tote', 'Cash envelope'],
        collectionProvider: collectionProvider,
        moneyProvider: moneyProvider,
        setPocketBudgetCap: true,
      );
      expect(checklist.isReusableTemplate, isTrue);
      expect(collectionProvider.collections.any((c) => c.id == checklist.id),
          isTrue);
      expect(moneyProvider.budgets.length, 1);

      final updated =
          expProvider.latestResultFor(ExperienceCatalog.weekendGeneratorId)!;
      expect(updated.createdScoutPresetId, preset.id);
      expect(updated.createdScoutPlaceId, geofenceProvider.places.first.id);
      expect(updated.createdRooCalendarEventId, event.id);
      expect(updated.createdTwillChecklistId, checklist.id);
      expect(updated.createdTwillBudgetId, moneyProvider.budgets.first.id);
    });

    testWidgets(
        'NestinDiscoverScreen completes Weekend Generator 6-step flow & triggers Scout/Roo/Twill actions cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final notif = _TestNotificationService();
      final expProvider = InteractiveExperienceProvider(storage);
      final bygProvider = BeforeYouGoProvider(
        storage,
        notif,
        weatherService: _FixedWeatherService(clearWarmWeather),
      );
      await bygProvider.refreshWeatherPrompts();

      final geofenceProvider = GeofenceProvider(
        storage,
        notif,
        geofencingService: _FakeGeofencingService(),
        seedDefaults: false,
        autoInitializeNative: false,
      );
      final calendarProvider = CalendarProvider(storage);
      final collectionProvider = CollectionProvider(storage);
      final moneyProvider = MoneyProvider(storage);
      final linkProvider = CrossModuleLinkProvider(storage);
      final hobbyProvider = HobbyProvider(storage);
      final noteProvider = NoteProvider(storage);
      final readingProvider = ReadingProvider(storage);
      final routineProvider = RoutineProvider(storage);
      final serenProvider = SerenRelaxationProvider(storage);
      final taskProvider = TaskProvider(storage);
      final timerProvider = TimerProvider(
        storage,
        notif,
        _TestAudioService(),
        _TestAmbientSoundService(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: expProvider),
            ChangeNotifierProvider.value(value: bygProvider),
            ChangeNotifierProvider.value(value: geofenceProvider),
            ChangeNotifierProvider.value(value: calendarProvider),
            ChangeNotifierProvider.value(value: collectionProvider),
            ChangeNotifierProvider.value(value: moneyProvider),
            ChangeNotifierProvider.value(value: linkProvider),
            ChangeNotifierProvider.value(value: hobbyProvider),
            ChangeNotifierProvider.value(value: noteProvider),
            ChangeNotifierProvider.value(value: readingProvider),
            ChangeNotifierProvider.value(value: routineProvider),
            ChangeNotifierProvider.value(value: serenProvider),
            ChangeNotifierProvider.value(value: taskProvider),
            ChangeNotifierProvider.value(value: timerProvider),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: NestinDiscoverScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to Scout's Weekend Generator Hero Card & tap start
      final startFinder =
          find.byKey(const ValueKey('btn_start_weekend_generator'));
      await tester.scrollUntilVisible(
        startFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('weekend_generator_hero_card')),
          findsOneWidget);

      await tester.tap(startFinder);
      await tester.pumpAndSettle();

      // Answer all 6 steps cleanly
      final optionOrder = [
        'wg_opt_mood_outdoor',
        'wg_opt_energy_mid',
        'wg_opt_time_half',
        'wg_opt_pref_adaptive',
        'wg_opt_comp_group',
        'wg_opt_budget_low',
      ];
      for (final optId in optionOrder) {
        final optFinder = find.byKey(ValueKey('option_$optId'));
        await tester.ensureVisible(optFinder);
        await tester.tap(optFinder);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('btn_next_or_complete_question')),
        );
        await tester.pumpAndSettle();
      }

      // Verify Result Card & trigger 1-tap Scout, Roo, Twill handoffs
      final resultCardFinder =
          find.byKey(const ValueKey('weekend_generator_result_card'));
      expect(resultCardFinder, findsOneWidget);

      final scoutBtn =
          find.byKey(const ValueKey('btn_wg_scout_before_you_go'));
      await tester.ensureVisible(scoutBtn);
      await tester.pumpAndSettle();
      await tester.tap(scoutBtn);
      await tester.pumpAndSettle();
      expect(bygProvider.presets.length, greaterThanOrEqualTo(4));

      final rooBtn = find.byKey(const ValueKey('btn_wg_roo_calendar'));
      await tester.ensureVisible(rooBtn);
      await tester.tap(rooBtn);
      await tester.pumpAndSettle();
      expect(calendarProvider.events.length, greaterThanOrEqualTo(1));

      final twillBtn = find.byKey(const ValueKey('btn_wg_twill_pack_budget'));
      await tester.ensureVisible(twillBtn);
      await tester.tap(twillBtn);
      await tester.pumpAndSettle();
      expect(collectionProvider.collections.length, greaterThanOrEqualTo(1));

      await tester.pumpWidget(const SizedBox.shrink());
      timerProvider.dispose();
      bygProvider.dispose();
    });
  });
}
