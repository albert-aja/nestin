import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/models/alarm_category.dart';
import '../data/models/before_you_go.dart';
import '../data/models/calendar_event.dart';
import '../data/models/collection_item.dart';
import '../data/models/entity_link.dart';
import '../data/models/focus_session_log.dart';
import '../data/models/hobby_item.dart';
import '../data/models/interactive_experience_models.dart';
import '../data/models/location_reminder.dart';
import '../data/models/money_category.dart';
import '../data/models/note_item.dart';
import '../data/models/reading_item.dart';
import '../data/models/routine_item.dart';
import '../data/models/saved_place.dart';
import '../data/models/task_item.dart';
import '../data/models/wishlist_item.dart';
import '../data/services/open_library_book_service.dart';
import '../data/services/storage_service.dart';
import '../data/services/weather_service.dart';
import '../domain/experiences/interactive_experience_engine.dart';
import '../domain/money/money_amount.dart';
import 'before_you_go_provider.dart';
import 'calendar_provider.dart';
import 'collection_provider.dart';
import 'cross_module_link_provider.dart';
import 'geofence_provider.dart';
import 'hobby_provider.dart';
import 'money_provider.dart';
import 'note_provider.dart';
import 'reading_provider.dart';
import 'routine_provider.dart';
import 'seren_relaxation_provider.dart';
import 'task_provider.dart';
import 'timer_provider.dart';

/// Shared Interactive Experience Provider (Phase 2 & Phase 3).
///
/// Orchestrates:
/// - Session draft persistence (pause/resume unfinished interactive sessions)
/// - Deterministic scoring & explainable result generation via [InteractiveExperienceEngine]
/// - Version-pinned result history (`ExperienceResultRecord`)
/// - Connected Multi-Bird Journey handoffs (Pippin Hobby, Twill Checklist & Wishlist Budget,
///   Roo Starter Task, Seren Paired Soundscape, and CrossModuleLink bidirectional linking)
class InteractiveExperienceProvider extends ChangeNotifier {
  final StorageService _storage;
  final Uuid _uuid = const Uuid();

  Map<String, ExperienceSessionDraft> _drafts = {};
  List<ExperienceResultRecord> _results = [];
  List<String> _disabledExperienceIds = [];
  late final OpenLibraryBookService _openLibraryService;
  bool _isFetchingOpenLibrary = false;

  InteractiveExperienceProvider(
    this._storage, {
    this.engine = const InteractiveExperienceEngine(),
    OpenLibraryBookService? openLibraryService,
  }) {
    _openLibraryService = openLibraryService ?? OpenLibraryBookService(_storage);
    _drafts = _storage.loadExperienceDrafts();
    _results = _storage.loadExperienceResults();
    _disabledExperienceIds =
        List<String>.from(_storage.loadDisabledExperienceIds());
  }

  final InteractiveExperienceEngine engine;
  OpenLibraryBookService get openLibraryService => _openLibraryService;
  bool get isFetchingOpenLibrary => _isFetchingOpenLibrary;
  List<BookRecommendationProfile> get cachedOpenLibraryBooks =>
      _openLibraryService.getCachedBooks();

  Map<String, ExperienceSessionDraft> get drafts => Map.unmodifiable(_drafts);

  List<ExperienceResultRecord> get results => List.unmodifiable(_results);

  List<String> get disabledExperienceIds =>
      List.unmodifiable(_disabledExperienceIds);

  bool isExperienceEnabled(String experienceId) =>
      !_disabledExperienceIds.contains(experienceId);

  Future<void> setExperienceEnabled(String experienceId, bool enabled) async {
    if (enabled) {
      _disabledExperienceIds.remove(experienceId);
    } else if (!_disabledExperienceIds.contains(experienceId)) {
      _disabledExperienceIds.add(experienceId);
    }
    await _storage.saveDisabledExperienceIds(_disabledExperienceIds);
    notifyListeners();
  }

  ExperienceSessionDraft? draftFor(String experienceId) =>
      _drafts[experienceId];

  ExperienceResultRecord? latestResultFor(String experienceId) {
    for (final record in _results) {
      if (record.experienceId == experienceId) return record;
    }
    return null;
  }

  /// Starts a new session or returns an existing saved draft if one exists for the current version.
  Future<ExperienceSessionDraft> startOrResumeSession(
    ExperienceDefinition definition,
  ) async {
    final existing = _drafts[definition.id];
    if (existing != null && existing.definitionVersion == definition.version) {
      return existing;
    }
    return startFreshSession(definition);
  }

  /// Starts a clean draft session for [definition].
  Future<ExperienceSessionDraft> startFreshSession(
    ExperienceDefinition definition,
  ) async {
    final now = DateTime.now();
    final initialNumeric = <String, double>{};
    for (final q in definition.questions) {
      if (q.type == ExperienceQuestionType.slider ||
          q.type == ExperienceQuestionType.numericInput) {
        initialNumeric[q.id] = q.defaultValue;
      }
    }
    final draft = ExperienceSessionDraft(
      experienceId: definition.id,
      definitionVersion: definition.version,
      currentQuestionIndex: 0,
      selectedOptionIdsByQuestion: const {},
      numericValueByQuestion: initialNumeric,
      skippedQuestionIds: const [],
      startedAt: now,
      updatedAt: now,
    );
    _drafts[definition.id] = draft;
    await _storage.saveExperienceDrafts(_drafts);
    notifyListeners();
    return draft;
  }

  List<ExperienceQuestion> visibleQuestionsFor(
    ExperienceDefinition definition,
  ) {
    final draft = _drafts[definition.id];
    if (draft == null) return definition.questions;
    return engine.visibleQuestions(definition, draft);
  }

  /// Toggles or selects [optionId] for [question] in the active draft.
  Future<void> selectOption({
    required ExperienceDefinition definition,
    required ExperienceQuestion question,
    required String optionId,
  }) async {
    final draft =
        _drafts[definition.id] ?? await startFreshSession(definition);
    final nextMap = <String, List<String>>{};
    draft.selectedOptionIdsByQuestion.forEach((k, v) {
      nextMap[k] = List<String>.from(v);
    });

    final currentList = List<String>.from(nextMap[question.id] ?? const []);
    if (question.type == ExperienceQuestionType.singleChoice ||
        question.type == ExperienceQuestionType.visualSelection) {
      nextMap[question.id] = [optionId];
    } else {
      // Multiple choice or ranking
      if (currentList.contains(optionId)) {
        currentList.remove(optionId);
      } else {
        if (question.type == ExperienceQuestionType.multipleChoice &&
            currentList.length >= question.maxSelections) {
          currentList.removeAt(0);
        }
        currentList.add(optionId);
      }
      nextMap[question.id] = currentList;
    }

    final nextSkipped = List<String>.from(draft.skippedQuestionIds)
      ..remove(question.id);

    final updated = draft.copyWith(
      selectedOptionIdsByQuestion: nextMap,
      skippedQuestionIds: nextSkipped,
      updatedAt: DateTime.now(),
    );
    _drafts[definition.id] = updated;
    await _storage.saveExperienceDrafts(_drafts);
    notifyListeners();
  }

  /// Sets a slider or numeric input value for [question] in the active draft.
  Future<void> setNumericValue({
    required ExperienceDefinition definition,
    required ExperienceQuestion question,
    required double value,
  }) async {
    final draft =
        _drafts[definition.id] ?? await startFreshSession(definition);
    final nextNumeric = Map<String, double>.from(draft.numericValueByQuestion);
    nextNumeric[question.id] =
        value.clamp(question.minValue, question.maxValue);
    final nextSkipped = List<String>.from(draft.skippedQuestionIds)
      ..remove(question.id);

    final updated = draft.copyWith(
      numericValueByQuestion: nextNumeric,
      skippedQuestionIds: nextSkipped,
      updatedAt: DateTime.now(),
    );
    _drafts[definition.id] = updated;
    await _storage.saveExperienceDrafts(_drafts);
    notifyListeners();
  }

  /// Skips an optional question and advances to the next step if possible.
  Future<void> skipOptionalQuestion({
    required ExperienceDefinition definition,
    required ExperienceQuestion question,
  }) async {
    if (!question.isOptional) return;
    final draft =
        _drafts[definition.id] ?? await startFreshSession(definition);
    final nextSkipped = List<String>.from(draft.skippedQuestionIds);
    if (!nextSkipped.contains(question.id)) {
      nextSkipped.add(question.id);
    }
    final visible = engine.visibleQuestions(definition, draft);
    final nextIndex =
        (draft.currentQuestionIndex + 1).clamp(0, visible.length - 1);

    final updated = draft.copyWith(
      skippedQuestionIds: nextSkipped,
      currentQuestionIndex: nextIndex,
      updatedAt: DateTime.now(),
    );
    _drafts[definition.id] = updated;
    await _storage.saveExperienceDrafts(_drafts);
    notifyListeners();
  }

