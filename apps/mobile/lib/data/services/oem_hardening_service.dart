import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/oem_hardening_data.dart';

abstract class OemHardeningServiceInterface {
  Future<OemHardeningStatus> getStatus();
  Future<bool> requestIgnoreBatteryOptimization();
  Future<bool> openOemAutostartSettings();
  Future<bool> openBatterySettings();
  Future<bool> startKeepAliveService();
  Future<bool> stopKeepAliveService();
  Future<QuickSettingsTileStatus> getQuickSettingsTileStatus();
  Future<String> requestAddQuickSettingsTile();
  void setOnKeepAliveChangedHandler(void Function(bool enabled)? handler);
}

class OemHardeningService implements OemHardeningServiceInterface {
  static const MethodChannel _channel =
      MethodChannel('com.nestin.app/oem_hardening');

  void Function(bool enabled)? _onKeepAliveChanged;

  OemHardeningService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onKeepAliveStateChanged') {
        final enabled = call.arguments as bool? ?? false;
        _onKeepAliveChanged?.call(enabled);
      }
    });
  }

  @override
  void setOnKeepAliveChangedHandler(void Function(bool enabled)? handler) {
    _onKeepAliveChanged = handler;
  }

  @override
  Future<OemHardeningStatus> getStatus() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getDeviceOemInfo');
        if (result != null) {
          return OemHardeningStatus.fromPlatformMap(result);
        }
      } else if (!kIsWeb && Platform.isIOS) {
        return const OemHardeningStatus(
          manufacturer: 'Apple',
          brand: 'Apple',
          model: 'iPhone',
          sdkInt: 18,
          isIgnoringBatteryOptimizations: true,
          isKeepAliveServiceRunning: false,
          isAggressiveOem: false,
          oemBrand: OemBrand.apple,
          riskLevel: OemRiskLevel.low,
        );
      }
    } catch (e) {
      debugPrint('OemHardeningService getStatus error: $e');
    }
    return OemHardeningStatus.defaultSafe();
  }

  @override
  Future<bool> requestIgnoreBatteryOptimization() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final res = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
        return res ?? false;
      }
    } catch (e) {
      debugPrint('OemHardeningService requestIgnoreBatteryOptimization error: $e');
    }
    return false;
  }

  @override
  Future<bool> openOemAutostartSettings() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final res = await _channel.invokeMethod<bool>('openOemAutostartSettings');
        return res ?? false;
      }
    } catch (e) {
      debugPrint('OemHardeningService openOemAutostartSettings error: $e');
    }
    return false;
  }

  @override
  Future<bool> openBatterySettings() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final res = await _channel.invokeMethod<bool>('openBatterySettings');
        return res ?? false;
      }
    } catch (e) {
      debugPrint('OemHardeningService openBatterySettings error: $e');
    }
    return false;
  }

  @override
  Future<bool> startKeepAliveService() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final res = await _channel.invokeMethod<bool>('startKeepAliveService');
        return res ?? false;
      }
    } catch (e) {
      debugPrint('OemHardeningService startKeepAliveService error: $e');
    }
    return false;
  }

  @override
  Future<bool> stopKeepAliveService() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final res = await _channel.invokeMethod<bool>('stopKeepAliveService');
        return res ?? false;
      }
    } catch (e) {
      debugPrint('OemHardeningService stopKeepAliveService error: $e');
    }
    return false;
  }

  @override
  Future<QuickSettingsTileStatus> getQuickSettingsTileStatus() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final res = await _channel
            .invokeMethod<Map<dynamic, dynamic>>('getQuickSettingsTileStatus');
        if (res != null) {
          return QuickSettingsTileStatus.fromPlatformMap(res);
        }
      }
    } catch (e) {
      debugPrint('OemHardeningService getQuickSettingsTileStatus error: $e');
    }
    return const QuickSettingsTileStatus.unsupported();
  }

  @override
  Future<String> requestAddQuickSettingsTile() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final res =
            await _channel.invokeMethod<String>('requestAddQuickSettingsTile');
        return res ?? 'unsupported';
      }
    } catch (e) {
      debugPrint('OemHardeningService requestAddQuickSettingsTile error: $e');
    }
    return 'unsupported';
  }
}

