import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nestin/data/models/alarm_category.dart';
import 'package:nestin/data/models/note_item.dart';
import 'package:nestin/data/models/reminder.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/collection_provider.dart';
import 'package:nestin/providers/note_provider.dart';
import 'package:nestin/providers/reminder_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/providers/task_provider.dart';
import 'package:nestin/ui/screens/organize/notes_list_screen.dart';
import 'package:nestin/ui/screens/organize/wishlist_screen.dart';
import 'package:nestin/ui/screens/reminders/reminders_list_screen.dart';
import 'package:nestin/ui/screens/time/tasks_screen.dart';
import 'package:nestin/ui/widgets/swipe_action_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<StorageService> createStorage() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  Future<void> swipeCard(WidgetTester tester, Finder finder, double dx) async {
    await tester.timedDrag(
      finder,
      Offset(dx, 0),
      const Duration(milliseconds: 250),
    );
    await tester.pumpAndSettle();
  }

  group('Provider Restore Snapshot Unit Tests', () {
    test('TaskProvider.restoreTask restores deleted and pre-toggle tasks idempotently',
        () async {
      final storage = await createStorage();
      final provider = TaskProvider(storage);
      final initialCount = provider.tasks.length;
      final first = provider.tasks.first;
      final originalIdx = provider.indexOfTask(first.id);

      await provider.deleteTask(first.id);
      expect(provider.tasks.length, initialCount - 1);

      await provider.restoreTask(first, index: originalIdx);
      await provider.restoreTask(first, index: originalIdx); // idempotent
      expect(provider.tasks.length, initialCount);
      expect(provider.indexOfTask(first.id), originalIdx);

      await provider.toggleTaskCompletion(first.id);
      expect(
        provider.tasks.firstWhere((t) => t.id == first.id).isCompleted,
        isTrue,
      );
      await provider.restoreTask(first, index: originalIdx);
      expect(
        provider.tasks.firstWhere((t) => t.id == first.id).isCompleted,
        isFalse,
      );
    });

    test('ReminderProvider.restoreReminder reverts recurring dueDateTime advancement',
        () async {
      final storage = await createStorage();
      final provider = ReminderProvider(storage, NotificationService());
      final due = DateTime(2026, 11, 14, 9, 0);
      final recurring = Reminder(
        id: 'rem_recur_1',
        title: 'Daily Standup',
        dueDateTime: due,
        recurrence: ReminderRecurrence.daily,
        category: AlarmCategory.fromType(AlarmCategoryType.work),
        createdAt: due,
      );
      await provider.addReminder(recurring);

      await provider.toggleCompletion('rem_recur_1');
      final advanced =
          provider.reminders.firstWhere((r) => r.id == 'rem_recur_1');
      expect(advanced.dueDateTime, due.add(const Duration(days: 1)));

      await provider.restoreReminder(recurring);
      final reverted =
          provider.reminders.firstWhere((r) => r.id == 'rem_recur_1');
      expect(reverted.dueDateTime, due);
      expect(reverted.isCompleted, isFalse);
    });

    test('NoteProvider.restoreNote preserves archived/pinned state and exact index',
        () async {
      final storage = await createStorage();
      final provider = NoteProvider(storage);
      final target = provider.notes.first;
      final idx = provider.indexOfNote(target.id);

      await provider.deleteNote(target.id);
      expect(provider.indexOfNote(target.id), -1);

      await provider.restoreNote(target, index: idx);
      expect(provider.indexOfNote(target.id), idx);
    });

    test('CollectionProvider.restoreWishlistItem restores deleted wishlist item at original index',
        () async {
      final storage = await createStorage();
      final provider = CollectionProvider(storage);
      final first = provider.wishlist.first;
      final idx = provider.indexOfWishlistItem(first.id);

      await provider.deleteWishlistItem(first.id);
      expect(provider.indexOfWishlistItem(first.id), -1);

      await provider.restoreWishlistItem(first, index: idx);
      expect(provider.indexOfWishlistItem(first.id), idx);
    });
  });

  group('SwipeActionCard & 4-Second Undo Snackbar Tests', () {
    testWidgets('SwipeActionCard triggers right/left callbacks and Undo snackbar dismisses after 4 seconds',
        (tester) async {
      final items = ['Item Alpha', 'Item Beta'];
      int rightSwipes = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final label = items[index];
                    return SwipeActionCard(
                      key: ValueKey('card_$label'),
                      dismissKey: ValueKey('dismiss_$label'),
                      swipeRightStyle: const SwipeActionStyle(
                        label: 'Done',
                        icon: Icons.check_circle_rounded,
                        color: Colors.green,
                      ),
                      swipeLeftStyle: const SwipeActionStyle(
                        label: 'Delete',
                        icon: Icons.delete_outline_rounded,
                        color: Colors.red,
                      ),
                      onSwipeRight: () {
                        rightSwipes++;
                        showUndoSnackBar(
                          context: context,
                          message: 'Marked $label',
                          onUndo: () => rightSwipes--,
                        );
                      },
                      onSwipeLeft: () {
                        final removedIdx = items.indexOf(label);
                        setState(() => items.removeAt(removedIdx));
                        showUndoSnackBar(
                          context: context,
                          message: 'Deleted $label',
                          onUndo: () => setState(
                            () => items.insert(removedIdx, label),
                          ),
                        );
                      },
                      child: SizedBox(
                        height: 64,
                        child: Center(child: Text(label)),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Swipe right keeps widget in tree and shows snackbar
      await swipeCard(tester, find.text('Item Alpha'), 450);
      expect(rightSwipes, 1);
      expect(find.text('Item Alpha'), findsOneWidget);
      expect(find.text('Marked Item Alpha'), findsOneWidget);

      // Swipe left replaces snackbar immediately and removes Item Beta
      await swipeCard(tester, find.text('Item Beta'), -450);
      expect(find.text('Item Beta'), findsNothing);
      expect(find.text('Marked Item Alpha'), findsNothing);
      expect(find.text('Deleted Item Beta'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Still visible just under 4 seconds, auto-dismisses after 4 seconds
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Deleted Item Beta'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Deleted Item Beta'), findsNothing);
    });
  });

  group('Screen Unified Swipe & Undo Widget Tests', () {
    testWidgets('TasksScreen swipe-right completes and swipe-left deletes with 4s Undo',
        (tester) async {
      final storage = await createStorage();
      final taskProvider = TaskProvider(storage);
      final targetTitle = taskProvider.pendingTasks.first.title;
      final targetId = taskProvider.pendingTasks.first.id;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TaskProvider>.value(
            value: taskProvider,
            child: const TasksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Swipe right -> Complete
      await swipeCard(tester, find.text(targetTitle), 450);
      expect(
        taskProvider.tasks.firstWhere((t) => t.id == targetId).isCompleted,
        isTrue,
      );
      expect(find.text('Completed "$targetTitle"'), findsOneWidget);

      // Tap Undo -> Back to Pending
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(
        taskProvider.tasks.firstWhere((t) => t.id == targetId).isCompleted,
        isFalse,
      );
      expect(find.text(targetTitle), findsOneWidget);

      // Swipe left -> Delete
      await swipeCard(tester, find.text(targetTitle), -450);
      expect(taskProvider.indexOfTask(targetId), -1);
      expect(find.text('Deleted "$targetTitle"'), findsOneWidget);

      // Tap Undo -> Restored
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(taskProvider.indexOfTask(targetId), isNot(-1));
      expect(find.text(targetTitle), findsOneWidget);
    });

    testWidgets('RemindersListScreen swipe-right completes/advances and swipe-left deletes with Undo',
        (tester) async {
      final storage = await createStorage();
      final reminderProvider =
          ReminderProvider(storage, NotificationService());
      final settingsProvider = SettingsProvider(storage);

      final now = DateTime(2026, 11, 14, 15, 0);
      await reminderProvider.addReminder(
        Reminder(
          id: 'swipe_rem_1',
          title: 'Stretch & Hydrate',
          dueDateTime: now,
          recurrence: ReminderRecurrence.daily,
          category: AlarmCategory.fromType(AlarmCategoryType.health),
          createdAt: now,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ReminderProvider>.value(
                value: reminderProvider,
              ),
              ChangeNotifierProvider<SettingsProvider>.value(
                value: settingsProvider,
              ),
            ],
            child: const RemindersListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Swipe right on recurring reminder -> advances due date + Undo reverts it
      await swipeCard(tester, find.text('Stretch & Hydrate'), 450);
      expect(
        reminderProvider.reminders
            .firstWhere((r) => r.id == 'swipe_rem_1')
            .dueDateTime,
        now.add(const Duration(days: 1)),
      );
      expect(
        find.text('Advanced "Stretch & Hydrate" to next schedule'),
        findsOneWidget,
      );

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(
        reminderProvider.reminders
            .firstWhere((r) => r.id == 'swipe_rem_1')
            .dueDateTime,
        now,
      );

      // Swipe left -> Deletes + Undo restores
      await swipeCard(tester, find.text('Stretch & Hydrate'), -450);
      expect(reminderProvider.indexOfReminder('swipe_rem_1'), -1);
      expect(find.text('Deleted "Stretch & Hydrate"'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(reminderProvider.indexOfReminder('swipe_rem_1'), isNot(-1));
      expect(find.text('Stretch & Hydrate'), findsOneWidget);
    });

    testWidgets('NotesListScreen swipe-right pins/unpins and swipe-left archives with Archived tab + Undo',
        (tester) async {
      final storage = await createStorage();
      final noteProvider = NoteProvider(storage);
      final now = DateTime.now().add(const Duration(minutes: 5));
      await noteProvider.addNote(
        NoteItem(
          id: 'swipe_note_1',
          title: 'Sprint Retrospective',
          content: '- Keep swipe gestures smooth',
          category: AlarmCategory.fromType(AlarmCategoryType.work),
          isPinned: false,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<NoteProvider>.value(
            value: noteProvider,
            child: const NotesListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Swipe right -> Pins note & Undo unpins
      await swipeCard(tester, find.text('Sprint Retrospective'), 450);
      expect(
        noteProvider.notes.firstWhere((n) => n.id == 'swipe_note_1').isPinned,
        isTrue,
      );
      expect(find.text('Pinned "Sprint Retrospective"'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(
        noteProvider.notes.firstWhere((n) => n.id == 'swipe_note_1').isPinned,
        isFalse,
      );

      // Swipe left -> Archives note + Undo unarchives
      await swipeCard(tester, find.text('Sprint Retrospective'), -450);
      expect(
        noteProvider.notes
            .firstWhere((n) => n.id == 'swipe_note_1')
            .isArchived,
        isTrue,
      );
      expect(find.text('Archived "Sprint Retrospective"'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(
        noteProvider.notes
            .firstWhere((n) => n.id == 'swipe_note_1')
            .isArchived,
        isFalse,
      );

      // Archive again and verify Archived tab supports Restore & Delete + Undo
      await swipeCard(tester, find.text('Sprint Retrospective'), -450);
      await tester.tap(find.text('Archived (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Sprint Retrospective'), findsOneWidget);

      // Swipe left in Archived -> Deletes + Undo restores to Archived
      await swipeCard(tester, find.text('Sprint Retrospective'), -450);
      expect(noteProvider.indexOfNote('swipe_note_1'), -1);
      expect(find.text('Deleted "Sprint Retrospective"'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(noteProvider.indexOfNote('swipe_note_1'), isNot(-1));
      expect(find.text('Sprint Retrospective'), findsOneWidget);
    });

    testWidgets('WishlistScreen swipe-right marks acquired and swipe-left deletes with Undo',
        (tester) async {
      final storage = await createStorage();
      final collectionProvider = CollectionProvider(storage);
      final target = collectionProvider.wishlist.first;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CollectionProvider>.value(
            value: collectionProvider,
            child: const WishlistScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Swipe right -> Marks acquired + Undo reverts
      await swipeCard(tester, find.text(target.title), 450);
      expect(
        collectionProvider.wishlist
            .firstWhere((w) => w.id == target.id)
            .isPurchased,
        isTrue,
      );
      expect(find.text('Marked "${target.title}" acquired'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(
        collectionProvider.wishlist
            .firstWhere((w) => w.id == target.id)
            .isPurchased,
        isFalse,
      );

      // Swipe left -> Deletes at index 0 + Undo restores at index 0
      await swipeCard(tester, find.text(target.title), -450);
      expect(collectionProvider.indexOfWishlistItem(target.id), -1);
      expect(find.text('Deleted "${target.title}"'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(collectionProvider.indexOfWishlistItem(target.id), 0);
      expect(find.text(target.title), findsOneWidget);
    });
  });
}
