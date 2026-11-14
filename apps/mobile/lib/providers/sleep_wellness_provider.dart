import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models/bedtime_wind_down_config.dart';
import '../data/services/storage_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/ambient_sound_service.dart';

class SleepWellnessProvider extends ChangeNotifier {
  final StorageService _storageService;
  final NotificationService _notificationService;
  final AmbientSoundService _ambientSoundService;

  late BedtimeWindDownConfig _config;
  BedtimeWindDownConfig get config => _config;

  static const int windDownNotificationId = 7200;

  // Bedtime Wind-Down Ambient Audio State
  bool _isWindDownAudioPlaying = false;
  AmbientSoundType _activeAmbientSound = AmbientSoundType.rain;
  int _windDownAudioMinutes = 30;
  int _remainingAudioSeconds = 0;
  double _ambientVolume = 0.5;
  Timer? _countdownTimer;

  SleepWellnessProvider(
    this._storageService,
    this._notificationService, [
    AmbientSoundService? ambientSoundService,
  ]) : _ambientSoundService = ambientSoundService ?? AmbientSoundService() {
    _load();
  }

  void _load() {
    _config = _storageService.loadBedtimeWindDownConfig();
  }

  bool get isEnabled => _config.enabled;
  bool get syncWithNextAlarm => _config.syncWithNextAlarm;
  int get targetSleepCycles => _config.targetSleepCycles;
  int get windDownLeadMinutes => _config.windDownLeadMinutes;

  // Wind-Down Audio Getters
  bool get isWindDownAudioPlaying => _isWindDownAudioPlaying;
  AmbientSoundType get activeAmbientSound => _activeAmbientSound;
  int get windDownAudioMinutes => _windDownAudioMinutes;
  int get remainingAudioSeconds => _remainingAudioSeconds;
  double get ambientVolume => _ambientVolume;

