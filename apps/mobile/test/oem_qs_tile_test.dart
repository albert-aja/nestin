import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/data/models/oem_hardening_data.dart';
import 'package:nestin/data/services/oem_hardening_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/oem_hardening_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/providers/sound_provider.dart';
import 'package:nestin/providers/wearable_provider.dart';
import 'package:nestin/ui/screens/settings/settings_screen.dart';
import 'package:nestin/ui/widgets/oem_hardening_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OEM Quick Settings Tile Provider & Sync', () {
    late StorageService storageService;
    late MockOemHardeningService mockService;
    late OemHardeningProvider oemProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
      mockService = MockOemHardeningService(
        manufacturer: 'Xiaomi',
        brand: 'POCO',
        model: 'F4 GT',
        isIgnoringBatteryOptimizations: false,
        isKeepAliveRunning: false,
        qsSupported: true,
        qsCanRequestAdd: true,
        qsTileAdded: false,
      );
      oemProvider = OemHardeningProvider(storageService, mockService);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    tearDown(() {
      oemProvider.dispose();
    });

    test('reads QS tile capabilities and pins tile cleanly', () async {
      expect(oemProvider.quickSettingsTileStatus.supported, isTrue);
      expect(oemProvider.quickSettingsTileStatus.canRequestAdd, isTrue);
      expect(oemProvider.quickSettingsTileStatus.isTileAdded, isFalse);

      final outcome = await oemProvider.pinQuickSettingsTile();
      expect(outcome, 'added');
      expect(mockService.requestAddTileCalled, isTrue);
      expect(oemProvider.quickSettingsTileStatus.isTileAdded, isTrue);

      final second = await oemProvider.pinQuickSettingsTile();
      expect(second, 'already_added');
    });

    test('native QS tile toggle syncs provider state, protection, risk level, and storage',
        () async {
      expect(oemProvider.isKeepAliveActive, isFalse);
      expect(oemProvider.isProtected, isFalse);
      expect(oemProvider.status.riskLevel, OemRiskLevel.critical);

      mockService.simulateNativeTileToggle(true);
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(oemProvider.isKeepAliveActive, isTrue);
      expect(oemProvider.isProtected, isTrue);
      expect(oemProvider.config.keepAliveEnabledByUser, isTrue);
      expect(
        storageService.loadOemHardeningConfig().keepAliveEnabledByUser,
        isTrue,
      );

      // When battery optimization is already ignored, Keep-Alive shifts risk moderate -> low
      mockService.isIgnoringBatteryOptimizations = true;
      await oemProvider.refreshStatus();
      expect(oemProvider.status.riskLevel, OemRiskLevel.low);

      mockService.simulateNativeTileToggle(false);
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(oemProvider.isKeepAliveActive, isFalse);
      expect(oemProvider.config.keepAliveEnabledByUser, isFalse);
      expect(oemProvider.status.riskLevel, OemRiskLevel.moderate);
    });
  });

  group('OEM Quick Settings Tile UI Integration', () {
    late StorageService storageService;
    late MockOemHardeningService mockService;
    late OemHardeningProvider oemProvider;
    late SettingsProvider settingsProvider;
    late SoundProvider soundProvider;
    late WearableProvider wearableProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
      mockService = MockOemHardeningService(
        manufacturer: 'Samsung',
        brand: 'Samsung',
        model: 'Galaxy S24',
        isIgnoringBatteryOptimizations: false,
        isKeepAliveRunning: false,
        qsSupported: true,
        qsCanRequestAdd: true,
        qsTileAdded: false,
      );
      oemProvider = OemHardeningProvider(storageService, mockService);
      settingsProvider = SettingsProvider(storageService);
      soundProvider = SoundProvider(storageService);
      wearableProvider = WearableProvider(storageService);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    tearDown(() {
      oemProvider.dispose();
    });

    Widget wrap(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<OemHardeningProvider>.value(
            value: oemProvider,
          ),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: settingsProvider,
          ),
          ChangeNotifierProvider<SoundProvider>.value(value: soundProvider),
          ChangeNotifierProvider<WearableProvider>.value(
            value: wearableProvider,
          ),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      );
    }

    testWidgets(
        'SettingsScreen renders Pin Tile button and marks tile Added after pinning',
        (tester) async {
      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      final listFinder = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Pin Tile'),
        300,
        scrollable: listFinder,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Quick Settings Tile ("Nestin Guard")'),
        findsOneWidget,
      );
      await tester.tap(find.text('Pin Tile'));
      await tester.pumpAndSettle();

      expect(find.text('Added'), findsOneWidget);
      expect(
        find.text('Nestin Guard tile ready in Quick Settings.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'OemHardeningSheet supports Pin Quick Settings Tile and live native sync',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => OemHardeningSheet.show(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final pinBtn = find.text('Pin Quick Settings Tile');
      await tester.ensureVisible(pinBtn);
      await tester.tap(pinBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('Quick Settings tile "Nestin Guard" is active in shade.'),
        findsOneWidget,
      );

      // Simulate user toggling QS tile in Android shade while sheet is open
      mockService.simulateNativeTileToggle(true);
      await tester.pumpAndSettle();
      expect(find.text('100% Protected Against Sleep Kill'), findsOneWidget);
    });
  });
}
