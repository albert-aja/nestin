import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/alarm.dart';
import 'package:nestin/data/models/alarm_category.dart';
import 'package:nestin/data/models/alarm_schedule.dart';
import 'package:nestin/data/models/hydration_data.dart';
import 'package:nestin/data/models/routine_item.dart';
import 'package:nestin/data/models/user_preferences.dart';
import 'package:nestin/data/services/audio_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/oem_hardening_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/data/services/widget_sync_service.dart';
import 'package:nestin/providers/alarm_provider.dart';
import 'package:nestin/providers/hydration_provider.dart';
import 'package:nestin/providers/oem_hardening_provider.dart';
import 'package:nestin/providers/routine_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/providers/sound_provider.dart';
import 'package:nestin/providers/wearable_provider.dart';
import 'package:nestin/ui/screens/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final recordedCalls = <({String method, Map<String, dynamic> args})>[];

  setUp(() {
    recordedCalls.clear();
    WidgetSyncService.instance.setShowMascotsEnabled(true);
    WidgetSyncService.instance.methodInvoker = (method, args) async {
      recordedCalls.add((method: method, args: Map<String, dynamic>.from(args)));
      return true;
    };
  });

  tearDown(() {
    WidgetSyncService.instance.methodInvoker = null;
    WidgetSyncService.instance.setShowMascotsEnabled(true);
  });

  group('Glance Widget Mascot Avatars', () {
    test('resolveAlarmMascot selects Roo quiet, hurry, or alarm pose accurately',
        () {
      final now = DateTime(2026, 11, 14, 7, 0);

      final quietAvatar = WidgetSyncService.resolveAlarmMascot(null, now: now);
      expect(quietAvatar.mascotName, 'Roo');
      expect(quietAvatar.drawableKey, 'roo_quiet');
      expect(
        quietAvatar.assetPath,
        'assets/mascots/sprites/roo/quiet_day.png',
      );

      final imminentAlarm = Alarm(
        id: 'alarm-soon',
        title: 'Standup Prep',
        hour: 7,
        minute: 40,
        isEnabled: true,
        category: AlarmCategory.fromType(AlarmCategoryType.wakeUp),
        schedule: AlarmSchedule.daily(),
        createdAt: now,
        updatedAt: now,
      );
      final hurryAvatar =
          WidgetSyncService.resolveAlarmMascot(imminentAlarm, now: now);
      expect(hurryAvatar.drawableKey, 'roo_hurry');
      expect(hurryAvatar.assetPath, 'assets/mascots/sprites/roo/hurry.png');

      final laterAlarm = Alarm(
        id: 'alarm-later',
        title: 'Morning Wake',
        hour: 10,
        minute: 30,
        isEnabled: true,
        category: AlarmCategory.fromType(AlarmCategoryType.wakeUp),
        schedule: AlarmSchedule.daily(),
        createdAt: now,
        updatedAt: now,
      );
      final scheduledAvatar =
          WidgetSyncService.resolveAlarmMascot(laterAlarm, now: now);
      expect(scheduledAvatar.drawableKey, 'roo_alarm');
      expect(
        scheduledAvatar.assetPath,
        'assets/mascots/sprites/roo/alarm.png',
      );

      final disabledAvatar = WidgetSyncService.resolveAlarmMascot(
        laterAlarm.copyWith(isEnabled: false),
        now: now,
      );
      expect(disabledAvatar.drawableKey, 'roo_quiet');
    });

    test('resolveHabitsMascot tracks planning, momentum, on_fire, and habit_done states',
        () {
      final now = DateTime(2026, 11, 14, 8, 0);

      expect(WidgetSyncService.resolveHabitsMascot(null).drawableKey, 'roo_quiet');

      final readyRoutine = RoutineItem(
        id: 'r1',
        title: 'Morning Reset',
        type: RoutineType.morning,
        steps: const ['Water', 'Stretch', 'Plan'],
        completedStepIndices: const {},
        streakCount: 1,
        createdAt: now,
      );
      expect(
        WidgetSyncService.resolveHabitsMascot(readyRoutine).drawableKey,
        'roo_planning',
      );

      final momentumRoutine = readyRoutine.copyWith(completedStepIndices: {0});
      expect(
        WidgetSyncService.resolveHabitsMascot(momentumRoutine).drawableKey,
        'roo_momentum',
      );

      final hotStreakRoutine = readyRoutine.copyWith(
        completedStepIndices: {0, 1},
        streakCount: 4,
      );
      expect(
        WidgetSyncService.resolveHabitsMascot(hotStreakRoutine).drawableKey,
        'roo_on_fire',
      );

      final completedRoutine =
          readyRoutine.copyWith(completedStepIndices: {0, 1, 2});
      expect(
        WidgetSyncService.resolveHabitsMascot(completedRoutine).drawableKey,
        'roo_habit_done',
      );
    });

    test('resolveHydrationMascot selects Seren hydrate, you_go, and refreshed poses',
        () {
      final low = HydrationData(
        glassesConsumed: 2,
        dailyGoalGlasses: 8,
        lastLoggedDate: '2026-11-14',
      );
      final lowAvatar = WidgetSyncService.resolveHydrationMascot(low);
      expect(lowAvatar.mascotName, 'Seren');
      expect(lowAvatar.drawableKey, 'seren_hydrate');
      expect(lowAvatar.assetPath, 'assets/mascots/sprites/seren/hydrate.png');

      final mid = low.copyWith(glassesConsumed: 4);
      final midAvatar = WidgetSyncService.resolveHydrationMascot(mid);
      expect(midAvatar.drawableKey, 'seren_you_go');
      expect(midAvatar.assetPath, 'assets/mascots/sprites/seren/you_go.png');

      final done = low.copyWith(glassesConsumed: 8);
      final doneAvatar = WidgetSyncService.resolveHydrationMascot(done);
      expect(doneAvatar.drawableKey, 'seren_refreshed');
      expect(
        doneAvatar.assetPath,
        'assets/mascots/sprites/seren/refreshed.png',
      );
    });

    test('Android widget layouts, halo drawables, and nodpi mascot PNGs are provisioned',
        () {
      final requiredAndroidDrawables = [
        'mascot_widget_roo_alarm.png',
        'mascot_widget_roo_hurry.png',
        'mascot_widget_roo_morning.png',
        'mascot_widget_roo_quiet.png',
        'mascot_widget_roo_planning.png',
        'mascot_widget_roo_momentum.png',
        'mascot_widget_roo_on_fire.png',
        'mascot_widget_roo_habit_done.png',
        'mascot_widget_seren_hydrate.png',
        'mascot_widget_seren_you_go.png',
        'mascot_widget_seren_refreshed.png',
        'mascot_widget_scout_captured.png',
        'mascot_widget_twill_noted.png',
        'mascot_widget_echo_reflect.png',
      ];

      for (final fileName in requiredAndroidDrawables) {
        final file = File(
          'android/app/src/main/res/drawable-nodpi/$fileName',
        );
        expect(file.existsSync(), isTrue, reason: 'Missing $fileName');
        expect(file.lengthSync(), greaterThan(1000));
        expect(file.lengthSync(), lessThan(80 * 1024));
      }

      for (final halo in [
        'widget_mascot_halo_roo.xml',
        'widget_mascot_halo_seren.xml',
        'widget_mascot_halo_scout.xml',
        'widget_mascot_halo_twill.xml',
        'widget_mascot_halo_echo.xml',
        'ic_widget_water.xml',
        'widget_btn_hydration_bg.xml',
        'widget_pill_hydration_bg.xml',
        'widget_pill_hydration_done_bg.xml',
        'widget_progress_hydration.xml',
        'widget_progress_hydration_done.xml',
      ]) {
        expect(
          File('android/app/src/main/res/drawable/$halo').existsSync(),
          isTrue,
          reason: 'Missing $halo',
        );
      }

      final nextAlarmXml =
          File('android/app/src/main/res/layout/widget_next_alarm.xml')
              .readAsStringSync();
      expect(nextAlarmXml.contains('iv_alarm_mascot'), isTrue);
      expect(nextAlarmXml.contains('layout_alarm_mascot_badge'), isTrue);

      final habitXml =
          File('android/app/src/main/res/layout/widget_habit_checklist.xml')
              .readAsStringSync();
      expect(habitXml.contains('iv_habit_mascot'), isTrue);
      expect(habitXml.contains('layout_habit_mascot_badge'), isTrue);

      final quickCaptureXml =
          File('android/app/src/main/res/layout/widget_quick_capture.xml')
              .readAsStringSync();
      expect(quickCaptureXml.contains('btn_qc_scout'), isTrue);
      expect(quickCaptureXml.contains('layout_qc_note_mascot'), isTrue);
      expect(quickCaptureXml.contains('layout_qc_task_mascot'), isTrue);
      expect(quickCaptureXml.contains('layout_qc_alarm_mascot'), isTrue);
      expect(quickCaptureXml.contains('layout_qc_journal_mascot'), isTrue);

      final hydrationXml =
          File('android/app/src/main/res/layout/widget_hydration.xml')
              .readAsStringSync();
      expect(hydrationXml.contains('btn_hydration_add_glass'), isTrue);
      expect(hydrationXml.contains('iv_hydration_mascot'), isTrue);
      expect(hydrationXml.contains('layout_hydration_mascot_badge'), isTrue);
      expect(hydrationXml.contains('pb_hydration_progress'), isTrue);

      final hydrationInfoXml =
          File('android/app/src/main/res/xml/widget_hydration_info.xml')
              .readAsStringSync();
      expect(hydrationInfoXml.contains('home_screen|keyguard'), isTrue);

      final manifestXml = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifestXml.contains('.widgets.HydrationWidgetProvider'), isTrue);
      expect(manifestXml.contains('ACTION_HYDRATION_ADD_GLASS'), isTrue);

      for (final item in WidgetSyncService.quickCaptureMascots) {
        expect(
          File(item.assetPath).existsSync(),
          isTrue,
          reason: 'Missing sprite ${item.assetPath}',
        );
      }
    });

    test('sync calls emit mascotPose & showMascots and UserPreferences roundtrips flag',
        () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final settings = SettingsProvider(storage);

      expect(settings.showWidgetMascots, isTrue);

      await settings.toggleWidgetMascots(false);
      expect(settings.showWidgetMascots, isFalse);
      expect(storage.loadPreferences().showWidgetMascots, isFalse);

      final decoded =
          UserPreferences.fromJson(storage.loadPreferences().toJson());
      expect(decoded.showWidgetMascots, isFalse);

      expect(recordedCalls.last.method, 'updateQuickCapture');
      expect(recordedCalls.last.args['showMascots'], isFalse);

      final now = DateTime(2026, 11, 14, 9, 0);
      final soonAlarm = Alarm(
        id: 'alarm-soon-channel',
        title: 'Water Break',
        hour: 9,
        minute: 20,
        isEnabled: true,
        category: AlarmCategory.fromType(AlarmCategoryType.wakeUp),
        schedule: AlarmSchedule.daily(),
        createdAt: now,
        updatedAt: now,
      );
      await WidgetSyncService.instance.syncNextAlarm(soonAlarm, now: now);
      expect(recordedCalls.last.method, 'updateNextAlarm');
      expect(recordedCalls.last.args['mascotPose'], 'roo_hurry');
      expect(recordedCalls.last.args['showMascots'], isFalse);

      await settings.toggleWidgetMascots(true);
      await WidgetSyncService.instance.syncHabits([
        RoutineItem(
          id: 'r-fire',
          title: 'Evening Unwind',
          type: RoutineType.evening,
          steps: const ['Tea', 'Journal'],
          completedStepIndices: const {0},
          streakCount: 5,
          createdAt: now,
        ),
      ]);
      expect(recordedCalls.last.method, 'updateHabits');
      expect(recordedCalls.last.args['mascotPose'], 'roo_on_fire');
      expect(recordedCalls.last.args['showMascots'], isTrue);
    });

    testWidgets(
      'SettingsScreen displays Glance Widget Mascots preview and syncs all widgets on toggle',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final storage = await StorageService.init();
        final settings = SettingsProvider(storage);
        final notifications = NotificationService();
        final audio = AudioService();
        final alarmProvider = AlarmProvider(storage, audio, notifications);
        final routineProvider = RoutineProvider(storage);
        final hydrationProvider = HydrationProvider(storage, notifications);
        final oemProvider = OemHardeningProvider(
          storage,
          MockOemHardeningService(
            manufacturer: 'Pixel',
            brand: 'Google',
            model: 'Pixel 9',
            isIgnoringBatteryOptimizations: true,
            isKeepAliveRunning: false,
          ),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<StorageService>.value(value: storage),
              Provider<NotificationService>.value(value: notifications),
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<AlarmProvider>.value(value: alarmProvider),
              ChangeNotifierProvider<RoutineProvider>.value(
                value: routineProvider,
              ),
              ChangeNotifierProvider<HydrationProvider>.value(
                value: hydrationProvider,
              ),
              ChangeNotifierProvider<SoundProvider>(
                create: (_) => SoundProvider(storage),
              ),
              ChangeNotifierProvider<WearableProvider>(
                create: (_) => WearableProvider(storage),
              ),
              ChangeNotifierProvider<OemHardeningProvider>.value(
                value: oemProvider,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.light,
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Glance Widget Mascots'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(find.text('Glance Widget Mascots'), findsOneWidget);
        expect(find.text('Alarms • Roo'), findsOneWidget);
        expect(find.text('Habits • Roo'), findsOneWidget);
        expect(find.text('Hydration • Seren'), findsOneWidget);
        expect(find.text('Capture • Flock'), findsOneWidget);

        recordedCalls.clear();
        await tester.tap(find.text('Glance Widget Mascots'));
        await tester.pumpAndSettle();

        expect(settings.showWidgetMascots, isFalse);
        expect(find.text('Alarms • Roo'), findsNothing);
        expect(
          recordedCalls.map((c) => c.method).toSet(),
          containsAll([
            'updateQuickCapture',
            'updateNextAlarm',
            'updateHabits',
            'updateHydration',
          ]),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        alarmProvider.dispose();
        routineProvider.dispose();
        hydrationProvider.dispose();
        settings.dispose();
        oemProvider.dispose();
      },
    );
  });
}
