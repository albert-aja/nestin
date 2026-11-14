import 'package:flutter/material.dart';

class ParsedDateResult {
  final String originalText;
  final String cleanTitle;
  final DateTime? date;
  final TimeOfDay? time;
  final String? matchedSnippet;
  final bool hasMatch;
  final DateTime? referenceDate;

  const ParsedDateResult({
    required this.originalText,
    required this.cleanTitle,
    this.date,
    this.time,
    this.matchedSnippet,
    this.hasMatch = false,
    this.referenceDate,
  });

  String formattedSummary([DateTime? ref]) {
    if (!hasMatch) return '';
    final parts = <String>[];
    if (date != null) {
      final now = ref ?? referenceDate ?? DateTime.now();
      final diffDays = DateTime(date!.year, date!.month, date!.day)
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;

      if (diffDays == 0) {
        parts.add('Today');
      } else if (diffDays == 1) {
        parts.add('Tomorrow');
      } else if (diffDays == 2) {
        parts.add('In 2 days');
      } else {
        const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        parts.add('${weekdays[date!.weekday - 1]}, ${months[date!.month - 1]} ${date!.day}');
      }
    }

    if (time != null) {
      final hour = time!.hourOfPeriod == 0 ? 12 : time!.hourOfPeriod;
      final minute = time!.minute.toString().padLeft(2, '0');
      final period = time!.period == DayPeriod.am ? 'AM' : 'PM';
      parts.add('at $hour:$minute $period');
    }

    return parts.join(' ');
  }
}

