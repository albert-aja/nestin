import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/models/alarm_category.dart';
import '../data/models/collection_item.dart';
import '../data/models/entity_link.dart';
import '../data/models/hobby_item.dart';
import '../data/models/interactive_experience_models.dart';
import '../data/models/task_item.dart';
import '../data/models/wishlist_item.dart';
import '../data/services/storage_service.dart';
import '../domain/experiences/interactive_experience_engine.dart';
import 'collection_provider.dart';
import 'cross_module_link_provider.dart';
import 'hobby_provider.dart';
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
}
