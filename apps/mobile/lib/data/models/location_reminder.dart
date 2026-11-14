import 'alarm_category.dart';

enum GeofenceTriggerType {
  arrive,
  leave,
  both,
}

extension GeofenceTriggerTypeExt on GeofenceTriggerType {
  String get displayName {
    switch (this) {
      case GeofenceTriggerType.arrive:
        return 'On Arrival';
      case GeofenceTriggerType.leave:
        return 'On Departure';
      case GeofenceTriggerType.both:
        return 'Arrive & Leave';
    }
  }

  String get shortLabel {
    switch (this) {
      case GeofenceTriggerType.arrive:
        return 'Arriving';
      case GeofenceTriggerType.leave:
        return 'Leaving';
      case GeofenceTriggerType.both:
        return 'Enter / Exit';
    }
  }

  String get preposition {
    switch (this) {
      case GeofenceTriggerType.arrive:
        return 'when arriving near';
      case GeofenceTriggerType.leave:
        return 'when leaving';
      case GeofenceTriggerType.both:
        return 'near';
    }
  }

  String get emoji {
    switch (this) {
      case GeofenceTriggerType.arrive:
        return '📥';
      case GeofenceTriggerType.leave:
        return '📤';
      case GeofenceTriggerType.both:
        return '🔄';
    }
  }
}

enum GeofenceTransitionEvent {
  enter,
  exit,
  dwell,
}

extension GeofenceTransitionEventExt on GeofenceTransitionEvent {
  String get displayName {
    switch (this) {
      case GeofenceTransitionEvent.enter:
        return 'Arrived';
      case GeofenceTransitionEvent.exit:
        return 'Departed';
      case GeofenceTransitionEvent.dwell:
        return 'At Location';
    }
  }

  String get emoji {
    switch (this) {
      case GeofenceTransitionEvent.enter:
        return '📥';
      case GeofenceTransitionEvent.exit:
        return '📤';
      case GeofenceTransitionEvent.dwell:
        return '📍';
    }
  }
}

enum LocationPermissionState {
  unknown,
  denied,
  deniedForever,
  whileInUse,
  alwaysGranted,
}

extension LocationPermissionStateExt on LocationPermissionState {
  String get label {
    switch (this) {
      case LocationPermissionState.unknown:
        return 'Checking Permission';
      case LocationPermissionState.denied:
        return 'Location Off';
      case LocationPermissionState.deniedForever:
        return 'Blocked in Settings';
      case LocationPermissionState.whileInUse:
        return 'While Using App';
      case LocationPermissionState.alwaysGranted:
        return 'Background Active';
    }
  }

  bool get canUseForeground =>
      this == LocationPermissionState.whileInUse ||
      this == LocationPermissionState.alwaysGranted;

  bool get isReadyForBackground =>
      this == LocationPermissionState.alwaysGranted;
}

/// Historical trigger log item emitted when entering or exiting a monitored place.
class GeofenceTriggerLog {
  final String id;
  final String reminderId;
  final String reminderTitle;
  final String placeId;
  final String placeName;
  final GeofenceTransitionEvent event;
  final DateTime triggeredAt;
  final bool isSimulated;

  const GeofenceTriggerLog({
    required this.id,
    required this.reminderId,
    required this.reminderTitle,
    required this.placeId,
    required this.placeName,
    required this.event,
    required this.triggeredAt,
    this.isSimulated = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reminderId': reminderId,
      'reminderTitle': reminderTitle,
      'placeId': placeId,
      'placeName': placeName,
      'event': event.name,
      'triggeredAt': triggeredAt.toIso8601String(),
      'isSimulated': isSimulated,
    };
  }

