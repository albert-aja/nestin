import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/models/alarm.dart';
import '../data/models/alarm_category.dart';
import '../data/models/alarm_schedule.dart';
import '../data/models/challenge_profile.dart';
import '../data/services/storage_service.dart';
import '../data/services/audio_service.dart';
import '../data/services/notification_service.dart';

class AlarmProvider extends ChangeNotifier {
  final StorageService _storageService;
  final AudioService _audioService;
  final NotificationService _notificationService;

  List<Alarm> _alarms = [];
  Alarm? _ringingAlarm;
  Timer? _scheduleWatcherTimer;

  AlarmProvider(
    this._storageService,
    this._audioService,
    this._notificationService,
  ) {
    _loadAlarms();
    _startScheduleWatcher();
  }

  List<Alarm> get alarms => List.unmodifiable(_alarms);
  Alarm? get ringingAlarm => _ringingAlarm;

  void _loadAlarms() {
    _alarms = _storageService.loadAlarms();
    if (_alarms.isEmpty) {
      // Seed initial high-quality default alarms
      _alarms = [
        Alarm(
          id: const Uuid().v4(),
          title: 'Sunrise Wake-Up',
          description: 'Start the day with high energy',
          hour: 7,
          minute: 0,
          isEnabled: true,
          category: AlarmCategory.fromType(AlarmCategoryType.wakeUp),
          schedule: AlarmSchedule.weekdays(),
          sound: 'rooster_dawn',
          volume: 0.9,
          gradualVolume: true,
          gradualDurationSeconds: 60,
          vibration: true,
          snoozeMinutes: 9,
          maxSnoozeCount: 3,
          challengeInherited: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Alarm(
          id: const Uuid().v4(),
          title: 'Daily Team Sync',
          description: 'Standup and sprint review',
          hour: 9,
          minute: 30,
          isEnabled: true,
          category: AlarmCategory.fromType(AlarmCategoryType.work),
          schedule: AlarmSchedule.weekdays(),
          sound: 'bell_chime',
          volume: 0.75,
          gradualVolume: false,
          vibration: true,
          snoozeMinutes: 5,
          maxSnoozeCount: 2,
          challengeInherited: false,
          challengeOverride: const WakeUpChallengeProfile(
            id: 'meeting_sync',
            isEnabled: false,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      _save();
    }
  }

  Future<void> _save() async {
    await _storageService.saveAlarms(_alarms);
    _rescheduleNotifications();
    notifyListeners();
  }

  void _rescheduleNotifications() {
    final now = DateTime.now();
    for (int i = 0; i < _alarms.length; i++) {
      final alarm = _alarms[i];
      if (!alarm.isEnabled) {
        _notificationService.cancel(alarm.id.hashCode);
        continue;
      }

      final next = alarm.nextOccurrence(now);
      _notificationService.scheduleAlarmNotification(
        id: alarm.id.hashCode,
        title: alarm.title,
        body: 'RooDoo Alarm: ${alarm.formattedTime()}',
        scheduledDate: next,
      );
    }
  }

  /// Calculates the nearest upcoming alarm among all enabled alarms
  Alarm? get nextUpcomingAlarm {
    final enabled = _alarms.where((a) => a.isEnabled).toList();
    if (enabled.isEmpty) return null;

    final now = DateTime.now();
    enabled.sort((a, b) =>
        a.nextOccurrence(now).compareTo(b.nextOccurrence(now)));
    return enabled.first;
  }

  Future<void> addAlarm(Alarm alarm) async {
    _alarms.add(alarm);
    await _save();
  }

  Future<void> updateAlarm(Alarm alarm) async {
    final index = _alarms.indexWhere((a) => a.id == alarm.id);
    if (index != -1) {
      _alarms[index] = alarm.copyWith(updatedAt: DateTime.now());
      await _save();
    }
  }

  Future<void> toggleAlarm(String id, bool isEnabled) async {
    final index = _alarms.indexWhere((a) => a.id == id);
    if (index != -1) {
      _alarms[index] = _alarms[index].copyWith(
        isEnabled: isEnabled,
        clearSnoozeUntil: !isEnabled,
        snoozeCount: isEnabled ? _alarms[index].snoozeCount : 0,
        updatedAt: DateTime.now(),
      );
      await _save();
    }
  }

  Future<void> duplicateAlarm(String id) async {
    final existing = _alarms.firstWhere((a) => a.id == id);
    final duplicated = existing.copyWith(
      id: const Uuid().v4(),
      title: '${existing.title} (Copy)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _alarms.add(duplicated);
    await _save();
  }

  Future<void> deleteAlarm(String id) async {
    _alarms.removeWhere((a) => a.id == id);
    _notificationService.cancel(id.hashCode);
    await _save();
  }

  /// Trigger active alarm screen and audio playback
  Future<void> triggerAlarm(Alarm alarm) async {
    _ringingAlarm = alarm;
    notifyListeners();

    await _audioService.startAlarm(
      soundId: alarm.sound,
      customFilePath: alarm.soundFilePath,
      targetVolume: alarm.volume,
      gradualVolume: alarm.gradualVolume,
      gradualDurationSeconds: alarm.gradualDurationSeconds,
    );

    await _notificationService.showAlarmNotification(
      id: alarm.id.hashCode,
      title: alarm.title,
      body: 'Time to wake up! ${alarm.description}',
    );
  }

  /// Snoozes the currently ringing alarm
  Future<void> snoozeAlarm(String alarmId) async {
    final index = _alarms.indexWhere((a) => a.id == alarmId);
    if (index != -1) {
      final alarm = _alarms[index];
      final newSnoozeCount = alarm.snoozeCount + 1;
      final snoozeTarget = DateTime.now().add(
        Duration(minutes: alarm.snoozeMinutes),
      );

      _alarms[index] = alarm.copyWith(
        snoozeCount: newSnoozeCount,
        snoozeUntil: snoozeTarget,
        updatedAt: DateTime.now(),
      );
      await _save();
    }

    await _audioService.stop();
    _ringingAlarm = null;
    notifyListeners();
  }

  /// Dismisses the currently ringing alarm
  Future<void> dismissAlarm(String alarmId) async {
    final index = _alarms.indexWhere((a) => a.id == alarmId);
    if (index != -1) {
      final alarm = _alarms[index];
      if (alarm.schedule.type == ScheduleType.oneTime) {
        // One-time alarms disable on dismissal
        _alarms[index] = alarm.copyWith(
          isEnabled: false,
          clearSnoozeUntil: true,
          snoozeCount: 0,
          updatedAt: DateTime.now(),
        );
      } else {
        // Recurring alarms reset snooze tracking
        _alarms[index] = alarm.copyWith(
          clearSnoozeUntil: true,
          snoozeCount: 0,
          updatedAt: DateTime.now(),
        );
      }
      await _save();
    }

    await _audioService.stop();
    _ringingAlarm = null;
    notifyListeners();
  }

  void _startScheduleWatcher() {
    _scheduleWatcherTimer?.cancel();
    // Periodic check every 15 seconds for alarms reaching trigger moment
    _scheduleWatcherTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_ringingAlarm != null) return; // already ringing
      final now = DateTime.now();
      for (final alarm in _alarms) {
        if (!alarm.isEnabled) continue;

        final next = alarm.nextOccurrence(now);
        // Check if scheduled occurrence is within the current minute window
        final diff = next.difference(now).abs();
        if (diff.inSeconds <= 20) {
          triggerAlarm(alarm);
          break;
        }
      }
    });
  }

  @override
  void dispose() {
    _scheduleWatcherTimer?.cancel();
    super.dispose();
  }
}

