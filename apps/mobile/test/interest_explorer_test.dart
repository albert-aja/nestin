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
import 'package:nestin/providers/bucket_list_provider.dart';
import 'package:nestin/providers/collection_provider.dart';
import 'package:nestin/providers/hobby_provider.dart';
import 'package:nestin/providers/interactive_experience_provider.dart';
import 'package:nestin/providers/reading_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/ui/screens/explore/interest_explorer_section.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('InterestExplorerCatalog & Deterministic Scoring Engine', () {
    const engine = InteractiveExperienceEngine();

    test(
        'deterministically surfaces Armchair Cartography for atlas, shadows, stargazing & bookshop choices',
        () {
      final matches = engine.evaluateInterestExplorer({
        'ie_rainy_afternoon': 'brew_tea_atlas',
        'ie_golden_hour': 'film_walk_shadows',
        'ie_cozy_desk': 'fountain_pen_ink',
        'ie_night_sky': 'stargazing_constellations',
        'ie_saturday_detour': 'secondhand_bookshop',
      });

      expect(matches, isNotEmpty);
      expect(matches.first.profileId, 'cartography_slow_atlas');
      expect(matches.first.matchPercentage, inInclusiveRange(60, 99));
      expect(matches.first.reasonKeys, isNotEmpty);
    });

    test(
        'deterministically surfaces Acoustic Strings & Tactile Studio Craft for fingerstyle, woodblock & workshop choices',
        () {
      final matches = engine.evaluateInterestExplorer({
        'ie_rainy_afternoon': 'fingerstyle_chords',
        'ie_golden_hour': 'botanical_pressing',
        'ie_cozy_desk': 'fountain_pen_ink',
        'ie_night_sky': 'woodblock_origami',
        'ie_saturday_detour': 'ceramic_luthiery_workshop',
      });

      expect(matches, isNotEmpty);
      expect(matches.first.profileId, 'acoustic_tactile_studio');
    });
  });

  group('InteractiveExperienceProvider Interest Explorer Persistence & Handoffs',
      () {
    test(
        'completes quiz, persists result, and executes BucketList, ReadingQueue, and Hobby+Twill Starter Kit handoffs',
        () async {
      final storage = await StorageService.init();
      final expProvider = InteractiveExperienceProvider(storage);
      final bucketProvider = BucketListProvider(storage, seedDefaults: false);
      final readingProvider = ReadingProvider(storage, seedDefaults: false);
      final hobbyProvider = HobbyProvider(storage);
      final collectionProvider = CollectionProvider(storage);

      await expProvider.selectOption(
        definition: InterestExplorerCatalog.definition,
        question: InterestExplorerCatalog.questions.first,
        optionId: 'brew_tea_atlas',
      );
      expect(
        expProvider.draftFor(ExperienceCatalog.interestExplorerId),
        isNotNull,
      );

      final record = await expProvider.completeInterestExplorer({
        'ie_rainy_afternoon': 'brew_tea_atlas',
        'ie_golden_hour': 'film_walk_shadows',
        'ie_cozy_desk': 'fountain_pen_ink',
        'ie_night_sky': 'stargazing_constellations',
        'ie_saturday_detour': 'secondhand_bookshop',
      });

      expect(record.experienceId, ExperienceCatalog.interestExplorerId);
      expect(record.topMatches.first.profileId, 'cartography_slow_atlas');
      expect(
        expProvider.draftFor(ExperienceCatalog.interestExplorerId),
        isNull,
      );

      final profile = ExperienceCatalog.findInterestSparkById(
        record.topMatches.first.profileId,
      );

      // 1. Bucket List handoff
      final bucketItem = await expProvider.addInterestSparkToBucketList(
        profile: profile,
        localizedBucketTitle: 'Explore a historic map room',
        localizedBucketNote: 'Sketch a favorite coastline.',
        bucketListProvider: bucketProvider,
      );
      expect(bucketProvider.items.any((i) => i.id == bucketItem.id), isTrue);
      expect(bucketItem.isStarred, isTrue);

      // 2. Reading Queue handoff
      final bookItem = await expProvider.addInterestSparkToReadingQueue(
        resultId: record.id,
        profile: profile,
        localizedBookTitle: 'Atlas of Remote Islands',
        localizedBookNote: 'Hand-drawn maps.',
        readingProvider: readingProvider,
      );
      expect(
        readingProvider.wantToReadItems.any((b) => b.id == bookItem.id),
        isTrue,
      );

      // 3. Hobby + Twill Starter Kit handoff
      final kit = await expProvider.createInterestHobbyAndTwillStarterKit(
        resultId: record.id,
        profile: profile,
        localizedHobbyTitle: 'Illustrated Map & Travel Sketching',
        localizedDescription: 'Tracing coastlines.',
        localizedStarterKitTitle:
            'Illustrated Map & Travel Sketching — Start Something New Kit',
        localizedChecklistItems: const [
          'Pocket dotted A5 field notebook',
          'Waterproof 0.3mm fineliner',
        ],
        hobbyProvider: hobbyProvider,
        collectionProvider: collectionProvider,
      );
      expect(hobbyProvider.hobbies.any((h) => h.id == kit.hobby.id), isTrue);
      expect(
        collectionProvider.collections.any((c) => c.id == kit.checklist.id),
        isTrue,
      );
      expect(kit.checklist.entries.length, 2);
    });
  });

  group('InterestExplorer UI Wizard & 1-Tap Handoffs Flow', () {
    testWidgets(
        'completes 5-step This or That wizard and triggers BucketList, Reading, and Hobby+Twill Kit handoffs',
        (tester) async {
      final storage = await StorageService.init();
      final settings = SettingsProvider(storage);
      await settings.setLanguage(AppLanguage.en);
      final expProvider = InteractiveExperienceProvider(storage);
      final bucketProvider = BucketListProvider(storage, seedDefaults: false);
      final readingProvider = ReadingProvider(storage, seedDefaults: false);
      final hobbyProvider = HobbyProvider(storage);
      final collectionProvider = CollectionProvider(storage);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: expProvider),
            ChangeNotifierProvider.value(value: bucketProvider),
            ChangeNotifierProvider.value(value: readingProvider),
            ChangeNotifierProvider.value(value: hobbyProvider),
            ChangeNotifierProvider.value(value: collectionProvider),
          ],
          child: Consumer<SettingsProvider>(
            builder: (context, s, _) => MaterialApp(
              locale: s.language.locale,
              theme: AppTheme.lightTheme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Consumer<InteractiveExperienceProvider>(
                  builder: (context, exp, _) {
                    final result = exp.latestResultFor(
                      ExperienceCatalog.interestExplorerId,
                    );
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        InterestExplorerHeroCard(
                          expProvider: exp,
                          draft: exp.draftFor(
                            ExperienceCatalog.interestExplorerId,
                          ),
                          latestResult: result,
                        ),
                        if (result != null) ...[
                          const SizedBox(height: 12),
                          InterestExplorerResultCard(
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
        ),
      );
      await tester.pumpAndSettle();

      // Launch wizard
      await tester.tap(find.byKey(const Key('exp_ie_launch_btn')));
      await tester.pumpAndSettle();

      // Step through all 5 This-or-That scenarios
      for (final q in InterestExplorerCatalog.questions) {
        final optKey = Key('exp_ie_opt_${q.id}_${q.options.first.id}');
        await tester.tap(find.byKey(optKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('exp_ie_next_or_finish_btn')));
        await tester.pumpAndSettle();
      }

      // Result card visible; scroll ListView down so handoff buttons are inside viewport
      expect(
        find.byKey(const Key('exp_interest_explorer_result_card')),
        findsOneWidget,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -260));
      await tester.pumpAndSettle();

      // 1-Tap Bucket List
      final bucketBtn = find.byKey(const Key('exp_ie_add_bucket_btn'));
      await tester.tap(bucketBtn);
      await tester.pumpAndSettle();
      expect(bucketProvider.items, isNotEmpty);

      // 1-Tap Reading Queue
      final readingBtn = find.byKey(const Key('exp_ie_add_reading_btn'));
      await tester.tap(readingBtn);
      await tester.pumpAndSettle();
      expect(readingProvider.wantToReadItems, isNotEmpty);

      // 1-Tap Start Something New (Hobby + Twill Kit)
      final hobbyKitBtn = find.byKey(const Key('exp_ie_start_hobby_kit_btn'));
      await tester.tap(hobbyKitBtn);
      await tester.pumpAndSettle();
      expect(
        hobbyProvider.hobbies.any(
          (h) => h.name == 'Illustrated Map & Travel Sketching',
        ),
        isTrue,
      );
      expect(
        collectionProvider.collections.any(
          (c) => c.title.contains('Start Something New Kit'),
        ),
        isTrue,
      );

      // Switch to Bahasa Indonesia and verify localized labels
      await settings.setLanguage(AppLanguage.id);
      await tester.pumpAndSettle();
      expect(find.text('Penjelajah Minat Pippin'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
