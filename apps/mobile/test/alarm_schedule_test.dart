import 'package:flutter_test/flutter_test.dart';
import 'package:nestin/data/models/alarm_schedule.dart';

void main() {
  group('AlarmSchedule Tests', () {
    test('One-time alarm schedules for today if time is in future', () {
      final now = DateTime(2026, 11, 10, 8, 0); // 8:00 AM
      final schedule = AlarmSchedule.oneTime();

      final next = schedule.calculateNextOccurrence(now, 10, 30); // 10:30 AM
      expect(next.year, 2026);
      expect(next.month, 11);
      expect(next.day, 10);
      expect(next.hour, 10);
      expect(next.minute, 30);
    });

    test('One-time alarm rolls to tomorrow if target time already passed today', () {
      final now = DateTime(2026, 11, 10, 14, 0); // 2:00 PM
      final schedule = AlarmSchedule.oneTime();

      final next = schedule.calculateNextOccurrence(now, 7, 0); // 7:00 AM
      expect(next.day, 11); // Tomorrow
      expect(next.hour, 7);
      expect(next.minute, 0);
    });

    test('Weekdays recurrence skips Saturday and Sunday', () {
      // 2026-11-13 is a Friday (weekday = 5)
      final fridayAfternoon = DateTime(2026, 11, 13, 18, 0);
      final schedule = AlarmSchedule.weekdays();

      // Next weekday occurrence after Friday 6:00 PM is Monday (2026-11-16)
      final next = schedule.calculateNextOccurrence(fridayAfternoon, 8, 0);
      expect(next.weekday, DateTime.monday);
      expect(next.day, 16);
      expect(next.hour, 8);
    });

    test('Custom days recurrence accurately finds next selected day', () {
      // Tuesday 2026-11-10 (weekday 2). Select Thursday (4) and Sunday (7).
      final now = DateTime(2026, 11, 10, 10, 0);
      final schedule = AlarmSchedule.customDays({4, 7});

      final next = schedule.calculateNextOccurrence(now, 9, 0);
      expect(next.weekday, DateTime.thursday);
      expect(next.day, 12);
    });

    test('Schedule display text formatting', () {
      expect(AlarmSchedule.oneTime().getDisplayText(), 'Once');
      expect(AlarmSchedule.daily().getDisplayText(), 'Every day');
      expect(AlarmSchedule.weekdays().getDisplayText(), 'Mon - Fri');
      expect(AlarmSchedule.weekends().getDisplayText(), 'Sat, Sun');
      expect(AlarmSchedule.customDays({1, 3, 5}).getDisplayText(), 'Mon, Wed, Fri');
    });
  });
}

