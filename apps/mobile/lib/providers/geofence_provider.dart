import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/models/alarm_category.dart';
import '../data/models/location_reminder.dart';
import '../data/models/saved_place.dart';
import '../data/services/geofencing_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/storage_service.dart';

class GeofenceProvider extends ChangeNotifier {
  static const int maxTriggerLogs = 60;

  final StorageService _storageService;
  final NotificationService _notificationService;
  final GeofencingServiceInterface _geofencingService;
  final Uuid _uuid = const Uuid();

  List<SavedPlace> _places = [];
  List<LocationReminder> _reminders = [];
  List<GeofenceTriggerLog> _logs = [];

  LocationPermissionState _permissionState = LocationPermissionState.unknown;
  GeoCoordinate? _lastKnownCoordinate;
  final Map<String, bool> _insidePlaceState = {};
  bool _nativeSupported = false;
  bool _isSyncing = false;
  String? _lastError;
  StreamSubscription<NativeGeofenceEvent>? _eventSubscription;

  GeofenceProvider(
    this._storageService,
    this._notificationService, {
    GeofencingServiceInterface? geofencingService,
    bool seedDefaults = true,
    bool autoInitializeNative = true,
  }) : _geofencingService = geofencingService ?? NativeGeofencingService() {
    _load(seedDefaults: seedDefaults);
    _bindEventStream();
    if (autoInitializeNative) {
      unawaited(initializeNativeEngine());
    }
  }

  // --- Read-only Getters ---

  List<SavedPlace> get places => List.unmodifiable(_places);

  List<LocationReminder> get reminders => List.unmodifiable(_reminders);

  List<LocationReminder> get armedReminders =>
      _reminders.where((r) => r.isArmed).toList();

  List<LocationReminder> get pendingReminders =>
      _reminders.where((r) => !r.isCompleted).toList();

  List<LocationReminder> get completedReminders =>
      _reminders.where((r) => r.isCompleted).toList()
        ..sort((a, b) =>
            (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt));

  List<LocationReminder> get arriveReminders => _reminders
      .where((r) =>
          !r.isCompleted &&
          (r.triggerType == GeofenceTriggerType.arrive ||
              r.triggerType == GeofenceTriggerType.both))
      .toList();

  List<LocationReminder> get leaveReminders => _reminders
      .where((r) =>
          !r.isCompleted &&
          (r.triggerType == GeofenceTriggerType.leave ||
              r.triggerType == GeofenceTriggerType.both))
      .toList();

  List<GeofenceTriggerLog> get logs => List.unmodifiable(_logs);

  LocationPermissionState get permissionState => _permissionState;
  GeoCoordinate? get lastKnownCoordinate => _lastKnownCoordinate;
  bool get nativeSupported => _nativeSupported;
  bool get isSyncing => _isSyncing;
  String? get lastError => _lastError;

  int get armedCount => armedReminders.length;

  SavedPlace? findPlaceById(String id) {
    for (final p in _places) {
      if (p.id == id) return p;
    }
    return null;
  }

  LocationReminder? findReminderById(String id) {
    for (final r in _reminders) {
      if (r.id == id) return r;
    }
    return null;
  }

  int reminderCountForPlace(String placeId) =>
      _reminders.where((r) => r.placeId == placeId && !r.isCompleted).length;

  int armedReminderCountForPlace(String placeId) =>
      _reminders.where((r) => r.placeId == placeId && r.isArmed).length;

  double? distanceToPlaceMeters(SavedPlace place) {
    final coord = _lastKnownCoordinate;
    if (coord == null) return null;
    return place.distanceToMeters(coord.latitude, coord.longitude);
  }

  bool? isCurrentlyInsidePlace(SavedPlace place) {
    final cached = _insidePlaceState[place.id];
    if (cached != null) return cached;
    final coord = _lastKnownCoordinate;
    if (coord == null) return null;
    return place.containsCoordinate(coord.latitude, coord.longitude);
  }

