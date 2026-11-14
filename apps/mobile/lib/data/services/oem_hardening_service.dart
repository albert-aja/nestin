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
}

class OemHardeningService implements OemHardeningServiceInterface {
  static const MethodChannel _channel =
      MethodChannel('com.nestin.app/oem_hardening');

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
}

class MockOemHardeningService implements OemHardeningServiceInterface {
  String manufacturer;
  String brand;
  String model;
  int sdkInt;
  bool isIgnoringBatteryOptimizations;
  bool isKeepAliveRunning;

  bool requestIgnoreCalled = false;
  bool openAutostartCalled = false;
  bool openBatterySettingsCalled = false;
  bool startKeepAliveCalled = false;
  bool stopKeepAliveCalled = false;

  MockOemHardeningService({
    this.manufacturer = 'Xiaomi',
    this.brand = 'POCO',
    this.model = 'F3',
    this.sdkInt = 34,
    this.isIgnoringBatteryOptimizations = false,
    this.isKeepAliveRunning = false,
  });

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

