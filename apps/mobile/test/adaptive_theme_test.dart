import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/theme/app_colors.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/challenge_profile.dart';
import 'package:nestin/data/services/audio_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/oem_hardening_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/data/services/weather_service.dart';
import 'package:nestin/providers/alarm_provider.dart';
import 'package:nestin/providers/before_you_go_provider.dart';
import 'package:nestin/providers/calendar_provider.dart';
import 'package:nestin/providers/collection_provider.dart';
import 'package:nestin/providers/dashboard_provider.dart';
import 'package:nestin/providers/geofence_provider.dart';
import 'package:nestin/providers/health_wellness_provider.dart';
import 'package:nestin/providers/hobby_provider.dart';
import 'package:nestin/providers/hydration_provider.dart';
import 'package:nestin/providers/journal_provider.dart';
import 'package:nestin/providers/medication_provider.dart';
import 'package:nestin/providers/money_provider.dart';
import 'package:nestin/providers/note_provider.dart';
import 'package:nestin/providers/oem_hardening_provider.dart';
import 'package:nestin/providers/reading_provider.dart';
import 'package:nestin/providers/reminder_provider.dart';
import 'package:nestin/providers/routine_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/providers/sleep_wellness_provider.dart';
import 'package:nestin/providers/sound_provider.dart';
import 'package:nestin/providers/task_provider.dart';
import 'package:nestin/providers/timer_provider.dart';
import 'package:nestin/providers/wearable_provider.dart';
import 'package:nestin/ui/screens/alarms/sound_picker_sheet.dart';
import 'package:nestin/ui/screens/challenges/challenge_modal_dialog.dart';
import 'package:nestin/ui/screens/explore/explore_hub_screen.dart';
import 'package:nestin/ui/screens/home/home_dashboard_screen.dart';
import 'package:nestin/ui/screens/organize/money/money_hub_screen.dart';
import 'package:nestin/ui/screens/organize/notes_list_screen.dart';
import 'package:nestin/ui/screens/organize/wishlist_screen.dart';
import 'package:nestin/ui/screens/reminders/reminders_list_screen.dart';
import 'package:nestin/ui/screens/settings/settings_screen.dart';
import 'package:nestin/ui/screens/time/calendar_screen.dart';
import 'package:nestin/ui/screens/time/tasks_screen.dart';
import 'package:nestin/ui/widgets/hydration_settings_sheet.dart';
import 'package:nestin/ui/widgets/quick_capture_sheet.dart';
import 'package:nestin/ui/widgets/sleep_cycle_sheet.dart';

const Set<int> _bannedDarkSurfaceHexValues = {
  0xFF111215,
  0xFF141519,
  0xFF15161C,
  0xFF16171D,
  0xFF181A20,
  0xFF1A1B20,
  0xFF1E1F26,
  0xFF1E2028,
  0xFF1F212B,
  0xFF23252C,
  0xFF252834,
  0xFF282A32,
  0xFF2B2D36,
};

class _TestEnv {
  final StorageService storage;
  final SettingsProvider settings;
  final AudioService audio;
  final NotificationService notifications;
  final OemHardeningProvider oem;

  _TestEnv({
    required this.storage,
    required this.settings,
    required this.audio,
    required this.notifications,
    required this.oem,
  });

