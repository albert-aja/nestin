import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/l10n/app_language.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/alarm_category.dart';
import 'package:nestin/data/models/challenge_profile.dart';
import 'package:nestin/data/models/user_preferences.dart';
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
import 'package:nestin/ui/screens/explore/explore_hub_screen.dart';
import 'package:nestin/ui/screens/home/home_dashboard_screen.dart';
import 'package:nestin/ui/screens/journal/journal_hub_screen.dart';
import 'package:nestin/ui/screens/main_navigation_screen.dart';
import 'package:nestin/ui/screens/organize/money/money_hub_screen.dart';
import 'package:nestin/ui/screens/organize/organize_hub_screen.dart';
import 'package:nestin/ui/screens/search/universal_search_screen.dart';
import 'package:nestin/ui/screens/settings/settings_screen.dart';
import 'package:nestin/ui/screens/time/time_hub_screen.dart';

class _L10nTestEnv {
  final StorageService storage;
  final SettingsProvider settings;
  final AudioService audio;
  final NotificationService notifications;
  final OemHardeningProvider oem;

  _L10nTestEnv({
    required this.storage,
    required this.settings,
    required this.audio,
    required this.notifications,
    required this.oem,
  });

  static Future<_L10nTestEnv> create({
    AppLanguage language = AppLanguage.en,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await AppLocalizations.ensureDateFormatting();
    final storage = await StorageService.init();
    final settings = SettingsProvider(storage);
    await settings.setLanguage(language);
    final oemService = MockOemHardeningService(
      manufacturer: 'Pixel',
      brand: 'Google',
      model: 'Pixel 9',
      isIgnoringBatteryOptimizations: true,
      isKeepAliveRunning: false,
    );
    return _L10nTestEnv(
      storage: storage,
      settings: settings,
      audio: AudioService(),
      notifications: NotificationService(),
      oem: OemHardeningProvider(storage, oemService),
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
      child: Consumer<SettingsProvider>(
        builder: (context, s, _) => MaterialApp(
          locale: s.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: s.themeMode,
          home: child,
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppLocalizations.currentLanguage = AppLanguage.en;
  });

  group('Dual Language Core & Persistence', () {
    test('AppLanguageExt.fromCode maps EN/ID variants and falls back safely', () {
      expect(AppLanguageExt.fromCode('en'), AppLanguage.en);
      expect(AppLanguageExt.fromCode('id'), AppLanguage.id);
      expect(AppLanguageExt.fromCode('id_ID'), AppLanguage.id);
      expect(AppLanguageExt.fromCode('id-id'), AppLanguage.id);
      expect(AppLanguageExt.fromCode('in'), AppLanguage.id);
      expect(AppLanguageExt.fromCode('Indonesian'), AppLanguage.id);
      expect(AppLanguageExt.fromCode('bahasa indonesia'), AppLanguage.id);
      expect(AppLanguageExt.fromCode('unknown'), AppLanguage.en);
      expect(AppLanguageExt.fromCode(null), AppLanguage.en);
    });

    test('UserPreferences JSON roundtrip preserves language and defaults legacy data to EN', () {
      final prefsId = UserPreferences(
        globalChallengeProfile: WakeUpChallengeProfile.defaultProfile(),
        language: AppLanguage.id,
      );
      final jsonMap = prefsId.toJson();
      expect(jsonMap['language'], 'id');

      final restored = UserPreferences.fromJson(jsonMap);
      expect(restored.language, AppLanguage.id);

      final legacy = UserPreferences.fromJson({'use24Hour': true});
      expect(legacy.language, AppLanguage.en);
      expect(legacy.copyWith(language: AppLanguage.id).language, AppLanguage.id);
    });

    test('SettingsProvider.setLanguage persists across storage reload & full backup restore', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final settings = SettingsProvider(storage);

      expect(settings.language, AppLanguage.en);
      expect(settings.locale, const Locale('en', 'US'));

      await settings.setLanguage(AppLanguage.id);
      expect(settings.language, AppLanguage.id);
      expect(settings.locale, const Locale('id', 'ID'));
      expect(AppLocalizations.currentLanguage, AppLanguage.id);

      // Reload from StorageService
      final reloaded = SettingsProvider(storage);
      expect(reloaded.language, AppLanguage.id);

      // Export & restore into clean prefs
      final backupJson = storage.exportFullBackupJson();
      final decoded = jsonDecode(backupJson) as Map<String, dynamic>;
      expect((decoded['preferences'] as Map<String, dynamic>)['language'], 'id');

      await reloaded.setLanguage(AppLanguage.en);
      expect(storage.loadPreferences().language, AppLanguage.en);

      await storage.restoreFullBackupJson(backupJson);
      expect(storage.loadPreferences().language, AppLanguage.id);
    });

    test('AppLocalizations formats EN & ID dictionaries, dates, and categories cleanly', () async {
      await AppLocalizations.ensureDateFormatting();
      const enL10n = AppLocalizations(AppLanguage.en);
      const idL10n = AppLocalizations(AppLanguage.id);

      expect(enL10n.tr('nav_today'), 'Today');
      expect(idL10n.tr('nav_today'), 'Hari Ini');
      expect(enL10n.tr('count_active', {'count': 4}), '4 Active');
      expect(idL10n.tr('count_active', {'count': 4}), '4 Aktif');
      expect(enL10n.categoryName(AlarmCategoryType.wakeUp), 'Wake Up');
      expect(idL10n.categoryName(AlarmCategoryType.wakeUp), 'Bangun Tidur');

      // Test Sunday in January 2026 (Jan 4, 2026)
      final sampleDate = DateTime(2026, 1, 4);
      expect(enL10n.formatDate(sampleDate, 'EEEE, MMMM d'), contains('January'));
      expect(idL10n.formatDate(sampleDate, 'EEEE, MMMM d'), contains('Januari'));
    });

    testWidgets('AppLocalizations.of(context) works safely without localizationsDelegates or SettingsProvider', (tester) async {
      AppLocalizations.currentLanguage = AppLanguage.id;
      late AppLocalizations resolved;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = context.l10n;
              return Text(resolved.tr('settings'));
            },
          ),
        ),
      );

      expect(resolved.language, AppLanguage.id);
      expect(find.text('Pengaturan'), findsOneWidget);
    });
  });

  group('Dual Language Live UI Switching', () {
    testWidgets('SettingsScreen switches EN <-> ID live in 1 tap', (tester) async {
      final env = await _L10nTestEnv.create(language: AppLanguage.en);
      await tester.pumpWidget(env.wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('General Preferences'), findsOneWidget);
      expect(find.text('Theme Mode'), findsOneWidget);

      await tester.tap(find.text('🇮🇩 Bahasa Indonesia'));
      await tester.pumpAndSettle();

      expect(env.settings.language, AppLanguage.id);
      expect(find.text('Pengaturan'), findsOneWidget);
      expect(find.text('Preferensi Umum'), findsOneWidget);
      expect(find.text('Mode Tema'), findsOneWidget);
      expect(find.text('Format Waktu 24 Jam'), findsOneWidget);

      await tester.tap(find.text('🇺🇸 English'));
      await tester.pumpAndSettle();

      expect(env.settings.language, AppLanguage.en);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Theme Mode'), findsOneWidget);
    });

    testWidgets('Navigation Shell, Hubs & Home Dashboard render Bahasa Indonesia cleanly', (tester) async {
      final env = await _L10nTestEnv.create(language: AppLanguage.id);

      await tester.pumpWidget(env.wrap(const MainNavigationScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Hari Ini'), findsAtLeastNWidgets(1));
      expect(find.text('Waktu'), findsAtLeastNWidgets(1));
      expect(find.text('Kelola'), findsAtLeastNWidgets(1));
      expect(find.text('Jurnal'), findsAtLeastNWidgets(1));
      expect(find.text('Jelajah'), findsAtLeastNWidgets(1));

      await tester.pumpWidget(env.wrap(HomeDashboardScreen(onNavigateTab: (_, [_]) {})));
      await tester.pumpAndSettle();
      expect(find.text('Catat Cepat'), findsAtLeastNWidgets(1));

      await tester.pumpWidget(env.wrap(const TimeHubScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Waktu & Rencana'), findsOneWidget);
      expect(find.text('Alarm'), findsAtLeastNWidgets(1));
      expect(find.text('Pengingat'), findsAtLeastNWidgets(1));
      expect(find.text('Timer'), findsAtLeastNWidgets(1));

      await tester.pumpWidget(env.wrap(const OrganizeHubScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Kelola • Twill'), findsOneWidget);
      expect(find.text('Keuangan'), findsAtLeastNWidgets(1));
      expect(find.text('Catatan'), findsAtLeastNWidgets(1));

      await tester.pumpWidget(env.wrap(const JournalHubScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Jurnal & Kenangan'), findsOneWidget);
      expect(find.text('Diari'), findsAtLeastNWidgets(1));
      expect(find.text('Linimasa'), findsAtLeastNWidgets(1));

      await tester.pumpWidget(env.wrap(const ExploreHubScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Keseharian & Kebugaran'), findsOneWidget);

      await tester.pumpWidget(env.wrap(const UniversalSearchScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Pencarian Universal'), findsOneWidget);

      await tester.pumpWidget(env.wrap(const MoneyHubScreen(standalone: true)));
      await tester.pumpAndSettle();
      expect(find.text('Pengelolaan Keuangan Twill'), findsOneWidget);
      expect(find.text('Ringkasan'), findsAtLeastNWidgets(1));
      expect(find.text('Transaksi'), findsAtLeastNWidgets(1));
      expect(find.text('Akun'), findsAtLeastNWidgets(1));
    });
  });
}
