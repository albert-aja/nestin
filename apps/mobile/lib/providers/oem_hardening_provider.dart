import 'package:flutter/foundation.dart';
import '../data/models/oem_hardening_data.dart';
import '../data/services/oem_hardening_service.dart';
import '../data/services/storage_service.dart';

class OemHardeningProvider extends ChangeNotifier {
  final StorageService _storageService;
  final OemHardeningServiceInterface _service;

  OemHardeningStatus _status = OemHardeningStatus.defaultSafe();
  OemHardeningConfig _config = const OemHardeningConfig();
  bool _isLoading = false;

  OemHardeningProvider(this._storageService, this._service) {
    _init();
  }

  OemHardeningStatus get status => _status;
  OemHardeningConfig get config => _config;
  bool get isLoading => _isLoading;

  bool get isKeepAliveActive =>
      _status.isKeepAliveServiceRunning || _config.keepAliveEnabledByUser;

  bool get isProtected =>
      _status.isIgnoringBatteryOptimizations || _config.keepAliveEnabledByUser;

  bool get shouldShowWarningBanner {
    if (_config.bannerDismissed) return false;
    if (!_status.isAggressiveOem) return false;
    return !_status.isIgnoringBatteryOptimizations &&
        !_config.keepAliveEnabledByUser;
  }

  Future<void> _init() async {
    _config = _storageService.loadOemHardeningConfig();
    await refreshStatus();

    // Auto-restore keep-alive foreground service if user enabled it previously
    if (_config.keepAliveEnabledByUser &&
        !_status.isKeepAliveServiceRunning) {
      await _service.startKeepAliveService();
      _status = _status.copyWith(isKeepAliveServiceRunning: true);
      notifyListeners();
    }
  }

  Future<void> refreshStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final fetchedStatus = await _service.getStatus();
      final effectiveKeepAlive = fetchedStatus.isKeepAliveServiceRunning ||
          _config.keepAliveEnabledByUser;

      final recalculatedRisk = OemHardeningStatus.calculateRiskLevel(
        brand: fetchedStatus.oemBrand,
        isIgnoringBattery: fetchedStatus.isIgnoringBatteryOptimizations,
        isKeepAliveActive: effectiveKeepAlive,
      );

      _status = fetchedStatus.copyWith(
        isKeepAliveServiceRunning: effectiveKeepAlive,
        riskLevel: recalculatedRisk,
      );
    } catch (e) {
      debugPrint('Error refreshing OEM hardening status: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> requestDisableBatteryOptimization() async {
    final success = await _service.requestIgnoreBatteryOptimization();
    await refreshStatus();
    return success;
  }

  Future<bool> openAutostartSettings() async {
    return await _service.openOemAutostartSettings();
  }

  Future<bool> openBatterySettings() async {
    return await _service.openBatterySettings();
  }

  Future<void> toggleKeepAliveService(bool enabled) async {
    _config = _config.copyWith(
      keepAliveEnabledByUser: enabled,
      lastChecked: DateTime.now(),
    );
    await _storageService.saveOemHardeningConfig(_config);

    if (enabled) {
      await _service.startKeepAliveService();
    } else {
      await _service.stopKeepAliveService();
    }

    _status = _status.copyWith(
      isKeepAliveServiceRunning: enabled,
      riskLevel: OemHardeningStatus.calculateRiskLevel(
        brand: _status.oemBrand,
        isIgnoringBattery: _status.isIgnoringBatteryOptimizations,
        isKeepAliveActive: enabled,
      ),
    );

    notifyListeners();
  }

  Future<void> dismissWarningBanner() async {
    _config = _config.copyWith(bannerDismissed: true);
    await _storageService.saveOemHardeningConfig(_config);
    notifyListeners();
  }

  Future<void> resetWarningBanner() async {
    _config = _config.copyWith(bannerDismissed: false);
    await _storageService.saveOemHardeningConfig(_config);
    notifyListeners();
  }
}

