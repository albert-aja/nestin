# Nestin — Personal Everyday Space & Universal Alarm Platform

> **Tagline:** Every moment, right on time.  
> **Brand Direction:** Universal alarms, smart wake-up intelligence, contextual planning, personal organization, everyday reflection, local-first money management, and wellness tools. Warm, inviting sanctuary aesthetic inspired by the comfort of nesting, with a clean, focused, privacy-respecting local-first architecture.

---

## Project Overview & Architectural Explanations

Nestin (formerly RooDoo) is a unified **Personal Everyday Space** that integrates high-reliability alarms, intelligent wake-up gates, daily planning, personal knowledge organization, local-first money management, and reflective memory journaling into one cohesive home. It bridges the gap between disconnected daily utilities by giving users one serene space for their day: wake up on time, track routines, manage tasks, organize personal finances and wishlists, record memories, and prepare for daily departures without bloat or unwanted online dependencies.

### Core Architectural Decisions & Design Patterns

1. **Strict Feature Preservation:**
   - The entire smart alarm engine (gradual volume ramping, challenge engine with arithmetic/memory/typing gates, snooze limits, custom sound import into app sandbox, full-screen active alarm interceptor) is preserved without regression.

2. **Modular, Feature-Oriented Clean Architecture:**
   - **Framework:** Flutter 3.44+ (Dart 3.12+) targeted primarily for Android, iOS, and cross-platform mobile environments.
   - **State Management:** Reactive `ChangeNotifier` and `Provider` pattern with single-responsibility providers (`AlarmProvider`, `ReminderProvider`, `TimerProvider`, `SettingsProvider`, `SoundProvider`, `CalendarProvider`, `TaskProvider`, `RoutineProvider`, `NoteProvider`, `CollectionProvider`, `JournalProvider`, `DashboardProvider`).
   - **Persistence Layer:** Structured, local-first JSON document persistence managed by `StorageService` using `SharedPreferences`. Guarantees zero-latency cold starts, resilient background recovery, and seamless offline functionality without SQLite migration locks.
   - **Local Backup & Restoration Engine:** Dedicated full backup serialization (`exportFullBackupJson` and `restoreFullBackupJson`) allowing users to export their entire personal life data into an offline JSON backup file and restore it on any device.

3. **Domain Abstractions & Extensibility:**
   - **Weather Abstraction:** `WeatherProviderInterface` decoupling current weather presentation from third-party APIs. Implemented with `LocalWeatherService` delivering immediate, context-aware forecasts and advice.
   - **Sleep Cycle Engine:** `SleepCycleCalculator` computing optimal 90-minute REM sleep cycles and 14-minute sleep latency to suggest restorative bedtime and wake-up target windows.
   - **Quick Capture Integration:** Global multi-entity sheet (`QuickCaptureSheet`) allowing instant creation of Notes, Tasks, Reminders, Journal entries, or Wishlist items from anywhere in the app.
   - **Universal Real-Time Search:** Cross-module indexing (`UniversalSearchScreen`) that queries Notes, Tasks, Calendar Events, Journal entries, Collections, and Alarms simultaneously with categorized search result pills.

4. **5-Hub Persistent Navigation Shell:**
   - **Tab 0: Today (`HomeDashboardScreen`):** Configurable daily dashboard aggregating weather, next alarm countdown, today's agenda, tasks due today, active habit routines, and everyday reflection mood logging.
   - **Tab 1: Time (`TimeHubScreen`):** Dedicated time and planning hub featuring 6 subtabs: Alarms, Reminders, Calendar, Tasks, Routines, and Timers.
   - **Tab 2: Organize (`OrganizeHubScreen`):** Personal organization space featuring 3 subtabs: Categorized Notes, Custom Lists/Collections, and Wishlist (Personal Money Management).
   - **Tab 3: Journal (`JournalHubScreen`):** Reflective memory space featuring 3 subtabs: Daily Diary with mood emojis, Unified Timeline Feed, and Milestone Memories.
   - **Tab 4: Explore (`ExploreHubScreen`):** Everyday wellness and utilities hub featuring Weather context, Sleep Cycle Calculator, Hydration Tracker, BeforeYouGo departure checklist, Universal Search launcher, Local Data Backup, and App Settings.
   - **Global Overlays:** Centered Floating Action Button for instant Quick Capture and `ActiveAlarmScreen` full-screen interceptor that takes over when an alarm triggers.

