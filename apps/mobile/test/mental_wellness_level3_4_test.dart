import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/l10n/app_translations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/journal_entry.dart';
import 'package:nestin/data/models/mental_wellness_models.dart';
import 'package:nestin/data/services/device_control_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/break_the_cycle_provider.dart';
import 'package:nestin/providers/journal_provider.dart';
import 'package:nestin/providers/routine_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/ui/screens/journal/timeline_screen.dart';
import 'package:nestin/ui/screens/seren/mental_wellness_screen.dart';
import 'package:nestin/ui/widgets/security_pin_gate_sheet.dart';

Future<StorageService> _initFreshStorage() async {
  SharedPreferences.setMockInitialValues({});
  return StorageService.init();
}

Widget _wrapWithApp({
  required SettingsProvider settings,
  required JournalProvider journal,
  required BreakTheCycleProvider btc,
  required RoutineProvider routines,
  required Widget home,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ChangeNotifierProvider<JournalProvider>.value(value: journal),
      ChangeNotifierProvider<BreakTheCycleProvider>.value(value: btc),
      ChangeNotifierProvider<RoutineProvider>.value(value: routines),
    ],
    child: MaterialApp(
      locale: const Locale('en', 'US'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.lightTheme,
      home: home,
    ),
  );
}

Future<void> _scrollMainAndTap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        finder,
        260.0,
        scrollable: scrollable.first,
      );
    }
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _ensureVisibleAndTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Level 3 & 4 Models, Backup Roundtrip & Passphrase Encryption', () {
    test(
      'MentalWellnessStateData roundtrips bookmarks, insights, wellbeingGoals, '
      'and remote crisis/directory overrides through full backup',
      () async {
        final storage = await _initFreshStorage();
        final now = DateTime(2026, 11, 19, 22, 0);

        final original = MentalWellnessStateData(
          bookmarkedGuideIds: const ['guide_stress', 'guide_boundaries'],
          personalInsights: [
            PersonalInsightNote(
              id: 'ins_1',
              title: 'Quiet evening walk helps',
              observation: 'Urges soften when stepping outside for 5 minutes.',
              relatedGuideId: 'guide_habit_loop',
              createdAt: now,
            ),
          ],
          wellbeingGoals: [
            PersonalWellbeingGoal(
              id: 'goal_custom_1',
              title: 'Dim desk lamp after 21:00',
              categoryKey: 'mw_l3_goal_cat_rest',
              isActive: true,
              createdAt: now,
            ),
          ],
          remoteCrisisOverrides: const [
            CrisisResourceEntry(
              id: 'crisis_sync_1',
              region: SupportRegionFilter.id,
              organizationName: 'Healing119 Editorial Update',
              roleKey: 'mw_l4_crisis_id_sejiwa_role',
              phoneOrShortcode: '119',
              websiteUrl: 'https://healing119.id/',
              verifiedSource: 'Kemenkes RI',
              lastVerifiedDate: '2026-11-19',
            ),
          ],
          remoteDirectoryOverrides: const [
            SupportDirectoryEntry(
              id: 'dir_sync_1',
              region: SupportRegionFilter.global,
              organizationName: 'Global Care Network',
              serviceTypeKey: 'mw_l4_dir_listening',
              descriptionKey: 'mw_l4_dir_global_befrienders_desc',
              websiteUrl: 'https://www.befrienders.org/',
              verifiedSource: 'Editorial Board',
              lastVerifiedDate: '2026-11-19',
            ),
          ],
        );

        await storage.saveMentalWellnessData(original);
        final exportedJson = storage.exportFullBackupJson();

        final cleanStorage = await _initFreshStorage();
        final restoredOk =
            await cleanStorage.restoreFullBackupJson(exportedJson);
        expect(restoredOk, isTrue);

        final loaded = cleanStorage.loadMentalWellnessData();
        expect(
          loaded.bookmarkedGuideIds,
          equals(['guide_stress', 'guide_boundaries']),
        );
        expect(loaded.personalInsights.single.title, 'Quiet evening walk helps');
        expect(loaded.wellbeingGoals.single.isActive, isTrue);
        expect(
          loaded.remoteCrisisOverrides.single.lastVerifiedDate,
          '2026-11-19',
        );
        expect(
          loaded.remoteDirectoryOverrides.single.organizationName,
          'Global Care Network',
        );
      },
    );

    test(
      'MentalWellnessCryptoHelper & BreakTheCycleProvider encrypt, decrypt, '
      'reject wrong passphrases, and reject tampered ciphertexts',
      () async {
        final storage = await _initFreshStorage();
        final btc = BreakTheCycleProvider(
          storage,
          deviceControlService: MockDeviceControlService(),
        );

        await btc.addPersonalInsightNote(
          title: 'Catatan Malam 🌿',
          observation: 'Tarik napas pelan sebelum menutup layar kerja.',
        );
        await btc.saveCommitment(
          PersonalCommitmentGoal(
            id: 'c_enc_1',
            behaviorTitle: 'Late-night scrolling',
            intention: ChangeIntentionType.reduce,
            myWhy: 'Rested mornings with clear energy',
            createdAt: DateTime(2026, 11, 19),
            updatedAt: DateTime(2026, 11, 19),
          ),
        );

        final envelopeJson = btc.exportEncryptedBackup('nestin-secret-99');
        final parsed = jsonDecode(envelopeJson) as Map<String, dynamic>;
        expect(parsed['format'], MentalWellnessCryptoHelper.envelopeFormat);
        expect(envelopeJson, isNot(contains('Late-night scrolling')));
        expect(envelopeJson, isNot(contains('Catatan Malam')));

        // Wrong passphrase must fail safely
        final cleanStorage = await _initFreshStorage();
        final cleanBtc = BreakTheCycleProvider(
          cleanStorage,
          deviceControlService: MockDeviceControlService(),
        );
        expect(
          await cleanBtc.importEncryptedBackup(envelopeJson, 'wrong-pass'),
          isFalse,
        );

        // Tampered ciphertext must fail MAC verification
        final tamperedMap = Map<String, dynamic>.from(parsed)
          ..['ciphertext'] = base64Encode(utf8.encode('tampered-bytes'));
        expect(
          await cleanBtc.importEncryptedBackup(
            jsonEncode(tamperedMap),
            'nestin-secret-99',
          ),
          isFalse,
        );

        // Correct passphrase restores full UTF-8 state
        expect(
          await cleanBtc.importEncryptedBackup(
            envelopeJson,
            'nestin-secret-99',
          ),
          isTrue,
        );
        expect(cleanBtc.personalInsights.single.title, 'Catatan Malam 🌿');
        expect(
          cleanBtc.commitments.single.behaviorTitle,
          'Late-night scrolling',
        );
      },
    );
  });

  group('Level 3 & 4 Provider Operations, Crisis Catalog & Granular Deletion',
      () {
    test(
      'Educational guides, guided reflection to Echo, insights, wellbeing goals, '
      'crisis overrides, and granular deletion behave cleanly without streaks',
      () async {
        final storage = await _initFreshStorage();
        final btc = BreakTheCycleProvider(
          storage,
          deviceControlService: MockDeviceControlService(),
        );
        final journal = JournalProvider(storage);
        final now = DateTime(2026, 11, 19, 21, 30);

        // 7 offline educational guides + starter goals seeded
        expect(EducationalGuideSpec.catalog.length, 7);
        expect(btc.wellbeingGoals.length, 4);

        // Guide bookmark + guided reflection into Echo
        await btc.toggleGuideBookmark('guide_emotions');
        expect(btc.bookmarkedGuideIds, contains('guide_emotions'));
        await btc.toggleGuideBookmark('guide_emotions');
        expect(btc.bookmarkedGuideIds, isNot(contains('guide_emotions')));

        final reflected = await btc.saveGuidedReflectionToEcho(
          journalProvider: journal,
          promptTitle: 'Understanding Mixed Emotions',
          reflectionText: 'Felt both relieved and tired after finishing.',
          guideId: 'guide_emotions',
          mood: JournalMood.good,
        );
        expect(reflected.isPrivate, isTrue);
        expect(reflected.tags, contains('GuidedReflection'));
        expect(journal.journalEntries.any((e) => e.id == reflected.id), isTrue);

        // Regional Crisis & Support Directory filtering + backend override
        final idLifelines = btc.crisisResourcesForRegion(SupportRegionFilter.id);
        expect(idLifelines.any((e) => e.phoneOrShortcode == '119'), isTrue);
        expect(
          idLifelines.any((e) => e.region == SupportRegionFilter.global),
          isTrue,
        );
        final usLifelines = btc.crisisResourcesForRegion(SupportRegionFilter.us);
        expect(usLifelines.any((e) => e.phoneOrShortcode == '988'), isTrue);
        expect(usLifelines.any((e) => e.phoneOrShortcode == '119'), isFalse);

        final syncedOk = await btc.applyBackendDirectoryPayload({
          'crisisResources': [
            const CrisisResourceEntry(
              id: 'crisis_sync_override',
              region: SupportRegionFilter.id,
              organizationName: 'Synced Kemenkes 119',
              roleKey: 'mw_l4_crisis_id_sejiwa_role',
              phoneOrShortcode: '119',
              verifiedSource: 'Backend Pipeline',
              lastVerifiedDate: '2026-11-19',
            ).toJson(),
          ],
          'directoryEntries': [],
        });
        expect(syncedOk, isTrue);
        expect(
          btc
              .crisisResourcesForRegion(SupportRegionFilter.id)
              .any((e) => e.organizationName == 'Synced Kemenkes 119'),
          isTrue,
        );

        // Granular record deletions & full reset
        await btc.addTriggerReflection(
          TriggerReflectionEntry(
            id: 'trig_del_1',
            createdAt: now,
            emotionalState: 'Restless',
          ),
        );
        await btc.addRecoveryReflection(
          RecoveryReflectionEntry(
            id: 'rec_del_1',
            createdAt: now,
            whatHappened: 'Scrolled longer than planned',
          ),
        );
        await btc.savePersonalSupportPlan(
          const PersonalSupportPlan(preferredWaysToAskForHelp: 'Short SMS'),
        );
        await btc.saveRelapsePreventionPlan(
          const RelapsePreventionPlan(knownTriggers: 'Late evening'),
        );
        await btc.addWellbeingGoal(title: 'Morning stretch');

        final customGoalId = btc.wellbeingGoals
            .firstWhere((g) => g.title == 'Morning stretch')
            .id;
        await btc.toggleWellbeingGoal(customGoalId);
        expect(
          btc.wellbeingGoals.firstWhere((g) => g.id == customGoalId).isActive,
          isFalse,
        );
        await btc.deleteWellbeingGoal(customGoalId);
        expect(
          btc.wellbeingGoals.any((g) => g.id == customGoalId),
          isFalse,
        );

        await btc.deleteTriggerReflection('trig_del_1');
        expect(btc.triggerReflections, isEmpty);
        await btc.deleteRecoveryReflection('rec_del_1');
        expect(btc.recoveryReflections, isEmpty);
        await btc.clearPersonalSupportPlan();
        expect(btc.personalSupportPlan.hasContent, isFalse);
        await btc.clearRelapsePreventionPlan();
        expect(btc.relapsePreventionPlan.hasContent, isFalse);

        await btc.addPersonalInsightNote(
          title: 'Temp insight',
          observation: 'Test observation',
        );
        await btc.resetAllMentalWellnessData();
        expect(btc.personalInsights, isEmpty);
        expect(btc.commitments, isEmpty);
        // Starter non-identifying defaults remain ready for fresh use
        expect(btc.wellbeingGoals.length, 4);
      },
    );
  });

  group('Level 3 & 4 Bilingual Localization Parity (EN & ID)', () {
    test(
      'All mw_l3_*, mw_l4_*, mw_hl_*, and su_guide_* keys exist cleanly in EN and ID',
      () {
        final en = kNestinTranslations['en'] ?? {};
        final id = kNestinTranslations['id'] ?? {};

        final level34Keys = en.keys
            .where(
              (k) =>
                  k.startsWith('mw_l3_') ||
                  k.startsWith('mw_l4_') ||
                  k.startsWith('mw_hl_') ||
                  k.startsWith('su_guide_'),
            )
            .toList();
        expect(level34Keys.length, greaterThanOrEqualTo(155));

        for (final key in level34Keys) {
          expect(en[key]?.trim().isNotEmpty, isTrue,
              reason: 'Empty EN value for $key');
          expect(id.containsKey(key), isTrue,
              reason: 'Missing ID translation for $key');
          expect(id[key]?.trim().isNotEmpty, isTrue,
              reason: 'Empty ID value for $key');
        }
      },
    );
  });

  group('Level 3 & 4 MentalWellnessScreen Widget Workflows', () {
    const widgetsChannel = MethodChannel('com.nestin.app/widgets');
    final capturedChannelCalls = <MethodCall>[];

    setUp(() {
      capturedChannelCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(widgetsChannel, (call) async {
        capturedChannelCalls.add(call);
        if (call.method == 'launchExternalUri') {
          return true;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(widgetsChannel, null);
    });

    testWidgets(
      'Crisis-Safety Override opens unlocked under DiaryLock, filters ID/US/Global, '
      'and launches verified tel: lifeline intent',
      (tester) async {
        final storage = await _initFreshStorage();
        final settings = SettingsProvider(storage);
        final journal = JournalProvider(storage);
        final btc = BreakTheCycleProvider(
          storage,
          deviceControlService: MockDeviceControlService(),
        );
        final routines = RoutineProvider(storage);

        await settings.setSecurityPin('1357');
        await settings.toggleDiaryLock(true);

        await tester.pumpWidget(
          _wrapWithApp(
            settings: settings,
            journal: journal,
            btc: btc,
            routines: routines,
            home: const MentalWellnessScreen(initialLayer: 1),
          ),
        );
        await tester.pumpAndSettle();

        await _scrollMainAndTap(
          tester,
          find.byKey(const Key('mw_l4_open_crisis_bridge_btn')),
        );
        expect(find.byType(SecurityPinGateSheet), findsNothing);
        expect(find.byKey(const Key('mw_l4_crisis_sheet')), findsOneWidget);

        // Switch to US region -> verifies 988 lifeline appears
        await _ensureVisibleAndTap(
          tester,
          find.byKey(const Key('mw_l4_region_us')),
        );
        expect(find.text('988 Suicide & Crisis Lifeline'), findsOneWidget);

        // Switch to ID region -> call 119 launches tel:119
        await _ensureVisibleAndTap(
          tester,
          find.byKey(const Key('mw_l4_region_id')),
        );
        await _ensureVisibleAndTap(
          tester,
          find.byKey(const Key('mw_l4_call_crisis_id_sehat_jiwa')),
        );
        expect(
          capturedChannelCalls.any(
            (c) =>
                c.method == 'launchExternalUri' &&
                (c.arguments as Map)['uri'] == 'tel:119',
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'Educational Library bookmarks guides, saves guided reflection to Echo, '
      'and Personal Insights saves notes + navigates to Echo TimelineScreen',
      (tester) async {
        final storage = await _initFreshStorage();
        final settings = SettingsProvider(storage);
        final journal = JournalProvider(storage);
        final btc = BreakTheCycleProvider(
          storage,
          deviceControlService: MockDeviceControlService(),
        );
        final routines = RoutineProvider(storage);

        await tester.pumpWidget(
          _wrapWithApp(
            settings: settings,
            journal: journal,
            btc: btc,
            routines: routines,
            home: const MentalWellnessScreen(initialLayer: 3),
          ),
        );
        await tester.pumpAndSettle();

        await _scrollMainAndTap(
          tester,
          find.byKey(const Key('mw_l3_open_edu_library_btn')),
        );
        expect(find.byKey(const Key('mw_l3_edu_library_sheet')), findsOneWidget);

        await _ensureVisibleAndTap(
          tester,
          find.byKey(const Key('mw_l3_bookmark_guide_stress')),
        );
        expect(btc.bookmarkedGuideIds, contains('guide_stress'));

        await _ensureVisibleAndTap(
          tester,
          find.byKey(const Key('mw_l3_guide_tile_guide_stress')),
        );
        expect(
          find.byKey(const Key('mw_l3_guide_reader_guide_stress')),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('mw_l3_guide_reflection_input')),
          'Stepped away for 10 minutes after finishing my draft.',
        );
        await _ensureVisibleAndTap(
          tester,
          find.byKey(const Key('mw_l3_guide_reflection_save_btn')),
        );
        expect(
          journal.journalEntries.any(
            (e) =>
                e.tags.contains('GuidedReflection') &&
                e.content.contains('Stepped away for 10 minutes'),
          ),
          isTrue,
        );

        // Close library sheet
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // Open Personal Insights & navigate to Echo TimelineScreen
        await _scrollMainAndTap(
          tester,
          find.byKey(const Key('mw_l3_open_insights_btn')),
        );
        expect(find.byKey(const Key('mw_l3_insights_sheet')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('mw_l3_insight_title_input')),
          'Quiet breaks reset focus',
        );
        await tester.enterText(
          find.byKey(const Key('mw_l3_insight_obs_input')),
          'Short walks beat switching tabs endlessly.',
        );
        await _ensureVisibleAndTap(
          tester,
          find.byKey(const Key('mw_l3_insight_save_btn')),
        );
        expect(btc.personalInsights.single.title, 'Quiet breaks reset focus');

        await _ensureVisibleAndTap(
          tester,
          find.byKey(const Key('mw_l3_open_echo_timeline_btn')),
        );
        expect(find.byType(TimelineScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Healthy Living Goals & Sensitive Data Privacy Controls honor DiaryLock, '
      'perform granular deletion, and export encrypted passphrase envelope',
      (tester) async {
        final storage = await _initFreshStorage();
        final settings = SettingsProvider(storage);
        final journal = JournalProvider(storage);
        final btc = BreakTheCycleProvider(
          storage,
          deviceControlService: MockDeviceControlService(),
        );
        final routines = RoutineProvider(storage);

        await btc.addTriggerReflection(
          TriggerReflectionEntry(
            id: 'trig_widget_1',
            createdAt: DateTime(2026, 11, 19),
            emotionalState: 'Tired after work',
          ),
        );

        await tester.pumpWidget(
          _wrapWithApp(
            settings: settings,
            journal: journal,
            btc: btc,
            routines: routines,
            home: const MentalWellnessScreen(initialLayer: 3),
          ),
        );
        await tester.pumpAndSettle();

        // Toggle seeded Healthy Living goal (`HL-07`)
        await _scrollMainAndTap(
          tester,
          find.byKey(const Key('mw_hl_goal_hl_goal_outdoors')),
        );
        expect(
          btc.wellbeingGoals
              .firstWhere((g) => g.id == 'hl_goal_outdoors')
              .isActive,
          isTrue,
        );

        // Add custom Healthy Living goal
        await _scrollMainAndTap(
          tester,
          find.byKey(const Key('mw_hl_add_wellbeing_goal_btn')),
        );
        await tester.enterText(
          find.byKey(const Key('mw_hl_goal_title_input')),
          'Sip herbal tea at dusk',
        );
        await tester.tap(find.byKey(const Key('mw_hl_goal_save_btn')));
        await tester.pumpAndSettle();
        expect(
          btc.wellbeingGoals.any((g) => g.title == 'Sip herbal tea at dusk'),
          isTrue,
        );

        // Enable DiaryLock -> privacy sheet must gate behind SecurityPinGateSheet
        await settings.setSecurityPin('2468');
        await settings.toggleDiaryLock(true);
        await tester.pumpAndSettle();

        await _scrollMainAndTap(
          tester,
          find.byKey(const Key('mw_l3_open_privacy_controls_btn')),
        );
        expect(find.byType(SecurityPinGateSheet), findsOneWidget);
        Navigator.of(tester.element(find.byType(SecurityPinGateSheet))).pop();
        await tester.pumpAndSettle();

        // Unlock diary session -> open SensitiveDataPrivacySheet
        settings.unlockDiary();
        await tester.pumpAndSettle();

        await _scrollMainAndTap(
          tester,
          find.byKey(const Key('mw_l3_open_privacy_controls_btn')),
        );
        expect(find.byKey(const Key('mw_l3_privacy_sheet')), findsOneWidget);

        // Granular delete trigger reflection
        await _ensureVisibleAndTap(
          tester,
          find.byKey(const Key('mw_l3_del_trigger_trig_widget_1')),
        );
        expect(btc.triggerReflections, isEmpty);

        // Passphrase encrypted backup export
        final passInputFinder =
            find.byKey(const Key('mw_l3_encrypt_passphrase_input'));
        await tester.ensureVisible(passInputFinder);
        await tester.pumpAndSettle();
        await tester.enterText(passInputFinder, 'seren-key-2026');
        await tester.pumpAndSettle();
        await _ensureVisibleAndTap(
          tester,
          find.byKey(const Key('mw_l3_export_encrypted_btn')),
        );
        final previewWidget = tester.widget<SelectableText>(
          find.byKey(const Key('mw_l3_exported_envelope_preview')),
        );
        final previewText = previewWidget.data ?? '';
        expect(
          previewText,
          contains(MentalWellnessCryptoHelper.envelopeFormat),
        );
        expect(
          MentalWellnessCryptoHelper.decryptJsonPayload(
            encryptedEnvelopeJson: previewText,
            passphrase: 'seren-key-2026',
          ),
          isNotNull,
        );
      },
    );
  });
}
