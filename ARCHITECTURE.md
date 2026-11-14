# Nestin System Architecture

## 1. Architectural Overview

Nestin follows a modular, local-first clean architecture centered around typed Dart models, `ChangeNotifier` state providers, platform service abstractions (`MethodChannel`), and reusable UI components.

```
lib/
├── core/
│   ├── constants/        # Platform/channel constants
│   ├── l10n/             # AppLanguage, AppLocalizations, kNestinTranslations (EN/ID)
│   └── theme/            # AppColors (adaptive dark/light tokens), AppTheme
├── data/
│   ├── models/           # Immutable JSON-serializable entities across all 6 families
│   └── services/         # StorageService, NotificationService, AudioService,
│                         # OemHardeningService, DeviceControlService, WidgetSyncService
├── domain/               # Pure logic (ChallengeEngine, NaturalLanguageDateParser, SleepCycleCalculator)
├── providers/            # 22 domain ChangeNotifiers + DeviceControlProvider,
│                         # AutomationProvider, CrossModuleLinkProvider
└── ui/
    ├── screens/          # MainNavigationScreen, Hubs, Settings, DigitalWellbeingScreen,
    │                     # PermissionCenterScreen, AutomationHubScreen, UniversalSearchScreen
    └── widgets/          # SwipeActionCard, LinkedEntitiesSection, Mascot/Feature sheets & cards
```

---

## 2. Shared Cross-Cutting Infrastructure

### 2.1 Shared Persistence (`StorageService`)
- Backed by `SharedPreferences` with deterministic `nestin_*_v1` key isolation (with automatic one-time migration from legacy keys).
- Provides `_saveJsonList` / `_loadJsonList`, `commitMoneyLedgerAtomically` rollback protection, `migrateMoneySchemaIfNeeded`, and full portability via `exportFullBackupJson()` / `restoreFullBackupJson()`.

### 2.2 Shared Scheduling & Notifications (`NotificationService`)
- Manages categorized local notification channels via `flutter_local_notifications`:
  - `nestin_alarm_channel` (max importance + `fullScreenIntent`)
  - `nestin_reminder_channel`, `nestin_timer_channel`, `nestin_wellness_channel`, `nestin_medication_channel` (with background isolate snooze action via `@pragma('vm:entry-point')`)
  - `nestin_geofence_channel`, `nestin_departure_channel`
  - `nestin_wellbeing_channel`, `nestin_automation_channel`

### 2.3 Device Capability & Control Abstraction (`DeviceControlServiceInterface`)
- `NativeDeviceControlService` communicates over `MethodChannel('com.nestin.app/device_control')` to Android `DeviceControlPlugin.kt` and iOS `DeviceControlManager`.
- `MockDeviceControlService` enables deterministic testing of OS permissions, revocations, capability tiers, app usage stats, and manual mid-session OS setting changes.

### 2.4 Shared Automation Engine (`AutomationProvider`)
- Orchestrates triggers (`timeSchedule`, `alarmDismissed`, `geofenceEnter`, `geofenceExit`, `calendarEventUpcoming`, `appUsageThreshold`, `manual`), conditions, user confirmation queue, `SharedSettingOwnership` conflict locking, retry policy, audit logging, and safe rollback.

### 2.5 Cross-Module Linking Layer (`CrossModuleLinkProvider` + `LinkedEntitiesSection`)
- Maintains normalized bidirectional `EntityLink` edges connecting entities across Roo, Echo, Seren, Pippin, Twill, and Scout without duplicating underlying entity records.
- Integrated defensively (`try/catch` provider lookups) inside `TasksScreen`, `CalendarScreen`, `NotesListScreen`, and tested independently.

---

## 3. Core Alarm & Reliability Components (Verified Untouched Regressions)

- **Alarm Engine:** `AlarmProvider`, `AudioService`, `RooAlarmToneService`, `ActiveAlarmScreen`, `AlarmEditScreen`, `ChallengeModalDialog`.
- **Platform Hardening:** `OemHardeningService`, `OemHardeningPlugin.kt`, `NestinKeepAliveService`, `OemWarningBanner`.
- **Home Screen Widgets:** `WidgetSyncService`, `NextAlarmWidgetProvider`, `HabitChecklistWidgetProvider`, `QuickCaptureWidgetProvider`.