  Future<void> goToQuestionIndex({
    required ExperienceDefinition definition,
    required int index,
  }) async {
    final draft = _drafts[definition.id];
    if (draft == null) return;
    final visible = engine.visibleQuestions(definition, draft);
    final clamped = index.clamp(0, visible.length - 1);
    _drafts[definition.id] = draft.copyWith(
      currentQuestionIndex: clamped,
      updatedAt: DateTime.now(),
    );
    await _storage.saveExperienceDrafts(_drafts);
    notifyListeners();
  }

  /// Completes the active session, computes deterministic top matches, saves a
  /// version-pinned [ExperienceResultRecord], and clears the unfinished draft.
  Future<ExperienceResultRecord> completeSession(
    ExperienceDefinition definition, {
    List<ReadingItem>? userReadingItems,
    WeatherInfo? currentWeather,
  }) async {
    if (definition.id == ExperienceCatalog.bookMatcherId) {
      return completeBookMatcherSession(userReadingItems: userReadingItems);
    }
    if (definition.id == ExperienceCatalog.weekendGeneratorId) {
      return completeWeekendGeneratorSession(currentWeather: currentWeather);
    }
    final draft =
        _drafts[definition.id] ?? await startFreshSession(definition);
    final topMatches = engine.evaluateHobbyFinder(
      definition: definition,
      draft: draft,
      maxResults: 3,
    );

    final record = ExperienceResultRecord(
      experienceId: definition.id,
      definitionVersion: definition.version,
      completedAt: DateTime.now(),
      topMatches: topMatches,
      answersSnapshot: {
        'selectedOptionIdsByQuestion': draft.selectedOptionIdsByQuestion,
        'numericValueByQuestion': draft.numericValueByQuestion,
        'skippedQuestionIds': draft.skippedQuestionIds,
      },
    );

    _results = [record, ..._results];
    _drafts.remove(definition.id);
    await _storage.saveExperienceResults(_results);
    await _storage.saveExperienceDrafts(_drafts);
    notifyListeners();
    return record;
  }

  // ===========================================================================
  // Connected Multi-Bird Journey Actions (Section 5: Pippin + Twill + Roo + Seren)
  // ===========================================================================

  /// 1. Pippin Action: Adds the recommended hobby to [HobbyProvider] and links it to [resultId].
  Future<HobbyItem> launchHobbyInPippin({
    required String resultId,
    required HobbyRecommendationProfile profile,
    required String localizedTitle,
    required String localizedCategory,
    required String localizedDescription,
    required HobbyProvider hobbyProvider,
  }) async {
    final now = DateTime.now();
    final hobby = HobbyItem(
      id: _uuid.v4(),
      name: localizedTitle,
      category: localizedCategory,
      iconEmoji: profile.iconEmoji,
      colorHex: profile.colorHex,
      targetHours: profile.recommendedTargetHours,
      totalMinutesPracticed: 0,
      notes: localizedDescription,
      createdAt: now,
      updatedAt: now,
    );
    await hobbyProvider.addHobby(hobby);
    await _updateResultRecord(
      resultId,
      (r) => r.copyWith(addedToPippinHobbyId: hobby.id),
    );
    return hobby;
  }

  /// 2. Twill Action (Checklist): Creates a starter project & gear checklist in [CollectionProvider].
  Future<CollectionItem> createStarterChecklistInTwill({
    required String resultId,
    required HobbyRecommendationProfile profile,
    required String localizedHobbyTitle,
    required CollectionProvider collectionProvider,
  }) async {
    final now = DateTime.now();
    final entries = profile.starterChecklistItems
        .map(
          (itemText) => CollectionEntry(
            id: _uuid.v4(),
            text: itemText,
            category: 'Starter Kit',
          ),
        )
        .toList();

    final collection = CollectionItem(
      id: _uuid.v4(),
      title: '$localizedHobbyTitle — Starter Kit',
      description:
          'Curated starter gear & setup checklist from Pippin\'s Hobby Finder',
      iconCodePoint: Icons.checklist_rounded.codePoint,
      colorValue: 0xFF10B981,
      entries: entries,
      isReusableTemplate: false,
      createdAt: now,
    );
    await collectionProvider.addCollection(collection);
    await _updateResultRecord(
      resultId,
      (r) => r.copyWith(createdTwillChecklistId: collection.id),
    );
    return collection;
  }

  /// 3. Twill Action (Personal Budget & Wishlist Estimate): Saves the starter kit cost estimate
  /// in [CollectionProvider.wishlist] for personal budget planning (non-banking).
  Future<WishlistItem> createBudgetEstimateInTwillWishlist({
    required String resultId,
    required HobbyRecommendationProfile profile,
    required String localizedHobbyTitle,
    required CollectionProvider collectionProvider,
  }) async {
    final item = WishlistItem(
      id: _uuid.v4(),
      title: '$localizedHobbyTitle Starter Kit',
      description: profile.starterChecklistItems.take(3).join(' • '),
      targetPrice: profile.estimatedStarterCostUsd.toDouble(),
      category: AlarmCategory.fromType(AlarmCategoryType.personal),
      priority: TaskPriority.medium,
      createdAt: DateTime.now(),
    );
    await collectionProvider.addWishlistItem(item);
    await _updateResultRecord(
      resultId,
      (r) => r.copyWith(createdTwillWishlistId: item.id),
    );
    return item;
  }

  /// 4. Roo Action: Schedules the first 30-minute starter practice session in [TaskProvider]
  /// and bidirectionally links it to the created Pippin [HobbyItem] via [CrossModuleLinkProvider].
  Future<TaskItem> createStarterTaskInRoo({
    required String resultId,
    required HobbyRecommendationProfile profile,
    required String localizedHobbyTitle,
    required TaskProvider taskProvider,
    CrossModuleLinkProvider? linkProvider,
  }) async {
    final now = DateTime.now();
    final subtasks = profile.starterChecklistItems
        .take(3)
        .map(
          (step) => TaskSubItem(
            id: _uuid.v4(),
            title: step,
          ),
        )
        .toList();

    final task = TaskItem(
      id: _uuid.v4(),
      title: '$localizedHobbyTitle: ${profile.firstSessionTaskTitle}',
      notes: 'Created from Nestin Discover • Pippin\'s Hobby Finder',
      dueDate: now.add(const Duration(days: 1)),
      priority: TaskPriority.medium,
      category: AlarmCategory.fromType(AlarmCategoryType.personal),
      subtasks: subtasks,
      createdAt: now,
    );
    await taskProvider.addTask(task);

    final record = _results.where((r) => r.id == resultId).firstOrNull;
    if (linkProvider != null && record?.addedToPippinHobbyId != null) {
      await linkProvider.addLink(
        sourceType: LinkEntityType.hobby,
        sourceId: record!.addedToPippinHobbyId!,
        sourceTitle: localizedHobbyTitle,
        targetType: LinkEntityType.task,
        targetId: task.id,
        targetTitle: task.title,
        relationship: 'starter_session',
      );
    }

    await _updateResultRecord(
      resultId,
      (r) => r.copyWith(createdRooTaskId: task.id),
    );
    return task;
  }

  /// 5. Seren Action: Plays the paired calm soundscape for the discovered hobby.
  Future<void> startSerenPairedSoundscape({
    required String resultId,
    required HobbyRecommendationProfile profile,
    required SerenRelaxationProvider serenProvider,
  }) async {
    if (!serenProvider.isSoundInMix(profile.pairedSerenSoundId)) {
      await serenProvider.playSingleSound(profile.pairedSerenSoundId);
    }
    await _updateResultRecord(
      resultId,
      (r) => r.copyWith(playedSerenSoundId: profile.pairedSerenSoundId),
    );
  }

  Future<void> _updateResultRecord(
    String resultId,
    ExperienceResultRecord Function(ExperienceResultRecord current) updater,
  ) async {
    final index = _results.indexWhere((r) => r.id == resultId);
    if (index == -1) return;
    _results[index] = updater(_results[index]);
    await _storage.saveExperienceResults(_results);
    notifyListeners();
  }

  // ===========================================================================
  // ECHO'S KNOWLEDGE ARENA (knowledge_arena_v1) — Echo + Pippin Integration
  // ===========================================================================

