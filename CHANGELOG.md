# Nestin Changelog

## [Unreleased / Nestin Full Blueprint Expansion]
### Added
- **Scout Digital Wellbeing & App Restriction Manager (`lib/data/models/digital_wellbeing.dart`, `lib/ui/screens/scout/digital_wellbeing_screen.dart`):** Tracked app rules (Instagram, TikTok, YouTube, Facebook, Games, custom packages), daily limits, warning thresholds, overnight/day blocked schedules, and 5-level intervention ladder (`trackOnly`, `preLimitWarning`, `timedSoftPause`, `blockingSchedule`, `strictModeGuard`) with local intervention history.
- **Phone Mode Orchestrator & Safe State Restoration (`lib/data/models/phone_mode.dart`, `lib/providers/device_control_provider.dart`):** Presets for `Sleep`, `Work`, `Study`, `Relax`, and `Custom` modes capturing pre-mode DND, raw brightness, and screen timeout into `StateRestorationSnapshot`, restoring settings on end or after restart while preserving manual mid-session user overrides.
- **Device Capability Registry & Permission Center (`lib/data/models/device_capability.dart`, `lib/ui/screens/settings/permission_center_screen.dart`):** 4-tier execution classification (`directlySupported`, `permissionRequired`, `delegatedToSystemSettings`, `unsupported`), Required/Recommended/Optional permission grouping, rationales, OS settings shortcuts, and revoked-permission detection.
- **Native Device Control Platform Bridges:**
  - Android: `DeviceControlPlugin.kt` registered in `MainActivity.kt` + `ACCESS_NOTIFICATION_POLICY`, `WRITE_SETTINGS`, and `PACKAGE_USAGE_STATS` manifest declarations.
  - iOS: `DeviceControlManager` in `ios/Runner/AppDelegate.swift` honestly surfacing Focus delegation and `FamilyControls` entitlement boundaries.
- **Shared Automation Engine (`lib/data/models/automation_rule.dart`, `lib/providers/automation_provider.dart`, `lib/ui/screens/automation/automation_hub_screen.dart`):** Unified triggers across Time, Wake-Up Alarms, Geofences, Calendar, App Usage, and Manual runs; conditions; user confirmation queue; `SharedSettingOwnership` conflict locking; retry policies; and rollback support.
- **Cross-Module Entity Linking (`lib/data/models/entity_link.dart`, `lib/providers/cross_module_link_provider.dart`, `lib/ui/widgets/linked_entities_section.dart`):** Bidirectional connecting of Tasks, Calendar Events, Notes, Reminders, Journal Entries, Memories, Hobbies, Reading Books, Medications, BeforeYouGo Checklists, and Automation Rules with orphan cleanup.
- **Notifications, Backups & Search:** Added `wellbeingChannelId` and `automationChannelId` channels, backup serialization in `StorageService`, deep links (`nestin://wellbeing`, `nestin://permissions`, `nestin://automation`), dashboard active mode/confirmation banner, and Universal Search indexing for Phone Modes and Automations.
- **Blueprint Deliverables & Tests:** Added 10 blueprint Markdown documents plus comprehensive unit & Light/Dark widget tests (`test/device_control_and_wellbeing_test.dart`, `test/automation_engine_test.dart`).

## [Previous Milestones — Preserved]
- Adaptive Material 3 Light/Dark surface token audit across screens, challenges, and modal sheets (`test/adaptive_theme_test.dart`).
- Unified Swipe Actions (`SwipeActionCard`) & 4-second Undo snackbars across Tasks, Reminders, Notes, and Wishlist (`test/unified_swipe_actions_test.dart`).
- Six-family expansion (Roo Calendar/Tasks/Reminders/Routines/Pomodoro, Echo Diary/Memories/PIN Lock, Seren Dose/Hydration/Sleep/Caffeine/Wearables, Pippin Hobbies/Reading, Twill Notes/Collections/Wishlist/Basic Money Management, Scout BeforeYouGo & Native Geofencing).
- Core Nestin smart alarm engine with progressive volume ramp, math/memory/typing wake-up challenges, custom audio sandbox, OEM hardening (`OemHardeningPlugin.kt`), and Android glance widgets.
