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
import 'package:nestin/data/models/mascot_companion.dart';
import 'package:nestin/data/models/user_preferences.dart';
import 'package:nestin/data/services/audio_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/oem_hardening_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/main.dart';
import 'package:nestin/providers/account_provider.dart';
import 'package:nestin/providers/device_control_provider.dart';
import 'package:nestin/providers/geofence_provider.dart';
import 'package:nestin/providers/money_provider.dart';
import 'package:nestin/providers/oem_hardening_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/providers/sound_provider.dart';
import 'package:nestin/providers/wearable_provider.dart';
import 'package:nestin/ui/screens/onboarding/mascot_onboarding_screen.dart';
import 'package:nestin/ui/screens/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithSettings(
    SettingsProvider settings,
    Widget child, {
    ThemeMode? themeMode,
  }) {
    return ChangeNotifierProvider<SettingsProvider>.value(
      value: settings,
      child: Consumer<SettingsProvider>(
        builder: (context, s, _) => MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode ?? s.themeMode,
          locale: s.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: child,
        ),
      ),
    );
  }

  group('NestinFlock & MascotCompanionProfile Domain Tests', () {
    test('Defines all 6 bird companions with verified sprite assets and offline-safe copy', () {
      expect(NestinFlock.companions.length, equals(6));
      expect(
        NestinFlock.companions.map((m) => m.name).toList(),
        equals(['Roo', 'Scout', 'Seren', 'Pippin', 'Twill', 'Echo']),
      );

      for (final id in NestinMascotId.values) {
        final bird = NestinFlock.byId(id);
        expect(bird.id, equals(id));
        expect(bird.roles.length, greaterThanOrEqualTo(3));
        expect(bird.species(false), isNotEmpty);
        expect(bird.species(true), isNotEmpty);
        expect(bird.archetype(false), isNotEmpty);
        expect(bird.archetype(true), isNotEmpty);
        expect(bird.domainTitle(false), isNotEmpty);
        expect(bird.domainTitle(true), isNotEmpty);
        expect(bird.speech(false), isNotEmpty);
        expect(bird.speech(false, alternate: true), isNotEmpty);
        expect(bird.speech(true), isNotEmpty);
        expect(bird.speech(true, alternate: true), isNotEmpty);

        // Verify sprite assets declared in NestinFlock exist on disk.
        expect(
          File(bird.primarySpriteAsset).existsSync(),
          isTrue,
          reason: 'Missing ${bird.primarySpriteAsset}',
        );
        expect(
          File(bird.altSpriteAsset).existsSync(),
          isTrue,
          reason: 'Missing ${bird.altSpriteAsset}',
        );
      }

      // Verify Twill stays strictly offline personal money management (no banking claims).
      final twill = NestinFlock.byId(NestinMascotId.twill);
      final combinedTwillCopy = [
        twill.primarySpeechEn,
        twill.altSpeechEn,
        ...twill.roles.map((r) => r.labelEn),
      ].join(' ').toLowerCase();
      expect(combinedTwillCopy.contains('payment'), isFalse);
      expect(combinedTwillCopy.contains('transfer'), isFalse);
      expect(combinedTwillCopy.contains('offline'), isTrue);
    });

    test('UserPreferences and SettingsProvider persist hasCompletedOnboarding', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final settings = SettingsProvider(storage);

      expect(settings.hasCompletedOnboarding, isFalse);

      final legacy = UserPreferences.fromJson({'use24Hour': true});
      expect(legacy.hasCompletedOnboarding, isFalse);

      await settings.completeMascotOnboarding();
      expect(settings.hasCompletedOnboarding, isTrue);

      final reloaded = SettingsProvider(storage);
      expect(reloaded.hasCompletedOnboarding, isTrue);

      final backupJson = storage.exportFullBackupJson();
      await reloaded.resetMascotOnboarding();
      expect(reloaded.hasCompletedOnboarding, isFalse);

      final restored = await storage.restoreFullBackupJson(backupJson);
      expect(restored, isTrue);
      expect(SettingsProvider(storage).hasCompletedOnboarding, isTrue);
    });

    test('Minimalist onboarding EN/ID localization keys match 100% across translations and ARBs', () {
      final enMap = kNestinTranslations['en']!;
      final idMap = kNestinTranslations['id']!;
      final enArb =
          jsonDecode(File('assets/l10n/app_en.arb').readAsStringSync())
              as Map<String, dynamic>;
      final idArb =
          jsonDecode(File('assets/l10n/app_id.arb').readAsStringSync())
              as Map<String, dynamic>;

      const keys = [
        'onb_skip',
        'onb_close',
        'onb_cta_explore',
        'onb_cta_learn_more',
        'onb_cta_continue',
        'onb_cta_enter',
        'onb_cta_finish',
        'onb_welcome_lead',
        'onb_welcome_hl',
        'onb_roo_p1_hl',
        'onb_roo_p2_hl',
        'onb_scout_p1_hl',
        'onb_scout_p2_hl',
        'onb_seren_p1_hl',
        'onb_seren_p2_hl',
        'onb_pippin_p1_hl',
        'onb_pippin_p2_hl',
        'onb_twill_p1_hl',
        'onb_twill_p2_hl',
        'onb_echo_p1_hl',
        'onb_echo_p2_hl',
        'onb_ready_hl',
      ];

      for (final k in keys) {
        expect(enMap.containsKey(k), isTrue, reason: 'Missing EN tr: $k');
        expect(idMap.containsKey(k), isTrue, reason: 'Missing ID tr: $k');
        expect(enArb.containsKey(k), isTrue, reason: 'Missing EN arb: $k');
        expect(idArb.containsKey(k), isTrue, reason: 'Missing ID arb: $k');
      }
    });
  });

  group('MascotOnboardingScreen Minimalist Multi-Page Tour Tests', () {
    testWidgets(
      'Steps through Welcome + 2 focused pages per bird (14 slides), toggles EN/ID, bounces hero & completes',
      (tester) async {
        tester.view.physicalSize = const Size(412, 860);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        await AppLocalizations.ensureDateFormatting();
        final storage = await StorageService.init();
        final settings = SettingsProvider(storage);

        var completedCallbackCount = 0;

        await tester.pumpWidget(
          wrapWithSettings(
            settings,
            MascotOnboardingScreen(
              onCompleted: () => completedCallbackCount++,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Slide 0: Minimalist Welcome
        expect(find.text('Welcome to Nestin'), findsOneWidget);
        expect(find.text('Explore'), findsOneWidget);

        await tester.tap(find.byKey(const Key('onboarding_primary_cta')));
        await tester.pumpAndSettle();

        // Slide 1: Roo Page 1 of 2
        expect(find.text('Roo'), findsOneWidget);
        expect(find.text('1/2'), findsOneWidget);
        expect(find.text('Wake up on time with smart alarms'), findsOneWidget);
        expect(find.text('Learn more'), findsOneWidget);

        // Tap mascot hero swaps reaction pose cleanly
        await tester.tap(find.byKey(const Key('onboarding_mascot_roo_1')));
        await tester.pumpAndSettle();

        // Live toggle to Bahasa Indonesia on the fly, then back to EN
        await tester.tap(find.byKey(const Key('onboarding_lang_toggle')));
        await tester.pumpAndSettle();
        expect(settings.language, equals(AppLanguage.id));
        expect(
          find.text('Bangun tepat waktu dengan alarm pintar'),
          findsOneWidget,
        );
        expect(find.text('Selengkapnya'), findsOneWidget);

        await tester.tap(find.byKey(const Key('onboarding_lang_toggle')));
        await tester.pumpAndSettle();
        expect(settings.language, equals(AppLanguage.en));

        // Slide 2: Roo Page 2 of 2
        await tester.tap(find.byKey(const Key('onboarding_primary_cta')));
        await tester.pumpAndSettle();
        expect(find.text('2/2'), findsOneWidget);
        expect(find.text('Build daily habits and stay focused'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);

        // Step through remaining 5 birds × 2 pages (10 slides)
        const expectedHeadlines = [
          'Step out prepared with BeforeYouGo',
          'Quietly automates your everyday flow',
          'Pause and breathe in calm spaces',
          'Gentle daily care for your body',
          'Grow your passions and reading goals',
          'Spark curiosity and bucket lists',
          'Keep notes and lists effortlessly tidy',
          'Manage your personal money offline',
          'Reflect softly and keep gratitude close',
          'Preserve memories and quiet curiosity',
        ];

        for (final headline in expectedHeadlines) {
          await tester.tap(find.byKey(const Key('onboarding_primary_cta')));
          await tester.pumpAndSettle();
          expect(find.text(headline), findsOneWidget);
        }

        // Slide 13: All-set Ready summary
        await tester.tap(find.byKey(const Key('onboarding_primary_cta')));
        await tester.pumpAndSettle();
        expect(find.text('Your six companions are ready'), findsOneWidget);
        expect(find.text('Enter Nestin'), findsOneWidget);

        await tester.tap(find.byKey(const Key('onboarding_primary_cta')));
        await tester.pumpAndSettle();

        expect(completedCallbackCount, equals(1));
        expect(settings.hasCompletedOnboarding, isTrue);
      },
    );

    testWidgets('Skip button completes onboarding immediately', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final settings = SettingsProvider(storage);

      await tester.pumpWidget(
        wrapWithSettings(settings, const MascotOnboardingScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onboarding_skip_button')));
      await tester.pumpAndSettle();

      expect(settings.hasCompletedOnboarding, isTrue);
    });

    testWidgets(
      'Renders cleanly without overflow in Light & Dark modes on 360x640 narrow viewport',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        final storage = await StorageService.init();
        final settings = SettingsProvider(storage);

        // Twill Page 2 (index 10) in Light mode at 360x640
        await tester.pumpWidget(
          wrapWithSettings(
            settings,
            const MascotOnboardingScreen(key: ValueKey('p10'), initialPage: 10),
            themeMode: ThemeMode.light,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Twill'), findsOneWidget);
        expect(find.text('Manage your personal money offline'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Ready summary (index 13) in Dark mode at 360x640 + tap bird jumps back
        await tester.pumpWidget(
          wrapWithSettings(
            settings,
            const MascotOnboardingScreen(
              key: ValueKey('p13'),
              initialPage: MascotOnboardingScreen.readyPageIndex,
            ),
            themeMode: ThemeMode.dark,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Your six companions are ready'), findsOneWidget);

        await tester.tap(find.byKey(const Key('onboarding_ready_bird_seren')));
        await tester.pumpAndSettle();
        expect(find.text('Seren'), findsOneWidget);
        expect(find.text('Pause and breathe in calm spaces'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('NestinApp First Launch & Settings Replay Integration Tests', () {
    testWidgets(
      'NestinApp shows MascotOnboardingScreen for first-time user then enters MainNavigationScreen',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        await AppLocalizations.ensureDateFormatting();
        final storage = await StorageService.init();

        await tester.pumpWidget(
          NestinApp(
            storageService: storage,
            audioService: AudioService(),
            notificationService: NotificationService(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Welcome to Nestin'), findsOneWidget);

        await tester.tap(find.byKey(const Key('onboarding_skip_button')));
        await tester.pumpAndSettle();

        expect(storage.loadPreferences().hasCompletedOnboarding, isTrue);
        expect(find.text('Welcome to Nestin'), findsNothing);
        expect(find.text('Dashboard'), findsAtLeastNWidgets(1));
        expect(find.text('Nest'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'SettingsScreen exposes Replay Onboarding Tour and pops back cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        await AppLocalizations.ensureDateFormatting();
        final storage = await StorageService.init();
        final settings = SettingsProvider(storage);
        await settings.completeMascotOnboarding();
        final notifications = NotificationService();
        final oem = OemHardeningProvider(
          storage,
          MockOemHardeningService(
            manufacturer: 'Pixel',
            brand: 'Google',
            model: 'Pixel 9',
            isIgnoringBatteryOptimizations: true,
            isKeepAliveRunning: false,
          ),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<StorageService>.value(value: storage),
              Provider<NotificationService>.value(value: notifications),
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider(create: (_) => SoundProvider(storage)),
              ChangeNotifierProvider(create: (_) => WearableProvider(storage)),
              ChangeNotifierProvider<OemHardeningProvider>.value(value: oem),
              ChangeNotifierProvider(
                create: (_) => GeofenceProvider(
                  storage,
                  notifications,
                  autoInitializeNative: false,
                ),
              ),
              ChangeNotifierProvider(create: (_) => MoneyProvider(storage)),
              ChangeNotifierProvider(
                create: (_) => DeviceControlProvider(
                  storage,
                  notifications: notifications,
                ),
              ),
              ChangeNotifierProvider(create: (_) => AccountProvider(storage)),
            ],
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final replayBtn =
            find.byKey(const Key('settings_replay_mascot_tour_button'));
        await tester.scrollUntilVisible(
          replayBtn,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Meet the 6 Bird Companions'), findsOneWidget);

        await tester.tap(replayBtn);
        await tester.pumpAndSettle();

        expect(find.text('Welcome to Nestin'), findsOneWidget);
        expect(find.text('Close'), findsOneWidget);

        await tester.tap(find.byKey(const Key('onboarding_skip_button')));
        await tester.pumpAndSettle();

        expect(find.text('Settings'), findsOneWidget);
      },
    );
  });
}
