import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/l10n/app_translations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/mental_wellness_models.dart';
import 'package:nestin/data/models/routine_item.dart';
import 'package:nestin/data/services/device_control_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/break_the_cycle_provider.dart';
import 'package:nestin/providers/journal_provider.dart';
import 'package:nestin/providers/routine_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
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

Future<void> _scrollAndTap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        finder,
        250.0,
        scrollable: scrollable.first,
      );
    }
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Level 2 Data Models & Backup Serialization', () {
    test(
      'MentalWellnessStateData roundtrips trustedContacts, messageTemplates, '
      'personalSupportPlan, and Level 2 ComfortKitItemKinds through full backup',
      () async {
        final storage = await _initFreshStorage();
        final now = DateTime(2026, 11, 19, 20, 30);

        final original = MentalWellnessStateData(
          comfortKitItems: [
            ComfortKitItem(
              id: 'kit_reading',
              kind: ComfortKitItemKind.reading,
              title: 'Quiet Harbor Story',
              subtitle: 'Seren calm reading',
              referenceId: 'reading_harbor',
              isPinned: true,
              isCustomNote: true,
              createdAt: now,
            ),
            ComfortKitItem(
              id: 'kit_memory',
              kind: ComfortKitItemKind.echoMemory,
              title: 'Rainy Walk with Friends',
              subtitle: '2026-10-12',
              referenceId: 'mem_1',
              isPinned: true,
              isCustomNote: true,
              createdAt: now,
            ),
            ComfortKitItem(
              id: 'kit_photo',
              kind: ComfortKitItemKind.comfortPhoto,
              title: 'Warm Desk Lamp',
              subtitle: '/storage/emulated/0/Pictures/lamp.jpg',
              referenceId: 'photo_warm_lamp',
              isPinned: true,
              isCustomNote: true,
              createdAt: now,
            ),
            ComfortKitItem(
              id: 'kit_bookmark',
              kind: ComfortKitItemKind.externalBookmark,
              title: 'Quiet Violin Stream',
              subtitle: 'Gentle focus link',
              referenceId: 'https://example.org/violin',
              isPinned: true,
              isCustomNote: true,
              createdAt: now,
            ),
          ],
          trustedContacts: [
            TrustedContact(
              id: 'tc_1',
              name: 'Nadia',
              relationshipLabel: 'Sister',
              phoneOrHandle: '+62 812-0000-1111',
              preferredChannel: TrustedContactChannel.whatsapp,
              note: 'Available evenings',
              isPrimary: true,
              createdAt: now,
            ),
          ],
          messageTemplates: [
            SupportMessageTemplate(
              id: 'tpl_custom_1',
              title: 'Need 5 calm minutes',
              messageBody: 'Hey, I feel overwhelmed. Could we chat briefly?',
              isCustom: true,
              createdAt: now,
            ),
          ],
          personalSupportPlan: PersonalSupportPlan(
            trustedContactIds: const ['tc_1'],
            preferredWaysToAskForHelp: 'Send short WhatsApp voice note or text',
            personalCopingStrategies: 'Box breathing + rain audio',
            helpfulResources: 'Neighborhood clinic Mon-Fri',
            postSetbackOrEmergencySteps: 'Call Nadia and step away from desk',
            updatedAt: now,
          ),
        );

        await storage.saveMentalWellnessData(original);
        final exportedJson = storage.exportFullBackupJson();
        final decodedBackup =
            jsonDecode(exportedJson) as Map<String, dynamic>;
        expect(decodedBackup['mentalWellnessData'], isA<Map<String, dynamic>>());

        final cleanStorage = await _initFreshStorage();
        final restoredOk =
            await cleanStorage.restoreFullBackupJson(exportedJson);
        expect(restoredOk, isTrue);

        final loaded = cleanStorage.loadMentalWellnessData();
        expect(loaded.comfortKitItems.length, 4);
        expect(
          loaded.comfortKitItems.map((e) => e.kind),
          equals([
            ComfortKitItemKind.reading,
            ComfortKitItemKind.echoMemory,
            ComfortKitItemKind.comfortPhoto,
            ComfortKitItemKind.externalBookmark,
          ]),
        );
        expect(loaded.comfortKitItems.last.referenceId,
            'https://example.org/violin');
        expect(loaded.trustedContacts.single.name, 'Nadia');
        expect(
          loaded.trustedContacts.single.preferredChannel,
          TrustedContactChannel.whatsapp,
        );
        expect(loaded.trustedContacts.single.isPrimary, isTrue);
        expect(loaded.messageTemplates.single.isCustom, isTrue);
        expect(loaded.messageTemplates.single.title, 'Need 5 calm minutes');
        expect(loaded.personalSupportPlan.trustedContactIds, ['tc_1']);
        expect(
          loaded.personalSupportPlan.personalCopingStrategies,
          'Box breathing + rain audio',
        );
      },
    );
  });

  group('Level 2 BreakTheCycleProvider CRUD, URI Formatting & Cross-Bird Links',
      () {
    test(
      'Provider seeds starter templates and manages Comfort Kit priority, '
      'Trusted Contacts, Templates, URIs, Voice Memos, and Roo Rituals',
      () async {
        final storage = await _initFreshStorage();
        final btc = BreakTheCycleProvider(
          storage,
          deviceControlService: MockDeviceControlService(),
        );
        final journal = JournalProvider(storage);
        final routines = RoutineProvider(storage);
        final now = DateTime(2026, 11, 19, 21, 0);

        // Default seeded starter templates
        expect(btc.messageTemplates.length, greaterThanOrEqualTo(4));
        expect(btc.messageTemplates.every((t) => !t.isCustom), isTrue);

        // Comfort Kit add + promote-to-top
        final item1 = ComfortKitItem(
          id: 'kit_first',
          kind: ComfortKitItemKind.reading,
          title: 'First pinned story',
          subtitle: 'Calm read',
          isPinned: true,
          isCustomNote: true,
          createdAt: now,
        );
        final item2 = ComfortKitItem(
          id: 'kit_second',
          kind: ComfortKitItemKind.externalBookmark,
          title: 'Second pinned link',
          subtitle: 'Sound link',
          referenceId: 'https://example.org/calm',
          isPinned: true,
          isCustomNote: true,
          createdAt: now,
        );
        await btc.addComfortKitItem(item1);
        await btc.addComfortKitItem(item2);
        expect(btc.pinnedComfortKitItems.first.id, 'kit_second');

        await btc.promoteComfortKitItemToTop('kit_first');
        expect(btc.pinnedComfortKitItems.first.id, 'kit_first');

        // Trusted Contact CRUD + composeContactUri
        final contact = TrustedContact(
          id: 'c_budi',
          name: 'Budi',
          relationshipLabel: 'Close friend',
          phoneOrHandle: '+62 811-2233-4455',
          preferredChannel: TrustedContactChannel.sms,
          createdAt: now,
        );
        await btc.saveTrustedContact(contact);
        expect(btc.trustedContacts.length, 1);

        final smsUri = btc.composeContactUri(
          contact: contact,
          messageBody: 'Having a tough evening',
        );
        expect(smsUri, startsWith('sms:+62 811-2233-4455?body='));
        expect(smsUri, contains('Having%20a%20tough%20evening'));

        final waUri = btc.composeContactUri(
          contact: contact,
          messageBody: 'Could we talk?',
          channelOverride: TrustedContactChannel.whatsapp,
        );
        expect(
          waUri,
          'https://wa.me/6281122334455?text=Could%20we%20talk%3F',
        );

        final callUri = btc.composeContactUri(
          contact: contact,
          messageBody: 'Ignored on call',
          channelOverride: TrustedContactChannel.call,
        );
        expect(callUri, 'tel:+62 811-2233-4455');

        await btc.deleteTrustedContact('c_budi');
        expect(btc.trustedContacts, isEmpty);

        // Custom template CRUD
        final customTpl = SupportMessageTemplate(
          id: 'tpl_mine',
          title: 'Short check-in',
          messageBody: 'No need to fix anything, just saying hi.',
          isCustom: true,
          createdAt: now,
        );
        await btc.saveMessageTemplate(customTpl);
        expect(btc.messageTemplates.any((t) => t.id == 'tpl_mine'), isTrue);
        await btc.deleteMessageTemplate('tpl_mine');
        expect(btc.messageTemplates.any((t) => t.id == 'tpl_mine'), isFalse);

        // Personal Support Plan
        await btc.savePersonalSupportPlan(
          PersonalSupportPlan(
            trustedContactIds: const ['c_budi'],
            preferredWaysToAskForHelp: 'Quiet text first',
            personalCopingStrategies: 'Slow breathing & warm water',
            updatedAt: now,
          ),
        );
        expect(btc.personalSupportPlan.hasContent, isTrue);

        // Voice reflection to Echo (`SU-02`)
        final voiceEntry = await btc.saveVoiceReflectionToEcho(
          journalProvider: journal,
          title: 'Evening decompression',
          transcriptOrNotes: 'Spoke through today without judging myself.',
          durationSeconds: 75,
        );
        expect(voiceEntry.isPrivate, isTrue);
        expect(voiceEntry.tags, contains('VoiceMemo'));
        expect(voiceEntry.content, contains('[🎙️ Voice Memo • 01:15]'));
        expect(
          journal.journalEntries.any((e) => e.id == voiceEntry.id),
          isTrue,
        );

        // Link Calm Ritual to Roo (`HL-03`)
        final routine = await btc.linkCalmRitualToRoo(
          routineProvider: routines,
          isMorning: false,
          title: 'Seren Gentle Wind-Down',
          description: 'No streaks, just calm steps.',
          steps: const ['Play rain audio', 'Dim light', 'Write one note'],
        );
        expect(routine.type, RoutineType.evening);
        expect(routines.routines.any((r) => r.id == routine.id), isTrue);
      },
    );
  });

  group('Level 2 Bilingual Localization Parity (EN & ID)', () {
    test('All gs_* and mw_l2_* keys exist and are non-empty in EN and ID', () {
      final en = kNestinTranslations['en'] ?? {};
      final id = kNestinTranslations['id'] ?? {};

      final level2Keys = en.keys
          .where((k) => k.startsWith('gs_') || k.startsWith('mw_l2_'))
          .toList();
      expect(level2Keys.length, greaterThanOrEqualTo(100));

      for (final key in level2Keys) {
        expect(en[key]?.trim().isNotEmpty, isTrue,
            reason: 'Empty EN value for $key');
        expect(id.containsKey(key), isTrue,
            reason: 'Missing ID translation for $key');
        expect(id[key]?.trim().isNotEmpty, isTrue,
            reason: 'Empty ID value for $key');
      }
    });
  });

  group('Level 2 MentalWellnessScreen Widget Workflows', () {
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
      'Comfort Kit adds external bookmark and promotes older pinned item to top',
      (tester) async {
        final storage = await _initFreshStorage();
        final settings = SettingsProvider(storage);
        final journal = JournalProvider(storage);
        final btc = BreakTheCycleProvider(
          storage,
          deviceControlService: MockDeviceControlService(),
        );
        final routines = RoutineProvider(storage);

        final previousFirstId = btc.pinnedComfortKitItems.first.id;

        await tester.pumpWidget(
          _wrapWithApp(
            settings: settings,
            journal: journal,
            btc: btc,
            routines: routines,
            home: const MentalWellnessScreen(),
          ),
        );
        await tester.pumpAndSettle();

        await _scrollAndTap(
          tester,
          find.byKey(const Key('mw_comfort_kit_add_item_btn')),
        );

        await tester.tap(
          find.byKey(const Key('mw_l2_kit_kind_externalBookmark')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('mw_l2_bookmark_title_input')),
          'Quiet Night Harp',
        );
        await tester.enterText(
          find.byKey(const Key('mw_l2_bookmark_url_input')),
          'https://example.org/harp',
        );
        await tester.tap(
          find.byKey(const Key('mw_l2_comfort_add_confirm_btn')),
        );
        await tester.pumpAndSettle();

        expect(btc.pinnedComfortKitItems.first.kind,
            ComfortKitItemKind.externalBookmark);
        expect(btc.pinnedComfortKitItems.first.title, 'Quiet Night Harp');

        // Previous first item moved down so pin-to-top button is visible on it
        final pinPrevFinder =
            find.byKey(Key('mw_kit_pin_top_$previousFirstId'));
        expect(pinPrevFinder, findsOneWidget);
        await _scrollAndTap(tester, pinPrevFinder);

        expect(btc.pinnedComfortKitItems.first.id, previousFirstId);
      },
    );

    testWidgets(
      'Trusted Contacts, custom template, QuickReachOutSheet (unlocked under '
      'DiaryLock), GS-06 modal, and Support Plan DiaryLock privacy gate',
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
            home: const MentalWellnessScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Add Trusted Contact
        await _scrollAndTap(
          tester,
          find.byKey(const Key('mw_gs_add_contact_btn')),
        );
        await tester.enterText(
          find.byKey(const Key('mw_gs_contact_name_input')),
          'Sinta',
        );
        await tester.enterText(
          find.byKey(const Key('mw_gs_contact_phone_input')),
          '+6281234567890',
        );
        await tester.tap(find.byKey(const Key('mw_gs_contact_save_btn')));
        await tester.pumpAndSettle();

        expect(btc.trustedContacts.length, 1);
        final contactId = btc.trustedContacts.single.id;

        // Add custom template ("+ Write My Own Template")
        await _scrollAndTap(
          tester,
          find.byKey(const Key('mw_gs_add_template_btn')),
        );
        await tester.enterText(
          find.byKey(const Key('mw_gs_template_title_input')),
          'Quick Grounding Ping',
        );
        await tester.enterText(
          find.byKey(const Key('mw_gs_template_body_input')),
          'No rush, can we talk for two minutes tonight?',
        );
        await tester.tap(find.byKey(const Key('mw_gs_template_save_btn')));
        await tester.pumpAndSettle();

        expect(
          btc.messageTemplates.any((t) => t.title == 'Quick Grounding Ping'),
          isTrue,
        );

        // Open non-stigmatizing GS-06 guidance modal
        await _scrollAndTap(
          tester,
          find.byKey(const Key('mw_gs_prof_guidance_btn')),
        );
        expect(
          find.text(
            AppLocalizations.current.tr('gs_prof_guidance_intro'),
          ),
          findsOneWidget,
        );
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // Enable DiaryLock so private records require PIN
        await settings.setSecurityPin('2468');
        await settings.toggleDiaryLock(true);
        await tester.pumpAndSettle();
        expect(settings.isDiaryLockEnabled, isTrue);
        expect(settings.isDiaryUnlocked, isFalse);

        // QuickReachOutSheet MUST open directly even while DiaryLock is locked!
        await _scrollAndTap(
          tester,
          find.byKey(Key('mw_gs_reach_out_$contactId')),
        );
        expect(find.byType(SecurityPinGateSheet), findsNothing);
        expect(
          find.byKey(const Key('mw_gs_reach_out_message_input')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('mw_gs_send_sms_btn')), findsOneWidget);
        expect(find.byKey(const Key('mw_gs_send_wa_btn')), findsOneWidget);
        expect(find.byKey(const Key('mw_gs_call_btn')), findsOneWidget);
        expect(find.text('Quick Grounding Ping'), findsOneWidget);

        await tester.tap(find.text('Quick Grounding Ping'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('mw_gs_send_sms_btn')));
        await tester.pumpAndSettle();
        expect(
          capturedChannelCalls.any(
            (c) =>
                c.method == 'launchExternalUri' &&
                (c.arguments as Map)['uri']
                    .toString()
                    .startsWith('sms:+6281234567890?body='),
          ),
          isTrue,
        );

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // Personal Support Plan IS protected by SecurityPinGateSheet when locked
        await _scrollAndTap(
          tester,
          find.byKey(const Key('mw_gs_support_plan_btn')),
        );
        expect(find.byType(SecurityPinGateSheet), findsOneWidget);
        Navigator.of(tester.element(find.byType(SecurityPinGateSheet))).pop();
        await tester.pumpAndSettle();

        // Unlock diary session and verify Personal Support Plan opens & saves
        settings.unlockDiary();
        await tester.pumpAndSettle();

        await _scrollAndTap(
          tester,
          find.byKey(const Key('mw_gs_support_plan_btn')),
        );
        expect(find.byType(SecurityPinGateSheet), findsNothing);
        expect(find.byKey(const Key('mw_gs_plan_ways_input')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('mw_gs_plan_ways_input')),
          'Call Sinta with short note',
        );
        await tester.tap(find.byKey(const Key('mw_gs_plan_save_btn')));
        await tester.pumpAndSettle();

        expect(
          btc.personalSupportPlan.preferredWaysToAskForHelp,
          'Call Sinta with short note',
        );
      },
    );

    testWidgets(
      'Voice Reflection saves private VoiceMemo to Echo and Calm Ritual links '
      'to Roo RoutineProvider',
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
            home: const MentalWellnessScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Voice Reflection (`SU-02`) -> saves private VoiceMemo in Echo
        await _scrollAndTap(
          tester,
          find.byKey(const Key('mw_open_voice_journal_btn')),
        );
        await tester.tap(find.byKey(const Key('mw_voice_memo_toggle_btn')));
        await tester.pump(const Duration(seconds: 2));
        await tester.tap(find.byKey(const Key('mw_voice_memo_toggle_btn')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('mw_voice_memo_notes_input')),
          'Needed three deep breaths before answering emails.',
        );
        await tester.tap(find.byKey(const Key('mw_voice_memo_save_btn')));
        await tester.pumpAndSettle();

        expect(
          journal.journalEntries.any(
            (e) =>
                e.isPrivate &&
                e.tags.contains('VoiceMemo') &&
                e.content.contains('Needed three deep breaths'),
          ),
          isTrue,
        );

        // Link Seren Calm Ritual to Roo (`HL-03`)
        final initialRoutinesCount = routines.routines.length;
        await _scrollAndTap(
          tester,
          find.byKey(const Key('mw_add_seren_routine_to_roo_btn')),
        );
        expect(routines.routines.length, initialRoutinesCount + 1);
      },
    );
  });
}
