enum FocusPhase {
  work,
  shortBreak,
  longBreak,
}

extension FocusPhaseExtension on FocusPhase {
  String get displayName {
    switch (this) {
      case FocusPhase.work:
        return 'Work Focus';
      case FocusPhase.shortBreak:
        return 'Short Break';
      case FocusPhase.longBreak:
        return 'Long Break';
    }
  }

  String get defaultDurationText {
    switch (this) {
      case FocusPhase.work:
        return '25m';
      case FocusPhase.shortBreak:
        return '5m';
      case FocusPhase.longBreak:
        return '15m';
    }
  }
}

class FocusSessionLog {
  final String id;
  final String taskLabel;
  final int durationMinutes;
  final FocusPhase phase;
  final DateTime completedAt;
  final String? ambientSoundUsed;

  const FocusSessionLog({
    required this.id,
    required this.taskLabel,
    required this.durationMinutes,
    required this.phase,
    required this.completedAt,
    this.ambientSoundUsed,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskLabel': taskLabel,
      'durationMinutes': durationMinutes,
      'phase': phase.name,
      'completedAt': completedAt.toIso8601String(),
      'ambientSoundUsed': ambientSoundUsed,
    };
  }

  factory FocusSessionLog.fromJson(Map<String, dynamic> json) {
    return FocusSessionLog(
      id: json['id'] as String,
      taskLabel: json['taskLabel'] as String? ?? 'Focus Sprint',
      durationMinutes: json['durationMinutes'] as int? ?? 25,
      phase: FocusPhase.values.firstWhere(
        (p) => p.name == json['phase'],
        orElse: () => FocusPhase.work,
      ),
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? '') ??
          DateTime.now(),
      ambientSoundUsed: json['ambientSoundUsed'] as String?,
    );
  }
}
