# Nestin Device Integration, OEM Reality & Safe Restoration

Nestin never claims unbreakable OS control when platform sandboxes, missing permissions, or OEM policies restrict third-party apps. Every device action passes through `DeviceCapabilityRegistry` (`lib/data/models/device_capability.dart`) and reports one of four exact classifications:

1. `directlySupported` — OS API & required runtime grant are present.
2. `permissionRequired` — Hardware/OS supports the capability once user grants the required special permission.
3. `delegatedToSystemSettings` — Platform reserves control for native OS menus (e.g., Samsung Modes & Routines, iOS Focus, battery restriction screens).
4. `unsupported` — Platform API prohibits programmatic mutation by third-party apps.

---

## 1. Android Implementation (`DeviceControlPlugin.kt` & `AndroidManifest.xml`)

Registered in `MainActivity.kt` on `MethodChannel('com.nestin.app/device_control')`.

| Feature | Android API | Permission Required | Honest Limitation / Fallback |
| :--- | :--- | :--- | :--- |
| App Usage Telemetry | `UsageStatsManager.queryAndAggregateUsageStats` + `UsageEvents` | `PACKAGE_USAGE_STATS` (`AppOpsManager.OPSTR_GET_USAGE_STATS`) | Returns `permissionGranted: false` with honest prompt until user permits Usage Access in OS Settings. |
| Do Not Disturb (DND) | `NotificationManager.setInterruptionFilter` | `ACCESS_NOTIFICATION_POLICY` | Returns `permissionRequired` unless Notification Policy Access is granted; Samsung One UI also offers **Modes & Routines** shortcut. |
| System Brightness & Auto-Lock Timeout | `Settings.System.putInt` (`SCREEN_BRIGHTNESS`, `SCREEN_OFF_TIMEOUT`) | `WRITE_SETTINGS` (`Settings.System.canWrite`) | Explicitly checks `Settings.System.canWrite(context)` before writes and records exact prior raw integer values for restoration. |
| Warning Overlays | `Settings.canDrawOverlays` | `SYSTEM_ALERT_WINDOW` | Optional; degrades cleanly to local notifications (`nestin_wellbeing_channel`). |
| Hard App Shielding | Accessibility / Digital Wellbeing | Optional Accessibility opt-in | Without Accessibility service enabled, delegates to notifications, mindful pause prompts, or OS Digital Wellbeing settings. |
| OEM Reliability & Alarms | `OemHardeningPlugin.kt`, `NestinKeepAliveService` | `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `SCHEDULE_EXACT_ALARM`, `USE_FULL_SCREEN_INTENT` | Surface brand-specific guidance (Samsung, Xiaomi/MIUI, OPPO, vivo, OnePlus). |
| Native Geofences | `GeofencingPlugin.kt` (`LocationManager.addProximityAlert`) | `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION` | Boot receiver re-registers fences cleanly. |

---

## 2. iOS Implementation (`DeviceControlManager` in `ios/Runner/AppDelegate.swift`)

| Feature | iOS API / Reality | Honest Classification |
| :--- | :--- | :--- |
| Cross-App Usage & Shielding | `FamilyControls` / `DeviceActivity` / `ManagedSettings` require special Apple Developer entitlement | Inspects `com.apple.developer.family-controls`; reports `unsupported` honestly unless signed with the entitlement. |
| Focus / Do Not Disturb | No public API for arbitrary third-party apps to toggle global Focus | `delegatedToSystemSettings` — directs user to iOS Focus Settings. |
| System Brightness & Auto-Lock | Apple prohibits third-party persistence of global brightness or Auto-Lock duration | `unsupported` — never faked or persisted as succeeded. |
| Native Geofencing | `GeofenceManager` (`CLLocationManager`, `CLCircularRegion`, `UNUserNotificationCenter`) | Supported when user grants Location Always / When In Use. |

---

## 3. Centralized Permission Center & Revoked Detection

- `PermissionCenterScreen` groups permissions into **Required** (`Notifications`, `Exact Alarms`), **Recommended** (`Usage Access`, `Battery Optimization`), and **Optional** (`DND Access`, `Modify System Settings`, `Display Over Other Apps`, `Location`, iOS `FamilyControls`).
- `DeviceControlProvider.refreshCapabilities()` compares live OS flags against `StorageService.loadPermissionHistory()`. If a previously granted permission becomes denied, its status automatically transitions to `PermissionStatus.revoked` and surfaces a warning banner.

---

## 4. Safe State Restoration Mechanism

When activating a Phone Mode (`Sleep`, `Work`, `Study`, `Relax`, `Custom`):
1. `DeviceControlProvider` reads live OS values first and persists a `StateRestorationSnapshot` (`nestin_state_restoration_snapshot_v1`) BEFORE altering any setting.
2. Only settings whose write actually returned `succeeded: true` record `modifiedByNestin = true` and their exact `appliedRawValue`.
3. On mode exit (or crash/restart recovery in `recoverExpiredOrInterruptedModeIfNeeded`):
   - `DeviceControlProvider` re-reads CURRENT OS values.
   - If the current value still equals `appliedRawValue`, Nestin restores `previousRawValue`.
   - If the user manually changed brightness, DND, or timeout mid-session (`current != applied`), Nestin **preserves the user's manual override** and logs why restoration was skipped!
