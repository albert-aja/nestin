import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/data/services/device_control_service.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/audio_service.dart';
import 'package:nestin/providers/device_control_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/providers/timer_provider.dart';
import 'package:nestin/ui/screens/discipline/digital_discipline_screen.dart';
import 'package:nestin/ui/screens/timers/timers_screen.dart';

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

  testWidgets('TimersScreen renders Pomodoro tab and Custom Timers tab',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storageService = StorageService(prefs);
    final notificationService = NotificationService();
    final audioService = AudioService();
    final timerProvider = TimerProvider(
      storageService,
      notificationService,
      audioService,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<TimerProvider>.value(
          value: timerProvider,
          child: const TimersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Tab Bar items
    expect(find.text('Pomodoro Focus'), findsOneWidget);
    expect(find.text('Custom Timers'), findsOneWidget);

    // Verify Pomodoro View initial state
    expect(find.text('WORK FOCUS'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('START FOCUS'), findsOneWidget);
    expect(find.text('Ambient White Noise'), findsOneWidget);
    expect(find.text('Gentle Rain'), findsOneWidget);
    expect(find.text('Quiet Café Ambience'), findsOneWidget);
    expect(find.text('Forest Ambience'), findsOneWidget);

    // Switch to Custom Timers Tab
    await tester.tap(find.text('Custom Timers'));
    await tester.pumpAndSettle();

    // Verify Custom Timers view
    expect(find.text('Quick Presets'), findsOneWidget);
    expect(find.text('1m Tea'), findsOneWidget);
    expect(find.text('25m Sprint'), findsOneWidget);
    expect(find.text('Active Timers'), findsOneWidget);

    timerProvider.dispose();
  });

  testWidgets('PomodoroView displays Roo Focus Lock strip and opens DigitalDisciplineScreen Focus Lock tab',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storageService = StorageService(prefs);
    final notificationService = NotificationService();
    final audioService = AudioService();
    final timerProvider = TimerProvider(
      storageService,
      notificationService,
      audioService,
    );
    final settingsProvider = SettingsProvider(storageService);
    final dcProvider = DeviceControlProvider(
      storageService,
      service: MockDeviceControlService(),
      notifications: notificationService,
      autoRefresh: false,
    );
    await dcProvider.refreshAll();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ChangeNotifierProvider<TimerProvider>.value(value: timerProvider),
          ChangeNotifierProvider<DeviceControlProvider>.value(value: dcProvider),
        ],
        child: const MaterialApp(
          home: TimersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Roo Focus Lock'), findsOneWidget);

    await tester.ensureVisible(find.textContaining('Roo Focus Lock'));
    await tester.tap(find.textContaining('Roo Focus Lock'));
    await tester.pumpAndSettle();

    expect(find.byType(DigitalDisciplineScreen), findsOneWidget);
    expect(find.text('Focus Lock & Roo Pomodoro Sync'), findsOneWidget);

    dcProvider.dispose();
    timerProvider.dispose();
  });
}
