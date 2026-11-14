enum VitalType {
  heartRate,
  bloodOxygen,
  bloodPressure,
  bodyWeight;

  String get label {
    switch (this) {
      case VitalType.heartRate:
        return 'Heart Rate';
      case VitalType.bloodOxygen:
        return 'Blood Oxygen';
      case VitalType.bloodPressure:
        return 'Blood Pressure';
      case VitalType.bodyWeight:
        return 'Body Weight';
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
    switch (type) {
      case VitalType.heartRate:
        if (primaryValue < 55) return 'Athletic Low';
        if (primaryValue <= 95) return 'Normal Resting';
        return 'Elevated';
      case VitalType.bloodOxygen:
        if (primaryValue >= 95) return 'Optimal SpO2';
        if (primaryValue >= 90) return 'Mildly Low';
        return 'Low Range';
      case VitalType.bloodPressure:
        final dia = secondaryValue ?? 80;
        if (primaryValue < 120 && dia < 80) return 'Normal';
        if (primaryValue < 130 && dia < 80) return 'Elevated';
        return 'High Range';
      case VitalType.bodyWeight:
        return 'Check-In';
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

