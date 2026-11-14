import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:nestin/data/models/alarm.dart';
import 'package:nestin/data/models/alarm_category.dart';
import 'package:nestin/data/models/alarm_schedule.dart';
import 'package:nestin/data/models/routine_item.dart';
import 'package:nestin/data/services/widget_sync_service.dart';

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
  });
}

