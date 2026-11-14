import 'package:flutter/material.dart';
import 'alarm_category.dart';

enum TaskPriority {
  low,
  medium,
  high,
  urgent,
}

class TaskSubItem {
  final String id;
  final String title;
  final bool isCompleted;

  const TaskSubItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  TaskSubItem copyWith({String? id, String? title, bool? isCompleted}) {
    return TaskSubItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
      };

  factory TaskSubItem.fromJson(Map<String, dynamic> json) => TaskSubItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        isCompleted: json['isCompleted'] as bool? ?? false,
      );
}

class TaskItem {
  final String id;
  final String title;
  final String notes;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime? dueDate;
  final TimeOfDay? dueTime;
  final TaskPriority priority;
  final AlarmCategory category;
  final List<TaskSubItem> subtasks;
  final bool hasReminder;
  final DateTime createdAt;

  const TaskItem({
    required this.id,
    required this.title,
    this.notes = '',
    this.isCompleted = false,
    this.completedAt,
    this.dueDate,
    this.dueTime,
    this.priority = TaskPriority.medium,
    required this.category,
    this.subtasks = const [],
    this.hasReminder = false,
    required this.createdAt,
  });

  bool isOverdue(DateTime now) {
    if (isCompleted || dueDate == null) return false;
    final compareDate = DateTime(
      dueDate!.year,
      dueDate!.month,
      dueDate!.day,
      dueTime?.hour ?? 23,
      dueTime?.minute ?? 59,
    );
    return compareDate.isBefore(now);
  }

  bool isDueToday(DateTime now) {
    if (dueDate == null) return false;
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

  int get completedSubtasksCount =>
      subtasks.where((s) => s.isCompleted).length;

  Color get priorityColor {
    switch (priority) {
      case TaskPriority.urgent:
        return const Color(0xFFEF4444);
      case TaskPriority.high:
        return const Color(0xFFF97316);
      case TaskPriority.medium:
        return const Color(0xFF3B82F6);
      case TaskPriority.low:
        return const Color(0xFF6B7280);
    }
  }

  String get priorityLabel => priority.name.toUpperCase();

  TaskItem copyWith({
    String? id,
    String? title,
    String? notes,
    bool? isCompleted,
    DateTime? completedAt,
    bool? clearCompletedAt,
    DateTime? dueDate,
    bool? clearDueDate,
    TimeOfDay? dueTime,
    bool? clearDueTime,
    TaskPriority? priority,
    AlarmCategory? category,
    List<TaskSubItem>? subtasks,
    bool? hasReminder,
    DateTime? createdAt,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: clearCompletedAt == true
          ? null
          : (completedAt ?? this.completedAt),
      dueDate: clearDueDate == true ? null : (dueDate ?? this.dueDate),
      dueTime: clearDueTime == true ? null : (dueTime ?? this.dueTime),
      priority: priority ?? this.priority,
      category: category ?? this.category,
      subtasks: subtasks ?? this.subtasks,
      hasReminder: hasReminder ?? this.hasReminder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'notes': notes,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'dueTime': dueTime != null ? '${dueTime!.hour}:${dueTime!.minute}' : null,
      'priority': priority.name,
      'category': category.toJson(),
      'subtasks': subtasks.map((s) => s.toJson()).toList(),
      'hasReminder': hasReminder,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseTime(String? str) {
      if (str == null || !str.contains(':')) return null;
      final parts = str.split(':');
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) return TimeOfDay(hour: h, minute: m);
      return null;
    }

    final priorityName = json['priority'] as String? ?? 'medium';
    final prio = TaskPriority.values.firstWhere(
      (p) => p.name == priorityName,
      orElse: () => TaskPriority.medium,
    );

    final rawSub = json['subtasks'] as List<dynamic>? ?? [];
    final subs = rawSub
        .map((s) => TaskSubItem.fromJson(s as Map<String, dynamic>))
        .toList();

    return TaskItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Task',
      notes: json['notes'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String)
          : null,
      dueTime: parseTime(json['dueTime'] as String?),
      priority: prio,
      category: AlarmCategory.fromJson(json['category']),
      subtasks: subs,
      hasReminder: json['hasReminder'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
