import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/data/models/reading_goal_data.dart';
import 'package:nestin/data/models/reading_item.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/reading_provider.dart';
import 'package:nestin/ui/widgets/reading_goal_sheet.dart';
import 'package:nestin/ui/widgets/reading_progress_card.dart';
import 'package:nestin/ui/widgets/reading_tracker_sheet.dart';

class _ScheduledReadingCall {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledDate;
  final String? payload;

  _ScheduledReadingCall({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledDate,
    this.payload,
  });
}

class _ShownReadingCall {
  final int id;
  final String title;
  final String body;
  final String? payload;

  _ShownReadingCall({
    required this.id,
    required this.title,
    required this.body,
    this.payload,
  });
}

class _RecordingReadingNotificationService extends NotificationService {
  final List<_ScheduledReadingCall> scheduledCalls = [];
  final List<_ShownReadingCall> shownCalls = [];
  final List<int> cancelledIds = [];

  @override
  Future<void> scheduleReadingNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    scheduledCalls.add(
      _ScheduledReadingCall(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        payload: payload,
      ),
    );
  }

  @override
  Future<void> showReadingNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    shownCalls.add(
      _ShownReadingCall(
        id: id,
        title: title,
        body: body,
        payload: payload,
      ),
    );
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadingGoalData Model Tests', () {
    test('Initializes defaults and serializes cleanly via JSON', () {
      final initial = ReadingGoalData.initial();
      expect(initial.dailyPageGoal, equals(15));
      expect(initial.eveningReminderEnabled, isFalse);
      expect(initial.reminderHour, equals(20));
      expect(initial.reminderMinute, equals(0));
      expect(initial.formattedReminderTime, equals('20:00'));

      final configured = ReadingGoalData(
        dailyPageGoal: 25,
        eveningReminderEnabled: true,
        reminderHour: 21,
        reminderMinute: 30,
        dailyPagesHistory: const {
          '2026-11-12': 25,
          '2026-11-13': 30,
        },
      );
      final restored = ReadingGoalData.fromJson(configured.toJson());
      expect(restored.dailyPageGoal, equals(25));
      expect(restored.eveningReminderEnabled, isTrue);
      expect(restored.reminderHour, equals(21));
      expect(restored.reminderMinute, equals(30));
      expect(restored.dailyPagesHistory['2026-11-13'], equals(30));
    });

    test('Computes currentStreak, bestStreak, and 7-day sparkline stats', () {
      final today = DateTime(2026, 11, 14);
      final goal = ReadingGoalData(
        dailyPageGoal: 15,
        dailyPagesHistory: {
          // Earlier 4-day streak (Nov 1-4)
          '2026-11-01': 16,
          '2026-11-02': 15,
          '2026-11-03': 20,
          '2026-11-04': 18,
          // Break on Nov 5 (5 pages)
          '2026-11-05': 5,
          // Current active streak (Nov 11, 12, 13 = 3 days; today not finished yet)
          '2026-11-11': 15,
          '2026-11-12': 22,
          '2026-11-13': 18,
          '2026-11-14': 6,
        },
      );

      // Yesterday met goal -> streak stays alive at 3 today until midnight
      expect(goal.getCurrentStreak(today), equals(3));
      expect(goal.getBestStreak(), equals(4));
      expect(goal.isTodayGoalMet(today), isFalse);
      expect(goal.pagesRemainingToday(today), equals(9));

      // Meeting goal today increments current streak to 4 immediately
      final metToday = goal.copyWith(
        dailyPagesHistory: {
          ...goal.dailyPagesHistory,
          '2026-11-14': 17,
        },
      );
      expect(metToday.isTodayGoalMet(today), isTrue);
      expect(metToday.getCurrentStreak(today), equals(4));
      expect(metToday.getWeeklyTotalPages(today), equals(17 + 18 + 22 + 15));
      expect(metToday.getWeeklyDaysMetCount(today), equals(4));
    });
  });

  group('ReadingProvider Goal, Streak & Pippin Evening Nudge Tests', () {
    late StorageService storage;
    late _RecordingReadingNotificationService notifications;
    late DateTime fakeNow;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = StorageService(prefs);
      notifications = _RecordingReadingNotificationService();
      fakeNow = DateTime(2026, 11, 14, 16, 0);
    });

    test('Slider drag previews do not double-count; persist logs exact delta and protects cross-book progress',
        () async {
      final provider = ReadingProvider(
        storage,
        notificationService: notifications,
        clock: () => fakeNow,
      );

      expect(provider.todayPagesRead, equals(0));
      final active = provider.primaryActiveBook!; // Atomic Habits @ page 144

      // Simulated drag without persist
      await provider.updatePageProgress(active.id, 180, persist: false);
      expect(provider.todayPagesRead, equals(0));

      // Drag settled back to 160 -> persist commits +16 net pages (not +36)
      await provider.updatePageProgress(active.id, 160, persist: true);
      expect(provider.todayPagesRead, equals(16));
      expect(provider.isDailyGoalMet, isTrue);
      expect(provider.currentStreak, equals(1));

      // Resetting previously finished Deep Work to Queue must NOT wipe Atomic Habits' 16 pages today
      final deepWork = provider.finishedItems.first;
      await provider.setStatus(deepWork.id, ReadingStatus.wantToRead);
      expect(provider.todayPagesRead, equals(16));

      // Quick -5p undo on active book adjusts todayPagesRead down cleanly (16 -> 11)
      await provider.incrementPages(active.id, -5);
      expect(provider.todayPagesRead, equals(11));
      expect(provider.isDailyGoalMet, isFalse);
    });

    test('Optional evening Pippin nudge schedules intelligently and respects goal completion',
        () async {
      final provider = ReadingProvider(
        storage,
        notificationService: notifications,
        clock: () => fakeNow, // 16:00
      );

      // Default: optional nudge disabled
      expect(provider.eveningReminderEnabled, isFalse);
      expect(provider.computeNextReminderDateTime(), isNull);
      expect(
        provider.buildEveningReminderBody(forDate: fakeNow),
        contains('Read 15 pages today'),
      );

      // Enabling schedules tonight at 20:00 because goal isn't met & 20:00 > 16:00
      await provider.toggleEveningReminder(true);
      expect(
        provider.computeNextReminderDateTime(),
        equals(DateTime(2026, 11, 14, 20, 0)),
      );
      expect(notifications.scheduledCalls.length, equals(1));
      expect(
        notifications.scheduledCalls.last.id,
        equals(ReadingProvider.eveningReminderNotificationId),
      );
      expect(
        notifications.scheduledCalls.last.body,
        contains('Read 15 pages today'),
      );
      expect(
        notifications.scheduledCalls.last.payload,
        equals(ReadingProvider.reminderPayload),
      );

      // Partial reading updates copy to remaining count
      await provider.logDailyPages(6);
      expect(
        provider.buildEveningReminderBody(forDate: fakeNow),
        contains('9 pages left'),
      );

      // Completing 15-page goal pushes next nudge to tomorrow evening at 20:00
      await provider.logDailyPages(10);
      expect(provider.isDailyGoalMet, isTrue);
      expect(
        provider.computeNextReminderDateTime(),
        equals(DateTime(2026, 11, 15, 20, 0)),
      );
      expect(
        notifications.scheduledCalls.last.scheduledDate,
        equals(DateTime(2026, 11, 15, 20, 0)),
      );

      // Changing goal updates tomorrow/today calculation & reschedules cleanly
      await provider.setDailyPageGoal(25);
      expect(provider.isDailyGoalMet, isFalse);
      expect(
        provider.computeNextReminderDateTime(),
        equals(DateTime(2026, 11, 14, 20, 0)),
      );

      // Disabling cancels reminder without rescheduling
      notifications.scheduledCalls.clear();
      notifications.cancelledIds.clear();
      await provider.toggleEveningReminder(false);
      expect(provider.computeNextReminderDateTime(), isNull);
      expect(
        notifications.cancelledIds,
        contains(ReadingProvider.eveningReminderNotificationId),
      );
      expect(notifications.scheduledCalls, isEmpty);

      // Test nudge sends immediately
      notifications.shownCalls.clear();
      await provider.testSendEveningNudgeNow();
      expect(notifications.shownCalls.length, equals(1));
      expect(
        notifications.shownCalls.single.id,
        equals(ReadingProvider.previewReminderNotificationId),
      );
      expect(
        notifications.shownCalls.single.payload,
        equals(ReadingProvider.reminderPayload),
      );
    });

    test('StorageService full backup export/restore preserves readingGoalData',
        () async {
      final provider = ReadingProvider(storage, clock: () => fakeNow);
      await provider.setDailyPageGoal(30);
      await provider.toggleEveningReminder(true);
      await provider.setReminderTime(21, 15);
      await provider.recordHistoricalPages('2026-11-13', 32);

      final backup = storage.exportFullBackupJson();
      expect(backup, contains('"readingGoalData"'));

      await storage.saveReadingGoalData(ReadingGoalData.initial());
      expect(storage.loadReadingGoalData().dailyPageGoal, equals(15));

      final restored = await storage.restoreFullBackupJson(backup);
      expect(restored, isTrue);

      final goalRestored = storage.loadReadingGoalData();
      expect(goalRestored.dailyPageGoal, equals(30));
      expect(goalRestored.eveningReminderEnabled, isTrue);
      expect(goalRestored.formattedReminderTime, equals('21:15'));
      expect(goalRestored.dailyPagesHistory['2026-11-13'], equals(32));
    });
  });

  group('Reading Goal, Sparkline & Evening Nudge Widget Tests', () {
    late StorageService storage;
    late _RecordingReadingNotificationService notifications;
    late DateTime fakeNow;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = StorageService(prefs);
      notifications = _RecordingReadingNotificationService();
      fakeNow = DateTime(2026, 11, 14, 16, 0);
    });

    testWidgets(
        'ReadingProgressCard renders streak badge, 7-day sparkline, and bumps streak when goal completed',
        (tester) async {
      final provider = ReadingProvider(
        storage,
        notificationService: notifications,
        clock: () => fakeNow,
      );
      await provider.recordHistoricalPages('2026-11-11', 16);
      await provider.recordHistoricalPages('2026-11-12', 18);
      await provider.recordHistoricalPages('2026-11-13', 20);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ReadingProvider>.value(
              value: provider,
              child: const SingleChildScrollView(
                child: ReadingProgressCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3d streak'), findsOneWidget);
      expect(find.text('Today: 0/15 pages'), findsOneWidget);
      expect(find.text('7-DAY PAGES READ'), findsOneWidget);

      // Tap +10 p twice (+20 p) -> hits 15-page goal & bumps streak to 4d!
      await tester.tap(find.text('+10 p'));
      await tester.pumpAndSettle();
      expect(find.text('Today: 10/15 pages'), findsOneWidget);

      await tester.tap(find.text('+10 p'));
      await tester.pumpAndSettle();
      expect(find.text('Today: 20/15 p ✓'), findsOneWidget);
      expect(find.text('4d streak'), findsOneWidget);

      // Tapping Today bar shows popover summary
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(find.text('20 pages • Goal Met 🎉'), findsOneWidget);
    });

    testWidgets(
        'ReadingGoalSettingsSheet edits daily page goal, enables Evening Pippin Nudge & sets time',
        (tester) async {
      final provider = ReadingProvider(
        storage,
        notificationService: notifications,
        clock: () => fakeNow,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ReadingProvider>.value(
              value: provider,
              child: const ReadingGoalSettingsSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('15 pages / day'), findsOneWidget);
      expect(find.textContaining('Read 15 pages today'), findsOneWidget);

      // Select 25 p goal preset
      await tester.ensureVisible(find.text('25 p'));
      await tester.tap(find.text('25 p'));
      await tester.pumpAndSettle();
      expect(provider.dailyPageGoal, equals(25));
      expect(find.text('25 pages / day'), findsOneWidget);
      expect(find.textContaining('Read 25 pages today'), findsOneWidget);

      // Toggle Evening Pippin Nudge ON
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(provider.eveningReminderEnabled, isTrue);

      // Switch time preset to 21:00
      await tester.ensureVisible(find.text('21:00'));
      await tester.tap(find.text('21:00'));
      await tester.pumpAndSettle();
      expect(provider.formattedReminderTime, equals('21:00'));

      // Send preview nudge
      await tester.ensureVisible(find.text('Send Test Nudge'));
      await tester.tap(find.text('Send Test Nudge'));
      await tester.pumpAndSettle();
      expect(find.text('Sent Pippin reading nudge preview!'), findsOneWidget);
    });

    testWidgets(
        'ReadingTrackerSheet toggles 7-day sparkline drawer and shows Today & Streak stats',
        (tester) async {
      final provider = ReadingProvider(
        storage,
        notificationService: notifications,
        clock: () => fakeNow,
      );
      await provider.recordHistoricalPages('2026-11-13', 18);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ReadingProvider>.value(
              value: provider,
              child: const ReadingTrackerSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0/15p'), findsOneWidget);
      expect(find.text('🔥 1d'), findsOneWidget);
      expect(find.text('7-DAY PAGES READ'), findsNothing);

      await tester.tap(find.byTooltip('Toggle 7-Day Sparkline'));
      await tester.pumpAndSettle();
      expect(find.text('7-DAY PAGES READ'), findsOneWidget);
    });
  });
}
