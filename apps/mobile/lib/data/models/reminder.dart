import 'package:intl/intl.dart';
import 'alarm_category.dart';

enum ReminderRecurrence {
  none,
  daily,
  weekdays,
  weekly,
  monthly,
}

class Reminder {
  final String id;
  final String title;
  final String notes;
  final DateTime dueDateTime;
  final ReminderRecurrence recurrence;
  final AlarmCategory category;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;

  const Reminder({
    required this.id,
    required this.title,
    this.notes = '',
    required this.dueDateTime,
    this.recurrence = ReminderRecurrence.none,
    required this.category,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
  });

  bool isOverdue(DateTime now) {
    if (isCompleted) return false;
    return dueDateTime.isBefore(now);
  }

  String formattedDueDate() {
    return DateFormat('EEE, MMM d, yyyy').format(dueDateTime);
  }

  String formattedDueTime({bool use24Hour = false}) {
    return use24Hour
        ? DateFormat('HH:mm').format(dueDateTime)
        : DateFormat('hh:mm a').format(dueDateTime);
  }

  String recurrenceLabel() {
    switch (recurrence) {
      case ReminderRecurrence.none:
        return 'No recurrence';
      case ReminderRecurrence.daily:
        return 'Repeats Daily';
      case ReminderRecurrence.weekdays:
        return 'Repeats Weekdays';
      case ReminderRecurrence.weekly:
        return 'Repeats Weekly';
      case ReminderRecurrence.monthly:
        return 'Repeats Monthly';
    }
  }

  Reminder copyWith({
    String? id,
    String? title,
    String? notes,
    DateTime? dueDateTime,
    ReminderRecurrence? recurrence,
    AlarmCategory? category,
    bool? isCompleted,
    DateTime? completedAt,
    bool? clearCompletedAt,
    DateTime? createdAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueDateTime: dueDateTime ?? this.dueDateTime,
      recurrence: recurrence ?? this.recurrence,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: clearCompletedAt == true ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'notes': notes,
      'dueDateTime': dueDateTime.toIso8601String(),
      'recurrence': recurrence.name,
      'category': category.toJson(),
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    final recName = json['recurrence'] as String? ?? 'none';
    final rec = ReminderRecurrence.values.firstWhere(
      (e) => e.name == recName,
      orElse: () => ReminderRecurrence.none,
    );
    return Reminder(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Reminder',
      notes: json['notes'] as String? ?? '',
      dueDateTime: json['dueDateTime'] != null
          ? DateTime.parse(json['dueDateTime'] as String)
          : DateTime.now().add(const Duration(hours: 1)),
      recurrence: rec,
      category: AlarmCategory.fromJson(json['category']),
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