class NaturalLanguageDateParser {
  static ParsedDateResult parse(String input, {DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    final text = input.trim();
    if (text.isEmpty) {
      return ParsedDateResult(
        originalText: input,
        cleanTitle: input,
        hasMatch: false,
      );
    }

    DateTime? detectedDate;
    TimeOfDay? detectedTime;
    final matchedTokens = <String>[];

    // 1. Time parsing (12-hour AM/PM and 24-hour HH:mm)
    // Matches: "at 3:30pm", "at 3pm", "3:30pm", "3pm", "at 15:00", "15:00"
    final time12Regex = RegExp(
      r'\b(?:at\s+)?([0-1]?[0-9])(?::([0-5][0-9]))?\s*(am|pm)\b',
      caseSensitive: false,
    );
    final time24Regex = RegExp(
      r'\b(?:at\s+)?([0-2]?[0-9]):([0-5][0-9])\b',
      caseSensitive: false,
    );
    final noonMidnightRegex = RegExp(
      r'\b(?:at\s+)?(noon|midday|midnight)\b',
      caseSensitive: false,
    );

    final match12 = time12Regex.firstMatch(text);
    if (match12 != null) {
      var hour = int.parse(match12.group(1)!);
      final minute = match12.group(2) != null ? int.parse(match12.group(2)!) : 0;
      final period = match12.group(3)!.toLowerCase();

      if (period == 'pm' && hour < 12) hour += 12;
      if (period == 'am' && hour == 12) hour = 0;

      detectedTime = TimeOfDay(hour: hour, minute: minute);
      matchedTokens.add(match12.group(0)!);
    } else {
      final match24 = time24Regex.firstMatch(text);
      if (match24 != null) {
        final hour = int.parse(match24.group(1)!);
        final minute = int.parse(match24.group(2)!);
        if (hour < 24 && minute < 60) {
          detectedTime = TimeOfDay(hour: hour, minute: minute);
          matchedTokens.add(match24.group(0)!);
        }
      } else {
        final matchNoon = noonMidnightRegex.firstMatch(text);
        if (matchNoon != null) {
          final word = matchNoon.group(1)!.toLowerCase();
          if (word == 'noon' || word == 'midday') {
            detectedTime = const TimeOfDay(hour: 12, minute: 0);
          } else if (word == 'midnight') {
            detectedTime = const TimeOfDay(hour: 0, minute: 0);
          }
          matchedTokens.add(matchNoon.group(0)!);
        }
      }
    }

    // 2. Relative Period of Day (in the morning, this afternoon, tonight)
    if (detectedTime == null) {
      final periodRegex = RegExp(
        r'\b(?:in\s+the\s+morning|this\s+morning)\b',
        caseSensitive: false,
      );
      final afternoonRegex = RegExp(
        r'\b(?:in\s+the\s+afternoon|this\s+afternoon)\b',
        caseSensitive: false,
      );
      final eveningRegex = RegExp(
        r'\b(?:in\s+the\s+evening|this\s+evening|tonight)\b',
        caseSensitive: false,
      );

      final pMorning = periodRegex.firstMatch(text);
      if (pMorning != null) {
        detectedTime = const TimeOfDay(hour: 9, minute: 0);
        matchedTokens.add(pMorning.group(0)!);
      } else {
        final pAfternoon = afternoonRegex.firstMatch(text);
        if (pAfternoon != null) {
          detectedTime = const TimeOfDay(hour: 14, minute: 0);
          matchedTokens.add(pAfternoon.group(0)!);
        } else {
          final pEvening = eveningRegex.firstMatch(text);
          if (pEvening != null) {
            detectedTime = const TimeOfDay(hour: 20, minute: 0);
            matchedTokens.add(pEvening.group(0)!);
          }
        }
      }
    }

    // 3. Date Parsing
    // Relative Days: "today", "tomorrow", "tmrw", "day after tomorrow"
    final dayAfterTomorrowRegex = RegExp(
      r'\b(?:on\s+)?(?:the\s+)?day\s+after\s+tomorrow\b',
      caseSensitive: false,
    );
    final tomorrowRegex = RegExp(
      r'\b(?:on\s+)?(?:tomorrow|tmrw)\b',
      caseSensitive: false,
    );
    final todayRegex = RegExp(
      r'\b(?:on\s+)?today\b',
      caseSensitive: false,
    );

    final mDayAfter = dayAfterTomorrowRegex.firstMatch(text);
    if (mDayAfter != null) {
      detectedDate = DateTime(now.year, now.month, now.day + 2);
      matchedTokens.add(mDayAfter.group(0)!);
    } else {
      final mTomorrow = tomorrowRegex.firstMatch(text);
      if (mTomorrow != null) {
        detectedDate = DateTime(now.year, now.month, now.day + 1);
        matchedTokens.add(mTomorrow.group(0)!);
      } else {
        final mToday = todayRegex.firstMatch(text);
        if (mToday != null) {
          detectedDate = DateTime(now.year, now.month, now.day);
          matchedTokens.add(mToday.group(0)!);
        }
      }
    }

    // "in X days" / "in a day" / "in a week" / "in X weeks"
    if (detectedDate == null) {
      final inDaysRegex = RegExp(
        r'\bin\s+(\d+|a|an)\s+(days?|weeks?)\b',
        caseSensitive: false,
      );
      final mInDays = inDaysRegex.firstMatch(text);
      if (mInDays != null) {
        final countStr = mInDays.group(1)!.toLowerCase();
        final unit = mInDays.group(2)!.toLowerCase();
        final count = (countStr == 'a' || countStr == 'an')
            ? 1
            : int.tryParse(countStr) ?? 1;

        if (unit.startsWith('week')) {
          detectedDate = DateTime(now.year, now.month, now.day + (count * 7));
        } else {
          detectedDate = DateTime(now.year, now.month, now.day + count);
        }
        matchedTokens.add(mInDays.group(0)!);
      }
    }

    // Weekdays: "next Monday", "this Friday", "on Wednesday", "Friday"
    if (detectedDate == null) {
      final weekdayRegex = RegExp(
        r'\b(?:on\s+)?(this\s+|next\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\b',
        caseSensitive: false,
      );
      final mWeekday = weekdayRegex.firstMatch(text);
      if (mWeekday != null) {
        final modifier = mWeekday.group(1)?.toLowerCase().trim();
        final dayName = mWeekday.group(2)!.toLowerCase();
        final targetWeekday = _parseWeekdayNumber(dayName);

        if (targetWeekday != null) {
          var diff = targetWeekday - now.weekday;
          if (modifier == 'next') {
            if (diff <= 0) diff += 7;
            diff += 7; // strictly next week
          } else {
            // "this" or unspecified: next occurrence
            if (diff <= 0) diff += 7;
          }
          detectedDate = DateTime(now.year, now.month, now.day + diff);
          matchedTokens.add(mWeekday.group(0)!);
        }
      }
    }

    // If time was detected without explicit date, default date to today
    if (detectedTime != null && detectedDate == null) {
      detectedDate = DateTime(now.year, now.month, now.day);
    }

    final hasMatch = detectedDate != null || detectedTime != null;

    // Clean title by stripping matched tokens
    var cleanTitle = text;
    for (final token in matchedTokens) {
      cleanTitle = cleanTitle.replaceAll(token, ' ');
    }

    // Clean up leftover prepositions at end/start, double spaces
    cleanTitle = cleanTitle
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s+(?:at|on|by|for)\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'^(?:at|on|by|for)\s+', caseSensitive: false), '')
        .trim();

    if (cleanTitle.isEmpty) {
      cleanTitle = text; // fallback if user only typed date/time
    }

    final matchedSnippet = matchedTokens.isNotEmpty
        ? matchedTokens.join(' ')
        : null;

    return ParsedDateResult(
      originalText: text,
      cleanTitle: cleanTitle,
      date: detectedDate,
      time: detectedTime,
      matchedSnippet: matchedSnippet,
      hasMatch: hasMatch,
      referenceDate: now,
    );
  }

  static int? _parseWeekdayNumber(String name) {
    if (name.startsWith('mon')) return DateTime.monday;
    if (name.startsWith('tue')) return DateTime.tuesday;
    if (name.startsWith('wed')) return DateTime.wednesday;
    if (name.startsWith('thu')) return DateTime.thursday;
    if (name.startsWith('fri')) return DateTime.friday;
    if (name.startsWith('sat')) return DateTime.saturday;
    if (name.startsWith('sun')) return DateTime.sunday;
    return null;
  }
}

