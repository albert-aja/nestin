import 'journal_entry.dart';

class ThrowbackItem {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String timeAgoLabel;
  final bool isMemory;
  final JournalMood? mood;
  final String? gratitudeNote;
  final bool isPrivate;
  final bool isMilestone;

  const ThrowbackItem({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.timeAgoLabel,
    this.isMemory = false,
    this.mood,
    this.gratitudeNote,
    this.isPrivate = false,
    this.isMilestone = false,
  });
}

