# RooDoo — Universal Alarm & Reminder Platform

> **Tagline:** Every moment, right on time.  
> **Brand Direction:** Universal alarms, smart reminders, wake-up intelligence. Clean, modern, reliable time-alert companion with warm sunrise rooster-inspired aesthetic.

---

## Project Overview & Architectural Explanations

RooDoo is a standalone mobile platform built with Flutter. It unifies time management across three distinct functional tiers:
1. **Universal Alarms:** Critical, hard-trigger alerts engineered for waking up or strict schedule enforcement with sound ramping, challenge gates, and recurrence.
2. **Smart Reminders:** Contextual task and event reminders with due dates, frequencies, and non-intrusive notification delivery.
3. **Countdown Timers:** Multi-instance concurrent countdown timers for cooking, workouts, and work sprints with background awareness.

### Core Architectural Decisions
- **Framework:** Flutter 3.44+ (Dart 3.12+) for reliable cross-platform execution (Android & iOS).
- **State Management:** `ChangeNotifier` and `Provider` pattern (`AlarmProvider`, `ReminderProvider`, `TimerProvider`, `SettingsProvider`, `SoundProvider`) for clean separation of concerns, reactivity, and testability.
- **Persistence Layer:** `StorageService` using local structured JSON storage via `SharedPreferences` for fast, zero-latency startup and resilience against platform background eviction.
- **Custom Audio Import & Isolation:**
  - `SoundManagementService` leverages system file picker (`FilePicker`) filtering for audio files (`mp3`, `wav`, `m4a`, `ogg`, `aac`).
  - Picked audio files are cloned into app internal persistent storage (`<appDocsDir>/custom_sounds/`) with unique IDs, safeguarding against broken paths if the user deletes original files from Downloads.
  - `Alarm` data model explicitly persists `soundFilePath` alongside `soundId`, enabling seamless playback via `DeviceFileSource` during alarm triggers.
- **Inheritance Engine for Wake-up Challenges:**
  - **Global Default Profile:** User sets app-wide challenge preferences (`WakeUpChallengeProfile`: Math, Memory, Typing, Difficulty, Rounds, Snooze permission).
  - **Individual Alarm Overrides:** Each alarm can either explicitly inherit the global profile (`challengeInherited = true`) or define custom overrides.
  - **Dynamic Inheritance & Protection:** Updating the global profile automatically updates all inheriting alarms while protecting overridden alarms from unintended changes.
  - **Reversion:** Alarms with overrides can be reset at any time to resume inheriting global defaults (`clearChallengeOverride`).
- **Reliable Scheduling Engine:**
  - Deterministic calculation of next alarm timestamps accounting for day-of-week recurrence (ISO 8601), one-time schedules, and active snooze states.
  - Android Manifest pre-configured with exact alarm permissions (`SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `POST_NOTIFICATIONS`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`, `USE_FULL_SCREEN_INTENT`, `READ_MEDIA_AUDIO`).
  - Integration with `flutter_local_notifications` for high-priority notification channels (`roodoo_alarm_channel`, `roodoo_reminder_channel`, `roodoo_timer_channel`).
  - Full-screen in-app `ActiveAlarmScreen` with glowing sunrise pulse animation, audio playback with gradual volume ramping, and dismissal challenge gate.

---

## Implemented Features