  String get formattedRemainingTime {
    final mins = _remainingAudioSeconds ~/ 60;
    final secs = _remainingAudioSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double get audioProgress {
    if (!_isWindDownAudioPlaying ||
        _windDownAudioMinutes <= 0 ||
        _remainingAudioSeconds <= 0) {
      return 0.0;
    }
    final total = _windDownAudioMinutes * 60.0;
    return ((total - _remainingAudioSeconds) / total).clamp(0.0, 1.0);
  }

  /// Effective target wake-up time given current time and optional next alarm
  DateTime getEffectiveWakeUpTime({
    DateTime? currentTime,
    DateTime? nextAlarmTime,
  }) {
    return _config.resolveEffectiveWakeUpTime(
      currentTime: currentTime,
      nextAlarmTime: nextAlarmTime,
    );
  }

  /// Target bedtime to achieve restorative 90-minute REM sleep cycles
  DateTime getTargetBedtime({
    DateTime? currentTime,
    DateTime? nextAlarmTime,
  }) {
    final wakeUp = getEffectiveWakeUpTime(
      currentTime: currentTime,
      nextAlarmTime: nextAlarmTime,
    );
    return _config.calculateTargetBedtime(wakeUp);
  }

  /// Exact time wind-down push alert fires (lead time prior to bedtime)
  DateTime getWindDownAlertTime({
    DateTime? currentTime,
    DateTime? nextAlarmTime,
  }) {
    final wakeUp = getEffectiveWakeUpTime(
      currentTime: currentTime,
      nextAlarmTime: nextAlarmTime,
    );
    return _config.calculateWindDownAlertTime(wakeUp);
  }

  /// Synchronize scheduled notification with NotificationService
  Future<void> syncWindDownSchedule({
    DateTime? currentTime,
    DateTime? nextAlarmTime,
  }) async {
    final now = currentTime ?? DateTime.now();

    if (!_config.enabled) {
      await cancelAlert();
      return;
    }

    var alertTime = getWindDownAlertTime(
      currentTime: now,
      nextAlarmTime: nextAlarmTime,
    );

    var targetBedtime = getTargetBedtime(
      currentTime: now,
      nextAlarmTime: nextAlarmTime,
    );

    // If today's alert time already passed, look ahead to tomorrow's schedule
    if (!alertTime.isAfter(now)) {
      final tomorrowNow = now.add(const Duration(days: 1));
      alertTime = getWindDownAlertTime(
        currentTime: tomorrowNow,
        nextAlarmTime: nextAlarmTime != null && nextAlarmTime.isAfter(now)
            ? nextAlarmTime
            : null,
      );
      targetBedtime = getTargetBedtime(
        currentTime: tomorrowNow,
        nextAlarmTime: nextAlarmTime != null && nextAlarmTime.isAfter(now)
            ? nextAlarmTime
            : null,
      );
    }

    if (alertTime.isAfter(now)) {
      await _notificationService.cancel(windDownNotificationId);

      final hourStr = targetBedtime.hour.toString().padLeft(2, '0');
      final minuteStr = targetBedtime.minute.toString().padLeft(2, '0');

      await _notificationService.scheduleWellnessNotification(
        id: windDownNotificationId,
        title: '🌙 Seren — Bedtime Wind-Down',
        body:
            'Time to unwind! Bedtime in ${_config.windDownLeadMinutes}m ($hourStr:$minuteStr for ${_config.targetSleepCycles} cycles). Tap to start 30m soothing ambient rain or forest breeze. 🌿🌧️',
        scheduledDate: alertTime,
        payload: 'wind_down_ambient',
      );
    }
  }

  /// Toggle wind-down alerts on/off
  Future<void> toggleEnabled(bool enabled, {DateTime? nextAlarmTime}) async {
    _config = _config.copyWith(enabled: enabled);
    await _storageService.saveBedtimeWindDownConfig(_config);
    await syncWindDownSchedule(nextAlarmTime: nextAlarmTime);
    notifyListeners();
  }

  /// Update configuration parameters
  Future<void> updateConfig(
    BedtimeWindDownConfig newConfig, {
    DateTime? nextAlarmTime,
  }) async {
    _config = newConfig;
    await _storageService.saveBedtimeWindDownConfig(_config);
    await syncWindDownSchedule(nextAlarmTime: nextAlarmTime);
    notifyListeners();
  }

  /// Cancel any scheduled wind-down notification
  Future<void> cancelAlert() async {
    await _notificationService.cancel(windDownNotificationId);
  }

  /// Test instant alert preview notification
  Future<void> testSendAlertNow({DateTime? nextAlarmTime}) async {
    final targetBedtime = getTargetBedtime(nextAlarmTime: nextAlarmTime);
    final hourStr = targetBedtime.hour.toString().padLeft(2, '0');
    final minuteStr = targetBedtime.minute.toString().padLeft(2, '0');

    await _notificationService.showWellnessNotification(
      id: 7199,
      title: '🌙 Seren — Bedtime Wind-Down (Test)',
      body:
          'Time to unwind! Bedtime in ${_config.windDownLeadMinutes}m ($hourStr:$minuteStr for ${_config.targetSleepCycles} cycles). Tap to start 30m soothing ambient rain or forest breeze. 🌿🌧️',
      payload: 'wind_down_ambient',
    );
  }

  // --- Bedtime Wind-Down Ambient Audio Controls ---

  /// Start playing soothing ambient audio for 30 minutes (or custom duration)
  Future<void> startWindDownAudio({
    AmbientSoundType? soundType,
    int durationMinutes = 30,
  }) async {
    _countdownTimer?.cancel();
    _activeAmbientSound = (soundType != null && soundType != AmbientSoundType.none)
        ? soundType
        : AmbientSoundType.rain;
    _windDownAudioMinutes = durationMinutes;
    _remainingAudioSeconds = durationMinutes * 60;
    _isWindDownAudioPlaying = true;
    notifyListeners();

    await _ambientSoundService.play(_activeAmbientSound, volume: _ambientVolume);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingAudioSeconds > 0) {
        _remainingAudioSeconds--;
        notifyListeners();
      } else {
        stopWindDownAudio();
      }
    });
  }

  /// Stop playing wind-down audio immediately
  Future<void> stopWindDownAudio() async {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _isWindDownAudioPlaying = false;
    _remainingAudioSeconds = 0;
    await _ambientSoundService.stop();
    notifyListeners();
  }

  /// Toggle wind-down audio playback
  Future<void> toggleWindDownAudio({
    AmbientSoundType? soundType,
    int durationMinutes = 30,
  }) async {
    if (_isWindDownAudioPlaying) {
      await stopWindDownAudio();
    } else {
      await startWindDownAudio(
        soundType: soundType,
        durationMinutes: durationMinutes,
      );
    }
  }

  /// Switch ambient sound between Rain and Forest
  Future<void> switchAmbientSound(AmbientSoundType soundType) async {
    _activeAmbientSound = soundType;
    if (_isWindDownAudioPlaying) {
      await _ambientSoundService.play(_activeAmbientSound, volume: _ambientVolume);
    }
    notifyListeners();
  }

  /// Adjust ambient sound volume
  Future<void> setAmbientVolume(double volume) async {
    _ambientVolume = volume.clamp(0.0, 1.0);
    await _ambientSoundService.setVolume(_ambientVolume);
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ambientSoundService.dispose();
    super.dispose();
  }
}
