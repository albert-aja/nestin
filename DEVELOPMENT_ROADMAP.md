# Nestin Development Roadmap

## Completed Phases

- **Phase 0–1 (Core Alarm Preservation & Nestin Six-Family Foundation):**
  - Preserved full alarm clock, challenge engine (Math/Memory/Typing), custom sound sandbox, countdown timers, Pomodoro sprints, and Android glance widgets.
  - Established all 6 bird families (**Roo**, **Echo**, **Seren**, **Pippin**, **Twill**, **Scout**), adaptive Light/Dark Material 3 theme engine, offline EN/ID localization, and unified `SwipeActionCard` undo workflows.
- **Phase 2–3 (Connected Personal Domains):**
  - Built Calendar/Tasks/Reminders/Routines + NLP date parser, Echo Diary/Memories/Timeline + PIN lock, Seren Dose Medications/Hydration/Sleep/Caffeine/Vitals, Pippin Hobbies/Reading, Twill Markdown Notes/Collections/Wishlist/Basic Money Management, and Scout BeforeYouGo + Native Geofencing.
- **Phase 4–5 (Shared Automation, Cross-Module Linking, Digital Wellbeing, Phone Modes & Permission Center):**
  - Implemented `DeviceCapabilityRegistry` & `PermissionCenterScreen` with 4-way classification & revoked-permission detection.
  - Implemented `DigitalWellbeingScreen`, 5-level App Restriction Manager, Phone Mode Orchestrator (`Sleep`, `Work`, `Study`, `Relax`, `Custom`) with Safe State Restoration preserving manual mid-session user edits, and Android `DeviceControlPlugin.kt` + iOS `DeviceControlManager`.
  - Implemented `AutomationProvider` & `AutomationHubScreen` (triggers, conditions, confirmation queue, `SharedSettingOwnership` conflict locking, retries, rollback) and `CrossModuleLinkProvider` + `LinkedEntitiesSection` across Tasks, Calendar, Notes, and Universal Search.

---

## Upcoming Roadmap

1. **Scheduled Background Time Evaluation (`WorkManager` / `BGAppRefreshTask`):** Periodically evaluate time-based `AutomationRule` triggers (`timeSchedule`) and `PhoneModeProfile` end windows even while the app UI is backgrounded.
2. **Optional Android Accessibility App-Shield Opt-In:** Provide an explicit, disabled-by-default Accessibility Service module for foreground distracting-app overlays (strictly opt-in with Play Store disclosure).
3. **Apple `FamilyControls` Entitlement Provisioning:** Configure signed `com.apple.developer.family-controls` entitlement and `DeviceActivityReport` extension when deploying on managed iOS developer provisioning profiles.
4. **Full JSON Backup File Picker Import/Export Flow:** Upgrade clipboard/preview export in `ExploreHubScreen` into direct OS share/save `.json` file export and interactive pre-restore diff preview.
5. **Deep Secondary Sheet EN/ID Localization & Narrow-Viewport Polish:** Extend translations into all remaining modal sheets and guard compact `<390dp` cards.
6. **Mascot Sprite UI Rollout (`Shared MascotSpriteView`):** Wire the 84 quantized PNG sprites (`assets/mascots/sprites/`) into empty states and celebratory banners with theme-adaptive speech bubbles.