  static const String _metaTopicKey = '_topic';
  static const String _metaSavedNotesKey = '_saved_notes';
  static const String _metaAddedBooksKey = '_added_books';

  KnowledgeArenaTopic activeKnowledgeArenaTopic() {
    final draft = _drafts[ExperienceCatalog.knowledgeArenaId];
    final raw = draft?.selectedOptionIdsByQuestion[_metaTopicKey]?.firstOrNull;
    if (raw == null) return KnowledgeArenaTopic.all;
    return KnowledgeArenaTopic.values.firstWhere(
      (t) => t.name == raw,
      orElse: () => KnowledgeArenaTopic.all,
    );
  }

  List<KnowledgeArenaCard> activeKnowledgeArenaCards() {
    return ExperienceCatalog.cardsForTopic(activeKnowledgeArenaTopic());
  }

  int knowledgeArenaAnsweredCount() {
    final draft = _drafts[ExperienceCatalog.knowledgeArenaId];
    if (draft == null) return 0;
    final cards = activeKnowledgeArenaCards();
    var count = 0;
    for (final c in cards) {
      final ans = draft.selectedOptionIdsByQuestion[c.id];
      if (ans != null && ans.isNotEmpty) count++;
    }
    return count;
  }

  Future<ExperienceSessionDraft> startOrResumeKnowledgeArena({
    KnowledgeArenaTopic topic = KnowledgeArenaTopic.all,
  }) async {
    final existing = _drafts[ExperienceCatalog.knowledgeArenaId];
    if (existing != null) {
      final existingTopic = activeKnowledgeArenaTopic();
      if (existingTopic == topic) {
        return existing;
      }
    }
    return startFreshKnowledgeArena(topic: topic);
  }

  Future<ExperienceSessionDraft> startFreshKnowledgeArena({
    KnowledgeArenaTopic topic = KnowledgeArenaTopic.all,
  }) async {
    final now = DateTime.now();
    final draft = ExperienceSessionDraft(
      experienceId: ExperienceCatalog.knowledgeArenaId,
      definitionVersion: 1,
      currentQuestionIndex: 0,
      selectedOptionIdsByQuestion: {
        _metaTopicKey: [topic.name],
      },
      numericValueByQuestion: const {},
      skippedQuestionIds: const [],
      startedAt: now,
      updatedAt: now,
    );
    _drafts[ExperienceCatalog.knowledgeArenaId] = draft;
    await _storage.saveExperienceDrafts(_drafts);
    notifyListeners();
    return draft;
  }

  String? selectedOptionForKnowledgeCard(String cardId) {
    final draft = _drafts[ExperienceCatalog.knowledgeArenaId];
    final list = draft?.selectedOptionIdsByQuestion[cardId];
    if (list != null && list.isNotEmpty) return list.first;
    final latest = latestResultFor(ExperienceCatalog.knowledgeArenaId);
    final savedAnswers =
        latest?.answersSnapshot['selectedOptionIdsByQuestion'];
    if (savedAnswers is Map) {
      final prevList = savedAnswers[cardId];
      if (prevList is List && prevList.isNotEmpty) {
        return prevList.first.toString();
      }
    }
    return null;
  }

  Future<void> answerKnowledgeArenaCard({
    required KnowledgeArenaCard card,
    required String optionId,
  }) async {
    final draft = _drafts[ExperienceCatalog.knowledgeArenaId] ??
        await startFreshKnowledgeArena();
    final nextMap = <String, List<String>>{};
    draft.selectedOptionIdsByQuestion.forEach((k, v) {
      nextMap[k] = List<String>.from(v);
    });
    nextMap[card.id] = [optionId];

    _drafts[ExperienceCatalog.knowledgeArenaId] = draft.copyWith(
      selectedOptionIdsByQuestion: nextMap,
      updatedAt: DateTime.now(),
    );
    await _storage.saveExperienceDrafts(_drafts);
    notifyListeners();
  }

  Future<void> goToKnowledgeArenaCardIndex(int index) async {
    final draft = _drafts[ExperienceCatalog.knowledgeArenaId];
    if (draft == null) return;
    final cards = activeKnowledgeArenaCards();
    if (cards.isEmpty) return;
    final clamped = index.clamp(0, cards.length - 1);
    _drafts[ExperienceCatalog.knowledgeArenaId] = draft.copyWith(
      currentQuestionIndex: clamped,
      updatedAt: DateTime.now(),
    );
    await _storage.saveExperienceDrafts(_drafts);
    notifyListeners();
  }

  String? savedNoteIdForCard(String cardId) {
    final draftPairs = _drafts[ExperienceCatalog.knowledgeArenaId]
            ?.selectedOptionIdsByQuestion[_metaSavedNotesKey] ??
        const [];
    for (final entry in draftPairs) {
      if (entry.startsWith('$cardId:')) {
        return entry.substring(cardId.length + 1);
      }
    }
    final latest = latestResultFor(ExperienceCatalog.knowledgeArenaId);
    final snapList = latest?.answersSnapshot['savedNotes'];
    if (snapList is List) {
      for (final raw in snapList) {
        final str = raw.toString();
        if (str.startsWith('$cardId:')) {
          return str.substring(cardId.length + 1);
        }
      }
    }
    return null;
  }

  String? addedBookIdForCard(String cardId) {
    final draftPairs = _drafts[ExperienceCatalog.knowledgeArenaId]
            ?.selectedOptionIdsByQuestion[_metaAddedBooksKey] ??
        const [];
    for (final entry in draftPairs) {
      if (entry.startsWith('$cardId:')) {
        return entry.substring(cardId.length + 1);
      }
    }
    final latest = latestResultFor(ExperienceCatalog.knowledgeArenaId);
    final snapList = latest?.answersSnapshot['addedBooks'];
    if (snapList is List) {
      for (final raw in snapList) {
        final str = raw.toString();
        if (str.startsWith('$cardId:')) {
          return str.substring(cardId.length + 1);
        }
      }
    }
    return null;
  }

  bool isFactCardSavedToNotes(String cardId) =>
      savedNoteIdForCard(cardId) != null;

  bool isSuggestedBookAddedToReading(String cardId) =>
      addedBookIdForCard(cardId) != null;

  /// Echo Action: Saves an explainable curiosity fact card directly to [NoteProvider]
  /// and bidirectionally links it with the related Pippin [ReadingItem] if present.
  Future<NoteItem> saveFactCardToEchoNotes({
    required KnowledgeArenaCard card,
    required String localizedTopic,
    required String localizedFactTitle,
    required String localizedPrompt,
    required String localizedCorrectAnswer,
    required String localizedExplanation,
    required String localizedBookTitle,
    required String localizedBookAuthor,
    required NoteProvider noteProvider,
    CrossModuleLinkProvider? linkProvider,
  }) async {
    final now = DateTime.now();
    final contentBuffer = StringBuffer()
      ..writeln('### $localizedPrompt')
      ..writeln()
      ..writeln('**✓ $localizedCorrectAnswer**')
      ..writeln()
      ..writeln(localizedExplanation)
      ..writeln()
      ..writeln(
        '📖 *$localizedBookTitle* — $localizedBookAuthor (${card.suggestedBookPages}p)',
      );

    final note = NoteItem(
      id: _uuid.v4(),
      title: '🏛️ $localizedFactTitle',
      content: contentBuffer.toString().trim(),
      category: AlarmCategory.fromType(AlarmCategoryType.activities),
      tags: ['Knowledge Arena', localizedTopic],
      isPinned: false,
      colorValue: 0xFF6366F1,
      createdAt: now,
      updatedAt: now,
    );
    await noteProvider.addNote(note);

    await _recordKnowledgeCardActionPair(
      metaKey: _metaSavedNotesKey,
      snapshotKey: 'savedNotes',
      pair: '${card.id}:${note.id}',
    );

    final linkedBookId = addedBookIdForCard(card.id);
    if (linkProvider != null && linkedBookId != null) {
      await linkProvider.addLink(
        sourceType: LinkEntityType.note,
        sourceId: note.id,
        sourceTitle: note.title,
        targetType: LinkEntityType.readingBook,
        targetId: linkedBookId,
        targetTitle: localizedBookTitle,
        relationship: 'knowledge_arena_reading',
      );
    }

    return note;
  }

