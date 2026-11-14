import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:nestin/data/models/medication_item.dart';
import 'package:nestin/data/models/medication_log.dart';
import 'package:nestin/data/models/medication_snooze.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/providers/medication_provider.dart';
import 'package:nestin/ui/widgets/medication_tracker_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => true,
    );
  });

  group('MedicationItem Model Tests', () {
    test('Default values initialize correctly', () {
      final now = DateTime.now();
      final item = MedicationItem(
        id: 'med_1',
        name: 'Vitamin D3',
        createdAt: now,
      );

      expect(item.dosageAmount, equals(1.0));
      expect(item.dosageUnit, equals('pills'));
      expect(item.mealInstruction, equals(MealInstruction.anytime));
      expect(item.scheduleTimes, equals(['08:00']));
      expect(item.daysOfWeek, equals([1, 2, 3, 4, 5, 6, 7]));
      expect(item.currentStock, isNull);
      expect(item.refillThreshold, equals(5));
      expect(item.isActive, isTrue);
      expect(item.isLowStock, isFalse);
      expect(item.dosageString, equals('1 pill'));
    });

    test('isLowStock computes true when stock <= threshold', () {
      final item = MedicationItem(
        id: 'med_2',
        name: 'Amoxicillin',
        dosageAmount: 2.0,
        currentStock: 4,
        refillThreshold: 5,
        refillWarningEnabled: true,
        createdAt: DateTime.now(),
      );

      expect(item.isLowStock, isTrue);
      expect(item.dosageString, equals('2 pills'));

      final stockedItem = item.copyWith(currentStock: 20);
      expect(stockedItem.isLowStock, isFalse);
    });

    test('dosageString formats units correctly', () {
      final mgItem = MedicationItem(
        id: 'med_mg',
        name: 'Metformin',
        dosageAmount: 500.0,
        dosageUnit: 'mg',
        createdAt: DateTime.now(),
      );
      expect(mgItem.dosageString, equals('500 mg'));

      final mlItem = MedicationItem(
        id: 'med_ml',
        name: 'Cough Syrup',
        dosageAmount: 10.0,
        dosageUnit: 'ml',
        createdAt: DateTime.now(),
      );
      expect(mlItem.dosageString, equals('10 ml'));
    });

    test('isScheduledForDate checks weekday accurately', () {
      // 2026-11-13 is a Friday (weekday = 5)
      final friday = DateTime(2026, 11, 13);
      final sunday = DateTime(2026, 11, 15);

      final weekdaysOnly = MedicationItem(
        id: 'med_weekdays',
        name: 'Blood Pressure',
        daysOfWeek: [1, 2, 3, 4, 5], // Mon-Fri
        createdAt: DateTime.now(),
      );

      expect(weekdaysOnly.isScheduledForDate(friday), isTrue);
      expect(weekdaysOnly.isScheduledForDate(sunday), isFalse);
    });

    test('JSON serialization roundtrip preserves all fields', () {
      final now = DateTime(2026, 11, 13, 8, 30);
      final item = MedicationItem(
        id: 'med_roundtrip',
        name: 'Omega-3 Fish Oil',
        dosageAmount: 2.0,
        dosageUnit: 'capsules',
        mealInstruction: MealInstruction.withMeal,
        scheduleTimes: ['08:00', '20:00'],
        daysOfWeek: [1, 3, 5],
        currentStock: 60,
        refillThreshold: 10,
        refillWarningEnabled: true,
        notes: 'Take with full glass of water',
        isActive: true,
        colorHex: '#10B981',
        createdAt: now,
      );

      final json = item.toJson();
      final restored = MedicationItem.fromJson(json);

      expect(restored.id, equals(item.id));
      expect(restored.name, equals(item.name));
      expect(restored.dosageAmount, equals(item.dosageAmount));
      expect(restored.dosageUnit, equals(item.dosageUnit));
      expect(restored.mealInstruction, equals(MealInstruction.withMeal));
      expect(restored.scheduleTimes, equals(['08:00', '20:00']));
      expect(restored.daysOfWeek, equals([1, 3, 5]));
      expect(restored.currentStock, equals(60));
      expect(restored.refillThreshold, equals(10));
      expect(restored.notes, equals('Take with full glass of water'));
      expect(restored.colorHex, equals('#10B981'));
    });
  });

  group('MedicationLog Model Tests', () {
    test('JSON serialization roundtrip preserves action and scheduled time', () {
      final scheduled = DateTime(2026, 11, 13, 8, 0);
      final actionTime = DateTime(2026, 11, 13, 8, 5);

      final log = MedicationLog(
        id: 'log_1',
        medicationId: 'med_1',
        medicationName: 'Vitamin D3',
        doseAmount: 1.0,
        doseUnit: 'pills',
        scheduledTimeString: '08:00',
        scheduledDateTime: scheduled,
        actionTime: actionTime,
        action: MedicationAction.taken,
        reason: null,
      );

      final json = log.toJson();
      final restored = MedicationLog.fromJson(json);

      expect(restored.id, equals(log.id));
      expect(restored.medicationId, equals(log.medicationId));
      expect(restored.action, equals(MedicationAction.taken));
      expect(restored.scheduledTimeString, equals('08:00'));
    });
  });

  group('MedicationProvider State & Dose Tracking Tests', () {
    late StorageService storageService;
    late NotificationService notificationService;
    late MedicationProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
      notificationService = NotificationService();
      provider = MedicationProvider(storageService, notificationService);
    });

    test('Add, update, toggle and delete medication', () async {
      expect(provider.medications, isEmpty);

      final med = MedicationItem(
        id: 'med_test_1',
        name: 'B-Complex',
        dosageAmount: 1.0,
        createdAt: DateTime.now(),
      );

      await provider.addMedication(med);
      expect(provider.medications.length, equals(1));
      expect(provider.activeMedications.length, equals(1));

      // Toggle active
      await provider.toggleActive('med_test_1');
      expect(provider.activeMedications, isEmpty);

      await provider.toggleActive('med_test_1');
      expect(provider.activeMedications.length, equals(1));

      // Update
      final updated = med.copyWith(name: 'Super B-Complex');
      await provider.updateMedication(updated);
      expect(provider.medications.first.name, equals('Super B-Complex'));

      // Delete
      await provider.deleteMedication('med_test_1');
      expect(provider.medications, isEmpty);
    });

    test('1-Tap Take decrements stock and triggers low stock alert', () async {
      final med = MedicationItem(
        id: 'med_stock_test',
        name: 'Iron Supplement',
        dosageAmount: 1.0,
        currentStock: 6,
        refillThreshold: 5,
        scheduleTimes: ['08:00'],
        createdAt: DateTime.now(),
      );

      await provider.addMedication(med);
      expect(provider.hasLowStockWarnings, isFalse);

      // Record dose as Taken
      await provider.recordDose(
        medicationId: 'med_stock_test',
        timeString: '08:00',
        action: MedicationAction.taken,
      );

      expect(provider.logs.length, equals(1));
      expect(provider.logs.first.action, equals(MedicationAction.taken));

      // Stock should decrement from 6 to 5
      expect(provider.medications.first.currentStock, equals(5));
      // Now stock <= refillThreshold (5 <= 5), so low stock warning becomes active!
      expect(provider.hasLowStockWarnings, isTrue);
      expect(provider.lowStockMedications.length, equals(1));
    });

    test('1-Tap Skip does not decrement stock', () async {
      final med = MedicationItem(
        id: 'med_skip_test',
        name: 'Melatonin',
        dosageAmount: 1.0,
        currentStock: 10,
        scheduleTimes: ['22:00'],
        createdAt: DateTime.now(),
      );

      await provider.addMedication(med);

      await provider.recordDose(
        medicationId: 'med_skip_test',
        timeString: '22:00',
        action: MedicationAction.skipped,
        reason: 'Not needed tonight',
      );

      expect(provider.logs.length, equals(1));
      expect(provider.logs.first.action, equals(MedicationAction.skipped));
      // Stock should remain 10
      expect(provider.medications.first.currentStock, equals(10));
    });

    test('Undo dose removes log and restores stock', () async {
      final med = MedicationItem(
        id: 'med_undo_test',
        name: 'Zinc',
        dosageAmount: 1.0,
        currentStock: 20,
        scheduleTimes: ['09:00'],
        createdAt: DateTime.now(),
      );

      await provider.addMedication(med);

      final log = await provider.recordDose(
        medicationId: 'med_undo_test',
        timeString: '09:00',
        action: MedicationAction.taken,
      );

      expect(provider.medications.first.currentStock, equals(19));
      expect(provider.logs.length, equals(1));

      // Undo
      await provider.undoDose(log!.id);

      expect(provider.logs, isEmpty);
      expect(provider.medications.first.currentStock, equals(20));
    });

    test('Refill medication increases stock and clears low-stock warning', () async {
      final med = MedicationItem(
        id: 'med_refill_test',
        name: 'Allergy Med',
        currentStock: 2,
        refillThreshold: 5,
        createdAt: DateTime.now(),
      );

      await provider.addMedication(med);
      expect(provider.hasLowStockWarnings, isTrue);

      await provider.refillMedication('med_refill_test', 30);

      expect(provider.medications.first.currentStock, equals(32));
      expect(provider.hasLowStockWarnings, isFalse);
    });

    test('Full JSON life backup export and restore preserves medications and logs', () async {
      final med = MedicationItem(
        id: 'med_backup_1',
        name: 'Prescription A',
        dosageAmount: 1.0,
        currentStock: 25,
        scheduleTimes: ['08:00', '20:00'],
        createdAt: DateTime.now(),
      );

      await provider.addMedication(med);
      await provider.recordDose(
        medicationId: 'med_backup_1',
        timeString: '08:00',
        action: MedicationAction.taken,
      );

      // Export full backup
      final backupJson = storageService.exportFullBackupJson();
      expect(backupJson, contains('med_backup_1'));
      expect(backupJson, contains('Prescription A'));

      // Clear storage
      SharedPreferences.setMockInitialValues({});
      final newPrefs = await SharedPreferences.getInstance();
      final newStorage = StorageService(newPrefs);

      // Restore
      final restoreSuccess = await newStorage.restoreFullBackupJson(backupJson);
      expect(restoreSuccess, isTrue);

      final restoredMeds = newStorage.loadMedications();
      final restoredLogs = newStorage.loadMedicationLogs();

      expect(restoredMeds.length, equals(1));
      expect(restoredMeds.first.name, equals('Prescription A'));
      expect(restoredLogs.length, equals(1));
      expect(restoredLogs.first.action, equals(MedicationAction.taken));
    });
  });

  group('MedicationTrackerSheet Widget Tests', () {
    testWidgets('Renders sheet with title, streak strip, tabs, and add button',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      final notif = NotificationService();
      final provider = MedicationProvider(storage, notif);

      await provider.addMedication(
        MedicationItem(
          id: 'widget_med_1',
          name: 'Vitamin C',
          dosageAmount: 1.0,
          mealInstruction: MealInstruction.withMeal,
          scheduleTimes: ['09:00'],
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<MedicationProvider>.value(
              value: provider,
              child: const MedicationTrackerSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Medication & Pill Tracker'), findsOneWidget);
      expect(find.text('Seren Wellness Companion'), findsOneWidget);
      expect(find.text('Vitamin C'), findsOneWidget);
      expect(find.text('Snooze 15m'), findsOneWidget);
      expect(find.text('Take'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Add New Medication'), findsOneWidget);
    });

    testWidgets('1-Tap Snooze 15m updates card badge and clears when taken',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      final notif = NotificationService();
      final provider = MedicationProvider(storage, notif);

      await provider.addMedication(
        MedicationItem(
          id: 'widget_snooze_1',
          name: 'Magnesium Glycinate',
          dosageAmount: 2.0,
          dosageUnit: 'capsules',
          mealInstruction: MealInstruction.afterMeal,
          scheduleTimes: ['21:00'],
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<MedicationProvider>.value(
              value: provider,
              child: const MedicationTrackerSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Snooze 15m'));
      await tester.pumpAndSettle();

      final slot = provider.todayDoses.first;
      expect(slot.isSnoozed, isTrue);
      expect(
        find.text('Snoozed until ${slot.snooze!.formattedSnoozedUntil}'),
        findsOneWidget,
      );

      // Marking Take automatically clears snooze indicator
      await tester.tap(find.text('Take'));
      await tester.pumpAndSettle();

      expect(provider.todayDoses.first.isTaken, isTrue);
      expect(provider.todayDoses.first.isSnoozed, isFalse);
      expect(find.text('Taken'), findsOneWidget);
    });
  });

  group('Medication Dose Time Snooze Unit & Notification Tests', () {
    test('MedicationSnooze payload build/parse and deterministic IDs', () {
      final payload = MedicationSnooze.buildDosePayload('med_42', '08:30');
      expect(payload, equals('medication_dose:med_42:08:30'));

      final parsed = MedicationSnooze.parseDosePayload(payload);
      expect(parsed, isNotNull);
      expect(parsed!.medicationId, equals('med_42'));
      expect(parsed.timeString, equals('08:30'));

      expect(MedicationSnooze.parseDosePayload('wind_down'), isNull);
      expect(MedicationSnooze.parseDosePayload('medication_dose:'), isNull);
      expect(MedicationSnooze.parseDosePayload('medication_dose:bad'), isNull);

      final idA = MedicationSnooze.regularDoseNotificationId('m1', '08:00', 0);
      final idB = MedicationSnooze.regularDoseNotificationId('m1', '08:00', 0);
      final snoozeId =
          MedicationSnooze.snoozedDoseNotificationId('m1', '08:00', '2026-11-14');
      expect(idA, equals(idB));
      expect(snoozeId, isNot(equals(idA)));
      expect(snoozeId, greaterThanOrEqualTo(100000));
    });

    test('NotificationService schedules Snooze 15m action button payload',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();

      final methodCalls = <MethodCall>[];
      const channel = MethodChannel('dexterous.com/flutter/local_notifications');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (call) async {
          methodCalls.add(call);
          return true;
        },
      );
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async => true);
      });

      final notif = NotificationService();
      await notif.scheduleMedicationNotification(
        id: 555,
        title: 'Take Med',
        body: '1 pill',
        scheduledDate: DateTime.now().add(const Duration(minutes: 10)),
        payload: 'medication_dose:med_1:09:00',
      );

      final zonedCall = methodCalls.lastWhere(
        (c) => c.method == 'zonedSchedule',
      );
      final args = Map<String, dynamic>.from(zonedCall.arguments as Map);
      final platformSpecifics =
          Map<String, dynamic>.from(args['platformSpecifics'] as Map);
      final actions = (platformSpecifics['actions'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      expect(actions.length, equals(1));
      expect(
        actions.first['id'],
        equals(NotificationService.actionMedicationSnooze15m),
      );
      expect(actions.first['title'], equals('Snooze 15m'));
      expect(actions.first['showsUserInterface'], isFalse);
      expect(actions.first['cancelNotification'], isTrue);
    });

    test('Foreground NotificationResponse Snooze 15m snoozes dose and repeats stack',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      final notif = NotificationService();
      final provider = MedicationProvider(storage, notif);

      await provider.addMedication(
        MedicationItem(
          id: 'med_fg_snooze',
          name: 'Vitamin D3',
          dosageAmount: 1.0,
          mealInstruction: MealInstruction.withMeal,
          scheduleTimes: ['08:00'],
          createdAt: DateTime.now(),
        ),
      );

      final handled = await provider.handleNotificationResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: 1234,
          actionId: NotificationService.actionMedicationSnooze15m,
          payload: 'medication_dose:med_fg_snooze:08:00',
        ),
        nowOverride: DateTime(2026, 11, 14, 11, 0),
      );

      expect(handled, isTrue);
      final snooze1 = provider.snoozeForSlot(
        'med_fg_snooze',
        '08:00',
        DateTime(2026, 11, 14),
      );
      expect(snooze1, isNotNull);
      expect(snooze1!.snoozeCount, equals(1));
      expect(snooze1.snoozedUntil, equals(DateTime(2026, 11, 14, 11, 15)));

      // Second tap snoozes another 15 minutes and increments count
      await provider.handleNotificationResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: 5678,
          actionId: NotificationService.actionMedicationSnooze15m,
          payload: 'medication_dose:med_fg_snooze:08:00',
        ),
        nowOverride: DateTime(2026, 11, 14, 11, 15),
      );

      final snooze2 = provider.snoozeForSlot(
        'med_fg_snooze',
        '08:00',
        DateTime(2026, 11, 14),
      );
      expect(snooze2!.snoozeCount, equals(2));
      expect(snooze2.snoozedUntil, equals(DateTime(2026, 11, 14, 11, 30)));
    });

    test('Background notification action persists snooze and syncs on reload',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      final notif = NotificationService();
      final provider = MedicationProvider(storage, notif);

      await provider.addMedication(
        MedicationItem(
          id: 'med_bg_snooze',
          name: 'Omega-3',
          dosageAmount: 1.0,
          scheduleTimes: ['12:00'],
          createdAt: DateTime.now(),
        ),
      );

      final bgNow = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        12,
        0,
      );

      final ok = await NotificationService.handleBackgroundNotificationAction(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: 99,
          actionId: NotificationService.actionMedicationSnooze15m,
          payload: 'medication_dose:med_bg_snooze:12:00',
        ),
        storageOverride: storage,
        notificationOverride: notif,
        nowOverride: bgNow,
      );

      expect(ok, isTrue);
      await provider.reloadFromStorage();
      final restored = provider.snoozeForSlot('med_bg_snooze', '12:00', bgNow);
      expect(restored, isNotNull);
      expect(restored!.snoozedUntil, equals(bgNow.add(const Duration(minutes: 15))));
    });

    test('JSON backup export and restore preserves medicationSnoozes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      final notif = NotificationService();
      final provider = MedicationProvider(storage, notif);

      await provider.addMedication(
        MedicationItem(
          id: 'med_backup_snz',
          name: 'Probiotic',
          scheduleTimes: ['09:00'],
          createdAt: DateTime.now(),
        ),
      );

      final snoozed = await provider.snoozeDose(
        medicationId: 'med_backup_snz',
        timeString: '09:00',
      );
      expect(snoozed, isNotNull);

      final jsonStr = storage.exportFullBackupJson();
      expect(jsonStr, contains('medicationSnoozes'));
      expect(jsonStr, contains('med_backup_snz'));

      SharedPreferences.setMockInitialValues({});
      final freshStorage = StorageService(await SharedPreferences.getInstance());
      final restoredOk = await freshStorage.restoreFullBackupJson(jsonStr);
      expect(restoredOk, isTrue);

      final restoredSnoozes = freshStorage.loadMedicationSnoozes();
      expect(restoredSnoozes.length, equals(1));
      expect(restoredSnoozes.first.medicationId, equals('med_backup_snz'));
    });
  });
}

