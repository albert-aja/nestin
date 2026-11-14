import 'challenge_profile.dart';

class WakeUpLog {
  final String id;
  final String alarmId;
  final String alarmTitle;
  final DateTime scheduledTime;
  final DateTime dismissedAt;
  final int snoozeCount;
  final bool challengeSolved;
  final ChallengeType? challengeType;
  final int solveDurationSeconds;

  const WakeUpLog({
    required this.id,
    required this.alarmId,
    required this.alarmTitle,
    required this.scheduledTime,
    required this.dismissedAt,
    this.snoozeCount = 0,
    this.challengeSolved = false,
    this.challengeType,
    this.solveDurationSeconds = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'alarmId': alarmId,
      'alarmTitle': alarmTitle,
      'scheduledTime': scheduledTime.toIso8601String(),
      'dismissedAt': dismissedAt.toIso8601String(),
      'snoozeCount': snoozeCount,
      'challengeSolved': challengeSolved,
      'challengeType': challengeType?.name,
      'solveDurationSeconds': solveDurationSeconds,
    };
  }

  factory WakeUpLog.fromJson(Map<String, dynamic> json) {
    final typeName = json['challengeType'] as String?;
    return WakeUpLog(
      id: json['id'] as String,
      alarmId: json['alarmId'] as String? ?? '',
      alarmTitle: json['alarmTitle'] as String? ?? 'Alarm',
      scheduledTime: json['scheduledTime'] != null
          ? DateTime.parse(json['scheduledTime'] as String)
          : DateTime.now(),
      dismissedAt: json['dismissedAt'] != null
          ? DateTime.parse(json['dismissedAt'] as String)
          : DateTime.now(),
      snoozeCount: json['snoozeCount'] as int? ?? 0,
      challengeSolved: json['challengeSolved'] as bool? ?? false,
      challengeType: typeName != null
          ? ChallengeType.values.firstWhere(
              (e) => e.name == typeName,
              orElse: () => ChallengeType.math,
            )
          : null,
      solveDurationSeconds: json['solveDurationSeconds'] as int? ?? 0,
    );
  }
}

