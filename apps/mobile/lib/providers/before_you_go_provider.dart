import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';
import '../data/models/before_you_go.dart';
import '../data/models/calendar_event.dart';
import '../data/services/notification_service.dart';
import '../data/services/storage_service.dart';

class BeforeYouGoProvider extends ChangeNotifier {
  final StorageService _storageService;
  final NotificationService _notificationService;

  static const int notificationBaseId = DepartureSnooze.notificationBaseId;
  static const int testNotificationId = 79501;
  static const String payloadPrefix = DepartureSnooze.payloadPrefix;

  List<DeparturePreset> _presets = [];
  List<DepartureEvent> _events = [];
  List<DepartureSnooze> _snoozes = [];
  late String _activePresetId;
  int _lastScheduledCount = 0;
  StreamSubscription<NotificationResponse>? _notifActionSub;

  BeforeYouGoProvider(
    this._storageService,
    this._notificationService,
  ) {
    _loadFromStorage();
    _notifActionSub =
        _notificationService.actionResponseStream.listen(_onNotificationAction);
  }

  @override
  void dispose() {
    _notifActionSub?.cancel();
    super.dispose();
  }

  List<DeparturePreset> get presets => List.unmodifiable(_presets);
  List<DepartureEvent> get events => List.unmodifiable(_events);
  List<DepartureSnooze> get snoozes => List.unmodifiable(_snoozes);
  String get activePresetId => _activePresetId;

  List<DepartureSnooze> get activeSnoozes {
    final now = DateTime.now();
    return List.unmodifiable(_snoozes.where((s) => s.isActiveAt(now)));
  }

  DepartureSnooze? snoozeForEvent(String eventId, [DateTime? date]) {
    final now = date ?? DateTime.now();
    final todayKey = DepartureEvent.formatDateKey(now);
    for (final s in _snoozes) {
      if (s.eventId == eventId && (s.dateKey == todayKey || s.isActiveAt(now))) {
        return s;
      }
    }
    return null;
  }

  /// Returns an active snooze for UI summary badges, prioritizing the next
  /// scheduled departure or current active preset.
  DepartureSnooze? activeSnoozeForNext([DateTime? nowOverride]) {
    final now = nowOverride ?? DateTime.now();
    final next = getNextScheduledDeparture(nowOverride: now);
    if (next != null) {
      final match = snoozeForEvent(next.id, now);
      if (match != null && match.isActiveAt(now)) return match;
    }
    final activeSynthetic = snoozeForEvent(
      DepartureSnooze.syntheticEventIdForPreset(_activePresetId),
      now,
    );
    if (activeSynthetic != null && activeSynthetic.isActiveAt(now)) {
      return activeSynthetic;
    }
    for (final s in _snoozes) {
      if (s.isActiveAt(now)) return s;
    }
    return null;
  }

  @visibleForTesting
  int get lastScheduledNotificationsCount => _lastScheduledCount;

  DeparturePreset get activePreset {
    for (final p in _presets) {
      if (p.id == _activePresetId) return p;
    }
    return _presets.first;
  }

  DeparturePreset? findPresetById(String? id) {
    if (id == null) return null;
    for (final p in _presets) {
      if (p.id == id) return p;
    }
    return null;
  }

  DepartureEvent? findEventById(String? id) {
    if (id == null) return null;
    for (final e in _events) {
      if (e.id == id) return e;
    }
    return null;
  }

  DepartureEvent? findEventByLinkedCalendarId(String calendarEventId) {
    for (final e in _events) {
      if (e.linkedCalendarEventId == calendarEventId) return e;
    }
    return null;
  }

  List<DepartureEvent> upcomingEvents({DateTime? nowOverride}) {
    final now = nowOverride ?? DateTime.now();
    final withNext = <MapEntry<DepartureEvent, DateTime?>>[];
    for (final e in _events) {
      withNext.add(MapEntry(e, e.nextDepartureAfter(now)));
    }
    withNext.sort((a, b) {
      if (a.value == null && b.value == null) return a.key.hour.compareTo(b.key.hour);
      if (a.value == null) return 1;
      if (b.value == null) return -1;
      return a.value!.compareTo(b.value!);
    });
    return withNext.map((e) => e.key).toList();
  }

