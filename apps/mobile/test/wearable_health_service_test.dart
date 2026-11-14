import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/data/models/wearable_source.dart';
import 'package:nestin/data/models/wearable_config.dart';
import 'package:nestin/data/models/wearable_sync_record.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/data/services/wearable_health_service.dart';
import 'package:nestin/providers/wearable_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Wearable Domain Models Tests', () {
    test('WearablePlatform extension properties return correct strings', () {
      expect(WearablePlatform.appleHealth.displayName, contains('Apple Health'));
      expect(WearablePlatform.appleHealth.shortName, 'Apple Health');
      expect(WearablePlatform.googleFit.shortName, 'Google Fit');
      expect(WearablePlatform.healthConnect.shortName, 'Health Connect');
      expect(WearablePlatform.simulated.shortName, 'Sandbox Simulator');
    });

    test('WearableSyncRecord formats duration and sleep cycles correctly', () {
      final record = WearableSyncRecord(
        platform: WearablePlatform.appleHealth,
        syncedAt: DateTime(2026, 11, 12, 8, 30),
        sleepMinutes: 450, // 7.5 hours = 5 cycles of 90 minutes
        stepCount: 8500,
        restingHeartRate: 60,
        waterIntakeMl: 1500,
      );

      expect(record.sleepDurationFormatted, '7h 30m');
      expect(record.sleepCyclesCount, 5);
      expect(record.isSyncSuccess, isTrue);

      final json = record.toJson();
      final restored = WearableSyncRecord.fromJson(json);

      expect(restored.platform, WearablePlatform.appleHealth);
      expect(restored.sleepMinutes, 450);
      expect(restored.stepCount, 8500);
      expect(restored.restingHeartRate, 60);
      expect(restored.waterIntakeMl, 1500);
      expect(restored.sleepCyclesCount, 5);
    });

    test('WearableConfig serialization and copyWith work as expected', () {
      const config = WearableConfig(
        isConnected: false,
        selectedPlatform: WearablePlatform.simulated,
        autoSyncOnLaunch: true,
        syncSleep: true,
        syncHydration: true,
        syncSteps: true,
        syncHeartRate: true,
      );

      final updated = config.copyWith(
        isConnected: true,
        selectedPlatform: WearablePlatform.googleFit,
        autoSyncOnLaunch: false,
      );

      expect(updated.isConnected, isTrue);
      expect(updated.selectedPlatform, WearablePlatform.googleFit);
      expect(updated.autoSyncOnLaunch, isFalse);
      expect(updated.syncSleep, isTrue);

      final json = updated.toJson();
      final fromJson = WearableConfig.fromJson(json);

      expect(fromJson.isConnected, isTrue);
      expect(fromJson.selectedPlatform, WearablePlatform.googleFit);
      expect(fromJson.autoSyncOnLaunch, isFalse);
    });
  });

  group('LocalWearableHealthService Tests', () {
    final service = const LocalWearableHealthService(forceSimulation: true);

    test('Checks platform availability successfully', () async {
      final apple = await service.isPlatformAvailable(WearablePlatform.appleHealth);
      final google = await service.isPlatformAvailable(WearablePlatform.googleFit);
      final healthConnect = await service.isPlatformAvailable(WearablePlatform.healthConnect);
      final sim = await service.isPlatformAvailable(WearablePlatform.simulated);

      expect(apple, isTrue);
      expect(google, isTrue);
      expect(healthConnect, isTrue);
      expect(sim, isTrue);
    });

    test('Requests permissions and grants all types in simulation', () async {
      final granted = await service.requestPermissions(
        WearablePlatform.appleHealth,
        {
          WearablePermissionType.sleep,
          WearablePermissionType.hydration,
          WearablePermissionType.steps,
          WearablePermissionType.heartRate,
        },
      );
      expect(granted, isTrue);
    });

    test('Fetches latest health metrics with 90m REM cycle alignment', () async {
      final record = await service.fetchLatestHealthMetrics(
        WearablePlatform.appleHealth,
        {
          WearablePermissionType.sleep,
          WearablePermissionType.hydration,
          WearablePermissionType.steps,
          WearablePermissionType.heartRate,
        },
      );

      expect(record.platform, WearablePlatform.appleHealth);
      expect(record.sleepMinutes, 450); // 5 cycles of 90m
      expect(record.sleepCyclesCount, 5);
      expect(record.stepCount, 6420);
      expect(record.restingHeartRate, 62);
      expect(record.waterIntakeMl, 1250);
      expect(record.isSyncSuccess, isTrue);
    });

    test('Writes hydration data to health platform', () async {
      final success = await service.writeHydrationData(
        WearablePlatform.healthConnect,
        1500,
        DateTime.now(),
      );
      expect(success, isTrue);
    });
  });

  group('WearableProvider & StorageService Integration Tests', () {
    late StorageService storage;
    late WearableProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await StorageService.init();
      provider = WearableProvider(
        storage,
        healthService: const LocalWearableHealthService(forceSimulation: true),
      );
    });

    test('Initial provider state is disconnected with default config', () {
      expect(provider.isConnected, isFalse);
      expect(provider.config.selectedPlatform, WearablePlatform.simulated);
      expect(provider.latestRecord, isNull);
    });

    test('Connects to platform, persists config, and runs immediate sync', () async {
      final success = await provider.connect(WearablePlatform.appleHealth);

      expect(success, isTrue);
      expect(provider.isConnected, isTrue);
      expect(provider.config.selectedPlatform, WearablePlatform.appleHealth);
      expect(provider.latestRecord, isNotNull);
      expect(provider.latestRecord!.platform, WearablePlatform.appleHealth);
      expect(provider.latestRecord!.sleepCyclesCount, 5);

      // Verify persisted in storage
      final loadedConfig = storage.loadWearableConfig();
      expect(loadedConfig.isConnected, isTrue);
      expect(loadedConfig.selectedPlatform, WearablePlatform.appleHealth);

      final loadedSync = storage.loadLatestWearableSync();
      expect(loadedSync, isNotNull);
      expect(loadedSync!.platform, WearablePlatform.appleHealth);
    });

    test('Disconnect resets connected status and saves to storage', () async {
      await provider.connect(WearablePlatform.googleFit);
      expect(provider.isConnected, isTrue);

      await provider.disconnect();
      expect(provider.isConnected, isFalse);

      final loadedConfig = storage.loadWearableConfig();
      expect(loadedConfig.isConnected, isFalse);
    });

    test('Update config changes granular permission toggles', () async {
      await provider.updateConfig(
        provider.config.copyWith(
          syncHeartRate: false,
          autoSyncOnLaunch: false,
        ),
      );

      expect(provider.config.syncHeartRate, isFalse);
      expect(provider.config.autoSyncOnLaunch, isFalse);

      final loadedConfig = storage.loadWearableConfig();
      expect(loadedConfig.syncHeartRate, isFalse);
      expect(loadedConfig.autoSyncOnLaunch, isFalse);
    });

    test('Bidirectional hydration sync updates record and storage', () async {
      await provider.connect(WearablePlatform.healthConnect);
      expect(provider.latestRecord, isNotNull);

      final result = await provider.syncHydrationToWearable(1750);
      expect(result, isTrue);
      expect(provider.latestRecord!.waterIntakeMl, 1750);

      final loadedSync = storage.loadLatestWearableSync();
      expect(loadedSync!.waterIntakeMl, 1750);
    });

    test('Full JSON backup exports and restores wearable config and sync state', () async {
      await provider.connect(WearablePlatform.appleHealth);
      await provider.syncHydrationToWearable(2000);

      final backupJson = storage.exportFullBackupJson();
      expect(backupJson, contains('wearableConfig'));
      expect(backupJson, contains('latestWearableSync'));
      expect(backupJson, contains('appleHealth'));

      // Clear preferences and restore
      SharedPreferences.setMockInitialValues({});
      final newStorage = await StorageService.init();
      expect(newStorage.loadWearableConfig().isConnected, isFalse);
      expect(newStorage.loadLatestWearableSync(), isNull);

      final restoredOk = await newStorage.restoreFullBackupJson(backupJson);
      expect(restoredOk, isTrue);

      final restoredConfig = newStorage.loadWearableConfig();
      expect(restoredConfig.isConnected, isTrue);
      expect(restoredConfig.selectedPlatform, WearablePlatform.appleHealth);

      final restoredSync = newStorage.loadLatestWearableSync();
      expect(restoredSync, isNotNull);
      expect(restoredSync!.waterIntakeMl, 2000);
    });
  });
}
