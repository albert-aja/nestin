enum SleepQualityRating {
  poor,
  fair,
  good,
  restorative,
  excellent;

  String get label {
    switch (this) {
      case SleepQualityRating.poor:
        return 'Poor';
      case SleepQualityRating.fair:
        return 'Fair';
      case SleepQualityRating.good:
        return 'Good';
      case SleepQualityRating.restorative:
        return 'Restorative';
      case SleepQualityRating.excellent:
        return 'Excellent';
    }
  }

  String get emoji {
    switch (this) {
      case SleepQualityRating.poor:
        return '😫';
      case SleepQualityRating.fair:
        return '🥱';
      case SleepQualityRating.good:
        return '😌';
      case SleepQualityRating.restorative:
        return '🌙';
      case SleepQualityRating.excellent:
        return '✨';
    }
  }

  int get defaultScore {
    switch (this) {
      case SleepQualityRating.poor:
        return 42;
      case SleepQualityRating.fair:
        return 60;
      case SleepQualityRating.good:
        return 76;
      case SleepQualityRating.restorative:
        return 88;
      case SleepQualityRating.excellent:
        return 95;
    }
  }

  static SleepQualityRating fromScore(int score) {
    if (score >= 92) return SleepQualityRating.excellent;
    if (score >= 82) return SleepQualityRating.restorative;
    if (score >= 68) return SleepQualityRating.good;
    if (score >= 52) return SleepQualityRating.fair;
    return SleepQualityRating.poor;
  }
}

class SleepLog {
  final String id;
  final String dateKey; // YYYY-MM-DD (wake-up date)
  final DateTime bedtime;
  final DateTime wakeTime;
  final int durationMinutes;
  final int deepMinutes;
  final int remMinutes;
  final int lightMinutes;
  final int awakeMinutes;
  final int qualityScore; // 0-100
  final SleepQualityRating qualityRating;
  final List<String> factors;
  final String? notes;
  final bool fromWearable;
  final DateTime createdAt;

  const SleepLog({
    required this.id,
    required this.dateKey,
    required this.bedtime,
    required this.wakeTime,
    required this.durationMinutes,
    this.deepMinutes = 0,
    this.remMinutes = 0,
    this.lightMinutes = 0,
    this.awakeMinutes = 0,
    this.qualityScore = 80,
    this.qualityRating = SleepQualityRating.good,
    this.factors = const [],
    this.notes,
    this.fromWearable = false,
    required this.createdAt,
  });

  /// Formats local date into YYYY-MM-DD key
  static String formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Estimates typical healthy sleep architecture (Deep ~20%, REM ~25%, Light ~55%)
  static ({int deep, int rem, int light}) estimateSleepStages(int totalMinutes) {
    if (totalMinutes <= 0) return (deep: 0, rem: 0, light: 0);
    final deep = (totalMinutes * 0.20).round();
    final rem = (totalMinutes * 0.25).round();
    final light = (totalMinutes - deep - rem).clamp(0, totalMinutes);
    return (deep: deep, rem: rem, light: light);
  }

  /// Computes a transparent 0-100 sleep score based on duration vs target,
  /// sleep efficiency, and optional subjective rating.
  static int computeQualityScore({
    required int durationMinutes,
    int targetMinutes = 450,
    int awakeMinutes = 0,
    SleepQualityRating? rating,
  }) {
    if (durationMinutes <= 0) return 0;
    final durationRatio =
        targetMinutes > 0 ? (durationMinutes / targetMinutes).clamp(0.0, 1.15) : 1.0;
    final durationPoints = (durationRatio.clamp(0.0, 1.0) * 60.0);

    final totalInBed = durationMinutes + awakeMinutes;
    final efficiency = totalInBed > 0 ? (durationMinutes / totalInBed) : 1.0;
    final efficiencyPoints = efficiency * 20.0;

    final subjectivePoints =
        rating != null ? ((rating.defaultScore / 100.0) * 20.0) : 16.0;

    return (durationPoints + efficiencyPoints + subjectivePoints)
        .round()
        .clamp(1, 100);
  }

  double get durationHours => durationMinutes / 60.0;

  String get formattedDuration {
    if (durationMinutes <= 0) return '0m';
    final hrs = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    if (hrs > 0 && mins > 0) return '${hrs}h ${mins}m';
    if (hrs > 0) return '${hrs}h';
    return '${mins}m';
  }

