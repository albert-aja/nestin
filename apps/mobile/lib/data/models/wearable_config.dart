import 'wearable_source.dart';

class WearableConfig {
  final bool isConnected;
  final WearablePlatform selectedPlatform;
  final bool autoSyncOnLaunch;
  final bool syncSleep;
  final bool syncHydration;
  final bool syncSteps;
  final bool syncHeartRate;

  const WearableConfig({
    this.isConnected = false,
    this.selectedPlatform = WearablePlatform.simulated,
    this.autoSyncOnLaunch = true,
    this.syncSleep = true,
    this.syncHydration = true,
    this.syncSteps = true,
    this.syncHeartRate = true,
  });

  WearableConfig copyWith({
    bool? isConnected,
    WearablePlatform? selectedPlatform,
    bool? autoSyncOnLaunch,
    bool? syncSleep,
    bool? syncHydration,
    bool? syncSteps,
    bool? syncHeartRate,
  }) {
    return WearableConfig(
      isConnected: isConnected ?? this.isConnected,
      selectedPlatform: selectedPlatform ?? this.selectedPlatform,
      autoSyncOnLaunch: autoSyncOnLaunch ?? this.autoSyncOnLaunch,
      syncSleep: syncSleep ?? this.syncSleep,
      syncHydration: syncHydration ?? this.syncHydration,
      syncSteps: syncSteps ?? this.syncSteps,
      syncHeartRate: syncHeartRate ?? this.syncHeartRate,
    );
  }

  Map<String, dynamic> toJson() => {
        'isConnected': isConnected,
        'selectedPlatform': selectedPlatform.name,
        'autoSyncOnLaunch': autoSyncOnLaunch,
        'syncSleep': syncSleep,
        'syncHydration': syncHydration,
        'syncSteps': syncSteps,
        'syncHeartRate': syncHeartRate,
      };

  factory WearableConfig.fromJson(Map<String, dynamic> json) {
    return WearableConfig(
      isConnected: json['isConnected'] as bool? ?? false,
      selectedPlatform: WearablePlatform.values.firstWhere(
        (p) => p.name == json['selectedPlatform'],
        orElse: () => WearablePlatform.simulated,
      ),
      autoSyncOnLaunch: json['autoSyncOnLaunch'] as bool? ?? true,
      syncSleep: json['syncSleep'] as bool? ?? true,
      syncHydration: json['syncHydration'] as bool? ?? true,
      syncSteps: json['syncSteps'] as bool? ?? true,
      syncHeartRate: json['syncHeartRate'] as bool? ?? true,
    );
  }
}
