enum WearablePlatform {
  appleHealth,
  googleFit,
  healthConnect,
  simulated,
}

extension WearablePlatformExtension on WearablePlatform {
  String get displayName {
    switch (this) {
      case WearablePlatform.appleHealth:
        return 'Apple Health (HealthKit)';
      case WearablePlatform.googleFit:
        return 'Google Fit';
      case WearablePlatform.healthConnect:
        return 'Health Connect (Android)';
      case WearablePlatform.simulated:
        return 'Local Device Simulator';
    }
  }

  String get shortName {
    switch (this) {
      case WearablePlatform.appleHealth:
        return 'Apple Health';
      case WearablePlatform.googleFit:
        return 'Google Fit';
      case WearablePlatform.healthConnect:
        return 'Health Connect';
      case WearablePlatform.simulated:
        return 'Sandbox Simulator';
    }
  }

  String get description {
    switch (this) {
      case WearablePlatform.appleHealth:
        return 'Sync sleep, steps, and hydration with Apple Watch and iOS HealthKit.';
      case WearablePlatform.googleFit:
        return 'Connect to Google Fit activity, sleep logs, and heart rate.';
      case WearablePlatform.healthConnect:
        return 'Android unified health platform with on-device granular permissions.';
      case WearablePlatform.simulated:
        return 'Privacy-first offline simulator for testing wearable metrics without accounts.';
    }
  }
}

enum WearablePermissionType {
  sleep,
  hydration,
  steps,
  heartRate,
}
