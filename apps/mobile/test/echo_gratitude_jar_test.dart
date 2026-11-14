import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nestin/core/l10n/app_language.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/gratitude_pebble.dart';
import 'package:nestin/data/models/journal_entry.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/journal_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/ui/screens/journal/diary_entries_screen.dart';
import 'package:nestin/ui/widgets/gratitude_jar_sheet.dart';

Future<({StorageService storage, SettingsProvider settings, JournalProvider journal})>
    _initEnv({AppLanguage language = AppLanguage.en}) async {
  SharedPreferences.setMockInitialValues({});
  await AppLocalizations.ensureDateFormatting();
  final storage = await StorageService.init();
  final settings = SettingsProvider(storage);
  await settings.setLanguage(language);
  final journal = JournalProvider(storage);
  return (storage: storage, settings: settings, journal: journal);
}

Widget _wrap({
  required SettingsProvider settings,
  required JournalProvider journal,
  required Widget child,
  ThemeMode themeMode = ThemeMode.dark,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ChangeNotifierProvider<JournalProvider>.value(value: journal),
    ],
    child: MaterialApp(
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: child,
    ),
  );
}

JournalEntry _makeEntry({
  required String id,
  required DateTime date,
  String? gratitudeNote,
  JournalMood mood = JournalMood.good,
  bool isPrivate = false,
  String? customLockHash,
}) {
  return JournalEntry(
    id: id,
    title: 'Reflection $id',
    content: 'Body content for $id',
    gratitudeNote: gratitudeNote,
    date: date,
    mood: mood,
    isPrivate: isPrivate,
    customLockHash: customLockHash,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Echo Gratitude Jar — Model & JournalProvider', () {
    test('extracts non-empty gratitude notes newest-first and hides private locks',
        () async {
      final env = await _initEnv();
      final seedId = env.journal.journalEntries.first.id;
      await env.journal.deleteJournalEntry(seedId);

      await env.journal.addJournalEntry(
        _makeEntry(
          id: 'old-note',
          date: DateTime(2026, 1, 5),
          gratitudeNote: '  Warm tea on a rainy morning.  ',
        ),
      );
      await env.journal.addJournalEntry(
        _makeEntry(
          id: 'blank-note',
          date: DateTime(2026, 1, 8),
          gratitudeNote: '   ',
        ),
      );
      await env.journal.addJournalEntry(
        _makeEntry(
          id: 'private-note',
          date: DateTime(2026, 1, 10),
          gratitudeNote: 'Private locked reflection gratitude',
          isPrivate: true,
        ),
      );
      await env.journal.addJournalEntry(
        _makeEntry(
          id: 'new-note',
          date: DateTime(2026, 1, 12),
          gratitudeNote: 'Kind text from an old friend.',
        ),
      );

      final publicPebbles = env.journal.getGratitudePebbles();
      expect(publicPebbles.length, 2);
      expect(publicPebbles.first.entryId, 'new-note');
      expect(publicPebbles.last.entryId, 'old-note');
      expect(publicPebbles.last.note, 'Warm tea on a rainy morning.');

      final allPebbles = env.journal.getGratitudePebbles(includePrivate: true);
      expect(allPebbles.length, 3);
      expect(allPebbles.any((p) => p.entryId == 'private-note'), isTrue);
    });

    test('pickRandomGratitudePebble avoids immediate repeat when 2+ pebbles exist',
        () async {
      final env = await _initEnv();
      final seedId = env.journal.journalEntries.first.id;
      await env.journal.deleteJournalEntry(seedId);

      expect(env.journal.pickRandomGratitudePebble(), isNull);

      await env.journal.addJournalEntry(
        _makeEntry(
          id: 'p1',
          date: DateTime(2026, 2, 1),
          gratitudeNote: 'Sunny walk outside.',
        ),
      );
      final singlePick = env.journal.pickRandomGratitudePebble(
        excludeEntryId: 'p1',
        random: Random(0),
      );
      expect(singlePick?.entryId, 'p1');

      await env.journal.addJournalEntry(
        _makeEntry(
          id: 'p2',
          date: DateTime(2026, 2, 2),
          gratitudeNote: 'Quiet evening music.',
        ),
      );

      final distinctPick = env.journal.pickRandomGratitudePebble(
        excludeEntryId: 'p2',
        random: Random(0),
      );
      expect(distinctPick?.entryId, 'p1');
    });

    test('isLowOrToughMood identifies low and tough moods strictly', () {
      expect(JournalProvider.isLowOrToughMood(JournalMood.low), isTrue);
      expect(JournalProvider.isLowOrToughMood(JournalMood.tough), isTrue);
      expect(JournalProvider.isLowOrToughMood(JournalMood.neutral), isFalse);
      expect(JournalProvider.isLowOrToughMood(JournalMood.good), isFalse);
      expect(JournalProvider.isLowOrToughMood(JournalMood.great), isFalse);
    });

    test('deterministicColorIndex maps entry IDs cleanly within palette bounds',
        () {
      final idx = GratitudePebble.deterministicColorIndex('entry-42');
      expect(idx, inInclusiveRange(0, GratitudePebble.palette.length - 1));
      expect(
        GratitudePebble.deterministicColorIndex('entry-42'),
        idx,
      );
    });
  });

  group('Echo Gratitude Jar — Card & Sheet Widgets', () {
    testWidgets(
        'GratitudeJarCard opens GratitudeJarSheet; tapping jar pulls pebble & cycles without repeat',
        (tester) async {
      final env = await _initEnv();
      await env.journal.addJournalEntry(
        _makeEntry(
          id: 'morning-sun',
          date: DateTime(2026, 3, 14),
          gratitudeNote: 'Golden sunlight on the kitchen table.',
        ),
      );

      await tester.pumpWidget(
        _wrap(
          settings: env.settings,
          journal: env.journal,
          child: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: GratitudeJarCard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ECHO GRATITUDE JAR'), findsOneWidget);
      expect(find.text('2 pebbles'), findsOneWidget);

      await tester.tap(find.byType(GratitudeJarCard));
      await tester.pumpAndSettle();

      expect(find.text('Echo’s Gratitude Jar'), findsOneWidget);
      expect(find.text('Shake & Pull a Pebble'), findsOneWidget);

      await tester.tap(find.byKey(const Key('echo_gratitude_jar_tap_target')));
      await tester.pumpAndSettle();

      expect(find.text('Pick Another Pebble'), findsOneWidget);
      final firstVisibleFreshAir =
          find.textContaining('Grateful for crisp fresh air').evaluate().isNotEmpty;
      final firstVisibleSunlight =
          find.textContaining('Golden sunlight').evaluate().isNotEmpty;
      expect(firstVisibleFreshAir || firstVisibleSunlight, isTrue);

      await tester.tap(find.text('Pick Another Pebble'));
      await tester.pumpAndSettle();

      if (firstVisibleFreshAir) {
        expect(find.textContaining('Golden sunlight'), findsOneWidget);
      } else {
        expect(find.textContaining('Grateful for crisp fresh air'), findsOneWidget);
      }
    });

    testWidgets(
        'autoShake on Tough mood shows comforting banner & supports Light Mode + Indonesian localization',
        (tester) async {
      final env = await _initEnv(language: AppLanguage.id);

      await tester.pumpWidget(
        _wrap(
          settings: env.settings,
          journal: env.journal,
          themeMode: ThemeMode.light,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  GratitudeJarSheet.show(
                    context,
                    triggeredByMood: JournalMood.tough,
                    autoShake: true,
                    random: Random(1),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Toples Syukur Echo'), findsOneWidget);
      expect(find.text('Pemilih Kerikil Syukur Echo'), findsOneWidget);
      expect(find.textContaining('Grateful for crisp fresh air'), findsOneWidget);
      expect(find.text('Ambil Kerikil Lain'), findsOneWidget);
    });

    testWidgets('renders cozy empty state when no unlocked pebbles exist',
        (tester) async {
      final env = await _initEnv();
      final seedId = env.journal.journalEntries.first.id;
      await env.journal.deleteJournalEntry(seedId);

      bool createCalled = false;

      await tester.pumpWidget(
        _wrap(
          settings: env.settings,
          journal: env.journal,
          child: Scaffold(
            body: GratitudeJarSheet(
              triggeredByMood: JournalMood.low,
              autoShake: true,
              onCreateReflection: () => createCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 pebbles collected yet'), findsOneWidget);
      expect(find.text('Your jar is waiting for its first pebble'), findsOneWidget);
      await tester.tap(find.text('Add Gratitude Note'));
      await tester.pumpAndSettle();
      expect(createCalled, isTrue);
    });

    testWidgets(
        'DiaryEntriesScreen opens GratitudeJarSheet automatically when saving a Tough mood reflection',
        (tester) async {
      final env = await _initEnv();

      await tester.pumpWidget(
        _wrap(
          settings: env.settings,
          journal: env.journal,
          child: const DiaryEntriesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GratitudeJarCard), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'Exhausted after work',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'Need some calm tonight.',
      );

      final toughMoodFinder = find.text('Tough Day');
      await tester.ensureVisible(toughMoodFinder);
      await tester.tap(toughMoodFinder);
      await tester.pumpAndSettle();

      final saveBtn = find.text('Save Entry');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Echo Tough-Day Pebble Picker'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GratitudeJarSheet),
          matching: find.textContaining('Grateful for crisp fresh air'),
        ),
        findsOneWidget,
      );
    });
  });
}
