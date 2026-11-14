import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/data/models/calendar_event.dart';
import 'package:nestin/data/models/task_item.dart';
import 'package:nestin/data/models/routine_item.dart';
import 'package:nestin/data/models/note_item.dart';
import 'package:nestin/data/models/collection_item.dart';
import 'package:nestin/data/models/wishlist_item.dart';
import 'package:nestin/data/models/journal_entry.dart';
import 'package:nestin/data/models/dashboard_config.dart';
import 'package:nestin/data/models/alarm_category.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/domain/sleep/sleep_cycle_calculator.dart';
import 'package:nestin/providers/dashboard_provider.dart';
import 'package:nestin/data/models/user_preferences.dart';
import 'package:nestin/data/models/journal_prompt.dart';
import 'package:nestin/data/models/memory_item.dart';
import 'package:nestin/providers/journal_provider.dart';
import 'package:nestin/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Expansion Domain Models Tests', () {
    test('CalendarEvent serializes and deserializes correctly', () {
      final now = DateTime.now();
      final event = CalendarEvent(
        id: 'evt-1',
        title: 'Team Architecture Review',
        description: 'Verify Nestin Everyday modules',
        date: DateTime(2026, 11, 15, 14, 0),
        startTime: const TimeOfDay(hour: 14, minute: 0),
        endTime: const TimeOfDay(hour: 15, minute: 30),
        location: 'Design Studio Room 4',
        category: AlarmCategory.fromType(AlarmCategoryType.work),
        hasReminder: true,
        createdAt: now,
      );

      final json = event.toJson();
      final revived = CalendarEvent.fromJson(json);

      expect(revived.id, equals('evt-1'));
      expect(revived.title, equals('Team Architecture Review'));
      expect(revived.startTime?.hour, equals(14));
      expect(revived.endTime?.minute, equals(30));
      expect(revived.location, equals('Design Studio Room 4'));
      expect(revived.isSameDay(DateTime(2026, 11, 15)), isTrue);
      expect(revived.isSameDay(DateTime(2026, 11, 16)), isFalse);
    });

    test('TaskItem subtask progress and completion logic works', () {
      final now = DateTime.now();
      final task = TaskItem(
        id: 'task-1',
        title: 'Weekly Groceries',
        dueDate: now,
        priority: TaskPriority.high,
        category: AlarmCategory.fromType(AlarmCategoryType.personal),
        subtasks: const [
          TaskSubItem(id: 's1', title: 'Oats', isCompleted: true),
          TaskSubItem(id: 's2', title: 'Fruit', isCompleted: false),
          TaskSubItem(id: 's3', title: 'Coffee', isCompleted: true),
        ],
        createdAt: now,
      );

      expect(task.completedSubtasksCount, equals(2));
      expect(task.isDueToday(now), isTrue);
      expect(task.priorityLabel, equals('HIGH'));

      final json = task.toJson();
      final restored = TaskItem.fromJson(json);
      expect(restored.subtasks.length, equals(3));
      expect(restored.subtasks[1].title, equals('Fruit'));
      expect(restored.subtasks[1].isCompleted, isFalse);
    });

    test('RoutineItem progress and streak calculations work correctly', () {
      final now = DateTime.now();
      final routine = RoutineItem(
        id: 'routine-1',
        title: 'Morning Energizer',
        type: RoutineType.morning,
        steps: const ['Drink water', 'Light stretch', 'Review agenda'],
        completedStepIndices: {0, 1},
        streakCount: 5,
        createdAt: now,
      );

      expect(routine.isCompletedToday, isFalse);
      expect(routine.progress, closeTo(2 / 3, 0.01));

      final allDoneRoutine = routine.copyWith(
        completedStepIndices: {0, 1, 2},
      );
      expect(allDoneRoutine.isCompletedToday, isTrue);
      expect(allDoneRoutine.progress, equals(1.0));

      final json = routine.toJson();
      final revived = RoutineItem.fromJson(json);
      expect(revived.steps.length, equals(3));
      expect(revived.completedStepIndices.contains(0), isTrue);
      expect(revived.completedStepIndices.contains(1), isTrue);
      expect(revived.completedStepIndices.contains(2), isFalse);
    });

    test('NoteItem pinning and category mapping work', () {
      final now = DateTime.now();
      final note = NoteItem(
        id: 'note-1',
        title: 'Ideas for Weekend Trip',
        content: 'Check train schedules and pack light jacket.',
        category: AlarmCategory.fromType(AlarmCategoryType.personal),
        isPinned: true,
        tags: const ['Travel', 'Weekend'],
        createdAt: now,
        updatedAt: now,
      );

      final json = note.toJson();
      final revived = NoteItem.fromJson(json);
      expect(revived.isPinned, isTrue);
      expect(revived.tags, contains('Travel'));
      expect(revived.content, contains('train schedules'));
    });

    test('CollectionItem checklist and displayIcon work', () {
      final now = DateTime.now();
      final list = CollectionItem(
        id: 'col-1',
        title: 'Tech Gear Checklist',
        iconCodePoint: 0xe59c,
        entries: const [
          CollectionEntry(id: 'e1', text: 'Laptop & Charger', isChecked: true),
          CollectionEntry(id: 'e2', text: 'Earphones', isChecked: false),
        ],
        createdAt: now,
      );

      expect(list.totalCount, equals(2));
      expect(list.checkedCount, equals(1));
      expect(list.progress, equals(0.5));
      expect(list.displayIcon, equals(Icons.shopping_cart_rounded));
    });

    test('WishlistItem budget and urgency flags work', () {
      final now = DateTime.now();
      final item = WishlistItem(
        id: 'wish-1',
        title: 'Noise Cancelling Headphones',
        targetPrice: 199.99,
        priority: TaskPriority.high,
        category: AlarmCategory.fromType(AlarmCategoryType.personal),
        isPurchased: false,
        createdAt: now,
      );

      expect(item.formattedPrice(), equals('\$199.99'));
      expect(item.priority, equals(TaskPriority.high));

      final json = item.toJson();
      final revived = WishlistItem.fromJson(json);
      expect(revived.targetPrice, equals(199.99));
      expect(revived.isPurchased, isFalse);
    });

    test('JournalEntry mood and gratitude serialization work', () {
      final now = DateTime.now();
      final entry = JournalEntry(
        id: 'journal-1',
        title: 'Productive Day',
        content: 'Completed the core modules for Everyday Space.',
        date: now,
        mood: JournalMood.great,
        gratitudeNote: 'Thankful for focus and flow state.',
        tags: const ['Sprint', 'Success'],
        createdAt: now,
        updatedAt: now,
      );

      expect(entry.mood.emoji, equals('😄'));
      expect(entry.gratitudeNote, contains('flow state'));

      final json = entry.toJson();
      final revived = JournalEntry.fromJson(json);
      expect(revived.mood, equals(JournalMood.great));
      expect(revived.tags, contains('Sprint'));
    });

    test('DashboardConfig customizable section toggles work', () {
      const config = DashboardConfig();
      expect(config.showWeather, isTrue);
      expect(config.showTodayAgenda, isTrue);

      final custom = config.copyWith(showWeather: false, showRoutines: false);
      expect(custom.showWeather, isFalse);
      expect(custom.showRoutines, isFalse);
      expect(custom.showTodayAgenda, isTrue);

      final json = custom.toJson();
      final restored = DashboardConfig.fromJson(json);
      expect(restored.showWeather, isFalse);
      expect(restored.showRoutines, isFalse);
      expect(restored.sectionOrder, equals(DashboardConfig.defaultSectionOrder));
    });

    test('DashboardProvider section reordering and persistence works', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final provider = DashboardProvider(storage);

      expect(provider.config.sectionOrder, equals(DashboardConfig.defaultSectionOrder));

      // Move section 0 to index 3
      await provider.reorderSections(0, 3);
      expect(provider.config.sectionOrder[0], isNot(equals(DashboardConfig.sectionWeather)));

      // Reset
      await provider.resetSectionOrder();
      expect(provider.config.sectionOrder, equals(DashboardConfig.defaultSectionOrder));
    });

    test('SleepCycleCalculator computes 90-minute sleep cycles', () {
      final bedTime = DateTime(2026, 11, 11, 23, 0); // 11:00 PM
      final wakeTimes = SleepCycleCalculator.calculateWakeUpTimes(bedTime);

      expect(wakeTimes.length, equals(4));
      expect(wakeTimes[0].cycles, equals(3)); // 4.5h sleep
      expect(wakeTimes[1].cycles, equals(4)); // 6h sleep
      expect(wakeTimes[2].cycles, equals(5)); // 7.5h sleep (optimal sweet spot)
      expect(wakeTimes[2].isRecommended, isTrue);
      expect(wakeTimes[3].cycles, equals(6)); // 9h sleep
    });
  });

  group('StorageService Backup Export & Restore Tests', () {
    test('Exports full JSON backup containing all modules and restores seamlessly', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();

      final now = DateTime.now();
      final task = TaskItem(
        id: 't-backup-1',
        title: 'Task For Backup',
        category: AlarmCategory.fromType(AlarmCategoryType.work),
        createdAt: now,
      );
      final note = NoteItem(
        id: 'n-backup-1',
        title: 'Note For Backup',
        content: 'Preserved perfectly',
        category: AlarmCategory.fromType(AlarmCategoryType.personal),
        createdAt: now,
        updatedAt: now,
      );

      await storage.saveTasks([task]);
      await storage.saveNotes([note]);

      final backupJson = storage.exportFullBackupJson();
      expect(backupJson, contains('t-backup-1'));
      expect(backupJson, contains('n-backup-1'));
      expect(backupJson, contains('Task For Backup'));

      // Clear prefs
      final clearedStorage = await StorageService.init();
      await clearedStorage.saveTasks([]);
      await clearedStorage.saveNotes([]);
      expect(clearedStorage.loadTasks(), isEmpty);

      // Restore from backup JSON
      final success = await clearedStorage.restoreFullBackupJson(backupJson);
      expect(success, isTrue);

      final restoredTasks = clearedStorage.loadTasks();
      final restoredNotes = clearedStorage.loadNotes();

      expect(restoredTasks.length, equals(1));
      expect(restoredTasks.first.title, equals('Task For Backup'));
      expect(restoredNotes.length, equals(1));
      expect(restoredNotes.first.content, equals('Preserved perfectly'));
    });

    test('UserPreferences security and journal settings serialization works', () {
      final defaultPrefs = UserPreferences.defaults();
      expect(defaultPrefs.isDiaryLockEnabled, isFalse);
      expect(defaultPrefs.isBiometricEnabled, isFalse);
      expect(defaultPrefs.securityPin, isNull);
      expect(defaultPrefs.showJournalPrompts, isTrue);
      expect(defaultPrefs.showThrowbacks, isTrue);

      final securedPrefs = defaultPrefs.copyWith(
        isDiaryLockEnabled: true,
        isBiometricEnabled: true,
        securityPin: '4321',
        showJournalPrompts: false,
        showThrowbacks: false,
      );

      final json = securedPrefs.toJson();
      final revived = UserPreferences.fromJson(json);

      expect(revived.isDiaryLockEnabled, isTrue);
      expect(revived.isBiometricEnabled, isTrue);
      expect(revived.securityPin, equals('4321'));
      expect(revived.showJournalPrompts, isFalse);
      expect(revived.showThrowbacks, isFalse);
    });

    test('SettingsProvider PIN verification, biometric toggle, and diary session lock work', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final settings = SettingsProvider(storage);

      expect(settings.hasPin, isFalse);
      expect(settings.isDiaryUnlocked, isTrue); // Not locked yet

      // Setup PIN and lock
      await settings.setSecurityPin('9876');
      await settings.toggleDiaryLock(true);
      await settings.toggleBiometric(true);

      expect(settings.hasPin, isTrue);
      expect(settings.securityPin, equals('9876'));
      expect(settings.isBiometricEnabled, isTrue);
      expect(settings.isDiaryLockEnabled, isTrue);
      expect(settings.isDiaryUnlocked, isFalse); // Locked now!

      // Verify incorrect PIN fails
      expect(settings.verifyPin('0000'), isFalse);
      expect(settings.isDiaryUnlocked, isFalse);

      // Verify correct PIN succeeds
      expect(settings.verifyPin('9876'), isTrue);
      settings.unlockDiary();
      expect(settings.isDiaryUnlocked, isTrue);

      // Lock again
      settings.lockDiary();
      expect(settings.isDiaryUnlocked, isFalse);

      // Remove PIN
      await settings.removeSecurityPin();
      expect(settings.hasPin, isFalse);
      expect(settings.isDiaryLockEnabled, isFalse);
      expect(settings.isDiaryUnlocked, isTrue);
    });

    test('JournalProvider getThrowbackMemories finds exact date memories across years', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final journal = JournalProvider(storage);

      final now = DateTime.now();
      final oneYearAgo = DateTime(now.year - 1, now.month, now.day, 9, 0);

      await journal.addMemory(
        MemoryItem(
          id: 'mem-tb-1',
          title: 'Trip to the coast',
          description: 'Salt air and good thoughts',
          date: oneYearAgo,
          isMilestone: true,
          createdAt: oneYearAgo,
        ),
      );

      final throwbacks = journal.getThrowbackMemories(forDate: now);
      expect(throwbacks.isNotEmpty, isTrue);
      final match = throwbacks.firstWhere((t) => t.id == 'mem-tb-1');
      expect(match.title, equals('Trip to the coast'));
      expect(match.timeAgoLabel, equals('1 year ago today'));
      expect(match.isMemory, isTrue);
    });

    test('JournalPrompt default prompts are populated with inspiring questions', () {
      expect(JournalPrompt.defaultPrompts.length, greaterThanOrEqualTo(5));
      final first = JournalPrompt.defaultPrompts.first;
      expect(first.prompt, contains('highlight'));
      expect(first.category, isNotEmpty);
    });
  });
}