  /// Pippin Action: Adds the card's suggested book to [ReadingProvider] (`wantToRead`)
  /// and bidirectionally links it with the saved Echo [NoteItem] if present.
  Future<ReadingItem> addSuggestedBookToPippinReading({
    required KnowledgeArenaCard card,
    required String localizedTopic,
    required String localizedFactTitle,
    required String localizedBookTitle,
    required String localizedBookAuthor,
    required ReadingProvider readingProvider,
    CrossModuleLinkProvider? linkProvider,
  }) async {
    final now = DateTime.now();
    final book = ReadingItem(
      id: _uuid.v4(),
      title: localizedBookTitle,
      author: localizedBookAuthor,
      category: localizedTopic,
      format: ReadingFormat.book,
      currentPage: 0,
      totalPages: card.suggestedBookPages,
      status: ReadingStatus.wantToRead,
      notes: 'Echo\'s Knowledge Arena • $localizedFactTitle',
      createdAt: now,
      updatedAt: now,
    );
    await readingProvider.addBook(book);

    await _recordKnowledgeCardActionPair(
      metaKey: _metaAddedBooksKey,
      snapshotKey: 'addedBooks',
      pair: '${card.id}:${book.id}',
    );

    final linkedNoteId = savedNoteIdForCard(card.id);
    if (linkProvider != null && linkedNoteId != null) {
      await linkProvider.addLink(
        sourceType: LinkEntityType.note,
        sourceId: linkedNoteId,
        sourceTitle: '🏛️ $localizedFactTitle',
        targetType: LinkEntityType.readingBook,
        targetId: book.id,
        targetTitle: book.title,
        relationship: 'knowledge_arena_reading',
      );
    }

    return book;
  }

