import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/data/models/entity_link.dart';
import 'package:nestin/data/models/interactive_experience_models.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/collection_provider.dart';
import 'package:nestin/providers/cross_module_link_provider.dart';
import 'package:nestin/providers/hobby_provider.dart';
import 'package:nestin/providers/interactive_experience_provider.dart';
import 'package:nestin/providers/seren_relaxation_provider.dart';
import 'package:nestin/providers/task_provider.dart';
import 'package:nestin/ui/screens/explore/nestin_discover_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Shared Interactive Experience Engine & Pippin Hobby Finder', () {
    late StorageService storage;
    late InteractiveExperienceProvider expProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = StorageService(prefs);
      expProvider = InteractiveExperienceProvider(storage);
    });

    test(
        'Conditional branching reveals q_living_water_branch only when opt_flow_nature is chosen',
        () async {
      const def = ExperienceCatalog.hobbyFinderV1;
      await expProvider.startFreshSession(def);

      // Initially, conditional question q_living_water_branch is hidden (7 visible out of 8 total)
      final initialVisible = expProvider.visibleQuestionsFor(def);
      expect(
        initialVisible.any((q) => q.id == 'q_living_water_branch'),
        isFalse,
      );
      expect(initialVisible.length, 7);

      // Select opt_flow_nature on q_flow_state
      final flowQuestion =
          def.questions.firstWhere((q) => q.id == 'q_flow_state');
      await expProvider.selectOption(
        definition: def,
        question: flowQuestion,
        optionId: 'opt_flow_nature',
      );

      final branchedVisible = expProvider.visibleQuestionsFor(def);
      expect(
        branchedVisible.any((q) => q.id == 'q_living_water_branch'),
        isTrue,
      );
      expect(branchedVisible.length, 8);
    });

    test(
        'Deterministic scoring matches Aquascaping #1 for aquatic ecosystem + zen water + high budget',
        () async {
      const def = ExperienceCatalog.hobbyFinderV1;
      await expProvider.startFreshSession(def);

      Future<void> answerChoice(String qId, String optId) async {
        final q = def.questions.firstWhere((item) => item.id == qId);
        await expProvider.selectOption(
          definition: def,
          question: q,
          optionId: optId,
        );
      }

      await answerChoice('q_flow_state', 'opt_flow_nature');
      await answerChoice('q_living_water_branch', 'opt_living_aquatic');
      await answerChoice('q_environment', 'opt_env_cozy_desk');
      await expProvider.setNumericValue(
        definition: def,
        question: def.questions.firstWhere((q) => q.id == 'q_weekly_hours'),
        value: 4.0,
      );
      await answerChoice('q_budget_tier', 'opt_budget_high');
      await answerChoice('q_visual_vibe', 'opt_vibe_zen_water');
      await expProvider.skipOptionalQuestion(
        definition: def,
        question: def.questions.firstWhere((q) => q.id == 'q_learning_style'),
      );
      await answerChoice('q_patience_horizon', 'opt_patience_evolving');

      final record = await expProvider.completeSession(def);
      expect(record.topMatches, isNotEmpty);
      expect(record.topMatches.first.profileId, 'aquascaping');
      expect(record.topMatches.first.matchPercentage, greaterThanOrEqualTo(85));
      expect(
        record.topMatches.first.reasonKeys,
        containsAll([
          'exp_hobby_aquascaping_why',
          'exp_reason_time_fit',
          'exp_reason_budget_fit',
          'exp_reason_env_fit',
        ]),
      );
      // Unfinished draft is cleared upon completion
      expect(expProvider.draftFor(def.id), isNull);
      expect(expProvider.latestResultFor(def.id)?.id, record.id);
    });

    test(
        'Draft persistence & full JSON backup round-trip preserve unfinished sessions and version-pinned results',
        () async {
      const def = ExperienceCatalog.hobbyFinderV1;
      await expProvider.startFreshSession(def);
      final qFlow = def.questions.firstWhere((q) => q.id == 'q_flow_state');
      await expProvider.selectOption(
        definition: def,
        question: qFlow,
        optionId: 'opt_flow_expressive',
      );
      await expProvider.goToQuestionIndex(definition: def, index: 2);

      // Re-instantiate provider from same storage to verify draft persistence
      final reloadedProvider = InteractiveExperienceProvider(storage);
      final resumedDraft = reloadedProvider.draftFor(def.id);
      expect(resumedDraft, isNotNull);
      expect(resumedDraft!.currentQuestionIndex, 2);
      expect(
        resumedDraft.selectedOptionIdsByQuestion['q_flow_state'],
        contains('opt_flow_expressive'),
      );

      // Complete and export backup JSON
      await reloadedProvider.completeSession(def);
      await reloadedProvider.setExperienceEnabled('brain_playground', false);
      final backupJson = storage.exportFullBackupJson();

      SharedPreferences.setMockInitialValues({});
      final cleanPrefs = await SharedPreferences.getInstance();
      final restoredStorage = StorageService(cleanPrefs);
      final ok = await restoredStorage.restoreFullBackupJson(backupJson);
      expect(ok, isTrue);

      final restoredProvider = InteractiveExperienceProvider(restoredStorage);
      expect(restoredProvider.results.length, 1);
      expect(restoredProvider.results.first.definitionVersion, 1);
      expect(
        restoredProvider.isExperienceEnabled('brain_playground'),
        isFalse,
      );
    });

    test(
        'Connected Multi-Bird Journey creates linked Hobby (Pippin), Checklist & Wishlist (Twill), Task (Roo), and Soundscape (Seren)',
        () async {
      const def = ExperienceCatalog.hobbyFinderV1;
      await expProvider.startFreshSession(def);
      final record = await expProvider.completeSession(def);
      final profile = ExperienceCatalog.findHobbyProfileById('aquascaping')!;

      final hobbyProvider = HobbyProvider(storage);
      final collectionProvider = CollectionProvider(storage);
      final taskProvider = TaskProvider(storage);
      final linkProvider = CrossModuleLinkProvider(storage);
      final serenProvider = SerenRelaxationProvider(storage);

      // 1. Pippin: Add Hobby
      final createdHobby = await expProvider.launchHobbyInPippin(
        resultId: record.id,
        profile: profile,
        localizedTitle: 'Planted Tank Aquascaping',
        localizedCategory: 'Nature & Living Ecosystems',
        localizedDescription: 'Miniature underwater landscapes',
        hobbyProvider: hobbyProvider,
      );
      expect(
        hobbyProvider.hobbies.any((h) => h.id == createdHobby.id),
        isTrue,
      );

      // 2. Twill: Starter Checklist
      final createdChecklist = await expProvider.createStarterChecklistInTwill(
        resultId: record.id,
        profile: profile,
        localizedHobbyTitle: 'Planted Tank Aquascaping',
        collectionProvider: collectionProvider,
      );
      expect(createdChecklist.entries.length, 5);
      expect(
        collectionProvider.collections.any((c) => c.id == createdChecklist.id),
        isTrue,
      );

      // 3. Twill: Starter Kit Budget Estimate in Wishlist
      final createdWishlist =
          await expProvider.createBudgetEstimateInTwillWishlist(
        resultId: record.id,
        profile: profile,
        localizedHobbyTitle: 'Planted Tank Aquascaping',
        collectionProvider: collectionProvider,
      );
      expect(createdWishlist.targetPrice, 115.0);
      expect(
        collectionProvider.wishlist.any((w) => w.id == createdWishlist.id),
        isTrue,
      );

      // 4. Roo: First 30-Min Starter Session Task + CrossModuleLink
      final createdTask = await expProvider.createStarterTaskInRoo(
        resultId: record.id,
        profile: profile,
        localizedHobbyTitle: 'Planted Tank Aquascaping',
        taskProvider: taskProvider,
        linkProvider: linkProvider,
      );
      expect(taskProvider.tasks.any((t) => t.id == createdTask.id), isTrue);
      final links =
          linkProvider.linksFor(LinkEntityType.hobby, createdHobby.id);
      expect(links.any((ref) => ref.entityId == createdTask.id), isTrue);

      // 5. Seren: Paired Calm Soundscape
      await expProvider.startSerenPairedSoundscape(
        resultId: record.id,
        profile: profile,
        serenProvider: serenProvider,
      );
      expect(serenProvider.isSoundInMix(profile.pairedSerenSoundId), isTrue);

      final updatedRecord = expProvider.latestResultFor(def.id)!;
      expect(updatedRecord.addedToPippinHobbyId, createdHobby.id);
      expect(updatedRecord.createdTwillChecklistId, createdChecklist.id);
      expect(updatedRecord.createdTwillWishlistId, createdWishlist.id);
      expect(updatedRecord.createdRooTaskId, createdTask.id);
      expect(updatedRecord.playedSerenSoundId, profile.pairedSerenSoundId);

      serenProvider.dispose();
    });

    testWidgets(
        'NestinDiscoverScreen renders in English and Bahasa Indonesia and launches Hobby Finder flow',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: expProvider),
            ChangeNotifierProvider(create: (_) => HobbyProvider(storage)),
            ChangeNotifierProvider(create: (_) => CollectionProvider(storage)),
            ChangeNotifierProvider(create: (_) => TaskProvider(storage)),
            ChangeNotifierProvider(
                create: (_) => CrossModuleLinkProvider(storage)),
            ChangeNotifierProvider(
              create: (_) => SerenRelaxationProvider(storage),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('id'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: NestinDiscoverScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Bahasa Indonesia localization
      expect(find.text('Pencari Hobi Pippin'), findsWidgets);
      expect(find.text('Mulai Pencari Hobi'), findsOneWidget);

      // Tap Start Hobby Finder to open modal flow sheet
      await tester.tap(find.byKey(const ValueKey('btn_start_hobby_finder')));
      await tester.pumpAndSettle();

      expect(find.text('Langkah 1 dari 7'), findsOneWidget);
    });
  });
}
