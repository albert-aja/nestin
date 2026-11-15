import 'package:flutter/widgets.dart';
import '../data/models/oem_hardening_data.dart';
import '../data/services/oem_hardening_service.dart';
import '../data/services/storage_service.dart';

class OemHardeningProvider extends ChangeNotifier with WidgetsBindingObserver {
  final StorageService _storageService;
  final OemHardeningServiceInterface _service;

  OemHardeningStatus _status = OemHardeningStatus.defaultSafe();
  OemHardeningConfig _config = const OemHardeningConfig();
  QuickSettingsTileStatus _qsTileStatus =
      const QuickSettingsTileStatus.unsupported();
  bool _isLoading = false;
  bool _disposed = false;

  OemHardeningProvider(this._storageService, this._service) {
    _service.setOnKeepAliveChangedHandler(_onNativeKeepAliveChanged);
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      // Safe when instantiated outside a WidgetsBinding in pure Dart unit tests.
    }
    _init();
  }

  OemHardeningStatus get status => _status;
  OemHardeningConfig get config => _config;
  QuickSettingsTileStatus get quickSettingsTileStatus => _qsTileStatus;
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
    if (_disposed) return;

    // Auto-restore keep-alive foreground service if user enabled it previously
    if (_config.keepAliveEnabledByUser &&
        !_status.isKeepAliveServiceRunning) {
      await _service.startKeepAliveService();
      if (_disposed) return;
      _status = _status.copyWith(isKeepAliveServiceRunning: true);
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncFromNative();
    }
  }

  /// Syncs config and service status from native OS prefs (e.g. after QS tile toggle).
  Future<void> syncFromNative() async {
    if (_disposed) return;
    await _storageService.reloadPrefs();
    _config = _storageService.loadOemHardeningConfig();
    await refreshStatus();
  }

  Future<void> _onNativeKeepAliveChanged(bool enabled) async {
    if (_disposed) return;
    _config = _config.copyWith(
      keepAliveEnabledByUser: enabled,
      lastChecked: DateTime.now(),
    );
    await _storageService.saveOemHardeningConfig(_config);
    if (_disposed) return;
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

  Future<void> refreshStatus() async {
    if (_disposed) return;
    _isLoading = true;
    notifyListeners();

    try {
      final fetchedStatus = await _service.getStatus();
      final qsStatus = await _service.getQuickSettingsTileStatus();
      if (_disposed) return;
      _qsTileStatus = qsStatus;

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
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<String> pinQuickSettingsTile() async {
    final result = await _service.requestAddQuickSettingsTile();
    if (_disposed) return result;
    if (result == 'added' || result == 'already_added') {
      _qsTileStatus = _qsTileStatus.copyWith(isTileAdded: true);
      notifyListeners();
    } else {
      _qsTileStatus = await _service.getQuickSettingsTileStatus();
      if (!_disposed) notifyListeners();
    }
    return result;
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

  @override
  void dispose() {
    _disposed = true;
    _service.setOnKeepAliveChangedHandler(null);
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    super.dispose();
  }
}