---

## Detailed Feature Explanations

### 1. Brand Identity & Visual Assets Integration (Nestin Rebrand)
- **App Logo (`assets/logo.jpg`):**
  - High-resolution 2048x2048 visual brand mark bundled directly into application assets (`pubspec.yaml`).
  - Integrated into `NestinBrandHeader` (`roodoo_brand_header.dart`) with rounded corner clipping (`ClipRRect`), soft elevation shadow, and automatic fallback handling.
  - Featured in `HomeDashboardScreen` top bar (`Nestin Everyday`) replacing generic placeholder icons.
  - Displayed in `SettingsScreen` in the dedicated **About Nestin** platform card with versioning and architecture highlights.
  - Scaled down using high-quality bicubic interpolation into native platform launcher icons:
    - Android mipmaps: `mipmap-mdpi` (48x48), `mipmap-hdpi` (72x72), `mipmap-xhdpi` (96x96), `mipmap-xxhdpi` (144x144), `mipmap-xxxhdpi` (192x192).
    - Web assets: `favicon.png` (64x64), `Icon-192.png`, `Icon-512.png`, and maskable variants.
- **Brand Banner (`assets/banner.jpg`):**
  - Ultra-high-resolution 2400x1792 visual banner asset registered in `pubspec.yaml`.
  - Prominently embedded at the very top of `README.md` to establish brand recognition and aesthetic tone.
- **Platform Rebranding:**
  - Package renamed to `nestin` in `pubspec.yaml`.
  - Android application label updated to `Nestin` in `AndroidManifest.xml`.
  - Web metadata, title, and Progressive Web App manifest configured as `Nestin` with theme color `#E04A3A`.
  - System notification channels updated to `Nestin Alarms`, `Nestin Reminders`, and `Nestin Timers`.

### 2. Centralized Today Dashboard (Module A)
- **Top Brand & Greeting Bar:** Contextual time-of-day greeting (Good morning / Good afternoon / Good evening) with official Nestin logo, quick search button, card customizer, and settings access.
- **Contextual Weather & Date Banner:** Displays current temperature in Celsius, sky condition, current date, and daily lifestyle advice snippet (configurable via `DashboardConfig.showWeather`).
- **Hero Next Alarm Card:** Live countdown badge (`in X hours Y mins`), large digital clock display, alarm label, category badge, required challenge status, and an instant **Test Ring** button to simulate alarm playback and challenge gates.
- **Metric Overview Strip:** Real-time counters showing active alarms, tasks due today, active reminders, and saved notes with tap-to-navigate routing to corresponding hubs.
- **Quick Action Bar:** Direct shortcuts for + Quick Capture (opens universal sheet) and + Alarm (opens alarm editor).
- **Today's Agenda Section:** Combines scheduled calendar events and pending reminders due on the current date with time badges and location metadata.
- **Tasks Due Today Section:** Lists tasks scheduled for today with inline checkboxes to toggle completion directly from the dashboard, priority tags (Urgent, High, Medium, Low), and subtask progress indicators.
- **Daily Habits & Routines Section:** Displays active morning/evening routines with current streak counter (`🔥 X day streak`), animated progress bar, and interactive step checkoffs.
- **Everyday Reflection (Quick Mood Check-in):** One-tap mood logging buttons (`😊 Great`, `🙂 Good`, `😐 Neutral`, `😔 Low`, `😫 Tough`) that instantly append a reflection entry to the user's diary with a floating confirmation notice.
- **Weekly Mood Trend Sparkline:** 7-day sparkline bar visualization analyzing consistency and dominant weekly emotions.
- **Pull-to-Refresh & Haptics:** Pulling down on the dashboard triggers tactile vibration rumble and refreshes countdowns and weather data.
- **Morning Briefing Greeting Banner:** Awareness of early morning hours with one-tap briefing dialog and audio chime.

