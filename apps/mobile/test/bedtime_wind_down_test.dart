import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/data/models/bedtime_wind_down_config.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/ambient_sound_service.dart';
import 'package:nestin/providers/sleep_wellness_provider.dart';

class FakeAmbientSoundService extends AmbientSoundService {
  AmbientSoundType _fakeType = AmbientSoundType.none;
  double _fakeVolume = 0.5;
  bool _fakePlaying = false;

  @override
  AmbientSoundType get currentType => _fakeType;
  @override
  double get volume => _fakeVolume;
  @override
  bool get isPlaying => _fakePlaying;

  @override
  Future<void> play(AmbientSoundType type, {double? volume}) async {
    if (volume != null) _fakeVolume = volume;
    _fakeType = type;
    _fakePlaying = (type != AmbientSoundType.none);
  }

  @override
  Future<void> stop() async {
    _fakePlaying = false;
    _fakeType = AmbientSoundType.none;
  }

  @override
  Future<void> setVolume(double vol) async {
    _fakeVolume = vol.clamp(0.0, 1.0);
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock notifications channel so plugin calls succeed in test environment
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dexterous.com/flutter/local_notifications'),
    (call) async => true,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    (call) async => 1,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (call) async => 1,
  );

  late StorageService storageService;
  late NotificationService notificationService;
  late FakeAmbientSoundService fakeAmbientService;
  late SleepWellnessProvider sleepWellnessProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
    notificationService = NotificationService();
    fakeAmbientService = FakeAmbientSoundService();
    sleepWellnessProvider = SleepWellnessProvider(
      storageService,
      notificationService,
      fakeAmbientService,
    );
  });

  tearDown(() {
    sleepWellnessProvider.dispose();
  });

  group('BedtimeWindDownConfig Tests', () {
    test('Default values initialize correctly (enabled, sync alarm, 5 cycles, 30m lead)', () {
      final config = BedtimeWindDownConfig.initial();
      expect(config.enabled, true);
      expect(config.syncWithNextAlarm, true);
      expect(config.targetWakeHour, 7);
      expect(config.targetWakeMinute, 0);
      expect(config.targetSleepCycles, 5);
      expect(config.windDownLeadMinutes, 30);
      expect(config.fallAsleepMinutes, 14);
    });

    test('Computes target bedtime for 5 REM cycles (7h 30m sleep + 14m latency = 464 mins)', () {
      final config = const BedtimeWindDownConfig(
        targetSleepCycles: 5,
        fallAsleepMinutes: 14,
        windDownLeadMinutes: 30,
      );

      // Target wake up at 07:00 AM on Nov 13, 2026
      final wakeUpTime = DateTime(2026, 11, 13, 7, 0);
      final bedtime = config.calculateTargetBedtime(wakeUpTime);

      // 7:00 AM minus 464 minutes (7 hours 44 minutes) = 11:16 PM (23:16) on Nov 12
      expect(bedtime, DateTime(2026, 11, 12, 23, 16));
    });

    test('Computes wind-down alert time exactly 30 minutes before target bedtime', () {
      final config = const BedtimeWindDownConfig(
        targetSleepCycles: 5,
        fallAsleepMinutes: 14,
        windDownLeadMinutes: 30,
      );

      final wakeUpTime = DateTime(2026, 11, 13, 7, 0);
      final alertTime = config.calculateWindDownAlertTime(wakeUpTime);

      // 11:16 PM minus 30 minutes = 10:46 PM (22:46) on Nov 12
      expect(alertTime, DateTime(2026, 11, 12, 22, 46));
    });

    test('Resolves next alarm when syncWithNextAlarm is active', () {
      final config = const BedtimeWindDownConfig(syncWithNextAlarm: true);
      final nextAlarmTime = DateTime(2026, 11, 13, 6, 30);
      final resolved = config.resolveEffectiveWakeUpTime(
        currentTime: DateTime(2026, 11, 12, 20, 0),
        nextAlarmTime: nextAlarmTime,
      );

      expect(resolved, nextAlarmTime);
    });

    test('Falls back to custom target wake time when no alarm provided', () {
      final config = const BedtimeWindDownConfig(
        syncWithNextAlarm: false,
        targetWakeHour: 8,
        targetWakeMinute: 15,
      );

      final resolved = config.resolveEffectiveWakeUpTime(
        currentTime: DateTime(2026, 11, 12, 20, 0),
      );

      expect(resolved, DateTime(2026, 11, 13, 8, 15));
    });

    test('JSON serialization roundtrip preserves all wind-down parameters', () {
      final original = const BedtimeWindDownConfig(
        enabled: true,
        syncWithNextAlarm: false,
        targetWakeHour: 6,
        targetWakeMinute: 45,
        targetSleepCycles: 6,
        windDownLeadMinutes: 45,
        fallAsleepMinutes: 15,
      );

      final json = original.toJson();
      final restored = BedtimeWindDownConfig.fromJson(json);

      expect(restored.enabled, original.enabled);
      expect(restored.syncWithNextAlarm, original.syncWithNextAlarm);
      expect(restored.targetWakeHour, original.targetWakeHour);
      expect(restored.targetWakeMinute, original.targetWakeMinute);
      expect(restored.targetSleepCycles, original.targetSleepCycles);
      expect(restored.windDownLeadMinutes, original.windDownLeadMinutes);
      expect(restored.fallAsleepMinutes, original.fallAsleepMinutes);
    });
  });

  group('SleepWellnessProvider State & Schedule Tests', () {
    test('Initializes with default config and provides timing getters', () {
      expect(sleepWellnessProvider.isEnabled, true);
      expect(sleepWellnessProvider.syncWithNextAlarm, true);
      expect(sleepWellnessProvider.targetSleepCycles, 5);
      expect(sleepWellnessProvider.windDownLeadMinutes, 30);

      final targetBedtime = sleepWellnessProvider.getTargetBedtime(
        currentTime: DateTime(2026, 11, 12, 20, 0),
        nextAlarmTime: DateTime(2026, 11, 13, 7, 0),
      );
      expect(targetBedtime, DateTime(2026, 11, 12, 23, 16));

      final alertTime = sleepWellnessProvider.getWindDownAlertTime(
        currentTime: DateTime(2026, 11, 12, 20, 0),
        nextAlarmTime: DateTime(2026, 11, 13, 7, 0),
      );
      expect(alertTime, DateTime(2026, 11, 12, 22, 46));
    });

    test('Toggle enabled updates state and persists to StorageService', () async {
      await sleepWellnessProvider.toggleEnabled(false);
      expect(sleepWellnessProvider.isEnabled, false);

      final reloaded = storageService.loadBedtimeWindDownConfig();
      expect(reloaded.enabled, false);

      await sleepWellnessProvider.toggleEnabled(true);
      expect(sleepWellnessProvider.isEnabled, true);
    });

    test('Update config modifies cycles and lead time', () async {
      final updated = sleepWellnessProvider.config.copyWith(
        targetSleepCycles: 6,
        windDownLeadMinutes: 45,
      );

      await sleepWellnessProvider.updateConfig(updated);
      expect(sleepWellnessProvider.targetSleepCycles, 6);
      expect(sleepWellnessProvider.windDownLeadMinutes, 45);

      final reloaded = storageService.loadBedtimeWindDownConfig();
      expect(reloaded.targetSleepCycles, 6);
      expect(reloaded.windDownLeadMinutes, 45);
    });

    test('Full JSON backup and restore includes bedtime wind-down config', () async {
      final customConfig = const BedtimeWindDownConfig(
        enabled: true,
        syncWithNextAlarm: false,
        targetWakeHour: 6,
        targetWakeMinute: 30,
        targetSleepCycles: 4,
        windDownLeadMinutes: 15,
      );

      await sleepWellnessProvider.updateConfig(customConfig);

      final backupJson = storageService.exportFullBackupJson();
      expect(backupJson.contains('bedtimeWindDownConfig'), true);
      expect(backupJson.contains('"targetWakeHour":6'), true);
      expect(backupJson.contains('"targetSleepCycles":4'), true);
      expect(backupJson.contains('"windDownLeadMinutes":15'), true);

      // Restore into fresh storage
      SharedPreferences.setMockInitialValues({});
      final newPrefs = await SharedPreferences.getInstance();
      final newStorage = StorageService(newPrefs);

      final success = await newStorage.restoreFullBackupJson(backupJson);
      expect(success, true);

      final restored = newStorage.loadBedtimeWindDownConfig();
      expect(restored.targetWakeHour, 6);
      expect(restored.targetWakeMinute, 30);
      expect(restored.targetSleepCycles, 4);
      expect(restored.windDownLeadMinutes, 15);
    });
  });

  group('Bedtime Wind-Down Ambient Audio Trigger Tests', () {
    test('Initializes with audio inactive and default rain sound', () {
      expect(sleepWellnessProvider.isWindDownAudioPlaying, false);
      expect(sleepWellnessProvider.activeAmbientSound, AmbientSoundType.rain);
      expect(sleepWellnessProvider.windDownAudioMinutes, 30);
      expect(sleepWellnessProvider.remainingAudioSeconds, 0);
      expect(sleepWellnessProvider.formattedRemainingTime, '00:00');
      expect(sleepWellnessProvider.audioProgress, 0.0);
    });

    test('1-tap startWindDownAudio initiates 30-minute timer and activates audio', () async {
      await sleepWellnessProvider.startWindDownAudio(
        soundType: AmbientSoundType.rain,
        durationMinutes: 30,
      );

      expect(sleepWellnessProvider.isWindDownAudioPlaying, true);
      expect(sleepWellnessProvider.activeAmbientSound, AmbientSoundType.rain);
      expect(sleepWellnessProvider.windDownAudioMinutes, 30);
      expect(sleepWellnessProvider.remainingAudioSeconds, 1800);
      expect(sleepWellnessProvider.formattedRemainingTime, '30:00');
      expect(sleepWellnessProvider.audioProgress, 0.0);

      await sleepWellnessProvider.stopWindDownAudio();
    });

    test('Switching ambient sound updates active sound to forest breeze', () async {
      await sleepWellnessProvider.startWindDownAudio(soundType: AmbientSoundType.rain);
      expect(sleepWellnessProvider.activeAmbientSound, AmbientSoundType.rain);

      await sleepWellnessProvider.switchAmbientSound(AmbientSoundType.forest);
      expect(sleepWellnessProvider.activeAmbientSound, AmbientSoundType.forest);

      await sleepWellnessProvider.stopWindDownAudio();
    });

    test('Toggle wind-down audio stops active playback and restarts smoothly', () async {
      expect(sleepWellnessProvider.isWindDownAudioPlaying, false);

      await sleepWellnessProvider.toggleWindDownAudio(soundType: AmbientSoundType.forest);
      expect(sleepWellnessProvider.isWindDownAudioPlaying, true);
      expect(sleepWellnessProvider.activeAmbientSound, AmbientSoundType.forest);

      // Second toggle stops it
      await sleepWellnessProvider.toggleWindDownAudio();
      expect(sleepWellnessProvider.isWindDownAudioPlaying, false);
      expect(sleepWellnessProvider.remainingAudioSeconds, 0);
    });

    test('Adjusting ambient volume updates volume state within limits', () async {
      await sleepWellnessProvider.setAmbientVolume(0.8);
      expect(sleepWellnessProvider.ambientVolume, 0.8);

      // Clamping checks
      await sleepWellnessProvider.setAmbientVolume(1.5);
      expect(sleepWellnessProvider.ambientVolume, 1.0);

      await sleepWellnessProvider.setAmbientVolume(-0.2);
      expect(sleepWellnessProvider.ambientVolume, 0.0);
    });

    test('Stopping audio resets countdown timer and active flag', () async {
      await sleepWellnessProvider.startWindDownAudio(durationMinutes: 15);
      expect(sleepWellnessProvider.isWindDownAudioPlaying, true);
      expect(sleepWellnessProvider.remainingAudioSeconds, 900);

      await sleepWellnessProvider.stopWindDownAudio();
      expect(sleepWellnessProvider.isWindDownAudioPlaying, false);
      expect(sleepWellnessProvider.remainingAudioSeconds, 0);
      expect(sleepWellnessProvider.formattedRemainingTime, '00:00');
    });
  });
}
