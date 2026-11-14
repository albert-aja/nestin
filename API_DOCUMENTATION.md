# Nestin Internal API & Platform Channel Reference

## 1. MethodChannel Contracts

### 1.1 `com.nestin.app/device_control`
Implemented by `DeviceControlPlugin.kt` (Android) and `DeviceControlManager` (`AppDelegate.swift`, iOS), consumed by `NativeDeviceControlService` (`lib/data/services/device_control_service.dart`).

| Method | Arguments | Return Shape |
| :--- | :--- | :--- |
| `inspectCapabilities` | none | `{ platform, manufacturer, brand, model, osVersion, sdkInt, hasUsageStats, hasDndAccess, canWriteSettings, hasOverlayPermission, hasAccessibilityService, hasExactAlarm, hasNotifications, hasLocation, hasBackgroundLocation, isBatteryOptimizationExempt, hasFamilyControlsEntitlement }` |
| `readSystemState` | none | `{ dndFilter, brightnessRaw, screenTimeoutMs, hasUsageStats, hasDndAccess, canWriteSettings, hasOverlayPermission, hasAccessibilityService, hasExactAlarm, hasNotifications, isBatteryOptimizationExempt, hasFamilyControlsEntitlement }` |
| `getAppUsageToday` | `{ packages: List<String> }` | `{ permissionGranted: bool, boundaryMessage: String, records: [{ packageName, appName, usedMinutesToday, launchCountToday, lastTimeUsedMs }] }` |
| `setDndEnabled` | `{ enable: bool }` | `{ support, succeeded, message, previousRawValue?, appliedRawValue? }` |
| `restoreDndFilter` | `{ filter: int }` | `{ support, succeeded, message, previousRawValue?, appliedRawValue? }` |
| `setScreenBrightness` | `{ percent: int }` | `{ support, succeeded, message, previousRawValue?, appliedRawValue? }` |
| `restoreBrightness` | `{ brightnessRaw: int }` | `{ support, succeeded, message, previousRawValue?, appliedRawValue? }` |
| `setScreenTimeoutSeconds` | `{ seconds: int }` | `{ support, succeeded, message, previousRawValue?, appliedRawValue? }` |
| `restoreScreenTimeoutMs` | `{ timeoutMs: int }` | `{ support, succeeded, message, previousRawValue?, appliedRawValue? }` |
| `openPermissionSettings` | `{ permission: String }` | `bool` |
| `openSystemModesOrWellbeing` | none | `bool` |

### 1.2 Other Native Channels (Preserved)
- `com.nestin.app/geofencing` (`GeofencingPlugin.kt` / `GeofenceManager`)
- `com.nestin.app/oem` (`OemHardeningPlugin.kt`)
- `com.nestin.app/widgets` (`MainActivity.kt` deep links `nestin://alarms`, `nestin://habits`, `nestin://new_alarm`, `nestin://wellbeing`, `nestin://permissions`, `nestin://automation`, `nestin://quick_capture`, `nestin://before_you_go`, `nestin://money`)
- `com.nestin.app/wearables` (`WearableHealthService`)

---

## 2. Core Dart Provider APIs

### `DeviceControlProvider` (`lib/providers/device_control_provider.dart`)
- `Future<void> refreshAll({DateTime? now})`
- `Future<DeviceCapabilityRegistry> refreshCapabilities()` — computes `PermissionStatus.revoked` when prior granted state turns `denied`.
- `Future<List<AppInterventionLog>> refreshAppUsage({bool dispatchNotifications = true, DateTime? now})`
- `Future<List<PhoneModeActionOutcome>> activatePhoneMode(String modeId, {DateTime? now})`
- `Future<List<String>> endActivePhoneMode({String reason = 'manual_end'})`
- `Future<void> recoverExpiredOrInterruptedModeIfNeeded({DateTime? now})`

### `AutomationProvider` (`lib/providers/automation_provider.dart`)
- `Future<List<AutomationExecutionLog>> triggerByEvent(AutomationTriggerType triggerType, {String triggerReason = '', Map<String, dynamic> eventContext = const {}, DateTime? now})`
- `Future<AutomationExecutionLog?> runRuleManually(String ruleId, {bool bypassConfirmation = true, DateTime? now})`
- `Future<AutomationExecutionLog?> confirmPendingExecution(String pendingId, {DateTime? now})`
- `Future<bool> rollbackExecution(String logId)`
- `void releaseOwnershipLock(String settingKey)`

### `CrossModuleLinkProvider` (`lib/providers/cross_module_link_provider.dart`)
- `List<LinkedEntityRef> linksFor(LinkEntityType type, String entityId)`
- `Future<EntityLink?> addLink(...)` (prevents duplicates & self-links)
- `Future<void> removeLink(String linkId)`
- `Future<void> removeAllLinksFor(LinkEntityType type, String entityId)`
- `Future<void> syncEntityTitle(LinkEntityType type, String entityId, String newTitle)`