### 3. Time & Planning Hub (Module B)
- **Universal Alarm Management (Preserved & Enhanced):**
  - Full CRUD operations: create, edit, toggle enable/disable, duplicate, and delete alarms.
  - Recurrence engine: One-time, Daily, Weekdays (Mon-Fri), Weekends (Sat-Sun), and Custom Days picker.
  - Multi-category support: Wake Up, Work, Personal, Health, Activities, and Other.
  - Audio & Volume Ramping: Volume slider (10% to 100%), gradual volume increase ramp (30s to 120s), and choice of asset tones or imported device audio.
  - Snooze control: Configurable snooze intervals (5m, 9m, 10m, 15m) and maximum snooze counters (1, 2, 3, 5, or unlimited).
- **Custom Audio Import & Isolation:**
  - `SoundPickerSheet` enables picking MP3, WAV, M4A, OGG, and AAC files directly from device storage.
  - Picked audio files are cloned into app internal persistent storage (`<appDocsDir>/custom_sounds/`) with unique IDs, safeguarding against broken paths if original files are moved or deleted.
- **Smart Wake-Up Intelligence & Challenge Gates:**
  - **Mathematical Challenges:** Generates dynamic addition, subtraction, and multiplication arithmetic problems scaled across Easy, Medium, and Hard tiers with custom in-dialog numeric keypad.
  - **Pattern Memory Challenges:** Interactive 4-pad color sequence memory game that flashes sequences of increasing length and tests user recall.
  - **Word Typing Challenges:** Motivational phrase typing challenge with real-time text matching validation ("Every moment, right on time with Nestin.").
  - **Inheritance & Override System:** Dual-tier architecture where alarms inherit the global default challenge profile or define custom overrides. Updating global defaults dynamically updates inheriting alarms while protecting overridden alarms.
- **Smart Reminders System:**
  - Contextual task reminders with title, notes, due date, due time, and category tags.
  - Recurrence engine supporting Daily, Weekdays, Weekly, Monthly, or One-time schedules. Recurring reminders automatically advance to the next occurrence when checked off.
  - Overdue warning pills and segmented filters (All, Pending, Completed).
- **Calendar & Everyday Events:**
  - Full calendar date selector with interactive day picking.
  - Event details: title, description, start time, end time, location, category badge, and reminder toggle.
  - Sorted chronological day agenda view with visual time spans.
- **Tasks & To-Do Management:**
  - Structured tasks with priorities (Urgent, High, Medium, Low), due dates, and optional time.
  - Subtask checklist support with progress calculation (`completed/total`).
  - Filter tabs for Pending vs Completed tasks with strike-through styling.
- **Daily Routines & Habits:**
  - Morning, Evening, and Custom routine templates.
  - Multi-step routine checklist with daily step completion tracking.
  - Streak tracking counter with automatic daily rollover detection.
- **Concurrent Timers:**
  - Multi-instance concurrent countdown timers running independently.
  - Quick presets: Tea (1m), Eggs (3m), Rest (5m), Break (10m), Focus Sprint (25m).
  - Circular progress ring, play/pause/reset/delete controls, and audio alert on completion.

### 4. Notes & Personal Organization (Module C — Money Management Focus)
- **Categorized Notes:**
  - Note creation with title, markdown-friendly text body, categories, and custom tags.
  - Pinned notes feature keeping critical notes at the top of the list.
  - Color-accented note cards with search filtering and archive support.
- **Custom Lists & Collections:**
  - Multi-purpose list manager for packing lists, books to read, gift ideas, and bucket lists.
  - Dynamic checklist entries with instant strike-off toggle and progress bars.
  - Icon and color customization for easy visual recognition.