  static Future<_TestEnv> create({ThemeMode themeMode = ThemeMode.light}) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
    final settings = SettingsProvider(storage);
    await settings.setThemeMode(themeMode);
    final oemService = MockOemHardeningService(
      manufacturer: 'Pixel',
      brand: 'Google',
      model: 'Pixel 9',
      isIgnoringBatteryOptimizations: true,
      isKeepAliveRunning: false,
    );
    return _TestEnv(
      storage: storage,
      settings: settings,
      audio: AudioService(),
      notifications: NotificationService(),
      oem: OemHardeningProvider(storage, oemService),
    );
  }

  Widget wrap(Widget child, {ThemeMode? overrideThemeMode}) {
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        Provider<NotificationService>.value(value: notifications),
        Provider<WeatherProviderInterface>(
          create: (_) => LocalWeatherService(),
        ),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<SoundProvider>(
          create: (_) => SoundProvider(storage),
        ),
        ChangeNotifierProvider<AlarmProvider>(
          create: (_) => AlarmProvider(storage, audio, notifications),
        ),
        ChangeNotifierProvider<ReminderProvider>(
          create: (_) => ReminderProvider(storage, notifications),
        ),
        ChangeNotifierProvider<TimerProvider>(
          create: (_) => TimerProvider(storage, notifications, audio),
        ),
        ChangeNotifierProvider<CalendarProvider>(
          create: (_) => CalendarProvider(storage),
        ),
        ChangeNotifierProvider<TaskProvider>(
          create: (_) => TaskProvider(storage),
        ),
        ChangeNotifierProvider<RoutineProvider>(
          create: (_) => RoutineProvider(storage),
        ),
        ChangeNotifierProvider<NoteProvider>(
          create: (_) => NoteProvider(storage),
        ),
        ChangeNotifierProvider<CollectionProvider>(
          create: (_) => CollectionProvider(storage),
        ),
        ChangeNotifierProvider<JournalProvider>(
          create: (_) => JournalProvider(storage),
        ),
        ChangeNotifierProvider<DashboardProvider>(
          create: (_) => DashboardProvider(storage),
        ),
        ChangeNotifierProvider<WearableProvider>(
          create: (_) => WearableProvider(storage),
        ),
        ChangeNotifierProvider<HydrationProvider>(
          create: (_) => HydrationProvider(storage, notifications),
        ),
        ChangeNotifierProvider<SleepWellnessProvider>(
          create: (_) => SleepWellnessProvider(storage, notifications),
        ),
        ChangeNotifierProvider<OemHardeningProvider>.value(value: oem),
        ChangeNotifierProvider<MedicationProvider>(
          create: (_) => MedicationProvider(storage, notifications),
        ),
        ChangeNotifierProvider<HobbyProvider>(
          create: (_) => HobbyProvider(storage),
        ),
        ChangeNotifierProvider<HealthWellnessProvider>(
          create: (_) => HealthWellnessProvider(storage, notifications),
        ),
        ChangeNotifierProvider<ReadingProvider>(
          create: (_) => ReadingProvider(storage),
        ),
        ChangeNotifierProvider<GeofenceProvider>(
          create: (_) => GeofenceProvider(
            storage,
            notifications,
            autoInitializeNative: false,
          ),
        ),
        ChangeNotifierProvider<MoneyProvider>(
          create: (_) => MoneyProvider(storage),
        ),
        ChangeNotifierProvider<BeforeYouGoProvider>(
          create: (_) => BeforeYouGoProvider(storage, notifications),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: overrideThemeMode ?? settings.themeMode,
        home: child,
      ),
    );
  }
}

void _expectNoHardcodedDarkSurfaces(WidgetTester tester, String label) {
  for (final widget in tester.allWidgets) {
    Color? surfaceColor;
    if (widget is Scaffold) {
      surfaceColor = widget.backgroundColor;
    } else if (widget is Card) {
      surfaceColor = widget.color;
    } else if (widget is Dialog) {
      surfaceColor = widget.backgroundColor;
    } else if (widget is Material) {
      surfaceColor = widget.color;
    } else if (widget is Container) {
      if (widget.color != null) {
        surfaceColor = widget.color;
      } else if (widget.decoration is BoxDecoration) {
        surfaceColor = (widget.decoration! as BoxDecoration).color;
      }
    }
    if (surfaceColor != null) {
      expect(
        _bannedDarkSurfaceHexValues.contains(surfaceColor.toARGB32()),
        isFalse,
        reason:
            '$label leaked hardcoded dark surface 0x${surfaceColor.toARGB32().toRadixString(16).toUpperCase()} on ${widget.runtimeType}',
      );
    }
  }
}