  int get completedCycles => durationMinutes > 0 ? durationMinutes ~/ 90 : 0;

  int get sleepEfficiencyPercent {
    final total = durationMinutes + awakeMinutes;
    if (total <= 0) return 0;
    return ((durationMinutes / total) * 100).round().clamp(0, 100);
  }

  double get deepPercent =>
      durationMinutes > 0 ? (deepMinutes / durationMinutes).clamp(0.0, 1.0) : 0.0;

  double get remPercent =>
      durationMinutes > 0 ? (remMinutes / durationMinutes).clamp(0.0, 1.0) : 0.0;

  double get lightPercent =>
      durationMinutes > 0 ? (lightMinutes / durationMinutes).clamp(0.0, 1.0) : 0.0;

  int sleepDebtMinutes(int targetMinutes) =>
      (targetMinutes - durationMinutes).clamp(0, targetMinutes);

  bool meetsTarget(int targetMinutes) => durationMinutes >= targetMinutes;

  SleepLog copyWith({
    String? id,
    String? dateKey,
    DateTime? bedtime,
    DateTime? wakeTime,
    int? durationMinutes,
    int? deepMinutes,
    int? remMinutes,
    int? lightMinutes,
    int? awakeMinutes,
    int? qualityScore,
    SleepQualityRating? qualityRating,
    List<String>? factors,
    String? notes,
    bool clearNotes = false,
    bool? fromWearable,
    DateTime? createdAt,
  }) {
    return SleepLog(
      id: id ?? this.id,
      dateKey: dateKey ?? this.dateKey,
      bedtime: bedtime ?? this.bedtime,
      wakeTime: wakeTime ?? this.wakeTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      deepMinutes: deepMinutes ?? this.deepMinutes,
      remMinutes: remMinutes ?? this.remMinutes,
      lightMinutes: lightMinutes ?? this.lightMinutes,
      awakeMinutes: awakeMinutes ?? this.awakeMinutes,
      qualityScore: qualityScore ?? this.qualityScore,
      qualityRating: qualityRating ?? this.qualityRating,
      factors: factors ?? this.factors,
      notes: clearNotes ? null : (notes ?? this.notes),
      fromWearable: fromWearable ?? this.fromWearable,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateKey': dateKey,
        'bedtime': bedtime.toIso8601String(),
        'wakeTime': wakeTime.toIso8601String(),
        'durationMinutes': durationMinutes,
        'deepMinutes': deepMinutes,
        'remMinutes': remMinutes,
        'lightMinutes': lightMinutes,
        'awakeMinutes': awakeMinutes,
        'qualityScore': qualityScore,
        'qualityRating': qualityRating.name,
        'factors': factors,
        'notes': notes,
        'fromWearable': fromWearable,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SleepLog.fromJson(Map<String, dynamic> json) {
    final wakeTime =
        DateTime.tryParse(json['wakeTime'] as String? ?? '') ?? DateTime.now();
    final bedtime = DateTime.tryParse(json['bedtime'] as String? ?? '') ??
        wakeTime.subtract(const Duration(hours: 7, minutes: 30));
    final duration = (json['durationMinutes'] as num?)?.toInt() ??
        wakeTime.difference(bedtime).inMinutes.clamp(0, 1440);
    final score = (json['qualityScore'] as num?)?.toInt() ?? 80;

    return SleepLog(
      id: json['id'] as String? ?? '',
      dateKey: json['dateKey'] as String? ?? formatDateKey(wakeTime),
      bedtime: bedtime,
      wakeTime: wakeTime,
      durationMinutes: duration,
      deepMinutes: (json['deepMinutes'] as num?)?.toInt() ?? 0,
      remMinutes: (json['remMinutes'] as num?)?.toInt() ?? 0,
      lightMinutes: (json['lightMinutes'] as num?)?.toInt() ?? 0,
      awakeMinutes: (json['awakeMinutes'] as num?)?.toInt() ?? 0,
      qualityScore: score,
      qualityRating: SleepQualityRating.values.firstWhere(
        (r) => r.name == json['qualityRating'],
        orElse: () => SleepQualityRating.fromScore(score),
      ),
      factors: (json['factors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      notes: json['notes'] as String?,
      fromWearable: json['fromWearable'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

