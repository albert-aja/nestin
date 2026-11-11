import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestin/domain/nlp/natural_language_date_parser.dart';

void main() {
  group('NaturalLanguageDateParser Tests', () {
    final fixedWednesday = DateTime(2026, 11, 11, 14, 0); // Wednesday

    test('Parses "Sync with team tomorrow at 3pm" correctly', () {
      final res = NaturalLanguageDateParser.parse(
        'Sync with team tomorrow at 3pm',
        referenceDate: fixedWednesday,
      );

      expect(res.hasMatch, isTrue);
      expect(res.cleanTitle, equals('Sync with team'));
      expect(res.date, isNotNull);
      expect(res.date!.year, equals(2026));
      expect(res.date!.month, equals(11));
      expect(res.date!.day, equals(12)); // Thursday
      expect(res.time, isNotNull);
      expect(res.time!.hour, equals(15));
      expect(res.time!.minute, equals(0));
      expect(res.formattedSummary(), contains('Tomorrow at 3:00 PM'));
    });

    test('Parses "Doctor visit Friday at 10:30am" correctly', () {
      final res = NaturalLanguageDateParser.parse(
        'Doctor visit Friday at 10:30am',
        referenceDate: fixedWednesday,
      );

      expect(res.hasMatch, isTrue);
      expect(res.cleanTitle, equals('Doctor visit'));
      expect(res.date!.weekday, equals(DateTime.friday));
      expect(res.date!.day, equals(13));
      expect(res.time!.hour, equals(10));
      expect(res.time!.minute, equals(30));
    });

    test('Parses 24-hour time "Team retro today at 16:00"', () {
      final res = NaturalLanguageDateParser.parse(
        'Team retro today at 16:00',
        referenceDate: fixedWednesday,
      );

      expect(res.hasMatch, isTrue);
      expect(res.cleanTitle, equals('Team retro'));
      expect(res.date!.day, equals(11));
      expect(res.time!.hour, equals(16));
      expect(res.time!.minute, equals(0));
    });

    test('Parses relative days "Dentist in 3 days at 9am"', () {
      final res = NaturalLanguageDateParser.parse(
        'Dentist in 3 days at 9am',
        referenceDate: fixedWednesday,
      );

      expect(res.hasMatch, isTrue);
      expect(res.cleanTitle, equals('Dentist'));
      expect(res.date!.day, equals(14));
      expect(res.time!.hour, equals(9));
      expect(res.time!.minute, equals(0));
    });

    test('Parses "Clean room next Monday"', () {
      final res = NaturalLanguageDateParser.parse(
        'Clean room next Monday',
        referenceDate: fixedWednesday,
      );

      expect(res.hasMatch, isTrue);
      expect(res.cleanTitle, equals('Clean room'));
      expect(res.date!.weekday, equals(DateTime.monday));
      expect(res.date!.isAfter(fixedWednesday), isTrue);
    });

    test('Handles input with no date or time gracefully', () {
      final res = NaturalLanguageDateParser.parse(
        'Buy fresh organic vegetables',
        referenceDate: fixedWednesday,
      );

      expect(res.hasMatch, isFalse);
      expect(res.cleanTitle, equals('Buy fresh organic vegetables'));
      expect(res.date, isNull);
      expect(res.time, isNull);
    });
  });
}