  DepartureEvent? getNextScheduledDeparture({DateTime? nowOverride}) {
    final now = nowOverride ?? DateTime.now();
    DepartureEvent? best;
    DateTime? bestDt;
    for (final e in _events) {
      if (!e.isEnabled) continue;
      final next = e.nextDepartureAfter(now);
      if (next == null) continue;
      if (bestDt == null || next.isBefore(bestDt)) {
        bestDt = next;
        best = e;
      }
    }
    return best;
  }

  static int notificationIdFor(String eventId, int dayOffset) =>
      DepartureSnooze.regularNotificationId(eventId, dayOffset);

  static String buildPayload(String eventId, String presetId) =>
      DepartureSnooze.buildPayload(eventId, presetId);

  static ({String eventId, String presetId})? parsePayload(String? raw) =>
      DepartureSnooze.parsePayload(raw);

  void _loadFromStorage() {
    final now = DateTime.now();
    final todayKey = DepartureEvent.formatDateKey(now);

    _presets = _storageService.loadDeparturePresets();
    if (_presets.isEmpty) {
      _presets = DeparturePreset.seedDefaults(now);
      unawaited(_storageService.saveDeparturePresets(_presets));
    }

    _events = _storageService.loadDepartureEvents();
    _snoozes = _storageService
        .loadDepartureSnoozes()
        .where((s) => s.dateKey == todayKey || s.isActiveAt(now))
        .toList();

    final savedActive = _storageService.loadActiveDeparturePresetId();
    if (savedActive != null && _presets.any((p) => p.id == savedActive)) {
      _activePresetId = savedActive;
    } else {
      _activePresetId = _presets.first.id;
      unawaited(_storageService.saveActiveDeparturePresetId(_activePresetId));
    }

    unawaited(rescheduleAllNotifications());
  }

  void _onNotificationAction(NotificationResponse response) {
    handleNotificationResponse(response);
  }

  /// Handles Android/Darwin notification shade inline actions:
  /// checking off the full preset ("Mark All Ready") or snoozing +5m ("Snooze 5m").
  Future<bool> handleNotificationResponse(
    NotificationResponse response, {
    DateTime? nowOverride,
  }) async {
    final actionId = response.actionId;
    if (actionId != NotificationService.actionDepartureMarkAllReady &&
        actionId != NotificationService.actionDepartureSnooze5m) {
      return false;
    }

    final parsed = DepartureSnooze.parseActionPayload(
      response.payload,
      fallbackPresetId: _activePresetId,
    );
    if (parsed == null) return false;

    if (actionId == NotificationService.actionDepartureMarkAllReady) {
      final result = await markPresetAllReady(
        parsed.presetId,
        eventId: parsed.eventId,
        dismissNotificationId: response.id,
        nowOverride: nowOverride,
      );
      return result != null;
    }

    final entry = await snoozeDeparture(
      eventId: parsed.eventId,
      presetId: parsed.presetId,
      dismissNotificationId: response.id,
      nowOverride: nowOverride,
    );
    return entry != null;
  }

  Future<void> reloadFromStorage() async {
    await _storageService.reloadPrefs();
    _loadFromStorage();
    notifyListeners();
  }

  // --- Preset & Checklist Item Management ---

  Future<void> selectActivePreset(String presetId) async {
    if (!_presets.any((p) => p.id == presetId)) return;
    _activePresetId = presetId;
    await _storageService.saveActiveDeparturePresetId(presetId);
    notifyListeners();
  }

  Future<DeparturePreset> createPreset({
    required String name,
    int? iconCodePoint,
    int? colorValue,
    List<DepartureChecklistItem>? items,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Preset name cannot be empty.');
    }
    final now = DateTime.now();
    final preset = DeparturePreset(
      id: 'preset_${const Uuid().v4().substring(0, 8)}',
      name: trimmed,
      iconCodePoint:
          iconCodePoint ?? Icons.backpack_outlined.codePoint,
      colorValue: colorValue ?? 0xFF3B82F6,
      items: items ??
          [
            DepartureChecklistItem(
              id: 'item_${const Uuid().v4().substring(0, 8)}',
              label: 'Keys & Wallet',
              isEssential: true,
            ),
            DepartureChecklistItem(
              id: 'item_${const Uuid().v4().substring(0, 8)}',
              label: 'Phone & Charger',
              isEssential: true,
            ),
          ],
      isDefault: false,
      createdAt: now,
      updatedAt: now,
    );

    _presets.add(preset);
    _activePresetId = preset.id;
    await _storageService.saveDeparturePresets(_presets);
    await _storageService.saveActiveDeparturePresetId(_activePresetId);
    notifyListeners();
    return preset;
  }

