import 'package:flutter/material.dart';

/// Preset stimulant categories with approximate caffeine content (mg).
enum StimulantType {
  espresso(
    defaultMg: 63,
    emoji: '☕',
    enName: 'Espresso',
    idName: 'Espresso',
    shortEn: 'Espresso',
    shortId: 'Espresso',
    colorHex: 0xFFD97706,
  ),
  coffee(
    defaultMg: 95,
    emoji: '☕',
    enName: 'Coffee',
    idName: 'Kopi',
    shortEn: 'Coffee',
    shortId: 'Kopi',
    colorHex: 0xFFB45309,
  ),
  matcha(
    defaultMg: 70,
    emoji: '🍵',
    enName: 'Matcha',
    idName: 'Matcha',
    shortEn: 'Matcha',
    shortId: 'Matcha',
    colorHex: 0xFF10B981,
  ),
  tea(
    defaultMg: 45,
    emoji: '🫖',
    enName: 'Tea',
    idName: 'Teh',
    shortEn: 'Tea',
    shortId: 'Teh',
    colorHex: 0xFF14B8A6,
  ),
  soda(
    defaultMg: 35,
    emoji: '🥤',
    enName: 'Soda',
    idName: 'Soda',
    shortEn: 'Soda',
    shortId: 'Soda',
    colorHex: 0xFFEC4899,
  ),
  custom(
    defaultMg: 80,
    emoji: '⚡',
    enName: 'Custom',
    idName: 'Kustom',
    shortEn: 'Custom',
    shortId: 'Kustom',
    colorHex: 0xFF8B5CF6,
  );

  const StimulantType({
    required this.defaultMg,
    required this.emoji,
    required this.enName,
    required this.idName,
    required this.shortEn,
    required this.shortId,
    required this.colorHex,
  });

  final int defaultMg;
  final String emoji;
  final String enName;
  final String idName;
  final String shortEn;
  final String shortId;
  final int colorHex;

  Color get color => Color(colorHex);

  String localizedName({required bool isIndonesian}) =>
      isIndonesian ? idName : enName;

  static StimulantType fromName(String? raw) {
    for (final value in StimulantType.values) {
      if (value.name == raw) return value;
    }
    return StimulantType.coffee;
  }
}

/// Single logged caffeine intake serving.
class CaffeineEntry {
  final String id;
  final StimulantType type;
  final String label;
  final int caffeineMg;
  final DateTime consumedAt;
  final String? note;

  const CaffeineEntry({
    required this.id,
    required this.type,
    required this.label,
    required this.caffeineMg,
    required this.consumedAt,
    this.note,
  });

  CaffeineEntry copyWith({
    String? id,
    StimulantType? type,
    String? label,
    int? caffeineMg,
    DateTime? consumedAt,
    String? note,
    bool clearNote = false,
  }) {
    return CaffeineEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      caffeineMg: caffeineMg ?? this.caffeineMg,
      consumedAt: consumedAt ?? this.consumedAt,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'label': label,
      'caffeineMg': caffeineMg,
      'consumedAt': consumedAt.toIso8601String(),
      if (note != null && note!.isNotEmpty) 'note': note,
    };
  }

  factory CaffeineEntry.fromJson(Map<String, dynamic> json) {
    final parsedType = StimulantType.fromName(json['type'] as String?);
    return CaffeineEntry(
      id: (json['id'] as String?) ?? '',
      type: parsedType,
      label: (json['label'] as String?) ?? parsedType.enName,
      caffeineMg: (json['caffeineMg'] as num?)?.toInt() ?? parsedType.defaultMg,
      consumedAt: DateTime.tryParse(json['consumedAt'] as String? ?? '') ??
          DateTime.now(),
      note: json['note'] as String?,
    );
  }
}

/// User configuration for caffeine tracking, half-life model, and afternoon curfew nudge.
class CaffeineConfig {
  final bool curfewEnabled;
  final int curfewHour;
  final int curfewMinute;

  /// When true, computes the curfew time dynamically as [bedtimeCutOffLeadHours]
  /// before tonight's [SleepCycleSheet] target bedtime.
  final bool syncCurfewWithBedtime;
  final int bedtimeCutOffLeadHours;
  final int dailyLimitMg;
  final int bedtimeSafeThresholdMg;
  final double halfLifeHours;

  const CaffeineConfig({
    this.curfewEnabled = true,
    this.curfewHour = 14,
    this.curfewMinute = 0,
    this.syncCurfewWithBedtime = false,
    this.bedtimeCutOffLeadHours = 8,
    this.dailyLimitMg = 400,
    this.bedtimeSafeThresholdMg = 50,
    this.halfLifeHours = 5.0,
  });

  factory CaffeineConfig.initial() => const CaffeineConfig();

  String get formattedCurfewTime =>
      '${curfewHour.toString().padLeft(2, '0')}:${curfewMinute.toString().padLeft(2, '0')}';

  CaffeineConfig copyWith({
    bool? curfewEnabled,
    int? curfewHour,
    int? curfewMinute,
    bool? syncCurfewWithBedtime,
    int? bedtimeCutOffLeadHours,
    int? dailyLimitMg,
    int? bedtimeSafeThresholdMg,
    double? halfLifeHours,
  }) {
    return CaffeineConfig(
      curfewEnabled: curfewEnabled ?? this.curfewEnabled,
      curfewHour: (curfewHour ?? this.curfewHour).clamp(0, 23),
      curfewMinute: (curfewMinute ?? this.curfewMinute).clamp(0, 59),
      syncCurfewWithBedtime:
          syncCurfewWithBedtime ?? this.syncCurfewWithBedtime,
      bedtimeCutOffLeadHours:
          (bedtimeCutOffLeadHours ?? this.bedtimeCutOffLeadHours).clamp(4, 14),
      dailyLimitMg: (dailyLimitMg ?? this.dailyLimitMg).clamp(50, 1000),
      bedtimeSafeThresholdMg:
          (bedtimeSafeThresholdMg ?? this.bedtimeSafeThresholdMg).clamp(10, 200),
      halfLifeHours:
          (halfLifeHours ?? this.halfLifeHours).clamp(2.5, 10.0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'curfewEnabled': curfewEnabled,
      'curfewHour': curfewHour,
      'curfewMinute': curfewMinute,
      'syncCurfewWithBedtime': syncCurfewWithBedtime,
      'bedtimeCutOffLeadHours': bedtimeCutOffLeadHours,
      'dailyLimitMg': dailyLimitMg,
      'bedtimeSafeThresholdMg': bedtimeSafeThresholdMg,
      'halfLifeHours': halfLifeHours,
    };
  }

  factory CaffeineConfig.fromJson(Map<String, dynamic> json) {
    return CaffeineConfig(
      curfewEnabled: json['curfewEnabled'] as bool? ?? true,
      curfewHour: (json['curfewHour'] as num?)?.toInt() ?? 14,
      curfewMinute: (json['curfewMinute'] as num?)?.toInt() ?? 0,
      syncCurfewWithBedtime:
          json['syncCurfewWithBedtime'] as bool? ?? false,
      bedtimeCutOffLeadHours:
          (json['bedtimeCutOffLeadHours'] as num?)?.toInt() ?? 8,
      dailyLimitMg: (json['dailyLimitMg'] as num?)?.toInt() ?? 400,
      bedtimeSafeThresholdMg:
          (json['bedtimeSafeThresholdMg'] as num?)?.toInt() ?? 50,
      halfLifeHours: (json['halfLifeHours'] as num?)?.toDouble() ?? 5.0,
    );
  }
}
