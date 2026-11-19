import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/models/journal_entry.dart';
import '../data/models/mental_wellness_models.dart';
import '../data/models/routine_item.dart';
import '../data/services/device_control_service.dart';
import '../data/services/storage_service.dart';
import 'journal_provider.dart';
import 'routine_provider.dart';

/// State coordinator for **Seren — Mental Wellness Support** (Emotional First Aid,
/// Ephemeral Writing, Comfort Kit, and Break the Cycle behavioral self-management).
///
/// Enforces Nestin's anti-guilt principles: zero days-clean counters, zero
/// abstinence streaks, zero failure logs, and zero automated clinical diagnoses.
class BreakTheCycleProvider extends ChangeNotifier {
  final StorageService _storageService;
  final DeviceControlServiceInterface _deviceControlService;
  final Uuid _uuid = const Uuid();

  late MentalWellnessStateData _data;
  FeltStateType? _activeFeltState;
  final Map<String, DateTime> _packageCooldownUntil = {};
  bool _disposed = false;

  BreakTheCycleProvider(
    this._storageService, {
    DeviceControlServiceInterface? deviceControlService,
  }) : _deviceControlService =
            deviceControlService ?? NativeDeviceControlService() {
    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  void _load() {
    _data = _storageService.loadMentalWellnessData();
    var seeded = false;
    var items = _data.comfortKitItems;
    var boundaries = _data.personalBoundaries;
    var templates = _data.messageTemplates;
    var goals = _data.wellbeingGoals;

    if (items.isEmpty) {
      items = ComfortKitItem.defaultStarterItems();
      seeded = true;
    }
    if (boundaries.isEmpty) {
      boundaries = PersonalBoundaryItem.defaultBoundaries();
      seeded = true;
    }
    if (templates.isEmpty) {
      templates = SupportMessageTemplate.defaultTemplates();
      seeded = true;
    }
    if (goals.isEmpty) {
      goals = PersonalWellbeingGoal.defaultStarterGoals();
      seeded = true;
    }
    if (seeded) {
      _data = _data.copyWith(
        comfortKitItems: items,
        personalBoundaries: boundaries,
        messageTemplates: templates,
        wellbeingGoals: goals,
      );
      _storageService.saveMentalWellnessData(_data);
    }
  }

  Future<void> _commit(MentalWellnessStateData next) async {
    _data = next;
    await _storageService.saveMentalWellnessData(_data);
    _safeNotify();
  }

  /// Reloads Mental Wellness state from storage after backup restore or resume.
  void reloadFromStorage() {
    _load();
    _safeNotify();
  }

  // --- Getters ---
  MentalWellnessStateData get data => _data;
  FeltStateType? get activeFeltState => _activeFeltState;

  List<ComfortKitItem> get comfortKitItems =>
      List.unmodifiable(_data.comfortKitItems);
  List<ComfortKitItem> get pinnedComfortKitItems => List.unmodifiable(
        _data.comfortKitItems.where((i) => i.isPinned).toList(),
      );

  List<PersonalCommitmentGoal> get commitments =>
      List.unmodifiable(_data.commitments);
  List<PersonalCommitmentGoal> get activeCommitments =>
      List.unmodifiable(_data.commitments.where((c) => c.isActive).toList());

  MindfulAppPauseConfig get mindfulAppPauseConfig =>
      _data.mindfulAppPauseConfig;

  List<TriggerReflectionEntry> get triggerReflections {
    final sorted = List<TriggerReflectionEntry>.from(_data.triggerReflections)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(sorted);
  }

  List<RecoveryReflectionEntry> get recoveryReflections {
    final sorted = List<RecoveryReflectionEntry>.from(_data.recoveryReflections)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(sorted);
  }

  List<PersonalBoundaryItem> get personalBoundaries =>
      List.unmodifiable(_data.personalBoundaries);

  RelapsePreventionPlan get relapsePreventionPlan =>
      _data.relapsePreventionPlan;

  QualitativeChangeProgress get qualitativeProgress =>
      _data.qualitativeProgress;

  List<TrustedContact> get trustedContacts =>
      List.unmodifiable(_data.trustedContacts);

  List<SupportMessageTemplate> get messageTemplates =>
      List.unmodifiable(_data.messageTemplates);

  PersonalSupportPlan get personalSupportPlan => _data.personalSupportPlan;

  List<String> get bookmarkedGuideIds =>
      List.unmodifiable(_data.bookmarkedGuideIds);

  List<PersonalInsightNote> get personalInsights {
    final sorted = List<PersonalInsightNote>.from(_data.personalInsights)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(sorted);
  }

  List<PersonalWellbeingGoal> get wellbeingGoals =>
      List.unmodifiable(_data.wellbeingGoals);

  // --- Emotional First Aid & Ephemeral Writing (`EFA-01`–`EFA-08`, `SU-04`, `SU-05`) ---

  void selectFeltState(FeltStateType? state) {
    _activeFeltState = state;
    _safeNotify();
  }

  Future<void> _incrementProgress({
    int reflections = 0,
    int strategies = 0,
    int goals = 0,
    int triggers = 0,
    int alternatives = 0,
    int grounding = 0,
  }) async {
    final p = _data.qualitativeProgress;
    await _commit(
      _data.copyWith(
        qualitativeProgress: p.copyWith(
          reflectionsCompletedCount:
              p.reflectionsCompletedCount + reflections,
          strategiesTriedCount: p.strategiesTriedCount + strategies,
          goalsShapedCount: p.goalsShapedCount + goals,
          triggersUnderstoodCount: p.triggersUnderstoodCount + triggers,
          alternativesExploredCount:
              p.alternativesExploredCount + alternatives,
          groundingSessionsCompletedCount:
              p.groundingSessionsCompletedCount + grounding,
        ),
      ),
    );
  }

  Future<void> recordGroundingCompleted() =>
      _incrementProgress(grounding: 1, strategies: 1);

  Future<void> recordBreathingBreakCompleted() =>
      _incrementProgress(strategies: 1);

  Future<void> recordEmotionalResetCompleted() =>
      _incrementProgress(strategies: 1);

  Future<void> recordSmallNextStepChosen(String stepId) =>
      _incrementProgress(strategies: 1);

  Future<void> addCustomEncouragementNote({
    required String title,
    required String subtitle,
  }) async {
    final cleanTitle = title.trim();
    final cleanSub = subtitle.trim();
    if (cleanTitle.isEmpty && cleanSub.isEmpty) return;

    final item = ComfortKitItem(
      id: _uuid.v4(),
      kind: ComfortKitItemKind.encouragementNote,
      title: cleanTitle.isNotEmpty ? cleanTitle : cleanSub,
      subtitle: cleanSub,
      isPinned: true,
      isCustomNote: true,
      createdAt: DateTime.now(),
    );
    await _commit(
      _data.copyWith(
        comfortKitItems: [item, ..._data.comfortKitItems],
      ),
    );
  }

  Future<void> toggleComfortKitPin(String id) async {
    final updated = _data.comfortKitItems
        .map((item) =>
            item.id == id ? item.copyWith(isPinned: !item.isPinned) : item)
        .toList();
    await _commit(_data.copyWith(comfortKitItems: updated));
  }

  Future<void> deleteComfortKitItem(String id) async {
    final updated =
        _data.comfortKitItems.where((item) => item.id != id).toList();
    await _commit(_data.copyWith(comfortKitItems: updated));
  }

  /// Adds or updates a pinned Comfort Kit item (`EFA-07` Level 2 customization).
  Future<void> addComfortKitItem(ComfortKitItem item) async {
    final existingIdx =
        _data.comfortKitItems.indexWhere((i) => i.id == item.id);
    final updated = List<ComfortKitItem>.from(_data.comfortKitItems);
    final nextItem = item.copyWith(isPinned: true);
    if (existingIdx == -1) {
      updated.insert(0, nextItem);
    } else {
      updated[existingIdx] = nextItem;
    }
    final p = _data.qualitativeProgress;
    await _commit(
      _data.copyWith(
        comfortKitItems: updated,
        qualitativeProgress:
            existingIdx == -1 ? p.copyWith(strategiesTriedCount: p.strategiesTriedCount + 1) : p,
      ),
    );
  }

  /// Promotes [id] to the front of the Comfort Kit shelf for 1-tap shortcut priority.
  Future<void> promoteComfortKitItemToTop(String id) async {
    final idx = _data.comfortKitItems.indexWhere((i) => i.id == id);
    if (idx <= 0) return;
    final updated = List<ComfortKitItem>.from(_data.comfortKitItems);
    final target = updated.removeAt(idx).copyWith(isPinned: true);
    updated.insert(0, target);
    await _commit(_data.copyWith(comfortKitItems: updated));
  }

  /// Persists *Let It Out* (`SU-04`) or *Unsent Letters* (`SU-05`) privately inside
  /// Echo's `JournalProvider` (`isPrivate: true`) instead of duplicating diary storage.
  Future<JournalEntry> saveEphemeralWritingToEcho({
    required JournalProvider journalProvider,
    required EphemeralWritingMode mode,
    required String title,
    required String content,
  }) async {
    final now = DateTime.now();
    final entry = JournalEntry(
      id: _uuid.v4(),
      title: title.trim().isNotEmpty ? title.trim() : mode.journalTag,
      content: content.trim(),
      date: now,
      mood: JournalMood.neutral,
      tags: ['Seren', mode.journalTag],
      isPrivate: true,
      createdAt: now,
      updatedAt: now,
    );
    await journalProvider.addJournalEntry(entry);
    await _incrementProgress(reflections: 1);
    return entry;
  }

  /// Ephemeral "Let It Go" release (`SU-04`, `SU-05`): clears composer without
  /// writing any personal writing to disk.
  void letItGoWithoutSaving() {
    // Intentionally performs zero storage writes so user thoughts vanish cleanly.
  }

  // --- Break the Cycle & Mindful App Pause (`BTC-01`–`BTC-11`) ---

  Future<void> saveCommitment(PersonalCommitmentGoal goal) async {
    final existingIdx = _data.commitments.indexWhere((c) => c.id == goal.id);
    final updated = List<PersonalCommitmentGoal>.from(_data.commitments);
    final isNew = existingIdx == -1;
    if (isNew) {
      updated.insert(0, goal);
    } else {
      updated[existingIdx] = goal.copyWith(updatedAt: DateTime.now());
    }
    final p = _data.qualitativeProgress;
    await _commit(
      _data.copyWith(
        commitments: updated,
        qualitativeProgress:
            isNew ? p.copyWith(goalsShapedCount: p.goalsShapedCount + 1) : p,
      ),
    );
  }

  Future<void> toggleCommitmentActive(String id) async {
    final updated = _data.commitments
        .map((c) => c.id == id
            ? c.copyWith(isActive: !c.isActive, updatedAt: DateTime.now())
            : c)
        .toList();
    await _commit(_data.copyWith(commitments: updated));
  }

  Future<void> deleteCommitment(String id) async {
    final updated = _data.commitments.where((c) => c.id != id).toList();
    await _commit(_data.copyWith(commitments: updated));
  }

  Future<void> updateMindfulAppPauseConfig(
      MindfulAppPauseConfig config) async {
    await _commit(_data.copyWith(mindfulAppPauseConfig: config));
  }

  Future<void> snoozeMindfulAppPause(
    Duration duration, {
    DateTime? now,
  }) async {
    final until = (now ?? DateTime.now()).add(duration);
    await _commit(
      _data.copyWith(
        mindfulAppPauseConfig:
            _data.mindfulAppPauseConfig.copyWith(snoozedUntil: until),
      ),
    );
  }

  Future<void> clearMindfulAppPauseSnooze() async {
    await _commit(
      _data.copyWith(
        mindfulAppPauseConfig:
            _data.mindfulAppPauseConfig.copyWith(clearSnoozedUntil: true),
      ),
    );
  }

  /// Evaluates whether [packageName] should trigger the calm `BTC-02`
  /// Mindful App Pause intention check at [now].
  bool shouldTriggerMindfulPauseForPackage(
    String? packageName, {
    DateTime? now,
  }) {
    if (packageName == null || packageName.isEmpty) return false;
    final cfg = _data.mindfulAppPauseConfig;
    if (!cfg.isEnabled) return false;
    if (!cfg.monitoredPackages.contains(packageName)) return false;

    final checkNow = now ?? DateTime.now();
    if (cfg.isSnoozedAt(checkNow)) return false;
    if (cfg.vulnerableHoursOnly && !cfg.isWithinVulnerableWindow(checkNow)) {
      return false;
    }

    final cooldownUntil = _packageCooldownUntil[packageName];
    if (cooldownUntil != null && cooldownUntil.isAfter(checkNow)) {
      return false;
    }
    return true;
  }

  /// Checks the device foreground app via `DeviceControlServiceInterface`
  /// without inspecting URLs or in-app content, returning the matching package
  /// if `BTC-02` Mindful App Pause should open.
  Future<String?> checkForegroundAppForMindfulPause({DateTime? now}) async {
    if (!_data.mindfulAppPauseConfig.isEnabled) return null;
    final pkg = await _deviceControlService.getCurrentForegroundApp();
    if (shouldTriggerMindfulPauseForPackage(pkg, now: now)) {
      return pkg;
    }
    return null;
  }

  /// Grants calm cooldown grace when the user chooses *"I have a clear purpose
  /// — Continue"* with zero penalty, zero failure counter, and zero streak reset.
  void grantMindfulPauseClearPurposeContinue(
    String packageName, {
    DateTime? now,
  }) {
    if (packageName.isEmpty) return;
    final checkNow = now ?? DateTime.now();
    _packageCooldownUntil[packageName] = checkNow.add(
      Duration(minutes: _data.mindfulAppPauseConfig.cooldownGraceMinutes),
    );
  }

  DateTime? cooldownUntilForPackage(String packageName) =>
      _packageCooldownUntil[packageName];

  Future<void> recordMindfulPauseStepBack(String packageName) =>
      _incrementProgress(strategies: 1);

  Future<void> recordUrgeSurfingCompleted() =>
      _incrementProgress(strategies: 1);

  Future<void> recordEnvironmentResetTried(String resetId) =>
      _incrementProgress(strategies: 1);

  Future<void> recordHealthyAlternativeExplored(String altId) =>
      _incrementProgress(alternatives: 1);

  Future<void> addTriggerReflection(
    TriggerReflectionEntry entry, {
    JournalProvider? journalProvider,
    bool saveToEcho = false,
  }) async {
    var persisted = entry;
    if (saveToEcho && journalProvider != null) {
      final echoId = _uuid.v4();
      final lines = <String>[
        if (entry.locationLabel.trim().isNotEmpty) entry.locationLabel.trim(),
        if (entry.currentActivity.trim().isNotEmpty)
          entry.currentActivity.trim(),
        if (entry.emotionalState.trim().isNotEmpty) entry.emotionalState.trim(),
        if (entry.whatHappenedBefore.trim().isNotEmpty)
          entry.whatHappenedBefore.trim(),
        if (entry.whatINeeded.trim().isNotEmpty) entry.whatINeeded.trim(),
        if (entry.tryDifferentlyNextTime.trim().isNotEmpty)
          entry.tryDifferentlyNextTime.trim(),
      ].join('\n');
      await journalProvider.addJournalEntry(
        JournalEntry(
          id: echoId,
          title: entry.currentActivity.trim().isNotEmpty
              ? entry.currentActivity.trim()
              : 'Break the Cycle Reflection',
          content: lines,
          date: entry.createdAt,
          mood: JournalMood.neutral,
          tags: const ['Seren', 'BreakTheCycle', 'TriggerReflection'],
          isPrivate: true,
          createdAt: entry.createdAt,
          updatedAt: entry.createdAt,
        ),
      );
      persisted = TriggerReflectionEntry(
        id: entry.id,
        commitmentId: entry.commitmentId,
        createdAt: entry.createdAt,
        locationLabel: entry.locationLabel,
        currentActivity: entry.currentActivity,
        emotionalState: entry.emotionalState,
        environmentNote: entry.environmentNote,
        whatHappenedBefore: entry.whatHappenedBefore,
        whatINeeded: entry.whatINeeded,
        tryDifferentlyNextTime: entry.tryDifferentlyNextTime,
        savedToEchoEntryId: echoId,
      );
    }

    final p = _data.qualitativeProgress;
    await _commit(
      _data.copyWith(
        triggerReflections: [persisted, ..._data.triggerReflections],
        qualitativeProgress: p.copyWith(
          reflectionsCompletedCount: p.reflectionsCompletedCount + 1,
          triggersUnderstoodCount: p.triggersUnderstoodCount + 1,
        ),
      ),
    );
  }

  /// Logs a shame-free voluntary post-setback reflection (`BTC-09`).
  /// Never resets or decrements any qualitative progress indicators.
  Future<void> addRecoveryReflection(
    RecoveryReflectionEntry entry, {
    JournalProvider? journalProvider,
    bool saveToEcho = false,
  }) async {
    var persisted = entry;
    if (saveToEcho && journalProvider != null) {
      final echoId = _uuid.v4();
      final lines = <String>[
        if (entry.whatHappened.trim().isNotEmpty) entry.whatHappened.trim(),
        if (entry.underlyingNeedOrFeeling.trim().isNotEmpty)
          entry.underlyingNeedOrFeeling.trim(),
        if (entry.selfCompassionNote.trim().isNotEmpty)
          entry.selfCompassionNote.trim(),
        if (entry.nextSmallAdjustment.trim().isNotEmpty)
          entry.nextSmallAdjustment.trim(),
      ].join('\n');
      await journalProvider.addJournalEntry(
        JournalEntry(
          id: echoId,
          title: 'Compassionate Reset',
          content: lines,
          date: entry.createdAt,
          mood: JournalMood.neutral,
          tags: const ['Seren', 'BreakTheCycle', 'RecoveryReflection'],
          isPrivate: true,
          createdAt: entry.createdAt,
          updatedAt: entry.createdAt,
        ),
      );
      persisted = RecoveryReflectionEntry(
        id: entry.id,
        commitmentId: entry.commitmentId,
        createdAt: entry.createdAt,
        whatHappened: entry.whatHappened,
        underlyingNeedOrFeeling: entry.underlyingNeedOrFeeling,
        selfCompassionNote: entry.selfCompassionNote,
        nextSmallAdjustment: entry.nextSmallAdjustment,
        savedToEchoEntryId: echoId,
      );
    }

    final p = _data.qualitativeProgress;
    await _commit(
      _data.copyWith(
        recoveryReflections: [persisted, ..._data.recoveryReflections],
        qualitativeProgress: p.copyWith(
          reflectionsCompletedCount: p.reflectionsCompletedCount + 1,
        ),
      ),
    );
  }

  Future<void> addPersonalBoundary(PersonalBoundaryItem item) async {
    final p = _data.qualitativeProgress;
    await _commit(
      _data.copyWith(
        personalBoundaries: [item, ..._data.personalBoundaries],
        qualitativeProgress:
            p.copyWith(goalsShapedCount: p.goalsShapedCount + 1),
      ),
    );
  }

  Future<void> togglePersonalBoundary(String id) async {
    final updated = _data.personalBoundaries
        .map((b) => b.id == id ? b.copyWith(isActive: !b.isActive) : b)
        .toList();
    await _commit(_data.copyWith(personalBoundaries: updated));
  }

  Future<void> deletePersonalBoundary(String id) async {
    final updated =
        _data.personalBoundaries.where((b) => b.id != id).toList();
    await _commit(_data.copyWith(personalBoundaries: updated));
  }

  Future<void> saveRelapsePreventionPlan(RelapsePreventionPlan plan) async {
    final nextPlan = plan.copyWith(updatedAt: DateTime.now());
    final p = _data.qualitativeProgress;
    await _commit(
      _data.copyWith(
        relapsePreventionPlan: nextPlan,
        qualitativeProgress:
            p.copyWith(goalsShapedCount: p.goalsShapedCount + 1),
      ),
    );
  }

  // --- Level 2: Trusted Contacts, Templates, Support Plan, Voice Journal & Rituals ---

  Future<void> saveTrustedContact(TrustedContact contact) async {
    final idx = _data.trustedContacts.indexWhere((c) => c.id == contact.id);
    final updated = List<TrustedContact>.from(_data.trustedContacts);
    final isNew = idx == -1;
    if (isNew) {
      updated.add(contact);
    } else {
      updated[idx] = contact;
    }
    final p = _data.qualitativeProgress;
    await _commit(
      _data.copyWith(
        trustedContacts: updated,
        qualitativeProgress:
            isNew ? p.copyWith(goalsShapedCount: p.goalsShapedCount + 1) : p,
      ),
    );
  }

  Future<void> deleteTrustedContact(String id) async {
    final updated = _data.trustedContacts.where((c) => c.id != id).toList();
    await _commit(_data.copyWith(trustedContacts: updated));
  }

  Future<void> saveMessageTemplate(SupportMessageTemplate template) async {
    final idx = _data.messageTemplates.indexWhere((t) => t.id == template.id);
    final updated = List<SupportMessageTemplate>.from(_data.messageTemplates);
    if (idx == -1) {
      updated.insert(0, template);
    } else {
      updated[idx] = template;
    }
    await _commit(_data.copyWith(messageTemplates: updated));
  }

  Future<void> deleteMessageTemplate(String id) async {
    final updated = _data.messageTemplates.where((t) => t.id != id).toList();
    await _commit(_data.copyWith(messageTemplates: updated));
  }

  Future<void> savePersonalSupportPlan(PersonalSupportPlan plan) async {
    final nextPlan = plan.copyWith(updatedAt: DateTime.now());
    final p = _data.qualitativeProgress;
    await _commit(
      _data.copyWith(
        personalSupportPlan: nextPlan,
        qualitativeProgress:
            p.copyWith(goalsShapedCount: p.goalsShapedCount + 1),
      ),
    );
  }

  /// Builds a native SMS, WhatsApp, or phone call URI for a Trusted Contact (`GS-02`).
  String composeContactUri({
    required TrustedContact contact,
    required String messageBody,
    TrustedContactChannel? channelOverride,
  }) {
    final channel = channelOverride ?? contact.preferredChannel;
    final cleanPhone = contact.phoneOrHandle.trim();
    switch (channel) {
      case TrustedContactChannel.call:
        return 'tel:$cleanPhone';
      case TrustedContactChannel.whatsapp:
        final digits = cleanPhone.replaceAll(RegExp(r'[^0-9]'), '');
        final encoded = Uri.encodeComponent(messageBody);
        return digits.isNotEmpty
            ? 'https://wa.me/$digits?text=$encoded'
            : 'https://wa.me/?text=$encoded';
      case TrustedContactChannel.sms:
        final encoded = Uri.encodeComponent(messageBody);
        return 'sms:$cleanPhone?body=$encoded';
    }
  }

  /// Captures a spoken voice reflection / memo inside Echo's private diary (`SU-02`).
  Future<JournalEntry> saveVoiceReflectionToEcho({
    required JournalProvider journalProvider,
    required String title,
    required String transcriptOrNotes,
    required int durationSeconds,
  }) async {
    final now = DateTime.now();
    final safeSecs = durationSeconds < 0 ? 0 : durationSeconds;
    final mm = (safeSecs ~/ 60).toString().padLeft(2, '0');
    final ss = (safeSecs % 60).toString().padLeft(2, '0');
    final notes = transcriptOrNotes.trim();
    final body = notes.isNotEmpty
        ? '[🎙️ Voice Memo • $mm:$ss]\n$notes'
        : '[🎙️ Voice Memo • $mm:$ss]';
    final entry = JournalEntry(
      id: _uuid.v4(),
      title: title.trim().isNotEmpty ? title.trim() : 'Voice Reflection ($mm:$ss)',
      content: body,
      date: now,
      mood: JournalMood.neutral,
      tags: const ['Seren', 'VoiceMemo', 'AudioMemo'],
      isPrivate: true,
      createdAt: now,
      updatedAt: now,
    );
    await journalProvider.addJournalEntry(entry);
    await _incrementProgress(reflections: 1);
    return entry;
  }

  /// Links a gentle Morning or Evening calm ritual into Roo's `RoutineProvider` (`HL-03`).
  Future<RoutineItem> linkCalmRitualToRoo({
    required RoutineProvider routineProvider,
    required bool isMorning,
    required String title,
    required String description,
    required List<String> steps,
  }) async {
    final routine = RoutineItem(
      id: _uuid.v4(),
      title: title,
      description: description,
      type: isMorning ? RoutineType.morning : RoutineType.evening,
      steps: steps,
      createdAt: DateTime.now(),
    );
    await routineProvider.addRoutine(routine);
    await _incrementProgress(strategies: 1);
    return routine;
  }

  // --- Level 3: Offline Educational Library, Guided Reflection, Personal Insights & Well-being Goals ---

  Future<void> toggleGuideBookmark(String guideId) async {
    final updated = List<String>.from(_data.bookmarkedGuideIds);
    if (updated.contains(guideId)) {
      updated.remove(guideId);
    } else {
      updated.insert(0, guideId);
    }
    await _commit(_data.copyWith(bookmarkedGuideIds: updated));
  }

  /// Saves an optional guided reflection (`SU-03`, `SU-06`, `SU-07`) into Echo's
  /// private diary without adding mandatory streaks or diagnostic labels.
  Future<JournalEntry> saveGuidedReflectionToEcho({
    required JournalProvider journalProvider,
    required String promptTitle,
    required String reflectionText,
    String? guideId,
    JournalMood mood = JournalMood.neutral,
  }) async {
    final now = DateTime.now();
    final tags = <String>[
      'Seren',
      'GuidedReflection',
      if (guideId != null && guideId.trim().isNotEmpty) guideId.trim(),
    ];
    final entry = JournalEntry(
      id: _uuid.v4(),
      title: promptTitle.trim(),
      content: reflectionText.trim(),
      date: now,
      mood: mood,
      tags: tags,
      isPrivate: true,
      createdAt: now,
      updatedAt: now,
    );
    await journalProvider.addJournalEntry(entry);
    await _incrementProgress(reflections: 1);
    return entry;
  }

  Future<void> addPersonalInsightNote({
    required String title,
    required String observation,
    String? relatedGuideId,
  }) async {
    final note = PersonalInsightNote(
      id: _uuid.v4(),
      title: title.trim(),
      observation: observation.trim(),
      relatedGuideId: relatedGuideId,
      createdAt: DateTime.now(),
    );
    await _commit(
      _data.copyWith(
        personalInsights: [note, ..._data.personalInsights],
      ),
    );
    await _incrementProgress(reflections: 1);
  }

  Future<void> deletePersonalInsightNote(String id) async {
    final updated = _data.personalInsights.where((n) => n.id != id).toList();
    await _commit(_data.copyWith(personalInsights: updated));
  }

  Future<void> addWellbeingGoal({
    required String title,
    String categoryKey = 'mw_l3_goal_cat_balance',
  }) async {
    final clean = title.trim();
    if (clean.isEmpty) return;
    final goal = PersonalWellbeingGoal(
      id: _uuid.v4(),
      title: clean,
      categoryKey: categoryKey,
      isActive: true,
      createdAt: DateTime.now(),
    );
    await _commit(
      _data.copyWith(
        wellbeingGoals: [goal, ..._data.wellbeingGoals],
      ),
    );
    await _incrementProgress(goals: 1);
  }

  Future<void> toggleWellbeingGoal(String id) async {
    final updated = _data.wellbeingGoals
        .map((g) => g.id == id ? g.copyWith(isActive: !g.isActive) : g)
        .toList();
    await _commit(_data.copyWith(wellbeingGoals: updated));
  }

  Future<void> deleteWellbeingGoal(String id) async {
    final updated = _data.wellbeingGoals.where((g) => g.id != id).toList();
    await _commit(_data.copyWith(wellbeingGoals: updated));
  }

  // --- Level 4: Locale-Aware Verified Crisis & Support Directory (`GS-04`, `GS-05`) ---

  List<CrisisResourceEntry> crisisResourcesForRegion(
    SupportRegionFilter region,
  ) {
    final source = _data.remoteCrisisOverrides.isNotEmpty
        ? _data.remoteCrisisOverrides
        : CrisisAndSupportCatalog.defaultCrisisResources;
    if (region == SupportRegionFilter.global) {
      return List.unmodifiable(
        source.where((e) => e.region == SupportRegionFilter.global),
      );
    }
    return List.unmodifiable(
      source.where(
        (e) => e.region == region || e.region == SupportRegionFilter.global,
      ),
    );
  }

  List<SupportDirectoryEntry> supportDirectoryForRegion(
    SupportRegionFilter region,
  ) {
    final source = _data.remoteDirectoryOverrides.isNotEmpty
        ? _data.remoteDirectoryOverrides
        : CrisisAndSupportCatalog.defaultDirectoryEntries;
    if (region == SupportRegionFilter.global) {
      return List.unmodifiable(
        source.where((e) => e.region == SupportRegionFilter.global),
      );
    }
    return List.unmodifiable(
      source.where(
        (e) => e.region == region || e.region == SupportRegionFilter.global,
      ),
    );
  }

  Future<bool> applyBackendDirectoryPayload(Map<String, dynamic> payload) async {
    final parsed = CrisisAndSupportCatalog.fromBackendPayload(payload);
    if (parsed.crisisResources.isEmpty && parsed.directoryEntries.isEmpty) {
      return false;
    }
    await _commit(
      _data.copyWith(
        remoteCrisisOverrides: parsed.crisisResources.isNotEmpty
            ? parsed.crisisResources
            : _data.remoteCrisisOverrides,
        remoteDirectoryOverrides: parsed.directoryEntries.isNotEmpty
            ? parsed.directoryEntries
            : _data.remoteDirectoryOverrides,
      ),
    );
    return true;
  }

  // --- Sensitive Data Controls: Granular Deletion & Passphrase Encryption ---

  Future<void> deleteTriggerReflection(String id) async {
    final updated =
        _data.triggerReflections.where((t) => t.id != id).toList();
    await _commit(_data.copyWith(triggerReflections: updated));
  }

  Future<void> deleteRecoveryReflection(String id) async {
    final updated =
        _data.recoveryReflections.where((r) => r.id != id).toList();
    await _commit(_data.copyWith(recoveryReflections: updated));
  }

  Future<void> clearPersonalSupportPlan() async {
    await _commit(
      _data.copyWith(personalSupportPlan: const PersonalSupportPlan()),
    );
  }

  Future<void> clearRelapsePreventionPlan() async {
    await _commit(
      _data.copyWith(relapsePreventionPlan: const RelapsePreventionPlan()),
    );
  }

  /// Clears user-authored private records while re-seeding non-identifying starters.
  Future<void> resetAllMentalWellnessData() async {
    final fresh = MentalWellnessStateData(
      comfortKitItems: ComfortKitItem.defaultStarterItems(),
      personalBoundaries: PersonalBoundaryItem.defaultBoundaries(),
      messageTemplates: SupportMessageTemplate.defaultTemplates(),
      wellbeingGoals: PersonalWellbeingGoal.defaultStarterGoals(),
    );
    await _commit(fresh);
  }

  String exportEncryptedBackup(String passphrase) {
    final payload = jsonEncode(_data.toJson());
    return MentalWellnessCryptoHelper.encryptJsonPayload(
      plainJson: payload,
      passphrase: passphrase,
    );
  }

  Future<bool> importEncryptedBackup(
    String encryptedEnvelopeJson,
    String passphrase,
  ) async {
    final decrypted = MentalWellnessCryptoHelper.decryptJsonPayload(
      encryptedEnvelopeJson: encryptedEnvelopeJson,
      passphrase: passphrase,
    );
    if (decrypted == null) return false;
    try {
      final decoded = jsonDecode(decrypted);
      if (decoded is! Map) return false;
      final restored = MentalWellnessStateData.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      await _commit(restored);
      return true;
    } catch (_) {
      return false;
    }
  }
}