### 1. Foundation, Design System & Navigation
- **Warm Rooster Sunrise Theme:** Defined color tokens (`AppColors.primary` #E04A3A, `AppColors.accent` #FF9E1B, dark card #1A1B20, light card #FFFFFF) and responsive themes (`AppTheme.darkTheme`, `AppTheme.lightTheme`).
- **Main Navigation Shell:** 5-tab persistent bottom navigation bar (`HomeDashboardScreen`, `AlarmsListScreen`, `RemindersListScreen`, `TimersScreen`, `SettingsScreen`).
- **Full-Screen Alarm Interceptor:** In-app alarm trigger overlay that displays `ActiveAlarmScreen` over any tab when an alarm rings.

### 2. Universal Alarm Management & Custom Sound Import
- **Custom Audio Import (MP3 / WAV / M4A):**
  - Interactive `SoundPickerSheet` modal allowing users to import audio files directly from device storage.
  - Persistent file storage in app sandbox directory (`custom_sounds/`) so sounds remain playable even if original file is moved or deleted.
  - Audio playback support for both asset ringtones and custom device audio files (`DeviceFileSource`) with live preview and delete management.
  - Integrated into `AlarmEditScreen` and `SettingsScreen` (Custom Ringtone Library card).
- **Alarm CRUD Operations:** Create, edit, toggle enable/disable, duplicate, and delete alarms with instant persistence.
- **Recurrence Engine:** Supports One-time, Daily, Weekdays (Mon-Fri), Weekends (Sat-Sun), and Custom Days picker.
- **Organization & Categories:** Predefined categories with dedicated color badges and icons: Wake Up, Work, Personal, Health, Activities, Other.
- **Audio & Volume Ramping:** Integrated `AudioService` supporting tone selection (Rooster Dawn, Gentle Breeze, Digital Pulse, Bell Chime, Energetic Beat, or Custom Sounds), live tone preview, volume slider (10% to 100%), and gradual volume increase ramp over 30 to 120 seconds.
- **Snooze Configuration:** Configurable snooze intervals (5, 9, 10, 15 minutes) and maximum snooze counters (1, 2, 3, 5, or unlimited).
- **Test Ring Simulator:** Instant in-app trigger button to test tone playback, gradual volume rise, and challenge solving.

### 3. Smart Wake-Up Intelligence & Challenge Engine
- **Mathematical Challenges:** Generates dynamic addition, subtraction, and multiplication arithmetic problems scaled across Easy, Medium, and Hard tiers with custom in-dialog numeric keypad.
- **Pattern Memory Challenges:** Interactive 4-pad color sequence memory game that flashes sequences of increasing length and tests user recall.
- **Word Typing Challenges:** Motivational phrase typing challenge with real-time text matching validation.
- **Inheritance & Override System:** Full implementation of global defaults vs alarm-specific overrides, verified with unit tests.

### 4. Smart Reminders System
- **Reminder Management:** Add, edit, complete, and delete contextual task reminders.
- **Recurrence Support:** Daily, Weekdays, Weekly, Monthly, or One-time recurrence. When a recurring reminder is checked off, its due date automatically advances to the next period.
- **Overdue Detection:** Automatic visual warning pills for overdue pending tasks.
- **Categorization & Filtering:** Segmented tabs for All, Pending, and Completed reminders with category badges.

### 5. Multi-Timer Experience
- **Concurrent Countdown Timers:** Support for multiple simultaneous countdown timers running independently.
- **Quick Presets:** Instant-start presets for Tea (1m), Eggs (3m), Rest (5m), Break (10m), and Focus Sprint (25m).
- **Interactive Controls:** Start, pause, resume, reset, and delete with circular progress ring.
- **Completion Alerts:** Audio bell chime and heads-up notification when a timer hits zero.

### 6. Home Dashboard & Settings
- **Hero Next Alarm Card:** Live countdown (`in X hours Y mins`), time, title, and challenge status.
- **Quick Metrics:** Live status pills showing active alarms count, pending reminders count, and running timers count.
- **Settings & Personalization:** Theme toggle (Dark / Light / System), 24-hour time format toggle, default snooze length, default volume and ramping duration, and Global Challenge Profile editor.
- **Automated Test Suite:** 18 unit and widget tests covering schedule calculations, inheritance rules, custom sound serialization, challenge generation, and UI widget rendering.

---

## Todo List & Recommendations

- [ ] **Phase 7: Advanced Wake-Up & Sleep Experience (UI/UX Boosts)**
  - [ ] **Bedtime & Sleep Cycle Calculator:** Suggest optimal bedtimes based on 90-minute REM sleep cycles from target wake-up alarm time (`SleepCycleCalculator`).
  - [ ] **Flip/Shake to Snooze:** Accelerometer-based physical gestures with sensitivity calibration.
  - [ ] **Pre-Alarm Sunrise Simulation:** Gentle screen brightness ramping from 0% to 100% warm amber before audio starts.
  - [ ] **Wake-Up Consistency Analytics:** Log wake-up times and challenge solve duration to track morning discipline over time.
- [ ] **Phase 8: Audio & Asset Enrichment**
  - [ ] Bundle custom high-fidelity audio files for rooster dawn crow, ambient rain, forest stream, and temple bells in `assets/sounds/`.
  - [ ] **In-App Audio Trimming Tool:** Allow trimming imported MP3 files (e.g. starting at chorus/intro).
  - [ ] **Waveform Visualizer:** Visual audio bar animation during alarm playback.
- [ ] **Phase 9: Platform-Specific Hardening**
  - [ ] Android native foreground service integration for OEM-aggressive battery optimization (Xiaomi, Samsung, Huawei background killer workarounds).
  - [ ] iOS Critical Alerts entitlement configuration for bypassing Do Not Disturb mode when authorized.
