import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/data/models/entity_link.dart';
import 'package:nestin/data/models/interactive_experience_models.dart';
import 'package:nestin/data/models/reading_item.dart';
import 'package:nestin/data/services/ambient_sound_service.dart';
import 'package:nestin/data/services/audio_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/open_library_book_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/collection_provider.dart';
import 'package:nestin/providers/cross_module_link_provider.dart';
import 'package:nestin/providers/hobby_provider.dart';
import 'package:nestin/providers/interactive_experience_provider.dart';
import 'package:nestin/providers/note_provider.dart';
import 'package:nestin/providers/reading_provider.dart';
import 'package:nestin/providers/routine_provider.dart';
import 'package:nestin/providers/seren_relaxation_provider.dart';
import 'package:nestin/providers/task_provider.dart';
import 'package:nestin/providers/timer_provider.dart';
import 'package:nestin/ui/screens/explore/nestin_discover_screen.dart';

class _TestAudioService implements AudioService {
  @override
  bool get isPlaying => false;

  @override
  double get currentVolume => 0.0;

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TestNotificationService implements NotificationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TestAmbientSoundService extends AmbientSoundService {
  @override
  Future<void> play(AmbientSoundType type, {double? volume}) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

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

    test(
        'Echo Knowledge Arena filters by topic, scores deterministically, and saves Fact Card to NoteProvider + Book to ReadingProvider with CrossModuleLink',
        () async {
      final noteProvider = NoteProvider(storage);
      final readingProvider = ReadingProvider(storage, seedDefaults: false);
      final linkProvider = CrossModuleLinkProvider(storage);

      await expProvider.startFreshKnowledgeArena(
        topic: KnowledgeArenaTopic.science,
      );
      final scienceCards = expProvider.activeKnowledgeArenaCards();
      expect(scienceCards.length, 2);

      final firstCard = scienceCards.first;
      await expProvider.answerKnowledgeArenaCard(
        card: firstCard,
        optionId: 'a', // correct answer
      );

      // Save Fact Card to Echo Notes
      final savedNote = await expProvider.saveFactCardToEchoNotes(
        card: firstCard,
        localizedTopic: 'Science',
        localizedFactTitle: 'Hexagonal Ice Lattice & Winter Lake Survival',
        localizedPrompt: 'Why does liquid water expand when it freezes?',
        localizedCorrectAnswer: 'Hexagonal hydrogen-bond crystal lattice',
        localizedExplanation:
            'Water reaches maximum density at 4C and forms a hexagonal lattice.',
        localizedBookTitle: 'Water: A Natural History',
        localizedBookAuthor: 'Alice Outwater',
        noteProvider: noteProvider,
        linkProvider: linkProvider,
      );
      expect(noteProvider.notes.any((n) => n.id == savedNote.id), isTrue);
      expect(expProvider.isFactCardSavedToNotes(firstCard.id), isTrue);

      // Add Related Book to Pippin ReadingProvider
      final addedBook = await expProvider.addSuggestedBookToPippinReading(
        card: firstCard,
        localizedTopic: 'Science',
        localizedFactTitle: 'Hexagonal Ice Lattice & Winter Lake Survival',
        localizedBookTitle: 'Water: A Natural History',
        localizedBookAuthor: 'Alice Outwater',
        readingProvider: readingProvider,
        linkProvider: linkProvider,
      );
      expect(readingProvider.items.any((b) => b.id == addedBook.id), isTrue);
      expect(expProvider.isSuggestedBookAddedToReading(firstCard.id), isTrue);

      // Verify bidirectional CrossModuleLink between Echo Note and Pippin ReadingBook
      final noteLinks = linkProvider.linksFor(LinkEntityType.note, savedNote.id);
      expect(noteLinks.any((ref) => ref.entityId == addedBook.id), isTrue);

      // Answer second Science card & complete Arena
      await expProvider.answerKnowledgeArenaCard(
        card: scienceCards[1],
        optionId: 'a',
      );
      final result = await expProvider.completeKnowledgeArenaSession();
      expect(result.topMatches.first.matchPercentage, 100);
      expect(result.answersSnapshot['correctCount'], 2);
    });

    testWidgets(
        'Echo Knowledge Arena UI opens in Bahasa Indonesia, reveals explanation, and executes 1-tap Echo Note & Pippin Book handoffs',
        (tester) async {
      final noteProvider = NoteProvider(storage);
      final readingProvider = ReadingProvider(storage, seedDefaults: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: expProvider),
            ChangeNotifierProvider(create: (_) => HobbyProvider(storage)),
            ChangeNotifierProvider(create: (_) => CollectionProvider(storage)),
            ChangeNotifierProvider(create: (_) => TaskProvider(storage)),
            ChangeNotifierProvider.value(value: noteProvider),
            ChangeNotifierProvider.value(value: readingProvider),
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

      expect(find.text('Arena Pengetahuan Echo'), findsWidgets);

      final startBtn = find.byKey(const ValueKey('btn_start_knowledge_arena'));
      await tester.scrollUntilVisible(
        startBtn,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      expect(find.text('Kartu Wawasan 1 dari 10'), findsOneWidget);

      // Tap Option A to reveal explanation card
      await tester.tap(find.byKey(const ValueKey('ka_opt_a')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ka_explanation_card')), findsOneWidget);

      // Tap 1-Tap Save Fact Card to Echo Notes
      final saveNoteBtn = find.byKey(const ValueKey('btn_ka_save_fact_note'));
      await tester.ensureVisible(saveNoteBtn);
      await tester.tap(saveNoteBtn);
      await tester.pumpAndSettle();
      expect(find.text('Tersimpan di Catatan Echo'), findsOneWidget);

      // Tap 1-Tap Add Book to Pippin Reading List
      final addBookBtn = find.byKey(const ValueKey('btn_ka_add_pippin_book'));
      await tester.ensureVisible(addBookBtn);
      await tester.tap(addBookBtn);
      await tester.pumpAndSettle();
      expect(find.text('Ditambahkan ke Daftar Bacaan Pippin'), findsOneWidget);
      expect(readingProvider.items.length, 1);
    });

    test(
        'Echo Brain Playground filters by category, logs pre-focus warm-up to TimerProvider (FocusSessionLog), starts Pomodoro sprint, and saves strategy to NoteProvider',
        () async {
      final timerProvider = TimerProvider(
        storage,
        _TestNotificationService(),
        _TestAudioService(),
        _TestAmbientSoundService(),
      );
      final noteProvider = NoteProvider(storage);

      await expProvider.startFreshBrainPlayground(
        category: BrainPlaygroundCategory.sequenceLogic,
      );
      final seqPuzzles = expProvider.activeBrainPlaygroundPuzzles();
      expect(seqPuzzles.length, 2);

      final firstPuzzle = seqPuzzles.first;
      await expProvider.answerBrainPlaygroundPuzzle(
        puzzle: firstPuzzle,
        optionId: 'a',
      );

      // 1. Roo: Log 3-Min Pre-Focus Warm-Up + Start Pomodoro Sprint
      final createdLog = await expProvider.logWarmupToRooFocusHistory(
        puzzle: firstPuzzle,
        localizedPuzzleTitle: 'Fibonacci Botanical Spiral Step',
        timerProvider: timerProvider,
        durationMinutes: 3,
        startPomodoroSprint: true,
      );
      expect(
        timerProvider.focusLogs.any((l) => l.id == createdLog.id),
        isTrue,
      );
      expect(createdLog.durationMinutes, 3);
      expect(timerProvider.isPomodoroRunning, isTrue);
      expect(expProvider.isPuzzleLoggedToRooFocus(firstPuzzle.id), isTrue);

      // 2. Echo: Save Reasoning Strategy to NoteProvider
      final savedNote = await expProvider.savePuzzleInsightToEchoNotes(
        puzzle: firstPuzzle,
        localizedCategory: 'Sequence Logic',
        localizedPuzzleTitle: 'Fibonacci Botanical Spiral Step',
        localizedPrompt: '1, 1, 2, 3, 5, 8, 13, ?',
        localizedCorrectAnswer: '21 (8 + 13)',
        localizedExplanation: 'Each term sums the two preceding numbers.',
        noteProvider: noteProvider,
      );
      expect(noteProvider.notes.any((n) => n.id == savedNote.id), isTrue);
      expect(expProvider.isPuzzleSavedToEchoNotes(firstPuzzle.id), isTrue);

      // Answer second Sequence puzzle & complete session
      await expProvider.answerBrainPlaygroundPuzzle(
        puzzle: seqPuzzles[1],
        optionId: 'a',
      );
      final result = await expProvider.completeBrainPlaygroundSession();
      expect(result.topMatches.first.matchPercentage, 100);
      expect(result.answersSnapshot['correctCount'], 2);

      timerProvider.dispose();
    });

    testWidgets(
        'Echo Brain Playground UI opens in Bahasa Indonesia, reveals reasoning card, and logs FocusSessionLog to Roo',
        (tester) async {
      final timerProvider = TimerProvider(
        storage,
        _TestNotificationService(),
        _TestAudioService(),
        _TestAmbientSoundService(),
      );
      final noteProvider = NoteProvider(storage);
      final readingProvider = ReadingProvider(storage, seedDefaults: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: expProvider),
            ChangeNotifierProvider(create: (_) => HobbyProvider(storage)),
            ChangeNotifierProvider(create: (_) => CollectionProvider(storage)),
            ChangeNotifierProvider(create: (_) => TaskProvider(storage)),
            ChangeNotifierProvider.value(value: noteProvider),
            ChangeNotifierProvider.value(value: readingProvider),
            ChangeNotifierProvider.value(value: timerProvider),
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

      final startBpBtn =
          find.byKey(const ValueKey('btn_start_brain_playground'));
      await tester.scrollUntilVisible(
        startBpBtn,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(startBpBtn);
      await tester.pumpAndSettle();

      expect(find.text('Pemanasan 1 dari 6'), findsOneWidget);
      expect(find.text('Mode Tenang Tanpa Timer'), findsOneWidget);

      // Select Option A to reveal reasoning explanation card
      await tester.tap(find.byKey(const ValueKey('bp_opt_a')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('bp_explanation_card')), findsOneWidget);

      // Tap 1-Tap Log Pre-Focus Warm-Up to Roo Focus History
      final logFocusBtn =
          find.byKey(const ValueKey('btn_bp_log_focus_session'));
      await tester.ensureVisible(logFocusBtn);
      await tester.tap(logFocusBtn);
      await tester.pumpAndSettle();

      expect(find.text('Tercatat di Riwayat Fokus Roo'), findsOneWidget);
      expect(timerProvider.focusLogs.length, 1);

      timerProvider.dispose();
    });

    test(
        'Pippin Next-Book Matcher (book_matcher_v1) 3-Tier Hybrid Data Strategy + Multi-Bird Handoffs (Pippin + Seren + Roo)',
        () async {
      // Verify Tier 1 Curated Offline Catalog has 42 timeless books across 6 genres
      expect(ExperienceCatalog.curatedBooks.length, 42);
      expect(BookMatcherGenre.values.length, 6);

      // Prepare ReadingProvider with:
      // 1) A completed book ('Before the Coffee Gets Cold') -> should be excluded
      // 2) A 5-star rated Creativity/Philosophy book -> should boost Philosophy genre
      // 3) An unread 'Want to Read' book ('My Saved Cozy Novel') -> should rank in Unread Shelf mode
      final now = DateTime.now();
      final readingProvider = ReadingProvider(storage, seedDefaults: false);
      await readingProvider.addBook(
        ReadingItem(
          id: 'completed_coffee',
          title: 'Before the Coffee Gets Cold',
          author: 'Toshikazu Kawaguchi',
          category: 'Fiction',
          format: ReadingFormat.book,
          currentPage: 213,
          totalPages: 213,
          status: ReadingStatus.finished,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await readingProvider.addBook(
        ReadingItem(
          id: 'rated_seneca',
          title: 'Letters from a Stoic',
          author: 'Seneca',
          category: 'Creativity',
          format: ReadingFormat.book,
          currentPage: 254,
          totalPages: 254,
          status: ReadingStatus.finished,
          rating: 5,
          createdAt: now,
          updatedAt: now,
        ),
      );

      const savedUnreadBookId = 'unread_cozy_1';
      await readingProvider.addBook(
        ReadingItem(
          id: savedUnreadBookId,
          title: 'My Saved Cozy Novel',
          author: 'A. Reader',
          category: 'Fiction',
          format: ReadingFormat.book,
          currentPage: 0,
          totalPages: 210,
          status: ReadingStatus.wantToRead,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Start book_matcher_v1 session for Philosophy + Short Chapters + <220 pages
      await expProvider.startFreshSession(ExperienceCatalog.bookMatcherV1);
      final qMood = ExperienceCatalog.bookMatcherV1.questions[0];
      final qPacing = ExperienceCatalog.bookMatcherV1.questions[1];
      final qLength = ExperienceCatalog.bookMatcherV1.questions[2];
      final qGenres = ExperienceCatalog.bookMatcherV1.questions[3];
      final qMins = ExperienceCatalog.bookMatcherV1.questions[4];
      final qMode = ExperienceCatalog.bookMatcherV1.questions[5];

      await expProvider.selectOption(
        definition: ExperienceCatalog.bookMatcherV1,
        question: qMood,
        optionId: 'bm_opt_mood_philosophical',
      );
      await expProvider.selectOption(
        definition: ExperienceCatalog.bookMatcherV1,
        question: qPacing,
        optionId: 'bm_opt_pace_modular',
      );
      await expProvider.selectOption(
        definition: ExperienceCatalog.bookMatcherV1,
        question: qLength,
        optionId: 'bm_opt_len_short',
      );
      await expProvider.selectOption(
        definition: ExperienceCatalog.bookMatcherV1,
        question: qGenres,
        optionId: 'bm_opt_topic_philosophy',
      );
      await expProvider.setNumericValue(
        definition: ExperienceCatalog.bookMatcherV1,
        question: qMins,
        value: 25,
      );
      await expProvider.selectOption(
        definition: ExperienceCatalog.bookMatcherV1,
        question: qMode,
        optionId: 'bm_opt_mode_curated',
      );

      final result = await expProvider.completeBookMatcherSession(
        userReadingItems: readingProvider.items,
      );
      expect(result.topMatches.length, 3);
      // Completed book ('bm_cozy_coffee_cold') must not appear in matches
      expect(
        result.topMatches.any((m) => m.profileId == 'bm_cozy_coffee_cold'),
        isFalse,
      );
      // Top match should be a Philosophy book with 4-5 star taste boost reason
      final topMatch = result.topMatches.first;
      final topBook = expProvider.resolveBookProfile(
        topMatch.profileId,
        userReadingItems: readingProvider.items,
      )!;
      expect(topBook.genre, BookMatcherGenre.philosophy);
      expect(topMatch.reasonKeys.contains('bm_reason_taste_boost'), isTrue);

      // Test Tier 2 Mode B: "Pick From My Unread Shelf" mode ranks user's wantToRead book first
      await expProvider.startFreshSession(ExperienceCatalog.bookMatcherV1);
      await expProvider.selectOption(
        definition: ExperienceCatalog.bookMatcherV1,
        question: qMood,
        optionId: 'bm_opt_mood_cozy',
      );
      await expProvider.selectOption(
        definition: ExperienceCatalog.bookMatcherV1,
        question: qPacing,
        optionId: 'bm_opt_pace_unhurried',
      );
      await expProvider.selectOption(
        definition: ExperienceCatalog.bookMatcherV1,
        question: qLength,
        optionId: 'bm_opt_len_short',
      );
      await expProvider.selectOption(
        definition: ExperienceCatalog.bookMatcherV1,
        question: qGenres,
        optionId: 'bm_opt_topic_cozy_fic',
      );
      await expProvider.selectOption(
        definition: ExperienceCatalog.bookMatcherV1,
        question: qMode,
        optionId: 'bm_opt_mode_unread_shelf',
      );

      final unreadShelfResult = await expProvider.completeBookMatcherSession(
        userReadingItems: readingProvider.items,
      );
      expect(
        unreadShelfResult.topMatches.first.profileId,
        'shelf_$savedUnreadBookId',
      );
      expect(
        unreadShelfResult.topMatches.first.reasonKeys
            .contains('bm_reason_from_unread_shelf'),
        isTrue,
      );

      // Test Tier 3 Open Library API JSON parser & cache enrichment
      final fakeOpenLibraryService = OpenLibraryBookService(
        storage,
        httpFetcher: (_) async => '''
        {
          "works": [
            {
              "key": "/works/OL99999W",
              "title": "The Art of Stillness",
              "authors": [{"name": "Pico Iyer"}],
              "cover_id": 8234111
            }
          ]
        }
        ''',
      );
      final providerWithOnline = InteractiveExperienceProvider(
        storage,
        openLibraryService: fakeOpenLibraryService,
      );
      final fetchedOnline = await fakeOpenLibraryService
          .fetchAndCacheSubjectBooks(BookMatcherGenre.philosophy);
      expect(fetchedOnline.length, 1);
      expect(fetchedOnline.first.titleEn, 'The Art of Stillness');
      expect(fetchedOnline.first.author, 'Pico Iyer');
      expect(fetchedOnline.first.tierSource, 3);
      expect(
        fetchedOnline.first.coverImageUrl,
        'https://covers.openlibrary.org/b/id/8234111-M.jpg',
      );

      // Test Connected 1-Tap Multi-Bird Handoffs (Pippin + Seren + Roo)
      final serenProvider = SerenRelaxationProvider(
        storage,
        ambientSoundService: _TestAmbientSoundService(),
      );
      final routineProvider = RoutineProvider(storage);
      final taskProvider = TaskProvider(storage);
      final linkProvider = CrossModuleLinkProvider(storage);

      // 1. Pippin Handoff: Add matched book to ReadingProvider
      final addedBook = await expProvider.addMatchedBookToPippinReading(
        resultId: result.id,
        profile: topBook,
        readingProvider: readingProvider,
        status: ReadingStatus.currentlyReading,
      );
      expect(addedBook.title, topBook.localizedTitle);
      expect(addedBook.totalPages, topBook.pageCount);
      expect(addedBook.status, ReadingStatus.currentlyReading);

      // 2. Seren Handoff: Play paired soundscape (e.g. warm_piano -> gentlePiano)
      await expProvider.startBookMatcherSerenSoundscape(
        resultId: result.id,
        profile: topBook,
        serenProvider: serenProvider,
      );
      expect(serenProvider.isMixerPlaying, isTrue);
      expect(serenProvider.isSoundInMix(topBook.canonicalSerenSoundId), isTrue);

      // 3. Roo Handoff: Schedule evening reading habit block in RoutineProvider & TaskProvider + CrossModuleLinkProvider
      final scheduledTask = await expProvider.scheduleBookReadingHabitInRoo(
        resultId: result.id,
        profile: topBook,
        taskProvider: taskProvider,
        routineProvider: routineProvider,
        linkProvider: linkProvider,
      );
      expect(scheduledTask.title.contains(topBook.localizedTitle), isTrue);
      expect(
        taskProvider.tasks.any((t) => t.title.contains(topBook.localizedTitle)),
        isTrue,
      );
      expect(linkProvider.allLinks.isNotEmpty, isTrue);
      expect(providerWithOnline.cachedOpenLibraryBooks.length, 1);

      serenProvider.dispose();
    });

    testWidgets(
        'Pippin Reading Taste & Next-Book Matcher UI card renders in NestinDiscoverScreen and opens 6-step quiz',
        (tester) async {
      final readingProvider = ReadingProvider(storage, seedDefaults: false);
      final routineProvider = RoutineProvider(storage);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: expProvider),
            ChangeNotifierProvider(create: (_) => HobbyProvider(storage)),
            ChangeNotifierProvider(create: (_) => CollectionProvider(storage)),
            ChangeNotifierProvider(create: (_) => TaskProvider(storage)),
            ChangeNotifierProvider(create: (_) => NoteProvider(storage)),
            ChangeNotifierProvider.value(value: readingProvider),
            ChangeNotifierProvider.value(value: routineProvider),
            ChangeNotifierProvider(
              create: (_) => CrossModuleLinkProvider(storage),
            ),
            ChangeNotifierProvider(
              create: (_) => SerenRelaxationProvider(
                storage,
                ambientSoundService: _TestAmbientSoundService(),
              ),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: NestinDiscoverScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final startBmBtn = find.byKey(const ValueKey('btn_start_book_matcher'));
      await tester.scrollUntilVisible(
        startBmBtn,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.text("Pippin's Reading Taste & Next-Book Matcher"),
        findsWidgets,
      );
      expect(
        find.byKey(const ValueKey('btn_book_matcher_unread_shelf')),
        findsOneWidget,
      );

      await tester.tap(startBmBtn);
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 6'), findsOneWidget);
      expect(
        find.text('What reading mood are you looking for tonight?'),
        findsOneWidget,
      );
    });
  });
}
