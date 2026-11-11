import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/models/reminder.dart';
import '../data/models/alarm_category.dart';
import '../data/services/storage_service.dart';
import '../data/services/notification_service.dart';

class ReminderProvider extends ChangeNotifier {
  final StorageService _storageService;
  final NotificationService _notificationService;

  List<Reminder> _reminders = [];

  ReminderProvider(this._storageService, this._notificationService) {
    _loadReminders();
  }

  List<Reminder> get reminders => List.unmodifiable(_reminders);

  List<Reminder> get pendingReminders =>
      _reminders.where((r) => !r.isCompleted).toList()
        ..sort((a, b) => a.dueDateTime.compareTo(b.dueDateTime));

  List<Reminder> get completedReminders =>
      _reminders.where((r) => r.isCompleted).toList()
        ..sort((a, b) => (b.completedAt ?? b.dueDateTime)
            .compareTo(a.completedAt ?? a.dueDateTime));

  void _loadReminders() {
    _reminders = _storageService.loadReminders();
    if (_reminders.isEmpty) {
      final now = DateTime.now();
      _reminders = [
        Reminder(
          id: const Uuid().v4(),
          title: 'Drink 500ml Water & Stretch',
          notes: 'Hydration goal for peak morning focus',
          dueDateTime: DateTime(now.year, now.month, now.day, 10, 0),
          recurrence: ReminderRecurrence.daily,
          category: AlarmCategory.fromType(AlarmCategoryType.health),
          isCompleted: false,
          createdAt: now,
        ),
        Reminder(
          id: const Uuid().v4(),
          title: 'Review Project Roadmap',
          notes: 'Evaluate sprint backlog with team',
          dueDateTime: DateTime(now.year, now.month, now.day, 14, 30),
          recurrence: ReminderRecurrence.none,
          category: AlarmCategory.fromType(AlarmCategoryType.work),
          isCompleted: false,
          createdAt: now,
        ),
      ];
      _save();
    }
  }

  Future<void> _save() async {
    await _storageService.saveReminders(_reminders);
    _rescheduleNotifications();
    notifyListeners();
  }

  void _rescheduleNotifications() {
    final now = DateTime.now();
    for (final reminder in _reminders) {
      if (reminder.isCompleted || reminder.dueDateTime.isBefore(now)) {
        _notificationService.cancel(reminder.id.hashCode);
        continue;
      }

      _notificationService.scheduleReminderNotification(
        id: reminder.id.hashCode,
        title: reminder.title,
        body: reminder.notes.isNotEmpty ? reminder.notes : 'Nestin Reminder',
        scheduledDate: reminder.dueDateTime,
      );
    }
  }

  Future<void> addReminder(Reminder reminder) async {
    _reminders.add(reminder);
    await _save();
  }

  Future<void> updateReminder(Reminder reminder) async {
    final index = _reminders.indexWhere((r) => r.id == reminder.id);
    if (index != -1) {
      _reminders[index] = reminder;
      await _save();
    }
  }

  Future<void> toggleCompletion(String id) async {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index != -1) {
      final item = _reminders[index];
      final willComplete = !item.isCompleted;

      // If repeating reminder is marked complete, advance due date!
      if (willComplete && item.recurrence != ReminderRecurrence.none) {
        DateTime nextDue = item.dueDateTime;
        if (item.recurrence == ReminderRecurrence.daily) {
          nextDue = nextDue.add(const Duration(days: 1));
        } else if (item.recurrence == ReminderRecurrence.weekdays) {
          do {
            nextDue = nextDue.add(const Duration(days: 1));
          } while (nextDue.weekday == DateTime.saturday ||
              nextDue.weekday == DateTime.sunday);
        } else if (item.recurrence == ReminderRecurrence.weekly) {
          nextDue = nextDue.add(const Duration(days: 7));
        } else if (item.recurrence == ReminderRecurrence.monthly) {
          nextDue = DateTime(
            nextDue.year,
            nextDue.month + 1,
            nextDue.day,
            nextDue.hour,
            nextDue.minute,
          );
        }

        _reminders[index] = item.copyWith(
          dueDateTime: nextDue,
          isCompleted: false,
        );
      } else {
        _reminders[index] = item.copyWith(
          isCompleted: willComplete,
          completedAt: willComplete ? DateTime.now() : null,
          clearCompletedAt: !willComplete,
        );
      }
      await _save();
    }
  }

  Future<void> deleteReminder(String id) async {
    _reminders.removeWhere((r) => r.id == id);
    _notificationService.cancel(id.hashCode);
    await _save();
  }
}