  // --- Initialization & Persistence ---

  void _load({required bool seedDefaults}) {
    _places = _storageService.loadSavedPlaces();
    _reminders = _storageService.loadLocationReminders();
    _logs = _storageService.loadGeofenceLogs();

    if (seedDefaults && _places.isEmpty && _reminders.isEmpty) {
      final now = DateTime.now();
      const homeId = 'place_home_default';
      const storeId = 'place_store_default';
      const gymId = 'place_gym_default';

      _places = [
        SavedPlace(
          id: homeId,
          name: 'Home',
          address: 'Set your home coordinates via GPS',
          latitude: 37.7749,
          longitude: -122.4194,
          radiusMeters: 120.0,
          category: PlaceCategory.home,
          createdAt: now,
        ),
        SavedPlace(
          id: storeId,
          name: 'Grocery Store',
          address: 'Nearby market / supermarket',
          latitude: 37.7812,
          longitude: -122.4110,
          radiusMeters: 150.0,
          category: PlaceCategory.store,
          createdAt: now,
        ),
        SavedPlace(
          id: gymId,
          name: 'Neighborhood Gym',
          address: 'Fitness studio or sports club',
          latitude: 37.7685,
          longitude: -122.4265,
          radiusMeters: 150.0,
          category: PlaceCategory.gym,
          createdAt: now,
        ),
      ];

      _reminders = [
        LocationReminder(
          id: 'loc_rem_gym_bag',
          title: 'Take gym bag',
          notes: 'Check shoes, towel & water bottle before heading out',
          placeId: homeId,
          triggerType: GeofenceTriggerType.leave,
          category: AlarmCategory.fromType(AlarmCategoryType.health),
          isEnabled: true,
          oneTimeOnly: false,
          cooldownMinutes: 30,
          checkDepartureChecklist: true,
          createdAt: now,
        ),
        LocationReminder(
          id: 'loc_rem_buy_milk',
          title: 'Buy milk & fresh fruit',
          notes: 'Check pantry essentials while passing the market',
          placeId: storeId,
          triggerType: GeofenceTriggerType.arrive,
          category: AlarmCategory.fromType(AlarmCategoryType.personal),
          isEnabled: true,
          oneTimeOnly: true,
          cooldownMinutes: 30,
          createdAt: now,
        ),
      ];

      unawaited(_persistAll());
    }
  }

  void _bindEventStream() {
    _eventSubscription = _geofencingService.eventStream.listen((event) {
      unawaited(handleTransitionEvent(event));
    });
  }

  Future<void> initializeNativeEngine() async {
    _nativeSupported = await _geofencingService.isSupported();
    _permissionState = await _geofencingService.checkPermission();

    final pending = await _geofencingService.drainPendingEvents();
    for (final event in pending) {
      await handleTransitionEvent(
        event,
        showLocalNotification: !event.alreadyNotifiedNatively,
      );
    }

    await syncWithNativeGeofences();
    notifyListeners();
  }

  Future<void> reloadFromStorage() async {
    _load(seedDefaults: false);
    await syncWithNativeGeofences();
    notifyListeners();
  }

  Future<void> _persistAll() async {
    await _storageService.saveSavedPlaces(_places);
    await _storageService.saveLocationReminders(_reminders);
    await _storageService.saveGeofenceLogs(_logs);
  }

  // --- Place CRUD ---

  Future<void> addPlace(SavedPlace place) async {
    _places.add(place);
    await _storageService.saveSavedPlaces(_places);
    notifyListeners();
  }

  Future<void> updatePlace(SavedPlace updated) async {
    final idx = _places.indexWhere((p) => p.id == updated.id);
    if (idx == -1) return;
    _places[idx] = updated;
    await _storageService.saveSavedPlaces(_places);
    await syncWithNativeGeofences();
    notifyListeners();
  }

