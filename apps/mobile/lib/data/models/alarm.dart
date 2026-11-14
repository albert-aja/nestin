import 'alarm_category.dart';
import 'alarm_schedule.dart';
import 'challenge_profile.dart';

class Alarm {
  final String id;
  final String title;
  final String description;
  final int hour;
  final int minute;
  final bool isEnabled;
  final AlarmCategory category;
  final AlarmSchedule schedule;

  // Sound & Vibration
  final String sound;
  final String? soundFilePath;
  final double volume; // 0.0 to 1.0
  final bool gradualVolume;
  final int gradualDurationSeconds;
  final bool vibration;

  // Snooze
  final int snoozeMinutes;
  final int maxSnoozeCount;
  final int snoozeCount;
  final DateTime? snoozeUntil;

  // Challenge Configuration & Inheritance
  final bool challengeInherited;
  final WakeUpChallengeProfile? challengeOverride;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Alarm({
    required this.id,
    required this.title,
    this.description = '',
    required this.hour,
    required this.minute,
    this.isEnabled = true,
    required this.category,
    required this.schedule,
    this.sound = 'rooster_dawn',
    this.soundFilePath,
    this.volume = 0.85,
    this.gradualVolume = true,
    this.gradualDurationSeconds = 60,
    this.vibration = true,
    this.snoozeMinutes = 9,
    this.maxSnoozeCount = 3,
    this.snoozeCount = 0,
    this.snoozeUntil,
    this.challengeInherited = true,
    this.challengeOverride,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Resolves the actual challenge profile to apply:
  /// If challengeInherited is true, uses the current global default.
  /// Otherwise, uses the individual alarm override.
  WakeUpChallengeProfile effectiveChallenge(WakeUpChallengeProfile globalProfile) {
    if (category.type != AlarmCategoryType.wakeUp) {
      // Non-wake up alarms don't enforce challenge by default unless overridden
      if (!challengeInherited && challengeOverride != null && challengeOverride!.isEnabled) {
        return challengeOverride!;
      }
      return const WakeUpChallengeProfile(id: 'none', isEnabled: false);
    }

    if (challengeInherited) {
      return globalProfile;
    }
    return challengeOverride ?? globalProfile;
  }

  /// Calculates next occurrence timestamp from reference [now].
  DateTime nextOccurrence(DateTime now) {
    if (snoozeUntil != null && snoozeUntil!.isAfter(now)) {
      return snoozeUntil!;
    }
    return schedule.calculateNextOccurrence(now, hour, minute);
  }

  String formattedTime({bool use24Hour = false}) {
    final hStr = hour.toString().padLeft(2, '0');
    final mStr = minute.toString().padLeft(2, '0');
    if (use24Hour) {
      return '$hStr:$mStr';
    }
    final period = hour >= 12 ? 'PM' : 'AM';
    final standardHour = hour % 12 == 0 ? 12 : hour % 12;
    final standardHStr = standardHour.toString().padLeft(2, '0');
    return '$standardHStr:$mStr $period';
  }

  String timeUntilNext(DateTime now) {
    final next = nextOccurrence(now);
    final diff = next.difference(now);
    if (diff.isNegative) return 'Now';

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;

    if (days > 0) {
      return 'in ${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      return 'in ${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return 'in ${minutes}m';
    } else {
      return 'in less than a minute';
    }
  }

  Alarm copyWith({
    String? id,
    String? title,
    String? description,
    int? hour,
    int? minute,
    bool? isEnabled,
    AlarmCategory? category,
    AlarmSchedule? schedule,
    String? sound,
    String? soundFilePath,
    bool? clearSoundFilePath,
    double? volume,
    bool? gradualVolume,
    int? gradualDurationSeconds,
    bool? vibration,
    int? snoozeMinutes,
    int? maxSnoozeCount,
    int? snoozeCount,
    DateTime? snoozeUntil,
    bool? clearSnoozeUntil,
    bool? challengeInherited,
    WakeUpChallengeProfile? challengeOverride,
    bool? clearChallengeOverride,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Alarm(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      isEnabled: isEnabled ?? this.isEnabled,
      category: category ?? this.category,
      schedule: schedule ?? this.schedule,
      sound: sound ?? this.sound,
      soundFilePath: clearSoundFilePath == true ? null : (soundFilePath ?? this.soundFilePath),
      volume: volume ?? this.volume,
      gradualVolume: gradualVolume ?? this.gradualVolume,
      gradualDurationSeconds:
          gradualDurationSeconds ?? this.gradualDurationSeconds,
      vibration: vibration ?? this.vibration,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      maxSnoozeCount: maxSnoozeCount ?? this.maxSnoozeCount,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      snoozeUntil: clearSnoozeUntil == true ? null : (snoozeUntil ?? this.snoozeUntil),
      challengeInherited: challengeInherited ?? this.challengeInherited,
      challengeOverride: clearChallengeOverride == true
          ? null
          : (challengeOverride ?? this.challengeOverride),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'hour': hour,
      'minute': minute,
      'isEnabled': isEnabled,
      'category': category.toJson(),
      'schedule': schedule.toJson(),
      'sound': sound,
      'soundFilePath': soundFilePath,
      'volume': volume,
      'gradualVolume': gradualVolume,
      'gradualDurationSeconds': gradualDurationSeconds,
      'vibration': vibration,
      'snoozeMinutes': snoozeMinutes,
      'maxSnoozeCount': maxSnoozeCount,
      'snoozeCount': snoozeCount,
      'snoozeUntil': snoozeUntil?.toIso8601String(),
      'challengeInherited': challengeInherited,
      'challengeOverride': challengeOverride?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Alarm.fromJson(Map<String, dynamic> json) {
    return Alarm(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Alarm',
      description: json['description'] as String? ?? '',
      hour: json['hour'] as int? ?? 7,
      minute: json['minute'] as int? ?? 0,
      isEnabled: json['isEnabled'] as bool? ?? true,
      category: AlarmCategory.fromJson(json['category']),
      schedule: AlarmSchedule.fromJson(
        json['schedule'] as Map<String, dynamic>? ?? {},
      ),
      sound: json['sound'] as String? ?? 'rooster_dawn',
      soundFilePath: json['soundFilePath'] as String?,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.85,
      gradualVolume: json['gradualVolume'] as bool? ?? true,
      gradualDurationSeconds: json['gradualDurationSeconds'] as int? ?? 60,
      vibration: json['vibration'] as bool? ?? true,
      snoozeMinutes: json['snoozeMinutes'] as int? ?? 9,
      maxSnoozeCount: json['maxSnoozeCount'] as int? ?? 3,
      snoozeCount: json['snoozeCount'] as int? ?? 0,
      snoozeUntil: json['snoozeUntil'] != null
          ? DateTime.tryParse(json['snoozeUntil'] as String)
          : null,
      challengeInherited: json['challengeInherited'] as bool? ?? true,
      challengeOverride: json['challengeOverride'] != null
          ? WakeUpChallengeProfile.fromJson(
              json['challengeOverride'] as Map<String, dynamic>,
            )
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}