class MockOemHardeningService implements OemHardeningServiceInterface {
  String manufacturer;
  String brand;
  String model;
  int sdkInt;
  bool isIgnoringBatteryOptimizations;
  bool isKeepAliveRunning;
  bool qsSupported;
  bool qsCanRequestAdd;
  bool qsTileAdded;

  bool requestIgnoreCalled = false;
  bool openAutostartCalled = false;
  bool openBatterySettingsCalled = false;
  bool startKeepAliveCalled = false;
  bool stopKeepAliveCalled = false;
  bool requestAddTileCalled = false;
  void Function(bool enabled)? _onKeepAliveChanged;

  MockOemHardeningService({
    this.manufacturer = 'Xiaomi',
    this.brand = 'POCO',
    this.model = 'F3',
    this.sdkInt = 34,
    this.isIgnoringBatteryOptimizations = false,
    this.isKeepAliveRunning = false,
    this.qsSupported = true,
    this.qsCanRequestAdd = true,
    this.qsTileAdded = false,
  });

  @override
  void setOnKeepAliveChangedHandler(void Function(bool enabled)? handler) {
    _onKeepAliveChanged = handler;
  }

  /// Simulates the user tapping Nestin Guard inside Android Quick Settings.
  void simulateNativeTileToggle(bool enabled) {
    isKeepAliveRunning = enabled;
    _onKeepAliveChanged?.call(enabled);
  }

  @override
  Future<QuickSettingsTileStatus> getQuickSettingsTileStatus() async {
    return QuickSettingsTileStatus(
      supported: qsSupported,
      canRequestAdd: qsCanRequestAdd,
      isTileAdded: qsTileAdded,
    );
  }

  @override
  Future<String> requestAddQuickSettingsTile() async {
    requestAddTileCalled = true;
    if (!qsSupported || !qsCanRequestAdd) return 'unsupported';
    if (qsTileAdded) return 'already_added';
    qsTileAdded = true;
    return 'added';
  }

  @override
  Future<OemHardeningStatus> getStatus() async {
    final oemBrand = OemHardeningStatus.resolveBrand(manufacturer);
    final isAggressive = OemHardeningStatus.isBrandAggressive(oemBrand);
    final risk = OemHardeningStatus.calculateRiskLevel(
      brand: oemBrand,
      isIgnoringBattery: isIgnoringBatteryOptimizations,
      isKeepAliveActive: isKeepAliveRunning,
    );

    return OemHardeningStatus(
      manufacturer: manufacturer,
      brand: brand,
      model: model,
      sdkInt: sdkInt,
      isIgnoringBatteryOptimizations: isIgnoringBatteryOptimizations,
      isKeepAliveServiceRunning: isKeepAliveRunning,
      isAggressiveOem: isAggressive,
      oemBrand: oemBrand,
      riskLevel: risk,
    );
  }

  @override
  Future<bool> requestIgnoreBatteryOptimization() async {
    requestIgnoreCalled = true;
    isIgnoringBatteryOptimizations = true;
    return true;
  }

  @override
  Future<bool> openOemAutostartSettings() async {
    openAutostartCalled = true;
    return true;
  }

  @override
  Future<bool> openBatterySettings() async {
    openBatterySettingsCalled = true;
    return true;
  }

  @override
  Future<bool> startKeepAliveService() async {
    startKeepAliveCalled = true;
    isKeepAliveRunning = true;
    return true;
  }

  @override
  Future<bool> stopKeepAliveService() async {
    stopKeepAliveCalled = true;
    isKeepAliveRunning = false;
    return true;
  }
}

