import 'package:material_ui/material_ui.dart';
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
import 'package:nestin/ui/screens/alarms/alarms_list_screen.dart';

Future<
    ({
      StorageService storage,
      SettingsProvider settings,
      AlarmProvider alarms,
      SoundProvider sounds,
    })> _createAlarmTestEnv({
  AppLanguage language = AppLanguage.en,
  List<Alarm> initialAlarms = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  await AppLocalizations.ensureDateFormatting();
  final storage = await StorageService.init();
  final settings = SettingsProvider(storage);
  await settings.setLanguage(language);
  if (initialAlarms.isNotEmpty) {
    await storage.saveAlarms(initialAlarms);
  }
  final alarms = AlarmProvider(
    storage,
    AudioService(),
    NotificationService(),
  );
  final sounds = SoundProvider(storage);
  return (
    storage: storage,
    settings: settings,
    alarms: alarms,
    sounds: sounds,
  );
}

Widget _wrapAlarmsScreen({
  required SettingsProvider settings,
  required AlarmProvider alarms,
  required SoundProvider sounds,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ChangeNotifierProvider<AlarmProvider>(create: (_) => alarms),
      ChangeNotifierProvider<SoundProvider>.value(value: sounds),
    ],
    child: Consumer<SettingsProvider>(
      builder: (_, s, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: s.themeMode,
        locale: s.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const AlarmsListScreen(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alarm.formatRingsIn unit tests', () {
    test('formats hours + minutes, minutes only, days, and < 1m in EN and ID',
        () {
      final base = DateTime(2026, 11, 14, 10, 0);

      final hoursMin = Alarm(
        id: 'a1',
        title: 'Afternoon',
        hour: 17,
        minute: 14,
        category: AlarmCategory.fromType(AlarmCategoryType.wakeUp),
        schedule: AlarmSchedule.daily(),
        createdAt: base,
        updatedAt: base,
      );
      expect(hoursMin.formatRingsIn(base), 'Rings in 7h 14m');
      expect(
        hoursMin.formatRingsIn(base, isIndonesian: true),
        'Berbunyi dalam 7j 14m',
      );

      final minsOnly = hoursMin.copyWith(hour: 10, minute: 25);
      expect(minsOnly.formatRingsIn(base), 'Rings in 25m');
      expect(
        minsOnly.formatRingsIn(base, isIndonesian: true),
        'Berbunyi dalam 25m',
      );

      final lessThanMin = hoursMin.copyWith(hour: 10, minute: 0);
      final almostThere = DateTime(2026, 11, 14, 9, 59, 30);
      expect(
        lessThanMin.formatRingsIn(almostThere),
        'Rings in less than a minute',
      );
      expect(
        lessThanMin.formatRingsIn(almostThere, isIndonesian: true),
        'Berbunyi kurang dari semenit',
      );

      // 2026-11-14 is Saturday (weekday 6); weekdays-only rings Monday (2d 0h 0m)
      final multiDay = hoursMin.copyWith(
        hour: 10,
        minute: 0,
        schedule: AlarmSchedule.weekdays(),
      );
      expect(multiDay.formatRingsIn(base), 'Rings in 2d 0h 0m');
      expect(
        multiDay.formatRingsIn(base, isIndonesian: true),
        'Berbunyi dalam 2h 0j 0m',
      );
    });
  });

  group('AlarmsListScreen & AlarmEditScreen next-ring snackbar', () {
    testWidgets('toggling alarm ON surfaces "Rings in ..." snackbar',
        (tester) async {
      final now = DateTime.now();
      final alarm = Alarm(
        id: 'alarm-toggle-1',
        title: 'Morning Wake',
        hour: 7,
        minute: 30,
        isEnabled: false,
        category: AlarmCategory.fromType(AlarmCategoryType.wakeUp),
        schedule: AlarmSchedule.daily(),
        createdAt: now,
        updatedAt: now,
      );

      final env = await _createAlarmTestEnv(initialAlarms: [alarm]);
      await tester.pumpWidget(
        _wrapAlarmsScreen(
          settings: env.settings,
          alarms: env.alarms,
          sounds: env.sounds,
        ),
      );
      await tester.pumpAndSettle();

      // Enable alarm via Switch
      await tester.tap(find.byType(Switch).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Rings in '), findsOneWidget);
      expect(env.alarms.alarms.first.isEnabled, isTrue);

      // Disable alarm -> hides snackbar without showing another countdown
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Rings in '), findsNothing);
      expect(env.alarms.alarms.first.isEnabled, isFalse);
    });

    testWidgets('toggling alarm ON in Indonesian surfaces "Berbunyi ..." toast',
        (tester) async {
      final now = DateTime.now();
      final alarm = Alarm(
        id: 'alarm-toggle-id',
        title: 'Pagi',
        hour: 6,
        minute: 0,
        isEnabled: false,
        category: AlarmCategory.fromType(AlarmCategoryType.wakeUp),
        schedule: AlarmSchedule.daily(),
        createdAt: now,
        updatedAt: now,
      );

      final env = await _createAlarmTestEnv(
        language: AppLanguage.id,
        initialAlarms: [alarm],
      );
      await tester.pumpWidget(
        _wrapAlarmsScreen(
          settings: env.settings,
          alarms: env.alarms,
          sounds: env.sounds,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Berbunyi '), findsOneWidget);
    });

    testWidgets('saving new alarm in AlarmEditScreen surfaces countdown toast',
        (tester) async {
      final env = await _createAlarmTestEnv();
      final initialCount = env.alarms.alarms.length;
      await tester.pumpWidget(
        _wrapAlarmsScreen(
          settings: env.settings,
          alarms: env.alarms,
          sounds: env.sounds,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rings '), findsOneWidget);
      expect(env.alarms.alarms.length, initialCount + 1);
    });

    testWidgets('saving a disabled alarm does not show next-ring toast',
        (tester) async {
      final now = DateTime.now();
      final disabledAlarm = Alarm(
        id: 'alarm-disabled-edit',
        title: 'Paused Alarm',
        hour: 8,
        minute: 15,
        isEnabled: false,
        category: AlarmCategory.fromType(AlarmCategoryType.work),
        schedule: AlarmSchedule.daily(),
        createdAt: now,
        updatedAt: now,
      );

      final env = await _createAlarmTestEnv(initialAlarms: [disabledAlarm]);
      await tester.pumpWidget(
        _wrapAlarmsScreen(
          settings: env.settings,
          alarms: env.alarms,
          sounds: env.sounds,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Paused Alarm'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
