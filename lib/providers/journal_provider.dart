import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/models/journal_entry.dart';
import '../data/models/memory_item.dart';
import '../data/models/throwback_item.dart';
import '../data/services/storage_service.dart';

class TimelineFeedItem {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String typeTag; // 'Journal', 'Milestone', 'Event'
  final IconData icon;
  final Color color;

  const TimelineFeedItem({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.typeTag,
    required this.icon,
    required this.color,
  });
}

class JournalProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<JournalEntry> _journalEntries = [];
  List<MemoryItem> _memories = [];

  JournalProvider(this._storageService) {
    _loadAll();
  }

  List<JournalEntry> get journalEntries {
    final list = List<JournalEntry>.from(_journalEntries);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<MemoryItem> get memories {
    final list = List<MemoryItem>.from(_memories);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  void _loadAll() {
    _journalEntries = _storageService.loadJournal();
    _memories = _storageService.loadMemories();
    final now = DateTime.now();

    if (_journalEntries.isEmpty) {
      _journalEntries = [
        JournalEntry(
          id: const Uuid().v4(),
          title: 'Clear Morning & Fresh Energy',
          content: 'Woke up right on time with the rooster chime. Solved the math challenge on first try. Feeling energized to build great things today.',
          date: now,
          mood: JournalMood.great,
          tags: const ['Morning', 'Focus', 'Productive'],
          gratitudeNote: 'Grateful for crisp fresh air and good health.',
          createdAt: now,
          updatedAt: now,
        ),
      ];
      _storageService.saveJournal(_journalEntries);
    }

    if (_memories.isEmpty) {
      final oneYearAgo = DateTime(now.year - 1, now.month, now.day, 10, 30);
      _memories = [
        MemoryItem(
          id: const Uuid().v4(),
          title: 'Decided to simplify everyday life',
          description: 'Started the journey to organize daily wake-up rhythm, routines, and personal reflections in one cozy space.',
          date: oneYearAgo,
          tags: const ['Milestone', 'Beginning', 'Nestin'],
          isMilestone: true,
          createdAt: oneYearAgo,
        ),
        MemoryItem(
          id: const Uuid().v4(),
          title: 'Nestin Everyday Space Evolution',
          description: 'Preserved the core smart alarm foundation while expanding into a unified personal life companion.',
          date: now,
          tags: const ['Milestone', 'Project', 'Evolution'],
          isMilestone: true,
          createdAt: now,
        ),
      ];
      _storageService.saveMemories(_memories);
    }
  }

  List<TimelineFeedItem> getUnifiedTimeline() {
    final items = <TimelineFeedItem>[];

    for (final j in _journalEntries) {
      items.add(
        TimelineFeedItem(
          id: j.id,
          title: j.title.isNotEmpty ? j.title : 'Journal Entry',
          description: j.content,
          date: j.date,
          typeTag: '${j.mood.emoji} ${j.mood.label}',
          icon: Icons.book_outlined,
          color: const Color(0xFFFF9E1B),
        ),
      );
    }

    for (final m in _memories) {
      items.add(
        TimelineFeedItem(
          id: m.id,
          title: m.title,
          description: m.description,
          date: m.date,
          typeTag: m.isMilestone ? '⭐ Milestone' : 'Memory',
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFFE04A3A),
        ),
      );
    }

    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  List<ThrowbackItem> getThrowbackMemories({DateTime? forDate}) {
    final target = forDate ?? DateTime.now();
    final results = <ThrowbackItem>[];

    // 1. Look for memories from exact same calendar day in past years
    for (final j in _journalEntries) {
      if (j.date.month == target.month &&
          j.date.day == target.day &&
          j.date.year != target.year) {
        final yearsDiff = target.year - j.date.year;
        final label = yearsDiff == 1
            ? '1 year ago today'
            : '$yearsDiff years ago today';
        results.add(
          ThrowbackItem(
            id: j.id,
            title: j.title.isNotEmpty ? j.title : 'Journal Reflection',
            content: j.content,
            date: j.date,
            timeAgoLabel: label,
            isMemory: false,
            mood: j.mood,
            gratitudeNote: j.gratitudeNote,
            isPrivate: j.isPrivate,
          ),
        );
      }
    }

    for (final m in _memories) {
      if (m.date.month == target.month &&
          m.date.day == target.day &&
          m.date.year != target.year) {
        final yearsDiff = target.year - m.date.year;
        final label = yearsDiff == 1
            ? '1 year ago today'
            : '$yearsDiff years ago today';
        results.add(
          ThrowbackItem(
            id: m.id,
            title: m.title,
            content: m.description,
            date: m.date,
            timeAgoLabel: label,
            isMemory: true,
            isMilestone: m.isMilestone,
          ),
        );
      }
    }

    // 2. Fallback: If no past years found on this date, check same day in past months
    if (results.isEmpty) {
      for (final j in _journalEntries) {
        if (j.date.day == target.day &&
            (j.date.month != target.month || j.date.year != target.year)) {
          final totalMonths =
              (target.year - j.date.year) * 12 + (target.month - j.date.month);
          if (totalMonths > 0) {
            final label = totalMonths == 1
                ? '1 month ago today'
                : '$totalMonths months ago today';
            results.add(
              ThrowbackItem(
                id: j.id,
                title: j.title.isNotEmpty ? j.title : 'Journal Reflection',
                content: j.content,
                date: j.date,
                timeAgoLabel: label,
                isMemory: false,
                mood: j.mood,
                gratitudeNote: j.gratitudeNote,
                isPrivate: j.isPrivate,
              ),
            );
          }
        }
      }

      for (final m in _memories) {
        if (m.date.day == target.day &&
            (m.date.month != target.month || m.date.year != target.year)) {
          final totalMonths =
              (target.year - m.date.year) * 12 + (target.month - m.date.month);
          if (totalMonths > 0) {
            final label = totalMonths == 1
                ? '1 month ago today'
                : '$totalMonths months ago today';
            results.add(
              ThrowbackItem(
                id: m.id,
                title: m.title,
                content: m.description,
                date: m.date,
                timeAgoLabel: label,
                isMemory: true,
                isMilestone: m.isMilestone,
              ),
            );
          }
        }
      }
    }

    results.sort((a, b) => b.date.compareTo(a.date));
    return results;
  }

  Future<void> addJournalEntry(JournalEntry entry) async {
    _journalEntries.add(entry);
    await _storageService.saveJournal(_journalEntries);
    notifyListeners();
  }

  Future<void> updateJournalEntry(JournalEntry entry) async {
    final index = _journalEntries.indexWhere((j) => j.id == entry.id);
    if (index != -1) {
      _journalEntries[index] = entry.copyWith(updatedAt: DateTime.now());
      await _storageService.saveJournal(_journalEntries);
      notifyListeners();
    }
  }

  Future<void> deleteJournalEntry(String id) async {
    _journalEntries.removeWhere((j) => j.id == id);
    await _storageService.saveJournal(_journalEntries);
    notifyListeners();
  }

  Future<void> addMemory(MemoryItem memory) async {
    _memories.add(memory);
    await _storageService.saveMemories(_memories);
    notifyListeners();
  }

  Future<void> deleteMemory(String id) async {
    _memories.removeWhere((m) => m.id == id);
    await _storageService.saveMemories(_memories);
    notifyListeners();
  }
}

