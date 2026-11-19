import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/l10n/app_language.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/l10n/app_translations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/mental_wellness_models.dart';
import 'package:nestin/data/services/device_control_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/break_the_cycle_provider.dart';
import 'package:nestin/providers/collection_provider.dart';
import 'package:nestin/providers/health_wellness_provider.dart';
import 'package:nestin/providers/hydration_provider.dart';
import 'package:nestin/providers/journal_provider.dart';
import 'package:nestin/providers/note_provider.dart';
import 'package:nestin/providers/reminder_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/providers/task_provider.dart';
import 'package:nestin/ui/screens/seren/mental_wellness_screen.dart';
import 'package:nestin/ui/widgets/quick_capture_sheet.dart';
import 'package:nestin/ui/widgets/seren_wellness_summary_card.dart';
import 'package:nestin/ui/widgets/seren/mindful_app_pause_dialog.dart';

Future<StorageService> _initFreshStorage() async {
  SharedPreferences.setMockInitialValues({});
  return StorageService.init();
}

Widget _wrapWithApp({
  required StorageService storage,
  required BreakTheCycleProvider btc,
  required SettingsProvider settings,
  required JournalProvider journal,
  ThemeMode? themeMode,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ChangeNotifierProvider<BreakTheCycleProvider>.value(value: btc),
      ChangeNotifierProvider<JournalProvider>.value(value: journal),
      ChangeNotifierProvider<HydrationProvider>(
        create: (_) => HydrationProvider(storage, NotificationService()),
      ),
      ChangeNotifierProvider<HealthWellnessProvider>(
        create: (_) => HealthWellnessProvider(storage, NotificationService()),
      ),
      ChangeNotifierProvider<NoteProvider>(
        create: (_) => NoteProvider(storage),
      ),
      ChangeNotifierProvider<TaskProvider>(
        create: (_) => TaskProvider(storage),
      ),
      ChangeNotifierProvider<ReminderProvider>(
        create: (_) => ReminderProvider(storage, NotificationService()),
      ),
      ChangeNotifierProvider<CollectionProvider>(
        create: (_) => CollectionProvider(storage),
      ),
    ],
    child: Consumer<SettingsProvider>(
      builder: (_, s, _) => MaterialApp(
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Models, Persistence & Anti-Guilt Invariants', () {
    test('MentalWellnessStateData serializes cleanly with zero guilt/streak keys', () async {
      final storage = await _initFreshStorage();
      final now = DateTime(2026, 11, 19, 20, 30);

      final goal = PersonalCommitmentGoal(
        id: 'goal_1',
        behaviorTitle: 'Late-night scrolling',
        intention: ChangeIntentionType.reduce,
        myWhy: 'Rested mornings',
        createdAt: now,
        updatedAt: now,
      );

      final pauseCfg = MindfulAppPauseConfig(
        isEnabled: true,
        monitoredPackages: const ['com.android.chrome'],
        monitoredAppNames: const {'com.android.chrome': 'Chrome'},
        pauseDurationSeconds: 4,
        cooldownGraceMinutes: 20,
        vulnerableHoursOnly: true,
        vulnerableStartHour: 22,
        vulnerableEndHour: 6,
      );

      final data = MentalWellnessStateData(
        comfortKitItems: ComfortKitItem.defaultStarterItems(now: now),
        commitments: [goal],
        mindfulAppPauseConfig: pauseCfg,
        personalBoundaries: PersonalBoundaryItem.defaultBoundaries(),
        qualitativeProgress: const QualitativeChangeProgress(
          reflectionsCompletedCount: 2,
          strategiesTriedCount: 4,
          goalsShapedCount: 1,
        ),
      );

      final encoded = jsonEncode(data.toJson());
      expect(encoded.contains('daysClean'), isFalse);
      expect(encoded.contains('streakCount'), isFalse);
      expect(encoded.contains('failureCount'), isFalse);

      await storage.saveMentalWellnessData(data);
      final backup = storage.exportFullBackupJson();

      // Clear and restore from full JSON backup
      final storage2 = await _initFreshStorage();
      final restored = await storage2.restoreFullBackupJson(backup);
      expect(restored, isTrue);

      final reloaded = storage2.loadMentalWellnessData();
      expect(reloaded.commitments.length, equals(1));
      expect(reloaded.commitments.first.myWhy, equals('Rested mornings'));
      expect(reloaded.mindfulAppPauseConfig.cooldownGraceMinutes, equals(20));
      expect(reloaded.qualitativeProgress.strategiesTriedCount, equals(4));
    });

    test('Shame-free setback reflection never resets qualitative progress', () async {
      final storage = await _initFreshStorage();
      final btc = BreakTheCycleProvider(storage);

      await btc.recordGroundingCompleted();
      await btc.recordUrgeSurfingCompleted();
      await btc.recordHealthyAlternativeExplored('alt_read_pages');

      final before = btc.qualitativeProgress;
      expect(before.groundingSessionsCompletedCount, equals(1));
      expect(before.strategiesTriedCount, equals(2));
      expect(before.alternativesExploredCount, equals(1));

      await btc.addRecoveryReflection(
        RecoveryReflectionEntry(
          id: 'rec_1',
          createdAt: DateTime(2026, 11, 19, 21, 0),
          whatHappened: 'Scrolled longer than planned after work stress',
          underlyingNeedOrFeeling: 'Exhausted',
          selfCompassionNote: 'I can rest now without blaming myself',
          nextSmallAdjustment: 'Put phone across room after 22:00',
        ),
      );

      final after = btc.qualitativeProgress;
      expect(after.groundingSessionsCompletedCount, equals(1));
      expect(after.strategiesTriedCount, equals(2));
      expect(after.alternativesExploredCount, equals(1));
      expect(after.reflectionsCompletedCount, equals(1));
      expect(btc.recoveryReflections.length, equals(1));
    });
  });

  group('Mindful App Pause (BTC-02) & Ephemeral Writing (SU-04 / SU-05)', () {
    test('MindfulAppPauseConfig handles cross-midnight window, cooldown & snooze', () async {
      final storage = await _initFreshStorage();
      final mockDevice = MockDeviceControlService()
        ..mockForegroundPackage = 'com.android.chrome';
      final btc = BreakTheCycleProvider(
        storage,
        deviceControlService: mockDevice,
      );

      await btc.updateMindfulAppPauseConfig(
        const MindfulAppPauseConfig(
          isEnabled: true,
          monitoredPackages: ['com.android.chrome'],
          monitoredAppNames: {'com.android.chrome': 'Chrome'},
          cooldownGraceMinutes: 15,
          vulnerableHoursOnly: true,
          vulnerableStartHour: 22,
          vulnerableEndHour: 6,
        ),
      );

      // Outside vulnerable window (14:00)
      final daytime = DateTime(2026, 11, 19, 14, 0);
      expect(await btc.checkForegroundAppForMindfulPause(now: daytime), isNull);

      // Inside cross-midnight vulnerable window (23:30)
      final night = DateTime(2026, 11, 19, 23, 30);
      expect(
        await btc.checkForegroundAppForMindfulPause(now: night),
        equals('com.android.chrome'),
      );

      // "I have a clear purpose — Continue" grants 15m cooldown grace with zero penalty
      btc.grantMindfulPauseClearPurposeContinue('com.android.chrome', now: night);
      expect(
        await btc.checkForegroundAppForMindfulPause(
          now: night.add(const Duration(minutes: 5)),
        ),
        isNull,
      );
      expect(
        await btc.checkForegroundAppForMindfulPause(
          now: night.add(const Duration(minutes: 16)),
        ),
        equals('com.android.chrome'),
      );

      // Snooze pauses intention checks cleanly for 1h
      await btc.snoozeMindfulAppPause(
        const Duration(hours: 1),
        now: night.add(const Duration(minutes: 16)),
      );
      expect(
        await btc.checkForegroundAppForMindfulPause(
          now: night.add(const Duration(minutes: 30)),
        ),
        isNull,
      );

      // Step back increments strategiesTriedCount
      await btc.recordMindfulPauseStepBack('com.android.chrome');
      expect(btc.qualitativeProgress.strategiesTriedCount, equals(1));
    });

    test('Let It Out & Unsent Letters support Save to Echo (Locked) vs Let It Go (Zero Trace)', () async {
      final storage = await _initFreshStorage();
      final btc = BreakTheCycleProvider(storage);
      final journal = JournalProvider(storage);
      final baselineCount = journal.journalEntries.length;

      // Ephemeral Let It Go writes zero journal entries
      btc.letItGoWithoutSaving();
      expect(journal.journalEntries.length, equals(baselineCount));

      // Save privately to Echo creates a private locked JournalEntry
      final saved = await btc.saveEphemeralWritingToEcho(
        journalProvider: journal,
        mode: EphemeralWritingMode.unsentLetter,
        title: 'Letter I did not send',
        content: 'Setting boundaries softly.',
      );
      expect(saved.isPrivate, isTrue);
      expect(saved.tags, containsAll(['Seren', 'UnsentLetter']));
      expect(journal.journalEntries.length, equals(baselineCount + 1));
      expect(btc.qualitativeProgress.reflectionsCompletedCount, equals(1));
    });

    test('All mw_* and btc_* translation keys exist in both EN and ID', () {
      final enKeys = kNestinTranslations['en']!;
      final idKeys = kNestinTranslations['id']!;
      final mwBtcKeys = enKeys.keys
          .where((k) =>
              k.startsWith('mw_') ||
              k.startsWith('btc_') ||
              k == 'qc_mental_aid' ||
              k == 'seren_summary_open_mental_wellness' ||
              k.startsWith('explore_mw_'))
          .toList();
      expect(mwBtcKeys.length, greaterThan(100));
      for (final key in mwBtcKeys) {
        expect(idKeys.containsKey(key), isTrue, reason: 'Missing ID key: $key');
        expect(idKeys[key]!.trim().isNotEmpty, isTrue);
      }
    });
  });

  group('MentalWellnessScreen, DiaryLockHelper & Entry Point Widget Tests', () {
    testWidgets('Felt-state door -> Guided Support -> 5-4-3-2-1 Grounding flow completes cleanly',
        (tester) async {
      await AppLocalizations.ensureDateFormatting();
      final storage = await _initFreshStorage();
      final settings = SettingsProvider(storage);
      final btc = BreakTheCycleProvider(storage);
      final journal = JournalProvider(storage);

      await tester.pumpWidget(
        _wrapWithApp(
          storage: storage,
          btc: btc,
          settings: settings,
          journal: journal,
          child: const MentalWellnessScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Open "I'm feeling overwhelmed"
      await tester.tap(find.byKey(const Key('mw_felt_state_overwhelmed')));
      await tester.pumpAndSettle();

      // Choose "Calm my body" -> opens 5-4-3-2-1 Grounding
      await tester.tap(find.byKey(const Key('mw_bucket_calmBody')));
      await tester.pumpAndSettle();

      expect(find.text('5-4-3-2-1 Sensory Grounding'), findsOneWidget);

      // Step through 5 -> 4 -> 3 -> 2 -> 1
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('mw_grounding_next_btn')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('mw_grounding_complete_btn')));
      await tester.pumpAndSettle();

      expect(btc.qualitativeProgress.groundingSessionsCompletedCount, equals(1));
    });

    testWidgets('Ephemeral Let It Out saves to Echo or clears cleanly on Let It Go',
        (tester) async {
      await AppLocalizations.ensureDateFormatting();
      final storage = await _initFreshStorage();
      final settings = SettingsProvider(storage);
      final btc = BreakTheCycleProvider(storage);
      final journal = JournalProvider(storage);
      final initialCount = journal.journalEntries.length;

      await tester.pumpWidget(
        _wrapWithApp(
          storage: storage,
          btc: btc,
          settings: settings,
          journal: journal,
          child: const MentalWellnessScreen(initialLayer: 2),
        ),
      );
      await tester.pumpAndSettle();

      // Open Let It Out
      final letItOutBtn = find.byKey(const Key('mw_open_let_it_out_btn'));
      await tester.ensureVisible(letItOutBtn);
      await tester.pumpAndSettle();
      await tester.tap(letItOutBtn);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('mw_ephemeral_text_field')),
        'Letting these racing thoughts go cleanly.',
      );
      await tester.tap(find.byKey(const Key('mw_ephemeral_let_it_go_btn')));
      await tester.pumpAndSettle();

      expect(journal.journalEntries.length, equals(initialCount));

      // Re-open and save privately to Echo
      await tester.ensureVisible(letItOutBtn);
      await tester.pumpAndSettle();
      await tester.tap(letItOutBtn);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('mw_ephemeral_text_field')),
        'Keep this reflection privately in Echo.',
      );
      await tester.tap(find.byKey(const Key('mw_ephemeral_save_to_echo_btn')));
      await tester.pumpAndSettle();

      expect(journal.journalEntries.length, equals(initialCount + 1));
      expect(journal.journalEntries.first.isPrivate, isTrue);
    });

    testWidgets('DiaryLockHelper gates private BTC records while acute tools stay open',
        (tester) async {
      await AppLocalizations.ensureDateFormatting();
      final storage = await _initFreshStorage();
      final settings = SettingsProvider(storage);
      await settings.updatePreferences(
        settings.preferences.copyWith(
          isDiaryLockEnabled: true,
          securityPin: '1234',
        ),
      );
      final btc = BreakTheCycleProvider(storage);
      final journal = JournalProvider(storage);

      await tester.pumpWidget(
        _wrapWithApp(
          storage: storage,
          btc: btc,
          settings: settings,
          journal: journal,
          child: const MentalWellnessScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Acute Immediate Urge Support & felt-state doors stay accessible
      expect(
        find.byKey(const Key('mw_immediate_urge_support_btn')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mw_felt_state_overwhelmed')),
        findsOneWidget,
      );

      // Private BTC records are shielded until unlocked
      final layer3Chip = find.byKey(const Key('mw_layer_chip_3'));
      await tester.ensureVisible(layer3Chip);
      await tester.pumpAndSettle();
      await tester.tap(layer3Chip);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('mw_btc_private_locked_card')),
      );
      expect(
        find.byKey(const Key('mw_btc_private_locked_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mw_btc_mindful_pause_switch')),
        findsOneWidget,
      );
    });

    testWidgets('MindfulAppPauseDialog displays My Why and Continue/Step Back/Snooze',
        (tester) async {
      await AppLocalizations.ensureDateFormatting();
      final storage = await _initFreshStorage();
      final settings = SettingsProvider(storage);
      final btc = BreakTheCycleProvider(storage);
      final journal = JournalProvider(storage);
      final now = DateTime.now();

      await btc.saveCommitment(
        PersonalCommitmentGoal(
          id: 'c1',
          behaviorTitle: 'Browser surfing',
          intention: ChangeIntentionType.manage,
          myWhy: 'Protect evening rest',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await btc.updateMindfulAppPauseConfig(
        const MindfulAppPauseConfig(
          isEnabled: true,
          monitoredPackages: ['com.android.chrome'],
          monitoredAppNames: {'com.android.chrome': 'Chrome'},
          pauseDurationSeconds: 3,
        ),
      );

      await tester.pumpWidget(
        _wrapWithApp(
          storage: storage,
          btc: btc,
          settings: settings,
          journal: journal,
          child: const Scaffold(
            body: MindfulAppPauseDialog(
              packageName: 'com.android.chrome',
              appDisplayName: 'Chrome',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Protect evening rest'), findsOneWidget);

      // Wait out 3-second intention countdown (1s per tick)
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      final continueBtn = tester.widget<OutlinedButton>(
        find.byKey(const Key('btc_mindful_pause_continue_btn')),
      );
      expect(continueBtn.onPressed, isNotNull);
    });

    testWidgets('Bahasa Indonesia & Light Theme render cleanly + entry points exist',
        (tester) async {
      await AppLocalizations.ensureDateFormatting();
      final storage = await _initFreshStorage();
      final settings = SettingsProvider(storage);
      await settings.setLanguage(AppLanguage.id);
      await settings.setThemeMode(ThemeMode.light);
      final btc = BreakTheCycleProvider(storage);
      final journal = JournalProvider(storage);

      // 1. MentalWellnessScreen in Bahasa Indonesia + Light theme
      await tester.pumpWidget(
        _wrapWithApp(
          storage: storage,
          btc: btc,
          settings: settings,
          journal: journal,
          themeMode: ThemeMode.light,
          child: const MentalWellnessScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dukungan Kesehatan Mental'), findsOneWidget);
      expect(find.text('Saya merasa kewalahan'), findsOneWidget);

      // 2. QuickCaptureSheet entry chip
      await tester.pumpWidget(
        _wrapWithApp(
          storage: storage,
          btc: btc,
          settings: settings,
          journal: journal,
          child: const Scaffold(body: QuickCaptureSheet()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('qc_mental_aid_chip')), findsOneWidget);

      // 3. SerenWellnessSummaryCard entry button
      await tester.pumpWidget(
        _wrapWithApp(
          storage: storage,
          btc: btc,
          settings: settings,
          journal: journal,
          child: const Scaffold(
            body: SingleChildScrollView(child: SerenWellnessSummaryCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('seren_summary_open_mental_wellness_btn')),
        findsOneWidget,
      );
    });
  });
}
