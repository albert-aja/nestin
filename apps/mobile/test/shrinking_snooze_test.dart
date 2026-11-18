import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/l10n/app_language.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/alarm.dart';
import 'package:nestin/data/models/alarm_category.dart';
import 'package:nestin/data/models/alarm_schedule.dart';
import 'package:nestin/data/services/audio_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/alarm_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/providers/sound_provider.dart';
import 'package:nestin/ui/screens/alarms/alarm_edit_screen.dart';

class _FakeAudioService implements AudioService {
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
  Future<void> stop() async {}

  @override
  Future<void> previewTone(
    String soundId,
    double volume, {
    String? customFilePath,
  }) async {}

  @override
  void dispose() {}
}

Alarm _sampleAlarm({
  int snoozeMinutes = 10,
  int maxSnoozeCount = 3,
  int snoozeCount = 0,
  bool shrinkingSnoozeEnabled = true,
}) {
  final now = DateTime(2026, 11, 18, 7, 0);
  return Alarm(
    id: 'alarm-shrink-1',
    title: 'Morning Wake',
    hour: 7,
    minute: 0,
    category: AlarmCategory.fromType(AlarmCategoryType.wakeUp),
    schedule: const AlarmSchedule(type: ScheduleType.daily),
    snoozeMinutes: snoozeMinutes,
    maxSnoozeCount: maxSnoozeCount,
    snoozeCount: snoozeCount,
    shrinkingSnoozeEnabled: shrinkingSnoozeEnabled,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Alarm Smart Shrinking Snooze Math & Serialization', () {
    test('shortens 10m -> 5m -> 3m -> 2m progressively when enabled', () {
      expect(
        Alarm.shrinkingPreviewSequence(baseMinutes: 10, maxCount: 3),
        [10, 5, 3],
      );
      expect(
        Alarm.computeShrinkingSnoozeMinutes(
          baseMinutes: 10,
          currentSnoozeCount: 3,
          shrinkingEnabled: true,
        ),
        2,
      );
      expect(
        Alarm.shrinkingPreviewSequence(baseMinutes: 9, maxCount: 3),
        [9, 5, 3],
      );
      expect(
        Alarm.computeShrinkingSnoozeMinutes(
          baseMinutes: 10,
          currentSnoozeCount: 2,
          shrinkingEnabled: false,
        ),
        10,
      );
    });

    test('round-trips shrinkingSnoozeEnabled in JSON with legacy default false',
        () {
      final alarm = _sampleAlarm(shrinkingSnoozeEnabled: true);
      final json = alarm.toJson();
      expect(json['shrinkingSnoozeEnabled'], isTrue);

      final decoded = Alarm.fromJson(json);
      expect(decoded.shrinkingSnoozeEnabled, isTrue);

      json.remove('shrinkingSnoozeEnabled');
      final legacy = Alarm.fromJson(json);
      expect(legacy.shrinkingSnoozeEnabled, isFalse);
    });
  });

  group('AlarmProvider.snoozeAlarm Shrinking Intervals', () {
    test('uses 10m, then 5m, then 3m on consecutive snoozes', () async {
      final storage = await StorageService.init();
      final alarmProvider = AlarmProvider(
        storage,
        _FakeAudioService(),
        NotificationService(),
      );
      final alarm = _sampleAlarm(
        snoozeMinutes: 10,
        maxSnoozeCount: 3,
        shrinkingSnoozeEnabled: true,
      );
      await alarmProvider.addAlarm(alarm);

      // Snooze #1 -> ~10m
      var before = DateTime.now();
      await alarmProvider.snoozeAlarm(alarm.id);
      var updated = alarmProvider.alarms.firstWhere((a) => a.id == alarm.id);
      expect(updated.snoozeCount, 1);
      expect(
        updated.snoozeUntil!.difference(before).inMinutes,
        inInclusiveRange(9, 10),
      );

      // Snooze #2 -> ~5m
      before = DateTime.now();
      await alarmProvider.snoozeAlarm(alarm.id);
      updated = alarmProvider.alarms.firstWhere((a) => a.id == alarm.id);
      expect(updated.snoozeCount, 2);
      expect(
        updated.snoozeUntil!.difference(before).inMinutes,
        inInclusiveRange(4, 5),
      );

      // Snooze #3 -> ~3m
      before = DateTime.now();
      await alarmProvider.snoozeAlarm(alarm.id);
      updated = alarmProvider.alarms.firstWhere((a) => a.id == alarm.id);
      expect(updated.snoozeCount, 3);
      expect(
        updated.snoozeUntil!.difference(before).inMinutes,
        inInclusiveRange(2, 3),
      );
      alarmProvider.dispose();
    });
  });

  group('AlarmEditScreen Shrinking Snooze Toggle UI', () {
    testWidgets('toggles Smart Shrinking Snooze and previews sequence',
        (tester) async {
      final storage = await StorageService.init();
      final settings = SettingsProvider(storage);
      await settings.setLanguage(AppLanguage.en);
      final alarmProvider = AlarmProvider(
        storage,
        _FakeAudioService(),
        NotificationService(),
      );
      final soundProvider = SoundProvider(storage);
      final initial = _sampleAlarm(
        snoozeMinutes: 10,
        maxSnoozeCount: 3,
        shrinkingSnoozeEnabled: false,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: alarmProvider),
            ChangeNotifierProvider.value(value: soundProvider),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AlarmEditScreen(initialAlarm: initial),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byKey(const Key('alarm_shrinking_snooze_switch'));
      await tester.ensureVisible(switchFinder);
      await tester.pumpAndSettle();

      expect(find.text('Smart Shrinking Snooze'), findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.text('Sequence: 10m → 5m → 3m'), findsOneWidget);
      expect(tester.takeException(), isNull);
      alarmProvider.dispose();
    });
  });
}