  Future<void> updatePreset(DeparturePreset updated) async {
    final idx = _presets.indexWhere((p) => p.id == updated.id);
    if (idx == -1) return;
    _presets[idx] = updated.copyWith(updatedAt: DateTime.now());
    await _storageService.saveDeparturePresets(_presets);
    await rescheduleAllNotifications();
    notifyListeners();
  }

  Future<bool> deletePreset(String presetId) async {
    if (_presets.length <= 1) return false;
    final idx = _presets.indexWhere((p) => p.id == presetId);
    if (idx == -1) return false;

    _presets.removeAt(idx);
    final fallbackId = _presets.first.id;
    if (_activePresetId == presetId) {
      _activePresetId = fallbackId;
      await _storageService.saveActiveDeparturePresetId(_activePresetId);
    }

    var changedEvents = false;
    for (var i = 0; i < _events.length; i++) {
      if (_events[i].presetId == presetId) {
        _events[i] = _events[i].copyWith(
          presetId: fallbackId,
          updatedAt: DateTime.now(),
        );
        changedEvents = true;
      }
    }

    await _storageService.saveDeparturePresets(_presets);
    if (changedEvents) {
      await _storageService.saveDepartureEvents(_events);
      await rescheduleAllNotifications();
    }
    notifyListeners();
    return true;
  }

  Future<void> toggleItem(String presetId, String itemId) async {
    final pIdx = _presets.indexWhere((p) => p.id == presetId);
    if (pIdx == -1) return;
    final now = DateTime.now();
    final preset = _presets[pIdx];
    final items = List<DepartureChecklistItem>.from(preset.items);
    final iIdx = items.indexWhere((i) => i.id == itemId);
    if (iIdx == -1) return;
    items[iIdx] = items[iIdx].copyWith(isChecked: !items[iIdx].isChecked);

    final updatedPreset = preset.copyWith(items: items, updatedAt: now);
    _presets[pIdx] = updatedPreset;

    final todayKey = DepartureEvent.formatDateKey(now);
    var eventsModified = false;
    if (!updatedPreset.allChecked) {
      for (var i = 0; i < _events.length; i++) {
        if (_events[i].presetId == presetId &&
            _events[i].lastCompletedDateKey == todayKey) {
          _events[i] = _events[i].copyWith(clearLastCompletedDateKey: true);
          eventsModified = true;
        }
      }
    } else {
      await _clearSnoozesForPreset(presetId, now);
    }

    await _storageService.saveDeparturePresets(_presets);
    if (eventsModified) {
      await _storageService.saveDepartureEvents(_events);
    }
    await rescheduleAllNotifications(nowOverride: now);
    notifyListeners();
  }

