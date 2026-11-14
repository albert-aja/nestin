import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/data/models/focus_session_log.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/audio_service.dart';
import 'package:nestin/data/services/ambient_sound_service.dart';
import 'package:nestin/providers/timer_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
  late AudioService audioService;
  late TimerProvider timerProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
    notificationService = NotificationService();
    audioService = AudioService();
    timerProvider = TimerProvider(
      storageService,
      notificationService,
      audioService,
    );
  });

  tearDown(() {
    timerProvider.dispose();
  });

  group('Pomodoro Focus Mode Tests', () {
    test('Initializes with standard 25m work phase and cycle 1', () {
      expect(timerProvider.pomodoroPhase, FocusPhase.work);
      expect(timerProvider.pomodoroCycle, 1);
      expect(timerProvider.pomodoroTotalSeconds, 25 * 60);
      expect(timerProvider.pomodoroRemainingSeconds, 25 * 60);
      expect(timerProvider.formattedPomodoroRemaining(), '25:00');
      expect(timerProvider.isPomodoroRunning, isFalse);
      expect(timerProvider.isPomodoroPaused, isFalse);
    });

    test('Start, pause, resume, and reset pomodoro focus timer', () async {
      await timerProvider.startPomodoro();
      expect(timerProvider.isPomodoroRunning, isTrue);
      expect(timerProvider.isPomodoroPaused, isFalse);

      await timerProvider.pausePomodoro();
      expect(timerProvider.isPomodoroRunning, isTrue);
      expect(timerProvider.isPomodoroPaused, isTrue);

      await timerProvider.resumePomodoro();
      expect(timerProvider.isPomodoroRunning, isTrue);
      expect(timerProvider.isPomodoroPaused, isFalse);

      await timerProvider.resetPomodoro();
      expect(timerProvider.isPomodoroRunning, isFalse);
      expect(timerProvider.isPomodoroPaused, isFalse);
      expect(timerProvider.pomodoroRemainingSeconds, 25 * 60);
    });

    test('Skip phase transitions from Work to Short Break and back to Work', () async {
      expect(timerProvider.pomodoroPhase, FocusPhase.work);
      expect(timerProvider.pomodoroCycle, 1);

      // Skip Work -> Short Break
      await timerProvider.skipPomodoroPhase();
      expect(timerProvider.pomodoroPhase, FocusPhase.shortBreak);
      expect(timerProvider.pomodoroTotalSeconds, 5 * 60);
      expect(timerProvider.formattedPomodoroRemaining(), '05:00');

      // Skip Short Break -> Work Cycle 2
      await timerProvider.skipPomodoroPhase();
      expect(timerProvider.pomodoroPhase, FocusPhase.work);
      expect(timerProvider.pomodoroCycle, 2);
      expect(timerProvider.pomodoroTotalSeconds, 25 * 60);
    });

    test('Cycle 4 work phase advances to Long Break', () async {
      // Simulate fast forward to cycle 4
      await timerProvider.skipPomodoroPhase(); // Break 1
      await timerProvider.skipPomodoroPhase(); // Work 2
      await timerProvider.skipPomodoroPhase(); // Break 2
      await timerProvider.skipPomodoroPhase(); // Work 3
      await timerProvider.skipPomodoroPhase(); // Break 3
      await timerProvider.skipPomodoroPhase(); // Work 4
      expect(timerProvider.pomodoroPhase, FocusPhase.work);
      expect(timerProvider.pomodoroCycle, 4);

      // Skip Work 4 -> Long Break (15 mins)
      await timerProvider.skipPomodoroPhase();
      expect(timerProvider.pomodoroPhase, FocusPhase.longBreak);
      expect(timerProvider.pomodoroTotalSeconds, 15 * 60);
      expect(timerProvider.formattedPomodoroRemaining(), '15:00');
    });

    test('Custom intervals updates work and break durations', () async {
      await timerProvider.setCustomPomodoroDurations(
        workMinutes: 50,
        shortBreakMinutes: 10,
        longBreakMinutes: 20,
      );

      expect(timerProvider.pomodoroTotalSeconds, 50 * 60);
      expect(timerProvider.pomodoroRemainingSeconds, 50 * 60);
      expect(timerProvider.formattedPomodoroRemaining(), '50:00');
    });

    test('Ambient background sound selection and volume control', () async {
      expect(timerProvider.selectedAmbientSound, AmbientSoundType.none);

      await timerProvider.setAmbientSound(AmbientSoundType.rain);
      expect(timerProvider.selectedAmbientSound, AmbientSoundType.rain);

      await timerProvider.setAmbientVolume(0.8);
      expect(timerProvider.ambientVolume, 0.8);

      await timerProvider.setAmbientSound(AmbientSoundType.coffeeShop);
      expect(timerProvider.selectedAmbientSound, AmbientSoundType.coffeeShop);

      await timerProvider.setAmbientSound(AmbientSoundType.forest);
      expect(timerProvider.selectedAmbientSound, AmbientSoundType.forest);
    });

    test('Focus history log recording and today metrics calculation', () async {
      expect(timerProvider.todayFocusMinutes, 0);
      expect(timerProvider.todayCompletedPomodoros, 0);

      // Simulate completed session logging
      final log1 = FocusSessionLog(
        id: 'log_1',
        taskLabel: 'Deep Work on Nestin',
        durationMinutes: 25,
        phase: FocusPhase.work,
        completedAt: DateTime.now(),
        ambientSoundUsed: 'rain',
      );
      final log2 = FocusSessionLog(
        id: 'log_2',
        taskLabel: 'Code Review',
        durationMinutes: 25,
        phase: FocusPhase.work,
        completedAt: DateTime.now(),
        ambientSoundUsed: 'coffeeShop',
      );

      await storageService.saveFocusLogs([log1, log2]);
      final loadedProvider = TimerProvider(
        storageService,
        notificationService,
        audioService,
      );

      expect(loadedProvider.focusLogs.length, 2);
      expect(loadedProvider.todayFocusMinutes, 50);
      expect(loadedProvider.todayCompletedPomodoros, 2);
      expect(loadedProvider.totalCompletedPomodoros, 2);

      await loadedProvider.clearFocusLogs();
      expect(loadedProvider.focusLogs, isEmpty);
      expect(loadedProvider.todayFocusMinutes, 0);

      loadedProvider.dispose();
    });

    test('AmbientSoundService synthesizes valid WAV audio bytes for all noise types', () {
      for (final type in [
        AmbientSoundType.rain,
        AmbientSoundType.coffeeShop,
        AmbientSoundType.forest,
      ]) {
        final bytes = AmbientSoundService.synthesizeWavBytes(type);
        expect(bytes.length, greaterThan(44));
        // Check RIFF header
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
        // Check WAVE header
        expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
        // Check fmt chunk
        expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
        // Check data chunk
        expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
      }
    });

    test('StorageService backup export and restore preserves focus logs', () async {
      final log = FocusSessionLog(
        id: 'backup_log_1',
        taskLabel: 'Architecture Sprint',
        durationMinutes: 25,
        phase: FocusPhase.work,
        completedAt: DateTime.now(),
        ambientSoundUsed: 'forest',
      );
      await storageService.saveFocusLogs([log]);

      final backupJson = storageService.exportFullBackupJson();
      expect(backupJson, contains('Architecture Sprint'));
      expect(backupJson, contains('backup_log_1'));

      // Wipe and restore
      await storageService.saveFocusLogs([]);
      expect(storageService.loadFocusLogs(), isEmpty);

      final restored = await storageService.restoreFullBackupJson(backupJson);
      expect(restored, isTrue);

      final restoredLogs = storageService.loadFocusLogs();
      expect(restoredLogs.length, 1);
      expect(restoredLogs.first.taskLabel, 'Architecture Sprint');
      expect(restoredLogs.first.ambientSoundUsed, 'forest');
    });
  });
}
