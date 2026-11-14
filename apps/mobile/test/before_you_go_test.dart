import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nestin/data/models/alarm_category.dart';
import 'package:nestin/data/models/before_you_go.dart';
import 'package:nestin/data/models/calendar_event.dart';
import 'package:nestin/data/models/dashboard_config.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/before_you_go_provider.dart';
import 'package:nestin/providers/calendar_provider.dart';
import 'package:nestin/providers/dashboard_provider.dart';
import 'package:nestin/ui/screens/time/calendar_screen.dart';
import 'package:nestin/ui/widgets/before_you_go_card.dart';
import 'package:nestin/ui/widgets/before_you_go_sheet.dart';

class RecordedNotification {
  final int id;
  final String title;
  final String body;
  final DateTime? scheduledDate;
  final String? payload;
  final bool isImmediate;
  final bool includeInlineActions;

  const RecordedNotification({
    required this.id,
    required this.title,
    required this.body,
    this.scheduledDate,
    this.payload,
    this.isImmediate = false,
    this.includeInlineActions = true,
  });
}

class RecordingNotificationService extends NotificationService {
  final List<RecordedNotification> scheduled = [];
  final List<RecordedNotification> shown = [];
  final List<int> cancelledIds = [];

  @override
  Future<void> scheduleDepartureNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    bool includeInlineActions = true,
  }) async {
    scheduled.add(
      RecordedNotification(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        payload: payload,
        includeInlineActions: includeInlineActions,
      ),
    );
  }

  @override
  Future<void> showDepartureNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool includeInlineActions = true,
  }) async {
    shown.add(
      RecordedNotification(
        id: id,
        title: title,
        body: body,
        payload: payload,
        isImmediate: true,
        includeInlineActions: includeInlineActions,
      ),
    );
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
  }

  void clearRecords() {
    scheduled.clear();
    shown.clear();
    cancelledIds.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dexterous.com/flutter/local_notifications'),
    (call) async => true,
  );

  late StorageService storage;
  late RecordingNotificationService notifications;
  late BeforeYouGoProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await StorageService.init();
    notifications = RecordingNotificationService();
    provider = BeforeYouGoProvider(storage, notifications);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() {
    provider.dispose();
  });

  group('DeparturePreset & Checklist Item Models', () {
    test('seedDefaults creates Everyday, Work, Travel, and Gym presets', () {
      final defaults = DeparturePreset.seedDefaults(DateTime(2026, 11, 14));
      expect(defaults.length, 4);
      expect(
        defaults.map((p) => p.id),
        [
          DeparturePreset.everydayPresetId,
          DeparturePreset.workPresetId,
          DeparturePreset.travelPresetId,
          DeparturePreset.gymPresetId,
        ],
      );
      expect(defaults.map((p) => p.name), ['Everyday', 'Work', 'Travel', 'Gym']);
      expect(defaults.every((p) => p.items.length == 5), isTrue);
      expect(defaults[1].items.where((i) => i.isEssential).length, 3);
    });

    test('DeparturePreset JSON roundtrip preserves items, essential flags, and state', () {
      final preset = DeparturePreset.seedDefaults(DateTime(2026, 11, 14)).first;
      final checkedFirst = preset.copyWith(
        items: [
          preset.items.first.copyWith(isChecked: true),
          ...preset.items.skip(1),
        ],
      );

      final restored = DeparturePreset.fromJson(checkedFirst.toJson());
      expect(restored.id, checkedFirst.id);
      expect(restored.name, 'Everyday');
      expect(restored.checkedCount, 1);
      expect(restored.totalCount, 5);
      expect(restored.items.first.isChecked, isTrue);
      expect(restored.items.first.isEssential, isTrue);
    });

    test('buildReminderHighlight prioritizes essential unchecked items', () {
      final now = DateTime(2026, 11, 14);
      final preset = DeparturePreset(
        id: 'p_custom',
        name: 'Custom',
        iconCodePoint: Icons.work_outline_rounded.codePoint,
        colorValue: 0xFF3B82F6,
        createdAt: now,
        updatedAt: now,
        items: const [
          DepartureChecklistItem(id: '1', label: 'Umbrella', isEssential: false),
          DepartureChecklistItem(id: '2', label: 'Keys', isEssential: true),
          DepartureChecklistItem(id: '3', label: 'Snacks', isEssential: false),
          DepartureChecklistItem(id: '4', label: 'Passport', isEssential: true),
        ],
      );

      expect(
        preset.buildReminderHighlight(maxItems: 2),
        'Check Keys, Passport (+2 more)',
      );

      final allReady = preset.copyWith(
        items: preset.items.map((i) => i.copyWith(isChecked: true)).toList(),
      );
      expect(
        allReady.buildReminderHighlight(),
        'All 4 Custom items checked & ready!',
      );
    });
  });

  group('BeforeYouGoProvider Checklist & Preset Persistence', () {
    test('custom presets and item edits/reorders/toggles persist across reloads', () async {
      final created = await provider.createPreset(name: 'Hiking');
      expect(provider.activePresetId, created.id);
      expect(provider.presets.length, 5);

      await provider.addItem(created.id, 'Compass', isEssential: true);
      await provider.addItem(created.id, 'Rain Jacket', isEssential: false);

      final hiking = provider.findPresetById(created.id)!;
      expect(hiking.items.map((i) => i.label).toList(), [
        'Keys & Wallet',
        'Phone & Charger',
        'Compass',
        'Rain Jacket',
      ]);

      await provider.toggleItem(created.id, hiking.items[2].id);
      // Classic onReorder move index 2 -> top (0)
      await provider.reorderItems(created.id, 2, 0);
      // Already-adjusted onReorderItem move top (0) -> index 1
      await provider.reorderItems(
        created.id,
        0,
        1,
        adjustForRemoval: false,
      );

      final reordered = BeforeYouGoProvider(storage, notifications);
      addTearDown(reordered.dispose);

      expect(reordered.activePresetId, created.id);
      final persisted = reordered.findPresetById(created.id)!;
      expect(persisted.items[1].label, 'Compass');
      expect(persisted.items[1].isChecked, isTrue);
      expect(persisted.items[1].isEssential, isTrue);

      await reordered.resetPresetItems(created.id);
      expect(reordered.findPresetById(created.id)!.checkedCount, 0);
    });

    test('deletePreset reassigns linked departure events to fallback preset', () async {
      final studio = await provider.createPreset(name: 'Studio');
      final ev = await provider.addDepartureEvent(
        title: 'Photo Shoot',
        presetId: studio.id,
        hour: 9,
        minute: 30,
        recurrence: DepartureRecurrenceType.oneTime,
        oneTimeDate: DateTime(2026, 11, 20),
        leadMinutes: 20,
      );

      final deleted = await provider.deletePreset(studio.id);
      expect(deleted, isTrue);
      expect(provider.findPresetById(studio.id), isNull);
      expect(provider.activePresetId, DeparturePreset.everydayPresetId);
      expect(
        provider.findEventById(ev.id)!.presetId,
        DeparturePreset.everydayPresetId,
      );

      // Cannot delete last remaining preset
      for (final p in provider.presets.skip(1).toList()) {
        await provider.deletePreset(p.id);
      }
      expect(provider.presets.length, 1);
      expect(await provider.deletePreset(provider.presets.first.id), isFalse);
    });
  });

  group('DepartureEvent Smart Heads-Up Scheduling', () {
    test('Mon-Fri 07:10 "Leaving for work" with 15m lead schedules Mon-Fri 06:55 only', () {
      // 2026-11-15 is a Sunday
      final sundayEvening = DateTime(2026, 11, 15, 20, 0);
      final workCommute = DepartureEvent(
        id: 'dep_work',
        title: 'Leaving for work',
        presetId: DeparturePreset.workPresetId,
        hour: 7,
        minute: 10,
        recurrence: DepartureRecurrenceType.weekdays,
        selectedDays: const {1, 2, 3, 4, 5},
        leadMinutes: 15,
        createdAt: sundayEvening,
        updatedAt: sundayEvening,
      );

      expect(workCommute.formattedDepartureTime, '07:10');
      expect(workCommute.formattedNotificationTime, '06:55');
      expect(workCommute.leadLabel, '15m before');

      expect(
        workCommute.nextDepartureAfter(sundayEvening),
        DateTime(2026, 11, 16, 7, 10),
      );
      expect(
        workCommute.nextNotificationAfter(sundayEvening),
        DateTime(2026, 11, 16, 6, 55),
      );

      final week = workCommute.upcomingNotificationsWithin(
        sundayEvening,
        daysHorizon: 7,
      );
      expect(week, [
        DateTime(2026, 11, 16, 6, 55), // Mon
        DateTime(2026, 11, 17, 6, 55), // Tue
        DateTime(2026, 11, 18, 6, 55), // Wed
        DateTime(2026, 11, 19, 6, 55), // Thu
        DateTime(2026, 11, 20, 6, 55), // Fri
      ]);
      // Skips Sat 21 and Sun 22
      expect(
        week.any((dt) => dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday),
        isFalse,
      );
    });

    test('One-time 16:00 "Going to airport" with 30m lead respects notification cutoff', () {
      final day = DateTime(2026, 11, 14);
      final airport = DepartureEvent(
        id: 'dep_airport',
        title: 'Going to airport',
        presetId: DeparturePreset.travelPresetId,
        hour: 16,
        minute: 0,
        recurrence: DepartureRecurrenceType.oneTime,
        oneTimeDate: day,
        leadMinutes: 30,
        createdAt: DateTime(2026, 11, 14, 9, 0),
        updatedAt: DateTime(2026, 11, 14, 9, 0),
      );

      final beforeAlert = DateTime(2026, 11, 14, 14, 0);
      expect(airport.nextDepartureAfter(beforeAlert), DateTime(2026, 11, 14, 16, 0));
      expect(airport.nextNotificationAfter(beforeAlert), DateTime(2026, 11, 14, 15, 30));
      expect(
        airport.upcomingNotificationsWithin(beforeAlert),
        [DateTime(2026, 11, 14, 15, 30)],
      );

      // At 15:40, notification time 15:30 already passed, departure still 20m away
      final afterAlertBeforeLeave = DateTime(2026, 11, 14, 15, 40);
      expect(
        airport.nextDepartureAfter(afterAlertBeforeLeave),
        DateTime(2026, 11, 14, 16, 0),
      );
      expect(airport.nextNotificationAfter(afterAlertBeforeLeave), isNull);
      expect(airport.upcomingNotificationsWithin(afterAlertBeforeLeave), isEmpty);

      // After 16:00, both return empty/null
      final afterDeparture = DateTime(2026, 11, 14, 16, 5);
      expect(airport.nextDepartureAfter(afterDeparture), isNull);
      expect(airport.upcomingNotificationsWithin(afterDeparture), isEmpty);
    });

    test('Custom weekdays and midnight lead rollover calculate accurately', () {
      // Tuesday 2026-11-17 at 22:00 -> custom Thu departure at 00:15 with 30m lead
      // fires Wednesday 2026-11-18 at 23:45.
      final tuesdayNight = DateTime(2026, 11, 17, 22, 0);
      final lateEvent = DepartureEvent(
        id: 'dep_late',
        title: 'Red-eye Shuttle',
        presetId: DeparturePreset.travelPresetId,
        hour: 0,
        minute: 15,
        recurrence: DepartureRecurrenceType.customDays,
        selectedDays: const {DateTime.thursday},
        leadMinutes: 30,
        createdAt: tuesdayNight,
        updatedAt: tuesdayNight,
      );

      expect(
        lateEvent.nextNotificationAfter(tuesdayNight),
        DateTime(2026, 11, 18, 23, 45),
      );
    });

    test('rescheduleAllNotifications schedules deterministic payloads and handles toggle/test', () async {
      notifications.clearRecords();

      final ev = await provider.addDepartureEvent(
        title: 'Leaving for work',
        presetId: DeparturePreset.workPresetId,
        hour: 7,
        minute: 10,
        recurrence: DepartureRecurrenceType.weekdays,
        selectedDays: const {1, 2, 3, 4, 5},
        leadMinutes: 250, // tests clamping to maxLeadMinutes (180)
      );

      expect(ev.leadMinutes, DepartureEvent.maxLeadMinutes);

      notifications.clearRecords();
      final sundayMorning = DateTime(2026, 11, 15, 8, 0);
      await provider.rescheduleAllNotifications(nowOverride: sundayMorning);

      expect(provider.lastScheduledNotificationsCount, 5);
      expect(notifications.scheduled.length, 5);
      final firstNotif = notifications.scheduled.first;
      expect(firstNotif.id, BeforeYouGoProvider.notificationIdFor(ev.id, 0));
      expect(firstNotif.title, contains('Scout BeforeYouGo: Leaving for work'));
      expect(firstNotif.body, contains('Work Checklist:'));
      expect(firstNotif.body, contains('Keys & Wallet'));

      final parsed = BeforeYouGoProvider.parsePayload(firstNotif.payload);
      expect(parsed?.eventId, ev.id);
      expect(parsed?.presetId, DeparturePreset.workPresetId);

      await provider.triggerTestNotification(ev.id);
      expect(notifications.shown.length, 1);
      expect(notifications.shown.first.id, BeforeYouGoProvider.testNotificationId);

      notifications.clearRecords();
      await provider.toggleDepartureEventEnabled(ev.id);
      expect(provider.findEventById(ev.id)!.isEnabled, isFalse);
      await provider.rescheduleAllNotifications(nowOverride: sundayMorning);
      expect(provider.lastScheduledNotificationsCount, 0);
      expect(notifications.scheduled, isEmpty);
      expect(notifications.cancelledIds.length, greaterThanOrEqualTo(8));
    });
  });

  group('Calendar Sync, Dashboard Config & Backup Roundtrip', () {
    test('CalendarEvent roundtrip and BeforeYouGoProvider calendar linking', () async {
      final start = DateTime(2026, 11, 18, 15, 0);
      final cal = CalendarEvent(
        id: 'cal_1',
        title: 'Dentist Visit',
        date: start,
        startTime: const TimeOfDay(hour: 15, minute: 0),
        category: AlarmCategory.fromType(AlarmCategoryType.health),
        hasReminder: true,
        beforeYouGoPresetId: DeparturePreset.everydayPresetId,
        departureLeadMinutes: 20,
        createdAt: DateTime(2026, 11, 14),
      );

      expect(cal.hasDepartureHeadsUp, isTrue);
      final roundtrip = CalendarEvent.fromJson(cal.toJson());
      expect(roundtrip.beforeYouGoPresetId, DeparturePreset.everydayPresetId);
      expect(roundtrip.departureLeadMinutes, 20);
      expect(roundtrip.copyWith(clearBeforeYouGo: true).hasDepartureHeadsUp, isFalse);

      final linked = await provider.upsertFromCalendarEvent(
        cal,
        presetId: DeparturePreset.everydayPresetId,
        leadMinutes: 20,
      );
      expect(linked, isNotNull);
      expect(linked!.linkedCalendarEventId, 'cal_1');
      expect(provider.events.length, 1);

      // Updating same calendar event updates existing departure record rather than duplicating
      await provider.upsertFromCalendarEvent(
        cal.copyWith(title: 'Dentist Checkup'),
        presetId: DeparturePreset.workPresetId,
        leadMinutes: 45,
      );
      expect(provider.events.length, 1);
      expect(provider.events.first.title, 'Dentist Checkup');
      expect(provider.events.first.presetId, DeparturePreset.workPresetId);
      expect(provider.events.first.leadMinutes, 45);

      await provider.removeByLinkedCalendarEventId('cal_1');
      expect(provider.events, isEmpty);
    });

    test('DashboardConfig migrates sectionBeforeYouGo and toggles visibility', () async {
      final legacy = DashboardConfig.fromJson(const {
        'sectionOrder': ['quick_stats', 'habits'],
        'showQuickStats': true,
      });
      expect(
        legacy.sectionOrder.contains(DashboardConfig.sectionBeforeYouGo),
        isTrue,
      );
      expect(legacy.showBeforeYouGo, isTrue);

      final dashProvider = DashboardProvider(storage);
      await dashProvider.toggleBeforeYouGo(false);
      expect(dashProvider.config.showBeforeYouGo, isFalse);
      final reloaded = DashboardProvider(storage);
      expect(reloaded.config.showBeforeYouGo, isFalse);
    });

    test('StorageService full backup export/restore preserves BeforeYouGo presets and schedules', () async {
      final custom = await provider.createPreset(name: 'Weekend Bag');
      await provider.addItem(custom.id, 'Camera', isEssential: true);
      await provider.addDepartureEvent(
        title: 'Train to Bandung',
        presetId: custom.id,
        hour: 6,
        minute: 45,
        recurrence: DepartureRecurrenceType.oneTime,
        oneTimeDate: DateTime(2026, 11, 21),
        leadMinutes: 30,
      );

      final backupJson = storage.exportFullBackupJson();

      // Wipe storage and restore from backup JSON
      SharedPreferences.setMockInitialValues({});
      final freshStorage = await StorageService.init();
      final result = await freshStorage.restoreFullBackupJson(backupJson);
      expect(result, isTrue);

      final restoredProvider = BeforeYouGoProvider(freshStorage, notifications);
      addTearDown(restoredProvider.dispose);

      expect(restoredProvider.activePresetId, custom.id);
      expect(restoredProvider.findPresetById(custom.id)?.items.last.label, 'Camera');
      expect(restoredProvider.events.single.title, 'Train to Bandung');
      expect(restoredProvider.events.single.leadMinutes, 30);
    });
  });

  group('Widget Integration Tests', () {
    testWidgets('BeforeYouGoCard switches presets, checks items, and resets cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BeforeYouGoProvider>.value(
            value: provider,
            child: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: BeforeYouGoCard(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BeforeYouGo • Scout'), findsOneWidget);
      expect(find.text('0/5 Ready'), findsOneWidget);
      expect(find.text('Keys & Wallet'), findsOneWidget);

      // Switch preset chip to Work
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      expect(provider.activePresetId, DeparturePreset.workPresetId);
      expect(find.text('Work ID / Badge'), findsOneWidget);

      // Toggle first item
      await tester.tap(find.text('Keys & Wallet'));
      await tester.pumpAndSettle();
      expect(find.text('1/5 Ready'), findsOneWidget);

      // Reset checklist
      await tester.tap(find.byTooltip('Reset Checklist'));
      await tester.pumpAndSettle();
      expect(find.text('0/5 Ready'), findsOneWidget);
    });

    testWidgets('BeforeYouGoSheet manages custom checklist items and quick schedules', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BeforeYouGoProvider>.value(
            value: provider,
            child: const Scaffold(
              body: BeforeYouGoSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Add new custom item on Checklists tab
      await tester.enterText(
        find.byType(TextField).first,
        'Umbrella & Sunglasses',
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(
        provider.activePreset.items.any((i) => i.label == 'Umbrella & Sunglasses'),
        isTrue,
      );
      await tester.dragUntilVisible(
        find.text('Umbrella & Sunglasses'),
        find.byType(ReorderableListView),
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();
      expect(find.text('Umbrella & Sunglasses'), findsOneWidget);

      // Switch to Schedules tab
      await tester.tap(find.text('Schedules (0)'));
      await tester.pumpAndSettle();

      expect(find.text('No Smart Departure Heads-Up Yet'), findsOneWidget);

      // Tap quick preset action for recurring Work commute & one-time Airport
      await tester.tap(find.text('Leaving for Work (Mon–Fri 07:10)'));
      await tester.pumpAndSettle();
      expect(provider.events.length, 1);
      expect(provider.events.first.title, 'Leaving for work');
      expect(provider.events.first.leadMinutes, 15);
      expect(find.text('Schedules (1)'), findsOneWidget);
      expect(find.text('Leaving for work'), findsOneWidget);
    });

    testWidgets('showDepartureEventEditorDialog creates custom one-time schedule', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BeforeYouGoProvider>.value(
            value: provider,
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showDepartureEventEditorDialog(context),
                    child: const Text('Open Editor'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Editor'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Event Title'),
        'Going to airport',
      );
      await tester.tap(find.text('One-time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30m before'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Schedule'));
      await tester.pumpAndSettle();

      expect(provider.events.length, 1);
      expect(provider.events.single.title, 'Going to airport');
      expect(provider.events.single.recurrence, DepartureRecurrenceType.oneTime);
      expect(provider.events.single.leadMinutes, 30);
    });

    testWidgets('CalendarScreen attaches Scout BeforeYouGo Heads-Up when saving a new event', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final calendarProvider = CalendarProvider(storage);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CalendarProvider>.value(
              value: calendarProvider,
            ),
            ChangeNotifierProvider<BeforeYouGoProvider>.value(
              value: provider,
            ),
          ],
          child: const MaterialApp(
            home: CalendarScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open New Event sheet
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Event Title'),
        'Flight to Bali',
      );

      final toggle = find.text('Scout BeforeYouGo Heads-Up');
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      final saveBtn = find.text('Save Event');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Flight to Bali'), findsOneWidget);
      expect(provider.events.length, 1);
      expect(provider.events.single.title, 'Flight to Bali');
      expect(provider.events.single.linkedCalendarEventId, isNotNull);
    });
  });

  group('Departure Notification Inline Actions ("Mark All Ready" & "Snooze 5m")', () {
    test('buildDepartureNotificationDetails attaches both Android shade inline actions cleanly', () {
      final withActions = NotificationService.buildDepartureNotificationDetails();
      final actions = withActions.android!.actions!;
      expect(actions.length, 2);
      expect(actions[0].id, NotificationService.actionDepartureMarkAllReady);
      expect(actions[0].title, 'Mark All Ready');
      expect(actions[0].showsUserInterface, isFalse);
      expect(actions[0].cancelNotification, isTrue);

      expect(actions[1].id, NotificationService.actionDepartureSnooze5m);
      expect(actions[1].title, 'Snooze 5m');
      expect(actions[1].showsUserInterface, isFalse);
      expect(actions[1].cancelNotification, isTrue);

      expect(
        withActions.iOS!.categoryIdentifier,
        NotificationService.departureCategoryId,
      );

      final withoutActions = NotificationService.buildDepartureNotificationDetails(
        includeInlineActions: false,
      );
      expect(withoutActions.android!.actions, isNull);
    });

    test('Foreground "Mark All Ready" checks entire preset, marks event ready today, cancels active snooze, and keeps tomorrow alert', () async {
      final now = DateTime(2026, 11, 16, 6, 56); // Mon 06:56
      final ev = await provider.addDepartureEvent(
        title: 'Leaving for work',
        presetId: DeparturePreset.workPresetId,
        hour: 7,
        minute: 10,
        recurrence: DepartureRecurrenceType.weekdays,
        selectedDays: const {1, 2, 3, 4, 5},
        leadMinutes: 15,
      );

      // Simulate an active 5m snooze on Mon before user taps Mark All Ready
      await provider.snoozeDeparture(
        eventId: ev.id,
        presetId: ev.presetId,
        nowOverride: now,
      );
      expect(provider.snoozeForEvent(ev.id, now), isNotNull);

      notifications.clearRecords();
      final notifId = BeforeYouGoProvider.notificationIdFor(ev.id, 0);
      final handled = await provider.handleNotificationResponse(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: notifId,
          actionId: NotificationService.actionDepartureMarkAllReady,
          payload: BeforeYouGoProvider.buildPayload(
            ev.id,
            DeparturePreset.workPresetId,
          ),
        ),
        nowOverride: now,
      );

      expect(handled, isTrue);
      final workPreset = provider.findPresetById(DeparturePreset.workPresetId)!;
      expect(workPreset.allChecked, isTrue);
      expect(workPreset.checkedCount, workPreset.totalCount);

      final updatedEvent = provider.findEventById(ev.id)!;
      expect(updatedEvent.isCompletedForDate(now), isTrue);
      expect(provider.snoozeForEvent(ev.id, now), isNull);

      final dateKey = DepartureEvent.formatDateKey(now);
      expect(notifications.cancelledIds, contains(notifId));
      expect(
        notifications.cancelledIds,
        contains(DepartureSnooze.snoozedNotificationId(ev.id, dateKey)),
      );
      // Today's remaining schedule stays clear, future Tue..Fri remain scheduled
      expect(
        notifications.scheduled.every(
          (n) => DepartureEvent.formatDateKey(n.scheduledDate!) != dateKey,
        ),
        isTrue,
      );
    });

    test('Foreground "Snooze 5m" schedules +5m notification with inline actions and increments repeat count', () async {
      final now = DateTime(2026, 11, 16, 6, 55);
      final ev = await provider.addDepartureEvent(
        title: 'Morning Commute',
        presetId: DeparturePreset.workPresetId,
        hour: 7,
        minute: 10,
        recurrence: DepartureRecurrenceType.daily,
        leadMinutes: 15,
      );
      notifications.clearRecords();

      final notifId = BeforeYouGoProvider.notificationIdFor(ev.id, 0);
      final payload = BeforeYouGoProvider.buildPayload(
        ev.id,
        DeparturePreset.workPresetId,
      );

      final firstHandled = await provider.handleNotificationResponse(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: notifId,
          actionId: NotificationService.actionDepartureSnooze5m,
          payload: payload,
        ),
        nowOverride: now,
      );

      expect(firstHandled, isTrue);
      final snooze1 = provider.snoozeForEvent(ev.id, now);
      expect(snooze1, isNotNull);
      expect(snooze1!.snoozeCount, 1);
      expect(snooze1.snoozedUntil, now.add(const Duration(minutes: 5)));
      expect(notifications.cancelledIds, contains(notifId));
      expect(notifications.scheduled.length, 1);
      expect(
        notifications.scheduled.single.id,
        DepartureSnooze.snoozedNotificationId(
          ev.id,
          DepartureEvent.formatDateKey(now),
        ),
      );
      expect(
        notifications.scheduled.single.scheduledDate,
        now.add(const Duration(minutes: 5)),
      );
      expect(notifications.scheduled.single.title, contains('Snoozed +5m'));
      expect(notifications.scheduled.single.includeInlineActions, isTrue);

      // Tap Snooze 5m a second time from the snoozed shade alert
      final secondHandled = await provider.handleNotificationResponse(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: notifications.scheduled.single.id,
          actionId: NotificationService.actionDepartureSnooze5m,
          payload: payload,
        ),
        nowOverride: now.add(const Duration(minutes: 5)),
      );

      expect(secondHandled, isTrue);
      final snooze2 = provider.snoozeForEvent(ev.id, now);
      expect(snooze2!.snoozeCount, 2);
      expect(snooze2.snoozedUntil, now.add(const Duration(minutes: 10)));
    });

    test('Background shade actions ("Snooze 5m" & "Mark All Ready") persist and sync on reload', () async {
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        7,
        0,
      );
      final ev = await provider.addDepartureEvent(
        title: 'Catch Train',
        presetId: DeparturePreset.everydayPresetId,
        hour: 7,
        minute: 15,
        recurrence: DepartureRecurrenceType.oneTime,
        oneTimeDate: today,
        leadMinutes: 15,
      );
      notifications.clearRecords();

      // Unrelated or empty payloads must be ignored cleanly
      final ignored = await NotificationService.handleBackgroundNotificationAction(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: 901,
          actionId: NotificationService.actionDepartureMarkAllReady,
          payload: 'medication_dose:med_1:08:00',
        ),
        storageOverride: storage,
        notificationOverride: notifications,
        nowOverride: today,
      );
      expect(ignored, isFalse);

      // Background Snooze 5m
      final payload = BeforeYouGoProvider.buildPayload(
        ev.id,
        DeparturePreset.everydayPresetId,
      );
      final snoozeOk =
          await NotificationService.handleBackgroundNotificationAction(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: 902,
          actionId: NotificationService.actionDepartureSnooze5m,
          payload: payload,
        ),
        storageOverride: storage,
        notificationOverride: notifications,
        nowOverride: today,
      );
      expect(snoozeOk, isTrue);

      await provider.reloadFromStorage();
      final restoredSnooze = provider.snoozeForEvent(ev.id, today);
      expect(restoredSnooze, isNotNull);
      expect(
        restoredSnooze!.snoozedUntil,
        today.add(const Duration(minutes: 5)),
      );

      // Background Mark All Ready from bare active-preset fallback payload
      await provider.selectActivePreset(DeparturePreset.travelPresetId);
      final readyOk =
          await NotificationService.handleBackgroundNotificationAction(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: 903,
          actionId: NotificationService.actionDepartureMarkAllReady,
          payload: BeforeYouGoProvider.payloadPrefix,
        ),
        storageOverride: storage,
        notificationOverride: notifications,
        nowOverride: today,
      );
      expect(readyOk, isTrue);

      await provider.reloadFromStorage();
      expect(
        provider.findPresetById(DeparturePreset.travelPresetId)!.allChecked,
        isTrue,
      );
    });

    test('JSON backup export/restore preserves departureSnoozes', () async {
      final ev = await provider.addDepartureEvent(
        title: 'Afternoon Bus',
        presetId: DeparturePreset.everydayPresetId,
        hour: 17,
        minute: 30,
        recurrence: DepartureRecurrenceType.oneTime,
        oneTimeDate: DateTime.now(),
        leadMinutes: 15,
      );

      final snoozed = await provider.snoozeDeparture(
        eventId: ev.id,
        presetId: ev.presetId,
      );
      expect(snoozed, isNotNull);

      final backupJson = storage.exportFullBackupJson();
      expect(backupJson, contains('departureSnoozes'));
      expect(backupJson, contains(ev.id));

      SharedPreferences.setMockInitialValues({});
      final freshStorage = await StorageService.init();
      final restoredOk = await freshStorage.restoreFullBackupJson(backupJson);
      expect(restoredOk, isTrue);

      final restoredSnoozes = freshStorage.loadDepartureSnoozes();
      expect(restoredSnoozes.length, 1);
      expect(restoredSnoozes.first.eventId, ev.id);
    });

    testWidgets('BeforeYouGoCard Mark All Ready button checks entire preset and shows snooze pill', (tester) async {
      final now = DateTime.now();
      final futureDep = now.add(const Duration(hours: 2));
      final ev = await provider.addDepartureEvent(
        title: 'Team Sync',
        presetId: DeparturePreset.everydayPresetId,
        hour: futureDep.hour,
        minute: futureDep.minute,
        recurrence: DepartureRecurrenceType.oneTime,
        oneTimeDate: futureDep,
        leadMinutes: 15,
      );
      await provider.snoozeDeparture(
        eventId: ev.id,
        presetId: ev.presetId,
        nowOverride: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BeforeYouGoProvider>.value(
            value: provider,
            child: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: BeforeYouGoCard(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Snoozed +5m until'), findsOneWidget);
      expect(find.text('Mark All Ready'), findsOneWidget);

      await tester.tap(find.text('Mark All Ready'));
      await tester.pumpAndSettle();

      expect(find.text('5/5 Ready'), findsOneWidget);
      expect(find.text('All Ready ✓'), findsOneWidget);
      expect(find.textContaining('Snoozed +5m until'), findsNothing);
    });

    testWidgets('BeforeYouGoSheet supports Mark All Ready & inline Snooze 5m on schedules', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await provider.addDepartureEvent(
        title: 'Morning Studio',
        presetId: DeparturePreset.everydayPresetId,
        hour: 23,
        minute: 30,
        recurrence: DepartureRecurrenceType.daily,
        leadMinutes: 15,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BeforeYouGoProvider>.value(
            value: provider,
            child: const Scaffold(
              body: BeforeYouGoSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Schedules tab first and trigger Snooze 5m
      await tester.tap(find.text('Schedules (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Snooze 5m'), findsOneWidget);
      await tester.tap(find.text('Snooze 5m'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Snoozed +5m ->'), findsOneWidget);

      // Switch back to Checklists tab and tap Mark All Ready
      await tester.tap(find.text('Checklists (0/5)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mark All Ready'));
      await tester.pumpAndSettle();

      expect(find.text('Checklists (5/5)'), findsOneWidget);
      expect(find.text('Everyday • 5/5 packed'), findsOneWidget);
    });
  });
}
