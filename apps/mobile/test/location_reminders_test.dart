import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/data/models/alarm_category.dart';
import 'package:nestin/data/models/dashboard_config.dart';
import 'package:nestin/data/models/location_reminder.dart';
import 'package:nestin/data/models/saved_place.dart';
import 'package:nestin/data/services/geofencing_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/dashboard_provider.dart';
import 'package:nestin/providers/geofence_provider.dart';
import 'package:nestin/ui/widgets/location_reminders_card.dart';
import 'package:nestin/ui/widgets/location_reminders_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SavedPlace Model Tests', () {
    test('Computes Haversine distances and boundary containment accurately', () {
      final home = SavedPlace(
        id: 'home',
        name: 'Home',
        latitude: 37.7749,
        longitude: -122.4194,
        radiusMeters: 150.0,
        category: PlaceCategory.home,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(home.containsCoordinate(37.7749, -122.4194), isTrue);
      // ~111m per 0.001 deg latitude -> 0.0007 deg is ~78m (inside 150m)
      expect(home.containsCoordinate(37.7756, -122.4194), isTrue);
      // 0.005 deg is ~556m (outside 150m)
      final distOutside = home.distanceToMeters(37.7799, -122.4194);
      expect(distOutside, greaterThan(500.0));
      expect(home.containsCoordinate(37.7799, -122.4194), isFalse);
    });

    test('Clamps coordinates, radius bounds, and formats labels cleanly', () {
      final weirdPlace = SavedPlace(
        id: 'p1',
        name: 'Outpost',
        latitude: 120.0,
        longitude: -220.0,
        radiusMeters: 10.0,
        category: PlaceCategory.custom,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(weirdPlace.clampedLatitude, 90.0);
      expect(weirdPlace.clampedLongitude, -180.0);
      expect(weirdPlace.clampedRadiusMeters, SavedPlace.minRadiusMeters);
      expect(weirdPlace.formattedRadius, '50 m');

      final largePlace = weirdPlace.copyWith(radiusMeters: 1500.0);
      expect(largePlace.formattedRadius, '1.5 km');
    });

    test('JSON serialization roundtrip preserves all SavedPlace fields', () {
      final original = SavedPlace(
        id: 'store_1',
        name: 'FreshMart',
        address: '42 Market St',
        latitude: 37.7812,
        longitude: -122.4110,
        radiusMeters: 200.0,
        category: PlaceCategory.store,
        createdAt: DateTime(2026, 5, 10, 8, 30),
      );

      final restored = SavedPlace.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.address, original.address);
      expect(restored.latitude, closeTo(original.latitude, 0.0001));
      expect(restored.longitude, closeTo(original.longitude, 0.0001));
      expect(restored.radiusMeters, original.radiusMeters);
      expect(restored.category, PlaceCategory.store);
    });
  });

  group('LocationReminder Model Tests', () {
    test('Matches arrival/departure transitions and respects cooldown window', () {
      final t0 = DateTime(2026, 5, 10, 9, 0);
      final leaveReminder = LocationReminder(
        id: 'r_leave',
        title: 'Take gym bag',
        placeId: 'home',
        triggerType: GeofenceTriggerType.leave,
        category: AlarmCategory.fromType(AlarmCategoryType.health),
        cooldownMinutes: 30,
        createdAt: t0,
      );

      expect(leaveReminder.describeRule('Home'),
          'Remind to Take gym bag when leaving Home');
      expect(leaveReminder.matchesTransition(GeofenceTransitionEvent.exit),
          isTrue);
      expect(leaveReminder.matchesTransition(GeofenceTransitionEvent.enter),
          isFalse);
      expect(leaveReminder.canTriggerAt(t0), isTrue);

      final triggered = leaveReminder.copyWith(lastTriggeredAt: t0);
      expect(triggered.canTriggerAt(t0.add(const Duration(minutes: 10))),
          isFalse);
      expect(triggered.canTriggerAt(t0.add(const Duration(minutes: 31))),
          isTrue);
    });

    test('JSON roundtrip preserves LocationReminder and GeofenceTriggerLog', () {
      final created = DateTime(2026, 6, 1, 7, 45);
      final reminder = LocationReminder(
        id: 'r_milk',
        title: 'Buy milk',
        notes: 'Low-fat 1L carton',
        placeId: 'store',
        triggerType: GeofenceTriggerType.arrive,
        category: AlarmCategory.fromType(AlarmCategoryType.personal),
        oneTimeOnly: true,
        cooldownMinutes: 45,
        checkDepartureChecklist: true,
        lastTriggeredAt: created.add(const Duration(hours: 2)),
        createdAt: created,
      );

      final restored = LocationReminder.fromJson(reminder.toJson());
      expect(restored.id, reminder.id);
      expect(restored.title, 'Buy milk');
      expect(restored.triggerType, GeofenceTriggerType.arrive);
      expect(restored.oneTimeOnly, isTrue);
      expect(restored.cooldownMinutes, 45);
      expect(restored.checkDepartureChecklist, isTrue);

      final log = GeofenceTriggerLog(
        id: 'log_1',
        reminderId: reminder.id,
        reminderTitle: reminder.title,
        placeId: 'store',
        placeName: 'Grocery Store',
        event: GeofenceTransitionEvent.enter,
        triggeredAt: created,
        isSimulated: false,
      );
      final restoredLog = GeofenceTriggerLog.fromJson(log.toJson());
      expect(restoredLog.placeName, 'Grocery Store');
      expect(restoredLog.event, GeofenceTransitionEvent.enter);
      expect(restoredLog.isSimulated, isFalse);
    });
  });

  group('GeofenceProvider & Native Mock Bridge Tests', () {
    late StorageService storageService;
    late NotificationService notificationService;
    late MockGeofencingService mockGeo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
      notificationService = NotificationService();
      mockGeo = MockGeofencingService(
        permissionState: LocationPermissionState.whileInUse,
      );
    });

    test('Seeds starter places & reminders and syncs armed rules to native OS',
        () async {
      final provider = GeofenceProvider(
        storageService,
        notificationService,
        geofencingService: mockGeo,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.places.length, 3);
      expect(provider.reminders.length, 2);
      expect(provider.armedCount, 2);
      expect(mockGeo.registeredRegions.length, 2);
      expect(mockGeo.syncCalls, greaterThanOrEqualTo(1));

      provider.dispose();
    });

    test('Native transition stream triggers arrival & departure rules properly',
        () async {
      final provider = GeofenceProvider(
        storageService,
        notificationService,
        geofencingService: mockGeo,
        seedDefaults: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final home = SavedPlace(
        id: 'home',
        name: 'Home',
        latitude: 37.7749,
        longitude: -122.4194,
        radiusMeters: 150.0,
        category: PlaceCategory.home,
        createdAt: DateTime(2026, 1, 1),
      );
      final store = SavedPlace(
        id: 'store',
        name: 'Corner Store',
        latitude: 37.7900,
        longitude: -122.4000,
        radiusMeters: 150.0,
        category: PlaceCategory.store,
        createdAt: DateTime(2026, 1, 1),
      );
      await provider.addPlace(home);
      await provider.addPlace(store);

      final gymBagReminder = LocationReminder(
        id: 'rem_leave_home',
        title: 'Take gym bag',
        placeId: 'home',
        triggerType: GeofenceTriggerType.leave,
        category: AlarmCategory.fromType(AlarmCategoryType.health),
        oneTimeOnly: false,
        checkDepartureChecklist: true,
        createdAt: DateTime(2026, 1, 1),
      );
      final milkReminder = LocationReminder(
        id: 'rem_arrive_store',
        title: 'Buy milk',
        placeId: 'store',
        triggerType: GeofenceTriggerType.arrive,
        category: AlarmCategory.fromType(AlarmCategoryType.personal),
        oneTimeOnly: true,
        createdAt: DateTime(2026, 1, 1),
      );
      await provider.addReminder(gymBagReminder);
      await provider.addReminder(milkReminder);
      expect(mockGeo.registeredRegions.length, 2);

      // Start inside Home -> leave Home -> arrive at Corner Store
      mockGeo.simulateLocationMove(37.7749, -122.4194, isSimulated: false);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(provider.logs, isEmpty); // leave rule shouldn't fire on enter

      // Move outside Home -> triggers rem_leave_home
      mockGeo.simulateLocationMove(37.7820, -122.4100, isSimulated: false);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(provider.logs.length, 1);
      expect(provider.logs.first.reminderTitle, 'Take gym bag');
      expect(provider.logs.first.event, GeofenceTransitionEvent.exit);
      expect(provider.findReminderById('rem_leave_home')!.isCompleted, isFalse);

      // Arrive at Corner Store -> triggers oneTimeOnly Buy milk & marks done
      mockGeo.simulateLocationMove(37.7900, -122.4000, isSimulated: false);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(provider.logs.length, 2);
      expect(provider.logs.first.reminderTitle, 'Buy milk');
      expect(provider.logs.first.event, GeofenceTransitionEvent.enter);

      final milkAfter = provider.findReminderById('rem_arrive_store')!;
      expect(milkAfter.isCompleted, isTrue);
      expect(milkAfter.isEnabled, isFalse);
      // One-time reminder disarms from native geofence registry
      expect(
        mockGeo.registeredRegions.any((r) => r.reminderId == 'rem_arrive_store'),
        isFalse,
      );

      provider.dispose();
    });

    test('Drains background queued events on startup & deletes cascaded rules',
        () async {
      mockGeo.queueBackgroundEvent(
        NativeGeofenceEvent(
          reminderId: 'loc_rem_gym_bag',
          placeId: 'place_home_default',
          placeName: 'Home',
          transition: GeofenceTransitionEvent.exit,
          timestamp: DateTime(2026, 6, 10, 8, 5),
          alreadyNotifiedNatively: true,
        ),
      );

      final provider = GeofenceProvider(
        storageService,
        notificationService,
        geofencingService: mockGeo,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.logs.length, 1);
      expect(provider.logs.first.reminderTitle, 'Take gym bag');
      expect(provider.logs.first.event, GeofenceTransitionEvent.exit);

      await provider.requestBackgroundPermission();
      expect(provider.permissionState, LocationPermissionState.alwaysGranted);

      await provider.deletePlace('place_home_default');
      expect(provider.findPlaceById('place_home_default'), isNull);
      expect(provider.findReminderById('loc_rem_gym_bag'), isNull);

      provider.dispose();
    });
  });

  group('StorageService & DashboardConfig Location Integration Tests', () {
    late StorageService storageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
    });

    test('Full JSON backup and restore preserves places, reminders & logs',
        () async {
      await storageService.saveSavedPlaces([
        SavedPlace(
          id: 'p_office',
          name: 'Office',
          latitude: 51.5074,
          longitude: -0.1278,
          radiusMeters: 200.0,
          category: PlaceCategory.work,
          createdAt: DateTime(2026, 3, 1),
        ),
      ]);
      await storageService.saveLocationReminders([
        LocationReminder(
          id: 'lr_badge',
          title: 'Scan ID badge',
          placeId: 'p_office',
          triggerType: GeofenceTriggerType.arrive,
          category: AlarmCategory.fromType(AlarmCategoryType.work),
          createdAt: DateTime(2026, 3, 1),
        ),
      ]);
      await storageService.saveGeofenceLogs([
        GeofenceTriggerLog(
          id: 'g_log_1',
          reminderId: 'lr_badge',
          reminderTitle: 'Scan ID badge',
          placeId: 'p_office',
          placeName: 'Office',
          event: GeofenceTransitionEvent.enter,
          triggeredAt: DateTime(2026, 3, 2, 9, 0),
        ),
      ]);

      final exported = storageService.exportFullBackupJson();
      final decoded = jsonDecode(exported) as Map<String, dynamic>;
      expect((decoded['savedPlaces'] as List).length, 1);
      expect((decoded['locationReminders'] as List).length, 1);
      expect((decoded['geofenceLogs'] as List).length, 1);

      SharedPreferences.setMockInitialValues({});
      final freshPrefs = await SharedPreferences.getInstance();
      final freshStorage = StorageService(freshPrefs);
      expect(await freshStorage.restoreFullBackupJson(exported), isTrue);

      expect(freshStorage.loadSavedPlaces().single.name, 'Office');
      expect(
        freshStorage.loadLocationReminders().single.title,
        'Scan ID badge',
      );
      expect(freshStorage.loadGeofenceLogs().single.placeName, 'Office');
    });

    test('DashboardConfig injects legacy location_reminders section & toggles cleanly',
        () async {
      final legacy = DashboardConfig.fromJson({
        'showWeather': true,
        'sectionOrder': [
          DashboardConfig.sectionWeather,
          DashboardConfig.sectionAgenda,
          DashboardConfig.sectionTasks,
        ],
      });

      expect(
        legacy.sectionOrder.contains(DashboardConfig.sectionLocationReminders),
        isTrue,
      );
      expect(
        legacy.sectionOrder.indexOf(DashboardConfig.sectionLocationReminders),
        greaterThan(legacy.sectionOrder.indexOf(DashboardConfig.sectionAgenda)),
      );

      final dashProvider = DashboardProvider(storageService);
      await dashProvider.toggleLocationReminders(false);
      expect(dashProvider.config.showLocationReminders, isFalse);
      expect(storageService.loadDashboardConfig().showLocationReminders, isFalse);
    });
  });

  group('Location Reminders UI Widget Tests', () {
    late StorageService storageService;
    late GeofenceProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
      provider = GeofenceProvider(
        storageService,
        NotificationService(),
        geofencingService: MockGeofencingService(
          permissionState: LocationPermissionState.alwaysGranted,
        ),
        autoInitializeNative: false,
      );
      await provider.refreshPermissionState();
    });

    tearDown(() {
      provider.dispose();
    });

    Widget wrapWithProviders(Widget child) {
      return ChangeNotifierProvider<GeofenceProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('LocationRemindersCard displays active rules and fires Test trigger',
        (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(const SingleChildScrollView(child: LocationRemindersCard())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Location Reminders'), findsOneWidget);
      expect(find.text('2 Armed'), findsOneWidget);
      expect(find.text('Take gym bag'), findsOneWidget);
      expect(find.text('Buy milk & fresh fruit'), findsOneWidget);

      await tester.tap(find.text('Test').first);
      await tester.pumpAndSettle();

      expect(provider.logs.length, 1);
      expect(provider.logs.first.isSimulated, isTrue);
    });

    testWidgets(
        'LocationRemindersSheet switches tabs, creates place & reminder, and simulates boundary',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapWithProviders(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => LocationRemindersSheet.show(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Scout Location Reminders'), findsOneWidget);
      expect(find.textContaining('Triggers (2)'), findsOneWidget);

      // Filter by Leave -> shows only Take gym bag
      await tester.tap(find.textContaining('📤 Leave'));
      await tester.pumpAndSettle();
      expect(find.text('Take gym bag'), findsOneWidget);
      expect(find.text('Buy milk & fresh fruit'), findsNothing);

      // Switch to Places tab and add Office
      await tester.tap(find.textContaining('Places (3)'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Grocery Store'), findsOneWidget);

      await tester.tap(find.text('Add Saved Place'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Downtown Office');
      await tester.tap(find.text('Save Place'));
      await tester.pumpAndSettle();

      expect(provider.places.any((p) => p.name == 'Downtown Office'), isTrue);

      // Switch back to Triggers tab and add a new location reminder
      await tester.tap(find.textContaining('Triggers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Location Reminder'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'Pick up visitor pass',
      );
      await tester.tap(find.text('Save Trigger'));
      await tester.pumpAndSettle();

      expect(
        provider.reminders.any((r) => r.title == 'Pick up visitor pass'),
        isTrue,
      );

      // Switch to Activity tab & simulate boundary departure
      await tester.tap(find.textContaining('Activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simulate Leave'));
      await tester.pumpAndSettle();

      expect(provider.logs, isNotEmpty);
    });
  });
}

