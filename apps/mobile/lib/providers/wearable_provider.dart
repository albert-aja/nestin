import 'package:flutter/foundation.dart';
import '../data/models/wearable_config.dart';
import '../data/models/wearable_source.dart';
import '../data/models/wearable_sync_record.dart';
import '../data/services/storage_service.dart';
import '../data/services/wearable_health_service.dart';

class WearableProvider extends ChangeNotifier {
  final StorageService _storageService;
  final WearableHealthServiceInterface _healthService;

  WearableConfig _config;
  WearableSyncRecord? _latestRecord;
  bool _isSyncing = false;
  String? _statusMessage;
  String? _errorMessage;

  WearableProvider(
    this._storageService, {
    WearableHealthServiceInterface? healthService,
  })  : _healthService = healthService ?? const LocalWearableHealthService(),
        _config = _storageService.loadWearableConfig(),
        _latestRecord = _storageService.loadLatestWearableSync() {
    if (_config.isConnected && _config.autoSyncOnLaunch) {
      // Background initial sync
      syncNow();
    }
  }

  WearableConfig get config => _config;
  WearableSyncRecord? get latestRecord => _latestRecord;
  bool get isConnected => _config.isConnected;
  bool get isSyncing => _isSyncing;
  String? get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;

  Set<WearablePermissionType> get _activePermissions {
    final permissions = <WearablePermissionType>{};
    if (_config.syncSleep) permissions.add(WearablePermissionType.sleep);
    if (_config.syncHydration) permissions.add(WearablePermissionType.hydration);
    if (_config.syncSteps) permissions.add(WearablePermissionType.steps);
    if (_config.syncHeartRate) permissions.add(WearablePermissionType.heartRate);
    return permissions;
  }

  Future<bool> connect(WearablePlatform platform) async {
    _isSyncing = true;
    _errorMessage = null;
    _statusMessage = 'Connecting to ${platform.shortName}...';
    notifyListeners();

    try {
      final isAvailable = await _healthService.isPlatformAvailable(platform);
      if (!isAvailable) {
        _errorMessage = '${platform.shortName} is not available on this device.';
        _isSyncing = false;
        notifyListeners();
        return false;
      }

      final granted = await _healthService.requestPermissions(
        platform,
        _activePermissions,
      );

      if (!granted) {
        _errorMessage = 'Permission denied by user.';
        _isSyncing = false;
        notifyListeners();
        return false;
      }

      _config = _config.copyWith(
        isConnected: true,
        selectedPlatform: platform,
      );
      await _storageService.saveWearableConfig(_config);

      _statusMessage = 'Connected to ${platform.shortName}';
      _isSyncing = false;
      notifyListeners();

      // Trigger immediate initial sync
      await syncNow();
      return true;
    } catch (e) {
      _errorMessage = 'Connection failed: $e';
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    _config = _config.copyWith(isConnected: false);
    await _storageService.saveWearableConfig(_config);
    _statusMessage = 'Disconnected';
    _errorMessage = null;
    notifyListeners();
  }

  Future<WearableSyncRecord?> syncNow() async {
    if (!_config.isConnected) {
      _statusMessage = 'Wearable platform not connected.';
      notifyListeners();
      return null;
    }

    _isSyncing = true;
    _errorMessage = null;
    _statusMessage = 'Synchronizing health & wellness metrics...';
    notifyListeners();

    try {
      final record = await _healthService.fetchLatestHealthMetrics(
        _config.selectedPlatform,
        _activePermissions,
      );

      _latestRecord = record;
      await _storageService.saveLatestWearableSync(record);

      _statusMessage = 'Synchronized with ${_config.selectedPlatform.shortName}';
      _isSyncing = false;
      notifyListeners();
      return record;
    } catch (e) {
      _errorMessage = 'Sync failed: $e';
      _isSyncing = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> updateConfig(WearableConfig newConfig) async {
    _config = newConfig;
    await _storageService.saveWearableConfig(_config);
    notifyListeners();
  }

  Future<bool> syncHydrationToWearable(int milliliters) async {
    if (!_config.isConnected || !_config.syncHydration) return false;

    try {
      final ok = await _healthService.writeHydrationData(
        _config.selectedPlatform,
        milliliters,
        DateTime.now(),
      );
      if (ok && _latestRecord != null) {
        _latestRecord = WearableSyncRecord(
          platform: _latestRecord!.platform,
          syncedAt: DateTime.now(),
          sleepStartTime: _latestRecord!.sleepStartTime,
          sleepEndTime: _latestRecord!.sleepEndTime,
          sleepMinutes: _latestRecord!.sleepMinutes,
          sleepQualityPercent: _latestRecord!.sleepQualityPercent,
          waterIntakeMl: milliliters,
          stepCount: _latestRecord!.stepCount,
          restingHeartRate: _latestRecord!.restingHeartRate,
          isSyncSuccess: true,
          notes: _latestRecord!.notes,
        );
        await _storageService.saveLatestWearableSync(_latestRecord!);
        notifyListeners();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }
}
