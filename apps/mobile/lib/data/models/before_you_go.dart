import 'package:flutter/material.dart';
import '../../core/utils/deterministic_hash.dart';

class DepartureChecklistItem {
  final String id;
  final String label;
  final bool isChecked;
  final bool isEssential;

  const DepartureChecklistItem({
    required this.id,
    required this.label,
    this.isChecked = false,
    this.isEssential = false,
  });

  DepartureChecklistItem copyWith({
    String? id,
    String? label,
    bool? isChecked,
    bool? isEssential,
  }) {
    return DepartureChecklistItem(
      id: id ?? this.id,
      label: label ?? this.label,
      isChecked: isChecked ?? this.isChecked,
      isEssential: isEssential ?? this.isEssential,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'isChecked': isChecked,
        'isEssential': isEssential,
      };

  factory DepartureChecklistItem.fromJson(Map<String, dynamic> json) {
    return DepartureChecklistItem(
      id: json['id'] as String? ?? 'item_${DateTime.now().microsecondsSinceEpoch}',
      label: json['label'] as String? ?? 'Item',
      isChecked: json['isChecked'] as bool? ?? false,
      isEssential: json['isEssential'] as bool? ?? false,
    );
  }
}

class DeparturePreset {
  static const String workPresetId = 'preset_work';
  static const String travelPresetId = 'preset_travel';
  static const String gymPresetId = 'preset_gym';
  static const String everydayPresetId = 'preset_everyday';

  static final List<IconData> availableIcons = [
    Icons.work_outline_rounded,
    Icons.flight_takeoff_rounded,
    Icons.fitness_center_rounded,
    Icons.door_front_door_outlined,
    Icons.school_outlined,
    Icons.shopping_bag_outlined,
    Icons.directions_car_outlined,
    Icons.backpack_outlined,
  ];

  static IconData resolvePresetIcon(int codePoint) {
    for (final icon in availableIcons) {
      if (icon.codePoint == codePoint) return icon;
    }
    return Icons.checklist_rounded;
  }

