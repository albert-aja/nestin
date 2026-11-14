import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/location_reminder.dart';
import '../models/saved_place.dart';

class GeoCoordinate {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime timestamp;
  final bool isSimulated;

  const GeoCoordinate({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    required this.timestamp,
    this.isSimulated = false,
  });

  factory GeoCoordinate.fromMap(Map<dynamic, dynamic> map) {
    final tsMs = (map['timestampMs'] as num?)?.toInt();
    return GeoCoordinate(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracyMeters: (map['accuracy'] as num?)?.toDouble(),
      timestamp: tsMs != null
          ? DateTime.fromMillisecondsSinceEpoch(tsMs)
          : DateTime.now(),
      isSimulated: map['isSimulated'] as bool? ?? false,
    );
  }
}

/// Flattened geofence region payload passed over platform MethodChannel to native Android/iOS OS APIs.
class NativeGeofenceRegistration {
  final String reminderId;
  final String placeId;
  final String placeName;
  final String title;
  final String notes;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final GeofenceTriggerType triggerType;
  final bool oneTimeOnly;
  final int cooldownMinutes;
  final bool checkDepartureChecklist;
  final int? lastTriggeredMs;

  const NativeGeofenceRegistration({
    required this.reminderId,
    required this.placeId,
    required this.placeName,
    required this.title,
    this.notes = '',
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.triggerType,
    this.oneTimeOnly = false,
    this.cooldownMinutes = 30,
    this.checkDepartureChecklist = false,
    this.lastTriggeredMs,
  });

  Map<String, dynamic> toPlatformMap() {
    return {
      'id': reminderId,
      'placeId': placeId,
      'placeName': placeName,
      'title': title,
      'notes': notes,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'triggerType': triggerType.name,
      'oneTimeOnly': oneTimeOnly,
      'cooldownMinutes': cooldownMinutes,
      'checkDepartureChecklist': checkDepartureChecklist,
      'lastTriggeredMs': lastTriggeredMs,
    };
  }
}

class NativeGeofenceEvent {
  final String reminderId;
  final String placeId;
  final String? placeName;
  final GeofenceTransitionEvent transition;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final bool isSimulated;
  final bool alreadyNotifiedNatively;

  const NativeGeofenceEvent({
    required this.reminderId,
    required this.placeId,
    this.placeName,
    required this.transition,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.isSimulated = false,
    this.alreadyNotifiedNatively = false,
  });

  factory NativeGeofenceEvent.fromPlatformMap(Map<dynamic, dynamic> map) {
    final trigStr = (map['transition'] as String? ?? 'enter').toLowerCase();
    final transition = GeofenceTransitionEvent.values.firstWhere(
      (e) => e.name == trigStr,
      orElse: () => trigStr == 'exit'
          ? GeofenceTransitionEvent.exit
          : GeofenceTransitionEvent.enter,
    );
    final tsMs = (map['timestampMs'] as num?)?.toInt();

    return NativeGeofenceEvent(
      reminderId: map['reminderId'] as String? ?? map['id'] as String? ?? '',
      placeId: map['placeId'] as String? ?? '',
      placeName: map['placeName'] as String?,
      transition: transition,
      timestamp: tsMs != null
          ? DateTime.fromMillisecondsSinceEpoch(tsMs)
          : DateTime.now(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      isSimulated: map['isSimulated'] as bool? ?? false,
      alreadyNotifiedNatively:
          map['alreadyNotifiedNatively'] as bool? ?? false,
    );
  }
}

abstract class GeofencingServiceInterface {
  Future<bool> isSupported();
  Future<LocationPermissionState> checkPermission();
  Future<LocationPermissionState> requestForegroundPermission();
  Future<LocationPermissionState> requestBackgroundPermission();
  Future<bool> openAppLocationSettings();
  Future<GeoCoordinate?> getCurrentLocation();
  Future<bool> syncGeofences(List<NativeGeofenceRegistration> regions);
  Future<bool> removeGeofence(String id);
  Future<bool> clearAllGeofences();
  Future<List<NativeGeofenceEvent>> drainPendingEvents();
  Stream<NativeGeofenceEvent> get eventStream;
  void dispose();
}

/// Bridges Flutter to Android (`LocationManager` / `GeofenceBroadcastReceiver`) and iOS (`CoreLocation` `CLCircularRegion`).
class NativeGeofencingService implements GeofencingServiceInterface {
  static const MethodChannel _channel =
      MethodChannel('com.nestin.app/geofencing');

