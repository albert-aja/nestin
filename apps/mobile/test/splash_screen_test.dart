import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestin/core/l10n/app_language.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/user_preferences.dart';
import 'package:nestin/data/services/audio_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/oem_hardening_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/main.dart';
import 'package:nestin/providers/oem_hardening_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/providers/sound_provider.dart';
import 'package:nestin/providers/wearable_provider.dart';
import 'package:nestin/ui/screens/settings/settings_screen.dart';
import 'package:nestin/ui/screens/splash/seasonal_loading_theme.dart';
import 'package:nestin/ui/screens/splash/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithTheme(
    Widget child, {
    ThemeMode themeMode = ThemeMode.dark,
    Locale locale = const Locale('en', 'US'),
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    );
  }

  group('SplashScreen UI & Animation Tests', () {
    testWidgets('renders brand title, PRO tag, tagline, logo and banner overlay', (tester) async {
      bool finished = false;
      await tester.pumpWidget(
        wrapWithTheme(
          SplashScreen(
            minDuration: const Duration(milliseconds: 600),
            onFinish: () => finished = true,
          ),
        ),
      );
      await tester.pump();

      // Verify immediate presence of brand elements
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('Nestin'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
      expect(find.text('Every moment, right on time.'), findsOneWidget);
      expect(find.text('Personal Everyday Space'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Verify image assets are referenced
      final imageWidgets = tester.widgetList<Image>(find.byType(Image)).toList();
      final assetNames = imageWidgets
          .map((img) => img.image is AssetImage ? (img.image as AssetImage).assetName : '')
          .toList();

      expect(assetNames, contains('assets/banner.jpg'));
      expect(assetNames, contains('assets/logo.jpg'));

      // Forward animation
      await tester.pump(const Duration(milliseconds: 300));
      expect(finished, isFalse);

      // Forward past minDuration to trigger callback
      await tester.pump(const Duration(milliseconds: 400));
      expect(finished, isTrue);
    });

    testWidgets('renders cleanly in Light mode with localized Indonesian tagline', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          SplashScreen(
            minDuration: const Duration(milliseconds: 400),
            onFinish: () {},
          ),
          themeMode: ThemeMode.light,
          locale: const Locale('id', 'ID'),
        ),
      );

      await tester.pump();
      expect(find.text('Nestin'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
      expect(find.text('Setiap momen, tepat waktu.'), findsOneWidget);
      expect(find.text('Ruang Keseharian Pribadi'), findsOneWidget);
    });
  });

  group('NestinApp Splash Screen Launch Flow', () {
    testWidgets('NestinApp displays SplashScreen on cold launch and transitions to destination', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final audio = AudioService();
      final notifications = NotificationService();

      await tester.pumpWidget(
        NestinApp(
          storageService: storage,
          audioService: audio,
          notificationService: notifications,
          showSplash: true,
        ),
      );
      await tester.pump();

      // Initially SplashScreen is visible
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('splash_screen')), findsOneWidget);

      // Let splash timer run and settle
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      // First time launch lands on MascotOnboardingScreen
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byKey(const ValueKey('mascot_onboarding')), findsOneWidget);
    });

    testWidgets('NestinApp showSplash=false enters directly without splash delay', (tester) async {
      SharedPreferences.setMockInitialValues({
        'has_completed_onboarding': false,
      });
      final storage = await StorageService.init();
      final audio = AudioService();
      final notifications = NotificationService();

      await tester.pumpWidget(
        NestinApp(
          storageService: storage,
          audioService: audio,
          notificationService: notifications,
          showSplash: false,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byKey(const ValueKey('mascot_onboarding')), findsOneWidget);
    });

    testWidgets('NestinApp uses Quick (800ms) splash dwell speed', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      await storage.savePreferences(
        UserPreferences.defaults().copyWith(splashSpeed: SplashSpeed.quick),
      );
      final audio = AudioService();
      final notifications = NotificationService();

      await tester.pumpWidget(
        NestinApp(
          storageService: storage,
          audioService: audio,
          notificationService: notifications,
          showSplash: true,
        ),
      );
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SplashScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byKey(const ValueKey('mascot_onboarding')), findsOneWidget);
    });

    testWidgets('NestinApp uses Relaxed (2200ms) splash dwell speed', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      await storage.savePreferences(
        UserPreferences.defaults().copyWith(splashSpeed: SplashSpeed.relaxed),
      );
      final audio = AudioService();
      final notifications = NotificationService();

      await tester.pumpWidget(
        NestinApp(
          storageService: storage,
          audioService: audio,
          notificationService: notifications,
          showSplash: true,
        ),
      );
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.byType(SplashScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byKey(const ValueKey('mascot_onboarding')), findsOneWidget);
    });

    testWidgets(
        'NestinApp skips splash when Instant Launch (0ms) is set and does not re-show on later speed change',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      await storage.savePreferences(
        UserPreferences.defaults().copyWith(splashSpeed: SplashSpeed.instant),
      );
      final audio = AudioService();
      final notifications = NotificationService();

      await tester.pumpWidget(
        NestinApp(
          storageService: storage,
          audioService: audio,
          notificationService: notifications,
          showSplash: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byKey(const ValueKey('mascot_onboarding')), findsOneWidget);

      final ctx = tester.element(find.byKey(const ValueKey('mascot_onboarding')));
      await ctx.read<SettingsProvider>().setSplashSpeed(SplashSpeed.normal);
      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byKey(const ValueKey('mascot_onboarding')), findsOneWidget);
    });
  });

  group('SplashSpeed Preference, Persistence & Settings UI', () {
    test('SplashSpeed durations and JSON round-trip with legacy fallback', () async {
      expect(SplashSpeed.quick.duration, const Duration(milliseconds: 800));
      expect(SplashSpeed.normal.duration, const Duration(milliseconds: 1400));
      expect(SplashSpeed.relaxed.duration, const Duration(milliseconds: 2200));
      expect(SplashSpeed.instant.duration, Duration.zero);

      final prefs = UserPreferences.defaults().copyWith(
        splashSpeed: SplashSpeed.relaxed,
      );
      final json = prefs.toJson();
      expect(json['splashSpeed'], 'relaxed');

      final parsed = UserPreferences.fromJson(json);
      expect(parsed.splashSpeed, SplashSpeed.relaxed);

      json.remove('splashSpeed');
      final legacy = UserPreferences.fromJson(json);
      expect(legacy.splashSpeed, SplashSpeed.normal);

      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final settings = SettingsProvider(storage);
      expect(settings.splashSpeed, SplashSpeed.normal);
      await settings.setSplashSpeed(SplashSpeed.quick);

      final reloaded = SettingsProvider(storage);
      expect(reloaded.splashSpeed, SplashSpeed.quick);

      settings.dispose();
      reloaded.dispose();
    });

    testWidgets('SplashScreen with minDuration=Duration.zero finishes on first frame',
        (tester) async {
      bool finished = false;
      await tester.pumpWidget(
        wrapWithTheme(
          SplashScreen(
            minDuration: Duration.zero,
            animationDuration: Duration.zero,
            onFinish: () => finished = true,
          ),
        ),
      );
      await tester.pump();
      expect(finished, isTrue);
    });

    testWidgets('SettingsScreen updates SplashSpeed cleanly in EN and ID',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await AppLocalizations.ensureDateFormatting();
      final storage = await StorageService.init();
      final settings = SettingsProvider(storage);
      final oem = OemHardeningProvider(storage, MockOemHardeningService());
      final sound = SoundProvider(storage);
      final wearable = WearableProvider(storage);
      addTearDown(() {
        settings.dispose();
        oem.dispose();
        sound.dispose();
        wearable.dispose();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<OemHardeningProvider>.value(value: oem),
            ChangeNotifierProvider<SoundProvider>.value(value: sound),
            ChangeNotifierProvider<WearableProvider>.value(value: wearable),
          ],
          child: Consumer<SettingsProvider>(
            builder: (_, s, _) => MaterialApp(
              theme: AppTheme.lightTheme,
              locale: s.locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const SettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tileFinder = find.byKey(const Key('settings_splash_speed_tile'));
      await tester.scrollUntilVisible(
        tileFinder,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Splash Screen Speed'), findsOneWidget);
      expect(
        find.text('Balanced 1400ms sunrise welcome animation'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('settings_splash_speed_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quick (0.8s)').last);
      await tester.pumpAndSettle();

      expect(settings.splashSpeed, SplashSpeed.quick);
      expect(
        find.text('Brief 800ms welcome before opening Nestin'),
        findsOneWidget,
      );

      // Switch to Bahasa Indonesia and choose Instant Launch
      await settings.setLanguage(AppLanguage.id);
      await tester.pumpAndSettle();

      expect(find.text('Kecepatan Layar Pembuka'), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings_splash_speed_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Instan (0 dtk)').last);
      await tester.pumpAndSettle();

      expect(settings.splashSpeed, SplashSpeed.instant);
      expect(
        find.text('Lewati layar pembuka dan langsung masuk'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Two-Phase Splash & Seasonal Wallpaper Loading Screen', () {
    test('SeasonalSplashResolver maps all 12 months and supports override', () {
      expect(
        SeasonalSplashResolver.resolveTheme(now: DateTime(2026, 12, 25)),
        SeasonalSplashTheme.christmas,
      );
      expect(
        SeasonalSplashResolver.resolveTheme(now: DateTime(2026, 1, 1)),
        SeasonalSplashTheme.newYear,
      );
      expect(
        SeasonalSplashResolver.resolveTheme(now: DateTime(2026, 2, 5)),
        SeasonalSplashTheme.lunarLantern,
      );
      expect(
        SeasonalSplashResolver.resolveTheme(now: DateTime(2026, 2, 14)),
        SeasonalSplashTheme.friendshipLetters,
      );
      expect(
        SeasonalSplashResolver.resolveTheme(now: DateTime(2026, 3, 20)),
        SeasonalSplashTheme.eidLantern,
      );
      expect(
        SeasonalSplashResolver.resolveTheme(now: DateTime(2026, 4, 10)),
        SeasonalSplashTheme.springBloom,
      );
      expect(
        SeasonalSplashResolver.resolveTheme(now: DateTime(2026, 4, 22)),
        SeasonalSplashTheme.earthDay,
      );
      expect(
        SeasonalSplashResolver.resolveTheme(now: DateTime(2026, 6, 15)),
        SeasonalSplashTheme.summerSun,
      );
      expect(
        SeasonalSplashResolver.resolveTheme(now: DateTime(2026, 7, 15)),
        SeasonalSplashTheme.midsummerKite,
      );
      expect(
        SeasonalSplashResolver.resolveTheme(now: DateTime(2026, 9, 20)),
        SeasonalSplashTheme.midAutumn,
      );
      expect(
        SeasonalSplashResolver.resolveTheme(now: DateTime(2026, 10, 5)),
        SeasonalSplashTheme.autumnHarvest,
      );
      expect(
        SeasonalSplashResolver.resolveTheme(now: DateTime(2026, 10, 31)),
        SeasonalSplashTheme.halloween,
      );
      expect(
        SeasonalSplashResolver.resolveTheme(now: DateTime(2026, 11, 5)),
        SeasonalSplashTheme.cozyLantern,
      );
      expect(
        SeasonalSplashResolver.resolveTheme(now: DateTime(2026, 11, 21, 9)),
        SeasonalSplashTheme.everydaySunnyPicnic,
      );
      expect(
        SeasonalSplashResolver.resolveTheme(now: DateTime(2026, 11, 21, 14)),
        SeasonalSplashTheme.everydayTreehouse,
      );
      expect(
        SeasonalSplashResolver.resolveTheme(now: DateTime(2026, 11, 21, 19)),
        SeasonalSplashTheme.everydayFireplace,
      );
      expect(
        SeasonalSplashResolver.resolveTheme(now: DateTime(2026, 11, 21, 23)),
        SeasonalSplashTheme.everydayStarlight,
      );
      expect(
        SeasonalSplashResolver.resolveTheme(now: DateTime(2026, 11, 26)),
        SeasonalSplashTheme.gratitudeHarvest,
      );
      expect(
        SeasonalSplashResolver.resolveTheme(
          now: DateTime(2026, 7, 15),
          override: SeasonalSplashTheme.christmas,
        ),
        SeasonalSplashTheme.christmas,
      );
    });

    testWidgets(
      'transitions from logo banner to December Christmas wallpaper loading screen',
      (tester) async {
        bool finished = false;
        await tester.pumpWidget(
          wrapWithTheme(
            SplashScreen(
              minDuration: const Duration(milliseconds: 1000),
              currentDate: DateTime(2026, 12, 20),
              onFinish: () => finished = true,
            ),
          ),
        );
        await tester.pump();

        // Phase 1: Logo banner
        expect(
          find.byKey(const ValueKey('splash_phase_logo_banner')),
          findsOneWidget,
        );
        expect(find.text('Nestin'), findsOneWidget);

        // Advance past 42% (420ms) into Phase 2: Christmas wallpaper
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.byKey(const ValueKey('splash_phase_seasonal_christmas')),
          findsOneWidget,
        );
        expect(find.text('December • Holiday Season'), findsOneWidget);
        expect(find.text('Warm Holiday Wishes'), findsOneWidget);
        expect(find.text('Preparing your sanctuary...'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        final imageWidgets =
            tester.widgetList<Image>(find.byType(Image)).toList();
        final assetNames = imageWidgets
            .map((img) =>
                img.image is AssetImage ? (img.image as AssetImage).assetName : '')
            .toList();
        expect(
          assetNames,
          contains('assets/mascots/wallpapers/seasonal/christmas_wallpaper.jpg'),
        );

        expect(finished, isFalse);

        // Advance past minDuration
        await tester.pump(const Duration(milliseconds: 200));
        expect(finished, isTrue);
      },
    );

    testWidgets(
      'transitions to January New Year wallpaper in Bahasa Indonesia',
      (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            SplashScreen(
              minDuration: const Duration(milliseconds: 1000),
              currentDate: DateTime(2026, 1, 2),
              onFinish: () {},
            ),
            themeMode: ThemeMode.light,
            locale: const Locale('id', 'ID'),
          ),
        );
        await tester.pump();

        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.byKey(const ValueKey('splash_phase_seasonal_newYear')),
          findsOneWidget,
        );
        expect(find.text('Januari • Tahun Baru'), findsOneWidget);
        expect(find.text('Awal yang Segar'), findsOneWidget);
        expect(find.text('Menyiapkan ruang tenang Anda...'), findsOneWidget);

        // Finish timer cleanly
        await tester.pump(const Duration(milliseconds: 200));
      },
    );

    test('UserPreferences persists seasonalSplashOverride round-trip', () {
      final prefs = UserPreferences.defaults().copyWith(
        seasonalSplashOverride: SeasonalSplashTheme.christmas,
      );
      final restored = UserPreferences.fromJson(prefs.toJson());
      expect(restored.seasonalSplashOverride, SeasonalSplashTheme.christmas);

      final cleared = restored.copyWith(clearSeasonalSplashOverride: true);
      expect(cleared.seasonalSplashOverride, isNull);
    });

    test('All 18 seasonal & everyday loading specs resolve to bundled flock wallpapers and EN/ID strings', () {
      const en = AppLocalizations(AppLanguage.en);
      const id = AppLocalizations(AppLanguage.id);
      expect(SeasonalSplashTheme.values.length, 18);

      for (final theme in SeasonalSplashTheme.values) {
        final spec = SeasonalSplashResolver.specFor(theme);
        expect(spec.wallpaperAsset, isNotNull);
        expect(
          spec.wallpaperAsset,
          startsWith('assets/mascots/wallpapers/'),
        );
        expect(File(spec.wallpaperAsset!).existsSync(), isTrue);

        for (final key in [
          theme.labelKey,
          spec.badgeKey,
          spec.titleKey,
          spec.subtitleKey,
        ]) {
          expect(en.tr(key), isNot(equals(key)));
          expect(id.tr(key), isNot(equals(key)));
        }
      }
    });
  });
}
