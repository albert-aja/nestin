enum MedicationAction {
  taken,
  skipped,
}

extension MedicationActionExtension on MedicationAction {
  String get label {
    switch (this) {
      case MedicationAction.taken:
        return 'Taken';
      case MedicationAction.skipped:
        return 'Skipped';
    }
  }
}

class MedicationLog {
  final String id;
  final String medicationId;
  final String medicationName;
  final double doseAmount;
  final String doseUnit;
  final String scheduledTimeString; // e.g. "08:00"
  final DateTime scheduledDateTime;
  final DateTime actionTime;
  final MedicationAction action;
  final String? reason;

  const MedicationLog({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.doseAmount,
    required this.doseUnit,
    required this.scheduledTimeString,
    required this.scheduledDateTime,
    required this.actionTime,
    required this.action,
    this.reason,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicationId': medicationId,
      'medicationName': medicationName,
      'doseAmount': doseAmount,
      'doseUnit': doseUnit,
      'scheduledTimeString': scheduledTimeString,
      'scheduledDateTime': scheduledDateTime.toIso8601String(),
      'actionTime': actionTime.toIso8601String(),
      'action': action.name,
      'reason': reason,
    };
  }

  factory MedicationLog.fromJson(Map<String, dynamic> json) {
    MedicationAction parsedAction = MedicationAction.taken;
    if (json['action'] != null) {
      try {
        parsedAction = MedicationAction.values.byName(json['action'] as String);
      } catch (_) {
        parsedAction = MedicationAction.taken;
      }
    }

    return MedicationLog(
      id: json['id'] as String,
      medicationId: json['medicationId'] as String,
      medicationName: json['medicationName'] as String,
      doseAmount: (json['doseAmount'] as num?)?.toDouble() ?? 1.0,
      doseUnit: json['doseUnit'] as String? ?? 'pills',
      scheduledTimeString: json['scheduledTimeString'] as String? ?? '08:00',
      scheduledDateTime: json['scheduledDateTime'] != null
          ? DateTime.parse(json['scheduledDateTime'] as String)
          : DateTime.now(),
      actionTime: json['actionTime'] != null
          ? DateTime.parse(json['actionTime'] as String)
          : DateTime.now(),
      action: parsedAction,
      reason: json['reason'] as String?,
    );
  }
}

