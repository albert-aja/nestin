enum RoutineType {
  morning,
  evening,
  custom,
}

class RoutineItem {
  final String id;
  final String title;
  final String description;
  final RoutineType type;
  final List<String> steps;
  final Set<int> completedStepIndices;
  final DateTime? lastCompletedDate;
  final int streakCount;
  final DateTime createdAt;

  const RoutineItem({
    required this.id,
    required this.title,
    this.description = '',
    required this.type,
    required this.steps,
    this.completedStepIndices = const {},
    this.lastCompletedDate,
    this.streakCount = 0,
    required this.createdAt,
  });

  bool get isCompletedToday {
    if (steps.isEmpty) return false;
    return completedStepIndices.length >= steps.length;
  }

  double get progress {
    if (steps.isEmpty) return 0.0;
    return (completedStepIndices.length / steps.length).clamp(0.0, 1.0);
  }

  String get typeLabel {
    switch (type) {
      case RoutineType.morning:
        return 'Morning Routine';
      case RoutineType.evening:
        return 'Evening Routine';
      case RoutineType.custom:
        return 'Custom Habit';
    }
  }

  RoutineItem copyWith({
    String? id,
    String? title,
    String? description,
    RoutineType? type,
    List<String>? steps,
    Set<int>? completedStepIndices,
    DateTime? lastCompletedDate,
    int? streakCount,
    DateTime? createdAt,
  }) {
    return RoutineItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      steps: steps ?? this.steps,
      completedStepIndices: completedStepIndices ?? this.completedStepIndices,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      streakCount: streakCount ?? this.streakCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'steps': steps,
      'completedStepIndices': completedStepIndices.toList(),
      'lastCompletedDate': lastCompletedDate?.toIso8601String(),
      'streakCount': streakCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory RoutineItem.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'morning';
    final rType = RoutineType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => RoutineType.morning,
    );

    final rawSteps = (json['steps'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final rawIndices = (json['completedStepIndices'] as List<dynamic>?)?.map((e) => e as int).toSet() ?? {};

    return RoutineItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Routine',
      description: json['description'] as String? ?? '',
      type: rType,
      steps: rawSteps,
      completedStepIndices: rawIndices,
      lastCompletedDate: json['lastCompletedDate'] != null
          ? DateTime.tryParse(json['lastCompletedDate'] as String)
          : null,
      streakCount: json['streakCount'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

