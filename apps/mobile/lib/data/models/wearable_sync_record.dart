import 'wearable_source.dart';

class WearableSyncRecord {
  final WearablePlatform platform;
  final DateTime syncedAt;
  final DateTime? sleepStartTime;
  final DateTime? sleepEndTime;
  final int? sleepMinutes;
  final int? sleepQualityPercent;
  final int? waterIntakeMl;
  final int? stepCount;
  final int? restingHeartRate;
  final bool isSyncSuccess;
  final String? notes;

  const WearableSyncRecord({
    required this.platform,
    required this.syncedAt,
    this.sleepStartTime,
    this.sleepEndTime,
    this.sleepMinutes,
    this.sleepQualityPercent,
    this.waterIntakeMl,
    this.stepCount,
    this.restingHeartRate,
    this.isSyncSuccess = true,
    this.notes,
  });

  int get sleepCyclesCount {
    if (sleepMinutes == null || sleepMinutes! <= 0) return 0;
    return (sleepMinutes! / 90).floor();
  }

  String get sleepDurationFormatted {
    if (sleepMinutes == null) return '--';
    final hours = sleepMinutes! ~/ 60;
    final mins = sleepMinutes! % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }

  Map<String, dynamic> toJson() => {
        'platform': platform.name,
        'syncedAt': syncedAt.toIso8601String(),
        'sleepStartTime': sleepStartTime?.toIso8601String(),
        'sleepEndTime': sleepEndTime?.toIso8601String(),
        'sleepMinutes': sleepMinutes,
        'sleepQualityPercent': sleepQualityPercent,
        'waterIntakeMl': waterIntakeMl,
        'stepCount': stepCount,
        'restingHeartRate': restingHeartRate,
        'isSyncSuccess': isSyncSuccess,
        'notes': notes,
      };

  factory WearableSyncRecord.fromJson(Map<String, dynamic> json) {
    return WearableSyncRecord(
      platform: WearablePlatform.values.firstWhere(
        (p) => p.name == json['platform'],
        orElse: () => WearablePlatform.simulated,
      ),
      syncedAt: DateTime.tryParse(json['syncedAt'] ?? '') ?? DateTime.now(),
      sleepStartTime: json['sleepStartTime'] != null
          ? DateTime.tryParse(json['sleepStartTime'])
          : null,
      sleepEndTime: json['sleepEndTime'] != null
          ? DateTime.tryParse(json['sleepEndTime'])
          : null,
      sleepMinutes: json['sleepMinutes'] as int?,
      sleepQualityPercent: json['sleepQualityPercent'] as int?,
      waterIntakeMl: json['waterIntakeMl'] as int?,
      stepCount: json['stepCount'] as int?,
      restingHeartRate: json['restingHeartRate'] as int?,
      isSyncSuccess: json['isSyncSuccess'] as bool? ?? true,
      notes: json['notes'] as String?,
    );
  }
}
