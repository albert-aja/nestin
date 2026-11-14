import '../../core/utils/deterministic_hash.dart' as deterministic;

/// Represents a snoozed dose alert for a specific daily medication slot.
class MedicationSnooze {
  static const String payloadPrefix = 'medication_dose:';

  final String medicationId;
  final String timeString; // Scheduled slot time, e.g. "08:00"
  final String dateKey; // Local calendar date "YYYY-MM-DD"
  final DateTime snoozedUntil;
  final int snoozeCount;

  const MedicationSnooze({
    required this.medicationId,
    required this.timeString,
    required this.dateKey,
    required this.snoozedUntil,
    this.snoozeCount = 1,
  });

  String get slotKey => '$dateKey|$medicationId|$timeString';

  bool isActiveAt(DateTime now) => snoozedUntil.isAfter(now);

  String get formattedSnoozedUntil {
    final hh = snoozedUntil.hour.toString().padLeft(2, '0');
    final mm = snoozedUntil.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Formats a local date as "YYYY-MM-DD" for per-day slot keying.
  static String formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String buildDosePayload(String medicationId, String timeString) =>
      '$payloadPrefix$medicationId:$timeString';

  /// Parses payloads shaped like `` `medication_dose:<medicationId>:<HH:mm>` ``.
  static ({String medicationId, String timeString})? parseDosePayload(
    String? payload,
  ) {
    if (payload == null || !payload.startsWith(payloadPrefix)) return null;
    final rest = payload.substring(payloadPrefix.length);
    final sepIndex = rest.indexOf(':');
    if (sepIndex <= 0 || sepIndex >= rest.length - 1) return null;

    final medicationId = rest.substring(0, sepIndex).trim();
    final timeString = rest.substring(sepIndex + 1).trim();
    if (medicationId.isEmpty || timeString.isEmpty) return null;
    return (medicationId: medicationId, timeString: timeString);
  }

  /// Deterministic FNV-1a 31-bit hash so background and main isolates compute
  /// identical notification IDs without Dart VM per-process hash randomization.
  static int stableHash31(String input) => deterministic.stableHash31(input);

  static int regularDoseNotificationId(
    String medicationId,
    String timeString,
    int dayOffset,
  ) {
    return 10000 +
        (stableHash31('$medicationId|$timeString|$dayOffset') % 90000);
  }

  static int snoozedDoseNotificationId(
    String medicationId,
    String timeString,
    String dateKey,
  ) {
    return 100000 +
        (stableHash31('snooze|$dateKey|$medicationId|$timeString') % 90000);
  }

  /// Inserts or replaces [entry] by [slotKey] while discarding stale snoozes
  /// from prior calendar days that are no longer active.
  static List<MedicationSnooze> mergeAndPrune(
    List<MedicationSnooze> current,
    MedicationSnooze entry,
    DateTime now,
  ) {
    final todayKey = formatDateKey(now);
    final merged = current
        .where((s) =>
            s.slotKey != entry.slotKey &&
            (s.dateKey == todayKey || s.isActiveAt(now)))
        .toList()
      ..add(entry);
    return merged;
  }

  MedicationSnooze copyWith({
    String? medicationId,
    String? timeString,
    String? dateKey,
    DateTime? snoozedUntil,
    int? snoozeCount,
  }) {
    return MedicationSnooze(
      medicationId: medicationId ?? this.medicationId,
      timeString: timeString ?? this.timeString,
      dateKey: dateKey ?? this.dateKey,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      snoozeCount: snoozeCount ?? this.snoozeCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'medicationId': medicationId,
        'timeString': timeString,
        'dateKey': dateKey,
        'snoozedUntil': snoozedUntil.toIso8601String(),
        'snoozeCount': snoozeCount,
      };

  factory MedicationSnooze.fromJson(Map<String, dynamic> json) {
    return MedicationSnooze(
      medicationId: json['medicationId'] as String,
      timeString: json['timeString'] as String? ?? '08:00',
      dateKey: json['dateKey'] as String? ?? formatDateKey(DateTime.now()),
      snoozedUntil: json['snoozedUntil'] != null
          ? DateTime.parse(json['snoozedUntil'] as String)
          : DateTime.now(),
      snoozeCount: (json['snoozeCount'] as num?)?.toInt() ?? 1,
    );
  }
}
