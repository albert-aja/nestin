import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nestin/core/l10n/app_language.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/l10n/app_translations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/user_preferences.dart';
import 'package:nestin/data/services/audio_service.dart';
import 'package:nestin/data/services/backend_gateway_service.dart';
import 'package:nestin/data/services/inspiration_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/oem_hardening_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/data/services/weather_service.dart';
import 'package:nestin/providers/account_provider.dart';
import 'package:nestin/providers/alarm_provider.dart';
import 'package:nestin/providers/automation_provider.dart';
import 'package:nestin/providers/before_you_go_provider.dart';
import 'package:nestin/providers/break_the_cycle_provider.dart';
import 'package:nestin/providers/bucket_list_provider.dart';
import 'package:nestin/providers/caffeine_provider.dart';
import 'package:nestin/providers/calendar_provider.dart';
import 'package:nestin/providers/collection_provider.dart';
import 'package:nestin/providers/cross_module_link_provider.dart';
import 'package:nestin/providers/dashboard_provider.dart';
import 'package:nestin/providers/device_control_provider.dart';
import 'package:nestin/providers/geofence_provider.dart';
import 'package:nestin/providers/health_wellness_provider.dart';
import 'package:nestin/providers/hobby_provider.dart';
import 'package:nestin/providers/hydration_provider.dart';
import 'package:nestin/providers/inspiration_provider.dart';
import 'package:nestin/providers/interactive_experience_provider.dart';
import 'package:nestin/providers/journal_provider.dart';
import 'package:nestin/providers/medication_provider.dart';
import 'package:nestin/providers/money_provider.dart';
import 'package:nestin/providers/note_provider.dart';
import 'package:nestin/providers/oem_hardening_provider.dart';
import 'package:nestin/providers/reading_provider.dart';
import 'package:nestin/providers/reminder_provider.dart';
import 'package:nestin/providers/routine_provider.dart';
import 'package:nestin/providers/seren_relaxation_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/providers/sleep_wellness_provider.dart';
import 'package:nestin/providers/sound_provider.dart';
import 'package:nestin/providers/task_provider.dart';
import 'package:nestin/providers/timer_provider.dart';
import 'package:nestin/providers/wearable_provider.dart';
import 'package:nestin/ui/screens/main_navigation_screen.dart';
import 'package:nestin/ui/screens/nest/echo_house_screen.dart';
import 'package:nestin/ui/screens/nest/nest_treehouse_scene_view.dart';
import 'package:nestin/ui/screens/nest/nest_treehouse_screen.dart';
import 'package:nestin/ui/screens/nest/pippin_house_screen.dart';
import 'package:nestin/ui/screens/nest/roo_house_screen.dart';
import 'package:nestin/ui/screens/nest/scout_house_screen.dart';
import 'package:nestin/ui/screens/nest/seren_house_screen.dart';
import 'package:nestin/ui/screens/nest/twill_house_screen.dart';
import 'package:nestin/ui/screens/search/universal_search_screen.dart';
import 'package:nestin/ui/screens/settings/settings_screen.dart';
import 'package:nestin/ui/widgets/animated_mascot_sprite.dart';
import 'package:nestin/ui/widgets/fade_through_indexed_stack.dart';
import 'package:nestin/ui/widgets/location_reminders_card.dart';
import 'package:nestin/ui/widgets/money_summary_card.dart';
import 'package:nestin/ui/widgets/quick_capture_sheet.dart';
import 'package:nestin/ui/widgets/reading_progress_card.dart';

class _RevampTestEnv {
  final StorageService storage;
  final SettingsProvider settings;
  final HydrationProvider hydration;
  final TaskProvider tasks;
  final NoteProvider notes;
  final NotificationService notifications;
  final AudioService audio;
  final LocalWeatherService weather;

  _RevampTestEnv._({
    required this.storage,
    required this.settings,
    required this.hydration,
    required this.tasks,
    required this.notes,
    required this.notifications,
    required this.audio,
    required this.weather,
  });

