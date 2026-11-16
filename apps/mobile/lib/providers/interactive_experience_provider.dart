import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/models/alarm_category.dart';
import '../data/models/collection_item.dart';
import '../data/models/entity_link.dart';
import '../data/models/hobby_item.dart';
import '../data/models/interactive_experience_models.dart';
import '../data/models/note_item.dart';
import '../data/models/reading_item.dart';
import '../data/models/task_item.dart';
import '../data/models/wishlist_item.dart';
import '../data/services/storage_service.dart';
import '../domain/experiences/interactive_experience_engine.dart';
import 'collection_provider.dart';
import 'cross_module_link_provider.dart';
import 'hobby_provider.dart';
import 'note_provider.dart';
import 'reading_provider.dart';
import 'seren_relaxation_provider.dart';
import 'task_provider.dart';

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

  InteractiveExperienceProvider(
    this._storage, {
    this.engine = const InteractiveExperienceEngine(),
  }) {
    _drafts = _storage.loadExperienceDrafts();
    _results = _storage.loadExperienceResults();
    _disabledExperienceIds =
        List<String>.from(_storage.loadDisabledExperienceIds());
  }

  final InteractiveExperienceEngine engine;

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
    ExperienceDefinition definition,
  ) async {
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
}
