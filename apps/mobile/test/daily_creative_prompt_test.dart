import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/l10n/app_language.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/interactive_experience_models.dart';
import 'package:nestin/data/models/journal_entry.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/hobby_provider.dart';
import 'package:nestin/providers/interactive_experience_provider.dart';
import 'package:nestin/providers/journal_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/ui/screens/explore/daily_creative_prompt_section.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DailyCreativePromptCatalog', () {
    test('covers all 4 creative mediums and selects deterministically per day',
        () {
      expect(DailyCreativePromptCatalog.prompts.length, 12);
      for (final m in CreativePromptMedium.values) {
        expect(DailyCreativePromptCatalog.promptsForMedium(m).length, 3);
      }

      final dayA = DailyCreativePromptCatalog.promptForDay(
        DateTime(2026, 11, 21),
      );
      final dayARepeat = DailyCreativePromptCatalog.promptForDay(
        DateTime(2026, 11, 21),
      );
      final dayB = DailyCreativePromptCatalog.promptForDay(
        DateTime(2026, 11, 22),
      );
      expect(dayA.id, dayARepeat.id);
      expect(dayA.id, isNot(dayB.id));

      final cycled = DailyCreativePromptCatalog.nextPrompt(dayA.id);
      expect(cycled.id, isNot(dayA.id));
    });
  });

  group('InteractiveExperienceProvider Daily Creative Prompt Handoffs', () {
    test('logs creative prompt directly as Pippin HobbyPracticeSession and Echo JournalEntry',
        () async {
      final storage = await StorageService.init();
      final expProvider = InteractiveExperienceProvider(storage);
      final hobbyProvider = HobbyProvider(storage);
      final journalProvider = JournalProvider(storage);

      final prompt = DailyCreativePromptCatalog.findById('dcp_poetry_1')!;

      // 1. Log to Pippin HobbyPracticeSession (auto-creates Writing creative hobby)
      final initialSessions = hobbyProvider.sessions.length;
      final logged = await expProvider.logCreativePromptToPippinHobby(
        prompt: prompt,
        localizedPromptTitle: 'Three-Line Weather Haiku',
        localizedPromptText: 'Write three short lines.',
        localizedDefaultHobbyName: 'Micro-Poetry Notebook',
        hobbyProvider: hobbyProvider,
        durationMinutes: 10,
        userNotes: 'Grey clouds drift slow\nKettle hums on wooden counter\nRain taps the glass',
      );

      expect(hobbyProvider.sessions.length, initialSessions + 1);
      expect(logged.session.durationMinutes, 10);
      expect(logged.session.focusTag, 'Creative Play');
      expect(logged.session.notes, contains('Grey clouds drift slow'));
      expect(logged.hobby.name, 'Micro-Poetry Notebook');

      // 2. Log to Echo JournalEntry tagged #CreativePrompt + #MicroPoetry
      final initialJournalCount = journalProvider.journalEntries.length;
      final entry = await expProvider.logCreativePromptToEchoJournal(
        prompt: prompt,
        localizedPromptTitle: 'Three-Line Weather Haiku',
        localizedPromptText: 'Write three short lines.',
        journalProvider: journalProvider,
        userNotes: 'Rain taps the glass',
        mood: JournalMood.great,
      );

      expect(journalProvider.journalEntries.length, initialJournalCount + 1);
      expect(entry.tags, containsAll(['CreativePrompt', 'MicroPoetry']));
      expect(entry.mood, JournalMood.great);
      expect(entry.content, contains('Rain taps the glass'));

      // Reload from storage and verify result persisted
      final reloaded = InteractiveExperienceProvider(storage);
      final latest = reloaded.latestResultFor(
        ExperienceCatalog.dailyCreativePromptId,
      );
      expect(latest, isNotNull);
      expect(latest!.answersSnapshot['loggedAs'], 'journal_entry');
    });
  });

  group('DailyCreativePrompt UI & Bilingual Flow', () {
    testWidgets(
        'opens studio sheet, filters medium, shuffles, logs HobbyPracticeSession & Echo JournalEntry',
        (tester) async {
      final storage = await StorageService.init();
      final settings = SettingsProvider(storage);
      await settings.setLanguage(AppLanguage.en);
      final expProvider = InteractiveExperienceProvider(storage);
      final hobbyProvider = HobbyProvider(storage);
      final journalProvider = JournalProvider(storage);

      Widget wrap() {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: expProvider),
            ChangeNotifierProvider.value(value: hobbyProvider),
            ChangeNotifierProvider.value(value: journalProvider),
          ],
          child: Consumer<SettingsProvider>(
            builder: (context, s, _) => MaterialApp(
              locale: s.language.locale,
              theme: AppTheme.lightTheme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Consumer<InteractiveExperienceProvider>(
                  builder: (context, exp, _) => ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      DailyCreativePromptHeroCard(
                        expProvider: exp,
                        latestResult: exp.latestResultFor(
                          ExperienceCatalog.dailyCreativePromptId,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('exp_daily_creative_prompt_card')),
        findsOneWidget,
      );
      expect(find.text("Pippin's Daily Creative Prompt"), findsOneWidget);

      // Launch studio sheet
      await tester.tap(find.byKey(const Key('exp_dcp_launch_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exp_dcp_sheet')), findsOneWidget);

      // Filter to Shadow Photography
      final shadowFilter = find.byKey(const Key('exp_dcp_filter_shadow_photography'));
      await tester.ensureVisible(shadowFilter);
      await tester.tap(shadowFilter);
      await tester.pumpAndSettle();
      expect(find.text('Window Blind Geometry'), findsOneWidget);

      // Shuffle prompt within Shadow Photography
      await tester.tap(find.byKey(const Key('exp_dcp_sheet_shuffle_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Cup or Plant Silhouette'), findsOneWidget);

      // Enter creative notes and log as Pippin HobbyPracticeSession
      await tester.enterText(
        find.byKey(const Key('exp_dcp_notes_field')),
        'Morning fern shadow stretched across desk.',
      );
      await tester.pumpAndSettle();

      final logHobbyBtn = find.byKey(const Key('exp_dcp_log_hobby_btn'));
      await tester.ensureVisible(logHobbyBtn);
      await tester.tap(logHobbyBtn);
      await tester.pumpAndSettle();

      expect(
        hobbyProvider.sessions.any(
          (s) =>
              s.durationMinutes == 10 &&
              (s.notes?.contains('Morning fern shadow') ?? false),
        ),
        isTrue,
      );

      // Re-open sheet, switch to Indonesian, and save to Echo Journal
      await settings.setLanguage(AppLanguage.id);
      await tester.pumpAndSettle();
      expect(find.text('Tantangan Kreatif Harian Pippin'), findsOneWidget);

      await tester.tap(find.byKey(const Key('exp_dcp_launch_btn')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('exp_dcp_notes_field')),
        'Garis cangkir hangat pagi ini.',
      );
      await tester.pumpAndSettle();

      final logJournalBtn = find.byKey(const Key('exp_dcp_log_journal_btn'));
      await tester.ensureVisible(logJournalBtn);
      await tester.tap(logJournalBtn);
      await tester.pumpAndSettle();

      expect(
        journalProvider.journalEntries.any(
          (e) =>
              e.tags.contains('CreativePrompt') &&
              e.content.contains('Garis cangkir hangat pagi ini.'),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