  Future<void> deletePlace(String placeId) async {
    _places.removeWhere((p) => p.id == placeId);
    final removedReminderIds = _reminders
        .where((r) => r.placeId == placeId)
        .map((r) => r.id)
        .toList();
    _reminders.removeWhere((r) => r.placeId == placeId);
    _insidePlaceState.remove(placeId);

    for (final id in removedReminderIds) {
      await _geofencingService.removeGeofence(id);
    }

    await _storageService.saveSavedPlaces(_places);
    await _storageService.saveLocationReminders(_reminders);
    await syncWithNativeGeofences();
    notifyListeners();
  }

  // --- Reminder CRUD ---

  Future<void> addReminder(LocationReminder reminder) async {
    _reminders.add(reminder);
    await _storageService.saveLocationReminders(_reminders);
    await syncWithNativeGeofences();
    notifyListeners();
  }

  Future<void> updateReminder(LocationReminder updated) async {
    final idx = _reminders.indexWhere((r) => r.id == updated.id);
    if (idx == -1) return;
    _reminders[idx] = updated;
    await _storageService.saveLocationReminders(_reminders);
    await syncWithNativeGeofences();
    notifyListeners();
  }

  Future<void> toggleEnabled(String id) async {
    final idx = _reminders.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final current = _reminders[idx];
    final nextEnabled = !current.isEnabled;
    _reminders[idx] = current.copyWith(
      isEnabled: nextEnabled,
      isCompleted: nextEnabled ? false : current.isCompleted,
      clearCompletedAt: nextEnabled,
    );
    await _storageService.saveLocationReminders(_reminders);
    await syncWithNativeGeofences();
    notifyListeners();
  }

  Future<void> toggleCompletion(String id) async {
    final idx = _reminders.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final current = _reminders[idx];
    final willComplete = !current.isCompleted;
    _reminders[idx] = current.copyWith(
      isCompleted: willComplete,
      isEnabled: willComplete ? false : true,
      completedAt: willComplete ? DateTime.now() : null,
      clearCompletedAt: !willComplete,
    );
    await _storageService.saveLocationReminders(_reminders);
    await syncWithNativeGeofences();
    notifyListeners();
  }

  Future<void> deleteReminder(String id) async {
    _reminders.removeWhere((r) => r.id == id);
    await _storageService.saveLocationReminders(_reminders);
    await _geofencingService.removeGeofence(id);
    await syncWithNativeGeofences();
    notifyListeners();
  }

  // --- Native Geofence Sync & Permissions ---

  List<NativeGeofenceRegistration> buildNativeRegistrations() {
    final regs = <NativeGeofenceRegistration>[];
    for (final reminder in armedReminders) {
      final place = findPlaceById(reminder.placeId);
      if (place == null) continue;
      regs.add(
        NativeGeofenceRegistration(
          reminderId: reminder.id,
          placeId: place.id,
          placeName: place.name,
          title: reminder.title,
          notes: reminder.notes,
          latitude: place.clampedLatitude,
          longitude: place.clampedLongitude,
          radiusMeters: place.clampedRadiusMeters,
          triggerType: reminder.triggerType,
          oneTimeOnly: reminder.oneTimeOnly,
          cooldownMinutes: reminder.safeCooldownMinutes,
          checkDepartureChecklist: reminder.checkDepartureChecklist,
          lastTriggeredMs: reminder.lastTriggeredAt?.millisecondsSinceEpoch,
        ),
      );
    }
    return regs;
  }

