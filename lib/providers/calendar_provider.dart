import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/models/calendar_event.dart';
import '../data/models/alarm_category.dart';
import '../data/services/storage_service.dart';

class CalendarProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<CalendarEvent> _events = [];

  CalendarProvider(this._storageService) {
    _loadEvents();
  }

  List<CalendarEvent> get events => List.unmodifiable(_events);

  void _loadEvents() {
    _events = _storageService.loadEvents();
    if (_events.isEmpty) {
      final now = DateTime.now();
      _events = [
        CalendarEvent(
          id: const Uuid().v4(),
          title: 'Project Architecture Review',
          description: 'Evaluate Nestin Everyday Space modules and performance',
          date: DateTime(now.year, now.month, now.day, 10, 0),
          startTime: const TimeOfDay(hour: 10, minute: 0),
          endTime: const TimeOfDay(hour: 11, minute: 30),
          location: 'Virtual Sync Room',
          category: AlarmCategory.fromType(AlarmCategoryType.work),
          hasReminder: true,
          createdAt: now,
        ),
        CalendarEvent(
          id: const Uuid().v4(),
          title: 'Evening Run & Stretch',
          description: '5km jog in the neighborhood park',
          date: DateTime(now.year, now.month, now.day, 18, 0),
          startTime: const TimeOfDay(hour: 18, minute: 0),
          endTime: const TimeOfDay(hour: 19, minute: 0),
          category: AlarmCategory.fromType(AlarmCategoryType.activities),
          hasReminder: false,
          createdAt: now,
        ),
      ];
      _save();
    }
  }

  Future<void> _save() async {
    await _storageService.saveEvents(_events);
    notifyListeners();
  }

  List<CalendarEvent> eventsForDate(DateTime date) {
    return _events.where((e) => e.isSameDay(date)).toList()
      ..sort((a, b) {
        if (a.startTime == null) return -1;
        if (b.startTime == null) return 1;
        return (a.startTime!.hour * 60 + a.startTime!.minute)
            .compareTo(b.startTime!.hour * 60 + b.startTime!.minute);
      });
  }

  List<CalendarEvent> upcomingEvents(DateTime now, {int limit = 5}) {
    final list = _events.where((e) {
      final eventDateTime = DateTime(
        e.date.year,
        e.date.month,
        e.date.day,
        e.startTime?.hour ?? 23,
        e.startTime?.minute ?? 59,
      );
      return eventDateTime.isAfter(now) || e.isSameDay(now);
    }).toList();

    list.sort((a, b) => a.date.compareTo(b.date));
    return list.take(limit).toList();
  }

  Future<void> addEvent(CalendarEvent event) async {
    _events.add(event);
    await _save();
  }

  Future<void> updateEvent(CalendarEvent event) async {
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      _events[index] = event;
      await _save();
    }
  }

  Future<void> deleteEvent(String id) async {
    _events.removeWhere((e) => e.id == id);
    await _save();
  }
}

