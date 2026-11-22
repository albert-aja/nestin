import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/l10n/app_language.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/interactive_experience_models.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/domain/experiences/interactive_experience_engine.dart';
import 'package:nestin/providers/interactive_experience_provider.dart';
import 'package:nestin/providers/journal_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/ui/screens/explore/strengths_lab_section.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Strengths & Quiet Life Skills Lab Engine', () {
    const engine = InteractiveExperienceEngine();

    test('deterministically surfaces Calm Anchor for boundary & calm choices',
        () {
      final matches = engine.evaluateStrengthsLab({
        'sl_boundary': 'kind_no',
        'sl_reset': 'unplugged_morning',
        'sl_prioritize': 'protect_promise',
        'sl_listening': 'hold_space',
        'sl_detour': 'breathe_reframe',
      });
      expect(matches, isNotEmpty);
      expect(matches.first.profileId, 'calm_anchor');
      expect(matches.first.matchPercentage, inInclusiveRange(60, 99));
      expect(matches.first.reasonKeys, isNotEmpty);
    });

    test('deterministically surfaces Quiet Navigator for clarity & detour choices',
        () {
      final matches = engine.evaluateStrengthsLab({
        'sl_boundary': 'scope_tradeoff',
        'sl_reset': 'walk_and_reflect',
        'sl_prioritize': 'one_anchor_task',
        'sl_listening': 'ask_gentle_question',
        'sl_detour': 'pivot_plan_b',
      });
      expect(matches, isNotEmpty);
      expect(matches.first.profileId, 'quiet_navigator');
    });
  });

  group('InteractiveExperienceProvider Strengths Lab Persistence & Echo Handoff',
      () {
    test('completes lab, persists result, and saves insight to JournalProvider',
        () async {
      final storage = await StorageService.init();
      final expProvider = InteractiveExperienceProvider(storage);
      final journalProvider = JournalProvider(storage);

      await expProvider.selectOption(
        definition: StrengthsLabCatalog.definition,
        question: StrengthsLabCatalog.questions.first,
        optionId: 'kind_no',
      );
      expect(
        expProvider.draftFor(StrengthsLabCatalog.strengthsLifeSkillsId),
        isNotNull,
      );

      final record = await expProvider.completeStrengthsLab({
        'sl_boundary': 'kind_no',
        'sl_reset': 'unplugged_morning',
        'sl_prioritize': 'protect_promise',
        'sl_listening': 'hold_space',
        'sl_detour': 'breathe_reframe',
      });

      expect(record.experienceId, StrengthsLabCatalog.strengthsLifeSkillsId);
      expect(record.topMatches.first.profileId, 'calm_anchor');
      expect(
        expProvider.draftFor(StrengthsLabCatalog.strengthsLifeSkillsId),
        isNull,
      );

      // Reload from storage and confirm persistence
      final reloaded = InteractiveExperienceProvider(storage);
      expect(
        reloaded
            .latestResultFor(StrengthsLabCatalog.strengthsLifeSkillsId)
            ?.topMatches
            .first
            .profileId,
        'calm_anchor',
      );

      // Echo Journal handoff
      final entry = await expProvider.saveStrengthInsightToJournal(
        journalProvider: journalProvider,
        strengthTitle: 'Calm Anchor',
        strengthDescription: 'Steady boundaries.',
        quietPractice: 'Pause for one breath.',
      );
      expect(entry.tags, containsAll(['Strength', 'SelfDiscovery']));
      expect(journalProvider.journalEntries.any((e) => e.id == entry.id), isTrue);
    });
  });

  group('StrengthsLab UI & Wizard Flow', () {
    testWidgets('completes 5-scenario wizard and saves Echo Journal handoff',
        (tester) async {
      final storage = await StorageService.init();
      final settings = SettingsProvider(storage);
      await settings.setLanguage(AppLanguage.en);
      final expProvider = InteractiveExperienceProvider(storage);
      final journalProvider = JournalProvider(storage);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: expProvider),
            ChangeNotifierProvider.value(value: journalProvider),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer<InteractiveExperienceProvider>(
                builder: (context, exp, _) {
                  final result = exp.latestResultFor(
                    StrengthsLabCatalog.strengthsLifeSkillsId,
                  );
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      StrengthsLabHeroCard(
                        expProvider: exp,
                        draft: exp.draftFor(
                          StrengthsLabCatalog.strengthsLifeSkillsId,
                        ),
                        latestResult: result,
                      ),
                      if (result != null) ...[
                        const SizedBox(height: 12),
                        StrengthsLabResultCard(
                          expProvider: exp,
                          result: result,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Launch wizard
      await tester.tap(find.byKey(const Key('exp_sl_launch_btn')));
      await tester.pumpAndSettle();

      // Step through all 5 scenarios
      for (final q in StrengthsLabCatalog.questions) {
        final optKey = Key('exp_sl_opt_${q.id}_${q.options.first.id}');
        await tester.tap(find.byKey(optKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('exp_sl_next_or_finish_btn')));
        await tester.pumpAndSettle();
      }

      // Result card should now be visible
      expect(
        find.byKey(const Key('exp_strengths_lab_result_card')),
        findsOneWidget,
      );

      // Tap Echo: Save Insight to Journal
      await tester.tap(find.byKey(const Key('exp_sl_save_journal_btn')));
      await tester.pumpAndSettle();

      expect(
        journalProvider.journalEntries.any(
          (e) =>
              e.tags.contains('Strength') && e.tags.contains('SelfDiscovery'),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
