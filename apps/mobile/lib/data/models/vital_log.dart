import '../../core/l10n/app_localizations.dart';

enum VitalType {
  heartRate,
  bloodOxygen,
  bloodPressure,
  bodyWeight;

  String get label {
    final l10n = AppLocalizations.current;
    switch (this) {
      case VitalType.heartRate:
        return l10n.tr('heart_rate');
      case VitalType.bloodOxygen:
        return l10n.tr('blood_oxygen');
      case VitalType.bloodPressure:
        return l10n.tr('blood_pressure');
      case VitalType.bodyWeight:
        return l10n.tr('body_weight');
    }
  }

  String get unit {
    switch (this) {
      case VitalType.heartRate:
        return 'bpm';
      case VitalType.bloodOxygen:
        return '%';
      case VitalType.bloodPressure:
        return 'mmHg';
      case VitalType.bodyWeight:
        return 'kg';
    }
  }

  String get emoji {
    switch (this) {
      case VitalType.heartRate:
        return '❤️';
      case VitalType.bloodOxygen:
        return '🫁';
      case VitalType.bloodPressure:
        return '🩺';
      case VitalType.bodyWeight:
        return '⚖️';
    }
  }
}

class VitalLog {
  final String id;
  final VitalType type;
  final double primaryValue;
  final double? secondaryValue; // Used for diastolic blood pressure
  final String? note;
  final bool fromWearable;
  final DateTime recordedAt;

  const VitalLog({
    required this.id,
    required this.type,
    required this.primaryValue,
    this.secondaryValue,
    this.note,
    this.fromWearable = false,
    required this.recordedAt,
  });

  String get formattedValue {
    switch (type) {
      case VitalType.bloodPressure:
        final dia = secondaryValue?.round() ?? 80;
        return '${primaryValue.round()}/$dia ${type.unit}';
      case VitalType.bodyWeight:
        return '${primaryValue.toStringAsFixed(1)} ${type.unit}';
      case VitalType.heartRate:
      case VitalType.bloodOxygen:
        return '${primaryValue.round()} ${type.unit}';
    }
  }

  String get statusLabel {
    final l10n = AppLocalizations.current;
    switch (type) {
      case VitalType.heartRate:
        if (primaryValue < 55) return l10n.tr('athletic_low');
        if (primaryValue <= 95) {
          return l10n.tr('normal_resting');
        }
        return l10n.tr('elevated');
      case VitalType.bloodOxygen:
        if (primaryValue >= 95) return l10n.tr('optimal_spo2');
        if (primaryValue >= 90) return l10n.tr('mildly_low');
        return l10n.tr('low_range');
      case VitalType.bloodPressure:
        final dia = secondaryValue ?? 80;
        if (primaryValue < 120 && dia < 80) return l10n.tr('normal');
        if (primaryValue < 130 && dia < 80) {
          return l10n.tr('elevated');
        }
        return l10n.tr('high_range');
      case VitalType.bodyWeight:
        return l10n.tr('check_in');
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'primaryValue': primaryValue,
        'secondaryValue': secondaryValue,
        'note': note,
        'fromWearable': fromWearable,
        'recordedAt': recordedAt.toIso8601String(),
      };

  factory VitalLog.fromJson(Map<String, dynamic> json) {
    return VitalLog(
      id: json['id'] as String? ?? '',
      type: VitalType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => VitalType.heartRate,
      ),
      primaryValue: (json['primaryValue'] as num?)?.toDouble() ?? 0.0,
      secondaryValue: (json['secondaryValue'] as num?)?.toDouble(),
      note: json['note'] as String?,
      fromWearable: json['fromWearable'] as bool? ?? false,
      recordedAt: DateTime.tryParse(json['recordedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

