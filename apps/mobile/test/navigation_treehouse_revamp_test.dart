import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nestin/core/l10n/app_language.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/l10n/app_translations.dart';
import 'package:nestin/core/theme/app_colors.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/alarm_category.dart';
import 'package:nestin/data/models/journal_entry.dart';
import 'package:nestin/data/models/task_item.dart';
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
import 'package:nestin/ui/screens/home/home_dashboard_screen.dart';
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
import 'package:nestin/ui/widgets/nestin_wordmark.dart';
import 'package:nestin/ui/widgets/quick_capture_sheet.dart';
import 'package:nestin/ui/widgets/reading_progress_card.dart';

class _RevampTestEnv {
  final StorageService storage;
  final SettingsProvider settings;
  final RoutineProvider routines;
  final HydrationProvider hydration;
  final TaskProvider tasks;
  final NoteProvider notes;
  final MoneyProvider money;
  final JournalProvider journal;
  final NotificationService notifications;
  final AudioService audio;
  final LocalWeatherService weather;

  _RevampTestEnv._({
    required this.storage,
    required this.settings,
    required this.routines,
    required this.hydration,
    required this.tasks,
    required this.notes,
    required this.money,
    required this.journal,
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
    final routines = RoutineProvider(storage);
    final hydration = HydrationProvider(storage, notifications);
    final tasks = TaskProvider(storage);
    final notes = NoteProvider(storage);
    final money = MoneyProvider(storage);
    final journal = JournalProvider(storage);

    return _RevampTestEnv._(
      storage: storage,
      settings: settings,
      routines: routines,
      hydration: hydration,
      tasks: tasks,
      notes: notes,
      money: money,
      journal: journal,
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
        ChangeNotifierProvider<RoutineProvider>.value(value: routines),
        ChangeNotifierProvider<NoteProvider>.value(value: notes),
        ChangeNotifierProvider(create: (_) => CollectionProvider(storage)),
        ChangeNotifierProvider<JournalProvider>.value(value: journal),
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
        ChangeNotifierProvider<MoneyProvider>.value(value: money),
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
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
        await tester.pump(const Duration(milliseconds: 250));

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
          await tester.pump(const Duration(milliseconds: 150));
          await tester.tap(card);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 450));

          expect(find.byType(entry.value), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Navigate back cleanly to Nest Treehouse
          await tester.pageBack();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 450));
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
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.byKey(const Key('nest_brand_title')), findsOneWidget);
        expect(find.byKey(const Key('nest_greeting_text')), findsOneWidget);
        expect(find.byKey(const Key('nest_slim_status_pill')), findsOneWidget);
        expect(find.text('Waktu & Kebiasaan'), findsOneWidget);
        expect(find.text('Panduan Harian'), findsOneWidget);
        expect(find.text('Tenang & Sehat'), findsOneWidget);
        expect(find.text('Minat & Tumbuh'), findsOneWidget);
        expect(find.text('Catatan & Uang'), findsOneWidget);
        expect(find.text('Jurnal & Refleksi'), findsOneWidget);

        // Verify refined dark-mode card border, outer glow, radial halo & borderless full-pill chip
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
            color: RooHouseScreen.rooColor.withValues(alpha: 0.42),
            width: 1.0,
          ),
        );
        expect(rooDecoration.boxShadow, isNotEmpty);
        expect(rooDecoration.boxShadow!.first.blurRadius, 14);

        final rooPill = tester.widget<Container>(
          find.byKey(const Key('nest_bird_pill_roo')),
        );
        final rooPillDeco = rooPill.decoration! as BoxDecoration;
        expect(rooPillDeco.borderRadius, BorderRadius.circular(999));
        expect(rooPillDeco.border, isNull);
        expect(find.byKey(const Key('nest_bird_halo_roo')), findsOneWidget);

        // Tapping alarm segment of slim quick-status pill navigates to Roo's House
        await tester.tap(find.byKey(const Key('nest_slim_pill_alarm_tap')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        expect(find.byType(RooHouseScreen), findsOneWidget);
        Navigator.of(tester.element(find.byType(RooHouseScreen))).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();

        // Tapping weather segment of slim quick-status pill navigates to Scout's House
        await tester.tap(find.byKey(const Key('nest_slim_pill_weather_tap')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
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
        await tester.pump(const Duration(milliseconds: 250));

        // Default is Rooms Grid View (now with 6 animated flock sprites too!)
        expect(find.byKey(const Key('nest_bird_card_roo')), findsOneWidget);
        expect(find.byType(AnimatedMascotSprite), findsNWidgets(6));
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
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

    test('all 6 birds wire verified 2-frame pose packs, calm sequence interleaving & organic room pacing math', () {
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

      // Interleaved calm sequence returns to primary reactive pose between visits
      final seq = sprite.buildPoseSequence();
      expect(seq.first, 'assets/mascots/sprites/roo/welcome.png');
      expect(seq, containsAll(TreehouseMascotFrameSheets.rooBlinkFrames));
      expect(seq, containsAll(TreehouseMascotFrameSheets.rooFlutterFrames));
      expect(sprite.resolveActiveFrameAsset(0.0), seq.first);
      // Reduced motion always returns base primary frame
      expect(
        sprite.resolveActiveFrameAsset(0.55, disableAnimations: true),
        'assets/mascots/sprites/roo/welcome.png',
      );

      // Organic horizontal room pacing: bounded, pauses naturally, flips direction
      final pauseLeft = AnimatedMascotSprite.computePacingState(
        0.10,
        phaseOffset: 0.0,
        rangeLeft: 20,
        rangeRight: 22,
      );
      expect(pauseLeft.isWalking, isFalse);
      expect(pauseLeft.dx, -20.0);
      expect(pauseLeft.flipX, isFalse);

      final walkRight = AnimatedMascotSprite.computePacingState(
        0.36,
        phaseOffset: 0.0,
        rangeLeft: 20,
        rangeRight: 22,
      );
      expect(walkRight.isWalking, isTrue);
      expect(walkRight.dx, inInclusiveRange(-20.0, 22.0));
      expect(walkRight.flipX, isFalse);

      final pauseRight = AnimatedMascotSprite.computePacingState(
        0.60,
        phaseOffset: 0.0,
        rangeLeft: 20,
        rangeRight: 22,
      );
      expect(pauseRight.isWalking, isFalse);
      expect(pauseRight.dx, 22.0);
      expect(pauseRight.flipX, isTrue);

      final walkLeft = AnimatedMascotSprite.computePacingState(
        0.86,
        phaseOffset: 0.0,
        rangeLeft: 20,
        rangeRight: 22,
      );
      expect(walkLeft.isWalking, isTrue);
      expect(walkLeft.dx, inInclusiveRange(-20.0, 22.0));
      expect(walkLeft.flipX, isTrue);

      final reducedMotion = AnimatedMascotSprite.computePacingState(
        0.36,
        phaseOffset: 0.0,
        rangeLeft: 20,
        rangeRight: 22,
        disableAnimations: true,
      );
      expect(reducedMotion.dx, 0.0);
      expect(reducedMotion.isWalking, isFalse);
    });
  });

  group('Phase 1 UI Redesign — Shell, 2×3 Rooms Grid & Interactive Cutaway Rooms', () {
    testWidgets(
      'top bar uses gear icon, transparent floating AppBar in Treehouse Scene, 24dp extra FAB clearance & 48dp touch targets',
      (tester) async {
        _setNarrowViewport(tester);
        final env = await _RevampTestEnv.create(themeMode: ThemeMode.light);

        await tester.pumpWidget(env.wrap(const MainNavigationScreen()));
        await tester.pump(const Duration(milliseconds: 250));

        // Verify bottom dock 48x48dp minimum touch targets
        for (final key in const [
          Key('nav_slot_dashboard'),
          Key('nav_slot_quick_capture'),
          Key('nav_slot_nest'),
        ]) {
          final size = tester.getSize(find.byKey(key));
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }

        // Switch to Nest tab
        await tester.tap(find.byKey(const Key('nav_slot_nest')));
        await tester.pump(const Duration(milliseconds: 300));

        // Top-right settings uses gear icon (Icons.settings_outlined), not sliders
        expect(
          find.descendant(
            of: find.byKey(const Key('nest_settings_btn')),
            matching: find.byIcon(Icons.settings_outlined),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('nest_top_app_bar')),
            matching: find.byIcon(Icons.tune_rounded),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('nest_search_btn')),
            matching: find.byIcon(Icons.search_rounded),
          ),
          findsOneWidget,
        );

        // Top bar icons & inline banner tap targets meet 48x48dp minimum
        for (final key in const [
          Key('nest_view_mode_toggle_btn'),
          Key('nest_search_btn'),
          Key('nest_settings_btn'),
          Key('nest_slim_pill_alarm_tap'),
          Key('nest_slim_pill_weather_tap'),
        ]) {
          final size = tester.getSize(find.byKey(key));
          expect(size.width, greaterThanOrEqualTo(48), reason: '$key width');
          expect(size.height, greaterThanOrEqualTo(48), reason: '$key height');
        }

        // Grid mode: Light Mode pure #FFFFFF top banner & 6 cards matching exact 18dp radius + soft shadow
        final bannerContainer = tester.widget<Container>(
          find.byKey(const Key('nest_time_banner')),
        );
        final bannerDeco = bannerContainer.decoration! as BoxDecoration;
        expect(bannerDeco.border, isNull);
        expect(bannerDeco.color, AppColors.lightCard);
        expect(bannerDeco.borderRadius, BorderRadius.circular(18));
        expect(bannerDeco.boxShadow, isNotEmpty);
        expect(bannerDeco.boxShadow!.first.blurRadius, 12);
        expect(bannerDeco.boxShadow!.first.offset, const Offset(0, 4));

        final lightCardContainer = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(const Key('nest_bird_card_roo')),
                matching: find.byType(Container),
              )
              .first,
        );
        final lightCardDeco = lightCardContainer.decoration! as BoxDecoration;
        expect(lightCardDeco.color, AppColors.lightCard);
        expect(lightCardDeco.borderRadius, BorderRadius.circular(18));
        expect(lightCardDeco.boxShadow, isNotEmpty);
        expect(lightCardDeco.boxShadow!.first.blurRadius, 12);
        expect(lightCardDeco.boxShadow!.first.offset, const Offset(0, 4));
        expect(
          lightCardDeco.boxShadow!.first.color,
          Colors.black.withValues(alpha: 0.05),
        );

        // Switch to Illustrated Cutaway Treehouse Scene in Light Mode
        await tester.tap(find.byKey(const Key('nest_view_mode_toggle_btn')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Transparent floating AppBar over the sky (no harsh gray bar in Light Mode)
        final scaffold = tester.widget<Scaffold>(
          find.byKey(const Key('nest_treehouse_screen')),
        );
        expect(scaffold.extendBodyBehindAppBar, isTrue);
        final appBar = tester.widget<AppBar>(
          find.byKey(const Key('nest_top_app_bar')),
        );
        expect(appBar.backgroundColor, Colors.transparent);

        // Bottom hint clears the raised (+) Quick Capture FAB by at least 24dp
        final fabRect = tester.getRect(
          find.byKey(const Key('nav_slot_quick_capture')),
        );
        final hintRect = tester.getRect(
          find.byKey(const Key('nest_scene_tap_hint_pill')),
        );
        expect(
          fabRect.top - hintRect.bottom,
          greaterThanOrEqualTo(24.0),
          reason: 'Hint pill must sit >= 24dp above raised + FAB',
        );

        // Scene top status targets, phase chips & all 6 cutaway rooms >= 48x48dp
        for (final key in const [
          Key('nest_scene_top_alarm_tap'),
          Key('nest_scene_top_weather_tap'),
          Key('nest_scene_phase_chip_auto'),
          Key('nest_scene_phase_chip_dawn'),
          Key('nest_scene_phase_chip_day'),
          Key('nest_scene_phase_chip_sunset'),
          Key('nest_scene_phase_chip_night'),
          Key('nest_scene_room_echo'),
          Key('nest_scene_room_roo'),
          Key('nest_scene_room_scout'),
          Key('nest_scene_room_seren'),
          Key('nest_scene_room_pippin'),
          Key('nest_scene_room_twill'),
        ]) {
          final size = tester.getSize(find.byKey(key));
          expect(size.width, greaterThanOrEqualTo(48), reason: '$key width');
          expect(size.height, greaterThanOrEqualTo(48), reason: '$key height');
        }

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Echo gratitude counter formats singular vs plural cleanly in EN and ID, and renders zero overflows at 390dp',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final env = await _RevampTestEnv.create(
          language: AppLanguage.en,
          themeMode: ThemeMode.dark,
        );

        // Default seeded journal has 1 gratitude pebble -> singular "1 pebble"
        await tester.pumpWidget(
          env.wrap(
            NestTreehouseScreen(
              clockOverride: DateTime(2026, 11, 24, 21, 0),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('Mood • 1 pebble'), findsOneWidget);
        expect(find.text('Mood • 1 pebbles'), findsNothing);

        // Add a 2nd gratitude pebble -> plural "2 pebbles"
        final now = DateTime(2026, 11, 24, 21, 5);
        await env.journal.addJournalEntry(
          JournalEntry(
            id: 'entry_second_pebble',
            title: 'Evening Tea',
            content: 'Calm evening wind-down.',
            date: now,
            mood: JournalMood.good,
            gratitudeNote: 'Warm lavender tea before sleep.',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Mood • 2 pebbles'), findsOneWidget);

        // Verify in Treehouse Scene mode too
        await env.settings.setNestViewMode(NestViewMode.treehouseScene);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Echo • 2 pebbles'), findsOneWidget);

        // Switch to Bahasa Indonesia -> "Echo • 2 kerikil"
        await env.settings.setLanguage(AppLanguage.id);
        await tester.pumpWidget(
          env.wrap(
            NestTreehouseScreen(
              clockOverride: DateTime(2026, 11, 24, 21, 0),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Echo • 2 kerikil'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'wires full-room tap, reactive sprites (Seren refreshed, Roo on_fire, Twill budgeted) & long-press micro-actions',
      (tester) async {
        _setNarrowViewport(tester);
        final env = await _RevampTestEnv.create(themeMode: ThemeMode.dark);
        await env.settings.setNestViewMode(NestViewMode.treehouseScene);

        final now = DateTime(2026, 11, 24, 14, 0);
        // Set on-budget monthly budget so Twill swaps to twill/budgeted.png
        await env.money.setMonthlyBudget(
          year: now.year,
          month: now.month,
          limitMinor: 500000,
        );

        await tester.pumpWidget(
          env.wrap(
            NestTreehouseScreen(clockOverride: now),
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));

        AnimatedMascotSprite spriteFor(String birdKey) =>
            tester.widget<AnimatedMascotSprite>(
              find.descendant(
                of: find.byKey(Key(birdKey)),
                matching: find.byType(AnimatedMascotSprite),
              ),
            );

        // Roo has seeded active streak (3d) -> roo/on_fire.png
        expect(
          spriteFor('nest_scene_bird_roo').spriteAsset,
          'assets/mascots/sprites/roo/on_fire.png',
        );
        // Twill has active healthy monthly budget -> twill/budgeted.png
        expect(
          spriteFor('nest_scene_bird_twill').spriteAsset,
          'assets/mascots/sprites/twill/budgeted.png',
        );
        // Seren starts below goal (0/8) -> seren/hello.png
        expect(
          spriteFor('nest_scene_bird_seren').spriteAsset,
          'assets/mascots/sprites/seren/hello.png',
        );

        // Long-press Seren's cutaway room -> logs +1 Glass inline!
        final initialGlasses = env.hydration.glassesConsumed;
        await tester.longPress(find.byKey(const Key('nest_scene_room_seren')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(env.hydration.glassesConsumed, initialGlasses + 1);
        expect(find.text('Seren logged +1 glass (1/8)'), findsOneWidget);

        // Reach 100% hydration -> Seren swaps live to seren/refreshed.png
        await tester.runAsync(
          () => env.hydration.addGlass(env.hydration.dailyGoalGlasses),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(env.hydration.isGoalMet, isTrue);
        expect(
          spriteFor('nest_scene_bird_seren').spriteAsset,
          'assets/mascots/sprites/seren/refreshed.png',
        );

        // Long-press Roo's cutaway room -> toggles next alarm off!
        final alarmProvider = Provider.of<AlarmProvider>(
          tester.element(find.byType(NestTreehouseScreen)),
          listen: false,
        );
        final nextBefore = alarmProvider.nextUpcomingAlarm;
        expect(nextBefore, isNotNull);
        await tester.longPress(find.byKey(const Key('nest_scene_room_roo')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final toggledOff =
            alarmProvider.alarms.firstWhere((a) => a.id == nextBefore!.id);
        expect(toggledOff.isEnabled, isFalse);

        // Tap inside an outer corner of Echo's cutaway room (away from sprite center) -> opens EchoHouseScreen
        final echoRoomRect =
            tester.getRect(find.byKey(const Key('nest_scene_room_echo')));
        await tester.tapAt(
          Offset(echoRoomRect.right - 10, echoRoomRect.top + 14),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(EchoHouseScreen), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Phase 2 UI Redesign — Decluttered HomeDashboardScreen & Refined 3-Zone QuickCaptureSheet', () {
    testWidgets(
      'HomeDashboardScreen renders 4 calm blocks, Light Mode #FFFFFF depth, tabular clock/counters, 48dp targets & inline interactions on 360dp',
      (tester) async {
        _setNarrowViewport(tester);
        final env = await _RevampTestEnv.create(themeMode: ThemeMode.light);

        // Use a deterministic future date so seeded "today" tasks don't crowd out
        // our test task from the balanced 5-item Agenda & Tasks cap.
        final now = DateTime(2026, 12, 15, 9, 15);
        await env.tasks.addTask(
          TaskItem(
            id: 'phase2_task_1',
            title: 'Finish UI review',
            priority: TaskPriority.high,
            dueDate: now,
            category: AlarmCategory.fromType(AlarmCategoryType.work),
            createdAt: now,
          ),
        );

        int? navigatedTab;
        int? navigatedSubTab;
        await tester.pumpWidget(
          env.wrap(
            HomeDashboardScreen(
              clockOverride: now,
              onNavigateTab: (tab, [subTab]) {
                navigatedTab = tab;
                navigatedSubTab = subTab;
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();

        // Top bar uses gear icon (matching Phase 1) and 48x48dp action targets
        expect(
          find.descendant(
            of: find.byKey(const Key('dashboard_settings_btn')),
            matching: find.byIcon(Icons.settings_outlined),
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.tune_rounded), findsNothing);
        for (final key in const [
          Key('dashboard_customize_btn'),
          Key('dashboard_search_btn'),
          Key('dashboard_settings_btn'),
          Key('dashboard_morning_briefing_btn'),
          Key('dashboard_inline_weather_tap'),
          Key('dashboard_inline_byg_tap'),
          Key('dashboard_alarm_test_btn'),
          Key('dashboard_alarm_open_btn'),
          Key('dashboard_agenda_view_all_btn'),
          Key('dashboard_add_glass_btn'),
          Key('dashboard_mood_checkin_btn'),
        ]) {
          expect(find.byKey(key), findsOneWidget, reason: 'Expected $key');
          final size = tester.getSize(find.byKey(key));
          expect(size.width, greaterThanOrEqualTo(48), reason: '$key width');
          expect(size.height, greaterThanOrEqualTo(48), reason: '$key height');
        }

        // Block 1: Borderless greeting strip with inline weather & BeforeYouGo
        final greetingBox = tester.widget<Container>(
          find.byKey(const Key('dashboard_greeting_strip')),
        );
        final greetingDeco = greetingBox.decoration! as BoxDecoration;
        expect(greetingDeco.border, isNull);
        expect(find.byKey(const Key('dashboard_weather_byg_strip')), findsOneWidget);

        // Block 2: Hero Next Alarm card uses #FFFFFF + soft shadow in Light Mode, tabular clock (28-34sp) & borderless pills
        final alarmContainer = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(const Key('dashboard_next_alarm_hero')),
                matching: find.byType(Container),
              )
              .first,
        );
        final alarmDeco = alarmContainer.decoration! as BoxDecoration;
        expect(alarmDeco.color, AppColors.lightCard);
        expect(alarmDeco.border, isNull);
        expect(alarmDeco.boxShadow, isNotEmpty);
        expect(alarmDeco.boxShadow!.first.blurRadius, 12);
        expect(alarmDeco.boxShadow!.first.offset, const Offset(0, 4));

        final clockText = tester.widget<Text>(
          find.byKey(const Key('dashboard_next_alarm_clock')),
        );
        expect(clockText.style?.fontSize, inInclusiveRange(28, 34));
        expect(
          clockText.style?.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );

        final countdownPill = tester.widget<Container>(
          find.byKey(const Key('dashboard_alarm_countdown_pill')),
        );
        final countdownDeco = countdownPill.decoration! as BoxDecoration;
        expect(countdownDeco.borderRadius, BorderRadius.circular(999));
        expect(countdownDeco.border, isNull);

        // Block 3: Unified Agenda & Tasks card with 48dp checkbox, priority dot & "View all" -> Roo's House (tab 1, null)
        final checkboxFinder =
            find.byKey(const Key('dashboard_task_checkbox_phase2_task_1'));
        expect(checkboxFinder, findsOneWidget);
        expect(tester.getSize(checkboxFinder).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(checkboxFinder).height, greaterThanOrEqualTo(48));
        expect(
          find.byKey(const Key('dashboard_task_priority_dot_phase2_task_1')),
          findsOneWidget,
        );
        await tester.ensureVisible(checkboxFinder);
        await tester.tap(checkboxFinder);
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          env.tasks.tasks.firstWhere((t) => t.id == 'phase2_task_1').isCompleted,
          isTrue,
        );

        await tester.ensureVisible(
          find.byKey(const Key('dashboard_agenda_view_all_btn')),
        );
        await tester.tap(find.byKey(const Key('dashboard_agenda_view_all_btn')));
        await tester.pump();
        expect(navigatedTab, 1);
        expect(navigatedSubTab, isNull);

        // Block 4: 2-Column Quick Check-In Bar (Hydration +1 Glass & Echo Mood)
        expect(
          find.byKey(const Key('dashboard_quick_checkin_bar')),
          findsOneWidget,
        );
        final counterText = tester.widget<Text>(
          find.byKey(const Key('dashboard_hydration_counter')),
        );
        expect(
          counterText.style?.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
        final beforeGlasses = env.hydration.glassesConsumed;
        final addGlassBtn = find.byKey(const Key('dashboard_add_glass_btn'));
        await tester.ensureVisible(addGlassBtn);
        await tester.tap(addGlassBtn);
        await tester.pump(const Duration(milliseconds: 150));
        expect(env.hydration.glassesConsumed, beforeGlasses + 1);

        // Mood Check-in opens clean 5-mood sheet and logs feeling
        final moodBtn = find.byKey(const Key('dashboard_mood_checkin_btn'));
        await tester.ensureVisible(moodBtn);
        await tester.tap(moodBtn);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('dashboard_mood_option_great')), findsOneWidget);
        await tester.tap(find.byKey(const Key('dashboard_mood_option_great')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('dashboard_today_mood_pill')), findsOneWidget);

        // Morning Briefing button opens Daily Briefing dialog
        final briefingBtn = find.byKey(const Key('dashboard_morning_briefing_btn'));
        await tester.ensureVisible(briefingBtn);
        await tester.tap(briefingBtn);
        await tester.pumpAndSettle();
        expect(find.text('Daily Briefing'), findsOneWidget);
        Navigator.of(tester.element(find.text('Daily Briefing'))).pop();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'HomeDashboardScreen shows calm + Set Alarm empty state when all alarms off and renders cleanly in Dark Mode + ID at 390dp',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final env = await _RevampTestEnv.create(
          language: AppLanguage.id,
          themeMode: ThemeMode.dark,
        );

        await tester.pumpWidget(
          env.wrap(
            HomeDashboardScreen(
              clockOverride: DateTime(2026, 11, 24, 20, 30),
              onNavigateTab: (_, [_]) {},
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        // Toggle off all active alarms via AlarmProvider -> calm "+ Atur Alarm" empty state
        final alarmProvider = Provider.of<AlarmProvider>(
          tester.element(find.byType(HomeDashboardScreen)),
          listen: false,
        );
        for (final a in List.of(alarmProvider.alarms)) {
          if (a.isEnabled) {
            await alarmProvider.toggleAlarm(a.id, false);
          }
        }
        await tester.pump(const Duration(milliseconds: 150));

        expect(find.byKey(const Key('dashboard_set_alarm_btn')), findsOneWidget);
        expect(find.text('+ Atur Alarm'), findsOneWidget);
        expect(find.text('Agenda Hari Ini'), findsOneWidget);
        expect(find.text('Lihat semua'), findsOneWidget);
        expect(find.text('Suasana Hati'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'QuickCaptureSheet uses 24dp radius, borderless pills, Date/Priority optional chips, 48dp targets & zero overflow with soft keyboard open at 360dp',
      (tester) async {
        _setNarrowViewport(tester);
        final env = await _RevampTestEnv.create(themeMode: ThemeMode.dark);

        await tester.pumpWidget(
          env.wrap(
            const Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: QuickCaptureSheet(initialType: CaptureType.task),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Sheet uses 24dp top radius and sheetSurface
        final sheetContainer = tester.widget<Container>(
          find.byKey(const Key('quick_capture_sheet_container')),
        );
        final sheetDeco = sheetContainer.decoration! as BoxDecoration;
        expect(
          sheetDeco.borderRadius,
          const BorderRadius.vertical(top: Radius.circular(24)),
        );
        expect(sheetDeco.color, AppColors.darkSheet);

        // Zone 3 Calm Anchor is borderless full-pill soft lavender
        final calmBox = tester.widget<Container>(
          find.byKey(const Key('qc_zone_calm_anchor')),
        );
        final calmDeco = calmBox.decoration! as BoxDecoration;
        expect(calmDeco.border, isNull);
        expect(calmDeco.borderRadius, BorderRadius.circular(999));

        // Touch targets >= 48dp on type pills, optional chips, Save, Quick Actions & Calm Anchor
        for (final key in const [
          Key('qc_type_pill_task'),
          Key('qc_type_pill_note'),
          Key('qc_toggle_datetime_chip'),
          Key('qc_toggle_priority_chip'),
          Key('qc_toggle_category_chip'),
          Key('qc_toggle_notes_chip'),
          Key('qc_save_btn'),
          Key('qc_action_money'),
          Key('qc_action_alarm'),
          Key('qc_action_before_you_go'),
          Key('qc_action_add_glass'),
          Key('qc_mental_aid_chip'),
        ]) {
          final size = tester.getSize(find.byKey(key));
          expect(size.width, greaterThanOrEqualTo(48), reason: '$key width');
          expect(size.height, greaterThanOrEqualTo(48), reason: '$key height');
        }

        // Priority optional chip sets Urgent priority on saved Task
        await tester.tap(find.byKey(const Key('qc_toggle_priority_chip')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('qc_priority_urgent')));
        await tester.pumpAndSettle();

        // Date/Time optional chip sets Tomorrow preset cleanly
        await tester.tap(find.byKey(const Key('qc_toggle_datetime_chip')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('qc_date_tomorrow_btn')));
        await tester.pumpAndSettle();

        // Simulate soft keyboard open (viewInsets.bottom = 300) on 360dp narrow width -> zero RenderFlex overflow & lower zones collapsed.
        // Mirror showModalBottomSheet (no outer Scaffold consuming viewInsets) by placing MediaQuery inside Scaffold.body.
        for (final mode in const [ThemeMode.dark, ThemeMode.light]) {
          await tester.pumpWidget(
            env.wrap(
              overrideThemeMode: mode,
              const Scaffold(
                resizeToAvoidBottomInset: false,
                body: MediaQuery(
                  data: MediaQueryData(
                    size: Size(360, 780),
                    viewInsets: EdgeInsets.only(bottom: 300),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: QuickCaptureSheet(initialType: CaptureType.task),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('qc_zones_collapsed')), findsOneWidget);
          expect(find.byKey(const Key('qc_zone_quick_actions')), findsNothing);
          expect(find.byKey(const Key('qc_zone_calm_anchor')), findsNothing);
          expect(tester.takeException(), isNull);
        }
      },
    );
  });

  group('Phase 1.5 Polish Pass — Leaf Green Brand, Floating Pill Dock, Calm Pacing & 2×3 Glow Borders', () {
    test('AppColors & AppTheme use Nestin Leaf Green globally while keeping Roo strictly Crimson', () {
      expect(AppColors.primary, const Color(0xFF649330));
      expect(AppColors.primaryLight, const Color(0xFF7CB342));
      expect(AppColors.rooCrimson, const Color(0xFFE04A3A));
      expect(RooHouseScreen.rooColor, const Color(0xFFE04A3A));
      expect(AppTheme.lightTheme.colorScheme.primary, const Color(0xFF649330));
      expect(AppTheme.darkTheme.colorScheme.primary, const Color(0xFF7CB342));
    });

    testWidgets(
      'renders lowercase nestin wordmark & undocked floating pill dock in Light & Dark modes at 360dp and 390dp with zero overflows',
      (tester) async {
        for (final size in const [Size(360, 780), Size(390, 844)]) {
          for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;

            final env = await _RevampTestEnv.create(themeMode: mode);
            await tester.pumpWidget(
              env.wrap(
                MainNavigationScreen(
                  key: ValueKey('main_${size.width.toInt()}_${mode.name}'),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 250));

            // Dashboard top bar renders NestinWordmark with lowercase "nest" + Leaf Green "in"
            final dashWordmark = tester.widget<Text>(
              find.byKey(const Key('dashboard_brand_title')),
            );
            final dashSpan = dashWordmark.textSpan! as TextSpan;
            expect(dashSpan.toPlainText(), 'nestin');
            final nestSpan = dashSpan.children![0] as TextSpan;
            final inSpan = dashSpan.children![1] as TextSpan;
            expect(nestSpan.text, 'nest');
            expect(inSpan.text, 'in');
            expect(
              nestSpan.style?.color,
              mode == ThemeMode.dark
                  ? AppColors.wordmarkOffWhite
                  : AppColors.wordmarkCharcoal,
            );
            expect(
              inSpan.style?.color,
              mode == ThemeMode.dark
                  ? AppColors.primaryLight
                  : AppColors.primary,
            );

            // Undocked floating pill dock is horizontally inset (16-20dp) & floats above bottom edge (12-16dp)
            final dockRect = tester.getRect(
              find.byKey(const Key('main_floating_pill_dock')),
            );
            expect(dockRect.left, inInclusiveRange(16.0, 20.0));
            expect(size.width - dockRect.right, inInclusiveRange(16.0, 20.0));
            expect(size.height - dockRect.bottom, inInclusiveRange(12.0, 16.0));
            final dockContainer = tester.widget<Container>(
              find.byKey(const Key('main_floating_pill_dock')),
            );
            final dockDeco = dockContainer.decoration! as BoxDecoration;
            expect(dockDeco.borderRadius, BorderRadius.circular(30));

            // Center raised (+) Quick Capture button is Nestin Leaf Green
            final fabContainer = tester.widget<Container>(
              find
                  .descendant(
                    of: find.byKey(const Key('nav_slot_quick_capture')),
                    matching: find.byType(Container),
                  )
                  .first,
            );
            final fabDeco = fabContainer.decoration! as BoxDecoration;
            expect(
              fabDeco.color,
              mode == ThemeMode.dark
                  ? AppColors.primaryLight
                  : AppColors.primary,
            );

            // Switch to Nest tab -> verify Grid wordmark, 6 animated birds & 6 moving glow borders
            await tester.tap(find.byKey(const Key('nav_slot_nest')));
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.byType(NestinWordmark), findsAtLeastNWidgets(1));
            expect(
              find.byKey(const Key('nest_bird_glow_border_roo')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('nest_bird_glow_border_echo')),
              findsOneWidget,
            );
            expect(
              find.descendant(
                of: find.byKey(const Key('nest_grid_ticker_mode')),
                matching: find.byType(AnimatedMascotSprite),
              ),
              findsNWidgets(6),
            );
            expect(tester.takeException(), isNull);
          }
        }
        tester.view.reset();
      },
    );

    testWidgets(
      'calm 7-11s pose switching holds smoothly without rapid glitch swaps & Grid TickerMode pauses off-tab and under reduced motion',
      (tester) async {
        _setNarrowViewport(tester);
        final env = await _RevampTestEnv.create(themeMode: ThemeMode.dark);

        // 1. Calm pose switch timing check on AnimatedMascotSprite
        final spriteKey = GlobalKey<AnimatedMascotSpriteState>();
        await tester.pumpWidget(
          env.wrap(
            Scaffold(
              body: Center(
                child: AnimatedMascotSprite(
                  key: spriteKey,
                  spriteAsset: 'assets/mascots/sprites/roo/welcome.png',
                  blinkFrames: TreehouseMascotFrameSheets.rooBlinkFrames,
                  flutterFrames: TreehouseMascotFrameSheets.rooFlutterFrames,
                  size: 64,
                  accentColor: RooHouseScreen.rooColor,
                  fallbackIcon: Icons.alarm_rounded,
                  ambientAnimation: const AlwaysStoppedAnimation<double>(0.2),
                  phaseOffset: 0.0,
                  poseSwitchInterval: const Duration(milliseconds: 8000),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          spriteKey.currentState!.currentPoseAsset,
          'assets/mascots/sprites/roo/welcome.png',
        );
        // After 1 second (previously glitched rapidly), pose stays completely steady
        await tester.pump(const Duration(seconds: 1));
        expect(
          spriteKey.currentState!.currentPoseAsset,
          'assets/mascots/sprites/roo/welcome.png',
        );
        // After calm staggered delay + interval elapses, smoothly switches via 450ms AnimatedSwitcher
        await tester.pump(const Duration(seconds: 8));
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          spriteKey.currentState!.currentPoseAsset,
          TreehouseMascotFrameSheets.rooBlinkFrames.first,
        );

        // 2. Grid Mode pauses TickerMode when inactive or disableAnimations: true
        await tester.pumpWidget(
          env.wrap(const NestTreehouseScreen(isActive: false)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          tester
              .widget<TickerMode>(find.byKey(const Key('nest_grid_ticker_mode')))
              .enabled,
          isFalse,
        );

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              disableAnimations: true,
            ),
            child: env.wrap(const NestTreehouseScreen(isActive: true)),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TickerMode>(find.byKey(const Key('nest_grid_ticker_mode')))
              .enabled,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '6-room living animations paint cleanly across Clear, Cool Breeze & Heavy Rain weather scenarios',
      (tester) async {
        _setNarrowViewport(tester);
        final env = await _RevampTestEnv.create(themeMode: ThemeMode.dark);
        await env.settings.setNestViewMode(NestViewMode.treehouseScene);

        final weatherScenarios = [
          const WeatherInfo(
            temperatureCelsius: 29,
            condition: 'Partly Sunny',
            locationName: 'Nest',
            highTemp: 31,
            lowTemp: 24,
            rainChancePercent: 10,
            advice: 'Warm sunshine.',
          ),
          const WeatherInfo(
            temperatureCelsius: 18,
            condition: 'Cool Breeze',
            locationName: 'Nest',
            highTemp: 21,
            lowTemp: 15,
            rainChancePercent: 15,
            advice: 'Breezy air.',
          ),
          const WeatherInfo(
            temperatureCelsius: 14,
            condition: 'Heavy Rain & Wind',
            locationName: 'Nest',
            highTemp: 17,
            lowTemp: 12,
            rainChancePercent: 85,
            advice: 'Pack waterproof gear.',
          ),
        ];

        for (final info in weatherScenarios) {
          env.weather.setOverrideWeather(info);
          await tester.pumpWidget(
            env.wrap(
              NestTreehouseScreen(
                clockOverride: DateTime(2026, 11, 24, 15, 0),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(seconds: 2));
          expect(find.byKey(const Key('nest_scene_room_effects')), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
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
        'nest_pill_echo_pebble_one',
        'nest_scene_pill_echo_pebble_one',
        'nest_pill_roo_alarm_task_one',
        'nest_pill_roo_task_one',
        'nest_scene_pill_roo_task_one',
        'nest_pill_twill_note_one',
        'nest_scene_pill_twill_note_one',
        'nest_micro_seren_glass_logged',
        'nest_micro_seren_goal_reached',
        'nest_micro_roo_alarm_off',
        'nest_micro_roo_alarm_on',
        'dash_view_all',
        'dash_set_alarm_cta',
        'dash_open_alarms',
        'dash_today_clear',
        'dash_mood_label',
        'dash_mood_checkin_cta',
        'dash_mood_prompt',
        'dash_open_diary',
        'dash_checkin_bar_title',
        'qc_datetime_chip',
        'qc_pick_date',
        'qc_pick_time',
        'qc_clear_date',
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
