import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/data/models/oem_hardening_data.dart';
import 'package:nestin/data/services/oem_hardening_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/oem_hardening_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OemHardening Data Model Tests', () {
    test('Correctly resolves brands from manufacturer strings', () {
      expect(OemHardeningStatus.resolveBrand('Xiaomi'), equals(OemBrand.xiaomi));
      expect(OemHardeningStatus.resolveBrand('redmi'), equals(OemBrand.xiaomi));
      expect(OemHardeningStatus.resolveBrand('POCO'), equals(OemBrand.xiaomi));
      expect(OemHardeningStatus.resolveBrand('samsung'), equals(OemBrand.samsung));
      expect(OemHardeningStatus.resolveBrand('HUAWEI'), equals(OemBrand.huawei));
      expect(OemHardeningStatus.resolveBrand('HONOR'), equals(OemBrand.huawei));
      expect(OemHardeningStatus.resolveBrand('OPPO'), equals(OemBrand.oppo));
      expect(OemHardeningStatus.resolveBrand('realme'), equals(OemBrand.oppo));
      expect(OemHardeningStatus.resolveBrand('vivo'), equals(OemBrand.vivo));
      expect(OemHardeningStatus.resolveBrand('OnePlus'), equals(OemBrand.oneplus));
      expect(OemHardeningStatus.resolveBrand('Google'), equals(OemBrand.stock));
      expect(OemHardeningStatus.resolveBrand('motorola'), equals(OemBrand.stock));
      expect(OemHardeningStatus.resolveBrand('Apple'), equals(OemBrand.apple));
      expect(OemHardeningStatus.resolveBrand('UnknownBrand'), equals(OemBrand.other));
    });

    test('Correctly computes risk levels for aggressive vs standard OEMs', () {
      // Xiaomi unwhitelisted -> Critical
      expect(
        OemHardeningStatus.calculateRiskLevel(
          brand: OemBrand.xiaomi,
          isIgnoringBattery: false,
          isKeepAliveActive: false,
        ),
        equals(OemRiskLevel.critical),
      );

      // Samsung unwhitelisted -> Critical
      expect(
        OemHardeningStatus.calculateRiskLevel(
          brand: OemBrand.samsung,
          isIgnoringBattery: false,
          isKeepAliveActive: false,
        ),
        equals(OemRiskLevel.critical),
      );

      // Huawei unwhitelisted -> Critical
      expect(
        OemHardeningStatus.calculateRiskLevel(
          brand: OemBrand.huawei,
          isIgnoringBattery: false,
          isKeepAliveActive: false,
        ),
        equals(OemRiskLevel.critical),
      );

      // Oppo unwhitelisted -> High
      expect(
        OemHardeningStatus.calculateRiskLevel(
          brand: OemBrand.oppo,
          isIgnoringBattery: false,
          isKeepAliveActive: false,
        ),
        equals(OemRiskLevel.high),
      );

      // Stock unwhitelisted -> Moderate
      expect(
        OemHardeningStatus.calculateRiskLevel(
          brand: OemBrand.stock,
          isIgnoringBattery: false,
          isKeepAliveActive: false,
        ),
        equals(OemRiskLevel.moderate),
      );

      // Protected (Both Whitelisted & Keep-Alive active) -> Low
      expect(
        OemHardeningStatus.calculateRiskLevel(
          brand: OemBrand.xiaomi,
          isIgnoringBattery: true,
          isKeepAliveActive: true,
        ),
        equals(OemRiskLevel.low),
      );

      // Apple is always low
      expect(
        OemHardeningStatus.calculateRiskLevel(
          brand: OemBrand.apple,
          isIgnoringBattery: false,
          isKeepAliveActive: false,
        ),
        equals(OemRiskLevel.low),
      );
    });

    test('Generates brand-specific guidance steps', () {
      const xiaomiStatus = OemHardeningStatus(
        manufacturer: 'Xiaomi',
        brand: 'POCO',
        model: 'F4',
        sdkInt: 34,
        isIgnoringBatteryOptimizations: false,
        isKeepAliveServiceRunning: false,
        isAggressiveOem: true,
        oemBrand: OemBrand.xiaomi,
        riskLevel: OemRiskLevel.critical,
      );

      final steps = xiaomiStatus.guidanceSteps;
      expect(steps.length, equals(3));
      expect(steps[0].title, contains('Battery Saver'));
      expect(steps[1].title, contains('Autostart'));
      expect(steps[2].title, contains('Keep-Alive'));
    });

    test('JSON serialization roundtrip preserves all values', () {
      const status = OemHardeningStatus(
        manufacturer: 'Samsung',
        brand: 'Galaxy',
        model: 'S24 Ultra',
        sdkInt: 34,
        isIgnoringBatteryOptimizations: true,
        isKeepAliveServiceRunning: true,
        isAggressiveOem: true,
        oemBrand: OemBrand.samsung,
        riskLevel: OemRiskLevel.low,
      );

      final json = status.toJson();
      final restored = OemHardeningStatus.fromJson(json);

      expect(restored.manufacturer, equals('Samsung'));
      expect(restored.brand, equals('Galaxy'));
      expect(restored.model, equals('S24 Ultra'));
      expect(restored.isIgnoringBatteryOptimizations, isTrue);
      expect(restored.isKeepAliveServiceRunning, isTrue);
      expect(restored.oemBrand, equals(OemBrand.samsung));
      expect(restored.riskLevel, equals(OemRiskLevel.low));
    });

    test('OemHardeningConfig serialization roundtrip', () {
      final config = OemHardeningConfig(
        keepAliveEnabledByUser: true,
        bannerDismissed: true,
        lastChecked: DateTime(2026, 11, 13, 21, 0),
      );

      final json = config.toJson();
      final restored = OemHardeningConfig.fromJson(json);

      expect(restored.keepAliveEnabledByUser, isTrue);
      expect(restored.bannerDismissed, isTrue);
      expect(restored.lastChecked?.year, equals(2026));
    });
  });

  group('OemHardeningProvider & Persistence Tests', () {
    late SharedPreferences prefs;
    late StorageService storageService;
    late MockOemHardeningService mockService;
    late OemHardeningProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
      mockService = MockOemHardeningService(
        manufacturer: 'Xiaomi',
        brand: 'Redmi',
        model: 'Note 13',
        isIgnoringBatteryOptimizations: false,
        isKeepAliveRunning: false,
      );
      provider = OemHardeningProvider(storageService, mockService);
      // Wait for provider async init to finish
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });

    test('Initializes with aggressive OEM status and displays warning banner', () {
      expect(provider.status.oemBrand, equals(OemBrand.xiaomi));
      expect(provider.status.isAggressiveOem, isTrue);
      expect(provider.status.isIgnoringBatteryOptimizations, isFalse);
      expect(provider.isProtected, isFalse);
      expect(provider.shouldShowWarningBanner, isTrue);
    });

    test('Requesting ignore battery optimizations updates status to protected', () async {
      final success = await provider.requestDisableBatteryOptimization();
      expect(success, isTrue);
      expect(mockService.requestIgnoreCalled, isTrue);
      expect(provider.status.isIgnoringBatteryOptimizations, isTrue);
      expect(provider.isProtected, isTrue);
      expect(provider.shouldShowWarningBanner, isFalse);
    });

    test('Toggling keep-alive service persists config and calls service methods', () async {
      expect(provider.config.keepAliveEnabledByUser, isFalse);
      expect(mockService.isKeepAliveRunning, isFalse);

      await provider.toggleKeepAliveService(true);

      expect(provider.config.keepAliveEnabledByUser, isTrue);
      expect(mockService.startKeepAliveCalled, isTrue);
      expect(provider.status.isKeepAliveServiceRunning, isTrue);
      expect(provider.isKeepAliveActive, isTrue);
      expect(provider.isProtected, isTrue);

      // Verify persistence in storage
      final reloadedConfig = storageService.loadOemHardeningConfig();
      expect(reloadedConfig.keepAliveEnabledByUser, isTrue);

      // Toggle off
      await provider.toggleKeepAliveService(false);
      expect(provider.config.keepAliveEnabledByUser, isFalse);
      expect(mockService.stopKeepAliveCalled, isTrue);
      expect(provider.status.isKeepAliveServiceRunning, isFalse);
    });

    test('Dismissing warning banner persists preference and hides banner', () async {
      expect(provider.shouldShowWarningBanner, isTrue);

      await provider.dismissWarningBanner();

      expect(provider.config.bannerDismissed, isTrue);
      expect(provider.shouldShowWarningBanner, isFalse);

      // Reloading from storage retains dismissal
      final reloaded = storageService.loadOemHardeningConfig();
      expect(reloaded.bannerDismissed, isTrue);
    });

    test('Full JSON backup and restore includes OEM hardening configuration', () async {
      await provider.toggleKeepAliveService(true);
      await provider.dismissWarningBanner();

      final backupJson = storageService.exportFullBackupJson();
      expect(backupJson, contains('oemHardeningConfig'));
      expect(backupJson, contains('"keepAliveEnabledByUser":true'));
      expect(backupJson, contains('"bannerDismissed":true'));

      // Clear prefs and restore
      await prefs.clear();
      final restoreSuccess = await storageService.restoreFullBackupJson(backupJson);
      expect(restoreSuccess, isTrue);

      final restoredConfig = storageService.loadOemHardeningConfig();
      expect(restoredConfig.keepAliveEnabledByUser, isTrue);
      expect(restoredConfig.bannerDismissed, isTrue);
    });
  });
}

