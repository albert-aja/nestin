import 'package:flutter/material.dart';
import 'journal_entry.dart';

/// Represents a single gratitude pebble stored in Echo's Gratitude Jar,
/// derived from a [JournalEntry]'s non-empty [JournalEntry.gratitudeNote].
class GratitudePebble {
  final String entryId;
  final String note;
  final String entryTitle;
  final JournalMood mood;
  final DateTime date;
  final bool isPrivate;
  final bool hasCustomLock;
  final int colorIndex;

  const GratitudePebble({
    required this.entryId,
    required this.note,
    required this.entryTitle,
    required this.mood,
    required this.date,
    required this.isPrivate,
    required this.hasCustomLock,
    required this.colorIndex,
  });

  static const List<Color> palette = [
    Color(0xFFF59E0B), // Warm Amber
    Color(0xFF10B981), // Sea-Glass Emerald
    Color(0xFF38BDF8), // Sky Pebble
    Color(0xFFFB7185), // Dawn Rose
    Color(0xFFA78BFA), // Lavender Quartz
    Color(0xFF2DD4BF), // Coastal Jade
    Color(0xFFF97316), // Terracotta Glow
  ];

  Color get color => palette[colorIndex % palette.length];

  static int deterministicColorIndex(String seed) {
    var hash = 2166136261;
    for (final code in seed.codeUnits) {
      hash ^= code;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash % palette.length;
  }

  factory GratitudePebble.fromJournalEntry(JournalEntry entry) {
    return GratitudePebble(
      entryId: entry.id,
      note: entry.gratitudeNote!.trim(),
      entryTitle: entry.title,
      mood: entry.mood,
      date: entry.date,
      isPrivate: entry.isPrivate,
      hasCustomLock: entry.hasCustomLock,
      colorIndex: deterministicColorIndex(entry.id),
    );
  }
}
