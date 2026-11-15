# Nestin Feature Matrix

Status Legend:
- **Implemented:** Code, persistence, UI, and unit/widget tests verified in repo.
- **Device-Dependent / Partial:** Flutter + Native bridge implemented; runtime behavior depends on OS version, runtime permissions, OEM policies, or hardware.
- **Delegated / Unsupported by OS:** Platform forbids third-party execution; Nestin honestly opens OS Settings or reports unsupported status.

| Family | Module / Capability | Status | Platform Notes / Code Anchor |
| :--- | :--- | :--- | :--- |
| **Roo** | Exact Wake-Up Alarms & Challenges | Implemented | `AlarmProvider`, `ChallengeEngine`, `ActiveAlarmScreen`, `OemHardeningPlugin.kt` |
| **Roo** | Custom Audio Sandbox Import & Crow Tone | Implemented | `AudioService`, `RooAlarmToneService`, `SoundPickerSheet` |
| **Roo** | Timers & Pomodoro Focus Engine | Implemented | `TimerProvider`, `TimersScreen`, `PomodoroView` |
| **Roo** | Calendar, Reminders, Tasks, Routines | Implemented | `CalendarScreen`, `RemindersListScreen`, `TasksScreen`, `RoutinesScreen` |
| **Roo** | Android Home Screen Glance Widgets | Implemented (Android) | `NextAlarmWidgetProvider`, `HabitChecklistWidgetProvider`, `WidgetSyncService` |
| **Echo** | Diary, Memories, Timeline, Prompts, PIN Lock | Implemented | `JournalProvider`, `JournalHubScreen`, `SecurityPinGateSheet` |
| **Seren** | Dose Medication Schedule & Snooze Action | Implemented | `MedicationProvider`, `MedicationTrackerSheet`, `NotificationService` |
| **Seren** | Hydration, Sleep Wind-Down, Caffeine, Vitals | Implemented | `HydrationProvider`, `SleepWellnessProvider`, `CaffeineProvider`, `HealthWellnessProvider` |
| **Seren** | Wearable Telemetry Bridge | Device-Dependent | `WearableProvider`, `WearableHealthService` (`com.nestin.app/wearables`) |
| **Pippin** | Hobbies, Practice Milestones & Reading List | Implemented | `HobbyProvider`, `ReadingProvider`, `HobbyPracticeSheet`, `ReadingTrackerSheet` |
| **Twill** | Markdown Notes, Checklists, Collections, Wishlist | Implemented | `NoteProvider`, `CollectionProvider`, `NotesListScreen`, `WishlistScreen` |
| **Twill** | Quick Capture & Home Widget | Implemented | `QuickCaptureSheet`, `QuickCaptureWidgetProvider` |
| **Twill** | Basic Local Money Management | Implemented | `MoneyProvider`, `MoneyHubScreen`, atomic ledger rollback (`commitMoneyLedgerAtomically`) |
| **Roo** | Digital Discipline, App Fast & Usage Limits | Device-Dependent | `DigitalDisciplineScreen`, `WellbeingAppFastTab`, Android `UsageStatsManager` (`PACKAGE_USAGE_STATS`); iOS reports `unsupported` honestly without `FamilyControls` |
| **Roo** | Focus Lock & Pomodoro App Restrictions | Delegated / Partial | Shared `RestrictionEngine` + `FocusLockCoordinator`; delegates to OS Digital Wellbeing unless Android Accessibility shield (`NestinAppShieldService`) is opted in or iOS `FamilyControls` entitlement exists |
| **Scout** | BeforeYouGo Departure Checklists | Implemented | `BeforeYouGoProvider`, `BeforeYouGoSheet`, `BeforeYouGoCard` |
| **Scout** | Geofencing & Location Reminders | Device-Dependent | `GeofenceProvider`, `GeofencingPlugin.kt` (Android), `GeofenceManager` (iOS) |
| **Scout** | Phone Modes (DND, Brightness, Timeout) | Device-Dependent | `PhoneModesScreen`; Android direct with `ACCESS_NOTIFICATION_POLICY` + `WRITE_SETTINGS`; iOS Focus delegated to System Settings, brightness/timeout unsupported |
| **Scout** | Safe State Restoration & User Override Guard | Implemented | `StateRestorationSnapshot`, `DeviceControlProvider.endActivePhoneMode` |
| **Scout** | Device Capability Registry & Permission Center | Implemented | `PermissionCenterScreen`, `DeviceControlPlugin.kt`, `DeviceControlManager` |
| **Shared** | Shared Automation Engine | Implemented | `AutomationProvider`, `AutomationHubScreen` (triggers, conditions, locks, confirmation gate, retries, rollback) |
| **Shared** | Unified Cross-Module Entity Linking | Implemented | `CrossModuleLinkProvider`, `LinkedEntitiesSection`, bidirectional cleanup |
| **Shared** | Adaptive Light/Dark Theme & EN/ID L10n | Implemented | `AppColors`, `AppTheme`, `AppLocalizations` (`en_US`, `id_ID`) |