- **Wishlist & Savings Goals (Money Management Tracker):**
  - **Strict Money Management Scope:** Nestin is purely a private, local-first personal budgeting and money management space. It is **not** a banking app and does **not** process financial transactions, bank accounts, card payments, or online payment gateways.
  - Track intended purchases, savings targets, and personal budget goals.
  - Set target prices, priorities (High, Medium, Low), and target achievement dates.
  - Status indicators for Achieved vs Pending items with formatted currency values.
  - Helps users budget mindfully and avoid impulsive purchases.

### 5. Journal & Memories (Module D)
- **Daily Diary:**
  - Personal journaling with title, content, date, tags, and private entry toggles.
  - Mood tracking with expressive mood emojis (`😄`, `🙂`, `😐`, `😔`, `😫`) and mood labels.
  - Dedicated Gratitude Note field on every entry to cultivate positive daily reflection.
- **Unified Everyday Timeline Feed:**
  - Aggregates diary entries, milestone memories, and major life events into a single chronological vertical timeline.
  - Color-coded badges and icons distinguish memories from journal entries.
- **Milestone Memories:**
  - Preserve special personal milestones, achievements, anniversaries, and meaningful events.
  - Milestone star badge highlighting life achievements.

### 6. Everyday Assistance & Wellness (Module E, F, G)
- **Weather Context:**
  - Clean temperature, conditions, and daily lifestyle advice display integrated into Today dashboard and Explore hub.
- **Sleep Cycle Calculator:**
  - Calculates recommended wake-up times from current time or bedtime using 90-minute REM sleep cycles and 14-minute sleep latency.
  - Highlights optimal sweet spots (5 cycles / 7.5 hours) to wake up feeling refreshed.
- **Hydration Water Tracker:**
  - Daily glass counter with tap-to-add/remove (250ml increments) and daily target progress bar.
- **BeforeYouGo Departure Checklist:**
  - Interactive departure checklist (Keys, Wallet, Phone, Charger, Water bottle, Turn off appliances, Lock doors) with quick reset for stress-free departures.
- **Data Backup & Privacy:**
  - Export full JSON backup containing all modules directly to clipboard or device file.
  - Restore full JSON backup with instantaneous state rehydration.
  - 100% offline and local-first architecture protecting user privacy.

### 7. Journal Reflections, Memory Throwback & Security Hardening (Phase 10 Implemented)
- **Biometric App & Diary Lock (`SecurityPinGateSheet` & `SettingsProvider`):**
  - **4-Digit Security PIN Engine:** Numeric entry keypad with error shake animation, visual dot indicators, and tactile rumble feedback (`HapticFeedback.heavyImpact()`).
  - **Biometric Quick-Unlock:** Integrated fingerprint and face authentication simulation with one-tap verification for effortless unlocking.
  - **Session-Based Privacy Gate:** In-memory session unlock state (`isDiaryUnlocked`) preventing unauthorized access while app is open.
  - **Entry-Level Privacy Protection:** Entries marked `isPrivate: true` replace sensitive text with a frosted lock card ("🔒 Private Reflection — Tap to unlock with PIN or Biometrics"), guarding against over-the-shoulder peeking.
  - **Header Quick-Lock Button:** Instant 1-tap lock toggle in the Reflections section header allowing users to immediately re-lock their diary session.
  - **Security & Privacy Settings:** Dedicated settings card in `SettingsScreen` to set/change PIN, toggle diary lock, toggle biometric unlock, and manage prompt/throwback visibility.
- **"On This Day" Nostalgic Memory Throwback (`ThrowbackSection` & `JournalProvider`):**
  - **Temporal Throwback Query Engine:** Queries all diary entries and milestone memories recorded on the exact same calendar day in previous years (`target.day == date.day && target.month == date.month && target.year != date.year`).
  - **Adaptive Multi-Month Fallback:** For newer users who haven't reached a full year, automatically surfaces memories from the same day of the month in past months (e.g. "1 month ago today", "2 months ago today").
  - **Nostalgic Throwback Hero Card:** Styled with a warm amber gradient border, time-ago badge, mood emoji, quote preview, and gratitude highlight.
  - **Privacy Enforcement:** Throwbacks referencing private reflections stay securely locked until the PIN or Biometric gate is passed.
  - **Detailed Throwback Dialog:** Tap to open the full memory in a nostalgic throwback inspection view with complete timestamp and gratitude details.
