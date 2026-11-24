import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nestin/core/l10n/app_language.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/l10n/app_translations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/daily_wallpaper_config.dart';
import 'package:nestin/data/models/inspiration_models.dart';
import 'package:nestin/data/services/backend_gateway_service.dart';
import 'package:nestin/data/services/daily_wallpaper_service.dart';
import 'package:nestin/data/services/inspiration_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/inspiration_provider.dart';
import 'package:nestin/ui/widgets/inspiration/daily_wallpaper_sheet.dart';
import 'package:nestin/ui/widgets/inspiration/lock_screen_wallpaper_canvas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DailyWallpaperConfig serialization & StorageService backup', () {
    test('defaults are strictly opt-in with 05:00 lock-only schedule', () {
      const cfg = DailyWallpaperConfig();
      expect(cfg.enabled, isFalse);
      expect(cfg.template, DailyWallpaperTemplate.sanctuaryMinimal);
      expect(cfg.target, DailyWallpaperTarget.lockOnly);
      expect(cfg.quoteSource, DailyWallpaperSource.dailyFeatured);
      expect(cfg.refreshHour, 5);
      expect(cfg.refreshMinute, 0);
      expect(cfg.formattedRefreshTime, '05:00');
      expect(cfg.showMascotSprite, isTrue);
    });

    test('JSON round-trip preserves all fields', () {
      const original = DailyWallpaperConfig(
        enabled: true,
        template: DailyWallpaperTemplate.treehouseGlassCard,
        target: DailyWallpaperTarget.lockAndHome,
        quoteSource: DailyWallpaperSource.calmGrounded,
        refreshHour: 6,
        refreshMinute: 30,
        showMascotSprite: false,
        lastAppliedDate: '2026-11-24',
      );
      final restored = DailyWallpaperConfig.fromJson(original.toJson());
      expect(restored, equals(original));
      expect(restored.formattedRefreshTime, '06:30');
    });

    test('StorageService full backup export/restore round-trips config', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      const saved = DailyWallpaperConfig(
        enabled: true,
        template: DailyWallpaperTemplate.seasonalAtmosphere,
        target: DailyWallpaperTarget.lockAndHome,
        quoteSource: DailyWallpaperSource.favorites,
        refreshHour: 7,
        refreshMinute: 15,
        showMascotSprite: true,
        lastAppliedDate: '2026-11-24',
      );
      await storage.saveDailyWallpaperConfig(saved);
      final backupJson = storage.exportFullBackupJson();

      // Clear and restore into fresh prefs
      SharedPreferences.setMockInitialValues({});
      final freshPrefs = await SharedPreferences.getInstance();
      final freshStorage = StorageService(freshPrefs);
      expect(freshStorage.loadDailyWallpaperConfig().enabled, isFalse);

      final restoredOk = await freshStorage.restoreFullBackupJson(backupJson);
      expect(restoredOk, isTrue);
      expect(freshStorage.loadDailyWallpaperConfig(), equals(saved));
    });
  });

  group('DailyWallpaperService 7-day rolling cache & channel contract', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nestin_daily_wp_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('pre-renders 7 rolling PNGs, detects top-up threshold, and cleans expired files', () async {
      final fixedNow = DateTime(2026, 11, 24, 8, 0);
      final fakePng = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);

      final service = DailyWallpaperService(
        directoryProvider: () async => tempDir,
        nowProvider: () => fixedNow,
        pngRenderer: (_, _, _) async => fakePng,
        isAndroidOverride: true,
        isIosOverride: false,
      );

      // Seed expired file (2 days ago) and yesterday file (should stay)
      final cacheDir = await service.getCacheDirectory();
      final expiredFile = File(
        '${cacheDir.path}${Platform.pathSeparator}2026-11-22.png',
      );
      final yesterdayFile = File(
        '${cacheDir.path}${Platform.pathSeparator}2026-11-23.png',
      );
      await expiredFile.writeAsBytes(fakePng);
      await yesterdayFile.writeAsBytes(fakePng);

      expect(await service.needsCacheTopUp(from: fixedNow), isTrue);

      final paths = await service.preRenderRollingCache(
        config: const DailyWallpaperConfig(enabled: true),
        quoteForDate: (date, offset) => InspirationQuote(
          id: 'q_$offset',
          quoteText: 'Quiet steps carry you far on ${DailyWallpaperService.formatDateKey(date)}.',
          author: 'Pippin',
          category: 'calm',
          mascotDomain: 'pippin',
        ),
        isDark: true,
        l10n: const AppLocalizations(AppLanguage.en),
        startDate: fixedNow,
      );

      expect(paths.length, 7);
      expect(await service.countFutureCachedDays(from: fixedNow), 7);
      expect(await service.needsCacheTopUp(from: fixedNow), isFalse);

      // Expired (< yesterday) deleted; yesterday retained
      expect(await expiredFile.exists(), isFalse);
      expect(await yesterdayFile.exists(), isTrue);

      // Fast-forward 3 days: only 4 future days remain (< 5 threshold -> needs top-up)
      final threeDaysLater = fixedNow.add(const Duration(days: 3));
      expect(await service.countFutureCachedDays(from: threeDaysLater), 4);
      expect(await service.needsCacheTopUp(from: threeDaysLater), isTrue);
    });

    test('invokes Android MethodChannel methods with expected contract', () async {
      final calls = <Map<String, dynamic>>[];
      final service = DailyWallpaperService(
        directoryProvider: () async => tempDir,
        isAndroidOverride: true,
        isIosOverride: false,
        channelInvoker: (method, [args]) async {
          calls.add({'method': method, 'args': args});
          return true;
        },
      );

      const cfg = DailyWallpaperConfig(
        enabled: true,
        target: DailyWallpaperTarget.lockAndHome,
        refreshHour: 5,
        refreshMinute: 15,
      );

      expect(
        await service.applyWallpaperNow(
          filePath: '/tmp/2026-11-24.png',
          target: cfg.target,
        ),
        isTrue,
      );
      expect(await service.scheduleDailyWallpaper(cfg), isTrue);
      expect(await service.cancelDailyWallpaper(), isTrue);

      expect(calls.length, 3);
      expect(calls[0]['method'], 'applyWallpaperNow');
      expect(calls[0]['args'], {
        'filePath': '/tmp/2026-11-24.png',
        'target': 'both',
      });
      expect(calls[1]['method'], 'scheduleDailyWallpaper');
      expect((calls[1]['args'] as Map)['hour'], 5);
      expect((calls[1]['args'] as Map)['minute'], 15);
      expect((calls[1]['args'] as Map)['target'], 'both');
      expect(
        ((calls[1]['args'] as Map)['cacheDir'] as String)
            .endsWith(DailyWallpaperService.cacheFolderName),
        isTrue,
      );
      expect(calls[2]['method'], 'cancelDailyWallpaper');
    });
  });

  group('LockScreenWallpaperCanvas safe-zone layout & typography', () {
    test('computeAutoScaledFontSize scales from 26sp down to 19sp', () {
      expect(
        LockScreenWallpaperCanvas.computeAutoScaledFontSize('Breathe in slowly.'),
        26.0,
      );
      expect(
        LockScreenWallpaperCanvas.computeAutoScaledFontSize(
          'Langkah kecil yang tenang hari ini jauh lebih berarti daripada tergesa-gesa tanpa arah yang jelas.',
        ),
        lessThanOrEqualTo(23.5),
      );
      expect(
        LockScreenWallpaperCanvas.computeAutoScaledFontSize(
          'Tidak semua hal harus selesai hari ini; cukup ambil satu langkah yang sadar, pelan, dan jujur pada energimu, lalu biarkan sisanya menunggu esok hari dengan tenang tanpa rasa bersalah.',
        ),
        19.0,
      );
    });

    for (final template in DailyWallpaperTemplate.values) {
      for (final isDark in [true, false]) {
        for (final width in [360.0, 390.0]) {
          testWidgets(
            '${template.name} (${isDark ? 'dark' : 'light'}, ${width.toInt()}dp) enforces 30/38/32 safe zones with long ID text',
            (tester) async {
              final height = width * 16 / 9;
              await tester.binding.setSurfaceSize(Size(width, height));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              await tester.pumpWidget(
                MaterialApp(
                  theme: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
                  home: Scaffold(
                    body: Center(
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: LockScreenWallpaperCanvas(
                          quoteText:
                              'Tidak semua hal harus selesai hari ini; cukup ambil satu langkah kecil yang tenang dan sadar untuk menjaga ruang damaimu.',
                          authorName: 'Pippin Sanctuary',
                          mascotDomain: 'seren',
                          template: template,
                          isDark: isDark,
                          referenceDate: DateTime(2026, 11, 24),
                          l10nOverride: const AppLocalizations(AppLanguage.id),
                        ),
                      ),
                    ),
                  ),
                ),
              );

              final topSize = tester.getSize(
                find.byKey(const ValueKey('lock_screen_top_safe_zone')),
              );
              final midSize = tester.getSize(
                find.byKey(const ValueKey('lock_screen_sanctuary_band')),
              );
              final botSize = tester.getSize(
                find.byKey(const ValueKey('lock_screen_bottom_safe_zone')),
              );

              expect(topSize.height, closeTo(height * 0.30, 1.0));
              expect(midSize.height, closeTo(height * 0.38, 1.0));
              expect(botSize.height, closeTo(height * 0.32, 1.0));
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  });

  group('DailyWallpaperSheet platform UX & responsiveness', () {
    Future<InspirationProvider> buildProvider({required bool isAndroid}) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      final inspirationService = InspirationService(
        prefs,
        BackendGatewayService(prefs),
      );
      final wpService = DailyWallpaperService(
        isAndroidOverride: isAndroid,
        isIosOverride: !isAndroid,
        channelInvoker: (_, [_]) async => true,
      );
      return InspirationProvider(
        inspirationService,
        storageService: storage,
        dailyWallpaperService: wpService,
      );
    }

    testWidgets('Android sheet renders auto-update toggle, target selector, and apply CTA without overflow at 360dp', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final provider = await buildProvider(isAndroid: true);
      await tester.pumpWidget(
        ChangeNotifierProvider<InspirationProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: DailyWallpaperSheet(
                initialQuoteText: 'Take one calm breath before the next step.',
                initialAuthorName: 'Seren',
                initialMascotDomain: 'seren',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Auto-Update Daily Lock Screen'), findsWidgets);
      expect(find.text('Mock OS Clock'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Sanctuary Minimal'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(find.text('Sanctuary Minimal'), findsOneWidget);
      expect(find.text('Seasonal Atmosphere'), findsOneWidget);
      expect(find.text('Treehouse Glass Card'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text("Apply Today's Wallpaper Now"),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(find.text('Lock Screen Only'), findsOneWidget);
      expect(find.text("Apply Today's Wallpaper Now"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('iOS sheet hides Android auto-apply flags and shows Save to Photos CTA', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final provider = await buildProvider(isAndroid: false);
      await tester.pumpWidget(
        ChangeNotifierProvider<InspirationProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: DailyWallpaperSheet(
                initialQuoteText: 'One calm step is enough for today.',
                initialAuthorName: 'Pippin',
                initialMascotDomain: 'pippin',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Daily Lock Screen Studio'), findsOneWidget);
      expect(find.text('Lock Screen Only'), findsNothing);
      expect(find.text('Daily Refresh Time'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('EN/ID localization parity for daily_wp_* keys', () {
    const requiredKeys = [
      'daily_wp_entry_title',
      'daily_wp_entry_desc',
      'daily_wp_entry_active_desc',
      'daily_wp_badge_active',
      'daily_wp_title_android',
      'daily_wp_subtitle_android',
      'daily_wp_title_ios',
      'daily_wp_subtitle_ios',
      'daily_wp_mock_clock_toggle',
      'daily_wp_show_bird_toggle',
      'daily_wp_auto_update_toggle',
      'daily_wp_auto_update_desc',
      'daily_wp_ios_honest_note',
      'daily_wp_template_section',
      'daily_wp_tpl_sanctuary_minimal',
      'daily_wp_tpl_sanctuary_minimal_desc',
      'daily_wp_tpl_seasonal_atmosphere',
      'daily_wp_tpl_seasonal_atmosphere_desc',
      'daily_wp_tpl_treehouse_glass',
      'daily_wp_tpl_treehouse_glass_desc',
      'daily_wp_source_section',
      'daily_wp_source_featured',
      'daily_wp_source_favorites',
      'daily_wp_source_calm_grounded',
      'daily_wp_target_section',
      'daily_wp_target_lock_only',
      'daily_wp_target_lock_and_home',
      'daily_wp_refresh_time_label',
      'daily_wp_refresh_time_desc',
      'daily_wp_apply_now_cta',
      'daily_wp_save_to_photos_cta',
      'daily_wp_applied_success',
      'daily_wp_apply_failed',
      'daily_wp_ios_ready_to_save',
      'daily_wp_ios_saved_locally',
      'daily_wp_label_daily_spark',
      'daily_wp_label_gentle_reminder',
      'daily_wp_label_quiet_reflection',
      'daily_wp_label_steady_rhythm',
      'daily_wp_label_mindful_note',
      'daily_wp_label_clear_horizon',
    ];

    test('all daily_wp_* keys exist in app_translations.dart and both ARB files', () {
      final enMap = kNestinTranslations['en']!;
      final idMap = kNestinTranslations['id']!;
      final enArb = jsonDecode(
        File('assets/l10n/app_en.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      final idArb = jsonDecode(
        File('assets/l10n/app_id.arb').readAsStringSync(),
      ) as Map<String, dynamic>;

      for (final key in requiredKeys) {
        expect(enMap[key], isNotNull, reason: 'Missing EN translation: $key');
        expect(enMap[key]!.trim(), isNotEmpty);
        expect(idMap[key], isNotNull, reason: 'Missing ID translation: $key');
        expect(idMap[key]!.trim(), isNotEmpty);
        expect(enArb[key], equals(enMap[key]), reason: 'EN ARB mismatch: $key');
        expect(idArb[key], equals(idMap[key]), reason: 'ID ARB mismatch: $key');
      }
    });
  });
}
