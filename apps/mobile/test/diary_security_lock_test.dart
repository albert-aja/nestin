import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/data/models/journal_entry.dart';
import 'package:nestin/data/models/user_preferences.dart';
import 'package:nestin/data/services/oem_hardening_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/domain/security/diary_lock_helper.dart';
import 'package:nestin/providers/journal_provider.dart';
import 'package:nestin/providers/oem_hardening_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/providers/sound_provider.dart';
import 'package:nestin/providers/wearable_provider.dart';
import 'package:nestin/ui/screens/journal/diary_entries_screen.dart';
import 'package:nestin/ui/screens/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DiaryLockHelper Unit Tests', () {
    test('sha256Hex matches standard FIPS 180-4 vectors', () {
      expect(
        DiaryLockHelper.sha256Hex(''),
        equals(
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        ),
      );
      expect(
        DiaryLockHelper.sha256Hex('abc'),
        equals(
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
        ),
      );
    });

    test('Validates 4 to 8 digit PINs and flexible text passwords', () {
      expect(DiaryLockHelper.isValidPin('123'), isFalse);
      expect(DiaryLockHelper.isValidPin('1234'), isTrue);
      expect(DiaryLockHelper.isValidPin('123456'), isTrue);
      expect(DiaryLockHelper.isValidPin('12345678'), isTrue);
      expect(DiaryLockHelper.isValidPin('123456789'), isFalse);
      expect(DiaryLockHelper.isValidPin('12a4'), isFalse);

      expect(DiaryLockHelper.isValidPassword('   '), isFalse);
      expect(DiaryLockHelper.isValidPassword('abc'), isFalse);
      expect(DiaryLockHelper.isValidPassword('abcd'), isTrue);
      expect(DiaryLockHelper.isValidPassword('sunset lake 42'), isTrue);
    });

    test('createCustomLock hashes secrets with unique salts and verifies accurately',
        () {
      final pinConfig = DiaryLockHelper.createCustomLock(
        type: DiaryLockType.pin,
        secret: '246810',
        hint: '  Even digits  ',
      );
      final pinConfigOther = DiaryLockHelper.createCustomLock(
        type: DiaryLockType.pin,
        secret: '246810',
      );

      expect(pinConfig.type, equals(DiaryLockType.pin));
      expect(pinConfig.hint, equals('Even digits'));
      expect(pinConfig.salt, isNot(equals(pinConfigOther.salt)));
      expect(pinConfig.hash, isNot(equals(pinConfigOther.hash)));
      expect(
        DiaryLockHelper.verifySecret(
          attempt: '246810',
          salt: pinConfig.salt,
          expectedHash: pinConfig.hash,
        ),
        isTrue,
      );
      expect(
        DiaryLockHelper.verifySecret(
          attempt: '246811',
          salt: pinConfig.salt,
          expectedHash: pinConfig.hash,
        ),
        isFalse,
      );
    });
  });

  group('Model Serialization & Auto-Lock Timeout Tests', () {
    test('UserPreferences persists securityPinHint and diaryAutoLockDelay', () {
      final prefs = UserPreferences.defaults().copyWith(
        securityPin: '135790',
        securityPinHint: 'Odd sequence',
        diaryAutoLockDelay: DiaryAutoLockDelay.fiveMinutes,
      );

      final revived = UserPreferences.fromJson(prefs.toJson());
      expect(revived.securityPin, equals('135790'));
      expect(revived.securityPinHint, equals('Odd sequence'));
      expect(
        revived.diaryAutoLockDelay,
        equals(DiaryAutoLockDelay.fiveMinutes),
      );
    });

    test('JournalEntry persists custom PIN/password lock + clue and clears cleanly',
        () {
      final now = DateTime(2026, 11, 14, 10, 0);
      final lock = DiaryLockHelper.createCustomLock(
        type: DiaryLockType.password,
        secret: 'MySecretPhrase!',
        hint: 'First trip city',
      );

      final entry = JournalEntry(
        id: 'j_custom_1',
        title: 'Vault Thought',
        content: 'Top secret note',
        date: now,
        isPrivate: true,
        customLockType: lock.type,
        customLockHash: lock.hash,
        customLockSalt: lock.salt,
        customLockHint: lock.hint,
        createdAt: now,
        updatedAt: now,
      );

      final revived = JournalEntry.fromJson(entry.toJson());
      expect(revived.hasCustomLock, isTrue);
      expect(revived.usesCustomPassword, isTrue);
      expect(revived.usesCustomPin, isFalse);
      expect(revived.customLockHint, equals('First trip city'));
      expect(revived.verifyCustomSecret('MySecretPhrase!'), isTrue);
      expect(revived.verifyCustomSecret('wrong'), isFalse);

      final revertedToGlobal = revived.copyWith(clearCustomLock: true);
      expect(revertedToGlobal.hasCustomLock, isFalse);
      expect(revertedToGlobal.customLockHash, isNull);
      expect(revertedToGlobal.customLockHint, isNull);
    });

    test('SettingsProvider enforces immediately, 1-minute, and 5-minute auto-lock delays',
        () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      DateTime fakeNow = DateTime(2026, 11, 14, 12, 0, 0);
      final settings = SettingsProvider(storage, clock: () => fakeNow);

      await settings.setSecurityPin('112233', hint: 'Pairs');
      await settings.toggleDiaryLock(true);

      final now = fakeNow;
      final globalEntry = JournalEntry(
        id: 'e_global',
        title: 'Global Private',
        content: 'Secret',
        date: now,
        isPrivate: true,
        createdAt: now,
        updatedAt: now,
      );
      final customLock = DiaryLockHelper.createCustomLock(
        type: DiaryLockType.password,
        secret: 'AlphaBeta',
      );
      final customEntry = JournalEntry(
        id: 'e_custom',
        title: 'Custom Private',
        content: 'Vault',
        date: now,
        isPrivate: true,
        customLockType: customLock.type,
        customLockHash: customLock.hash,
        customLockSalt: customLock.salt,
        createdAt: now,
        updatedAt: now,
      );

      // Unlock Global Diary -> custom entry stays strictly locked!
      settings.unlockDiary();
      expect(settings.isEntryLocked(globalEntry), isFalse);
      expect(settings.isEntryLocked(customEntry), isTrue);

      settings.unlockEntry(customEntry.id);
      expect(settings.isEntryLocked(customEntry), isFalse);

      // 1-minute timeout: leaving & returning within 45s stays unlocked
      await settings.updateDiaryAutoLockDelay(DiaryAutoLockDelay.oneMinute);
      settings.notifyDiaryEntered(now: fakeNow);
      settings.notifyDiaryLeft(now: fakeNow);
      fakeNow = fakeNow.add(const Duration(seconds: 45));
      settings.notifyDiaryEntered(now: fakeNow);
      expect(settings.isEntryLocked(globalEntry), isFalse);
      expect(settings.isEntryLocked(customEntry), isFalse);

      // Leaving & returning after 61s locks both global and custom entries
      settings.notifyDiaryLeft(now: fakeNow);
      fakeNow = fakeNow.add(const Duration(seconds: 61));
      settings.notifyDiaryEntered(now: fakeNow);
      expect(settings.isEntryLocked(globalEntry), isTrue);
      expect(settings.isEntryLocked(customEntry), isTrue);

      // 5-minute timeout: stays unlocked at 4m, locks at 5m 1s
      await settings.updateDiaryAutoLockDelay(DiaryAutoLockDelay.fiveMinutes);
      settings.unlockDiary();
      settings.unlockEntry(customEntry.id);
      settings.notifyDiaryEntered(now: fakeNow);
      settings.notifyDiaryLeft(now: fakeNow);
      fakeNow = fakeNow.add(const Duration(minutes: 4));
      expect(settings.evaluateAutoLock(now: fakeNow), isFalse);
      expect(settings.isEntryLocked(globalEntry), isFalse);

      fakeNow = fakeNow.add(const Duration(minutes: 1, seconds: 1));
      settings.notifyDiaryEntered(now: fakeNow);
      expect(settings.isEntryLocked(globalEntry), isTrue);
      expect(settings.isEntryLocked(customEntry), isTrue);

      // Immediate timeout: locks instantaneously upon leaving
      await settings.updateDiaryAutoLockDelay(DiaryAutoLockDelay.immediately);
      settings.unlockDiary();
      settings.unlockEntry(customEntry.id);
      settings.notifyDiaryLeft(now: fakeNow);
      expect(settings.isEntryLocked(globalEntry), isTrue);
      expect(settings.isEntryLocked(customEntry), isTrue);

      settings.dispose();
    });
  });

  group('SecurityPinGateSheet & DiaryEntriesScreen Widget Tests', () {
    late StorageService storage;
    late SettingsProvider settings;
    late JournalProvider journal;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await StorageService.init();
      settings = SettingsProvider(storage);
      journal = JournalProvider(storage);
    });

    tearDown(() {
      settings.dispose();
    });

    testWidgets(
      '6-digit Global PIN unlock supports biometrics and Show Clue toggle',
      (tester) async {
        await settings.setSecurityPin('246810', hint: 'Even ladder');
        await settings.toggleDiaryLock(true);
        await settings.toggleBiometric(true);

        final now = DateTime.now();
        await journal.addJournalEntry(
          JournalEntry(
            id: 'global_6digit',
            title: 'Quiet Thought',
            content: 'Confidential journal body',
            date: now,
            isPrivate: true,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<JournalProvider>.value(value: journal),
            ],
            child: const MaterialApp(home: DiaryEntriesScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Private Reflection'), findsOneWidget);
        expect(find.textContaining('Even ladder'), findsNothing);

        await tester.tap(find.text('Private Reflection'));
        await tester.pumpAndSettle();

        // Biometric icon MUST be available for Global Lock
        expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);

        // Clue hidden behind Show Clue button
        expect(find.text('Clue: Even ladder'), findsNothing);
        await tester.tap(find.text('Show Clue'));
        await tester.pumpAndSettle();
        expect(find.text('Clue: Even ladder'), findsOneWidget);

        // Enter 6-digit PIN: 2 4 6 8 1 0 + Unlock
        for (final digit in ['2', '4', '6', '8', '1', '0']) {
          await tester.tap(find.text(digit));
          await tester.pump();
        }
        await tester.tap(find.text('Unlock'));
        await tester.pumpAndSettle();

        expect(find.text('Quiet Thought'), findsOneWidget);
        expect(find.text('Confidential journal body'), findsOneWidget);
      },
    );

    testWidgets(
      'Custom Password entry disables biometrics, rejects Global PIN, shows clue on tap, and unlocks cleanly',
      (tester) async {
        await settings.setSecurityPin('1234', hint: 'Global clue');
        await settings.toggleDiaryLock(true);
        await settings.toggleBiometric(true);
        settings.unlockDiary(); // Even when global diary is already unlocked!

        final lock = DiaryLockHelper.createCustomLock(
          type: DiaryLockType.password,
          secret: 'CedarTree99',
          hint: 'Backyard oak',
        );
        final now = DateTime.now();
        await journal.addJournalEntry(
          JournalEntry(
            id: 'custom_pw_entry',
            title: 'Private Letter',
            content: 'Deep secret note content',
            date: now,
            isPrivate: true,
            customLockType: lock.type,
            customLockHash: lock.hash,
            customLockSalt: lock.salt,
            customLockHint: lock.hint,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<JournalProvider>.value(value: journal),
            ],
            child: const MaterialApp(home: DiaryEntriesScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Custom entry remains locked even though Global Diary is unlocked, and clue is hidden!
        expect(find.text('Custom Password Lock'), findsOneWidget);
        expect(find.text('Private Letter'), findsNothing);
        expect(find.textContaining('Backyard oak'), findsNothing);

        await tester.tap(find.text('Custom Password Lock'));
        await tester.pumpAndSettle();

        // Biometrics MUST NOT appear on custom-locked entries
        expect(find.byIcon(Icons.fingerprint_rounded), findsNothing);

        // Reveal clue cleanly
        await tester.tap(find.text('Show Clue'));
        await tester.pumpAndSettle();
        expect(find.text('Clue: Backyard oak'), findsOneWidget);

        // Global PIN fallback MUST NOT unlock custom entry
        await tester.enterText(find.byType(TextField).first, '1234');
        await tester.pump();
        await tester.tap(find.text('Unlock'));
        await tester.pumpAndSettle();
        expect(find.text('Incorrect password. Try again.'), findsOneWidget);

        // Enter exact custom password -> unlocks cleanly
        await tester.enterText(find.byType(TextField).first, 'CedarTree99');
        await tester.pump();
        await tester.tap(find.text('Unlock'));
        await tester.pumpAndSettle();

        expect(find.text('Private Letter'), findsOneWidget);
        expect(find.text('Deep secret note content'), findsOneWidget);
        expect(find.text('Custom Password'), findsOneWidget);
      },
    );

    testWidgets(
      'Custom 8-digit PIN entry disables biometrics, shows PIN clue, and rejects global PIN',
      (tester) async {
        await settings.setSecurityPin('0000');
        await settings.toggleDiaryLock(true);
        await settings.toggleBiometric(true);

        final lock = DiaryLockHelper.createCustomLock(
          type: DiaryLockType.pin,
          secret: '19283746',
          hint: 'Zigzag keypad',
        );
        final now = DateTime.now();
        await journal.addJournalEntry(
          JournalEntry(
            id: 'custom_pin_entry',
            title: 'Pin Vault',
            content: '8-digit vault body',
            date: now,
            isPrivate: true,
            customLockType: lock.type,
            customLockHash: lock.hash,
            customLockSalt: lock.salt,
            customLockHint: lock.hint,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<JournalProvider>.value(value: journal),
            ],
            child: const MaterialApp(home: DiaryEntriesScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Custom PIN Lock'));
        await tester.pumpAndSettle();

        // Biometrics disabled on custom PIN entry
        expect(find.byIcon(Icons.fingerprint_rounded), findsNothing);

        // Clue works on PIN lock too
        await tester.tap(find.text('Show Clue'));
        await tester.pumpAndSettle();
        expect(find.text('Clue: Zigzag keypad'), findsOneWidget);

        // Global PIN '0000' fails
        for (final digit in ['0', '0', '0', '0']) {
          await tester.tap(find.text(digit));
          await tester.pump();
        }
        await tester.tap(find.text('Unlock'));
        await tester.pumpAndSettle();
        expect(find.text('Incorrect PIN. Try again.'), findsOneWidget);

        // Enter 8-digit custom PIN
        for (final digit in ['1', '9', '2', '8', '3', '7', '4', '6']) {
          await tester.tap(find.text(digit));
          await tester.pump();
        }
        await tester.tap(find.text('Unlock'));
        await tester.pumpAndSettle();

        expect(find.text('Pin Vault'), findsOneWidget);
        expect(find.text('8-digit vault body'), findsOneWidget);
      },
    );

    testWidgets(
      'SettingsScreen allows switching Diary Auto-Lock Timeout presets',
      (tester) async {
        final oemProvider = OemHardeningProvider(
          storage,
          MockOemHardeningService(),
        );
        final soundProvider = SoundProvider(storage);
        final wearableProvider = WearableProvider(storage);
        addTearDown(() {
          oemProvider.dispose();
          soundProvider.dispose();
          wearableProvider.dispose();
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<OemHardeningProvider>.value(
                value: oemProvider,
              ),
              ChangeNotifierProvider<SoundProvider>.value(value: soundProvider),
              ChangeNotifierProvider<WearableProvider>.value(
                value: wearableProvider,
              ),
            ],
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final immediateChip = find.text('Immediately');
        await tester.scrollUntilVisible(
          immediateChip,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(find.text('Diary Auto-Lock Timeout'), findsOneWidget);
        expect(immediateChip, findsOneWidget);
        expect(find.text('1 minute'), findsOneWidget);
        expect(find.text('5 minutes'), findsOneWidget);

        await tester.tap(immediateChip);
        await tester.pumpAndSettle();
        expect(
          settings.diaryAutoLockDelay,
          equals(DiaryAutoLockDelay.immediately),
        );

        await tester.ensureVisible(find.text('5 minutes'));
        await tester.tap(find.text('5 minutes'));
        await tester.pumpAndSettle();
        expect(
          settings.diaryAutoLockDelay,
          equals(DiaryAutoLockDelay.fiveMinutes),
        );
      },
    );

    testWidgets(
      'DiaryEntriesScreen editor creates custom password entry with clue and locks immediately on save',
      (tester) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<JournalProvider>.value(value: journal),
            ],
            child: const MaterialApp(home: DiaryEntriesScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Title / Prompt Highlight'),
          'Vault Journal',
        );
        await tester.enterText(
          find.widgetWithText(
            TextField,
            'Dear Diary... reflection, observations, memories',
          ),
          'Top secret reflection created in UI',
        );

        await tester.ensureVisible(find.byType(Switch));
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Custom PIN / Password'));
        await tester.tap(find.text('Custom PIN / Password'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Set Secret'));
        await tester.tap(find.text('Set Secret'));
        await tester.pumpAndSettle();

        // Switch lock setup sheet from PIN to Password
        await tester.tap(find.text('Password'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Entry Password'),
          'PineCone!9',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Password Clue (Optional)'),
          'Forest seed',
        );
        await tester.pump();
        await tester.ensureVisible(find.text('Continue'));
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Confirm Password'),
          'PineCone!9',
        );
        await tester.pump();
        await tester.ensureVisible(find.text('Save Lock'));
        await tester.tap(find.text('Save Lock'));
        await tester.pumpAndSettle();

        expect(find.text('Custom Password Active (No Biometrics)'), findsOneWidget);
        await tester.ensureVisible(find.text('Save Entry'));
        await tester.tap(find.text('Save Entry'));
        await tester.pumpAndSettle();

        // Entry saves locked immediately
        expect(find.text('Custom Password Lock'), findsOneWidget);
        expect(find.text('Top secret reflection created in UI'), findsNothing);
        expect(find.textContaining('Forest seed'), findsNothing);

        // Unlock with clue & custom password
        await tester.tap(find.text('Custom Password Lock'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Show Clue'));
        await tester.pumpAndSettle();
        expect(find.text('Clue: Forest seed'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextField, 'Entry Password'),
          'PineCone!9',
        );
        await tester.pump();
        await tester.tap(find.text('Unlock'));
        await tester.pumpAndSettle();

        expect(find.text('Vault Journal'), findsOneWidget);
        expect(find.text('Top secret reflection created in UI'), findsOneWidget);
      },
    );
  });
}