void _configureMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('Adaptive Theme Tokens & Persistence', () {
    test('AppTheme defines distinct light and dark palettes & surface hierarchy',
        () {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      expect(light.brightness, Brightness.light);
      expect(light.scaffoldBackgroundColor, AppColors.lightBg);
      expect(light.colorScheme.surface, AppColors.lightCard);
      expect(light.colorScheme.onSurface, AppColors.lightTextPrimary);
      expect(light.bottomSheetTheme.backgroundColor, AppColors.lightSheet);

      expect(dark.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, AppColors.darkBg);
      expect(dark.colorScheme.surface, AppColors.darkCard);
      expect(dark.colorScheme.onSurface, AppColors.darkTextPrimary);
      expect(dark.bottomSheetTheme.backgroundColor, AppColors.darkSheet);
    });

    testWidgets('AppColors adaptive getters switch cleanly between Light & Dark',
        (tester) async {
      late Color lightScaffold;
      late Color lightCard;
      late Color lightSheet;
      late Color lightPanel;
      late Color lightText;
      late Color lightAdaptive;

      late Color darkScaffold;
      late Color darkCard;
      late Color darkSheet;
      late Color darkPanel;
      late Color darkText;
      late Color darkAdaptive;

      Widget probe(ThemeData theme, ValueSetter<BuildContext> onBuild) {
        return MaterialApp(
          key: ValueKey(theme.brightness),
          theme: theme,
          home: Builder(
            builder: (ctx) {
              onBuild(ctx);
              return const SizedBox.shrink();
            },
          ),
        );
      }

      await tester.pumpWidget(
        probe(AppTheme.lightTheme, (ctx) {
          expect(AppColors.isDark(ctx), isFalse);
          lightScaffold = AppColors.scaffoldBg(ctx);
          lightCard = AppColors.cardSurface(ctx);
          lightSheet = AppColors.sheetSurface(ctx);
          lightPanel = AppColors.elevatedSurface(ctx);
          lightText = AppColors.textPrimary(ctx);
          lightAdaptive = AppColors.adaptive(
            ctx,
            dark: AppColors.accent,
            light: const Color(0xFFB45309),
          );
        }),
      );

      expect(lightScaffold, AppColors.lightBg);
      expect(lightCard, AppColors.lightCard);
      expect(lightSheet, AppColors.lightSheet);
      expect(lightPanel, AppColors.lightPanel);
      expect(lightText, AppColors.lightTextPrimary);
      expect(lightAdaptive, const Color(0xFFB45309));

      await tester.pumpWidget(
        probe(AppTheme.darkTheme, (ctx) {
          expect(AppColors.isDark(ctx), isTrue);
          darkScaffold = AppColors.scaffoldBg(ctx);
          darkCard = AppColors.cardSurface(ctx);
          darkSheet = AppColors.sheetSurface(ctx);
          darkPanel = AppColors.elevatedSurface(ctx);
          darkText = AppColors.textPrimary(ctx);
          darkAdaptive = AppColors.adaptive(
            ctx,
            dark: AppColors.accent,
            light: const Color(0xFFB45309),
          );
        }),
      );

      expect(darkScaffold, AppColors.darkBg);
      expect(darkCard, AppColors.darkCard);
      expect(darkSheet, AppColors.darkSheet);
      expect(darkPanel, AppColors.darkPanel);
      expect(darkText, AppColors.darkTextPrimary);
      expect(darkAdaptive, AppColors.accent);
    });

    test('SettingsProvider persists ThemeMode selections across reload',
        () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final provider = SettingsProvider(storage);

      expect(provider.themeMode, ThemeMode.dark);

      await provider.setThemeMode(ThemeMode.light);
      expect(provider.themeMode, ThemeMode.light);

      final reloaded = SettingsProvider(storage);
      expect(reloaded.themeMode, ThemeMode.light);

      await reloaded.setThemeMode(ThemeMode.system);
      expect(SettingsProvider(storage).themeMode, ThemeMode.system);
    });
  });

  group('Light Mode Surface Token Audit (Screens)', () {
    testWidgets('ExploreHubScreen renders crisp light surfaces with zero dark surface leaks',
        (tester) async {
      _configureMobileViewport(tester);
      final env = await _TestEnv.create(themeMode: ThemeMode.light);

      await tester.pumpWidget(env.wrap(const ExploreHubScreen()));
      await tester.pumpAndSettle();

      _expectNoHardcodedDarkSurfaces(tester, 'ExploreHubScreen');
      expect(find.text('Everyday Life & Wellness'), findsOneWidget);

      await tester.pumpWidget(
        env.wrap(const ExploreHubScreen(), overrideThemeMode: ThemeMode.dark),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('WishlistScreen & Add Wishlist sheet use light surface tokens in ThemeMode.light',
        (tester) async {
      _configureMobileViewport(tester);
      final env = await _TestEnv.create(themeMode: ThemeMode.light);

      await tester.pumpWidget(env.wrap(const WishlistScreen()));
      await tester.pumpAndSettle();

      _expectNoHardcodedDarkSurfaces(tester, 'WishlistScreen');

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      _expectNoHardcodedDarkSurfaces(tester, 'WishlistScreen Add Sheet');
    });

    testWidgets('CalendarScreen & Add Event sheet use light surface tokens in ThemeMode.light',
        (tester) async {
      _configureMobileViewport(tester);
      final env = await _TestEnv.create(themeMode: ThemeMode.light);

      await tester.pumpWidget(env.wrap(const CalendarScreen()));
      await tester.pumpAndSettle();

      _expectNoHardcodedDarkSurfaces(tester, 'CalendarScreen');

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      _expectNoHardcodedDarkSurfaces(tester, 'CalendarScreen Add Event Sheet');
    });

    testWidgets('SettingsScreen & Global Challenge sheet adapt cleanly to Light & Dark modes',
        (tester) async {
      _configureMobileViewport(tester);
      final env = await _TestEnv.create(themeMode: ThemeMode.light);

      await tester.pumpWidget(env.wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      _expectNoHardcodedDarkSurfaces(tester, 'SettingsScreen');
      expect(find.text('Theme Mode'), findsOneWidget);

      await tester.pumpWidget(
        env.wrap(const SettingsScreen(), overrideThemeMode: ThemeMode.dark),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('MoneyHubScreen, TasksScreen, RemindersListScreen, NotesListScreen, and HomeDashboardScreen pass Light Mode audit',
        (tester) async {
      _configureMobileViewport(tester);
      final env = await _TestEnv.create(themeMode: ThemeMode.light);

      for (final entry in <String, Widget>{
        'MoneyHubScreen': const MoneyHubScreen(standalone: true),
        'TasksScreen': const TasksScreen(),
        'RemindersListScreen': const RemindersListScreen(),
        'NotesListScreen': const NotesListScreen(),
      }.entries) {
        await tester.pumpWidget(env.wrap(entry.value));
        await tester.pumpAndSettle();
        _expectNoHardcodedDarkSurfaces(tester, entry.key);
      }

      // HomeDashboardScreen runs a 1s periodic clock ticker, so advance frames explicitly.
      await tester.pumpWidget(
        env.wrap(Scaffold(body: HomeDashboardScreen(onNavigateTab: (_, [_]) {}))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      _expectNoHardcodedDarkSurfaces(tester, 'HomeDashboardScreen');
      expect(tester.takeException(), isNull);
    });
  });

  group('Light Mode Surface Token Audit (Modal Sheets & Challenges)', () {
    testWidgets('Modal bottom sheets & ChallengeModalDialog use light surfaces under ThemeMode.light',
        (tester) async {
      _configureMobileViewport(tester);
      final env = await _TestEnv.create(themeMode: ThemeMode.light);

      for (final entry in <String, Widget>{
        'QuickCaptureSheet': const Material(child: QuickCaptureSheet()),
        'HydrationSettingsSheet': const Material(child: HydrationSettingsSheet()),
        'SleepCycleSheet': const Material(child: SleepCycleSheet()),
        'SoundPickerSheet': const Material(
          child: SoundPickerSheet(currentSoundId: 'rooster_classic'),
        ),
        'ChallengeModalDialog': ChallengeModalDialog(
          challenge: WakeUpChallengeProfile.defaultProfile(),
          onDismissAlarm: () {},
          onSnooze: () {},
        ),
      }.entries) {
        await tester.pumpWidget(env.wrap(entry.value));
        await tester.pump(const Duration(milliseconds: 100));
        _expectNoHardcodedDarkSurfaces(tester, entry.key);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
