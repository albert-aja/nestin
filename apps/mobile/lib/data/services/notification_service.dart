import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/before_you_go.dart';
import '../models/medication_item.dart';
import '../models/medication_snooze.dart';
import 'storage_service.dart';

/// Top-level background notification action entry point invoked by Android/iOS
/// when an action with `showsUserInterface: false` is tapped while the app
/// isolate is inactive.
@pragma('vm:entry-point')
Future<void> nestinNotificationTapBackground(
  NotificationResponse response,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.handleBackgroundNotificationAction(response);
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static bool _tzInitialized = false;

  final StreamController<String> _payloadController =
      StreamController<String>.broadcast();
  Stream<String> get payloadStream => _payloadController.stream;

  final StreamController<NotificationResponse> _actionResponseController =
      StreamController<NotificationResponse>.broadcast();
  Stream<NotificationResponse> get actionResponseStream =>
      _actionResponseController.stream;

  static const String actionMedicationSnooze15m = 'medication_snooze_15m';
  static const String medicationCategoryId = 'nestin_medication_category';
  static const Duration medicationSnoozeDuration = Duration(minutes: 15);

  static const String actionDepartureMarkAllReady = 'departure_mark_all_ready';
  static const String actionDepartureSnooze5m = 'departure_snooze_5m';
  static const String departureCategoryId = 'nestin_departure_category';
  static const Duration departureSnoozeDuration =
      DepartureSnooze.defaultSnoozeDuration;

  static const String alarmChannelId = 'nestin_alarm_channel';
  static const String alarmChannelName = 'Nestin Alarms';
  static const String alarmChannelDesc = 'Critical full-screen alerts for wake up and events';

  static const String reminderChannelId = 'nestin_reminder_channel';
  static const String reminderChannelName = 'Nestin Reminders';
  static const String reminderChannelDesc = 'Contextual alerts for tasks and activities';

  static const String timerChannelId = 'nestin_timer_channel';
  static const String timerChannelName = 'Nestin Timers';
  static const String timerChannelDesc = 'Notifications when countdown timers reach zero';

  static const String wellnessChannelId = 'nestin_wellness_channel';
  static const String wellnessChannelName = 'Nestin Wellness & Hydration';
  static const String wellnessChannelDesc = 'Gentle hydration and wellness companion reminders from Seren';

  static const String medicationChannelId = 'nestin_medication_channel';
  static const String medicationChannelName = 'Nestin Medication & Dosage';
  static const String medicationChannelDesc = 'Dose reminders, meal instructions, and refill warnings';

  static const String geofenceChannelId = 'nestin_geofence_channel';
  static const String geofenceChannelName = 'Scout Location Reminders';
  static const String geofenceChannelDesc = 'Arrival and departure alerts when reaching or leaving saved places';

  static const String departureChannelId = 'nestin_departure_channel';
  static const String departureChannelName = 'Scout BeforeYouGo Heads-Up';
  static const String departureChannelDesc =
      'Pre-departure alerts reminding you to review your BeforeYouGo checklist';

  static void ensureTimezonesInitialized() {
    if (_tzInitialized) return;
    try {
      tz.initializeTimeZones();
    } catch (_) {}
    _tzInitialized = true;
  }

  /// Routes foreground notification taps and quick action button presses.
  void handleNotificationResponse(NotificationResponse response) {
    if (response.actionId != null && response.actionId!.isNotEmpty) {
      _actionResponseController.add(response);
      return;
    }
    if (response.payload != null && response.payload!.isNotEmpty) {
      _payloadController.add(response.payload!);
    }
  }

  Future<void> init() async {
    if (_initialized) return;

    ensureTimezonesInitialized();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          medicationCategoryId,
          actions: [
            DarwinNotificationAction.plain(
              actionMedicationSnooze15m,
              'Snooze 15m',
            ),
          ],
        ),
        DarwinNotificationCategory(
          departureCategoryId,
          actions: [
            DarwinNotificationAction.plain(
              actionDepartureMarkAllReady,
              'Mark All Ready',
            ),
            DarwinNotificationAction.plain(
              actionDepartureSnooze5m,
              'Snooze 5m',
            ),
          ],
        ),
      ],
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          nestinNotificationTapBackground,
    );

    // Request Android 13+ notification permissions
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }

    _initialized = true;
  }

  /// Requests OS notification permission explicitly (e.g., when opting in to daily Inspiration).
  Future<bool> requestPermissions() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return (await android.requestNotificationsPermission()) ?? true;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return (await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            )) ??
            true;
      }
    } catch (_) {}
    return true;
  }

  Future<void> showAlarmNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      alarmChannelId,
      alarmChannelName,
      channelDescription: alarmChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
      sound: 'default',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> scheduleAlarmNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      final tzTime = tz.TZDateTime.from(scheduledDate, tz.local);

      const androidDetails = AndroidNotificationDetails(
        alarmChannelId,
        alarmChannelName,
        channelDescription: alarmChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // In case exact alarm permission is restricted on specific test devices
    }
  }

  Future<void> scheduleReminderNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      final tzTime = tz.TZDateTime.from(scheduledDate, tz.local);

      const androidDetails = AndroidNotificationDetails(
        reminderChannelId,
        reminderChannelName,
        channelDescription: reminderChannelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  Future<void> showTimerCompleteNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      timerChannelId,
      timerChannelName,
      channelDescription: timerChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> showWellnessNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        wellnessChannelId,
        wellnessChannelName,
        channelDescription: wellnessChannelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
        enableVibration: true,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (_) {}
  }

  Future<void> scheduleWellnessNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      final tzTime = tz.TZDateTime.from(scheduledDate, tz.local);

      const androidDetails = AndroidNotificationDetails(
        wellnessChannelId,
        wellnessChannelName,
        channelDescription: wellnessChannelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzTime,
        notificationDetails: details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // In case exact alarm permission is restricted on specific test devices
    }
  }

  static NotificationDetails _medicationNotificationDetails({
    bool includeSnoozeAction = true,
  }) {
    final androidDetails = AndroidNotificationDetails(
      medicationChannelId,
      medicationChannelName,
      channelDescription: medicationChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      actions: includeSnoozeAction
          ? const <AndroidNotificationAction>[
              AndroidNotificationAction(
                actionMedicationSnooze15m,
                'Snooze 15m',
                showsUserInterface: false,
                cancelNotification: true,
              ),
            ]
          : null,
    );

    final darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: includeSnoozeAction ? medicationCategoryId : null,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );
  }

  Future<void> scheduleMedicationNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    bool includeSnoozeAction = true,
  }) async {
    try {
      ensureTimezonesInitialized();
      final tzTime = tz.TZDateTime.from(scheduledDate, tz.local);

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzTime,
        notificationDetails: _medicationNotificationDetails(
          includeSnoozeAction: includeSnoozeAction,
        ),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  /// Displays a medication alert immediately (useful for manual previews).
  Future<void> showMedicationNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool includeSnoozeAction = true,
  }) async {
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _medicationNotificationDetails(
          includeSnoozeAction: includeSnoozeAction,
        ),
        payload: payload,
      );
    } catch (_) {}
  }

  /// Schedules a snoozed dose alert and returns the persisted [MedicationSnooze].
  Future<MedicationSnooze> scheduleMedicationSnooze({
    required MedicationItem med,
    required String timeString,
    List<MedicationSnooze> existingSnoozes = const [],
    Duration duration = medicationSnoozeDuration,
    int? dismissNotificationId,
    DateTime? nowOverride,
  }) async {
    final now = nowOverride ?? DateTime.now();
    final snoozeUntil = now.add(duration);
    final dateKey = MedicationSnooze.formatDateKey(now);

    var prevCount = 0;
    for (final existing in existingSnoozes) {
      if (existing.medicationId == med.id &&
          existing.timeString == timeString &&
          existing.dateKey == dateKey) {
        prevCount = existing.snoozeCount;
        break;
      }
    }

    final entry = MedicationSnooze(
      medicationId: med.id,
      timeString: timeString,
      dateKey: dateKey,
      snoozedUntil: snoozeUntil,
      snoozeCount: prevCount + 1,
    );

    if (dismissNotificationId != null) {
      await cancel(dismissNotificationId);
    }
    await cancel(
      MedicationSnooze.regularDoseNotificationId(med.id, timeString, 0),
    );

    final mealAdvice = med.mealInstruction != MealInstruction.anytime
        ? ' • ${med.mealInstruction.label}'
        : '';
    final snoozeId = MedicationSnooze.snoozedDoseNotificationId(
      med.id,
      timeString,
      dateKey,
    );

    await scheduleMedicationNotification(
      id: snoozeId,
      title: '⏰ Seren (Snoozed +${duration.inMinutes}m): ${med.name}',
      body:
          'Take ${med.dosageString}$mealAdvice. Tap Snooze 15m again if needed.',
      scheduledDate: snoozeUntil,
      payload: MedicationSnooze.buildDosePayload(med.id, timeString),
    );

    return entry;
  }

  /// Handles 1-tap notification actions when the app runs in the background.
  static Future<bool> handleBackgroundNotificationAction(
    NotificationResponse response, {
    StorageService? storageOverride,
    NotificationService? notificationOverride,
    DateTime? nowOverride,
  }) async {
    switch (response.actionId) {
      case actionMedicationSnooze15m:
        return _handleBackgroundMedicationSnooze(
          response,
          storageOverride: storageOverride,
          notificationOverride: notificationOverride,
          nowOverride: nowOverride,
        );
      case actionDepartureMarkAllReady:
      case actionDepartureSnooze5m:
        return _handleBackgroundDepartureAction(
          response,
          storageOverride: storageOverride,
          notificationOverride: notificationOverride,
          nowOverride: nowOverride,
        );
      default:
        return false;
    }
  }

  static Future<bool> _handleBackgroundMedicationSnooze(
    NotificationResponse response, {
    StorageService? storageOverride,
    NotificationService? notificationOverride,
    DateTime? nowOverride,
  }) async {
    final parsed = MedicationSnooze.parseDosePayload(response.payload);
    if (parsed == null) return false;

    ensureTimezonesInitialized();
    final storage = storageOverride ?? await StorageService.init();
    await storage.reloadPrefs();

    MedicationItem? med;
    for (final item in storage.loadMedications()) {
      if (item.id == parsed.medicationId && item.isActive) {
        med = item;
        break;
      }
    }
    if (med == null) return false;

    final now = nowOverride ?? DateTime.now();
    final currentSnoozes = storage.loadMedicationSnoozes();
    final notif = notificationOverride ?? NotificationService();
    final entry = await notif.scheduleMedicationSnooze(
      med: med,
      timeString: parsed.timeString,
      existingSnoozes: currentSnoozes,
      dismissNotificationId: response.id,
      nowOverride: now,
    );

    final pruned = MedicationSnooze.mergeAndPrune(currentSnoozes, entry, now);

    await storage.saveMedicationSnoozes(pruned);
    return true;
  }

  static Future<bool> _handleBackgroundDepartureAction(
    NotificationResponse response, {
    StorageService? storageOverride,
    NotificationService? notificationOverride,
    DateTime? nowOverride,
  }) async {
    ensureTimezonesInitialized();
    final storage = storageOverride ?? await StorageService.init();
    await storage.reloadPrefs();
    final now = nowOverride ?? DateTime.now();

    var presets = storage.loadDeparturePresets();
    if (presets.isEmpty) {
      presets = DeparturePreset.seedDefaults(now);
    }
    final fallbackPresetId =
        storage.loadActiveDeparturePresetId() ?? presets.first.id;
    final parsed = DepartureSnooze.parseActionPayload(
      response.payload,
      fallbackPresetId: fallbackPresetId,
    );
    if (parsed == null) return false;

    final events = storage.loadDepartureEvents();
    final currentSnoozes = storage.loadDepartureSnoozes();
    final notif = notificationOverride ?? NotificationService();

    if (response.actionId == actionDepartureMarkAllReady) {
      final result = DepartureSnooze.applyMarkAllReady(
        presets: presets,
        events: events,
        snoozes: currentSnoozes,
        presetId: parsed.presetId,
        eventId: parsed.eventId,
        now: now,
      );
      if (result == null) return false;

      await notif.cancelDepartureActiveAlerts(
        clearedEventIds: result.clearedEventIds,
        events: result.events,
        dismissNotificationId: response.id,
        now: now,
      );
      await storage.saveDeparturePresets(result.presets);
      await storage.saveDepartureEvents(result.events);
      await storage.saveDepartureSnoozes(result.snoozes);
      return true;
    }

    final target = DepartureSnooze.resolveSnoozeTarget(
      presets: presets,
      events: events,
      eventId: parsed.eventId,
      presetId: parsed.presetId,
    );
    if (target == null) return false;

    final entry = await notif.scheduleDepartureSnooze(
      eventId: target.eventId,
      preset: target.preset,
      titleLabel: target.titleLabel,
      existingSnoozes: currentSnoozes,
      dismissNotificationId: response.id,
      nowOverride: now,
    );
    final merged = DepartureSnooze.mergeAndPrune(currentSnoozes, entry, now);
    await storage.saveDepartureSnoozes(merged);
    return true;
  }

  Future<void> showGeofenceNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        geofenceChannelId,
        geofenceChannelName,
        channelDescription: geofenceChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (_) {}
  }

  @visibleForTesting
  static NotificationDetails buildDepartureNotificationDetails({
    bool includeInlineActions = true,
  }) {
    final androidDetails = AndroidNotificationDetails(
      departureChannelId,
      departureChannelName,
      channelDescription: departureChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      actions: includeInlineActions
          ? const <AndroidNotificationAction>[
              AndroidNotificationAction(
                actionDepartureMarkAllReady,
                'Mark All Ready',
                showsUserInterface: false,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                actionDepartureSnooze5m,
                'Snooze 5m',
                showsUserInterface: false,
                cancelNotification: true,
              ),
            ]
          : null,
    );

    final darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: includeInlineActions ? departureCategoryId : null,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );
  }

  static const String wellbeingChannelId = 'nestin_wellbeing_channel';
  static const String wellbeingChannelName = 'Scout Digital Wellbeing';
  static const String wellbeingChannelDesc =
      'App limit warnings, mindful pause prompts, and Phone Mode state alerts';

  static const String automationChannelId = 'nestin_automation_channel';
  static const String automationChannelName = 'Nestin Automations';
  static const String automationChannelDesc =
      'Local cross-module automation confirmations and status alerts';

  static const String readingChannelId = 'nestin_reading_channel';
  static const String readingChannelName = 'Pippin Reading Nudge';
  static const String readingChannelDesc =
      'Optional evening daily reading page goal & streak reminders from Pippin';

  static const NotificationDetails _readingNotificationDetails =
      NotificationDetails(
    android: AndroidNotificationDetails(
      readingChannelId,
      readingChannelName,
      channelDescription: readingChannelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static const NotificationDetails _wellbeingNotificationDetails =
      NotificationDetails(
    android: AndroidNotificationDetails(
      wellbeingChannelId,
      wellbeingChannelName,
      channelDescription: wellbeingChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static const NotificationDetails _automationNotificationDetails =
      NotificationDetails(
    android: AndroidNotificationDetails(
      automationChannelId,
      automationChannelName,
      channelDescription: automationChannelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      enableVibration: false,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  /// Displays a Scout Digital Wellbeing or Phone Mode status notification.
  Future<void> showWellbeingNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _wellbeingNotificationDetails,
        payload: payload,
      );
    } catch (_) {}
  }

  /// Displays an Automation Engine notification or pending confirmation alert.
  Future<void> showAutomationNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _automationNotificationDetails,
        payload: payload,
      );
    } catch (_) {}
  }

  /// Schedules a Scout BeforeYouGo pre-departure push notification.
  Future<void> scheduleDepartureNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    bool includeInlineActions = true,
  }) async {
    try {
      ensureTimezonesInitialized();
      final tzTime = tz.TZDateTime.from(scheduledDate, tz.local);

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzTime,
        notificationDetails: buildDepartureNotificationDetails(
          includeInlineActions: includeInlineActions,
        ),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  /// Displays a Scout BeforeYouGo notification immediately (useful for manual previews).
  Future<void> showDepartureNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool includeInlineActions = true,
  }) async {
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: buildDepartureNotificationDetails(
          includeInlineActions: includeInlineActions,
        ),
        payload: payload,
      );
    } catch (_) {}
  }

  /// Schedules a 5-minute snoozed BeforeYouGo heads-up notification.
  Future<DepartureSnooze> scheduleDepartureSnooze({
    required String eventId,
    required DeparturePreset preset,
    required String titleLabel,
    List<DepartureSnooze> existingSnoozes = const [],
    Duration duration = departureSnoozeDuration,
    int? dismissNotificationId,
    DateTime? nowOverride,
  }) async {
    final now = nowOverride ?? DateTime.now();
    final snoozeUntil = now.add(duration);
    final dateKey = DepartureEvent.formatDateKey(now);

    var prevCount = 0;
    for (final existing in existingSnoozes) {
      if (existing.eventId == eventId && existing.dateKey == dateKey) {
        prevCount = existing.snoozeCount;
        break;
      }
    }

    final entry = DepartureSnooze(
      eventId: eventId,
      presetId: preset.id,
      dateKey: dateKey,
      snoozedUntil: snoozeUntil,
      snoozeCount: prevCount + 1,
    );

    if (dismissNotificationId != null) {
      await cancel(dismissNotificationId);
    }

    final content = DepartureSnooze.buildSnoozedContent(
      titleLabel: titleLabel,
      preset: preset,
      duration: duration,
    );

    await scheduleDepartureNotification(
      id: DepartureSnooze.snoozedNotificationId(eventId, dateKey),
      title: content.title,
      body: content.body,
      scheduledDate: snoozeUntil,
      payload: DepartureSnooze.buildPayload(eventId, preset.id),
      includeInlineActions: true,
    );

    return entry;
  }

  /// Cancels the active shade alert, any today snoozes, and today's slot 0 alert
  /// if it falls on [now]'s calendar day.
  Future<void> cancelDepartureActiveAlerts({
    required Set<String> clearedEventIds,
    required List<DepartureEvent> events,
    int? dismissNotificationId,
    required DateTime now,
  }) async {
    if (dismissNotificationId != null) {
      await cancel(dismissNotificationId);
    }
    final todayKey = DepartureEvent.formatDateKey(now);
    for (final evId in clearedEventIds) {
      await cancel(DepartureSnooze.snoozedNotificationId(evId, todayKey));
      for (final ev in events) {
        if (ev.id == evId) {
          final next = ev.nextNotificationAfter(now);
          if (next != null && DepartureEvent.formatDateKey(next) == todayKey) {
            await cancel(DepartureSnooze.regularNotificationId(evId, 0));
          }
          break;
        }
      }
    }
  }

  /// Schedules Pippin's optional evening reading goal & streak nudge.
  Future<void> scheduleReadingNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      ensureTimezonesInitialized();
      final tzTime = tz.TZDateTime.from(scheduledDate, tz.local);

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzTime,
        notificationDetails: _readingNotificationDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  /// Displays a Pippin reading notification immediately (useful for manual previews).
  Future<void> showReadingNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _readingNotificationDetails,
        payload: payload,
      );
    } catch (_) {}
  }

  static const String inspirationChannelId = 'nestin_inspiration_daily';
  static const String inspirationChannelName = 'Daily Inspiration';
  static const String inspirationChannelDesc =
      'Optional daily inspirational quotes from Nestin';
  static const int dailyInspirationNotificationId = 94001;
  static const int inspirationPreviewNotificationId = 94002;

  NotificationDetails get _inspirationNotificationDetails =>
      const NotificationDetails(
        android: AndroidNotificationDetails(
          inspirationChannelId,
          inspirationChannelName,
          channelDescription: inspirationChannelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      );

  /// Schedules or updates the optional daily Inspiration notification.
  /// Only invoked when the user has explicitly opted in.
  Future<void> scheduleDailyInspirationNotification({
    required int hour,
    required int minute,
    required String title,
    required String body,
    String frequency = 'DAILY',
    String? quoteId,
  }) async {
    try {
      ensureTimezonesInitialized();
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      if (frequency == 'WEEKDAYS') {
        while (scheduled.weekday == DateTime.saturday ||
            scheduled.weekday == DateTime.sunday) {
          scheduled = scheduled.add(const Duration(days: 1));
        }
      } else if (frequency == 'WEEKLY') {
        while (scheduled.weekday != DateTime.monday) {
          scheduled = scheduled.add(const Duration(days: 1));
        }
      }

      final payload = quoteId != null && quoteId.isNotEmpty
          ? 'nestin://inspiration?quoteId=$quoteId'
          : 'nestin://inspiration';

      await _plugin.zonedSchedule(
        id: dailyInspirationNotificationId,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: _inspirationNotificationDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: frequency == 'WEEKLY'
            ? DateTimeComponents.dayOfWeekAndTime
            : DateTimeComponents.time,
      );
    } catch (_) {}
  }

  Future<void> cancelDailyInspirationNotification() async {
    await cancel(dailyInspirationNotificationId);
  }

  Future<void> showInspirationPreviewNotification({
    required String title,
    required String body,
    String? quoteId,
  }) async {
    try {
      final payload = quoteId != null && quoteId.isNotEmpty
          ? 'nestin://inspiration?quoteId=$quoteId'
          : 'nestin://inspiration';
      await _plugin.show(
        id: inspirationPreviewNotificationId,
        title: title,
        body: body,
        notificationDetails: _inspirationNotificationDetails,
        payload: payload,
      );
    } catch (_) {}
  }

  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