  final StreamController<NativeGeofenceEvent> _eventController =
      StreamController<NativeGeofenceEvent>.broadcast();

  bool _handlerBound = false;

  NativeGeofencingService() {
    _bindNativeCallbacks();
  }

  bool get _isMobilePlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  void _bindNativeCallbacks() {
    if (_handlerBound) return;
    _handlerBound = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onGeofenceTransition') {
        final args = call.arguments;
        if (args is Map<dynamic, dynamic>) {
          _eventController.add(NativeGeofenceEvent.fromPlatformMap(args));
        }
      }
      return null;
    });
  }

  @override
  Stream<NativeGeofenceEvent> get eventStream => _eventController.stream;

  @override
  Future<bool> isSupported() async {
    if (!_isMobilePlatform) return false;
    try {
      final supported = await _channel.invokeMethod<bool>('isSupported');
      return supported ?? true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<LocationPermissionState> checkPermission() async {
    if (!_isMobilePlatform) return LocationPermissionState.denied;
    try {
      final raw = await _channel.invokeMethod<String>('checkPermission');
      return _parsePermission(raw);
    } catch (_) {
      return LocationPermissionState.unknown;
    }
  }

  @override
  Future<LocationPermissionState> requestForegroundPermission() async {
    if (!_isMobilePlatform) return LocationPermissionState.denied;
    try {
      final raw =
          await _channel.invokeMethod<String>('requestForegroundPermission');
      return _parsePermission(raw);
    } catch (_) {
      return LocationPermissionState.denied;
    }
  }

  @override
  Future<LocationPermissionState> requestBackgroundPermission() async {
    if (!_isMobilePlatform) return LocationPermissionState.denied;
    try {
      final raw =
          await _channel.invokeMethod<String>('requestBackgroundPermission');
      return _parsePermission(raw);
    } catch (_) {
      return LocationPermissionState.whileInUse;
    }
  }

  @override
  Future<bool> openAppLocationSettings() async {
    if (!_isMobilePlatform) return false;
    try {
      final opened =
          await _channel.invokeMethod<bool>('openAppLocationSettings');
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<GeoCoordinate?> getCurrentLocation() async {
    if (!_isMobilePlatform) return null;
    try {
      final map = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getCurrentLocation');
      if (map == null) return null;
      return GeoCoordinate.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> syncGeofences(List<NativeGeofenceRegistration> regions) async {
    if (!_isMobilePlatform) return false;
    try {
      final ok = await _channel.invokeMethod<bool>(
        'syncGeofences',
        {
          'regions': regions.map((r) => r.toPlatformMap()).toList(),
        },
      );
      return ok ?? false;
    } catch (e) {
      debugPrint('NativeGeofencingService syncGeofences skipped: $e');
      return false;
    }
  }

  @override
  Future<bool> removeGeofence(String id) async {
    if (!_isMobilePlatform) return false;
    try {
      final ok =
          await _channel.invokeMethod<bool>('removeGeofence', {'id': id});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> clearAllGeofences() async {
    if (!_isMobilePlatform) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('clearAllGeofences');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<NativeGeofenceEvent>> drainPendingEvents() async {
    if (!_isMobilePlatform) return const [];
    try {
      final list = await _channel.invokeMethod<List<dynamic>>('drainPendingEvents');
      if (list == null) return const [];
      return list
          .whereType<Map<dynamic, dynamic>>()
          .map(NativeGeofenceEvent.fromPlatformMap)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static LocationPermissionState _parsePermission(String? raw) {
    switch (raw) {
      case 'always':
      case 'alwaysGranted':
        return LocationPermissionState.alwaysGranted;
      case 'whileInUse':
        return LocationPermissionState.whileInUse;
      case 'deniedForever':
        return LocationPermissionState.deniedForever;
      case 'denied':
        return LocationPermissionState.denied;
      default:
        return LocationPermissionState.unknown;
    }
  }

  @override
  void dispose() {
    _eventController.close();
  }
}

/// Deterministic in-memory geofencing implementation for tests & desktop sandboxing.
class MockGeofencingService implements GeofencingServiceInterface {
  bool supported;
  LocationPermissionState permissionState;
  GeoCoordinate? currentLocation;
  List<NativeGeofenceRegistration> registeredRegions = [];
  final List<NativeGeofenceEvent> _queuedEvents = [];
  final Map<String, bool> _insideByReminderId = {};

  final StreamController<NativeGeofenceEvent> _controller =
      StreamController<NativeGeofenceEvent>.broadcast();

  int syncCalls = 0;
  int removeCalls = 0;
  int clearCalls = 0;
  bool openSettingsCalled = false;

  MockGeofencingService({
    this.supported = true,
    this.permissionState = LocationPermissionState.alwaysGranted,
    this.currentLocation,
  });

  @override
  Stream<NativeGeofenceEvent> get eventStream => _controller.stream;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<LocationPermissionState> checkPermission() async => permissionState;

  @override
  Future<LocationPermissionState> requestForegroundPermission() async {
    if (permissionState == LocationPermissionState.denied ||
        permissionState == LocationPermissionState.unknown) {
      permissionState = LocationPermissionState.whileInUse;
    }
    return permissionState;
  }

  @override
  Future<LocationPermissionState> requestBackgroundPermission() async {
    permissionState = LocationPermissionState.alwaysGranted;
    return permissionState;
  }

  @override
  Future<bool> openAppLocationSettings() async {
    openSettingsCalled = true;
    return true;
  }

  @override
  Future<GeoCoordinate?> getCurrentLocation() async => currentLocation;

  @override
  Future<bool> syncGeofences(List<NativeGeofenceRegistration> regions) async {
    syncCalls++;
    registeredRegions = List.of(regions);
    final activeIds = regions.map((r) => r.reminderId).toSet();
    _insideByReminderId.removeWhere((id, _) => !activeIds.contains(id));
    return supported;
  }

  @override
  Future<bool> removeGeofence(String id) async {
    removeCalls++;
    registeredRegions.removeWhere((r) => r.reminderId == id);
    _insideByReminderId.remove(id);
    return true;
  }

  @override
  Future<bool> clearAllGeofences() async {
    clearCalls++;
    registeredRegions.clear();
    _insideByReminderId.clear();
    return true;
  }

  void queueBackgroundEvent(NativeGeofenceEvent event) {
    _queuedEvents.add(event);
  }

  @override
  Future<List<NativeGeofenceEvent>> drainPendingEvents() async {
    final drained = List<NativeGeofenceEvent>.of(_queuedEvents);
    _queuedEvents.clear();
    return drained;
  }

  /// Moves simulated GPS coordinate and emits genuine enter/exit events when geofences cross boundaries.
  List<NativeGeofenceEvent> simulateLocationMove(
    double latitude,
    double longitude, {
    DateTime? timestamp,
    bool isSimulated = true,
  }) {
    final now = timestamp ?? DateTime.now();
    currentLocation = GeoCoordinate(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: 12.0,
      timestamp: now,
      isSimulated: isSimulated,
    );

    final emitted = <NativeGeofenceEvent>[];
    for (final region in registeredRegions) {
      final distance = SavedPlace.haversineMeters(
        region.latitude,
        region.longitude,
        latitude,
        longitude,
      );
      final isInside = distance <= region.radiusMeters;
      final wasInside = _insideByReminderId[region.reminderId];

      if (wasInside == null) {
        _insideByReminderId[region.reminderId] = isInside;
        if (isInside && region.triggerType != GeofenceTriggerType.leave) {
          final event = NativeGeofenceEvent(
            reminderId: region.reminderId,
            placeId: region.placeId,
            placeName: region.placeName,
            transition: GeofenceTransitionEvent.enter,
            timestamp: now,
            latitude: latitude,
            longitude: longitude,
            isSimulated: isSimulated,
          );
          emitted.add(event);
          _controller.add(event);
        }
        continue;
      }

      if (!wasInside && isInside) {
        _insideByReminderId[region.reminderId] = true;
        final event = NativeGeofenceEvent(
          reminderId: region.reminderId,
          placeId: region.placeId,
          placeName: region.placeName,
          transition: GeofenceTransitionEvent.enter,
          timestamp: now,
          latitude: latitude,
          longitude: longitude,
          isSimulated: isSimulated,
        );
        emitted.add(event);
        _controller.add(event);
      } else if (wasInside && !isInside) {
        _insideByReminderId[region.reminderId] = false;
        final event = NativeGeofenceEvent(
          reminderId: region.reminderId,
          placeId: region.placeId,
          placeName: region.placeName,
          transition: GeofenceTransitionEvent.exit,
          timestamp: now,
          latitude: latitude,
          longitude: longitude,
          isSimulated: isSimulated,
        );
        emitted.add(event);
        _controller.add(event);
      }
    }

    return emitted;
  }

  void emitTransition(NativeGeofenceEvent event) {
    _controller.add(event);
  }

  @override
  void dispose() {
    _controller.close();
  }
}