  Future<bool> syncWithNativeGeofences() async {
    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final registrations = buildNativeRegistrations();
      final result = await _geofencingService.syncGeofences(registrations);
      _isSyncing = false;
      notifyListeners();
      return result;
    } catch (e) {
      _lastError = e.toString();
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  Future<LocationPermissionState> refreshPermissionState() async {
    _permissionState = await _geofencingService.checkPermission();
    notifyListeners();
    return _permissionState;
  }

  Future<LocationPermissionState> requestForegroundPermission() async {
    _permissionState = await _geofencingService.requestForegroundPermission();
    await syncWithNativeGeofences();
    notifyListeners();
    return _permissionState;
  }

  Future<LocationPermissionState> requestBackgroundPermission() async {
    if (!_permissionState.canUseForeground) {
      _permissionState = await _geofencingService.requestForegroundPermission();
      if (!_permissionState.canUseForeground) {
        notifyListeners();
        return _permissionState;
      }
    }
    _permissionState = await _geofencingService.requestBackgroundPermission();
    await syncWithNativeGeofences();
    notifyListeners();
    return _permissionState;
  }

  Future<bool> openLocationSettings() async {
    return _geofencingService.openAppLocationSettings();
  }

  Future<GeoCoordinate?> refreshCurrentLocation({
    bool evaluateTransitions = false,
  }) async {
    final coord = await _geofencingService.getCurrentLocation();
    if (coord != null) {
      _lastKnownCoordinate = coord;
      if (evaluateTransitions) {
        await evaluateCoordinateSweep(
          coord.latitude,
          coord.longitude,
          now: coord.timestamp,
          isSimulated: coord.isSimulated,
        );
      } else {
        for (final place in _places) {
          _insidePlaceState[place.id] =
              place.containsCoordinate(coord.latitude, coord.longitude);
        }
        notifyListeners();
      }
    }
    return coord;
  }

  // --- Transition Evaluation & Simulator ---

  /// Evaluates GPS coordinates against all saved places, triggering reminders when boundaries are crossed.
  Future<List<GeofenceTriggerLog>> evaluateCoordinateSweep(
    double latitude,
    double longitude, {
    DateTime? now,
    bool isSimulated = false,
    bool showLocalNotification = true,
  }) async {
    final ts = now ?? DateTime.now();
    _lastKnownCoordinate = GeoCoordinate(
      latitude: latitude,
      longitude: longitude,
      timestamp: ts,
      isSimulated: isSimulated,
    );

    final triggered = <GeofenceTriggerLog>[];

    for (final place in _places) {
      final isInside = place.containsCoordinate(latitude, longitude);
      final wasInside = _insidePlaceState[place.id];
      _insidePlaceState[place.id] = isInside;

      GeofenceTransitionEvent? transition;
      if (wasInside == null) {
        if (isInside) transition = GeofenceTransitionEvent.enter;
      } else if (!wasInside && isInside) {
        transition = GeofenceTransitionEvent.enter;
      } else if (wasInside && !isInside) {
        transition = GeofenceTransitionEvent.exit;
      }

      if (transition == null) continue;

      final matchingReminders = _reminders
          .where((r) => r.placeId == place.id && r.isArmed)
          .toList();

      for (final reminder in matchingReminders) {
        final log = await handleTransitionEvent(
          NativeGeofenceEvent(
            reminderId: reminder.id,
            placeId: place.id,
            placeName: place.name,
            transition: transition,
            timestamp: ts,
            latitude: latitude,
            longitude: longitude,
            isSimulated: isSimulated,
          ),
          showLocalNotification: showLocalNotification,
        );
        if (log != null) triggered.add(log);
      }
    }

    notifyListeners();
    return triggered;
  }

  /// Processes a single native or simulated transition event.
  Future<GeofenceTriggerLog?> handleTransitionEvent(
    NativeGeofenceEvent event, {
    bool showLocalNotification = true,
  }) async {
    final idx = _reminders.indexWhere((r) => r.id == event.reminderId);
    if (idx == -1) return null;

    final reminder = _reminders[idx];
    if (!reminder.matchesTransition(event.transition)) return null;
    if (!event.isSimulated &&
        !event.alreadyNotifiedNatively &&
        !reminder.canTriggerAt(event.timestamp)) {
      return null;
    }

    final place = findPlaceById(reminder.placeId);
    final resolvedPlaceName = place?.name ?? event.placeName ?? 'Saved Place';

    _reminders[idx] = reminder.copyWith(
      lastTriggeredAt: event.timestamp,
      isCompleted: reminder.oneTimeOnly ? true : reminder.isCompleted,
      isEnabled: reminder.oneTimeOnly ? false : reminder.isEnabled,
      completedAt:
          reminder.oneTimeOnly ? event.timestamp : reminder.completedAt,
    );

    final log = GeofenceTriggerLog(
      id: _uuid.v4(),
      reminderId: reminder.id,
      reminderTitle: reminder.title,
      placeId: reminder.placeId,
      placeName: resolvedPlaceName,
      event: event.transition,
      triggeredAt: event.timestamp,
      isSimulated: event.isSimulated,
    );

    _logs.insert(0, log);
    if (_logs.length > maxTriggerLogs) {
      _logs = _logs.sublist(0, maxTriggerLogs);
    }

    if (showLocalNotification && !event.alreadyNotifiedNatively) {
      await _fireReminderNotification(
        reminder: reminder,
        placeName: resolvedPlaceName,
        transition: event.transition,
      );
    }

    await _storageService.saveLocationReminders(_reminders);
    await _storageService.saveGeofenceLogs(_logs);
    if (reminder.oneTimeOnly) {
      await syncWithNativeGeofences();
    }
    notifyListeners();
    return log;
  }

  /// Manual 1-tap test trigger used to preview arrival/departure alerts without physical travel.
  Future<GeofenceTriggerLog?> simulateTrigger(
    String reminderId, {
    GeofenceTransitionEvent? transition,
    DateTime? timestamp,
  }) async {
    final reminder = findReminderById(reminderId);
    if (reminder == null) return null;
    final place = findPlaceById(reminder.placeId);

    final effectiveTransition = transition ??
        (reminder.triggerType == GeofenceTriggerType.leave
            ? GeofenceTransitionEvent.exit
            : GeofenceTransitionEvent.enter);

    final idx = _reminders.indexWhere((r) => r.id == reminderId);
    if (idx == -1) return null;

    final now = timestamp ?? DateTime.now();
    _reminders[idx] = _reminders[idx].copyWith(lastTriggeredAt: now);

    final log = GeofenceTriggerLog(
      id: _uuid.v4(),
      reminderId: reminder.id,
      reminderTitle: reminder.title,
      placeId: reminder.placeId,
      placeName: place?.name ?? 'Saved Place',
      event: effectiveTransition,
      triggeredAt: now,
      isSimulated: true,
    );

    _logs.insert(0, log);
    if (_logs.length > maxTriggerLogs) {
      _logs = _logs.sublist(0, maxTriggerLogs);
    }

    await _fireReminderNotification(
      reminder: _reminders[idx],
      placeName: log.placeName,
      transition: effectiveTransition,
    );

    await _storageService.saveLocationReminders(_reminders);
    await _storageService.saveGeofenceLogs(_logs);
    notifyListeners();
    return log;
  }

  Future<void> _fireReminderNotification({
    required LocationReminder reminder,
    required String placeName,
    required GeofenceTransitionEvent transition,
  }) async {
    final actionVerb = transition == GeofenceTransitionEvent.exit
        ? 'Leaving'
        : 'Near';
    final title = '🧭 $actionVerb $placeName: ${reminder.title}';

    final buffer = StringBuffer();
    if (reminder.notes.isNotEmpty) {
      buffer.write(reminder.notes);
    } else {
      buffer.write(reminder.describeRule(placeName));
    }
    if (reminder.checkDepartureChecklist &&
        transition == GeofenceTransitionEvent.exit) {
      buffer.write(' • Check BeforeYouGo keys, wallet & essentials!');
    }

    await _notificationService.showGeofenceNotification(
      id: 7400 + (reminder.id.hashCode.abs() % 500),
      title: title,
      body: buffer.toString(),
      payload: 'location_reminders',
    );
  }

  Future<void> clearLogs() async {
    _logs.clear();
    await _storageService.saveGeofenceLogs(_logs);
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _geofencingService.dispose();
    super.dispose();
  }
}

