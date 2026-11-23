import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestin/core/l10n/app_language.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/user_preferences.dart';
import 'package:nestin/data/services/audio_service.dart';
import 'package:nestin/data/services/backend_gateway_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/oem_hardening_service.dart';
import 'package:nestin/data/services/splash_wallpaper_pack_service.dart';
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

class _FakeBackendGatewayService extends BackendGatewayService {
  final List<Map<String, dynamic>> wallpapers;

  _FakeBackendGatewayService(SharedPreferences prefs, this.wallpapers)
      : super(
          prefs,
          config: const BackendGatewayConfig(
            apiBaseUrl: 'https://api.nestin.local',
            supabaseUrl: 'https://supabase.nestin.local',
            supabaseAnonKey: 'anon-key',
          ),
        );

  @override
  Future<BackendResult<Map<String, dynamic>>> fetchMediaWallpapers({
    String? locale,
    String? mascotDomain,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    return BackendResult.ok({'items': wallpapers});
  }
}

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
    testWidgets('renders clean white background with centered logo banner and tagline', (tester) async {
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

      // Verify clean white background + centered logo banner
      expect(find.byType(SplashScreen), findsOneWidget);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.white);
      expect(find.text('Every moment, right on time.'), findsOneWidget);
      expect(find.text('Personal Everyday Space'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Verify banner asset is centered with BoxFit.contain
      final imageWidgets = tester.widgetList<Image>(find.byType(Image)).toList();
      final bannerImg = imageWidgets.firstWhere(
        (img) =>
            img.image is AssetImage &&
            (img.image as AssetImage).assetName == 'assets/banner.jpg',
      );
      expect(bannerImg.fit, BoxFit.contain);

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
      expect(find.text('Setiap momen, tepat waktu.'), findsOneWidget);
      expect(find.text('Ruang Keseharian Pribadi'), findsOneWidget);

      // Flush timers cleanly
      await tester.pump(const Duration(milliseconds: 500));
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
        expect(find.text('Every moment, right on time.'), findsOneWidget);

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

  group('Custom Personal Photo & Remote Holiday Wallpaper Packs', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('nestin_splash_pack_test_');
      SplashWallpaperPackService.debugBaseDirectoryOverride = tempDir;
    });

    tearDown(() {
      SplashWallpaperPackService.debugBaseDirectoryOverride = null;
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('SeasonalSplashResolver prioritizes custom photo, then remote pack, then seasonal theme', () async {
      final photoFile = File('${tempDir.path}/family_memory.jpg');
      await photoFile.writeAsBytes([1, 2, 3, 4]);

      final packFile = File('${tempDir.path}/cherry-blossom-picnic.jpg');
      await packFile.writeAsBytes([5, 6, 7, 8]);

      // 1. Personal photo takes highest precedence even when remote pack and override are set
      final customSpec = SeasonalSplashResolver.resolve(
        now: DateTime(2026, 12, 25),
        override: SeasonalSplashTheme.christmas,
        customPhotoPath: photoFile.path,
        remotePackSlug: 'cherry-blossom-picnic',
        installedRemotePackPaths: {'cherry-blossom-picnic': packFile.path},
      );
      expect(customSpec.hasCustomPhoto, isTrue);
      expect(customSpec.customWallpaperFilePath, photoFile.path);
      expect(customSpec.badgeKey, 'splash_custom_photo_badge');
      expect(customSpec.titleKey, 'splash_custom_photo_title');
      expect(customSpec.subtitleKey, 'splash_custom_photo_subtitle');

      // 2. Active remote pack takes precedence over seasonal override when no custom photo
      final packSpec = SeasonalSplashResolver.resolve(
        now: DateTime(2026, 12, 25),
        override: SeasonalSplashTheme.christmas,
        remotePackSlug: 'cherry-blossom-picnic',
        installedRemotePackPaths: {'cherry-blossom-picnic': packFile.path},
      );
      expect(packSpec.hasCustomPhoto, isFalse);
      expect(packSpec.hasRemotePack, isTrue);
      expect(packSpec.remotePackSlug, 'cherry-blossom-picnic');
      expect(packSpec.customWallpaperFilePath, packFile.path);
      expect(packSpec.titleKey, 'splash_pack_cherry_blossom_title');

      // 3. Falls back to seasonal theme when custom photo & remote pack are absent
      final seasonalSpec = SeasonalSplashResolver.resolve(
        now: DateTime(2026, 12, 25),
      );
      expect(seasonalSpec.hasCustomPhoto, isFalse);
      expect(seasonalSpec.hasRemotePack, isFalse);
      expect(seasonalSpec.theme, SeasonalSplashTheme.christmas);
    });

    test('UserPreferences persists customSplashPhotoPath and remote pack fields round-trip', () {
      final prefs = UserPreferences.defaults().copyWith(
        customSplashPhotoPath: '/sandbox/splash/custom_photo.jpg',
        activeRemoteSplashPackSlug: 'winter-snow-cabin',
        installedRemoteSplashPackSlugs: const [
          'cherry-blossom-picnic',
          'winter-snow-cabin',
        ],
        installedRemoteSplashPackPaths: const {
          'cherry-blossom-picnic': '/sandbox/packs/cherry-blossom-picnic.jpg',
          'winter-snow-cabin': '/sandbox/packs/winter-snow-cabin.jpg',
        },
      );

      final restored = UserPreferences.fromJson(prefs.toJson());
      expect(
        restored.customSplashPhotoPath,
        '/sandbox/splash/custom_photo.jpg',
      );
      expect(restored.activeRemoteSplashPackSlug, 'winter-snow-cabin');
      expect(
        restored.installedRemoteSplashPackSlugs,
        containsAll(['cherry-blossom-picnic', 'winter-snow-cabin']),
      );
      expect(
        restored.installedRemoteSplashPackPaths['winter-snow-cabin'],
        '/sandbox/packs/winter-snow-cabin.jpg',
      );

      final cleared = restored.copyWith(
        clearCustomSplashPhotoPath: true,
        clearActiveRemoteSplashPackSlug: true,
      );
      expect(cleared.customSplashPhotoPath, isNull);
      expect(cleared.activeRemoteSplashPackSlug, isNull);
    });

    test('SplashWallpaperPackService & SettingsProvider import personal photo, fetch remote catalog, install, activate, and remove packs', () async {
      SharedPreferences.setMockInitialValues({});
      final rawPrefs = await SharedPreferences.getInstance();
      final storage = await StorageService.init();
      final settings = SettingsProvider(storage);
      addTearDown(settings.dispose);

      // Import a personal photo from a source file
      final sourcePhoto = File('${tempDir.path}/source_photo.jpg');
      final pngBytes = File('assets/logo.jpg').readAsBytesSync();
      await sourcePhoto.writeAsBytes(pngBytes);

      final importedPath = await settings.importAndSetCustomSplashPhotoFromFile(
        sourcePhoto.path,
      );
      expect(importedPath, isNotNull);
      expect(settings.hasCustomSplashPhoto, isTrue);
      expect(settings.customSplashPhotoPath, isNotNull);
      expect(File(settings.customSplashPhotoPath!).existsSync(), isTrue);

      // Clear personal photo and verify sandbox file is deleted
      final oldCustomPath = settings.customSplashPhotoPath!;
      await settings.clearCustomSplashPhoto();
      expect(settings.hasCustomSplashPhoto, isFalse);
      expect(settings.customSplashPhotoPath, isNull);
      expect(File(oldCustomPath).existsSync(), isFalse);

      // Fetch catalog from BackendGatewayService
      final fakeGateway = _FakeBackendGatewayService(rawPrefs, [
        {
          'slug': 'winter-snow-cabin',
          'assetType': 'wallpaper',
          'publicUrl': 'https://cdn.nestin.local/wallpapers/winter_snow_cabin.jpg',
          'byteSize': 152400,
        },
      ]);
      final fetchedPacks = await settings.refreshRemoteSplashCatalog(
        gateway: fakeGateway,
      );
      expect(fetchedPacks.length, 4);
      final winterPack = fetchedPacks.firstWhere(
        (p) => p.slug == 'winter-snow-cabin',
      );
      expect(
        winterPack.publicUrl,
        'https://cdn.nestin.local/wallpapers/winter_snow_cabin.jpg',
      );
      expect(winterPack.byteSize, 152400);

      // Install pack by slug and activate immediately
      final installed = await settings.installRemoteSplashPack(
        'winter-snow-cabin',
        activateOnInstall: true,
      );
      expect(installed, isTrue);
      expect(settings.isRemoteSplashPackInstalled('winter-snow-cabin'), isTrue);
      expect(settings.activeRemoteSplashPackSlug, 'winter-snow-cabin');
      final cachedPath =
          settings.installedRemoteSplashPackPaths['winter-snow-cabin'];
      expect(cachedPath, isNotNull);
      expect(File(cachedPath!).existsSync(), isTrue);

      // Selecting a built-in seasonal theme clears activeRemoteSplashPackSlug
      await settings.setSeasonalSplashOverride(SeasonalSplashTheme.christmas);
      expect(settings.activeRemoteSplashPackSlug, isNull);
      expect(settings.seasonalSplashOverride, SeasonalSplashTheme.christmas);

      // Re-activate installed remote pack
      await settings.setActiveRemoteSplashPackSlug('winter-snow-cabin');
      expect(settings.activeRemoteSplashPackSlug, 'winter-snow-cabin');

      // Remove remote pack
      await settings.removeRemoteSplashPack('winter-snow-cabin');
      expect(settings.isRemoteSplashPackInstalled('winter-snow-cabin'), isFalse);
      expect(settings.activeRemoteSplashPackSlug, isNull);
      expect(File(cachedPath).existsSync(), isFalse);
    });

    testWidgets('SplashScreen Phase 2 renders custom personal photo and remote holiday pack wallpaper', (tester) async {
      final customPhoto = File('${tempDir.path}/personal_wallpaper.jpg');
      customPhoto.writeAsBytesSync([1, 2, 3, 4]);

      // 1. Custom Personal Photo Phase 2
      await tester.pumpWidget(
        wrapWithTheme(
          SplashScreen(
            key: const ValueKey('splash_custom_photo_instance'),
            minDuration: const Duration(milliseconds: 1000),
            customPhotoPath: customPhoto.path,
            onFinish: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(const ValueKey('splash_phase_seasonal_custom_photo')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('splash_custom_file_image')),
        findsOneWidget,
      );
      expect(find.text('Personal Sanctuary • Your Photo'), findsOneWidget);
      expect(find.text('Welcome Home'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));

      // 2. Remote Holiday Pack Phase 2
      await tester.pumpWidget(
        wrapWithTheme(
          SplashScreen(
            key: const ValueKey('splash_remote_pack_instance'),
            minDuration: const Duration(milliseconds: 1000),
            remotePackSlug: 'cherry-blossom-picnic',
            onFinish: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(
          const ValueKey('splash_phase_seasonal_pack_cherry-blossom-picnic'),
        ),
        findsOneWidget,
      );
      expect(find.text('Spring Pack • Cherry Blossom'), findsOneWidget);
      expect(find.text('Sakura Meadow Picnic'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('SettingsScreen downloads, activates, and removes Remote Holiday Wallpaper Pack in EN and ID', (tester) async {
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

      final customPhotoCard = find.byKey(
        const Key('settings_splash_personal_photo_card'),
      );
      await tester.scrollUntilVisible(
        customPhotoCard,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Personal Photo Wallpaper'), findsOneWidget);
      expect(find.text('Holiday & Seasonal Wallpaper Packs'), findsOneWidget);

      final downloadBtn = find.byKey(
        const Key('settings_splash_pack_download_cherry-blossom-picnic'),
      );
      await tester.scrollUntilVisible(
        downloadBtn,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await settings.installRemoteSplashPack(
          'cherry-blossom-picnic',
          activateOnInstall: true,
        );
      });
      await tester.pumpAndSettle();

      expect(
        settings.isRemoteSplashPackInstalled('cherry-blossom-picnic'),
        isTrue,
      );
      expect(settings.activeRemoteSplashPackSlug, 'cherry-blossom-picnic');
      expect(
        find.byKey(
          const Key('settings_splash_pack_remove_cherry-blossom-picnic'),
        ),
        findsOneWidget,
      );

      // Switch to Bahasa Indonesia and verify localized pack labels
      await settings.setLanguage(AppLanguage.id);
      await tester.pumpAndSettle();

      expect(find.text('Wallpaper Foto Pribadi'), findsOneWidget);
      expect(find.text('Paket Wallpaper Liburan & Musiman'), findsOneWidget);
      expect(find.text('Piknik Padang Sakura'), findsWidgets);

      await tester.runAsync(() async {
        await settings.removeRemoteSplashPack('cherry-blossom-picnic');
      });
      await tester.pumpAndSettle();

      expect(
        settings.isRemoteSplashPackInstalled('cherry-blossom-picnic'),
        isFalse,
      );
      expect(settings.activeRemoteSplashPackSlug, isNull);
    });
  });
}