  factory GeofenceTriggerLog.fromJson(Map<String, dynamic> json) {
    final eventName = json['event'] as String? ?? 'enter';
    final event = GeofenceTransitionEvent.values.firstWhere(
      (e) => e.name == eventName,
      orElse: () => GeofenceTransitionEvent.enter,
    );
    return GeofenceTriggerLog(
      id: json['id'] as String? ?? 'log_unknown',
      reminderId: json['reminderId'] as String? ?? '',
      reminderTitle: json['reminderTitle'] as String? ?? 'Reminder',
      placeId: json['placeId'] as String? ?? '',
      placeName: json['placeName'] as String? ?? 'Place',
      event: event,
      triggeredAt: json['triggeredAt'] != null
          ? DateTime.tryParse(json['triggeredAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isSimulated: json['isSimulated'] as bool? ?? false,
    );
  }
}

/// Reminder anchored to a [SavedPlace] geofence boundary.
class LocationReminder {
  final String id;
  final String title;
  final String notes;
  final String placeId;
  final GeofenceTriggerType triggerType;
  final AlarmCategory category;
  final bool isEnabled;
  final bool isCompleted;
  final bool oneTimeOnly;
  final int cooldownMinutes;
  final bool checkDepartureChecklist;
  final DateTime? lastTriggeredAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  const LocationReminder({
    required this.id,
    required this.title,
    this.notes = '',
    required this.placeId,
    this.triggerType = GeofenceTriggerType.arrive,
    required this.category,
    this.isEnabled = true,
    this.isCompleted = false,
    this.oneTimeOnly = false,
    this.cooldownMinutes = 30,
    this.checkDepartureChecklist = false,
    this.lastTriggeredAt,
    this.completedAt,
    required this.createdAt,
  });

  bool get isArmed => isEnabled && !isCompleted;

  int get safeCooldownMinutes => cooldownMinutes.clamp(0, 1440);

  bool matchesTransition(GeofenceTransitionEvent event) {
    switch (triggerType) {
      case GeofenceTriggerType.arrive:
        return event == GeofenceTransitionEvent.enter ||
            event == GeofenceTransitionEvent.dwell;
      case GeofenceTriggerType.leave:
        return event == GeofenceTransitionEvent.exit;
      case GeofenceTriggerType.both:
        return true;
    }
  }

  /// Checks whether reminder is armed and outside its trigger cooldown window.
  bool canTriggerAt(DateTime now) {
    if (!isArmed) return false;
    final last = lastTriggeredAt;
    if (last == null || safeCooldownMinutes == 0) return true;
    return now.difference(last).inMinutes >= safeCooldownMinutes;
  }

  String describeRule(String placeName) {
    return 'Remind to $title ${triggerType.preposition} $placeName';
  }

  LocationReminder copyWith({
    String? id,
    String? title,
    String? notes,
    String? placeId,
    GeofenceTriggerType? triggerType,
    AlarmCategory? category,
    bool? isEnabled,
    bool? isCompleted,
    bool? oneTimeOnly,
    int? cooldownMinutes,
    bool? checkDepartureChecklist,
    DateTime? lastTriggeredAt,
    bool? clearLastTriggeredAt,
    DateTime? completedAt,
    bool? clearCompletedAt,
    DateTime? createdAt,
  }) {
    return LocationReminder(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      placeId: placeId ?? this.placeId,
      triggerType: triggerType ?? this.triggerType,
      category: category ?? this.category,
      isEnabled: isEnabled ?? this.isEnabled,
      isCompleted: isCompleted ?? this.isCompleted,
      oneTimeOnly: oneTimeOnly ?? this.oneTimeOnly,
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
      checkDepartureChecklist:
          checkDepartureChecklist ?? this.checkDepartureChecklist,
      lastTriggeredAt: clearLastTriggeredAt == true
          ? null
          : (lastTriggeredAt ?? this.lastTriggeredAt),
      completedAt:
          clearCompletedAt == true ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'notes': notes,
      'placeId': placeId,
      'triggerType': triggerType.name,
      'category': category.toJson(),
      'isEnabled': isEnabled,
      'isCompleted': isCompleted,
      'oneTimeOnly': oneTimeOnly,
      'cooldownMinutes': safeCooldownMinutes,
      'checkDepartureChecklist': checkDepartureChecklist,
      'lastTriggeredAt': lastTriggeredAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LocationReminder.fromJson(Map<String, dynamic> json) {
    final trigName = json['triggerType'] as String? ?? 'arrive';
    final trig = GeofenceTriggerType.values.firstWhere(
      (e) => e.name == trigName,
      orElse: () => GeofenceTriggerType.arrive,
    );

    return LocationReminder(
      id: json['id'] as String? ?? 'loc_rem_unknown',
      title: json['title'] as String? ?? 'Location Reminder',
      notes: json['notes'] as String? ?? '',
      placeId: json['placeId'] as String? ?? '',
      triggerType: trig,
      category: AlarmCategory.fromJson(json['category']),
      isEnabled: json['isEnabled'] as bool? ?? true,
      isCompleted: json['isCompleted'] as bool? ?? false,
      oneTimeOnly: json['oneTimeOnly'] as bool? ?? false,
      cooldownMinutes: (json['cooldownMinutes'] as num?)?.toInt() ?? 30,
      checkDepartureChecklist:
          json['checkDepartureChecklist'] as bool? ?? false,
      lastTriggeredAt: json['lastTriggeredAt'] != null
          ? DateTime.tryParse(json['lastTriggeredAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