  static Future<_RevampTestEnv> create({
    AppLanguage language = AppLanguage.en,
    ThemeMode themeMode = ThemeMode.dark,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await AppLocalizations.ensureDateFormatting();
    final storage = await StorageService.init();
    final settings = SettingsProvider(storage);
    await settings.setLanguage(language);
    await settings.setThemeMode(themeMode);
    await settings.completeMascotOnboarding();

    final notifications = NotificationService();
    final audio = AudioService();
    final weather = LocalWeatherService(
      overrideWeather: const WeatherInfo(
        temperatureCelsius: 28,
        condition: 'Partly Sunny',
        locationName: 'Test Nest',
        highTemp: 30,
        lowTemp: 23,
        rainChancePercent: 10,
        advice: 'Warm and bright outside.',
      ),
    );
    final hydration = HydrationProvider(storage, notifications);
    final tasks = TaskProvider(storage);
    final notes = NoteProvider(storage);

    return _RevampTestEnv._(
      storage: storage,
      settings: settings,
      hydration: hydration,
      tasks: tasks,
      notes: notes,
      notifications: notifications,
      audio: audio,
      weather: weather,
    );
  }

  Widget wrap(Widget child, {ThemeMode? overrideThemeMode}) {
    final deviceControl = DeviceControlProvider(
      storage,
      notifications: notifications,
    );
    final reminderProvider = ReminderProvider(storage, notifications);
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        Provider<NotificationService>.value(value: notifications),
        Provider<WeatherProviderInterface>.value(value: weather),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider(create: (_) => SoundProvider(storage)),
        ChangeNotifierProvider(
          create: (_) => AlarmProvider(storage, audio, notifications),
        ),
        ChangeNotifierProvider<ReminderProvider>.value(value: reminderProvider),
        ChangeNotifierProvider<DeviceControlProvider>.value(
          value: deviceControl,
        ),
        ChangeNotifierProvider(
          create: (_) => TimerProvider(
            storage,
            notifications,
            audio,
            null,
            deviceControl,
          ),
        ),
        ChangeNotifierProvider(create: (_) => CalendarProvider(storage)),
        ChangeNotifierProvider<TaskProvider>.value(value: tasks),
        ChangeNotifierProvider(create: (_) => RoutineProvider(storage)),
        ChangeNotifierProvider<NoteProvider>.value(value: notes),
        ChangeNotifierProvider(create: (_) => CollectionProvider(storage)),
        ChangeNotifierProvider(create: (_) => JournalProvider(storage)),
        ChangeNotifierProvider(create: (_) => DashboardProvider(storage)),
        ChangeNotifierProvider(create: (_) => WearableProvider(storage)),
        ChangeNotifierProvider<HydrationProvider>.value(value: hydration),
        ChangeNotifierProvider(
          create: (_) => SleepWellnessProvider(storage, notifications),
        ),
        ChangeNotifierProvider(
          create: (_) => OemHardeningProvider(
            storage,
            MockOemHardeningService(
              manufacturer: 'Pixel',
              brand: 'Google',
              model: 'Pixel 9',
              isIgnoringBatteryOptimizations: true,
              isKeepAliveRunning: false,
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => MedicationProvider(storage, notifications),
        ),
        ChangeNotifierProvider(create: (_) => HobbyProvider(storage)),
        ChangeNotifierProvider(
          create: (_) => HealthWellnessProvider(storage, notifications),
        ),
        ChangeNotifierProvider(
          create: (_) => ReadingProvider(
            storage,
            notificationService: notifications,
          ),
        ),
        ChangeNotifierProvider(create: (_) => BucketListProvider(storage)),
        ChangeNotifierProvider(
          create: (_) => GeofenceProvider(
            storage,
            notifications,
            autoInitializeNative: false,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => BeforeYouGoProvider(
            storage,
            notifications,
            weatherService: weather,
          ),
        ),
        ChangeNotifierProvider(create: (_) => MoneyProvider(storage)),
        ChangeNotifierProvider(
          create: (_) => CaffeineProvider(storage, notifications),
        ),
        ChangeNotifierProvider(
          create: (_) => AutomationProvider(
            storage,
            deviceControl,
            tasks: tasks,
            reminders: reminderProvider,
            hydration: hydration,
            notifications: notifications,
          ),
        ),
        ChangeNotifierProvider(create: (_) => CrossModuleLinkProvider(storage)),
        ChangeNotifierProvider(create: (_) => AccountProvider(storage)),
        ChangeNotifierProvider(
          create: (_) => InspirationProvider(
            InspirationService.live(
              storage.prefs,
              BackendGatewayService(storage.prefs),
            ),
            notificationService: notifications,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SerenRelaxationProvider(
            storage,
            notificationService: notifications,
          ),
        ),
        ChangeNotifierProvider(create: (_) => BreakTheCycleProvider(storage)),
        ChangeNotifierProvider(
          create: (_) => InteractiveExperienceProvider(storage),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: overrideThemeMode ?? settings.themeMode,
        locale: settings.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: child,
      ),
    );
  }
}

void _setNarrowViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    QuickCaptureSheet.resetSessionMemory();
  });

  group('3-Slot Bottom Navigation Dock', () {
    testWidgets(
      'switches Dashboard <-> Nest via FadeThroughIndexedStack, taps + for QuickCaptureSheet, long-presses + for UniversalSearchScreen',
      (tester) async {
        _setNarrowViewport(tester);
        final env = await _RevampTestEnv.create(themeMode: ThemeMode.light);

        await tester.pumpWidget(env.wrap(const MainNavigationScreen()));
        await tester.pump(const Duration(milliseconds: 250));

        // 3 slots present
        expect(find.byKey(const Key('nav_slot_dashboard')), findsOneWidget);
        expect(find.byKey(const Key('nav_slot_quick_capture')), findsOneWidget);
        expect(find.byKey(const Key('nav_slot_nest')), findsOneWidget);
        expect(find.byType(FadeThroughIndexedStack), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Dashboard overflow');

        // Decluttered Dashboard omits full-module discovery walls
        expect(find.byType(MoneySummaryCard), findsNothing);
        expect(find.byType(ReadingProgressCard), findsNothing);
        expect(find.byType(LocationRemindersCard), findsNothing);

        // Switch to Nest tab
        await tester.tap(find.byKey(const Key('nav_slot_nest')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const Key('nest_treehouse_screen')), findsOneWidget);
        expect(find.byKey(const Key('nest_bird_card_roo')), findsOneWidget);
        expect(find.byKey(const Key('nest_bird_card_echo')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Nest overflow');

        // Tap center (+) opens redesigned QuickCaptureSheet
        await tester.tap(find.byKey(const Key('nav_slot_quick_capture')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(QuickCaptureSheet), findsOneWidget);
        expect(find.byKey(const Key('qc_zone_quick_actions')), findsOneWidget);
        expect(find.byKey(const Key('qc_mental_aid_chip')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'QuickCapture overflow');

        // Dismiss sheet
        Navigator.of(tester.element(find.byType(QuickCaptureSheet))).pop();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(QuickCaptureSheet), findsNothing);

        // Long-press center (+) opens UniversalSearchScreen directly
        await tester.longPress(find.byKey(const Key('nav_slot_quick_capture')));
        await tester.pumpAndSettle();
        expect(find.byType(UniversalSearchScreen), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Search overflow');
      },
    );
  });

  group('Nest Treehouse 6-Bird Grid & Bird Houses Routing', () {
    testWidgets(
      'all 6 bird cards render cleanly on narrow viewport and route into each Bird House screen',
      (tester) async {
        _setNarrowViewport(tester);
        final env = await _RevampTestEnv.create(themeMode: ThemeMode.light);

        await tester.pumpWidget(env.wrap(const NestTreehouseScreen()));
        await tester.pumpAndSettle();

        final routes = <Key, Type>{
          const Key('nest_bird_card_roo'): RooHouseScreen,
          const Key('nest_bird_card_scout'): ScoutHouseScreen,
          const Key('nest_bird_card_seren'): SerenHouseScreen,
          const Key('nest_bird_card_pippin'): PippinHouseScreen,
          const Key('nest_bird_card_twill'): TwillHouseScreen,
          const Key('nest_bird_card_echo'): EchoHouseScreen,
        };

        for (final entry in routes.entries) {
          final card = find.byKey(entry.key);
          await tester.ensureVisible(card);
          await tester.pumpAndSettle();
          await tester.tap(card);
          await tester.pumpAndSettle();

          expect(find.byType(entry.value), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Navigate back cleanly to Nest Treehouse
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.byType(NestTreehouseScreen), findsOneWidget);
        }
      },
    );

    testWidgets(
      'NestTreehouseScreen renders cleanly in Bahasa Indonesia & Dark Theme',
      (tester) async {
        _setNarrowViewport(tester);
        final env = await _RevampTestEnv.create(
          language: AppLanguage.id,
          themeMode: ThemeMode.dark,
        );

        await tester.pumpWidget(env.wrap(const NestTreehouseScreen()));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('nest_brand_title')), findsOneWidget);
        expect(find.byKey(const Key('nest_greeting_text')), findsOneWidget);
        expect(find.byKey(const Key('nest_slim_status_pill')), findsOneWidget);
        expect(find.text('Waktu & Kebiasaan'), findsOneWidget);
        expect(find.text('Panduan Harian'), findsOneWidget);
        expect(find.text('Tenang & Sehat'), findsOneWidget);
        expect(find.text('Minat & Tumbuh'), findsOneWidget);
        expect(find.text('Catatan & Uang'), findsOneWidget);
        expect(find.text('Jurnal & Refleksi'), findsOneWidget);

        // Verify domain-colored border & dark-mode outer glow on Roo card
        final rooContainer = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(const Key('nest_bird_card_roo')),
                matching: find.byType(Container),
              )
              .first,
        );
        final rooDecoration = rooContainer.decoration! as BoxDecoration;
        expect(
          rooDecoration.border,
          Border.all(
            color: RooHouseScreen.rooColor.withValues(alpha: 0.75),
            width: 1.3,
          ),
        );
        expect(rooDecoration.boxShadow, isNotEmpty);
        expect(rooDecoration.boxShadow!.first.blurRadius, 14);

        // Tapping alarm segment of slim quick-status pill navigates to Roo's House
        await tester.tap(find.byKey(const Key('nest_slim_pill_alarm_tap')));
        await tester.pumpAndSettle();
        expect(find.byType(RooHouseScreen), findsOneWidget);
        Navigator.of(tester.element(find.byType(RooHouseScreen))).pop();
        await tester.pumpAndSettle();

        // Tapping weather segment of slim quick-status pill navigates to Scout's House
        await tester.tap(find.byKey(const Key('nest_slim_pill_weather_tap')));
        await tester.pumpAndSettle();
        expect(find.byType(ScoutHouseScreen), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Redesigned 3-Zone QuickCaptureSheet', () {
    testWidgets(
      'collapses Zones 2 & 3 on input focus, logs +1 Glass inline, preserves draft & remembers last type',
      (tester) async {
        _setNarrowViewport(tester);
        final env = await _RevampTestEnv.create(themeMode: ThemeMode.light);

        await tester.pumpWidget(
          env.wrap(
            Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    key: const Key('open_qc_btn'),
                    onPressed: () => QuickCaptureSheet.show(context),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open QuickCaptureSheet
        await tester.tap(find.byKey(const Key('open_qc_btn')));
        await tester.pumpAndSettle();

        // Zones 1, 2, 3 visible initially
        expect(find.byKey(const Key('qc_text_input')), findsOneWidget);
        expect(find.byKey(const Key('qc_zone_quick_actions')), findsOneWidget);
        expect(find.byKey(const Key('qc_zone_calm_anchor')), findsOneWidget);
        expect(find.byKey(const Key('qc_mental_aid_chip')), findsOneWidget);

        // Inline +1 Glass logs hydration without closing the sheet
        final beforeGlasses = env.hydration.glassesConsumed;
        await tester.tap(find.byKey(const Key('qc_action_add_glass')));
        await tester.pumpAndSettle();
        expect(env.hydration.glassesConsumed, beforeGlasses + 1);
        expect(find.byType(QuickCaptureSheet), findsOneWidget);

        // Switch capture type to Note -> Save button tints to Twill Amber (#F59E0B)
        await tester.tap(find.byKey(const Key('qc_type_pill_note')));
        await tester.pumpAndSettle();
        final saveBtn = tester.widget<ElevatedButton>(
          find.byKey(const Key('qc_save_btn')),
        );
        expect(
          saveBtn.style?.backgroundColor?.resolve({}),
          const Color(0xFFF59E0B),
        );

        // Focus text input -> Zones 2 & 3 smoothly collapse
        await tester.tap(find.byKey(const Key('qc_text_input')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('qc_zone_quick_actions')), findsNothing);
        expect(find.byKey(const Key('qc_zone_calm_anchor')), findsNothing);
        expect(find.byKey(const Key('qc_zones_collapsed')), findsOneWidget);

        // Enter draft text without saving, then dismiss sheet
        await tester.enterText(
          find.byKey(const Key('qc_text_input')),
          'Buy sourdough bread',
        );
        await tester.pumpAndSettle();

        // Unfocus restores Zones 2 & 3
        await tester.tap(find.byKey(const Key('qc_unfocus_btn')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('qc_zone_quick_actions')), findsOneWidget);
        expect(find.byKey(const Key('qc_zone_calm_anchor')), findsOneWidget);

        // Dismiss sheet without saving
        Navigator.of(tester.element(find.byType(QuickCaptureSheet))).pop();
        await tester.pumpAndSettle();

        // Reopen without explicit initialType -> draft text & Note type restored
        await tester.tap(find.byKey(const Key('open_qc_btn')));
        await tester.pumpAndSettle();
        expect(find.text('Buy sourdough bread'), findsOneWidget);
        expect(find.text('Draft restored'), findsOneWidget);
        final reopenedBtn = tester.widget<ElevatedButton>(
          find.byKey(const Key('qc_save_btn')),
        );
        expect(
          reopenedBtn.style?.backgroundColor?.resolve({}),
          const Color(0xFFF59E0B),
        );

        // Saving clears draft and adds Note
        await tester.tap(find.byKey(const Key('qc_save_btn')));
        await tester.pumpAndSettle();
        expect(
          env.notes.activeNotes.any((n) => n.title == 'Buy sourdough bread'),
          isTrue,
        );

        // Reopening after Save starts clean
        await tester.tap(find.byKey(const Key('open_qc_btn')));
        await tester.pumpAndSettle();
        expect(find.text('Buy sourdough bread'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Nest View Mode Toggle (Rooms Grid <-> Treehouse Scene)', () {
    test('UserPreferences persists nestViewMode cleanly with roomsGrid default', () async {
      final defaults = UserPreferences.defaults();
      expect(defaults.nestViewMode, NestViewMode.roomsGrid);

      final legacy = UserPreferences.fromJson(const {'themeMode': 'dark'});
      expect(legacy.nestViewMode, NestViewMode.roomsGrid);

      final updated = defaults.copyWith(
        nestViewMode: NestViewMode.treehouseScene,
      );
      final restored = UserPreferences.fromJson(updated.toJson());
      expect(restored.nestViewMode, NestViewMode.treehouseScene);

      final env = await _RevampTestEnv.create();
      expect(env.settings.nestViewMode, NestViewMode.roomsGrid);
      await env.settings.toggleNestViewMode();
      expect(env.settings.nestViewMode, NestViewMode.treehouseScene);

      // Reload fresh provider from persisted StorageService
      final reloaded = SettingsProvider(env.storage);
      expect(reloaded.nestViewMode, NestViewMode.treehouseScene);
    });

    testWidgets(
      'toggles Rooms Grid <-> Living Animated Treehouse Scene, persists choice, hops & routes to each House on 360dp viewport',
      (tester) async {
        _setNarrowViewport(tester);
        final env = await _RevampTestEnv.create(themeMode: ThemeMode.light);

        await tester.pumpWidget(
          env.wrap(
            NestTreehouseScreen(
              clockOverride: DateTime(2026, 11, 22, 10, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Default is Rooms Grid View
        expect(find.byKey(const Key('nest_bird_card_roo')), findsOneWidget);
        expect(find.byKey(const Key('nest_treehouse_scene_view')), findsNothing);
        expect(env.settings.nestViewMode, NestViewMode.roomsGrid);

        // Tap top-bar view-mode toggle -> switches to Living Animated Treehouse Scene
        await tester.tap(find.byKey(const Key('nest_view_mode_toggle_btn')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(env.settings.nestViewMode, NestViewMode.treehouseScene);
        expect(find.byKey(const Key('nest_treehouse_scene_view')), findsOneWidget);
        expect(find.byKey(const Key('nest_scene_art_day')), findsOneWidget);
        expect(find.byKey(const Key('nest_scene_room_effects')), findsOneWidget);
        expect(find.byKey(const Key('nest_scene_atmosphere')), findsOneWidget);
        expect(find.byType(AnimatedMascotSprite), findsNWidgets(6));
        expect(find.byKey(const Key('nest_bird_card_roo')), findsNothing);

        // Floating dark-glass status pill shows live weather for Scout
        expect(find.text('Scout • 28°C'), findsOneWidget);

        // Every one of the 6 birds plays hop bounce and navigates cleanly to its House
        final sceneRoutes = <Key, Type>{
          const Key('nest_scene_bird_roo'): RooHouseScreen,
          const Key('nest_scene_bird_scout'): ScoutHouseScreen,
          const Key('nest_scene_bird_seren'): SerenHouseScreen,
          const Key('nest_scene_bird_pippin'): PippinHouseScreen,
          const Key('nest_scene_bird_twill'): TwillHouseScreen,
          const Key('nest_scene_bird_echo'): EchoHouseScreen,
        };

        for (final entry in sceneRoutes.entries) {
          final hotspot = find.byKey(entry.key);
          expect(hotspot, findsOneWidget);
          await tester.tap(hotspot);
          // Let 190ms springy hop bounce complete, then let route push settle
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 220));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.byType(entry.value), findsOneWidget);
          expect(tester.takeException(), isNull);

          Navigator.of(tester.element(find.byType(entry.value))).pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump();
          expect(find.byType(entry.value), findsNothing);
          expect(
            find.byKey(const Key('nest_treehouse_scene_view')),
            findsOneWidget,
          );
        }

        // Toggle back to Rooms Grid View
        await tester.tap(find.byKey(const Key('nest_view_mode_toggle_btn')));
        await tester.pumpAndSettle();
        expect(env.settings.nestViewMode, NestViewMode.roomsGrid);
        expect(find.byKey(const Key('nest_bird_card_roo')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Living Treehouse Scene renders cleanly in Bahasa Indonesia, Night phase & rainy weather',
      (tester) async {
        _setNarrowViewport(tester);
        final env = await _RevampTestEnv.create(
          language: AppLanguage.id,
          themeMode: ThemeMode.dark,
        );
        env.weather.setOverrideWeather(
          const WeatherInfo(
            temperatureCelsius: 22,
            condition: 'Rain Showers',
            locationName: 'Test Nest',
            highTemp: 25,
            lowTemp: 20,
            rainChancePercent: 80,
            advice: 'Bring an umbrella.',
          ),
        );
        await env.settings.setNestViewMode(NestViewMode.treehouseScene);

        await tester.pumpWidget(
          env.wrap(
            NestTreehouseScreen(
              clockOverride: DateTime(2026, 11, 22, 21, 15),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byKey(const Key('nest_treehouse_scene_view')), findsOneWidget);
        expect(find.byKey(const Key('nest_scene_art_night')), findsOneWidget);
        expect(
          find.text('Ketuk burung mana saja untuk masuk ke rumahnya'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Living Animated Treehouse — 4-Phase Cycle, Performance & Accessibility', () {
    test('resolves exact 4-phase windows and verifies all 4 artwork assets exist & are registered', () {
      expect(TreehouseDayPhaseX.resolve(DateTime(2026, 1, 1, 4, 59)), TreehouseDayPhase.night);
      expect(TreehouseDayPhaseX.resolve(DateTime(2026, 1, 1, 5, 0)), TreehouseDayPhase.dawn);
      expect(TreehouseDayPhaseX.resolve(DateTime(2026, 1, 1, 7, 59)), TreehouseDayPhase.dawn);
      expect(TreehouseDayPhaseX.resolve(DateTime(2026, 1, 1, 8, 0)), TreehouseDayPhase.day);
      expect(TreehouseDayPhaseX.resolve(DateTime(2026, 1, 1, 16, 59)), TreehouseDayPhase.day);
      expect(TreehouseDayPhaseX.resolve(DateTime(2026, 1, 1, 17, 0)), TreehouseDayPhase.sunset);
      expect(TreehouseDayPhaseX.resolve(DateTime(2026, 1, 1, 19, 29)), TreehouseDayPhase.sunset);
      expect(TreehouseDayPhaseX.resolve(DateTime(2026, 1, 1, 19, 30)), TreehouseDayPhase.night);

      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('- assets/images/'), isTrue);
      for (final phase in TreehouseDayPhase.values) {
        expect(
          File(phase.backdropAsset).existsSync(),
          isTrue,
          reason: 'Missing treehouse artwork: ${phase.backdropAsset}',
        );
      }
    });

    testWidgets(
      'pauses TickerMode when Nest tab is inactive and respects MediaQuery.disableAnimations while keeping live clock hands',
      (tester) async {
        _setNarrowViewport(tester);
        final env = await _RevampTestEnv.create(themeMode: ThemeMode.dark);
        await env.settings.setNestViewMode(NestViewMode.treehouseScene);

        // 1. Active tab -> TickerMode enabled
        await tester.pumpWidget(
          env.wrap(
            NestTreehouseScreen(
              isActive: true,
              clockOverride: DateTime(2026, 11, 22, 6, 30),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(const Key('nest_scene_art_dawn')), findsOneWidget);
        expect(
          tester
              .widget<TickerMode>(find.byKey(const Key('nest_scene_ticker_mode')))
              .enabled,
          isTrue,
        );

        // 2. Inactive tab (e.g. switched to Dashboard) -> TickerMode disabled
        await tester.pumpWidget(
          env.wrap(
            NestTreehouseScreen(
              isActive: false,
              clockOverride: DateTime(2026, 11, 22, 18, 15),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(const Key('nest_scene_art_sunset')), findsOneWidget);
        expect(
          tester
              .widget<TickerMode>(find.byKey(const Key('nest_scene_ticker_mode')))
              .enabled,
          isFalse,
        );

        // 3. Reduced motion (disableAnimations: true) -> TickerMode disabled,
        //    pumpAndSettle succeeds cleanly, live clock effects still paint,
        //    and bird tap navigates immediately without hop delay.
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              disableAnimations: true,
            ),
            child: env.wrap(
              NestTreehouseScreen(
                isActive: true,
                clockOverride: DateTime(2026, 11, 22, 14, 45),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TickerMode>(find.byKey(const Key('nest_scene_ticker_mode')))
              .enabled,
          isFalse,
        );
        expect(find.byKey(const Key('nest_scene_room_effects')), findsOneWidget);

        await tester.tap(find.byKey(const Key('nest_scene_bird_roo')));
        await tester.pumpAndSettle();
        expect(find.byType(RooHouseScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'paints Seren playing lamp halo, Echo unlogged warm glow, and supports AnimatedMascotSprite multi-frame drop-in cleanly',
      (tester) async {
        _setNarrowViewport(tester);
        final env = await _RevampTestEnv.create(themeMode: ThemeMode.dark);

        var tapped = false;
        await tester.pumpWidget(
          env.wrap(
            Scaffold(
              body: NestTreehouseSceneView(
                phase: TreehouseDayPhase.night,
                clockOverride: DateTime(2026, 11, 22, 22, 10),
                isActive: true,
                nextAlarmTime: '06:30',
                weather: const WeatherInfo(
                  temperatureCelsius: 21,
                  condition: 'Light Rain',
                  locationName: 'Nest',
                  highTemp: 24,
                  lowTemp: 19,
                  rainChancePercent: 70,
                  advice: 'Pack an umbrella.',
                ),
                isSerenPlaying: true,
                hasLoggedTodayReflection: false,
                onOpenRooHouse: () {},
                onOpenScoutHouse: () {},
                birds: [
                  TreehouseSceneBirdHotspot(
                    key: const Key('test_bird_seren'),
                    name: 'Seren',
                    compactMetric: '4/8',
                    accentColor: SerenHouseScreen.serenColor,
                    spriteAsset: 'assets/mascots/sprites/seren/hello.png',
                    blinkFrames: const ['assets/mascots/sprites/seren/calm.png'],
                    flutterFrames: const ['assets/mascots/sprites/seren/breathe.png'],
                    fallbackIcon: Icons.spa_rounded,
                    fx: TreehouseSceneAnchors.serenPerch.dx,
                    fy: TreehouseSceneAnchors.serenPerch.dy,
                    onTap: () => tapped = true,
                  ),
                ],
              ),
            ),
          ),
        );

        // Advance animation several frames across the 12s harmonic cycle
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 3));
        expect(find.byKey(const Key('nest_scene_room_effects')), findsOneWidget);
        expect(find.byKey(const Key('nest_scene_atmosphere')), findsOneWidget);

        await tester.tap(find.byKey(const Key('test_bird_seren')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));
        expect(tapped, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'live Time-of-Day Phase Preview Scrubber in Treehouse Scene & SettingsScreen cross-fades all 4 atmospheres and persists override',
      (tester) async {
        _setNarrowViewport(tester);
        final env = await _RevampTestEnv.create(themeMode: ThemeMode.dark);
        await env.settings.setNestViewMode(NestViewMode.treehouseScene);

        // Start at 10:15 (Auto = Day)
        await tester.pumpWidget(
          env.wrap(
            NestTreehouseScreen(
              clockOverride: DateTime(2026, 11, 22, 10, 15),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byKey(const Key('nest_scene_phase_scrubber')), findsOneWidget);
        expect(find.byKey(const Key('nest_scene_art_day')), findsOneWidget);
        expect(env.settings.treehousePhaseOverride, isNull);

        // Tap Sunset chip in live Treehouse scrubber -> cross-fades to Sunset & persists
        await tester.tap(find.byKey(const Key('nest_scene_phase_chip_sunset')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 950));
        expect(env.settings.treehousePhaseOverride, TreehouseDayPhase.sunset);
        expect(find.byKey(const Key('nest_scene_art_sunset')), findsOneWidget);

        // Tap Night chip in live Treehouse scrubber -> cross-fades to Night
        await tester.tap(find.byKey(const Key('nest_scene_phase_chip_night')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 950));
        expect(env.settings.treehousePhaseOverride, TreehouseDayPhase.night);
        expect(find.byKey(const Key('nest_scene_art_night')), findsOneWidget);

        // Tap Dawn chip in live Treehouse scrubber -> cross-fades to Dawn
        await tester.tap(find.byKey(const Key('nest_scene_phase_chip_dawn')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 950));
        expect(env.settings.treehousePhaseOverride, TreehouseDayPhase.dawn);
        expect(find.byKey(const Key('nest_scene_art_dawn')), findsOneWidget);

        // Reload fresh SettingsProvider from StorageService -> override persisted
        final reloaded = SettingsProvider(env.storage);
        expect(reloaded.treehousePhaseOverride, TreehouseDayPhase.dawn);

        // Tap Auto chip -> clears override back to live clock (Day at 10:15)
        await tester.tap(find.byKey(const Key('nest_scene_phase_chip_auto')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 950));
        expect(env.settings.treehousePhaseOverride, isNull);
        expect(find.byKey(const Key('nest_scene_art_day')), findsOneWidget);

        // Verify SettingsScreen also exposes the Treehouse Lighting Atmosphere tile & chips
        await tester.pumpWidget(env.wrap(const SettingsScreen()));
        await tester.pumpAndSettle();
        final tileFinder = find.byKey(const Key('settings_treehouse_phase_tile'));
        await tester.ensureVisible(tileFinder);
        await tester.pumpAndSettle();
        expect(tileFinder, findsOneWidget);

        await tester.tap(find.byKey(const Key('settings_treehouse_phase_chip_night')));
        await tester.pumpAndSettle();
        expect(env.settings.treehousePhaseOverride, TreehouseDayPhase.night);

        await tester.tap(find.byKey(const Key('settings_treehouse_phase_chip_auto')));
        await tester.pumpAndSettle();
        expect(env.settings.treehousePhaseOverride, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    test('all 6 birds wire verified 2-frame blinkFrames & flutterFrames and resolveActiveFrameAsset cycles deterministically', () {
      for (final frameList in TreehouseMascotFrameSheets.allFrameLists) {
        expect(frameList.length, 2);
        for (final assetPath in frameList) {
          expect(
            File(assetPath).existsSync(),
            isTrue,
            reason: 'Missing blink/flutter sprite asset: $assetPath',
          );
        }
      }

      const controller = AlwaysStoppedAnimation<double>(0.0);
      const sprite = AnimatedMascotSprite(
        spriteAsset: 'assets/mascots/sprites/roo/welcome.png',
        blinkFrames: TreehouseMascotFrameSheets.rooBlinkFrames,
        flutterFrames: TreehouseMascotFrameSheets.rooFlutterFrames,
        size: 56,
        accentColor: RooHouseScreen.rooColor,
        fallbackIcon: Icons.alarm_rounded,
        ambientAnimation: controller,
        phaseOffset: 0.0,
      );

      // Base idle frame
      expect(
        sprite.resolveActiveFrameAsset(0.10),
        'assets/mascots/sprites/roo/welcome.png',
      );
      // 2-frame blink sequence (cycle = (t * 3.0) % 1.0 in [0.90, 0.96))
      expect(
        sprite.resolveActiveFrameAsset(0.91 / 3.0),
        TreehouseMascotFrameSheets.rooBlinkFrames[0],
      );
      expect(
        sprite.resolveActiveFrameAsset(0.945 / 3.0),
        TreehouseMascotFrameSheets.rooBlinkFrames[1],
      );
      // 2-frame wing-flutter sequence (t in [0.44, 0.52))
      expect(
        sprite.resolveActiveFrameAsset(0.45),
        TreehouseMascotFrameSheets.rooFlutterFrames[0],
      );
      expect(
        sprite.resolveActiveFrameAsset(0.50),
        TreehouseMascotFrameSheets.rooFlutterFrames[1],
      );
      // Reduced motion always returns base frame
      expect(
        sprite.resolveActiveFrameAsset(0.45, disableAnimations: true),
        'assets/mascots/sprites/roo/welcome.png',
      );
    });
  });

  group('Bilingual Localization Parity (EN/ID)', () {
    test('new navigation, nest, house, dashboard & quick capture keys match 100% across translations and ARBs', () {
      final enMap = kNestinTranslations['en']!;
      final idMap = kNestinTranslations['id']!;
      final enArb =
          jsonDecode(File('assets/l10n/app_en.arb').readAsStringSync())
              as Map<String, dynamic>;
      final idArb =
          jsonDecode(File('assets/l10n/app_id.arb').readAsStringSync())
              as Map<String, dynamic>;

      const requiredKeys = [
        'nav_dashboard',
        'nav_nest',
        'nest_title',
        'nest_pill_next_alarm',
        'nest_pill_scout_byg_ready',
        'nest_pill_seren_short',
        'nest_pill_pippin_reading_short',
        'nest_pill_pippin_hobby_short',
        'nest_pill_echo_short',
        'nest_switch_to_scene',
        'nest_switch_to_grid',
        'nest_view_rooms_grid',
        'nest_view_treehouse_scene',
        'nest_scene_tap_hint',
        'nest_scene_pill_roo_tasks',
        'nest_scene_pill_roo_quiet',
        'nest_scene_pill_seren_glasses',
        'nest_scene_pill_pippin_page',
        'nest_scene_pill_pippin_hobby',
        'nest_scene_pill_pippin_discover',
        'nest_scene_pill_twill_notes',
        'nest_scene_pill_echo_pebbles',
        'nest_scene_pill_echo_diary',
        'nest_roo_subtitle',
        'nest_scout_subtitle',
        'nest_seren_subtitle',
        'nest_pippin_subtitle',
        'nest_twill_subtitle',
        'nest_echo_subtitle',
        'house_roo_title',
        'house_scout_title',
        'house_seren_title',
        'house_pippin_title',
        'house_twill_title',
        'house_echo_title',
        'qc_diary',
        'qc_action_money',
        'qc_action_alarm',
        'qc_action_before_you_go',
        'qc_action_add_glass',
        'qc_calm_anchor_title',
        'qc_draft_restored',
        'treehouse_phase_setting_title',
        'treehouse_phase_setting_auto_desc',
        'treehouse_phase_setting_override_desc',
        'treehouse_phase_auto',
        'treehouse_phase_short_auto',
        'treehouse_phase_dawn',
        'treehouse_phase_short_dawn',
        'treehouse_phase_day',
        'treehouse_phase_short_day',
        'treehouse_phase_sunset',
        'treehouse_phase_short_sunset',
        'treehouse_phase_night',
        'treehouse_phase_short_night',
      ];

      for (final key in requiredKeys) {
        expect(enMap.containsKey(key), isTrue, reason: 'Missing EN tr: $key');
        expect(idMap.containsKey(key), isTrue, reason: 'Missing ID tr: $key');
        expect(enArb.containsKey(key), isTrue, reason: 'Missing EN arb: $key');
        expect(idArb.containsKey(key), isTrue, reason: 'Missing ID arb: $key');
      }
      expect(enMap.length, idMap.length);
    });
  });
}