  Future<void> addItem(
    String presetId,
    String label, {
    bool isEssential = false,
  }) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    final pIdx = _presets.indexWhere((p) => p.id == presetId);
    if (pIdx == -1) return;
    final preset = _presets[pIdx];
    final items = List<DepartureChecklistItem>.from(preset.items)
      ..add(
        DepartureChecklistItem(
          id: 'item_${const Uuid().v4().substring(0, 8)}',
          label: trimmed,
          isEssential: isEssential,
        ),
      );
    _presets[pIdx] = preset.copyWith(items: items, updatedAt: DateTime.now());
    await _storageService.saveDeparturePresets(_presets);
    await rescheduleAllNotifications();
    notifyListeners();
  }

  Future<void> updateItem(String presetId, DepartureChecklistItem updated) async {
    final pIdx = _presets.indexWhere((p) => p.id == presetId);
    if (pIdx == -1) return;
    final preset = _presets[pIdx];
    final items = List<DepartureChecklistItem>.from(preset.items);
    final iIdx = items.indexWhere((i) => i.id == updated.id);
    if (iIdx == -1) return;
    items[iIdx] = updated;
    _presets[pIdx] = preset.copyWith(items: items, updatedAt: DateTime.now());
    await _storageService.saveDeparturePresets(_presets);
    await rescheduleAllNotifications();
    notifyListeners();
  }

  Future<void> removeItem(String presetId, String itemId) async {
    final pIdx = _presets.indexWhere((p) => p.id == presetId);
    if (pIdx == -1) return;
    final preset = _presets[pIdx];
    final items = preset.items.where((i) => i.id != itemId).toList();
    _presets[pIdx] = preset.copyWith(items: items, updatedAt: DateTime.now());
    await _storageService.saveDeparturePresets(_presets);
    await rescheduleAllNotifications();
    notifyListeners();
  }

  Future<void> reorderItems(
    String presetId,
    int oldIndex,
    int newIndex, {
    bool adjustForRemoval = true,
  }) async {
    final pIdx = _presets.indexWhere((p) => p.id == presetId);
    if (pIdx == -1) return;
    final preset = _presets[pIdx];
    final items = List<DepartureChecklistItem>.from(preset.items);
    if (oldIndex < 0 || oldIndex >= items.length) return;
    if (adjustForRemoval && newIndex > oldIndex) newIndex -= 1;
    final safeNew = newIndex.clamp(0, items.length - 1);
    final moved = items.removeAt(oldIndex);
    items.insert(safeNew, moved);

    _presets[pIdx] = preset.copyWith(items: items, updatedAt: DateTime.now());
    await _storageService.saveDeparturePresets(_presets);
    notifyListeners();
  }

  Future<void> resetPresetItems(String presetId) async {
    final pIdx = _presets.indexWhere((p) => p.id == presetId);
    if (pIdx == -1) return;
    final now = DateTime.now();
    final preset = _presets[pIdx];
    final resetItems = preset.items
        .map((i) => i.copyWith(isChecked: false))
        .toList();
    _presets[pIdx] = preset.copyWith(items: resetItems, updatedAt: now);

    final todayKey = DepartureEvent.formatDateKey(now);
    var eventsModified = false;
    for (var i = 0; i < _events.length; i++) {
      if (_events[i].presetId == presetId &&
          _events[i].lastCompletedDateKey == todayKey) {
        _events[i] = _events[i].copyWith(clearLastCompletedDateKey: true);
        eventsModified = true;
      }
    }

    await _clearSnoozesForPreset(presetId, now);
    await _storageService.saveDeparturePresets(_presets);
    if (eventsModified) {
      await _storageService.saveDepartureEvents(_events);
    }
    await rescheduleAllNotifications(nowOverride: now);
    notifyListeners();
  }

  /// Checks off every item in [presetId], marks matching event(s) ready today,
  /// cancels pending today/snooze alerts, and updates schedules.
  Future<DepartureMarkAllReadyResult?> markPresetAllReady(
    String presetId, {
    String? eventId,
    int? dismissNotificationId,
    DateTime? nowOverride,
  }) async {
    final now = nowOverride ?? DateTime.now();
    final result = DepartureSnooze.applyMarkAllReady(
      presets: _presets,
      events: _events,
      snoozes: _snoozes,
      presetId: presetId,
      eventId: eventId,
      now: now,
    );
    if (result == null) return null;

    _presets = result.presets;
    _events = result.events;
    _snoozes = result.snoozes;

    await _notificationService.cancelDepartureActiveAlerts(
      clearedEventIds: result.clearedEventIds,
      events: _events,
      dismissNotificationId: dismissNotificationId,
      now: now,
    );

    await _storageService.saveDeparturePresets(_presets);
    await _storageService.saveDepartureEvents(_events);
    await _storageService.saveDepartureSnoozes(_snoozes);
    await rescheduleAllNotifications(nowOverride: now);
    notifyListeners();
    return result;
  }

  /// Snoozes a departure heads-up notification by 5 minutes (or [duration]),
  /// replacing any active snooze slot for the same departure today.
  Future<DepartureSnooze?> snoozeDeparture({
    required String eventId,
    String? presetId,
    int? dismissNotificationId,
    Duration duration = NotificationService.departureSnoozeDuration,
    DateTime? nowOverride,
  }) async {
    final target = DepartureSnooze.resolveSnoozeTarget(
      presets: _presets,
      events: _events,
      eventId: eventId,
      presetId: presetId,
    );
    if (target == null) return null;

    final now = nowOverride ?? DateTime.now();
    final entry = await _notificationService.scheduleDepartureSnooze(
      eventId: target.eventId,
      preset: target.preset,
      titleLabel: target.titleLabel,
      existingSnoozes: _snoozes,
      duration: duration,
      dismissNotificationId: dismissNotificationId,
      nowOverride: now,
    );

    _snoozes = DepartureSnooze.mergeAndPrune(_snoozes, entry, now);
    await _storageService.saveDepartureSnoozes(_snoozes);
    notifyListeners();
    return entry;
  }

  Future<void> _clearSnoozesForEvents(
    Set<String> eventIds,
    DateTime now,
  ) async {
    if (eventIds.isEmpty) return;
    final todayKey = DepartureEvent.formatDateKey(now);
    for (final evId in eventIds) {
      await _notificationService.cancel(
        DepartureSnooze.snoozedNotificationId(evId, todayKey),
      );
    }
    _snoozes = DepartureSnooze.pruneWithout(
      _snoozes,
      eventIds: eventIds,
      now: now,
    );
    await _storageService.saveDepartureSnoozes(_snoozes);
  }

  Future<void> _clearSnoozesForPreset(String presetId, DateTime now) async {
    final ids = <String>{
      DepartureSnooze.syntheticEventIdForPreset(presetId),
      for (final e in _events)
        if (e.presetId == presetId) e.id,
    };
    await _clearSnoozesForEvents(ids, now);
  }

  // --- Departure Schedules & Heads-Up Push Notifications ---

  Future<DepartureEvent> addDepartureEvent({
    required String title,
    required String presetId,
    required int hour,
    required int minute,
    DepartureRecurrenceType recurrence = DepartureRecurrenceType.oneTime,
    Set<int> selectedDays = const {},
    DateTime? oneTimeDate,
    int leadMinutes = 15,
    bool isEnabled = true,
    String? linkedCalendarEventId,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Departure event title cannot be empty.');
    }
    final validPresetId =
        _presets.any((p) => p.id == presetId) ? presetId : _presets.first.id;
    final now = DateTime.now();

    final normalizedDays = _normalizeDaysForRecurrence(recurrence, selectedDays);
    final event = DepartureEvent(
      id: 'dep_${const Uuid().v4().substring(0, 10)}',
      title: trimmed,
      presetId: validPresetId,
      hour: hour.clamp(0, 23),
      minute: minute.clamp(0, 59),
      recurrence: recurrence,
      selectedDays: normalizedDays,
      oneTimeDate: recurrence == DepartureRecurrenceType.oneTime
          ? (oneTimeDate ?? now)
          : null,
      leadMinutes: leadMinutes.clamp(
        DepartureEvent.minLeadMinutes,
        DepartureEvent.maxLeadMinutes,
      ),
      isEnabled: isEnabled,
      linkedCalendarEventId: linkedCalendarEventId,
      createdAt: now,
      updatedAt: now,
    );

    _events.add(event);
    await _storageService.saveDepartureEvents(_events);
    await rescheduleAllNotifications();
    notifyListeners();
    return event;
  }

  Future<void> updateDepartureEvent(DepartureEvent updated) async {
    final idx = _events.indexWhere((e) => e.id == updated.id);
    if (idx == -1) return;
    await _cancelEventNotifications(updated.id);
    _events[idx] = updated.copyWith(
      selectedDays:
          _normalizeDaysForRecurrence(updated.recurrence, updated.selectedDays),
      leadMinutes: updated.leadMinutes.clamp(
        DepartureEvent.minLeadMinutes,
        DepartureEvent.maxLeadMinutes,
      ),
      updatedAt: DateTime.now(),
    );
    await _storageService.saveDepartureEvents(_events);
    await rescheduleAllNotifications();
    notifyListeners();
  }

  Future<void> toggleDepartureEventEnabled(String eventId) async {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return;
    final now = DateTime.now();
    final nextEnabled = !_events[idx].isEnabled;
    if (!nextEnabled) {
      await _cancelEventNotifications(eventId);
      await _clearSnoozesForEvents({eventId}, now);
    }
    _events[idx] = _events[idx].copyWith(
      isEnabled: nextEnabled,
      updatedAt: now,
    );
    await _storageService.saveDepartureEvents(_events);
    await rescheduleAllNotifications(nowOverride: now);
    notifyListeners();
  }

  Future<void> markEventReadyToday(
    String eventId, {
    bool ready = true,
    DateTime? nowOverride,
  }) async {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return;
    final now = nowOverride ?? DateTime.now();
    _events[idx] = _events[idx].copyWith(
      lastCompletedDateKey: ready ? DepartureEvent.formatDateKey(now) : null,
      clearLastCompletedDateKey: !ready,
      updatedAt: now,
    );
    if (ready) {
      await _clearSnoozesForEvents({eventId}, now);
    }
    await _storageService.saveDepartureEvents(_events);
    await rescheduleAllNotifications(nowOverride: now);
    notifyListeners();
  }

  Future<void> deleteDepartureEvent(String eventId) async {
    final now = DateTime.now();
    await _cancelEventNotifications(eventId);
    await _clearSnoozesForEvents({eventId}, now);
    _events.removeWhere((e) => e.id == eventId);
    await _storageService.saveDepartureEvents(_events);
    await rescheduleAllNotifications(nowOverride: now);
    notifyListeners();
  }

  Future<DepartureEvent?> upsertFromCalendarEvent(
    CalendarEvent calEvent, {
    required String presetId,
    int leadMinutes = 15,
  }) async {
    final startTime = calEvent.startTime;
    if (startTime == null) return null;

    final existing = findEventByLinkedCalendarId(calEvent.id);
    if (existing != null) {
      final updated = existing.copyWith(
        title: calEvent.title,
        presetId: presetId,
        hour: startTime.hour,
        minute: startTime.minute,
        recurrence: DepartureRecurrenceType.oneTime,
        oneTimeDate: calEvent.date,
        leadMinutes: leadMinutes,
        isEnabled: true,
      );
      await updateDepartureEvent(updated);
      return updated;
    }

    return addDepartureEvent(
      title: calEvent.title,
      presetId: presetId,
      hour: startTime.hour,
      minute: startTime.minute,
      recurrence: DepartureRecurrenceType.oneTime,
      oneTimeDate: calEvent.date,
      leadMinutes: leadMinutes,
      isEnabled: true,
      linkedCalendarEventId: calEvent.id,
    );
  }

  Future<void> removeByLinkedCalendarEventId(String calendarEventId) async {
    final matches = _events
        .where((e) => e.linkedCalendarEventId == calendarEventId)
        .map((e) => e.id)
        .toList();
    if (matches.isEmpty) return;
    for (final id in matches) {
      await _cancelEventNotifications(id);
    }
    _events.removeWhere((e) => e.linkedCalendarEventId == calendarEventId);
    await _storageService.saveDepartureEvents(_events);
    await rescheduleAllNotifications();
    notifyListeners();
  }

  Set<int> _normalizeDaysForRecurrence(
    DepartureRecurrenceType recurrence,
    Set<int> selectedDays,
  ) {
    switch (recurrence) {
      case DepartureRecurrenceType.oneTime:
        return const {};
      case DepartureRecurrenceType.daily:
        return const {1, 2, 3, 4, 5, 6, 7};
      case DepartureRecurrenceType.weekdays:
        return const {1, 2, 3, 4, 5};
      case DepartureRecurrenceType.weekends:
        return const {6, 7};
      case DepartureRecurrenceType.customDays:
        return selectedDays.where((d) => d >= 1 && d <= 7).toSet();
    }
  }

  ({String title, String body}) buildNotificationContent(DepartureEvent event) {
    final preset = findPresetById(event.presetId) ?? activePreset;
    return DepartureSnooze.buildHeadsUpContent(event: event, preset: preset);
  }

  Future<void> triggerTestNotification(String eventId) async {
    final event = findEventById(eventId);
    if (event == null) return;
    final content = buildNotificationContent(event);
    await _notificationService.showDepartureNotification(
      id: testNotificationId,
      title: content.title,
      body: content.body,
      payload: buildPayload(event.id, event.presetId),
    );
  }

  Future<void> _cancelEventNotifications(String eventId) async {
    for (var dayOffset = 0; dayOffset <= 7; dayOffset++) {
      await _notificationService.cancel(notificationIdFor(eventId, dayOffset));
    }
  }

  Future<void> rescheduleAllNotifications({DateTime? nowOverride}) async {
    final now = nowOverride ?? DateTime.now();
    var scheduledCount = 0;

    for (final event in _events) {
      // Cancel all 8 rolling slots first to keep schedules clean and deterministic
      await _cancelEventNotifications(event.id);
      if (!event.isEnabled) continue;

      final upcoming = event
          .upcomingNotificationsWithin(now, daysHorizon: 7)
          .where((dt) => !event.isCompletedForDate(dt))
          .toList();
      if (upcoming.isEmpty) continue;

      final content = buildNotificationContent(event);
      final payload = buildPayload(event.id, event.presetId);

      for (var i = 0; i < upcoming.length && i < 8; i++) {
        await _notificationService.scheduleDepartureNotification(
          id: notificationIdFor(event.id, i),
          title: content.title,
          body: content.body,
          scheduledDate: upcoming[i],
          payload: payload,
        );
        scheduledCount++;
      }
    }

    _lastScheduledCount = scheduledCount;
  }
}