  final String id;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  final List<DepartureChecklistItem> items;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DeparturePreset({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    required this.items,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  IconData get icon => resolvePresetIcon(iconCodePoint);
  Color get color => Color(colorValue);

  int get checkedCount => items.where((i) => i.isChecked).length;
  int get totalCount => items.length;
  bool get allChecked => items.isNotEmpty && checkedCount == totalCount;
  List<DepartureChecklistItem> get uncheckedItems =>
      items.where((i) => !i.isChecked).toList();

  double get completionFraction =>
      items.isEmpty ? 0.0 : (checkedCount / totalCount).clamp(0.0, 1.0);

  /// Formats a concise reminder summary highlighting essential/unchecked items.
  String buildReminderHighlight({int maxItems = 3}) {
    if (items.isEmpty) return 'Check your essentials before heading out!';
    final remaining = uncheckedItems;
    if (remaining.isEmpty) {
      return 'All ${items.length} $name items checked & ready!';
    }
    final prioritized = [
      ...remaining.where((i) => i.isEssential),
      ...remaining.where((i) => !i.isEssential),
    ];
    final preview = prioritized.take(maxItems).map((i) => i.label).join(', ');
    final extra = prioritized.length - maxItems;
    if (extra > 0) {
      return 'Check $preview (+$extra more)';
    }
    return 'Check $preview';
  }

  DeparturePreset copyWith({
    String? id,
    String? name,
    int? iconCodePoint,
    int? colorValue,
    List<DepartureChecklistItem>? items,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeparturePreset(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      items: items ?? this.items,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconCodePoint': iconCodePoint,
        'colorValue': colorValue,
        'items': items.map((e) => e.toJson()).toList(),
        'isDefault': isDefault,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory DeparturePreset.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>?) ?? const [];
    final created = json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now();
    return DeparturePreset(
      id: json['id'] as String? ?? 'preset_custom',
      name: json['name'] as String? ?? 'Custom',
      iconCodePoint:
          (json['iconCodePoint'] as num?)?.toInt() ?? Icons.checklist_rounded.codePoint,
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFFF59E0B,
      items: rawItems
          .map((e) => DepartureChecklistItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: created,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : created,
    );
  }

  static List<DeparturePreset> seedDefaults([DateTime? nowOverride]) {
    final now = nowOverride ?? DateTime.now();
    return [
      DeparturePreset(
        id: everydayPresetId,
        name: 'Everyday',
        iconCodePoint: Icons.door_front_door_outlined.codePoint,
        colorValue: 0xFF3B82F6,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
        items: const [
          DepartureChecklistItem(
            id: 'ed_keys_wallet',
            label: 'Keys & Wallet',
            isEssential: true,
          ),
          DepartureChecklistItem(
            id: 'ed_phone_charger',
            label: 'Phone & Charger',
            isEssential: true,
          ),
          DepartureChecklistItem(
            id: 'ed_water',
            label: 'Water bottle',
          ),
          DepartureChecklistItem(
            id: 'ed_appliances',
            label: 'Turn off appliances',
          ),
          DepartureChecklistItem(
            id: 'ed_locks',
            label: 'Lock windows & doors',
          ),
        ],
      ),
      DeparturePreset(
        id: workPresetId,
        name: 'Work',
        iconCodePoint: Icons.work_outline_rounded.codePoint,
        colorValue: 0xFF6366F1,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
        items: const [
          DepartureChecklistItem(
            id: 'wk_keys_wallet',
            label: 'Keys & Wallet',
            isEssential: true,
          ),
          DepartureChecklistItem(
            id: 'wk_phone_charger',
            label: 'Phone & Charger',
            isEssential: true,
          ),
          DepartureChecklistItem(
            id: 'wk_badge',
            label: 'Work ID / Badge',
            isEssential: true,
          ),
          DepartureChecklistItem(
            id: 'wk_laptop',
            label: 'Laptop & Power Adapter',
          ),
          DepartureChecklistItem(
            id: 'wk_water',
            label: 'Tumbler / Lunch',
          ),
        ],
      ),
      DeparturePreset(
        id: travelPresetId,
        name: 'Travel',
        iconCodePoint: Icons.flight_takeoff_rounded.codePoint,
        colorValue: 0xFFF59E0B,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
        items: const [
          DepartureChecklistItem(
            id: 'tr_passport',
            label: 'Passport / ID & Boarding Pass',
            isEssential: true,
          ),
          DepartureChecklistItem(
            id: 'tr_keys_wallet',
            label: 'Keys & Wallet',
            isEssential: true,
          ),
          DepartureChecklistItem(
            id: 'tr_powerbank',
            label: 'Phone, Charger & Power Bank',
            isEssential: true,
          ),
          DepartureChecklistItem(
            id: 'tr_meds',
            label: 'Essential Medications & Toiletries',
          ),
          DepartureChecklistItem(
            id: 'tr_home_lock',
            label: 'Unplug appliances & lock home',
          ),
        ],
      ),
      DeparturePreset(
        id: gymPresetId,
        name: 'Gym',
        iconCodePoint: Icons.fitness_center_rounded.codePoint,
        colorValue: 0xFF10B981,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
        items: const [
          DepartureChecklistItem(
            id: 'gm_shoes',
            label: 'Gym Bag & Sneakers',
            isEssential: true,
          ),
          DepartureChecklistItem(
            id: 'gm_keys',
            label: 'Keys, Wallet & Access Card',
            isEssential: true,
          ),
          DepartureChecklistItem(
            id: 'gm_water_towel',
            label: 'Water Bottle & Towel',
          ),
          DepartureChecklistItem(
            id: 'gm_earbuds',
            label: 'Phone & Earbuds',
          ),
          DepartureChecklistItem(
            id: 'gm_clothes',
            label: 'Change of Clothes & Locker Lock',
          ),
        ],
      ),
    ];
  }
}

enum DepartureRecurrenceType {
  oneTime('One-time'),
  daily('Every day'),
  weekdays('Mon–Fri'),
  weekends('Weekends'),
  customDays('Custom days');

  final String label;
  const DepartureRecurrenceType(this.label);

  static DepartureRecurrenceType fromName(String? raw) {
    return DepartureRecurrenceType.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => DepartureRecurrenceType.oneTime,
    );
  }
}

class DepartureEvent {
  static const int minLeadMinutes = 0;
  static const int maxLeadMinutes = 180;
  static const List<int> quickLeadMinuteOptions = [0, 5, 10, 15, 20, 30, 45, 60];

  final String id;
  final String title;
  final String presetId;
  final int hour;
  final int minute;
  final DepartureRecurrenceType recurrence;
  /// ISO weekdays: 1 = Mon .. 7 = Sun (used when recurrence == customDays/weekdays/weekends/daily).
  final Set<int> selectedDays;
  final DateTime? oneTimeDate;
  final int leadMinutes;
  final bool isEnabled;
  final String? linkedCalendarEventId;
  final String? lastCompletedDateKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DepartureEvent({
    required this.id,
    required this.title,
    required this.presetId,
    required this.hour,
    required this.minute,
    this.recurrence = DepartureRecurrenceType.oneTime,
    this.selectedDays = const {},
    this.oneTimeDate,
    this.leadMinutes = 15,
    this.isEnabled = true,
    this.linkedCalendarEventId,
    this.lastCompletedDateKey,
    required this.createdAt,
    required this.updatedAt,
  });

  int get clampedLeadMinutes =>
      leadMinutes.clamp(minLeadMinutes, maxLeadMinutes);

  TimeOfDay get departureTimeOfDay => TimeOfDay(hour: hour, minute: minute);

  bool get isRecurring => recurrence != DepartureRecurrenceType.oneTime;

  String get formattedDepartureTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get formattedNotificationTime {
    final sample = DateTime(2026, 1, 2, hour, minute)
        .subtract(Duration(minutes: clampedLeadMinutes));
    return '${sample.hour.toString().padLeft(2, '0')}:${sample.minute.toString().padLeft(2, '0')}';
  }

  String get leadLabel =>
      clampedLeadMinutes == 0 ? 'At departure time' : '${clampedLeadMinutes}m before';

  String get recurrenceSummary {
    switch (recurrence) {
      case DepartureRecurrenceType.oneTime:
        if (oneTimeDate == null) return 'One-time';
        final d = oneTimeDate!;
        final now = DateTime.now();
        if (d.year == now.year && d.month == now.month && d.day == now.day) {
          return 'Today';
        }
        final tmrw = now.add(const Duration(days: 1));
        if (d.year == tmrw.year && d.month == tmrw.month && d.day == tmrw.day) {
          return 'Tomorrow';
        }
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        return '${months[d.month - 1]} ${d.day}';
      case DepartureRecurrenceType.daily:
        return 'Every day';
      case DepartureRecurrenceType.weekdays:
        return 'Mon–Fri';
      case DepartureRecurrenceType.weekends:
        return 'Sat–Sun';
      case DepartureRecurrenceType.customDays:
        if (selectedDays.isEmpty) return 'No days selected';
        const names = {
          1: 'Mon',
          2: 'Tue',
          3: 'Wed',
          4: 'Thu',
          5: 'Fri',
          6: 'Sat',
          7: 'Sun',
        };
        final sorted = selectedDays.toList()..sort();
        return sorted.map((d) => names[d] ?? '').where((s) => s.isNotEmpty).join(', ');
    }
  }

  bool isCompletedForDate(DateTime date) =>
      lastCompletedDateKey == formatDateKey(date);

  static String formatDateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool matchesDate(DateTime date) {
    switch (recurrence) {
      case DepartureRecurrenceType.oneTime:
        final target = oneTimeDate ?? createdAt;
        return target.year == date.year &&
            target.month == date.month &&
            target.day == date.day;
      case DepartureRecurrenceType.daily:
        return true;
      case DepartureRecurrenceType.weekdays:
        return date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
      case DepartureRecurrenceType.weekends:
        return date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday;
      case DepartureRecurrenceType.customDays:
        return selectedDays.contains(date.weekday);
    }
  }

  DateTime departureDateTimeForDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, hour, minute);

  DateTime notificationDateTimeForDay(DateTime date) =>
      departureDateTimeForDay(date)
          .subtract(Duration(minutes: clampedLeadMinutes));

  /// Returns next scheduled departure DateTime strictly after [now],
  /// or `null` if a one-time departure has already passed or no recurring day matched.
  DateTime? nextDepartureAfter(DateTime now) {
    if (recurrence == DepartureRecurrenceType.oneTime) {
      final base = oneTimeDate ?? createdAt;
      final candidate = departureDateTimeForDay(base);
      return candidate.isAfter(now) ? candidate : null;
    }

    for (var offset = 0; offset <= 7; offset++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
      if (!matchesDate(day)) continue;
      final candidate = departureDateTimeForDay(day);
      if (candidate.isAfter(now)) return candidate;
    }
    return null;
  }

  /// Returns next heads-up notification DateTime strictly after [now],
  /// accounting cleanly for day-rollover when leadMinutes crosses midnight
  /// (check tomorrow too if `notificationTime` falls at 23:xx the prior day).
  DateTime? nextNotificationAfter(DateTime now) {
    if (recurrence == DepartureRecurrenceType.oneTime) {
      final base = oneTimeDate ?? createdAt;
      final notifyAt = notificationDateTimeForDay(base);
      return notifyAt.isAfter(now) ? notifyAt : null;
    }

    for (var offset = 0; offset <= 8; offset++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
      if (!matchesDate(day)) continue;
      final notifyAt = notificationDateTimeForDay(day);
      if (notifyAt.isAfter(now)) return notifyAt;
    }
    return null;
  }

  /// Returns upcoming heads-up notification timestamps inside `[now, now + daysHorizon]`.
  List<DateTime> upcomingNotificationsWithin(
    DateTime now, {
    int daysHorizon = 7,
  }) {
    if (!isEnabled) return const [];
    if (recurrence == DepartureRecurrenceType.oneTime) {
      final base = oneTimeDate ?? createdAt;
      final notifyAt = notificationDateTimeForDay(base);
      if (notifyAt.isAfter(now)) return [notifyAt];
      return const [];
    }

    final cutoff = now.add(Duration(days: daysHorizon));
    final results = <DateTime>[];
    for (var offset = 0; offset <= daysHorizon + 1; offset++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
      if (!matchesDate(day)) continue;
      final notifyAt = notificationDateTimeForDay(day);
      if (notifyAt.isAfter(now) && !notifyAt.isAfter(cutoff)) {
        results.add(notifyAt);
      }
    }
    return results;
  }

  DepartureEvent copyWith({
    String? id,
    String? title,
    String? presetId,
    int? hour,
    int? minute,
    DepartureRecurrenceType? recurrence,
    Set<int>? selectedDays,
    DateTime? oneTimeDate,
    bool? clearOneTimeDate,
    int? leadMinutes,
    bool? isEnabled,
    String? linkedCalendarEventId,
    bool? clearLinkedCalendarEventId,
    String? lastCompletedDateKey,
    bool? clearLastCompletedDateKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DepartureEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      presetId: presetId ?? this.presetId,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      recurrence: recurrence ?? this.recurrence,
      selectedDays: selectedDays ?? this.selectedDays,
      oneTimeDate: clearOneTimeDate == true ? null : (oneTimeDate ?? this.oneTimeDate),
      leadMinutes: leadMinutes ?? this.leadMinutes,
      isEnabled: isEnabled ?? this.isEnabled,
      linkedCalendarEventId: clearLinkedCalendarEventId == true
          ? null
          : (linkedCalendarEventId ?? this.linkedCalendarEventId),
      lastCompletedDateKey: clearLastCompletedDateKey == true
          ? null
          : (lastCompletedDateKey ?? this.lastCompletedDateKey),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'presetId': presetId,
        'hour': hour,
        'minute': minute,
        'recurrence': recurrence.name,
        'selectedDays': selectedDays.toList()..sort(),
        'oneTimeDate': oneTimeDate?.toIso8601String(),
        'leadMinutes': leadMinutes,
        'isEnabled': isEnabled,
        'linkedCalendarEventId': linkedCalendarEventId,
        'lastCompletedDateKey': lastCompletedDateKey,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory DepartureEvent.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now();
    final rawDays = (json['selectedDays'] as List<dynamic>?) ?? const [];
    return DepartureEvent(
      id: json['id'] as String? ?? 'dep_${DateTime.now().microsecondsSinceEpoch}',
      title: json['title'] as String? ?? 'Departure',
      presetId: json['presetId'] as String? ?? DeparturePreset.everydayPresetId,
      hour: (json['hour'] as num?)?.toInt() ?? 8,
      minute: (json['minute'] as num?)?.toInt() ?? 0,
      recurrence: DepartureRecurrenceType.fromName(json['recurrence'] as String?),
      selectedDays: rawDays.map((e) => (e as num).toInt()).toSet(),
      oneTimeDate: json['oneTimeDate'] != null
          ? DateTime.parse(json['oneTimeDate'] as String)
          : null,
      leadMinutes: (json['leadMinutes'] as num?)?.toInt() ?? 15,
      isEnabled: json['isEnabled'] as bool? ?? true,
      linkedCalendarEventId: json['linkedCalendarEventId'] as String?,
      lastCompletedDateKey: json['lastCompletedDateKey'] as String?,
      createdAt: created,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : created,
    );
  }
}

/// Result of applying a "Mark All Ready" transition across BeforeYouGo presets,
/// departure events, and active snooze entries.
class DepartureMarkAllReadyResult {
  final DeparturePreset preset;
  final DepartureEvent? event;
  final List<DeparturePreset> presets;
  final List<DepartureEvent> events;
  final List<DepartureSnooze> snoozes;
  final Set<String> clearedEventIds;

  const DepartureMarkAllReadyResult({
    required this.preset,
    required this.event,
    required this.presets,
    required this.events,
    required this.snoozes,
    required this.clearedEventIds,
  });
}

/// Represents a 5-minute snoozed BeforeYouGo heads-up notification stored
/// persistently across main and background isolates.
class DepartureSnooze {
  static const String payloadPrefix = 'before_you_go';
  static const Duration defaultSnoozeDuration = Duration(minutes: 5);
  static const int notificationBaseId = 81000;
  static const int snoozedNotificationBaseId = 200000;

  final String eventId;
  final String presetId;
  final String dateKey;
  final DateTime snoozedUntil;
  final int snoozeCount;

  const DepartureSnooze({
    required this.eventId,
    required this.presetId,
    required this.dateKey,
    required this.snoozedUntil,
    this.snoozeCount = 1,
  });

  String get slotKey => '$dateKey|$eventId';

  bool isActiveAt(DateTime now) => snoozedUntil.isAfter(now);

  String get formattedSnoozedUntil {
    final hh = snoozedUntil.hour.toString().padLeft(2, '0');
    final mm = snoozedUntil.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  static String syntheticEventIdForPreset(String presetId) => 'active_$presetId';

  static String buildPayload(String eventId, String presetId) =>
      '$payloadPrefix|$eventId|$presetId';

  static ({String eventId, String presetId})? parsePayload(String? raw) {
    if (raw == null || !raw.startsWith('$payloadPrefix|')) return null;
    final parts = raw.split('|');
    if (parts.length < 3) return null;
    return (eventId: parts[1], presetId: parts[2]);
  }

  /// Parses payloads from notification shade actions, accepting both
  /// `before_you_go|<eventId>|<presetId>` and bare `before_you_go` targets.
  static ({String eventId, String presetId})? parseActionPayload(
    String? raw, {
    required String fallbackPresetId,
  }) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed == payloadPrefix || trimmed == 'nestin://$payloadPrefix') {
      return (eventId: '', presetId: fallbackPresetId);
    }
    final parsed = parsePayload(trimmed);
    if (parsed == null) return null;
    final resolvedPreset =
        parsed.presetId.isNotEmpty ? parsed.presetId : fallbackPresetId;
    return (eventId: parsed.eventId, presetId: resolvedPreset);
  }

  static int regularNotificationId(String eventId, int dayOffset) {
    return notificationBaseId + ((stableHash31(eventId) % 4000) * 10 + dayOffset);
  }

  static int snoozedNotificationId(String eventId, String dateKey) {
    return snoozedNotificationBaseId +
        (stableHash31('dep_snooze|$dateKey|$eventId') % 90000);
  }

  static ({String title, String body}) buildHeadsUpContent({
    required DepartureEvent event,
    required DeparturePreset preset,
  }) {
    final leadText = event.clampedLeadMinutes == 0
        ? 'Time to leave'
        : 'in ${event.clampedLeadMinutes}m (${event.formattedDepartureTime})';
    final title = '🧭 Scout BeforeYouGo: ${event.title} $leadText';
    final body =
        '${preset.name} Checklist: ${preset.buildReminderHighlight(maxItems: 4)}';
    return (title: title, body: body);
  }

  static ({String title, String body}) buildSnoozedContent({
    required String titleLabel,
    required DeparturePreset preset,
    Duration duration = defaultSnoozeDuration,
  }) {
    final title = '🧭 Scout (Snoozed +${duration.inMinutes}m): $titleLabel';
    final body =
        '${preset.name} Checklist (${preset.checkedCount}/${preset.totalCount}): ${preset.buildReminderHighlight(maxItems: 4)}';
    return (title: title, body: body);
  }

  /// Inserts or replaces [entry] by [slotKey] while discarding stale snoozes
  /// from prior calendar days that are no longer active.
  static List<DepartureSnooze> mergeAndPrune(
    List<DepartureSnooze> current,
    DepartureSnooze entry,
    DateTime now,
  ) {
    final todayKey = DepartureEvent.formatDateKey(now);
    return current
        .where(
          (s) =>
              s.slotKey != entry.slotKey &&
              (s.dateKey == todayKey || s.isActiveAt(now)),
        )
        .toList()
      ..add(entry);
  }

  /// Removes active today snoozes for [eventIds] while dropping expired days.
  static List<DepartureSnooze> pruneWithout(
    List<DepartureSnooze> current, {
    required Set<String> eventIds,
    required DateTime now,
  }) {
    final todayKey = DepartureEvent.formatDateKey(now);
    return current
        .where(
          (s) =>
              !(s.dateKey == todayKey && eventIds.contains(s.eventId)) &&
              (s.dateKey == todayKey || s.isActiveAt(now)),
        )
        .toList();
  }

  /// Checks off all items in the resolved preset, stamps today's ready key on
  /// matching event(s), and clears any pending today snoozes for them.
  static DepartureMarkAllReadyResult? applyMarkAllReady({
    required List<DeparturePreset> presets,
    required List<DepartureEvent> events,
    required List<DepartureSnooze> snoozes,
    required String presetId,
    String? eventId,
    required DateTime now,
  }) {
    DepartureEvent? matchedEvent;
    var matchedEventIdx = -1;
    if (eventId != null &&
        eventId.isNotEmpty &&
        !eventId.startsWith('active_')) {
      matchedEventIdx = events.indexWhere((e) => e.id == eventId);
      if (matchedEventIdx != -1) {
        matchedEvent = events[matchedEventIdx];
      }
    }

    var targetPresetIdx = presets.indexWhere((p) => p.id == presetId);
    if (targetPresetIdx == -1 && matchedEvent != null) {
      targetPresetIdx =
          presets.indexWhere((p) => p.id == matchedEvent!.presetId);
    }
    if (targetPresetIdx == -1) return null;

    final targetPreset = presets[targetPresetIdx];
    final checkedItems = targetPreset.items
        .map((i) => i.copyWith(isChecked: true))
        .toList();
    final updatedPreset = targetPreset.copyWith(
      items: checkedItems,
      updatedAt: now,
    );

    final updatedPresets = List<DeparturePreset>.from(presets);
    updatedPresets[targetPresetIdx] = updatedPreset;

    final todayKey = DepartureEvent.formatDateKey(now);
    final updatedEvents = List<DepartureEvent>.from(events);
    final clearedEventIds = <String>{
      syntheticEventIdForPreset(updatedPreset.id),
    };

    if (matchedEventIdx != -1) {
      final completed = updatedEvents[matchedEventIdx].copyWith(
        lastCompletedDateKey: todayKey,
        updatedAt: now,
      );
      updatedEvents[matchedEventIdx] = completed;
      clearedEventIds.add(completed.id);
      matchedEvent = completed;
    } else if (eventId == null || eventId.isEmpty) {
      for (var i = 0; i < updatedEvents.length; i++) {
        final ev = updatedEvents[i];
        if (ev.presetId == updatedPreset.id && ev.matchesDate(now)) {
          updatedEvents[i] = ev.copyWith(
            lastCompletedDateKey: todayKey,
            updatedAt: now,
          );
          clearedEventIds.add(ev.id);
        }
      }
    }

    // Clear any active snooze on events sharing this preset since all items are ready.
    for (final ev in updatedEvents) {
      if (ev.presetId == updatedPreset.id) {
        clearedEventIds.add(ev.id);
      }
    }

    final updatedSnoozes = pruneWithout(
      snoozes,
      eventIds: clearedEventIds,
      now: now,
    );

    return DepartureMarkAllReadyResult(
      preset: updatedPreset,
      event: matchedEvent,
      presets: updatedPresets,
      events: updatedEvents,
      snoozes: updatedSnoozes,
      clearedEventIds: clearedEventIds,
    );
  }

  /// Resolves the canonical event ID, preset, and notification title for a
  /// snooze request, returning `null` when a named event no longer exists.
  static ({String eventId, DeparturePreset preset, String titleLabel})?
      resolveSnoozeTarget({
    required List<DeparturePreset> presets,
    required List<DepartureEvent> events,
    required String eventId,
    String? presetId,
  }) {
    if (presets.isEmpty) return null;

    DepartureEvent? event;
    if (eventId.isNotEmpty && !eventId.startsWith('active_')) {
      for (final e in events) {
        if (e.id == eventId) {
          event = e;
          break;
        }
      }
      if (event == null) return null;
    }

    DeparturePreset? preset;
    if (presetId != null && presetId.isNotEmpty) {
      for (final p in presets) {
        if (p.id == presetId) {
          preset = p;
          break;
        }
      }
    }
    if (preset == null && event != null) {
      for (final p in presets) {
        if (p.id == event.presetId) {
          preset = p;
          break;
        }
      }
    }
    preset ??= presets.first;

    final targetEventId =
        eventId.isNotEmpty ? eventId : syntheticEventIdForPreset(preset.id);
    final titleLabel = event?.title ?? '${preset.name} Departure';
    return (eventId: targetEventId, preset: preset, titleLabel: titleLabel);
  }

  DepartureSnooze copyWith({
    String? eventId,
    String? presetId,
    String? dateKey,
    DateTime? snoozedUntil,
    int? snoozeCount,
  }) {
    return DepartureSnooze(
      eventId: eventId ?? this.eventId,
      presetId: presetId ?? this.presetId,
      dateKey: dateKey ?? this.dateKey,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      snoozeCount: snoozeCount ?? this.snoozeCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'presetId': presetId,
        'dateKey': dateKey,
        'snoozedUntil': snoozedUntil.toIso8601String(),
        'snoozeCount': snoozeCount,
      };

  factory DepartureSnooze.fromJson(Map<String, dynamic> json) {
    return DepartureSnooze(
      eventId: json['eventId'] as String? ?? '',
      presetId: json['presetId'] as String? ?? DeparturePreset.everydayPresetId,
      dateKey:
          json['dateKey'] as String? ?? DepartureEvent.formatDateKey(DateTime.now()),
      snoozedUntil: json['snoozedUntil'] != null
          ? DateTime.parse(json['snoozedUntil'] as String)
          : DateTime.now(),
      snoozeCount: (json['snoozeCount'] as num?)?.toInt() ?? 1,
    );
  }
}
