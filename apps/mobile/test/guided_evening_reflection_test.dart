import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/l10n/app_translations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/journal_prompt.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/journal_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/ui/screens/journal/diary_entries_screen.dart';

Future<StorageService> _initFreshStorage() async {
  SharedPreferences.setMockInitialValues({});
  return StorageService.init();
}

Widget _wrapWithApp({
  required SettingsProvider settings,
  required JournalProvider journal,
  required Widget home,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ChangeNotifierProvider<JournalProvider>.value(value: journal),
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

Future<void> _ensureVisibleAndTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GuidedReflectionTemplate Unit & Localization Tests', () {
    test('Catalog exposes 4 evening templates with 3 questions each & EN/ID parity',
        () {
      expect(GuidedReflectionTemplate.eveningTemplates.length, 4);
      expect(
        GuidedReflectionTemplate.eveningTemplates.map((t) => t.id).toList(),
        equals([
          'rose_thorn_bud',
          'three_good_things',
          'anxiety_unload',
          'weekly_wins',
        ]),
      );

      final en = kNestinTranslations['en'] ?? {};
      final id = kNestinTranslations['id'] ?? {};
      final keys = en.keys.where((k) => k.startsWith('diary_tpl_')).toList();
      expect(keys.length, 23);

      for (final key in keys) {
        expect(en[key]?.trim().isNotEmpty, isTrue, reason: 'Empty EN: $key');
        expect(id[key]?.trim().isNotEmpty, isTrue, reason: 'Empty ID: $key');
      }

      for (final tpl in GuidedReflectionTemplate.eveningTemplates) {
        expect(tpl.questionKeys.length, 3);
        final formatted = tpl.formatGuidedContent(
          tr: (k) => en[k] ?? k,
          answers: const ['First answer', '', 'Third answer'],
          extraNotes: 'Sleep early tonight.',
        );
        expect(formatted, contains(en[tpl.questionKeys[0]]!));
        expect(formatted, contains('First answer'));
        expect(formatted, isNot(contains(en[tpl.questionKeys[1]]!)));
        expect(formatted, contains('Third answer'));
        expect(formatted, contains('Sleep early tonight.'));
      }
    });
  });

  group('DiaryEntriesScreen Guided Evening Reflection Widget Tests', () {
    testWidgets(
      'Editor offers all 4 selectable 3-question templates, saves structured '
      'entry with tags, and preserves text when switching back to Free Write',
      (tester) async {
        final storage = await _initFreshStorage();
        final settings = SettingsProvider(storage);
        final journal = JournalProvider(storage);

        await tester.pumpWidget(
          _wrapWithApp(
            settings: settings,
            journal: journal,
            home: const DiaryEntriesScreen(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('diary_new_entry_fab')));
        await tester.pumpAndSettle();

        // All 4 templates visible
        expect(
          find.byKey(const Key('diary_tpl_chip_rose_thorn_bud')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('diary_tpl_chip_three_good_things')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('diary_tpl_chip_anxiety_unload')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('diary_tpl_chip_weekly_wins')),
          findsOneWidget,
        );

        // Select Anxiety Unload -> type Q1 -> switch to Free Write preserves text
        await _ensureVisibleAndTap(
          tester,
          find.byKey(const Key('diary_tpl_chip_anxiety_unload')),
        );
        expect(
          find.byKey(const Key('diary_tpl_panel_anxiety_unload')),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const Key('diary_tpl_q_0')),
          'Tomorrow morning presentation',
        );
        await _ensureVisibleAndTap(
          tester,
          find.byKey(const Key('diary_tpl_chip_free')),
        );
        final contentField = tester.widget<TextField>(
          find.byKey(const Key('diary_content_input')),
        );
        expect(
          contentField.controller?.text,
          contains('Tomorrow morning presentation'),
        );
        contentField.controller?.clear();

        // Select 3 Good Things -> fill 3 questions -> save entry
        await _ensureVisibleAndTap(
          tester,
          find.byKey(const Key('diary_tpl_chip_three_good_things')),
        );
        expect(find.byKey(const Key('diary_tpl_q_0')), findsOneWidget);
        expect(find.byKey(const Key('diary_tpl_q_1')), findsOneWidget);
        expect(find.byKey(const Key('diary_tpl_q_2')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('diary_tpl_q_0')),
          'Warm coffee on the porch',
        );
        await tester.enterText(
          find.byKey(const Key('diary_tpl_q_1')),
          'Kind note from a teammate',
        );
        await tester.enterText(
          find.byKey(const Key('diary_tpl_q_2')),
          'Finished reading a chapter',
        );

        final initialCount = journal.journalEntries.length;
        await _ensureVisibleAndTap(
          tester,
          find.byKey(const Key('diary_save_entry_btn')),
        );

        expect(journal.journalEntries.length, initialCount + 1);
        final saved = journal.journalEntries.firstWhere(
          (e) => e.tags.contains('3GoodThings'),
        );
        expect(saved.title, '3 Good Things');
        expect(saved.tags, containsAll(['EveningReflection', '3GoodThings']));
        expect(saved.content, contains('Warm coffee on the porch'));
        expect(saved.content, contains('Kind note from a teammate'));
        expect(saved.content, contains('Finished reading a chapter'));
      },
    );
  });
}