- **Daily Journal Prompt Carousel (`JournalPromptCarousel` & `JournalPrompt`):**
  - **Curated Reflective Questions:** Comprehensive deck spanning 7 mindful categories:
    - *Morning Intention* ("What was the highlight of your morning or your main intention today?")
    - *Daily Gratitude* ("Who made a positive difference in your day, and how did it feel?")
    - *Small Comforts* ("What is a small everyday comfort you appreciated or often take for granted?")
    - *Growth & Resilience* ("What challenge did you navigate with patience or wisdom today?")
    - *Mindful Moment* ("What is one thing that brought your mind peace or made you smile today?")
    - *Evening Unwind* ("What is one thing or worry you are ready to let go of tonight before sleep?")
    - *Self Discovery* ("What is a valuable lesson or reminder you experienced about yourself today?")
  - **Interactive Horizontal Carousel:** Smooth swipeable card carousel with category badge, icon, and progress indicator (`X/7`).
  - **Shuffle Prompt Randomizer:** 1-tap dice icon to immediately cycle and animate to the next inspiring prompt.
  - **1-Tap Answer Action:** Tapping "Answer Prompt" immediately launches the diary composer with the selected prompt pre-filled as context and focuses the reflection field, eliminating blank page writer's block.
  - **Configurable Visibility:** Toggleable in settings if the user prefers a minimal diary layout.

### 8. Natural Language Input Parsing & Intelligent Scheduling (Phase 8 Implemented)
- **Deterministic Regex & Token Extraction Engine (`NaturalLanguageDateParser`):**
  - **Temporal Extraction:** Automatically detects relative days (*today*, *tonight*, *tomorrow*, *tmrw*, *day after tomorrow*), offsets (*in 2 days*, *in a week*), and named weekdays (*this Friday*, *next Monday*, *Wednesday*).
  - **Clock & Time Recognition:** Detects 12-hour AM/PM formats (*at 3pm*, *3:30 pm*, *10:15am*), 24-hour military formats (*at 16:00*, *09:30*), and diurnal natural language expressions (*noon*, *midnight*, *in the morning*, *this afternoon*, *tonight*).
  - **Clean Title Sanitization:** Automatically parses and removes date/time snippets, trailing prepositions (*at*, *on*, *by*, *for*), and cleans double whitespaces without mangling other task description tokens.
  - **Live Detection Chip (`NlpDateDetectorChip`):** Displays real-time interactive confirmation pill as the user types with formatted summary, 1-tap "Clean Title" action, and an undo/dismiss button.
- **Cross-Module Input Integration:**
  - **Tasks Management (`TasksScreen`):** Auto-populates task `dueDate` and `dueTime` with interactive visual date/time selectors.
  - **Calendar Events (`CalendarScreen`):** Auto-schedules calendar event `date` and `startTime` directly from natural event titles.
  - **Global Quick Capture (`QuickCaptureSheet`):** Seamless natural language detection during rapid floating capture for Tasks and Reminders.

---

## Todo List & Recommendations

- [ ] **Phase 8: Time & Planning Hub Improvements (Calendar, Tasks, Habits, Timers)**
  - [ ] **Habit Streak Freeze & Rest Day Support:** Allow configuring scheduled rest days (e.g. weekends for workouts) so streaks are preserved without artificial breaks.
  - [ ] **Pomodoro Focus Mode for Timers:** Add 25m work / 5m break interval cycles with focus history log and ambient background white noise (rain, coffee shop, forest).
  - [ ] **Priority & Category NLP Tagging:** Auto-detect priority tags (e.g. `!urgent`, `!high`) and category hashtags (e.g. `#work`, `#health`) from titles.
  - [ ] **Interactive Subtask Drag-and-Drop:** Allow reordering subtasks inside task details screen with smooth drag handles.
  - [ ] **Interactive Week Calendar Strip:** Horizontal scrolling 7-day strip at the top of the Tasks and Calendar views for instant day switching.

