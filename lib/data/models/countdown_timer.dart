class CountdownTimer {
  final String id;
  final String label;
  final int totalSeconds;
  final int remainingSeconds;
  final bool isRunning;
  final bool isPaused;
  final DateTime? startedAt;

  const CountdownTimer({
    required this.id,
    required this.label,
    required this.totalSeconds,
    required this.remainingSeconds,
    this.isRunning = false,
    this.isPaused = false,
    this.startedAt,
  });

  double get progress {
    if (totalSeconds <= 0) return 0.0;
    return (totalSeconds - remainingSeconds) / totalSeconds;
  }

  bool get isFinished => remainingSeconds <= 0;

  String formattedRemaining() {
    final h = remainingSeconds ~/ 3600;
    final m = (remainingSeconds % 3600) ~/ 60;
    final s = remainingSeconds % 60;

    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String formattedTotal() {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;

    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  CountdownTimer copyWith({
    String? id,
    String? label,
    int? totalSeconds,
    int? remainingSeconds,
    bool? isRunning,
    bool? isPaused,
    DateTime? startedAt,
  }) {
    return CountdownTimer(
      id: id ?? this.id,
      label: label ?? this.label,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'totalSeconds': totalSeconds,
      'remainingSeconds': remainingSeconds,
      'isRunning': isRunning,
      'isPaused': isPaused,
      'startedAt': startedAt?.toIso8601String(),
    };
  }

  factory CountdownTimer.fromJson(Map<String, dynamic> json) {
    return CountdownTimer(
      id: json['id'] as String,
      label: json['label'] as String? ?? 'Timer',
      totalSeconds: json['totalSeconds'] as int? ?? 300,
      remainingSeconds: json['remainingSeconds'] as int? ?? 300,
      isRunning: json['isRunning'] as bool? ?? false,
      isPaused: json['isPaused'] as bool? ?? false,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'] as String)
          : null,
    );
  }
}

