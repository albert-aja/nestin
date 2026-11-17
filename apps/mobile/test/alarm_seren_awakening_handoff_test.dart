import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/data/models/alarm.dart';
import 'package:nestin/data/models/alarm_category.dart';
import 'package:nestin/data/models/alarm_schedule.dart';
import 'package:nestin/data/models/challenge_profile.dart';
import 'package:nestin/data/models/seren_relaxation_models.dart';
import 'package:nestin/data/services/ambient_sound_service.dart';
import 'package:nestin/data/services/audio_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/seren_tts_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/alarm_provider.dart';
import 'package:nestin/providers/seren_relaxation_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/ui/screens/alarms/active_alarm_screen.dart';

class _FakeAudioService implements AudioService {
  int stopCalls = 0;

  @override
  bool get isPlaying => false;

  @override
  double get currentVolume => 0.0;

  @override
  Future<void> startAlarm({
    required String soundId,
    String? customFilePath,
    required double targetVolume,
    required bool gradualVolume,
    required int gradualDurationSeconds,
  }) async {}

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeNotificationService implements NotificationService {
  @override
  Future<void> scheduleAlarmNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {}

  @override
  Future<void> showAlarmNotification({
    required int id,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAmbientSoundService extends AmbientSoundService {
  @override
  Future<void> syncMixerTracks(
    List<SoundMixerTrackConfig> tracks, {
    required double masterVolume,
    required bool shouldPlay,
    double duckFactor = 1.0,
    double fadeMultiplier = 1.0,
  }) async {}

  @override
  Future<void> applyMixerVolumes(
    List<SoundMixerTrackConfig> tracks, {
    required double masterVolume,
    double duckFactor = 1.0,
    double fadeMultiplier = 1.0,
  }) async {}

  @override
  Future<void> pauseMixer() async {}

  @override
  Future<void> stopMixer() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeSerenTtsService extends SerenTtsService {
  @override
  Future<void> speakParagraphs(
    List<String> paragraphs, {
    double? rate,
    double? volume,
    String? languageCode,
    int startIndex = 0,
    VoidCallback? onCompleted,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Morning Alarm -> Seren Peaceful Awakening Handoff', () {
    late StorageService storage;
    late _FakeAudioService audioService;
    late NotificationService notificationService;
    late AlarmProvider alarmProvider;
    late SerenRelaxationProvider serenProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = StorageService(prefs);
      audioService = _FakeAudioService();
      notificationService = _FakeNotificationService();
      alarmProvider = AlarmProvider(
        storage,
        audioService,
        notificationService,
      );
      serenProvider = SerenRelaxationProvider(
        storage,
        ambientSoundService: _FakeAmbientSoundService(),
        ttsService: _FakeSerenTtsService(),
      );
    });

    tearDown(() {
      serenProvider.dispose();
    });

    test(
        'Alarm serializes and restores serenAwakeningHandoff mode across JSON round-trip',
        () {
      final now = DateTime(2026, 11, 17, 7, 0);
      final alarm = Alarm(
        id: 'alarm_handoff_1',
        title: 'Morning Sanctuary Wake-Up',
        hour: 6,
        minute: 30,
        category: AlarmCategory.fromType(AlarmCategoryType.wakeUp),
        schedule: AlarmSchedule.weekdays(),
        serenAwakeningHandoff:
            SerenAwakeningHandoffMode.peacefulMorningSoundscape,
        createdAt: now,
        updatedAt: now,
      );

      final restored = Alarm.fromJson(alarm.toJson());
      expect(
        restored.serenAwakeningHandoff,
        SerenAwakeningHandoffMode.peacefulMorningSoundscape,
      );
    });

    test(
        'Dismissing alarm with peacefulMorningSoundscape handoff launches 3-minute Peaceful Morning Sanctuary preset',
        () async {
      final now = DateTime.now();
      final alarm = Alarm(
        id: 'alarm_soundscape',
        title: 'Sunrise Soundscape Alarm',
        hour: 7,
        minute: 0,
        category: AlarmCategory.fromType(AlarmCategoryType.wakeUp),
        schedule: AlarmSchedule.daily(),
        serenAwakeningHandoff:
            SerenAwakeningHandoffMode.peacefulMorningSoundscape,
        createdAt: now,
        updatedAt: now,
      );
      await alarmProvider.addAlarm(alarm);
      await alarmProvider.triggerAlarm(alarm);
      expect(alarmProvider.ringingAlarm?.id, alarm.id);

      await alarmProvider.dismissAlarm(
        alarm.id,
        serenRelaxationProvider: serenProvider,
      );

      expect(alarmProvider.ringingAlarm, isNull);
      expect(
        alarmProvider.lastTriggeredAwakeningHandoff,
        SerenAwakeningHandoffMode.peacefulMorningSoundscape,
      );
      expect(serenProvider.timeOfDayMode, RelaxationTimeOfDayMode.morning);
      expect(serenProvider.isMixerPlaying, isTrue);
      expect(serenProvider.activeSoundscapeId, 'preset_peaceful_morning');
      expect(serenProvider.isTimerActive, isTrue);
      expect(serenProvider.timerTotalSeconds, 180);
    });

    test(
        'Dismissing alarm with gentleMorningBreath handoff launches 3-minute Gentle Morning Awakening Breath session',
        () async {
      final now = DateTime.now();
      final alarm = Alarm(
        id: 'alarm_breath',
        title: 'Morning Breath Alarm',
        hour: 6,
        minute: 45,
        category: AlarmCategory.fromType(AlarmCategoryType.wakeUp),
        schedule: AlarmSchedule.daily(),
        serenAwakeningHandoff: SerenAwakeningHandoffMode.gentleMorningBreath,
        createdAt: now,
        updatedAt: now,
      );
      await alarmProvider.addAlarm(alarm);
      await alarmProvider.triggerAlarm(alarm);

      await alarmProvider.dismissAlarm(
        alarm.id,
        serenRelaxationProvider: serenProvider,
      );

      expect(alarmProvider.ringingAlarm, isNull);
      expect(
        alarmProvider.lastTriggeredAwakeningHandoff,
        SerenAwakeningHandoffMode.gentleMorningBreath,
      );
      expect(serenProvider.isGuidedSessionRunning, isTrue);
      expect(serenProvider.activeGuidedSession?.id, 'breath_gentle_morning');
      expect(serenProvider.guidedDurationMinutes, 3);
    });

    testWidgets(
        'ActiveAlarmScreen renders Bahasa Indonesia handoff chips and launches Seren soundscape on dismiss',
        (tester) async {
      final now = DateTime.now();
      final alarm = Alarm(
        id: 'alarm_ui_id',
        title: 'Bangun Pagi',
        hour: 6,
        minute: 30,
        category: AlarmCategory.fromType(AlarmCategoryType.wakeUp),
        schedule: AlarmSchedule.daily(),
        challengeInherited: false,
        challengeOverride: const WakeUpChallengeProfile(
          id: 'no_challenge',
          isEnabled: false,
        ),
        serenAwakeningHandoff: SerenAwakeningHandoffMode.none,
        createdAt: now,
        updatedAt: now,
      );
      await alarmProvider.addAlarm(alarm);
      await alarmProvider.triggerAlarm(alarm);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: alarmProvider),
            ChangeNotifierProvider.value(value: serenProvider),
            ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
          ],
          child: MaterialApp(
            locale: const Locale('id'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: ActiveAlarmScreen(alarm: alarm),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Transisi Bangun Tenang Seren saat Dimatikan'),
        findsOneWidget,
      );

      // Select 3-Min Peaceful Morning Soundscape chip on ActiveAlarmScreen
      await tester.tap(
        find.byKey(
          const ValueKey(
            'active_alarm_handoff_chip_peacefulMorningSoundscape',
          ),
        ),
      );
      await tester.pump();

      // Tap Dismiss Alarm button
      await tester.tap(find.byKey(const ValueKey('btn_active_alarm_dismiss')));
      await tester.pump();

      expect(serenProvider.isMixerPlaying, isTrue);
      expect(serenProvider.activeSoundscapeId, 'preset_peaceful_morning');
      expect(serenProvider.timerTotalSeconds, 180);

      serenProvider.cancelPlaybackTimer();
    });
  });
}
