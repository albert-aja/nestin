import 'package:flutter/material.dart';
import 'alarm_category.dart';

class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime date; // Date of event
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String? location;
  final double? budget;
  final bool hasReminder;
  final String? beforeYouGoPresetId;
  final int? departureLeadMinutes;
  final AlarmCategory category;
  final DateTime createdAt;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.description = '',
    required this.date,
    this.startTime,
    this.endTime,
    this.location,
    this.budget,
    this.hasReminder = false,
    this.beforeYouGoPresetId,
    this.departureLeadMinutes,
    required this.category,
    required this.createdAt,
  });

  bool get hasDepartureHeadsUp =>
      beforeYouGoPresetId != null && beforeYouGoPresetId!.isNotEmpty;

  bool isSameDay(DateTime other) {
    return date.year == other.year &&
        date.month == other.month &&
        date.day == other.day;
  }

  String formattedTime() {
    if (startTime == null) return 'All day';
    final h = startTime!.hour.toString().padLeft(2, '0');
    final m = startTime!.minute.toString().padLeft(2, '0');
    if (endTime != null) {
      final eh = endTime!.hour.toString().padLeft(2, '0');
      final em = endTime!.minute.toString().padLeft(2, '0');
      return '$h:$m - $eh:$em';
    }
    return '$h:$m';
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    TimeOfDay? startTime,
    bool? clearStartTime,
    TimeOfDay? endTime,
    bool? clearEndTime,
    String? location,
    double? budget,
    bool? hasReminder,
    String? beforeYouGoPresetId,
    bool? clearBeforeYouGo,
    int? departureLeadMinutes,
    AlarmCategory? category,
    DateTime? createdAt,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      startTime: clearStartTime == true ? null : (startTime ?? this.startTime),
      endTime: clearEndTime == true ? null : (endTime ?? this.endTime),
      location: location ?? this.location,
      budget: budget ?? this.budget,
      hasReminder: hasReminder ?? this.hasReminder,
      beforeYouGoPresetId: clearBeforeYouGo == true
          ? null
          : (beforeYouGoPresetId ?? this.beforeYouGoPresetId),
      departureLeadMinutes: clearBeforeYouGo == true
          ? null
          : (departureLeadMinutes ?? this.departureLeadMinutes),
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'startTime': startTime != null ? '${startTime!.hour}:${startTime!.minute}' : null,
      'endTime': endTime != null ? '${endTime!.hour}:${endTime!.minute}' : null,
      'location': location,
      'budget': budget,
      'hasReminder': hasReminder,
      'beforeYouGoPresetId': beforeYouGoPresetId,
      'departureLeadMinutes': departureLeadMinutes,
      'category': category.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseTime(String? str) {
      if (str == null || !str.contains(':')) return null;
      final parts = str.split(':');
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) return TimeOfDay(hour: h, minute: m);
      return null;
    }

    return CalendarEvent(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Event',
      description: json['description'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      startTime: parseTime(json['startTime'] as String?),
      endTime: parseTime(json['endTime'] as String?),
      location: json['location'] as String?,
      budget: (json['budget'] as num?)?.toDouble(),
      hasReminder: json['hasReminder'] as bool? ?? false,
      beforeYouGoPresetId: json['beforeYouGoPresetId'] as String?,
      departureLeadMinutes: (json['departureLeadMinutes'] as num?)?.toInt(),
      category: AlarmCategory.fromJson(json['category']),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

