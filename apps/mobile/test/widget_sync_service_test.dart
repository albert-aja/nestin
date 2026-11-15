import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/data/models/alarm.dart';
import 'package:nestin/data/models/alarm_category.dart';
import 'package:nestin/data/models/alarm_schedule.dart';
import 'package:nestin/data/models/hydration_data.dart';
import 'package:nestin/data/models/routine_item.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/data/services/widget_sync_service.dart';
import 'package:nestin/providers/hydration_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> methodCalls = [];

  setUp(() {
    methodCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.nestin.app/widgets'),
      (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        if (methodCall.method == 'getInitialUri') {
          return 'nestin://quick_capture?type=note';
        }
        return true;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.nestin.app/widgets'),
      null,
    );
  });

  group('WidgetSyncService Tests', () {
    test('syncNextAlarm formats alarm countdown and payload correctly', () async {
      final alarm = Alarm(
        id: 'alarm_test_1',
        title: 'Morning Awakening',
        hour: 7,
        minute: 30,
        isEnabled: true,
        category: AlarmCategory.fromType(AlarmCategoryType.wakeUp),
        schedule: AlarmSchedule.daily(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await WidgetSyncService.instance.syncNextAlarm(alarm);

      expect(methodCalls.length, 1);
      final call = methodCalls.first;
      expect(call.method, 'updateNextAlarm');
      final args = call.arguments as Map<dynamic, dynamic>;
      expect(args['hasAlarm'], isTrue);
      expect(args['time'], '07:30');
      expect(args['ampm'], 'AM');
      expect(args['label'], contains('Morning Awakening'));
      expect(args['countdown'], isNotEmpty);
    });

    test('syncNextAlarm handles null or disabled alarm gracefully', () async {
      await WidgetSyncService.instance.syncNextAlarm(null);

      expect(methodCalls.length, 1);
      final call = methodCalls.first;
      expect(call.method, 'updateNextAlarm');
      final args = call.arguments as Map<dynamic, dynamic>;
      expect(args['hasAlarm'], isFalse);
      expect(args['time'], '--:--');
      expect(args['countdown'], 'Off');
    });

    test('syncHabits formats routine checklist, streak, and progress correctly', () async {
      final routine = RoutineItem(
        id: 'routine_1',
        title: 'Morning Energizer',
        type: RoutineType.morning,
        steps: const [
          'Drink 500ml water',
          '5-minute stretching',
          'Plan priorities',
          'Healthy breakfast',
        ],
        completedStepIndices: const {0, 1},
        streakCount: 5,
        createdAt: DateTime.now(),
      );

      await WidgetSyncService.instance.syncHabits([routine]);

      expect(methodCalls.length, 1);
      final call = methodCalls.first;
      expect(call.method, 'updateHabits');
      final args = call.arguments as Map<dynamic, dynamic>;
      expect(args['title'], 'Morning Energizer');
      expect(args['streak'], '🔥 5d');
      expect(args['progress'], '2/4');

      final steps = args['steps'] as List;
      expect(steps.length, 4);
      expect(steps[0]['text'], 'Drink 500ml water');
      expect(steps[0]['isDone'], isTrue);
      expect(steps[1]['isDone'], isTrue);
      expect(steps[2]['isDone'], isFalse);
    });

    test('deepLinkStream emits deep links correctly', () async {
      WidgetSyncService.instance.initialize();

      expectLater(
        WidgetSyncService.instance.deepLinkStream,
        emits(Uri.parse('nestin://habits')),
      );

      // Simulate native calling onDeepLink
      final binaryMessenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const codec = StandardMethodCodec();
      final ByteData data = codec.encodeMethodCall(
        const MethodCall('onDeepLink', 'nestin://habits'),
      );

      await binaryMessenger.handlePlatformMessage(
        'com.nestin.app/widgets',
        data,
        (ByteData? reply) {},
      );
    });

    test('syncHydration emits Seren mascot pose and intake payload accurately',
        () async {
      final hydration = HydrationData(
        glassesConsumed: 8,
        dailyGoalGlasses: 8,
        lastLoggedDate: '2026-11-14',
      );

      await WidgetSyncService.instance.syncHydration(hydration);

      expect(methodCalls.length, 1);
      final call = methodCalls.first;
      expect(call.method, 'updateHydration');
      final args = call.arguments as Map<dynamic, dynamic>;
      expect(args['glassesConsumed'], 8);
      expect(args['dailyGoalGlasses'], 8);
      expect(args['currentMilliliters'], 2000);
      expect(args['targetMilliliters'], 2000);
      expect(args['isGoalMet'], isTrue);
      expect(args['mascotPose'], 'seren_refreshed');
    });

    test(
        'HydrationProvider reloads background widget +1 writes via reloadFromStorage and onHydrationUpdatedFromWidget',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async => true,
      );

      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final notif = NotificationService();
      final provider = HydrationProvider(storage, notif);
      WidgetSyncService.instance.initialize();

      expect(provider.glassesConsumed, 0);

      // Simulate native HydrationWidgetProvider writing +1 glass directly to FlutterSharedPreferences
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final prefs = await SharedPreferences.getInstance();
      final externalData = HydrationData(
        glassesConsumed: 8,
        dailyGoalGlasses: 8,
        lastLoggedDate: today,
        dailyHistory: {today: 8},
      );
      await prefs.setString(
        'nestin_hydration_data_v1',
        jsonEncode(externalData.toJson()),
      );

      methodCalls.clear();

      // Simulate native calling onHydrationUpdatedFromWidget while engine is alive
      final binaryMessenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const codec = StandardMethodCodec();
      final ByteData data = codec.encodeMethodCall(
        const MethodCall('onHydrationUpdatedFromWidget', null),
      );
      await binaryMessenger.handlePlatformMessage(
        'com.nestin.app/widgets',
        data,
        (ByteData? reply) {},
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(provider.glassesConsumed, 8);
      expect(provider.isGoalMet, isTrue);
      expect(
        methodCalls.any((c) => c.method == 'updateHydration'),
        isTrue,
      );

      provider.dispose();
    });
  });
}