  Future<void> _recordKnowledgeCardActionPair({
    required String metaKey,
    required String snapshotKey,
    required String pair,
  }) async {
    final draft = _drafts[ExperienceCatalog.knowledgeArenaId];
    if (draft != null) {
      final nextMap = <String, List<String>>{};
      draft.selectedOptionIdsByQuestion.forEach((k, v) {
        nextMap[k] = List<String>.from(v);
      });
      final list = List<String>.from(nextMap[metaKey] ?? const []);
      if (!list.contains(pair)) {
        list.add(pair);
      }
      nextMap[metaKey] = list;
      _drafts[ExperienceCatalog.knowledgeArenaId] = draft.copyWith(
        selectedOptionIdsByQuestion: nextMap,
        updatedAt: DateTime.now(),
      );
      await _storage.saveExperienceDrafts(_drafts);
    }

    final latestIndex = _results.indexWhere(
      (r) => r.experienceId == ExperienceCatalog.knowledgeArenaId,
    );
    if (latestIndex != -1) {
      final current = _results[latestIndex];
      final snap = Map<String, dynamic>.from(current.answersSnapshot);
      final existingList = (snap[snapshotKey] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      if (!existingList.contains(pair)) {
        existingList.add(pair);
      }
      snap[snapshotKey] = existingList;
      _results[latestIndex] = ExperienceResultRecord(
        id: current.id,
        experienceId: current.experienceId,
        definitionVersion: current.definitionVersion,
        completedAt: current.completedAt,
        topMatches: current.topMatches,
        answersSnapshot: snap,
      );
      await _storage.saveExperienceResults(_results);
    }
    notifyListeners();
  }

  /// Completes the active Knowledge Arena session and records the summary snapshot.
  Future<ExperienceResultRecord> completeKnowledgeArenaSession() async {
    final draft = _drafts[ExperienceCatalog.knowledgeArenaId] ??
        await startFreshKnowledgeArena();
    final topic = activeKnowledgeArenaTopic();
    final cards = ExperienceCatalog.cardsForTopic(topic);

    var correctCount = 0;
    for (final c in cards) {
      final chosen = draft.selectedOptionIdsByQuestion[c.id]?.firstOrNull;
      if (chosen == c.correctOptionId) {
        correctCount++;
      }
    }
    final total = cards.isEmpty ? 1 : cards.length;
    final percentage = ((correctCount / total) * 100).round().clamp(0, 100);

    final savedNotes = List<String>.from(
      draft.selectedOptionIdsByQuestion[_metaSavedNotesKey] ?? const [],
    );
    final addedBooks = List<String>.from(
      draft.selectedOptionIdsByQuestion[_metaAddedBooksKey] ?? const [],
    );

    final record = ExperienceResultRecord(
      experienceId: ExperienceCatalog.knowledgeArenaId,
      definitionVersion: 1,
      completedAt: DateTime.now(),
      topMatches: [
        ExperienceMatchedOutcome(
          profileId: topic.name,
          matchPercentage: percentage,
          rawScore: correctCount.toDouble(),
          reasonKeys: const ['ka_subtitle'],
        ),
      ],
      answersSnapshot: {
        'topic': topic.name,
        'correctCount': correctCount,
        'totalCards': cards.length,
        'selectedOptionIdsByQuestion': draft.selectedOptionIdsByQuestion,
        'savedNotes': savedNotes,
        'addedBooks': addedBooks,
      },
    );

    _results = [record, ..._results];
    _drafts.remove(ExperienceCatalog.knowledgeArenaId);
    await _storage.saveExperienceResults(_results);
    await _storage.saveExperienceDrafts(_drafts);
    notifyListeners();
    return record;
  }

  // ===========================================================================
  // ECHO'S BRAIN PLAYGROUND (brain_playground_v1) — Echo + Roo Pomodoro Integration
  // ===========================================================================

  static const String _metaBpCategoryKey = '_bp_category';
  static const String _metaBpFocusLogsKey = '_bp_focus_logs';
  static const String _metaBpSavedNotesKey = '_bp_saved_notes';

  BrainPlaygroundCategory activeBrainPlaygroundCategory() {
    final draft = _drafts[ExperienceCatalog.brainPlaygroundId];
    final raw =
        draft?.selectedOptionIdsByQuestion[_metaBpCategoryKey]?.firstOrNull;
    if (raw == null) return BrainPlaygroundCategory.all;
    return BrainPlaygroundCategory.values.firstWhere(
      (c) => c.name == raw,
      orElse: () => BrainPlaygroundCategory.all,
    );
  }

  List<BrainPlaygroundPuzzle> activeBrainPlaygroundPuzzles() {
    return ExperienceCatalog.puzzlesForCategory(
      activeBrainPlaygroundCategory(),
    );
  }

  int brainPlaygroundAnsweredCount() {
    final draft = _drafts[ExperienceCatalog.brainPlaygroundId];
    if (draft == null) return 0;
    final puzzles = activeBrainPlaygroundPuzzles();
    var count = 0;
    for (final p in puzzles) {
      final ans = draft.selectedOptionIdsByQuestion[p.id];
      if (ans != null && ans.isNotEmpty) count++;
    }
    return count;
  }

  Future<ExperienceSessionDraft> startOrResumeBrainPlayground({
    BrainPlaygroundCategory category = BrainPlaygroundCategory.all,
  }) async {
    final existing = _drafts[ExperienceCatalog.brainPlaygroundId];
    if (existing != null && activeBrainPlaygroundCategory() == category) {
      return existing;
    }
    return startFreshBrainPlayground(category: category);
  }

  Future<ExperienceSessionDraft> startFreshBrainPlayground({
    BrainPlaygroundCategory category = BrainPlaygroundCategory.all,
  }) async {
    final now = DateTime.now();
    final draft = ExperienceSessionDraft(
      experienceId: ExperienceCatalog.brainPlaygroundId,
      definitionVersion: 1,
      currentQuestionIndex: 0,
      selectedOptionIdsByQuestion: {
        _metaBpCategoryKey: [category.name],
      },
      numericValueByQuestion: const {},
      skippedQuestionIds: const [],
      startedAt: now,
      updatedAt: now,
    );
    _drafts[ExperienceCatalog.brainPlaygroundId] = draft;
    await _storage.saveExperienceDrafts(_drafts);
    notifyListeners();
    return draft;
  }

  String? selectedOptionForBrainPuzzle(String puzzleId) {
    final draft = _drafts[ExperienceCatalog.brainPlaygroundId];
    final list = draft?.selectedOptionIdsByQuestion[puzzleId];
    if (list != null && list.isNotEmpty) return list.first;
    final latest = latestResultFor(ExperienceCatalog.brainPlaygroundId);
    final savedAnswers =
        latest?.answersSnapshot['selectedOptionIdsByQuestion'];
    if (savedAnswers is Map) {
      final prevList = savedAnswers[puzzleId];
      if (prevList is List && prevList.isNotEmpty) {
        return prevList.first.toString();
      }
    }
    return null;
  }

  Future<void> answerBrainPlaygroundPuzzle({
    required BrainPlaygroundPuzzle puzzle,
    required String optionId,
  }) async {
    final draft = _drafts[ExperienceCatalog.brainPlaygroundId] ??
        await startFreshBrainPlayground();
    final nextMap = <String, List<String>>{};
    draft.selectedOptionIdsByQuestion.forEach((k, v) {
      nextMap[k] = List<String>.from(v);
    });
    nextMap[puzzle.id] = [optionId];

    _drafts[ExperienceCatalog.brainPlaygroundId] = draft.copyWith(
      selectedOptionIdsByQuestion: nextMap,
      updatedAt: DateTime.now(),
    );
    await _storage.saveExperienceDrafts(_drafts);
    notifyListeners();
  }

  Future<void> goToBrainPlaygroundPuzzleIndex(int index) async {
    final draft = _drafts[ExperienceCatalog.brainPlaygroundId];
    if (draft == null) return;
    final puzzles = activeBrainPlaygroundPuzzles();
    if (puzzles.isEmpty) return;
    final clamped = index.clamp(0, puzzles.length - 1);
    _drafts[ExperienceCatalog.brainPlaygroundId] = draft.copyWith(
      currentQuestionIndex: clamped,
      updatedAt: DateTime.now(),
    );
    await _storage.saveExperienceDrafts(_drafts);
    notifyListeners();
  }

  bool isPuzzleLoggedToRooFocus(String puzzleId) {
    final draftList = _drafts[ExperienceCatalog.brainPlaygroundId]
            ?.selectedOptionIdsByQuestion[_metaBpFocusLogsKey] ??
        const [];
    if (draftList.any((e) => e.startsWith('$puzzleId:'))) return true;
    final latest = latestResultFor(ExperienceCatalog.brainPlaygroundId);
    final snapList = latest?.answersSnapshot['focusLogs'];
    if (snapList is List) {
      return snapList.any((e) => e.toString().startsWith('$puzzleId:'));
    }
    return false;
  }

  bool isPuzzleSavedToEchoNotes(String puzzleId) {
    final draftList = _drafts[ExperienceCatalog.brainPlaygroundId]
            ?.selectedOptionIdsByQuestion[_metaBpSavedNotesKey] ??
        const [];
    if (draftList.any((e) => e.startsWith('$puzzleId:'))) return true;
    final latest = latestResultFor(ExperienceCatalog.brainPlaygroundId);
    final snapList = latest?.answersSnapshot['savedNotes'];
    if (snapList is List) {
      return snapList.any((e) => e.toString().startsWith('$puzzleId:'));
    }
    return false;
  }

  /// Roo Action 1: Logs a 3-minute pre-focus cognitive warm-up into [TimerProvider.focusLogs]
  /// (`FocusSessionLog`) and optionally starts a 25-minute Pomodoro sprint immediately.
  Future<FocusSessionLog> logWarmupToRooFocusHistory({
    required BrainPlaygroundPuzzle puzzle,
    required String localizedPuzzleTitle,
    required TimerProvider timerProvider,
    int durationMinutes = 3,
    bool startPomodoroSprint = false,
  }) async {
    final log = await timerProvider.recordPreFocusWarmup(
      warmupLabel: '🧩 Brain Playground • $localizedPuzzleTitle',
      durationMinutes: durationMinutes,
      startPomodoroSprint: startPomodoroSprint,
    );

    await _recordBrainPlaygroundActionPair(
      metaKey: _metaBpFocusLogsKey,
      snapshotKey: 'focusLogs',
      pair: '${puzzle.id}:${log.id}',
    );
    return log;
  }

  /// Echo Action: Saves the puzzle's reasoning strategy & mental model into [NoteProvider].
  Future<NoteItem> savePuzzleInsightToEchoNotes({
    required BrainPlaygroundPuzzle puzzle,
    required String localizedCategory,
    required String localizedPuzzleTitle,
    required String localizedPrompt,
    required String localizedCorrectAnswer,
    required String localizedExplanation,
    required NoteProvider noteProvider,
  }) async {
    final now = DateTime.now();
    final content = StringBuffer()
      ..writeln('### ${puzzle.visualBanner}')
      ..writeln()
      ..writeln(localizedPrompt)
      ..writeln()
      ..writeln('**✓ $localizedCorrectAnswer**')
      ..writeln()
      ..writeln(localizedExplanation);

    final note = NoteItem(
      id: _uuid.v4(),
      title: '🧩 $localizedPuzzleTitle',
      content: content.toString().trim(),
      category: AlarmCategory.fromType(AlarmCategoryType.activities),
      tags: ['Brain Playground', localizedCategory],
      isPinned: false,
      colorValue: 0xFF8B5CF6,
      createdAt: now,
      updatedAt: now,
    );
    await noteProvider.addNote(note);

    await _recordBrainPlaygroundActionPair(
      metaKey: _metaBpSavedNotesKey,
      snapshotKey: 'savedNotes',
      pair: '${puzzle.id}:${note.id}',
    );
    return note;
  }

  Future<void> _recordBrainPlaygroundActionPair({
    required String metaKey,
    required String snapshotKey,
    required String pair,
  }) async {
    final draft = _drafts[ExperienceCatalog.brainPlaygroundId];
    if (draft != null) {
      final nextMap = <String, List<String>>{};
      draft.selectedOptionIdsByQuestion.forEach((k, v) {
        nextMap[k] = List<String>.from(v);
      });
      final list = List<String>.from(nextMap[metaKey] ?? const []);
      if (!list.contains(pair)) {
        list.add(pair);
      }
      nextMap[metaKey] = list;
      _drafts[ExperienceCatalog.brainPlaygroundId] = draft.copyWith(
        selectedOptionIdsByQuestion: nextMap,
        updatedAt: DateTime.now(),
      );
      await _storage.saveExperienceDrafts(_drafts);
    }

    final latestIndex = _results.indexWhere(
      (r) => r.experienceId == ExperienceCatalog.brainPlaygroundId,
    );
    if (latestIndex != -1) {
      final current = _results[latestIndex];
      final snap = Map<String, dynamic>.from(current.answersSnapshot);
      final existingList = (snap[snapshotKey] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      if (!existingList.contains(pair)) {
        existingList.add(pair);
      }
      snap[snapshotKey] = existingList;
      _results[latestIndex] = ExperienceResultRecord(
        id: current.id,
        experienceId: current.experienceId,
        definitionVersion: current.definitionVersion,
        completedAt: current.completedAt,
        topMatches: current.topMatches,
        answersSnapshot: snap,
      );
      await _storage.saveExperienceResults(_results);
    }
    notifyListeners();
  }

  /// Completes the active Brain Playground session and records the summary snapshot.
  Future<ExperienceResultRecord> completeBrainPlaygroundSession() async {
    final draft = _drafts[ExperienceCatalog.brainPlaygroundId] ??
        await startFreshBrainPlayground();
    final category = activeBrainPlaygroundCategory();
    final puzzles = ExperienceCatalog.puzzlesForCategory(category);

    var correctCount = 0;
    for (final p in puzzles) {
      final chosen = draft.selectedOptionIdsByQuestion[p.id]?.firstOrNull;
      if (chosen == p.correctOptionId) {
        correctCount++;
      }
    }
    final total = puzzles.isEmpty ? 1 : puzzles.length;
    final percentage = ((correctCount / total) * 100).round().clamp(0, 100);

    final focusLogs = List<String>.from(
      draft.selectedOptionIdsByQuestion[_metaBpFocusLogsKey] ?? const [],
    );
    final savedNotes = List<String>.from(
      draft.selectedOptionIdsByQuestion[_metaBpSavedNotesKey] ?? const [],
    );

    final record = ExperienceResultRecord(
      experienceId: ExperienceCatalog.brainPlaygroundId,
      definitionVersion: 1,
      completedAt: DateTime.now(),
      topMatches: [
        ExperienceMatchedOutcome(
          profileId: category.name,
          matchPercentage: percentage,
          rawScore: correctCount.toDouble(),
          reasonKeys: const ['bp_subtitle'],
        ),
      ],
      answersSnapshot: {
        'category': category.name,
        'correctCount': correctCount,
        'totalPuzzles': puzzles.length,
        'selectedOptionIdsByQuestion': draft.selectedOptionIdsByQuestion,
        'focusLogs': focusLogs,
        'savedNotes': savedNotes,
      },
    );

    _results = [record, ..._results];
    _drafts.remove(ExperienceCatalog.brainPlaygroundId);
    await _storage.saveExperienceResults(_results);
    await _storage.saveExperienceDrafts(_drafts);
    notifyListeners();
    return record;
  }

  // ===========================================================================
  // PIPPIN'S READING TASTE & NEXT-BOOK MATCHER (book_matcher_v1)
  // ===========================================================================

  /// Resolves a [BookRecommendationProfile] by [profileId] across Tier 1 (Bundled Catalog),
  /// Tier 2 (On-Device User Shelf), and Tier 3 (Cached Open Library API).
  BookRecommendationProfile? resolveBookProfile(
    String profileId, {
    List<ReadingItem>? userReadingItems,
    ExperienceResultRecord? resultRecord,
  }) {
    final snapMap = resultRecord?.answersSnapshot['matchedBooksById'];
    if (snapMap is Map && snapMap[profileId] is Map) {
      return BookRecommendationProfile.fromJson(
        Map<String, dynamic>.from(snapMap[profileId] as Map),
      );
    }

    final fromCatalogOrCache = BookMatcherCatalog.findBookById(
      profileId,
      extraBooks: _openLibraryService.getCachedBooks(),
    );
    if (fromCatalogOrCache != null) return fromCatalogOrCache;

    if (profileId.startsWith('shelf_')) {
      final rawItemId = profileId.substring('shelf_'.length);
      final items = userReadingItems ?? _storage.loadReadingItems();
      for (final item in items) {
        if (item.id == rawItemId) {
          return InteractiveExperienceEngine.profileFromUserReadingItem(item);
        }
      }
    }
    return null;
  }

  /// Completes Pippin's Reading Taste & Next-Book Matcher (`book_matcher_v1`),
  /// evaluating across Tier 1 (42 Bundled Books), Tier 2 (On-Device `ReadingProvider`),
  /// and Tier 3 (Cached Open Library API books).
  Future<ExperienceResultRecord> completeBookMatcherSession({
    List<ReadingItem>? userReadingItems,
  }) async {
    const def = BookMatcherCatalog.definition;
    final draft = _drafts[def.id] ?? await startFreshSession(def);
    final shelfItems = userReadingItems ?? _storage.loadReadingItems();
    final onlineBooks = _openLibraryService.getCachedBooks();

    final topMatches = engine.evaluateBookMatcher(
      draft: draft,
      userReadingItems: shelfItems,
      extraOnlineBooks: onlineBooks,
      maxResults: 3,
    );

    final matchedBooksById = <String, dynamic>{};
    for (final match in topMatches) {
      final profile = resolveBookProfile(
        match.profileId,
        userReadingItems: shelfItems,
      );
      if (profile != null) {
        matchedBooksById[match.profileId] = profile.toJson();
      }
    }

    final dailyMinutes =
        (draft.numericValueByQuestion['bm_q_daily_mins'] ?? 20.0)
            .round()
            .clamp(10, 60);

    final record = ExperienceResultRecord(
      experienceId: def.id,
      definitionVersion: def.version,
      completedAt: DateTime.now(),
      topMatches: topMatches,
      answersSnapshot: {
        'selectedOptionIdsByQuestion': draft.selectedOptionIdsByQuestion,
        'numericValueByQuestion': draft.numericValueByQuestion,
        'skippedQuestionIds': draft.skippedQuestionIds,
        'dailyReadingMinutes': dailyMinutes,
        'matchedBooksById': matchedBooksById,
      },
    );

    _results = [record, ..._results];
    _drafts.remove(def.id);
    await _storage.saveExperienceResults(_results);
    await _storage.saveExperienceDrafts(_drafts);
    notifyListeners();
    return record;
  }

  /// Tier-3 Action: Fetches live book suggestions from the free Open Library API
  /// (`openlibrary.org/subjects/*`), caches them locally in [StorageService],
  /// and refreshes the latest `book_matcher_v1` result if present.
  Future<List<BookRecommendationProfile>> enrichBookMatcherViaOpenLibrary({
    BookMatcherGenre? genre,
    List<ReadingItem>? userReadingItems,
  }) async {
    _isFetchingOpenLibrary = true;
    notifyListeners();
    try {
      final targetGenre = genre ?? _inferPreferredBookGenre();
      final fetched = await _openLibraryService.fetchAndCacheSubjectBooks(
        targetGenre,
      );

      final latest = latestResultFor(ExperienceCatalog.bookMatcherId);
      if (latest != null && fetched.isNotEmpty) {
        final rawSelected =
            latest.answersSnapshot['selectedOptionIdsByQuestion'] as Map? ?? {};
        final parsedSelected = <String, List<String>>{};
        rawSelected.forEach((k, v) {
          if (v is List) {
            parsedSelected[k.toString()] = v.map((e) => e.toString()).toList();
          }
        });
        final rawNumeric =
            latest.answersSnapshot['numericValueByQuestion'] as Map? ?? {};
        final parsedNumeric = <String, double>{};
        rawNumeric.forEach((k, v) {
          if (v is num) parsedNumeric[k.toString()] = v.toDouble();
        });

        final syntheticDraft = ExperienceSessionDraft(
          experienceId: ExperienceCatalog.bookMatcherId,
          definitionVersion: 1,
          selectedOptionIdsByQuestion: parsedSelected,
          numericValueByQuestion: parsedNumeric,
          startedAt: latest.completedAt,
          updatedAt: DateTime.now(),
        );
        final shelfItems = userReadingItems ?? _storage.loadReadingItems();
        final refreshedMatches = engine.evaluateBookMatcher(
          draft: refreshedDraftWithTopic(syntheticDraft, targetGenre),
          userReadingItems: shelfItems,
          extraOnlineBooks: _openLibraryService.getCachedBooks(),
          maxResults: 3,
        );
        final matchedBooksById = <String, dynamic>{};
        for (final m in refreshedMatches) {
          final p = resolveBookProfile(m.profileId, userReadingItems: shelfItems);
          if (p != null) {
            matchedBooksById[m.profileId] = p.toJson();
          }
        }
        final updatedSnap = Map<String, dynamic>.from(latest.answersSnapshot);
        updatedSnap['matchedBooksById'] = matchedBooksById;
        updatedSnap['openLibraryEnrichedGenre'] = targetGenre.name;

        final idx = _results.indexWhere((r) => r.id == latest.id);
        if (idx != -1) {
          _results[idx] = ExperienceResultRecord(
            id: latest.id,
            experienceId: latest.experienceId,
            definitionVersion: latest.definitionVersion,
            completedAt: latest.completedAt,
            topMatches: refreshedMatches,
            answersSnapshot: updatedSnap,
            addedToPippinBookId: latest.addedToPippinBookId,
            createdRooTaskId: latest.createdRooTaskId,
            createdRooRoutineId: latest.createdRooRoutineId,
            playedSerenSoundId: latest.playedSerenSoundId,
          );
          await _storage.saveExperienceResults(_results);
        }
      }
      return fetched;
    } finally {
      _isFetchingOpenLibrary = false;
      notifyListeners();
    }
  }

  static ExperienceSessionDraft refreshedDraftWithTopic(
    ExperienceSessionDraft draft,
    BookMatcherGenre genre,
  ) {
    return draft;
  }

  BookMatcherGenre _inferPreferredBookGenre() {
    final latest = latestResultFor(ExperienceCatalog.bookMatcherId);
    final rawSelected =
        latest?.answersSnapshot['selectedOptionIdsByQuestion'] as Map?;
    final topics = (rawSelected?['bm_q_topics'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];
    if (topics.contains('bm_opt_topic_nature_sci')) {
      return BookMatcherGenre.natureAndScience;
    }
    if (topics.contains('bm_opt_topic_mindful')) {
      return BookMatcherGenre.mindfulNonFiction;
    }
    if (topics.contains('bm_opt_topic_philosophy')) {
      return BookMatcherGenre.philosophy;
    }
    if (topics.contains('bm_opt_topic_history')) {
      return BookMatcherGenre.historicalAdventure;
    }
    if (topics.contains('bm_opt_topic_indo_world')) {
      return BookMatcherGenre.indonesianAndWorldLit;
    }
    return BookMatcherGenre.cozyFiction;
  }

  /// 1. Pippin Handoff (`book_matcher_v1`): Adds or promotes the matched book in
  /// [ReadingProvider] (`wantToRead` or `currentlyReading`) with page count target.
  Future<ReadingItem> addMatchedBookToPippinReading({
    required String resultId,
    required BookRecommendationProfile profile,
    required ReadingProvider readingProvider,
    ReadingStatus status = ReadingStatus.wantToRead,
    bool updateDailyPageGoalFromQuiz = true,
  }) async {
    final now = DateTime.now();
    ReadingItem targetBook;

    if (profile.existingReadingItemId != null) {
      final existing = readingProvider.findById(profile.existingReadingItemId!);
      if (existing != null) {
        targetBook = existing.copyWith(
          status: status,
          startedAt: status == ReadingStatus.currentlyReading
              ? (existing.startedAt ?? now)
              : existing.startedAt,
          updatedAt: now,
        );
        await readingProvider.updateBook(targetBook);
      } else {
        targetBook = ReadingItem(
          id: _uuid.v4(),
          title: profile.localizedTitle,
          author: profile.author,
          category: profile.readingCategory,
          format: ReadingFormat.book,
          currentPage: 0,
          totalPages: profile.pageCount,
          status: status,
          notes: profile.localizedSynopsis,
          startedAt: status == ReadingStatus.currentlyReading ? now : null,
          createdAt: now,
          updatedAt: now,
        );
        await readingProvider.addBook(targetBook);
      }
    } else {
      targetBook = ReadingItem(
        id: _uuid.v4(),
        title: profile.localizedTitle,
        author: profile.author,
        category: profile.readingCategory,
        format: ReadingFormat.book,
        currentPage: 0,
        totalPages: profile.pageCount,
        status: status,
        notes: profile.localizedSynopsis,
        startedAt: status == ReadingStatus.currentlyReading ? now : null,
        createdAt: now,
        updatedAt: now,
      );
      await readingProvider.addBook(targetBook);
    }

    final record = _results.where((r) => r.id == resultId).firstOrNull;
    if (updateDailyPageGoalFromQuiz && record != null) {
      final quizMins =
          (record.answersSnapshot['dailyReadingMinutes'] as num?)?.toInt() ??
              20;
      final suggestedPages = (quizMins * 0.85).round().clamp(5, 100);
      await readingProvider.setDailyPageGoal(suggestedPages);
    }

    await _updateResultRecord(
      resultId,
      (r) => r.copyWith(addedToPippinBookId: targetBook.id),
    );
    return targetBook;
  }

  /// 2. Seren Handoff (`book_matcher_v1`): Starts the paired reading soundscape
  /// (`nylon_guitar` -> `nylonAcousticGuitar`, `gentle_rain` -> `rain`,
  /// `warm_piano` -> `gentlePiano`) in [SerenRelaxationProvider].
  Future<void> startBookMatcherSerenSoundscape({
    required String resultId,
    required BookRecommendationProfile profile,
    required SerenRelaxationProvider serenProvider,
  }) async {
    final canonicalId = profile.canonicalSerenSoundId;
    await serenProvider.playSingleSound(canonicalId);
    await _updateResultRecord(
      resultId,
      (r) => r.copyWith(playedSerenSoundId: canonicalId),
    );
  }

  /// 3. Roo Handoff (`book_matcher_v1`): Schedules a 20-minute (or quiz-configured)
  /// evening reading habit block in [RoutineProvider] and [TaskProvider],
  /// bidirectionally linked to the Pippin [ReadingItem] via [CrossModuleLinkProvider].
  Future<TaskItem> scheduleBookReadingHabitInRoo({
    required String resultId,
    required BookRecommendationProfile profile,
    required TaskProvider taskProvider,
    RoutineProvider? routineProvider,
    CrossModuleLinkProvider? linkProvider,
  }) async {
    final now = DateTime.now();
    final record = _results.where((r) => r.id == resultId).firstOrNull;
    final dailyMins =
        (record?.answersSnapshot['dailyReadingMinutes'] as num?)?.toInt() ?? 20;
    final stepTitle =
        '📖 Read "${profile.localizedTitle}" ($dailyMins min evening reading)';

    String? createdRoutineId;
    if (routineProvider != null) {
      final eveningRoutine = routineProvider.routines
          .where((r) => r.type == RoutineType.evening)
          .firstOrNull;
      if (eveningRoutine != null) {
        createdRoutineId = eveningRoutine.id;
        if (!eveningRoutine.steps.contains(stepTitle)) {
          final updatedSteps = List<String>.from(eveningRoutine.steps)
            ..add(stepTitle);
          final updatedRoutines = routineProvider.routines
              .map(
                (r) => r.id == eveningRoutine.id
                    ? r.copyWith(steps: updatedSteps)
                    : r,
              )
              .toList();
          await _storage.saveRoutines(updatedRoutines);
        }
      } else {
        final newRoutine = RoutineItem(
          id: _uuid.v4(),
          title: 'Evening Reading Sanctuary',
          description: 'Pippin & Roo evening reading habit block',
          type: RoutineType.evening,
          steps: [stepTitle],
          createdAt: now,
        );
        createdRoutineId = newRoutine.id;
        await routineProvider.addRoutine(newRoutine);
      }
    }

    final task = TaskItem(
      id: _uuid.v4(),
      title: stepTitle,
      notes:
          'Pippin\'s Next-Book Matcher • ${profile.author} (${profile.pageCount}p)',
      dueDate: DateTime(now.year, now.month, now.day, 20, 30),
      priority: TaskPriority.medium,
      category: AlarmCategory.fromType(AlarmCategoryType.personal),
      subtasks: [
        TaskSubItem(
          id: _uuid.v4(),
          title: 'Read for $dailyMins minutes with Seren ambient audio',
        ),
      ],
      createdAt: now,
    );
    await taskProvider.addTask(task);

    if (linkProvider != null && record?.addedToPippinBookId != null) {
      await linkProvider.addLink(
        sourceType: LinkEntityType.readingBook,
        sourceId: record!.addedToPippinBookId!,
        sourceTitle: profile.localizedTitle,
        targetType: LinkEntityType.task,
        targetId: task.id,
        targetTitle: task.title,
        relationship: 'evening_reading_habit',
      );
    }

    await _updateResultRecord(
      resultId,
      (r) => r.copyWith(
        createdRooTaskId: task.id,
        createdRooRoutineId: createdRoutineId ?? r.createdRooRoutineId,
      ),
    );
    return task;
  }

  // ===========================================================================
  // SCOUT'S WEEKEND GENERATOR (weekend_generator_v1) — Scout + Roo + Twill
  // ===========================================================================

  /// Completes Scout's Weekend Generator (`weekend_generator_v1`), evaluating
  /// bundled offline micro-itineraries alongside live/simulated [WeatherInfo].
  Future<ExperienceResultRecord> completeWeekendGeneratorSession({
    WeatherInfo? currentWeather,
  }) async {
    const def = WeekendGeneratorCatalog.definition;
    final draft = _drafts[def.id] ?? await startFreshSession(def);
    final topMatches = engine.evaluateWeekendGenerator(
      draft: draft,
      currentWeather: currentWeather,
      maxResults: 3,
    );

    final record = ExperienceResultRecord(
      experienceId: def.id,
      definitionVersion: def.version,
      completedAt: DateTime.now(),
      topMatches: topMatches,
      answersSnapshot: {
        'selectedOptionIdsByQuestion': draft.selectedOptionIdsByQuestion,
        'numericValueByQuestion': draft.numericValueByQuestion,
        'skippedQuestionIds': draft.skippedQuestionIds,
        if (currentWeather != null)
          'weatherSummary': {
            'condition': currentWeather.condition,
            'tempCelsius': currentWeather.temperatureCelsius,
            'rainChancePercent': currentWeather.rainChancePercent,
            'isRainy': currentWeather.isRainy,
          },
      },
    );

    _results = [record, ..._results];
    _drafts.remove(def.id);
    await _storage.saveExperienceResults(_results);
    await _storage.saveExperienceDrafts(_drafts);
    notifyListeners();
    return record;
  }

  /// 1. Scout Handoff (`weekend_generator_v1`): Creates a tailored [DeparturePreset]
  /// in [BeforeYouGoProvider] (auto-enriched with local weather gear suggestions) and
  /// optionally pins an arrival [SavedPlace] + [LocationReminder] in [GeofenceProvider].
  Future<DeparturePreset> launchWeekendInScoutBeforeYouGo({
    required String resultId,
    required WeekendItineraryProfile profile,
    required String localizedTitle,
    required List<String> localizedGearItems,
    required String localizedPlaceName,
    required BeforeYouGoProvider beforeYouGoProvider,
    GeofenceProvider? geofenceProvider,
    CrossModuleLinkProvider? linkProvider,
    String languageCode = 'en',
    bool includeGeofenceReminder = false,
  }) async {
    final items = <DepartureChecklistItem>[
      DepartureChecklistItem(
        id: 'item_${_uuid.v4().substring(0, 8)}',
        label: languageCode.toLowerCase().startsWith('id')
            ? 'Kunci & Dompet / Identitas'
            : 'Keys & Wallet / ID',
        isEssential: true,
      ),
      for (final gear in localizedGearItems)
        DepartureChecklistItem(
          id: 'item_${_uuid.v4().substring(0, 8)}',
          label: gear,
          isEssential: false,
        ),
    ];

    final preset = await beforeYouGoProvider.createPreset(
      name: localizedTitle,
      iconCodePoint: Icons.explore_rounded.codePoint,
      colorValue: 0xFF3B82F6,
      items: items,
    );
    await beforeYouGoProvider.addAllWeatherSuggestionsToPreset(
      preset.id,
      languageCode: languageCode,
    );

    String? createdPlaceId;
    if (includeGeofenceReminder && geofenceProvider != null) {
      final place = SavedPlace(
        id: 'place_${_uuid.v4().substring(0, 8)}',
        name: localizedPlaceName,
        latitude: -6.2088,
        longitude: 106.8456,
        radiusMeters: profile.placeCategory.defaultRadiusMeters,
        category: profile.placeCategory,
        createdAt: DateTime.now(),
      );
      await geofenceProvider.addPlace(place);
      await geofenceProvider.addReminder(
        LocationReminder(
          id: 'georem_${_uuid.v4().substring(0, 8)}',
          title: '$localizedTitle — $localizedPlaceName',
          notes: localizedGearItems.take(3).join(' • '),
          placeId: place.id,
          triggerType: GeofenceTriggerType.arrive,
          category: AlarmCategory.fromType(AlarmCategoryType.personal),
          checkDepartureChecklist: true,
          createdAt: DateTime.now(),
        ),
      );
      createdPlaceId = place.id;
    }

    final existingRecord = _results.where((r) => r.id == resultId).firstOrNull;
    if (linkProvider != null &&
        existingRecord?.createdRooCalendarEventId != null) {
      await linkProvider.addLink(
        sourceType: LinkEntityType.calendarEvent,
        sourceId: existingRecord!.createdRooCalendarEventId!,
        sourceTitle: localizedTitle,
        targetType: LinkEntityType.beforeYouGoPreset,
        targetId: preset.id,
        targetTitle: preset.name,
        relationship: 'weekend_departure',
      );
    }

    await _updateResultRecord(
      resultId,
      (r) => r.copyWith(
        createdScoutPresetId: preset.id,
        createdScoutPlaceId: createdPlaceId ?? r.createdScoutPlaceId,
      ),
    );
    return preset;
  }

  /// Resolves the next upcoming Saturday (`DateTime.saturday`) or Sunday
  /// (`DateTime.sunday`) relative to [referenceDate].
  static DateTime nextWeekendDate({
    DateTime? referenceDate,
    int targetWeekday = DateTime.saturday,
  }) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var delta = (targetWeekday - today.weekday) % 7;
    if (delta == 0 && now.hour >= 18) {
      delta = 7;
    }
    return today.add(Duration(days: delta));
  }

  /// 2. Roo Handoff (`weekend_generator_v1`): Blocks a Saturday or Sunday outing
  /// window in [CalendarProvider] and links Scout's [DeparturePreset] if created.
  Future<CalendarEvent> scheduleWeekendBlockInRooCalendar({
    required String resultId,
    required WeekendItineraryProfile profile,
    required String localizedTitle,
    required String localizedDescription,
    required String localizedPlaceName,
    required CalendarProvider calendarProvider,
    CrossModuleLinkProvider? linkProvider,
    int targetWeekday = DateTime.saturday,
    DateTime? referenceDate,
  }) async {
    final eventDate = nextWeekendDate(
      referenceDate: referenceDate,
      targetWeekday: targetWeekday,
    );
    final start = TimeOfDay(
      hour: profile.defaultStartHour,
      minute: profile.defaultStartMinute,
    );
    final totalMinutes = (profile.durationHours * 60).round();
    final endTotalMins = (start.hour * 60 + start.minute + totalMinutes).clamp(
      start.hour * 60 + 30,
      23 * 60 + 45,
    );
    final end = TimeOfDay(
      hour: endTotalMins ~/ 60,
      minute: endTotalMins % 60,
    );

    final record = _results.where((r) => r.id == resultId).firstOrNull;
    final linkedPresetId = record?.createdScoutPresetId;

    final event = CalendarEvent(
      id: 'evt_${_uuid.v4().substring(0, 8)}',
      title: '${profile.iconEmoji} $localizedTitle',
      description: localizedDescription,
      date: eventDate,
      startTime: start,
      endTime: end,
      location: localizedPlaceName,
      budget: profile.estimatedPocketBudgetUsd > 0
          ? profile.estimatedPocketBudgetUsd.toDouble()
          : null,
      hasReminder: true,
      beforeYouGoPresetId: linkedPresetId,
      departureLeadMinutes: linkedPresetId != null ? 30 : null,
      category: AlarmCategory.fromType(AlarmCategoryType.personal),
      createdAt: DateTime.now(),
    );
    await calendarProvider.addEvent(event);

    if (linkProvider != null && linkedPresetId != null) {
      await linkProvider.addLink(
        sourceType: LinkEntityType.calendarEvent,
        sourceId: event.id,
        sourceTitle: event.title,
        targetType: LinkEntityType.beforeYouGoPreset,
        targetId: linkedPresetId,
        targetTitle: localizedTitle,
        relationship: 'weekend_departure',
      );
    }

    await _updateResultRecord(
      resultId,
      (r) => r.copyWith(createdRooCalendarEventId: event.id),
    );
    return event;
  }

  /// 3. Twill Handoff (`weekend_generator_v1`): Creates a weekend packing & gear
  /// checklist in [CollectionProvider] and optionally seeds/adjusts a monthly
  /// personal pocket-budget allowance in [MoneyProvider] (strictly non-banking).
  Future<CollectionItem> createWeekendPackAndBudgetInTwill({
    required String resultId,
    required WeekendItineraryProfile profile,
    required String localizedTitle,
    required List<String> localizedGearItems,
    required CollectionProvider collectionProvider,
    MoneyProvider? moneyProvider,
    bool setPocketBudgetCap = true,
  }) async {
    final now = DateTime.now();
    final entries = localizedGearItems
        .map(
          (itemText) => CollectionEntry(
            id: _uuid.v4(),
            text: itemText,
            category: 'Weekend Gear',
          ),
        )
        .toList();

    final collection = CollectionItem(
      id: _uuid.v4(),
      title: '$localizedTitle — Weekend Pack',
      description: 'Generated by Scout\'s Weekend Generator & Twill',
      iconCodePoint: Icons.backpack_rounded.codePoint,
      colorValue: 0xFFF59E0B,
      entries: entries,
      isReusableTemplate: true,
      createdAt: now,
    );
    await collectionProvider.addCollection(collection);

    String? createdBudgetId;
    if (setPocketBudgetCap &&
        profile.estimatedPocketBudgetUsd > 0 &&
        moneyProvider != null &&
        moneyProvider.isAuthenticated) {
      try {
        final expenseCats =
            moneyProvider.categoriesByType(MoneyCategoryType.expense);
        if (expenseCats.isNotEmpty) {
          final targetCat = expenseCats
                  .where((c) => c.id.endsWith('_exp_entertainment'))
                  .firstOrNull ??
              expenseCats.first;
          final currency = moneyProvider.settings.currency;
          final unitMultiplier = switch (currency) {
            MoneyCurrency.idr => 15000,
            MoneyCurrency.jpy => 150,
            _ => 1,
          };
          final weekendCapMinor =
              profile.estimatedPocketBudgetUsd * unitMultiplier * MoneyAmount.scale;
          final existingBudget = moneyProvider.budgets
              .where((b) =>
                  b.year == now.year &&
                  b.month == now.month &&
                  b.categoryId == targetCat.id)
              .firstOrNull;
          final nextLimitMinor =
              (existingBudget?.limitMinor ?? 0) + weekendCapMinor;
          final savedBudget = await moneyProvider.setMonthlyBudget(
            year: now.year,
            month: now.month,
            categoryId: targetCat.id,
            limitMinor: nextLimitMinor,
            note: 'Scout Weekend Cap: $localizedTitle',
          );
          createdBudgetId = savedBudget.id;
        }
      } catch (_) {
        // Non-fatal: weekend packing checklist still saves cleanly
      }
    }

    await _updateResultRecord(
      resultId,
      (r) => r.copyWith(
        createdTwillChecklistId: collection.id,
        createdTwillBudgetId: createdBudgetId ?? r.createdTwillBudgetId,
      ),
    );
    return collection;
  }
}
