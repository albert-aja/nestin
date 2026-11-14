import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/data/services/oem_hardening_service.dart';
import 'package:nestin/providers/oem_hardening_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/providers/sound_provider.dart';
import 'package:nestin/providers/wearable_provider.dart';
import 'package:nestin/ui/widgets/oem_hardening_sheet.dart';
import 'package:nestin/ui/widgets/oem_warning_banner.dart';
import 'package:nestin/ui/screens/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OEM Hardening Widget Tests', () {
    late SharedPreferences prefs;
    late StorageService storageService;
    late MockOemHardeningService mockService;
    late OemHardeningProvider oemProvider;
    late SettingsProvider settingsProvider;
    late SoundProvider soundProvider;
    late WearableProvider wearableProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
      mockService = MockOemHardeningService(
        manufacturer: 'Xiaomi',
        brand: 'POCO',
        model: 'F4 GT',
        isIgnoringBatteryOptimizations: false,
        isKeepAliveRunning: false,
      );
      oemProvider = OemHardeningProvider(storageService, mockService);
      settingsProvider = SettingsProvider(storageService);
      soundProvider = SoundProvider(storageService);
      wearableProvider = WearableProvider(storageService);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });

    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<OemHardeningProvider>.value(value: oemProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ChangeNotifierProvider<SoundProvider>.value(value: soundProvider),
          ChangeNotifierProvider<WearableProvider>.value(value: wearableProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: child,
          ),
        ),
      );
    }

    testWidgets('OemWarningBanner displays warning when aggressive OEM is unwhitelisted and dismisses on tap',
        (tester) async {
      await tester.pumpWidget(createTestApp(const OemWarningBanner()));
      await tester.pumpAndSettle();

      expect(find.text('Xiaomi (MIUI / HyperOS) Battery Alert'), findsOneWidget);
      expect(find.text('Protect'), findsOneWidget);

      // Tap close button to dismiss
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Xiaomi (MIUI / HyperOS) Battery Alert'), findsNothing);
    });

    testWidgets('OemHardeningSheet renders Xiaomi guidance steps, risk banner and keep-alive toggle',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => OemHardeningSheet.show(context),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify sheet header and content
      expect(find.text('Xiaomi (MIUI / HyperOS)'), findsOneWidget);
      expect(find.text('Critical Risk of Sleep Kill'), findsOneWidget);
      expect(find.text('Turn Off Battery Saver'), findsOneWidget);
      expect(find.text('Allow Autostart'), findsOneWidget);
      expect(find.text('Keep-Alive Foreground Guard'), findsOneWidget);
      expect(find.text('Xiaomi (MIUI / HyperOS) Pro-Tips'), findsOneWidget);

      // Ensure visible and tap Keep-Alive switch
      final switchWidget = find.byType(Switch);
      await tester.ensureVisible(switchWidget);
      await tester.pumpAndSettle();
      await tester.tap(switchWidget);
      await tester.pumpAndSettle();

      expect(oemProvider.isKeepAliveActive, isTrue);
      expect(mockService.startKeepAliveCalled, isTrue);
    });

    testWidgets('SettingsScreen integrates OEM Hardening card and Keep-Alive toggle',
        (tester) async {
      await tester.pumpWidget(createTestApp(const SettingsScreen()));
      await tester.pumpAndSettle();

      // Scroll down ListView until Platform & System Reliability is rendered
      for (int i = 0; i < 6; i++) {
        if (find.text('Platform & System Reliability').evaluate().isNotEmpty) {
          break;
        }
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();
      }

      expect(find.text('Platform & System Reliability'), findsOneWidget);
      expect(find.text('Xiaomi (MIUI / HyperOS)'), findsOneWidget);
      expect(find.text('Keep-Alive Foreground Guard'), findsOneWidget);
      expect(find.text('Notifications Engine'), findsOneWidget);
      expect(find.text('Exact Alarm Scheduling'), findsOneWidget);
      expect(find.text('Background WakeLock'), findsOneWidget);
    });
  });
}