- [ ] **Phase 9: Organize, Notes & Personal Money Management (UI/UX Boosts)**
  - [ ] **Markdown Live Preview for Notes:** Rich rendering of headers, bold text, bullet points, and code spans in note cards.
  - [ ] **Wishlist Savings Target Calculator (Money Management Tracker):** Add a savings progress tracker to wishlist items showing percentage saved toward target price and estimated days left (strictly personal budgeting calculation, zero banking/payment integrations).
  - [ ] **Personal Monthly Budget Allocation Visualizer (Money Management):** Local-first monthly budgeting bucket summary (e.g. 50/30/20 budget envelope allocation) calculating discretionary vs savings targets without bank syncing.
  - [ ] **One-Tap List Sharing / Export:** Export custom packing or shopping lists as cleanly formatted plain text or markdown to device share sheet / clipboard.
  - [ ] **Note Search Keyword Highlighting:** Highlight matching search terms directly in note cards and search results.
  - [ ] **Custom Category & Color Palette Builder:** Allow users to create custom categories with custom hex colors and custom icons beyond predefined sets.

- [ ] **Phase 10: Journal, Diary & Privacy Hardening (Next Milestones)**
  - [ ] **Local Photo Attachment for Memories:** Allow attaching 1-3 local photos to diary entries and milestone records stored in app sandbox.
  - [ ] **Auto-Lock Inactivity Timeout:** Configurable auto-lock delay (immediately, 1 minute, 5 minutes after leaving diary) to re-engage security PIN.
  - [ ] **Mood Filter & Keyword Search:** Filter reflections by mood emoji and search gratitude notes with matching keyword highlights.
  - [ ] **Memory Voice Audio Memos:** Record short 30-second local voice memos attached to memories and diary entries.

- [ ] **Phase 11: Everyday Wellness & Contextual Assistance**
  - [ ] **Smart Departure Heads-Up:** Push notification 15 minutes before scheduled calendar events reminding the user to check their *BeforeYouGo* list (Keys, Wallet, Charger).
  - [ ] **Hydration Schedule Reminders:** Gentle periodic notifications (every 90 minutes between 8 AM and 9 PM) to drink water until daily target is met.
  - [ ] **Optimal Bedtime Wind-Down Alert:** Push notification 30 minutes before recommended sleep cycle target to dim lights and prepare for sleep.

- [ ] **Phase 12: Visual Branding, Audio & Platform Hardening**
  - [ ] **App Onboarding / Welcome Hero Screen:** Display the brand banner (`assets/banner.jpg`) on first app launch with a brief feature tour.
  - [ ] **Vector Brand Assets (SVG):** Add vector SVG versions of the Nestin logo for lossless scaling on desktop and web builds.
  - [ ] **Android Glance AppWidgets:** Home screen widgets for Next Alarm countdown, Daily Habit checklist, and 1-tap Quick Capture.
  - [ ] **In-App Audio Trimming Tool:** Allow trimming imported MP3 files (e.g. starting at chorus/intro) with interactive waveform scrubber.
  - [ ] **High-Fidelity Audio Asset Pack:** Bundle custom offline audio files for rooster dawn crow, ambient rain, forest stream, and temple bells in `assets/sounds/`.
  - [ ] **Waveform Visualizer:** Visual animated audio equalizer during alarm playback and ringtone preview.
  - [ ] **Automated Weekly Backup Reminder:** Gentle weekly notification suggesting export of full JSON life backup.
  - [ ] **Flip/Shake to Snooze:** Accelerometer-based physical gestures with sensitivity calibration.
  - [ ] **Pre-Alarm Sunrise Simulation:** Gentle screen brightness ramping from 0% to 100% warm amber before audio starts.
  - [ ] **OEM Background Killer Hardening:** Foreground service workarounds for aggressive battery optimizations on Xiaomi, Samsung, and Huawei devices.
  - [ ] **iOS Critical Alerts Entitlement:** Setup entitlement instructions for bypassing Do Not Disturb mode on iOS when authorized.
