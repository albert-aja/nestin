# Nestin — Personal Everyday Space & Universal Alarm Platform

> **Tagline:** Every moment, right on time.  
> **Brand Direction:** Universal alarms, smart wake-up intelligence, contextual planning, personal organization, everyday reflection, curated wishlists, and wellness tools. Warm, inviting sanctuary aesthetic inspired by the comfort of nesting, with a clean, focused, privacy-respecting local-first architecture.  
> **The Mascot Flock:** Six specialized bird companions guiding users across six core life domains: **Roo** (Time & Planning), **Scout** (Everyday Assistance), **Seren** (Personal Wellness), **Pippin** (Personal Interests), **Twill** (Notes, Organization & Personal Money Management), and **Echo** (Journal & Memories).

---

## Project Overview & Architectural Explanations

Nestin is a unified **Personal Everyday Space** that integrates high-reliability alarms, intelligent wake-up gates, daily planning, personal knowledge organization, wellness habits, curated wishlists, and reflective memory journaling into one cohesive home. It bridges the gap between disconnected daily utilities by giving users one serene space for their day: wake up on time, track routines, manage tasks, explore personal interests, organize curated wishlists and checklists, record memories, and prepare for daily departures without bloat or unwanted online dependencies.

### Core Architectural Decisions & Design Patterns

1. **Strict Feature Preservation:**
   - The entire smart alarm engine (gradual volume ramping, challenge engine with arithmetic/memory/typing gates, snooze limits, custom sound import into app sandbox, full-screen active alarm interceptor) is preserved without regression.

2. **Modular, Feature-Oriented Clean Architecture:**
   - **Framework:** Flutter 3.44+ (Dart 3.12+) targeted primarily for Android, iOS, and cross-platform mobile environments.
   - **State Management:** Reactive `ChangeNotifier` and `Provider` pattern with single-responsibility providers (`AlarmProvider`, `ReminderProvider`, `TimerProvider`, `SettingsProvider`, `SoundProvider`, `CalendarProvider`, `TaskProvider`, `RoutineProvider`, `NoteProvider`, `CollectionProvider`, `JournalProvider`, `DashboardProvider`, `WearableProvider`, `ReadingProvider`, `GeofenceProvider`, `BeforeYouGoProvider`, `MoneyProvider`).
   - **Persistence Layer:** Structured, local-first JSON document persistence managed by `StorageService` using `SharedPreferences` (including versioned schema migrations via `migrateMoneySchemaIfNeeded()`, atomic snapshot rollback commits via `commitMoneyLedgerAtomically()`, and full JSON backup export/restore). Guarantees zero-latency cold starts, resilient background recovery, and seamless offline functionality without SQLite migration locks.
   - **Local Backup & Restoration Engine:** Dedicated full backup serialization (`exportFullBackupJson` and `restoreFullBackupJson`) allowing users to export their entire personal life data into an offline JSON backup file and restore it on any device.

3. **Domain Abstractions & Extensibility:**
   - **Weather Abstraction:** `WeatherProviderInterface` decoupling current weather presentation from third-party APIs. Implemented with `LocalWeatherService` delivering immediate, context-aware forecasts and advice.
   - **Sleep Cycle Engine:** `SleepCycleCalculator` computing optimal 90-minute REM sleep cycles and 14-minute sleep latency to suggest restorative bedtime and wake-up target windows.
   - **Quick Capture Integration:** Global multi-entity sheet (`QuickCaptureSheet`) allowing instant creation of Notes, Tasks, Reminders, Journal entries, or Wishlist items from anywhere in the app.
   - **Universal Real-Time Search:** Cross-module indexing (`UniversalSearchScreen`) that queries Notes, Tasks, Calendar Events, Journal entries (respecting private/custom lock masking), Collections & Packing Lists, Wishlist items, Reading List items, Location Reminders & Saved Places, BeforeYouGo Trips & Presets, Money Accounts & Transactions, Phone Modes, Automations, and Alarms simultaneously with categorized search result pills.
   - **Wearable Health Telemetry:** Decoupled `WearableHealthServiceInterface` with `LocalWearableHealthService` supporting native platform channel bridges (`com.nestin.app/wearables`) and simulated test sandboxes for step counts, sleep duration, and hydration syncing.

4. **Flock Companion Architecture & Domain Ownership:**
   - Features, screens, and empty states are organized into **6 Mascot Domains**.
   - Each mascot represents a personality archetype, visual color accent, and functional responsibility, giving users a warm, emotionally supportive everyday environment.

5. **Adaptive Light/Dark Material 3 Theme Engine & Surface Token Architecture (`AppColors`, `AppTheme`, `UserPreferences`, `SettingsProvider`, `SettingsScreen`):**
   - **Default Dark Theme (`ThemeMode.dark`):** Built around a Charcoal/Obsidian dark palette in `lib/core/theme/app_colors.dart` (`darkBg`: `#111215`, `darkRecessed`: `#141519`, `darkSheet`: `#16171D`, `darkCard`: `#1A1B20`, `darkPanel`: `#1E2028`, `darkCardElevated`: `#23252C`, `darkTrack`: `#252834`, `darkBorder`: `#2D303A`) paired with Nestin Crimson (`#E04A3A`) primary and Sunrise Amber (`#FF9E1B`) secondary accents, functional semantic tokens (`success`, `warning`, `error`, `info`), and 6 alarm category colors.
   - **Crisp Light Palette & Context-Aware Adaptive Helpers (`AppColors`):** Mirrors the dark elevation ladder with a structured daylight palette (`lightBg`: `#F4F6F9`, `lightRecessed`: `#EAEEF4`, `lightSheet`: `#FFFFFF`, `lightCard`: `#FFFFFF`, `lightPanel`: `#F1F4F8`, `lightCardElevated`: `#E9EDF4`, `lightTrack`: `#DDE3EC`, `lightBorder`: `#DCE1EA`) and high-contrast daylight inks (`lightTextPrimary`: `#181A20`, `lightTextSecondary`: `#5A6170`, `lightTextMuted`: `#6E7585`). Static helpers (`isDark`, `scaffoldBg`, `recessedSurface`, `sheetSurface`, `cardSurface`, `elevatedSurface`, `trackSurface`, `border`, `subtleFill`, `scrimHandle`, `textPrimary`, `textSecondary`, `textMuted`, and `adaptive(dark: ..., light: ...)`) automatically track `Theme.of(context).brightness`.
   - **Theme Definitions (`lib/core/theme/app_theme.dart`):** `AppTheme.darkTheme` and `AppTheme.lightTheme` (`useMaterial3: true`) configure scaffold backgrounds, full Material 3 `ColorScheme.dark` / `ColorScheme.light` container slots, flat outlined `CardThemeData` (`18dp` radius), `BottomSheetThemeData` (`24dp` top radius), adaptive `ChipThemeData`, rounded dialogs (`24dp` radius), fixed bottom navigation bar styling, filled input decoration themes, and custom `SwitchThemeData`.
   - **Persistence & Live Runtime Switching:** `UserPreferences.themeMode` (`lib/data/models/user_preferences.dart`) defaults to `ThemeMode.dark`, serializes via `'themeMode': themeMode.name` through `StorageService`, and updates reactively via `SettingsProvider.setThemeMode(ThemeMode)` (`lib/providers/settings_provider.dart`) wired directly to `MaterialApp(theme: AppTheme.lightTheme, darkTheme: AppTheme.darkTheme, themeMode: settings.themeMode)` in `lib/main.dart`.
   - **Settings UI Controls:** `SettingsScreen` (`General Preferences -> Theme Mode`) exposes live switching across `Dark`, `Light`, and `System` modes without requiring app restart.
   - **Full Light/Dark Surface Token Audit & Regression Guard:** Eliminated hardcoded dark surface hexes and white-on-light text leaks across all primary hubs (`HomeDashboardScreen`, `ExploreHubScreen`, `OrganizeHubScreen`, `TimeHubScreen`, `JournalHubScreen`, `MoneyHubScreen`, `MainNavigationScreen`), sub-screens (`WishlistScreen`, `CalendarScreen`, `SettingsScreen`, `TasksScreen`, `RemindersListScreen`, `NotesListScreen`, `CollectionsListScreen`, `DiaryEntriesScreen`, `MemoriesScreen`, `TimelineScreen`, `AlarmsListScreen`, `AlarmEditScreen`, `RoutinesScreen`, `TimersScreen`, `PomodoroView`, `UniversalSearchScreen`), wake-up challenge widgets (`ChallengeModalDialog`, `MathChallengeWidget`, `MemoryChallengeWidget`, `TypingChallengeWidget`), and modal sheets/cards (`QuickCaptureSheet`, `HydrationSettingsSheet`, `SleepCycleSheet`, `HealthWellnessSheet`, `MedicationTrackerSheet`, `HobbyPracticeSheet`, `ReadingTrackerSheet`, `WearableSyncSheet`, `OemHardeningSheet`, `SecurityPinGateSheet`, `LocationRemindersSheet`, `MoneyEditorDialogs`, `SoundPickerSheet`), while intentionally preserving `ActiveAlarmScreen`'s bedside dark surface (`#0F1014`). Added adaptive daylight gradients for dashboard hero banners (`Morning Briefing`, `Next Alarm`) and Twill's champagne balance hero card, deeper amber ink (`#B45309`) for legible daylight highlights, fixed `CalendarScreen` BeforeYouGo sheet `Material` wrapping and `HomeDashboardScreen` `CalendarEvent.formattedTime()` agenda rendering, and verified Light/Dark fidelity in `test/adaptive_theme_test.dart`.

6. **Offline-First Dual Language Localization Engine (`AppLanguage`, `AppLocalizations`, `flutter_localizations`):**
   - **Supported Languages (`lib/core/l10n/app_language.dart`):** Supports **English (`en_US`)** (`AppLanguage.en`) and **Bahasa Indonesia (`id_ID`)** (`AppLanguage.id`) 100% offline with zero network dependency, providing `.code`, `.locale`, `.dateLocale`, `.nativeName`, `.shortCode`, `.flag`, and tolerant `AppLanguageExt.fromCode` parsing (`en`, `id`, `id_ID`, legacy `in`, `"Indonesian"`, `"Bahasa Indonesia"`).
   - **Dictionary, Date Formatting & Safe Resolution (`lib/core/l10n/app_localizations.dart`, `lib/core/l10n/app_translations.dart`):** Centralizes core UI strings in `kNestinTranslations` (`tr(key, [params])` with `{placeholder}` interpolation), offers `pick(en, id)` for concise contextual strings, formats dates in English or Bahasa Indonesia (`Januari`, `Minggu`, etc.) via `formatDate(date, pattern)` backed by `flutter_localizations` + `intl` (`AppLocalizations.ensureDateFormatting()`), translates `AlarmCategoryType` and `ThemeMode` labels, and gracefully falls back inside isolated widget tests that omit `localizationsDelegates` or `SettingsProvider` (`context.l10n`).
   - **Persistence, Live Switching & Backup Portability:** `UserPreferences.language` (`lib/data/models/user_preferences.dart`) defaults legacy profiles to `AppLanguage.en`, persists locally in `StorageService`, and is preserved across full backup export/restore (`exportFullBackupJson` / `restoreFullBackupJson`). `SettingsProvider.setLanguage(AppLanguage)` (`lib/providers/settings_provider.dart`) updates `MaterialApp.locale`, `supportedLocales`, and `localizationsDelegates` (`lib/main.dart`) live without restart, controlled by a 1-tap `🇺🇸 English` / `🇮🇩 Bahasa Indonesia` selector in `SettingsScreen` (`General Preferences -> App Language / Bahasa Aplikasi`).
   - **Cross-App Coverage & Verification:** Localizes the navigation shell (`MainNavigationScreen`), Home (`HomeDashboardScreen`), hub headers/tabs (`TimeHubScreen`, `OrganizeHubScreen`, `JournalHubScreen`, `ExploreHubScreen`), `UniversalSearchScreen`, `QuickCaptureSheet`, Twill Money hub & summary (`MoneyHubScreen`, `MoneySummaryCard`), mascot cards (`BeforeYouGoCard`, `LocationRemindersCard`, `ReadingProgressCard`, `HydrationSparklineCard`, `SerenWellnessSummaryCard`), primary sub-screens (`AlarmsListScreen`, `TasksScreen`, `CalendarScreen`, `NotesListScreen`, `DiaryEntriesScreen`), and shared badges (`CategoryBadge`, `NestinBrandHeader`), verified in `test/dual_language_test.dart`.

7. **Multi-Application Monorepo, NestJS Backend, Admin CMS & Supabase Foundation (`apps/mobile`, `apps/backend`, `apps/admin`, `infrastructure/supabase`, `packages/contracts`, `docs/`, `scripts/`):**
   - **Monorepo Restructuring & Unified Validation:** Relocated the entire Flutter application intact into `apps/mobile/` (preserving all 6 mascot domains, Android/iOS native plugins, `assets/`, and `source_art/`) alongside `apps/backend/` (Node.js/TypeScript/NestJS REST API `/api/v1` + Swagger `/api/docs`), `apps/admin/` (React + TypeScript + Vite Inspiration & Moderation Admin CMS), `infrastructure/supabase/` (PostgreSQL schema migrations, RLS policies, idempotent `seed.sql`, `config.toml`), `packages/contracts/` (shared API & P1 sync TypeScript/Dart contracts), `docs/` (`SYSTEM_ARCHITECTURE.md`, `LOCAL_AUDIT_REPORT.md`, `SUPABASE_SCHEMA.md`, `BACKEND_API.md`, `0001-local-first-monorepo-and-supabase.md`), and `scripts/dev-check.ps1` (one-command monorepo validation for Flutter analyze/tests + NestJS typecheck/build/tests).
   - **Unified `Nestin` Naming, Package IDs & Automatic Storage Key Migration:** Standardized mobile platform identifiers (`com.nestin.app` across Android `namespace`/`applicationId`/Kotlin packages, iOS `PRODUCT_BUNDLE_IDENTIFIER` & `CFBundleDisplayName`, macOS, Linux, Windows, and `.idea`), removed legacy `RooDooBrandHeader`/`RooDooApp` aliases in favor of `NestinBrandHeader` (`SettingsScreen`, `nestin_brand_header.dart`), and unified all `StorageService` `SharedPreferences` keys under `nestin_*_v1` with automatic one-time `migrateLegacyStorageKeysIfNeeded()` preservation on `StorageService.init()`.
   - **Strict Local-First & Guest-First Architecture (`AppEnvironment`, `SyncMetadata`, `GuestIdentityProfile`, `BackendGatewayService`):** Personal everyday data remains persisted on-device inside `StorageService` (`SharedPreferences`) with zero mandatory authentication or backend dependency. On first launch, `BackendGatewayService.ensureGuestIdentity()` auto-provisions a local UUID (`guestLocalId`), and optional guest-to-registered linking (`POST /api/v1/auth/guest-migration/prepare`) keeps `cloudSyncOptIn = false` unless explicitly opted in during future P1 work.
   - **Optional Account Sign-In & Guest Migration UI (`AccountProvider`, `BackendGatewayService`, `NestinAccountSettingsTile`, `NestinAccountSheet`, `SettingsScreen`):**
     - **Dependency-Free Supabase Auth & Migration Client (`lib/data/services/backend_gateway_service.dart`, `lib/core/config/api_contracts.dart`, `lib/core/config/app_environment.dart`):** Extends `BackendGatewayService` with injectable `BackendGatewayConfig` and `BackendHttpTransport` (defaulting to `dart:io` `HttpClient`) to support optional Supabase Auth email/password sign-up (`POST /auth/v1/signup`), sign-in (`POST /auth/v1/token?grant_type=password`), best-effort sign-out (`POST /auth/v1/logout`), honest handling of email-confirmation-pending responses (`SupabaseSignUpOutcome.requiresEmailConfirmation`), and persistent session/receipt storage (`nestin_auth_session_v1`, `nestin_guest_migration_receipt_v1`). `prepareGuestMigration()` invokes `POST /api/v1/auth/guest-migration/prepare` with Bearer JWT, `guestLocalId`, `preferredLanguage`, and read-only record counts from `StorageService.collectLocalRecordCounts()`, receiving `GuestMigrationReceipt` (`localDataPreserved: true`, `cloudSyncOptIn: false`) while strictly leaving every local alarm, task, note, journal, and money record untouched.
     - **Reactive State & Graceful Fallback (`lib/providers/account_provider.dart`, `lib/main.dart`):** `AccountProvider` manages optional authentication, loading indicators, error messaging, guest-link state, and sign-out lifecycle without blocking offline launch, wired into `NestinApp` (`MultiProvider`).
     - **Non-Intrusive Settings Tile & Adaptive Bilingual Modal (`lib/ui/widgets/nestin_account_sheet.dart`, `lib/ui/screens/settings/settings_screen.dart`):** Adds an unobtrusive `"Nestin Account (Optional)"` card near the bottom of `SettingsScreen` (above About Nestin) displaying current `Guest` / `Signed In` / `Linked` status. Tapping opens `NestinAccountSheet` featuring a Local-First Guarantee banner, on-device `guestLocalId` and protected local record counts, Sign Up / Sign In toggle with validation, offline build configuration awareness (`NESTIN_SUPABASE_URL` / `NESTIN_API_BASE_URL`), direct `"Prepare Guest Migration"` / `"Refresh Guest Migration Link"` actions, acknowledgement receipt summary, and `"Sign Out (Keep Local Data)"` using adaptive Light/Dark `AppColors` tokens and full EN/ID translations (verified in `test/optional_account_migration_test.dart`).
   - **P0 NestJS Backend Modules:** Implemented modular strict-TypeScript services with global URI versioning (`/api/v1`), `ValidationPipe`, Helmet, CORS, Throttler rate limiting, structured JSON logging, `AllExceptionsFilter`, `ResponseEnvelopeInterceptor`, and `SupabaseAuthGuard` + `RolesGuard` (future admin role extension point with zero admin UI built prematurely):
     - `auth` (`/api/v1/auth/policy`, `/session`, `/guest-migration/prepare`)
     - `users` (`/api/v1/users/me` GET/PATCH/DELETE soft-delete under RLS)
     - `devices` (`/api/v1/devices`, `/register`, `/:id` revoke under RLS)
     - `content` (`/api/v1/content`, `/:slug` localized guides & templates with fallback catalog)
     - `quotes` (`/api/v1/quotes`, `/featured` EN/ID motivation quote library)
     - `media` (`/api/v1/media`, `/:slug` wallpaper & inspiration card metadata)
     - `remote-config` (`/api/v1/config` min supported version, maintenance status, feature flags)
     - `system` (`/api/v1/system/health`, `/status` readiness & Supabase connectivity probe)
   - **Supabase Schema, Security & P1 Extension Points (`202611140001_initial_foundation.sql`):** Defined UUID PKs, `created_at`/`updated_at`/`deleted_at` conventions, profile provisioning trigger `on_auth_user_created`, indexes, strict per-table Row Level Security (`auth.uid()` owner policies & `public.is_admin()` write gates), and `sync_tombstones` table for future incremental sync. Never exposes `SUPABASE_SERVICE_ROLE_KEY` to `apps/mobile`.

---

## The Nestin Mascot Flock: 6 Core Feature Domains

```
   ┌─────────────────────────────────────────────────────────────────────────────┐
   │                           THE NESTIN FLOCK                                  │
   ├───────────────────────┬─────────────────────────────┬───────────────────────┤
   │ Roo (Rooster)         │ Scout (Carrier Pigeon)      │ Seren (Dove)          │
   │ "The Energetic Starter│ "The Reliable Guide"        │ "The Gentle Companion"│
   │ ⏰ Time & Planning     │ 🧭 Everyday Assistance      │ 🌿 Personal Wellness  │
   ├───────────────────────┼─────────────────────────────┼───────────────────────┤
   │ Pippin (Explorer Dodo)│ Twill (Weaver Bird)         │ Echo (Wise Owl)       │
   │ "The Curious Explorer"│ "The Little Architect"      │ "The Thoughtful Observer"
   │ 🔍 Personal Interests │ 📐 Notes & Organization     │ 📖 Journal & Memories │
   └───────────────────────┴─────────────────────────────┴───────────────────────┘
```

The 6 mascots anchor user workflows across the platform:
- **Roo:** Wakes the user up, drives task momentum, enforces routines, keeps timers running.
- **Scout:** Greets user at dawn, assists daily departures, navigates quick captures, backs up data.
- **Seren:** Calms the mind, tracks hydration, guides sleep cycles, generates soothing ambient sounds.
- **Pippin:** Fuels curiosity, manages reading wishlists, tracks life bucket lists, explores hobbies.
- **Twill:** Structures notes, builds custom collections, organizes ideas, curates personal wishlists and checklists, and oversees everyday manual personal money management (wallets, cash flow ledger, category budgets, recurring templates, and monthly financial summaries).
- **Echo:** Records daily diary reflections, prompts mindfulness, surfaces nostalgic throwbacks, locks secrets behind biometrics.

### Mascot Expression & Interactive System Architecture
1. **6 Standardized Expression States:** Each bird features 6 visual postures: `idle` (gentle breathing hover), `celebrate` (joyful raised wings, sparkle effects), `nudge` (helpful reminder, pointing wing), `sleepy_relaxed` (calm nightcap/closed eyes), `thinking` (analytical chin-tap for searches/NLP), and `alert_surprised` (active alarm or timer zero).
2. **24-Hour Day Cycle Handoff:**
   - *06:00 - 08:30 (Dawn):* **Roo & Scout** wake user up, enforce math challenges, and run customizable BeforeYouGo departure checklists with smart heads-up alerts.
   - *08:30 - 12:00 (Morning):* **Roo & Seren** drive Pomodoro focus sprints and pace hydration intake.
   - *12:00 - 17:00 (Midday):* **Scout & Twill** manage task progress, scheduled agenda, and structured notes.
   - *17:00 - 20:00 (Evening):* **Pippin & Twill** track hobby practice hours, reading lists, and curated wishlists.
   - *20:00 - 22:30 (Dusk):* **Echo** guides mindful reflections, daily prompt carousels, and nostalgic memories.
   - *22:30 - 06:00 (Night):* **Seren** coordinates 30-minute bedtime wind-down, procedural rain audio, and REM sleep cycles.
3. **Interactive Touch Gestures:** Single-tap triggers spring physics bounce with contextual speech bubble quips; double-tap triggers joyful 360° spin with flock chirp; long-press opens domain navigator.
4. **Contextual Dialog Engine:** Dynamic quips tailored to time of day, completion streaks, alarm solves, hydration status, and departure checks.
5. **Mascot Expression & Pose Sticker Library (`assets/mascots/sheets/`):**
   - **Full 6-Bird Asset Coverage (14 Sheets / 84 Poses Registered in `pubspec.yaml`):**
     - **Roo (`roo_expressions_1.jpg`, `roo_expressions_2.jpg`, `roo_expressions_3.jpg` — 18 poses):** Celebrating (`YAY!`), Greeting (`WELCOME!`), Watch Urgency (`HURRY!`), Clipboard Planning (`PLANNING...`), Rest Break (`REST...`), Encouragement (`YOU GOT THIS!`), Whistle Wake-Up (`ALARM!`), Streak Fire (`ON FIRE!`), Drowsy Snooze (`SNOOZED...`), Math Chalkboard (`CHALLENGE!`), Stopwatch Sprint (`FOCUS!`), Flex Celebration (`CRUSHED IT!`), Dawn Sunbeam Stretch (`MORNING!`), Habit Check (`HABIT DONE!`), Idle Clock Confusion (`QUIET DAY`), Workout Dumbbell (`MOMENTUM!`), Post-Sprint Cool Down (`BREAK TIME!`), Flying High-Five (`HIGH FIVE!`).
     - **Seren (`seren_expressions_1.jpg`, `seren_expressions_2.jpg`, `seren_expressions_3.jpg` — 18 poses):** Lavender Welcome (`HELLO!`), Cozy Mug (`TEA TIME!`), Flower Gift (`FOR YOU!`), Sleep Mask (`REST...`), Gentle Wave (`YOU GO!`), Peace Branch (`PEACE!`), Water Glass (`HYDRATE!`), Droplet Crown (`REFRESHED!`), Lotus Meditation (`BREATHE...`), Rainfall Listener (`WIND DOWN`), Moonlit Yawn (`SLEEPY`), Herbal Heart (`GENTLE`), Pill & Water (`DOSE TIME!`), Mood Pebbles (`CHECK-IN`), Overhead Wing Stretch (`STRETCH!`), Eye Rest (`EYE BREAK`), Pine Breeze (`FRESH AIR`), Open Wing Embrace (`BIG HUG!`).
     - **Echo (`echo_expressions_1.jpg`, `echo_expressions_2.jpg` — 12 poses):** Open Star Diary (`REFLECT!`), Glowing Throwback Card (`THROWBACK!`), Idea Lightbulb (`PROMPT!`), Locked Padlock (`SECRET!`), Warm Gratitude (`GRATEFUL!`), Twig Scarf Night (`GOODNIGHT!`), Comforting Tissue (`IT'S OKAY`), Scrapbook Confetti (`MILESTONE!`), Gold Key Unlock (`UNLOCKED!`), Cocoa Unwind (`UNWIND...`), Attentive Listening (`LISTENING`), Archived Yearbooks (`ARCHIVED!`).
     - **Pippin (`pippin_expressions_1.jpg`, `pippin_expressions_2.jpg` — 12 poses):** Magnifying Discovery (`DISCOVER!`), Adventure Book (`READING!`), Passport Gold Stamp (`STAMPED!`), Ukulele Practice (`HOBBY TIME!`), Binocular Scan (`EXPLORING!`), Campfire Mug (`CAMP BREAK!`), Vintage Camera (`SNAPSHOT!`), Milestone Steps (`LEVEL UP!`), Easel Painting (`SKETCHING`), Book Stacks (`DEEP DIVE!`), Shooting Star (`INSPIRED!`), Mountain Flag (`SUMMIT!`).
     - **Twill (`twill_expressions_1.jpg`, `twill_expressions_2.jpg` — 12 poses):** Clipboard Notes (`NOTED!`), Tidy Nest (`ORGANIZED!`), Project Target Goal (`PLANNING!`), Suitcase Checklist (`PACKED!`), Blueprint Scroll (`ARCHITECT!`), Checked Basket (`SORTED!`), Task Folder (`STRUCTURED!`), Pinned Sticky Note (`PINNED!`), Tag Stringing (`TAGGED!`), Empty Basket (`EMPTY!`), Step-by-Step Ruler (`CHECKLIST`), Paper Airplane (`EXPORTED!`). *(Strictly personal organization and checklist visuals — zero financial or banking graphics).*
     - **Scout (`scout_expressions_1.jpg`, `scout_expressions_2.jpg` — 12 poses):** Wing Salute (`READY!`), House Keys & Checklist (`BEFORE YOU GO!`), Express Card Dash (`CAPTURED!`), Glowing Folder Search (`SEARCHING!`), Data Backup Shield (`PROTECTED!`), Opened Map (`BRIEFING!`), Alert Megaphone (`REMINDER!`), Battery Whitelist Check (`GUARDED!`), Leaf Hammock (`FREE TIME!`), Soaring Envelope (`DELIVERY!`), Empty Satchel Shrug (`TRY AGAIN?`), Dawn Perch (`DAWN BRIEF!`).
6. **Clean Alpha-Transparent Sprite Library (`assets/mascots/sprites/` — Completed, 84 PNGs / 1.80 MB):**
   - **Zero Baked-In Text (Pure Pose PNGs):** Sliced all 14 expression sheets (`assets/mascots/sheets/`, kept on disk as source art) into **84 individual RGBA transparent PNG sprites** across `assets/mascots/sprites/` (`roo/` 18, `seren/` 18, `echo/` 12, `pippin/` 12, `twill/` 12, `scout/` 12):
     - *Roo (`roo/*.png`, 18):* `yay`, `welcome`, `hurry`, `planning`, `rest`, `you_got_this`, `alarm`, `on_fire`, `snoozed`, `challenge`, `focus`, `crushed_it`, `morning`, `habit_done`, `quiet_day`, `momentum`, `break_time`, `high_five`.
     - *Seren (`seren/*.png`, 18):* `hello`, `tea_time`, `for_you`, `rest`, `you_go`, `peace`, `hydrate`, `refreshed`, `breathe`, `wind_down`, `sleepy`, `gentle`, `dose_time`, `check_in`, `stretch`, `eye_break`, `fresh_air`, `big_hug`.
     - *Echo (`echo/*.png`, 12):* `reflect`, `throwback`, `prompt`, `secret`, `grateful`, `goodnight`, `its_okay`, `milestone`, `unlocked`, `unwind`, `listening`, `archived`.
     - *Pippin (`pippin/*.png`, 12):* `discover`, `reading`, `stamped`, `hobby_time`, `exploring`, `camp_break`, `snapshot`, `level_up`, `sketching`, `deep_dive`, `inspired`, `summit`.
     - *Twill (`twill/*.png`, 12):* `noted`, `organized`, `saving_up`, `packed`, `architect`, `sorted`, `budgeted`, `pinned`, `tagged`, `empty`, `checklist`, `exported`.
     - *Scout (`scout/*.png`, 12):* `ready`, `before_you_go`, `captured`, `searching`, `protected`, `briefing`, `reminder`, `guarded`, `free_time`, `delivery`, `try_again`, `dawn_brief`.
   - **Automated + Surgical Per-Cell Cleaning:** Stripped 100% of bottom bold captions, comic speech bubbles + pointer tails (`pippin_expressions_1.jpg`, `scout_expressions_1.jpg`, `twill_expressions_1.jpg`), floating black speech text, `z Z` glyphs, double `"How's your heart?"` text, `twill/tagged` `"Teap"` tag typo (cleanly filled with matching sage green), white die-cut sticker rims & cast shadows (`seren_expressions_3.jpg`, `echo_expressions_2.jpg`), flat beige ground ovals on all 12 Pippin poses, choppy yellow sunburst wedges on `seren/big_hug` and noisy yellow outer spray around `scout/guarded`, plus trapped interior cream pockets between legs (`seren/gentle`, `seren/peace`, `echo/grateful`, `echo/listening`, `scout/protected`, `scout/reminder`, `scout/dawn_brief`, `twill/empty`, `twill/checklist`, `twill/organized`, `pippin/inspired`), inside `roo/quiet_day` clock handle/leg, `roo/break_time` elbow loop, `pippin/sketching` tripod easel legs, and `pippin/summit` flagpole gap, with anti-aliased edge color decontamination for seamless display on Dark (`#1A1B20`) and Light (`#FFFFFF`) cards.
   - **Indexed RGBA PNG & Bundle Slimming (`pubspec.yaml`):** Quantized all 84 sprites to visually lossless 256-color indexed RGBA PNGs (`1.80 MB` combined total vs ~8 MB raw sheets), registered all 6 `assets/mascots/sprites/<bird>/` directories in `pubspec.yaml`, and removed `assets/mascots/sheets/` from `pubspec.yaml` runtime assets to keep mobile bundles lean.
7. **APK Bundle Slimming & Asset Architecture (`pubspec.yaml` & `source_art/mascots/sheets/`):**
   - **Exclusion of Heavy Raw Sheets (~7.6 MB Savings):** Moved all 14 raw expression sheets (`echo_expressions_1/2`, `pippin_expressions_1/2`, `roo_expressions_1/2/3`, `scout_expressions_1/2`, `seren_expressions_1/2/3`, `twill_expressions_1/2`) from `assets/mascots/sheets/` into `source_art/mascots/sheets/` outside the Flutter runtime asset directory.
   - **Lean Runtime Declaration:** Updated `pubspec.yaml` to explicitly register only individual runtime assets (`assets/logo.jpg`, `assets/banner.jpg`, `assets/mascots/flock_mascots.jpg`) and the 6 quantized sprite folders (`assets/mascots/sprites/roo/`, `seren/`, `echo/`, `pippin/`, `twill/`, `scout/`).
   - **Asset Integrity Test Suite (`bundle_slimming_asset_test.dart`):** Automated regression tests verifying that raw sheets do not exist in runtime `assets/`, source art is safely preserved under `source_art/`, all 84 PNG sprites exist totaling under 2.0 MB, and `pubspec.yaml` excludes `sheets`.
8. **Widget & UI Integration Blueprint (Started in Inspiration; App-Wide Rollout Next):**
   - **Inspiration Mascot Domain Mapping (`lib/ui/widgets/inspiration/mascot_helper.dart`):** Already maps all 6 mascot domains (`roo`, `seren`, `echo`, `pippin`, `twill`, `scout`) via `inspirationMascotFor()` to representative PNG sprites (`morning.png`, `peace.png`, `grateful.png`, `inspired.png`, `noted.png`, `dawn_brief.png`) and domain accents for `QuoteCardStudioScreen` and `InspirationExploreCard`.
   - **Shared `MascotSpriteView` + Separate `MascotSpeechBubble` (Flutter Dialog Balloon):** A reusable sprite widget pairs size presets (32–48dp badges, 64–88dp sheet headers/banners, 120–160dp empty states/alerts) with a subtle radial category-tinted halo backdrop in Dark Mode so dark ink outlines stay high-contrast. Speech text is rendered separately in a Flutter dialog balloon widget (`CustomPainter` tail + theme-matched surface & border) anchored dynamically beside or above the bird (with optional tap-to-cycle quips or hide-balloon mode for tight UI slots).
   - **Core Placement Layers Across Nestin Screens:**
     - *Empty States (`MascotEmptyState`):* Clean illustration + native Flutter title/subtitle/action button across `alarms_list_screen.dart`, `tasks_screen.dart`, `notes_list_screen.dart`, `wishlist_screen.dart`, `diary_entries_screen.dart`, and `universal_search_screen.dart`.
     - *Sheet Headers & Inline Companions:* Compact sprites in `quick_capture_sheet.dart`, `hydration_sparkline_card.dart`, `medication_tracker_sheet.dart`, `sleep_cycle_sheet.dart`, `journal_prompt_carousel.dart`, `throwback_section.dart`, `oem_hardening_sheet.dart`, `oem_warning_banner.dart`, and `security_pin_gate_sheet.dart`.
     - *Active Timers, Alarms & Celebrations:* Larger expressive poses inside `active_alarm_screen.dart`, `challenge_modal_dialog.dart`, `pomodoro_view.dart`, and `nestin_brand_header.dart` (`home_dashboard_screen.dart`), with Twill strictly representing personal wishlist, notes, and project organization (zero banking/payment activities).

---

## Detailed Feature Explanations by Group

### Group 1: Time & Planning (Mascot: Roo — "The Energetic Starter")

*Roo is the spirited rooster with a headband, whistle, and wristwatch. Roo champions morning momentum, punctuality, focused productivity, and structured daily rhythm.*

- **Universal Alarm Engine (Preserved & Enhanced):**
  - Full CRUD operations: create, edit, toggle enable/disable, duplicate, and delete alarms.
  - Recurrence engine: One-time, Daily, Weekdays (Mon-Fri), Weekends (Sat-Sun), and Custom Days picker.
  - Multi-category support: Wake Up, Work, Personal, Health, Activities, and Other.
  - Audio & Volume Ramping: Volume slider (10% to 100%), gradual volume increase ramp (30s to 120s), and choice of asset tones or imported device audio.
  - Snooze control: Configurable snooze intervals (5m, 9m, 10m, 15m) and maximum snooze counters (1, 2, 3, 5, or unlimited).
  - Full-screen active alarm interceptor (`ActiveAlarmScreen`) taking over the display with vibration and audio when alarms fire.
- **Custom Audio Import & Isolation:**
  - `SoundPickerSheet` enables picking MP3, WAV, M4A, OGG, and AAC files directly from device storage.
  - Clones picked audio into app persistent sandbox (`<appDocsDir>/custom_sounds/`) with unique IDs, preventing broken paths if device files are modified.
- **Roo Morning Crow Alarm Tone & Procedural Tone Synthesis (`RooAlarmToneService` & `AudioService`):**
  - **Signature Mascot Wake-Up Crow:** Custom high-fidelity 44.1 kHz 16-bit PCM dawn rooster crow ("Cock-a-doodle-doo!") designed as Roo's signature alarm tone.
  - **Acoustic Avian Syrinx Modeling:** Synthesizes 4 expressive vocal syllables (the punchy "Cock" attack, short transition "a", soaring ascent "doodle", and sustained high-energy cry "dooooo" with 5.8 Hz natural vibrato, tremolo, brassy saturation, and breath resonance).
  - **Zero-Dependency Asset Bundling:** Pre-rendered pristine WAV assets bundled directly in `assets/sounds/` (`rooster_dawn.wav`, `rooster_crow.wav`, `gentle_breeze.wav`, `digital_pulse.wav`, `bell_chime.wav`, `energetic_beat.wav`).
  - **On-Demand Local Fallback Generation:** `RooAlarmToneService.getOrCreateToneFile()` synthesizes and caches missing tone files in internal app storage on-the-fly in under 50ms, guaranteeing alarms never fail or remain silent even in headless or restricted storage environments.
  - **Enhanced Ringtone Picker UI:** `SoundPickerSheet` features dedicated mascot signature styling, rooster dawn badges, sun icons, and 1-tap tone preview.
- **Smart Wake-Up Challenge Gates (`ChallengeEngine`):**
  - **Mathematical Challenges:** Generates dynamic addition, subtraction, and multiplication arithmetic problems scaled across Easy, Medium, and Hard tiers with custom in-dialog numeric keypad.
  - **Pattern Memory Challenges:** Interactive 4-pad color sequence memory game testing user recall with escalating sequence lengths.
  - **Word Typing Challenges:** Motivational phrase typing challenge with real-time text matching validation ("Every moment, right on time with Nestin.").
  - **Inheritance & Override System:** Dual-tier architecture where alarms inherit the global default challenge profile or define custom overrides.
- **Smart Reminders System:**
  - Contextual reminders with title, notes, due date, due time, and category tags.
  - Recurrence engine supporting Daily, Weekdays, Weekly, Monthly, or One-time schedules. Recurring reminders automatically advance to the next occurrence when checked off.
  - Overdue warning pills and segmented filters (All, Pending, Completed).
  - **Unified Swipe & Undo Protection (`SwipeActionCard`):** Swiping right completes one-time reminders, reopens completed ones, or advances recurring reminders to their next schedule (`Next Due`), while swiping left (or tapping delete) removes the reminder with a 4-second floating `Undo` snackbar restoring the exact pre-action `Reminder` snapshot (`ReminderProvider.restoreReminder`) and OS notification schedule.
- **Calendar & Everyday Events:**
  - Full calendar date selector with interactive day picking.
  - Event details: title, description, start time, end time, location, category badge, and reminder toggle.
  - Sorted chronological day agenda view with visual time spans.
- **Tasks & To-Do Management:**
  - Structured tasks with priorities (Urgent, High, Medium, Low), due dates, and optional time.
  - Subtask checklist support with progress calculation (`completed/total`).
  - Filter tabs for Pending vs Completed tasks with strike-through styling.
  - **Unified Swipe & Undo Protection (`SwipeActionCard`):** Swiping right completes pending tasks or reopens completed tasks, and swiping left (or tapping delete) removes tasks with a 4-second floating `Undo` snackbar backed by `TaskProvider.restoreTask` for exact index and completion-state recovery.
- **Daily Habits & Routines:**
  - Morning, Evening, and Custom routine templates.
  - Multi-step routine checklist with daily step completion tracking.
  - Streak tracking counter with automatic daily rollover detection and fire badge (`🔥 X day streak`).
- **Concurrent Timers & Pomodoro Focus Engine:**
  - **Pomodoro Focus Interval Engine:** Classic 25m work sprint / 5m short break intervals with automatic transition to 15m long break after 4 full cycles.
  - **Dynamic State Machine:** `TimerProvider` managing `FocusPhase.work`, `FocusPhase.shortBreak`, and `FocusPhase.longBreak` with color-coded sanctuary themeing (Flame/Crimson `#E04A3A`, Emerald `#10B981`, Cyan `#06B6D4`).
  - **Circular Progress Ring:** 220px high-contrast animated circular indicator displaying remaining time (`MM:SS`), cycle dot matrix (`Cycle X of 4`), and customizable task label.
  - **Customizable Intervals:** Modal dialog adjusting Work Sprint (1-90m), Short Break (1-30m), and Long Break (5-60m).
  - **Focus History Log:** Completing work sprints automatically logs `FocusSessionLog` capturing task label, duration, timestamp, and ambient noise utilized.
  - **Preserved Multi-Timers:** Multi-instance concurrent countdown timers with quick presets: Tea (1m), Eggs (3m), Rest (5m), Break (10m), Focus Sprint (25m).
- **Natural Language Scheduling (`NaturalLanguageDateParser`):**
  - Deterministic regex & token extraction engine detecting relative days (*today*, *tomorrow*, *in 2 days*), clock times (*3pm*, *16:30*), and diurnal periods (*morning*, *noon*, *tonight*).
  - Integrated into Tasks, Calendar, and Quick Capture with real-time detection chips (`NlpDateDetectorChip`).
- **Android Glance Time Widgets:**
  - **Next Alarm Countdown Widget (`NextAlarmWidgetProvider`):** Hero digital clock, AM/PM tag, live countdown pill ("in 7h 15m"), and 1-tap deep link to `nestin://alarms`.
  - **Habit Checklist Widget (`HabitChecklistWidgetProvider`):** Glanceable step checklist showing up to 4 routine steps with checkmark indicators and deep link to `nestin://habits`.

---

### Group 2: Everyday Assistance (Mascot: Scout — "The Reliable Guide")

*Scout is the nimble carrier pigeon with a messenger bag, map, and house key. Scout guides the user through daily transitions, quick inputs, and system navigation.*

- **Centralized Today Dashboard (`HomeDashboardScreen`):**
  - **Brand & Greeting Bar:** Contextual time-of-day greeting (Good morning / afternoon / evening) with official Nestin logo, quick search button, card customizer, and settings access.
  - **Contextual Weather & Date Banner:** Displays current temperature in Celsius, sky condition, current date, and daily lifestyle advice snippet (configurable via `DashboardConfig.showWeather`).
  - **Hero Next Alarm Card:** Live countdown badge, large clock display, alarm label, category badge, required challenge status, and an instant **Test Ring** button to simulate alarm playback.
  - **Metric Overview Strip:** Real-time counters showing active alarms, tasks due today, active reminders, and saved notes with tap-to-navigate routing.
  - **Quick Action Bar:** Direct shortcuts for + Quick Capture and + Alarm.
  - **Today's Agenda Section:** Combines scheduled calendar events and pending reminders due on current date.
  - **Tasks Due Today Section:** Interactive inline checkboxes with priority tags and subtask progress.
  - **Pull-to-Refresh & Haptics:** Pulling down triggers tactile vibration rumble and refreshes countdowns and weather data.
  - **Morning Briefing Greeting Banner:** Early morning awareness with one-tap briefing dialog and audio chime.
- **Universal Quick Capture Sheet (`QuickCaptureSheet`):**
  - Global floating action button launching a multi-entity instant capture modal.
  - Allows rapid 1-tap creation of Notes, Tasks, Reminders, Journal Reflections, or Wishlist items from anywhere in the app without navigating between tabs, plus 1-tap jump shortcuts to Scout *Departure (BeforeYouGo)*, *Location Reminder*, *Alarm*, and Twill *Money Transaction*.
- **Customizable BeforeYouGo Departure Assistant & Smart Heads-Up (`BeforeYouGoProvider`, `DeparturePreset`, `DepartureEvent`, `DepartureSnooze`, `BeforeYouGoCard`, `BeforeYouGoSheet`):**
  - *Customizable Presets & Reorderable Items:* Ships with 4 seeded presets (`Everyday`, `Work`, `Travel`, `Gym`) plus custom user presets with selectable icons and accent colors stored persistently in `StorageService`. Users can add items, edit labels, flag essential items (`isEssential`), reorder items via `ReorderableListView.builder` (`onReorderItem`), check items off inline, run a 1-tap **Mark All Ready** (`markPresetAllReady`), or reset items without losing preset configuration.
  - *Smart Departure Heads-Up Push Notifications (`nestin_departure_channel`):* Schedule recurring routines (every day, Mon–Fri weekdays, weekends, custom ISO weekdays) or one-time trips with customizable notification lead times (`0m`, `5m`, `10m`, `15m`, `20m`, `30m`, `45m`, `60m`, or custom `0–180m` before departure). Schedules rolling 7-day local notifications via `NotificationService.scheduleDepartureNotification` using deterministic FNV-1a cross-isolate IDs (`stableHash31`), prioritizing unchecked essential items inside the notification preview, with a 1-tap `Test Alert` button (`showDepartureNotification`).
  - *Android Notification Shade Inline Actions ("Mark All Ready" & "Snooze 5m"):* Every departure heads-up alert attaches two non-intrusive Android notification actions (`actionDepartureMarkAllReady` -> **Mark All Ready**, `actionDepartureSnooze5m` -> **Snooze 5m**) with `showsUserInterface: false` and `cancelNotification: true` (plus matching `nestin_departure_category` Darwin actions on iOS/macOS). Tapping **Mark All Ready** checks off every item in the linked or active `DeparturePreset`, stamps today's `lastCompletedDateKey` on the departure event, cancels active snoozes and remaining same-day alerts while preserving future recurring days; tapping **Snooze 5m** dismisses the current notification and schedules a repeat +5m follow-up (`DepartureSnooze`, notification ID band `200000–289999`) tracking repeat `snoozeCount`. Both actions work seamlessly while foregrounded (`BeforeYouGoProvider.handleNotificationResponse`) and while terminated/backgrounded (`nestinNotificationTapBackground` -> `NotificationService.handleBackgroundNotificationAction`), syncing immediately into the UI on app resume (`MainNavigationScreen.didChangeAppLifecycleState`). Live snooze countdown pills (`⏰ Snoozed +5m until HH:mm`) and today-ready badges appear directly on `BeforeYouGoCard` and `BeforeYouGoSheet`.
  - *Calendar Event Integration (`CalendarEvent`, `CalendarScreen`):* Optional **Scout BeforeYouGo Heads-Up** toggle, preset picker, and advance lead-time selector directly inside the New Event modal, live clickable Scout pill badges on event cards, 1-tap edit/attach dialog on timed calendar events, and automatic linked departure cleanup when events are deleted.
  - *App-Wide Access, Notification Deep Linking & Backups:* Exposed on both `HomeDashboardScreen` (`DashboardConfig.sectionBeforeYouGo`) and `ExploreHubScreen` via `BeforeYouGoCard`, reachable from `QuickCaptureSheet` (`Departure` chip) and `UniversalSearchScreen`, routed directly into `BeforeYouGoSheet` from `before_you_go|<eventId>|<presetId>` notification payloads or `nestin://before_you_go`, and preserved (presets, events, active preset ID, and active `departureSnoozes`) inside `exportFullBackupJson` / `restoreFullBackupJson`.
- **Location-Based Reminders & Geofence Triggers (`LocationRemindersCard`, `LocationRemindersSheet`, `GeofenceProvider`, `NativeGeofencingService`):**
  - **Designated Places (`SavedPlace` & `PlaceCategory`):** Supports Home, Work, Store, Gym, Transit, and Custom places with coordinate/radius validation and Haversine distance calculation (`distanceMetersTo`).
  - **Trigger Rules (`LocationReminder` & `GeofenceTriggerType`):** Arm reminders for `arrival`, `departure`, or `both` transitions, with configurable cooldown windows, optional one-time auto-disarm behavior, and detailed trigger activity logs (`GeofenceTriggerLog`).
  - **Native Geofencing Platform Bridge (`com.nestin.app/geofencing`):**
    - *Android:* Native Kotlin plugin (`GeofencingPlugin.kt`, `GeofenceRegistry.kt`, `GeofenceBroadcastReceiver.kt`, `GeofenceBootReceiver.kt`) using `LocationManager.addProximityAlert` with Android 12+ `PendingIntent.FLAG_MUTABLE` safety, background notification fallback, device boot re-registration, and runtime permission handling (`ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`).
    - *iOS:* Native Swift `GeofenceManager` inside `AppDelegate.swift` built on `CLLocationManager`, `CLCircularRegion`, and `UNUserNotificationCenter` with `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, and `location` background mode in `Info.plist`.
    - *Service Layer (`GeofencingServiceInterface`):* `NativeGeofencingService` for device execution and `MockGeofencingService` for deterministic simulation and testing.
  - **Provider & Notification Engine:** `GeofenceProvider` synchronizes armed rules with native OS registrations, evaluates coordinate sweeps (`evaluateCoordinateSweep`), drains queued background transition events (`handleTransitionEvent`), dispatches alerts on the dedicated `nestin_geofence_channel` (`NotificationService.showGeofenceNotification`), and supports instant simulated testing (`simulateTrigger`).
  - **Interactive Sheet, Dashboard & App-Wide Integration:**
    - `LocationRemindersSheet` features three tabs (`Triggers`, `Places`, `Activity`) plus a geofence boundary simulator, dedicated editor dialogs (`_LocationReminderEditorDialog`, `_SavedPlaceEditorDialog`), and trigger log management (`clearLogs`).
    - Embedded as a customizable Home card (`LocationRemindersCard`, `sectionLocationReminders = 'location_reminders'`, `DashboardProvider.toggleLocationReminders`) and linked across `ExploreHubScreen`, `RemindersListScreen`, `UniversalSearchScreen`, `QuickCaptureSheet`, `MainNavigationScreen`, and `SettingsScreen`.
  - **Offline Backup Support:** Places, trigger rules, and trigger logs (`savedPlaces`, `locationReminders`, `geofenceLogs`) persist in `StorageService` and round-trip cleanly via `exportFullBackupJson` and `restoreFullBackupJson`.
- **Universal Real-Time Search (`UniversalSearchScreen`):**
  - Real-time cross-module search querying Notes, Tasks, Calendar Events, Journal entries (masking private/custom-locked entries), Collections & Packing Lists, Wishlist items, Reading List items, Location Reminders & Saved Places, BeforeYouGo Trips & Presets, Money Accounts & Transactions, Phone Modes, Automations, and Alarms simultaneously.
  - Categorized search result pills with instant navigation to matched items.
- **Local Data Backup & Restoration Engine:**
  - Dedicated full backup serialization (`exportFullBackupJson` and `restoreFullBackupJson`).
  - Allows exporting full personal life data into an offline JSON backup file or clipboard.
  - Instant offline restoration on any device without database migration locks.
- **1-Tap Quick Capture Widget Bar (`QuickCaptureWidgetProvider`):**
  - Compact 4-tile native Android home screen launcher:
    1. *Note:* Launches `nestin://quick_capture?type=note`.
    2. *Task:* Launches `nestin://quick_capture?type=task`.
    3. *Alarm:* Launches `nestin://new_alarm`.
    4. *Journal:* Launches `nestin://quick_capture?type=journal`.
  - Backed by `WidgetSyncService` deep-link bridge on `com.nestin.app/widgets`.
- **Scout Digital Wellbeing, 5-Level App Restrictions & Phone Mode Orchestrator (`DigitalWellbeingScreen`, `DeviceControlProvider`, `DeviceControlServiceInterface`, `DeviceControlPlugin.kt`, `DeviceControlManager`):**
  - **Usage Telemetry & App Restriction Manager (`TrackedAppRule`, `AppUsageRecord`, `WellbeingDailySnapshot`):** Pre-seeded rules for Instagram, TikTok, YouTube, Facebook, and Mobile Games plus user-added custom packages with configurable daily minute caps, warning threshold percentages (e.g. 80%), and blocked schedules supporting overnight ranges (e.g. `22:30`–`07:00`). Queries live Android `UsageStatsManager` (`queryAndAggregateUsageStats` + `UsageEvents`) when `PACKAGE_USAGE_STATS` is granted, while honestly reporting missing OS entitlements (`FamilyControls`) on iOS.
  - **5-Level Graduated Intervention Ladder (`WellbeingInterventionLevel`):** Supports `trackOnly` (silent measurement), `preLimitWarning` (proactive warning alert on `nestin_wellbeing_channel`), `timedSoftPause` (mindful reflection pause dialog logging user pause vs bypass outcomes), `blockingSchedule`, and `strictModeGuard` (uses supported overlay/shield where permitted, honestly degrading to notifications or OS Digital Wellbeing delegation when restricted).
  - **Phone Mode Orchestrator (`PhoneModeProfile` — `Sleep`, `Work`, `Study`, `Relax`, `Custom`):** Applies Do Not Disturb (`ACCESS_NOTIFICATION_POLICY`), system brightness % and screen auto-lock timeout (`WRITE_SETTINGS`), and app restriction sets with duration timers (`expiresAt`) and 4-way visual capability chips (`Direct`, `Needs Permission`, `System Settings`, `Unsupported`). Includes direct delegation shortcuts to Samsung Modes & Routines / OS Focus settings.
  - **Safe State Restoration & Mid-Session User Override Protection (`StateRestorationSnapshot`):** Captures original pre-mode raw OS DND filter, brightness (`0..255`), and timeout (`ms`) persistently into `StorageService` BEFORE mutating device state. On mode exit or post-restart expiration recovery (`recoverExpiredOrInterruptedModeIfNeeded`), Nestin re-reads current OS state and restores ONLY settings it modified whose live values still match what Nestin applied—preserving manual user adjustments made mid-session.
- **Device Capability Registry & Centralized Permission Center (`PermissionCenterScreen`, `DeviceCapabilityRegistry`):**
  - Inspects Android & iOS runtime capabilities over `MethodChannel('com.nestin.app/device_control')` classifying actions across 4 honest states (`directlySupported`, `permissionRequired`, `delegatedToSystemSettings`, `unsupported`).
  - Organizes permissions into **Required** (`Notifications`, `Exact Alarms`), **Recommended** (`Usage Access`, `Battery Optimization`), and **Optional** (`DND Access`, `Modify System Settings`, `Display Over Other Apps`, `Location`, iOS `FamilyControls`) tiers with plain-language rationales, OS enable instructions, deep-links into native settings, and **Revoked Permission Detection** comparing live state against persisted `PermissionEntry` history.
- **Shared Cross-Family Local Automation Engine (`AutomationProvider`, `AutomationRule`, `AutomationHubScreen`):**
  - Unified automation pipeline evaluating triggers (`timeSchedule`, `alarmDismissed`, `geofenceEnter`, `geofenceExit`, `calendarEventUpcoming`, `appUsageThreshold`, `manual`), conditions (`always`, `weekdayOnly`, `weekendOnly`, `timeWindow`, `activePhoneModeEquals`, `permissionGranted`), retry policies (`AutomationRetryPolicy`), and cross-module actions (`activatePhoneMode`, `endActivePhoneMode`, `sendNotification`, `createTask`, `createReminder`, `logHydration`, `setDndEnabled`, `setBrightness`, `delegateToSystemSettings`).
  - **Safety, Conflict Locking & Rollback:** Enforces `SharedSettingOwnership` priority locks preventing lower-priority rules from overwriting active DND/brightness/timeout/mode owners, gates sensitive actions behind `PendingAutomationConfirmation` alerts surfaced on `HomeDashboardScreen` and `AutomationHubScreen`, validates permissions before execution, and records audit logs (`AutomationExecutionLog`) with 1-tap `Rollback Mode` support.
- **Unified Cross-Module Entity Linking ("Link Everything" — `CrossModuleLinkProvider`, `EntityLink`, `LinkedEntitiesSection`):**
  - Connects `CalendarEvent`, `TaskItem`, `NoteItem`, `Reminder`, `JournalEntry`, `MemoryItem`, `HobbyItem`, `ReadingItem`, `MedicationItem`, `BeforeYouGoPreset`, and `AutomationRule` records bidirectionally without duplicating underlying data.
  - Prevents duplicate pairs and self-links, syncs renamed titles across links, cleans up orphan links automatically on Task/Event deletion, persists across `exportFullBackupJson`/`restoreFullBackupJson`, and integrates directly inside `TasksScreen`, `CalendarScreen`, `NotesListScreen`, and `UniversalSearchScreen` (verified in `test/device_control_and_wellbeing_test.dart` and `test/automation_engine_test.dart`).

---

### Group 3: Personal Wellness (Mascot: Seren — "The Gentle Companion")

*Seren is the serene dove holding a sprig of lavender. Seren fosters physical restoration, hydration, restful sleep cycles, and mental stillness.*

- **Sleep Cycle Calculator & Optimal Bedtime Wind-Down Engine (`SleepWellnessProvider`, `SleepCycleSheet`, `BedtimeWindDownConfig`):**
  - **REM Sleep Cycle Mathematics:** Computes restorative 90-minute REM sleep cycles and 14-minute average sleep latency (5 cycles = 7.5 hours of sleep, 464 total minutes to optimal sweet spot).
  - **Dynamic Wake Source Resolution:** Automatically links with nearest upcoming alarm (`AlarmProvider.nextUpcomingAlarm`) or custom target wake time (default 07:00 AM) to establish ideal sleep and wake windows.
  - **30-Minute Wind-Down Lead Time Alert:** Computes the exact wind-down trigger time (30 minutes prior to optimal bedtime) and schedules a gentle push notification via `nestin_wellness_channel` ("🌙 Seren: Time to unwind! Bedtime in 30 minutes (target: HH:mm for 5 sleep cycles). Dim lights, step away from screens, and prepare for restorative sleep. 🌿").
  - **Tomorrow Lookahead Protection:** If today's calculated alert time has already passed, the engine seamlessly targets tomorrow's schedule so alerts are always armed ahead of time.
  - **Interactive Companion Sheet (`SleepCycleSheet`):** Dual-mode interface displaying recommended bedtimes for target wake time vs wake-up times if sleeping immediately, cycle selector chips (4, 5, 6 cycles), source toggle (Next Alarm vs Fixed 07:00), lead time details, and a 1-tap "Test Wind-Down Nudge" preview button.
  - **Bedtime Wind-Down Ambient Audio Trigger (Seren's Sleep Audio Companion):**
    - *1-Tap Instant Audio Trigger:* Direct 1-tap action directly within `SleepCycleSheet` and on the `ExploreHubScreen` under the Wellness Row to launch 30 minutes of calming ambient sleep audio.
    - *High-Fidelity Procedural Offline Audio:* Leverages `AmbientSoundService` with offline procedural WAV synthesis to play loopable Rainfall (`AmbientSoundType.rain`) or gentle Forest Breeze (`AmbientSoundType.forest`) with zero internet connection or bundle bloat.
    - *30-Minute Auto-Countdown Timer:* Reactive countdown timer in `SleepWellnessProvider` tracking `remainingAudioSeconds` (default 1800s / 30m). Continuously updates remaining duration and automatically stops audio upon timer expiration to ensure uninterrupted restful sleep.
    - *Interactive Sheet Controls:* Features formatted countdown (`MM:SS`), animated linear progress indicator (`audioProgress`), sound switcher chips, volume slider (0% to 100%), and 1-tap start/stop toggle button with tactile feedback.
    - *Explore Hub Mini-Player Banner:* When active, the Explore Hub displays an illuminated active audio badge (`Playing • MM:SS remaining`) with a 1-tap stop action. When idle, shows 1-tap `[🌧️ 30m Rain]` and `[🌲 30m Forest]` shortcuts.
    - *Push Notification & Deep Link Integration:* Scheduled wind-down notifications include ambient audio advice and carry the payload `wind_down_ambient`. Tapping the notification or deep link `nestin://ambient_wind_down` routes to Explore Hub and opens `SleepCycleSheet` with the ambient player ready.
  - **Full Offline Portability:** Configuration serialized in `_keyBedtimeWindDownConfig` and preserved across device migrations with the JSON backup export and restore engine.
- **Hydration Water Tracker & Seren Periodic Schedule Engine (`HydrationProvider` & `HydrationSettingsSheet`):**
  - **Persistent Local-First Hydration Model (`HydrationData`):** Tracks glasses consumed (250ml each), configurable daily target (default 8 glasses / 2000ml), reminder preferences, and calendar date tracking with automatic midnight rollover reset.
  - **Periodic Schedule Engine (Every 90m between 8 AM and 9 PM):** Automatically calculates 9 evenly spaced reminder slots throughout active waking hours (08:00, 09:30, 11:00, 12:30, 14:00, 15:30, 17:00, 18:30, 20:00).
  - **Gentle Seren Wellness Notification Channel:** High-clarity, non-intrusive notification channel (`nestin_wellness_channel`) delivering encouraging reminders ("💧 Seren: Time for a sip! Drink a fresh glass of water (250ml) to stay refreshed. Progress: X/8 glasses.").
  - **Goal Completion Auto-Pause:** Reaching the daily water target automatically cancels all remaining reminder slots for today. If water glasses are decremented back below target, future slots are immediately restored.
  - **Interactive Seren Companion Sheet (`HydrationSettingsSheet`):** Modal dialog with Seren lavender accent, periodic reminders toggle, active slots progress tracker ("X of 9 slots left today"), goal slider (4 to 16 glasses), interval selector (60m, 90m, 120m), and instant 1-tap "Test Seren Nudge" notification button.
  - **Cross-Service Integration:** Automatically syncs hydration volume into `WearableProvider` for connected health platforms, and fully serializes hydration configuration and logs into the local JSON backup and restore engine (`exportFullBackupJson` / `restoreFullBackupJson`).
- **7-Day Hydration Intake Sparkline Chart & Consistency Analysis (`HydrationSparklineCard`, `HydrationData`, `HydrationProvider`):**
  - **Visual 7-Day Sparkline Bar Chart:** Displays weekly hydration intake trend across 7 calendar days (Mon–Sun / trailing 7 days) on both the Today Dashboard (`HomeDashboardScreen`) and Explore Hub (`ExploreHubScreen`).
  - **Daily Intake History Persistence:** Backed by `HydrationData.dailyHistory: Map<String, int>` mapping `YYYY-MM-DD` date keys to glasses logged. Automatically commits updates on every glass increment or decrement, and seamlessly preserves previous day tallies during midnight rollover before resetting the active counter.
  - **Dynamic Visual Status Coding:** Proportional vertical bars with volume labels (e.g. `2.0L`, `1.5L`, `0.5L`). Bars dynamically color-code status: Emerald (`#10B981`) for days meeting or exceeding daily goal, Cyan (`#06B6D4`) for active intake days below goal, Dark Slate (`#334155`) for zero-intake days, and an illuminated white border highlighting Today.
  - **Interactive Day Popover:** Tapping any bar in the sparkline opens a contextual popover badge detailing the exact date, volume consumed in milliliters, glasses logged, and goal completion status (`Goal Met` vs `Below Goal`).
  - **Weekly Hydration Consistency Analytics:**
    - *Consistency Pill Badge:* Shows goal completion ratio and percentage (`X/7d • Y%`) directly in the card header.
    - *Metrics Strip:* Side-by-side summary of Today's Intake (ml / glasses), 7-Day Daily Average (ml/day), and Days Met consistency count.
    - *Qualitative Consistency Rating:* Categorizes weekly hydration rhythm into 4 distinct tiers (*"Consistent Hydration"*, *"Good Hydration Rhythm"*, *"Building Momentum"*, *"Getting Started"*).
    - *Seren Actionable Insight Banner:* Displays encouraging contextual advice based on weekly performance (e.g., celebrating 100% adherence, or suggesting an extra morning glass).
  - **Inline Quick Logging Controls:** Includes 1-tap `-250ml` and `+250ml` buttons with tactile feedback, active progress indicator (`X / Y ml`), and automated background sync to `WearableProvider`.
  - **Dashboard Customization & Reordering:** Integrated with `DashboardConfig.sectionHydration` and `DashboardProvider.toggleHydration`, allowing users to hide, show, or reorder the hydration sparkline card on their Today dashboard.
- **Everyday Reflection & Mood Check-In:**
  - One-tap quick mood check-in on the Today dashboard (`😊 Great`, `🙂 Good`, `😐 Neutral`, `😔 Low`, `😫 Tough`).
  - Appends reflection entries to diary with a floating confirmation notice.
  - **7-Day Mood Trend Sparkline:** Visual bar visualization analyzing emotional consistency and dominant weekly emotions.
- **Procedural Ambient White Noise Engine (`AmbientSoundService`):**
  - Lightweight, procedural 16-bit 22.05 kHz PCM audio synthesis generating artifact-free loopable sound offline without external sound files:
    - *Rainfall (`AmbientSoundType.rain`):* Pink-noise-filtered acoustic drizzle with soft droplet spikes.
    - *Coffee Shop (`AmbientSoundType.coffeeShop`):* Low-frequency warm room resonance with muffled hum.
    - *Forest Breeze (`AmbientSoundType.forest`):* Modulated nature wind rustle blended with bird chirps.
    - *Silent (`AmbientSoundType.none`):* Pure silent countdown.
  - Simultaneous playback with independent volume slider (0% to 100%) running alongside timers.
- **Local Wearable Health Telemetry Integration (`WearableHealthService`, `WearableProvider`, `WearableSyncSheet`):**
  - **Multi-Platform Wearable Abstraction:** Abstract `WearableHealthServiceInterface` connecting to Android Health Connect, Apple HealthKit, and Google Fit native bridges (`com.nestin.app/wearables`) alongside simulated offline test sandboxes.
  - **Local Telemetry Sync:** Pulls step counts, restful sleep duration (hours and minutes), and hydration volume with zero cloud lock-in.
  - **Wearable Sync Modal Sheet (`WearableSyncSheet`):** Intuitive interface on Explore Hub and Settings with active source selector (Apple Health, Health Connect, Google Fit, Simulated Sandbox), connection status indicator, auto-poll frequency, and 1-tap "Sync Now" trigger with real-time feedback.
  - **Automated Health Telemetry Ingestion:** Seamlessly feeds step counts into daily activity metrics and syncs hydration logs with `HydrationProvider`.
- **Medication Schedules & Dosage Tracking (Pill Tracker Engine) (`MedicationItem`, `MedicationLog`, `MedicationSnooze`, `MedicationProvider`, `MedicationTrackerSheet`):**
  - **Comprehensive Dose Prescription Model (`MedicationItem`):** Configurable medication/supplement name, dosage amount, flexible units (pills, mg, ml, drops, mcg, puffs), meal instructions (Before Food, With Food, After Food, Empty Stomach, Any Time), custom color accents, and notes.
  - **Multi-Slot Schedule & Recurrence Engine:** Set multiple daily reminder times (e.g., `08:00, 20:00`) with customizable weekday repeat filters (Daily, Weekdays, Weekends, or specific days of the week).
  - **Dedicated Android Notification Channel (`nestin_medication_channel`):** High-priority alerts delivering actionable dosage guidance ("💊 Seren: Time for Vitamin D3 • Take 1 pill with food. Stay consistent!").
  - **1-Tap Notification & In-App Dose Snooze (`Snooze 15m`, `MedicationSnooze`):**
    - *Actionable Notification Button:* Schedules medication notifications with Android `AndroidNotificationAction` (`actionMedicationSnooze15m = 'medication_snooze_15m'`, `showsUserInterface: false`, `cancelNotification: true`) and iOS `DarwinNotificationCategory` (`nestin_medication_category`), allowing 1-tap postponing by 15 minutes right from the notification shade without opening the app.
    - *Background & Foreground Isolate Sync:* Top-level `@pragma('vm:entry-point')` `nestinNotificationTapBackground` invokes `NotificationService.handleBackgroundNotificationAction` to persist `MedicationSnooze` entries in background isolates using deterministic FNV-1a notification IDs (`MedicationSnooze.regularDoseNotificationId` & `snoozedDoseNotificationId`), while `MainNavigationScreen` calls `reloadFromStorage()` on `AppLifecycleState.resumed` and `MedicationProvider` listens live to `actionResponseStream` when foregrounded.
    - *Repeat Stacking & Auto-Cleanup:* Supports repeated snoozing (`snoozeCount` tracking), shows an amber `"Snoozed until HH:mm"` badge with cancel toggle on `MedicationTrackerSheet` and snooze count on `ExploreHubScreen`, offers a 1-tap in-app `Snooze 15m` button on pending slots, and automatically cancels pending snooze notifications when the user logs `Taken` or `Skipped`.
    - *Direct Notification Routing:* Tapping the medication notification card itself routes `medication_dose:<medId>:<HH:mm>` payloads (or `nestin://medication`) directly to Explore Hub -> `MedicationTrackerSheet`.
  - **1-Tap "Take / Skip" Action Logging:**
    - Instant 1-tap `[✓ Take]` logs the dose with precise timestamp and automatically decrements remaining inventory.
    - 1-tap `[⊘ Skip]` records reason (e.g. fasting, nausea) without penalizing inventory.
    - Full undo support immediately reversing logs and restoring stock counts.
  - **Automated Pill Inventory & Refill Warnings:**
    - Tracks active stock counts in real time.
    - Dynamic low-supply threshold (e.g. `<= 5 pills remaining`) triggers prominent amber refill warnings ("⚠️ Low Supply: Amoxicillin has only 2 pills remaining!").
    - 1-tap interactive refill dialog with quick-refill presets (`+10, +30, +60, +90 pills`).
  - **Adherence Streak & Consistency Analytics:**
    - Tracks consecutive days of 100% adherence with celebratory flame badge (`🔥 X-Day Streak`).
    - 7-day adherence rate calculator displaying percentage compliance over the past week.
  - **Interactive Companion Hub Sheet (`MedicationTrackerSheet` & `AddEditMedicationSheet`):**
    - Dual-tab sanctuary view displaying "Today's Doses" with time-sorted dose cards and "Cabinet" managing prescriptions, inventory, and active toggles.
    - Celebratory Seren banner when all daily doses are completed.
  - **Full Offline Portability:** Persisted in `_keyMedications`, `_keyMedicationLogs`, and `_keyMedicationSnoozes`, fully exported and restored in the local JSON backup engine (`exportFullBackupJson` / `restoreFullBackupJson`).
- **Seren Health Sanctuary — Sleep Tracking, Daily Steps, Body Vitals & Guided Breathing (`SleepLog`, `DailyHealthActivity`, `HealthGoalsConfig`, `VitalLog`, `HealthWellnessProvider`, `SerenWellnessSummaryCard`, `HealthWellnessSheet`):**
  - **Nightly Sleep Architecture & Quality Scoring (`SleepLog`, `SleepQualityRating`):**
    - *Cross-Midnight Session Logging:* Handles bedtime-to-wake-time intervals seamlessly across midnight (`wakeTime.isAfter(bedtime)` normalization) and links logs to wake date (`YYYY-MM-DD`).
    - *Sleep Stage Estimation & Efficiency:* Computes balanced stage breakdowns via `SleepLog.estimateSleepStages` (~20% Deep, ~25% REM, ~55% Light) alongside awake interruptions, sleep efficiency (`sleepEfficiencyPercent`), and completed 90-minute REM cycles (`completedCycles`).
    - *Transparent 0–100 Sleep Score (`SleepLog.computeQualityScore`):* Weights duration vs target (up to 60 pts), sleep efficiency (20 pts), and subjective quality rating (`poor`, `fair`, `good`, `restorative`, `excellent` — 20 pts), plus contextual sleep factors and freeform notes.
    - *Weekly Sleep Debt & Consistency Streaks:* Tracks trailing 7-day nightly durations via an interactive chart, computes `weeklyAverageSleepMinutes`, `weeklyAverageSleepScore`, `weeklySleepDebtMinutes`, and sustained `sleepTargetStreakDays`.
  - **Daily Steps, Distance & Movement Tracker (`DailyHealthActivity`, `HealthGoalsConfig`):**
    - *Step Counter & Calibrated Metrics:* Tracks daily steps against configurable goals (default `8,000` steps), stride-calibrated distance (`strideLengthMeters = 0.762` -> `distanceKmWithStride`), active movement minutes (default `30m` goal), and `estimatedActiveCalories` (`steps * 0.04 + activeMinutes * 4`). Zero-division guards protect all percentage/distance getters.
    - *Instant Quick Logs & 7-Day Activity Analytics:* 1-tap logging increments (`+500`, `+1,000`, `+2,500`, `+15m Walk`), custom step override modal, 7-day trailing step bar chart, weekly totals/averages, and multi-day `stepStreakDays` (preserving yesterday's streak until today closes).
    - *Optional Afternoon Movement Stretch Alert:* Schedules a gentle 15:00 local reminder via `notificationId = 7250` (`nestin_wellness_channel`) carrying payload `seren_health_move` and deep link `nestin://health` to jump directly into Seren Health.
  - **Body Vitals & Daily Energy Check-In (`VitalLog`, `VitalType`):**
    - *Multi-Metric Vital Logs:* Records resting Heart Rate (`bpm`), Blood Oxygen SpO2 (`%`), Blood Pressure (`systolic/diastolic mmHg`), and Body Weight (`kg`) with automatic clinical-reference status badges (`Athletic Low`/`Normal Resting`/`Elevated`, `Optimal SpO2`/`Mildly Low`/`Low Range`, `Normal`/`Elevated`/`High Range`, `Check-In`) and syncs latest resting HR/SpO2 onto the day's `DailyHealthActivity`.
    - *Subjective Energy Check-In:* Tracks 1–5 daily energy ratings (`energyScore`) alongside objective vitals.
  - **Seren Guided Breathing Studio & Mindful Minutes (`HealthWellnessSheet` Breathe Tab):**
    - *Interactive Haptic Breathing Modes:* Switchable **4-7-8 Relaxing Sleep** (`Inhale Nose` 4s, `Hold Breath` 7s, `Exhale Mouth` 8s) and **4-4-4-4 Box Focus** (`Inhale Gently`, `Hold Softly`, `Exhale Slowly`, `Rest Calmly` 4s each) guided timer with smooth breathing animation and phase-shift tactile feedback (`HapticFeedback`).
    - *Mindful Minute Persistence:* Stopping a session saves accumulated mindful minutes onto today's `DailyHealthActivity`, alongside a 1-tap `+5m Calm` quick button.
  - **Composite Seren Daily Wellness Score (0–100) & Contextual Insights:**
    - `computeDailyWellnessScore` combines daily Steps (35%), Sleep duration vs target (35%), `HydrationProvider` intake fraction (15%), Active movement minutes (10%), and Mindful minutes (5%), paired with dynamic `wellnessInsight` guidance.
  - **Wearable Telemetry Ingestion Bridge (`ingestWearableRecord`):**
    - Automatically ingests synced `WearableSyncRecord` payloads from `WearableProvider` (`ExploreHubScreen` & `WearableSyncSheet`), preserving higher step totals, upserting wearable sleep sessions for the wake date, and recording resting heart rate while deduplicating identical wearable HR readings within 60 minutes.
  - **Dashboard Widget & Full JSON Portability:**
    - Features the 4-tab `HealthWellnessSheet` (`Steps`, `Sleep`, `Vitals`, `Breathe`) and `SerenWellnessSummaryCard` on both `ExploreHubScreen` and `HomeDashboardScreen` (toggleable/reorderable via `DashboardConfig.sectionWellness` / `DashboardConfig.showWellness`), persisted locally in `_keySleepLogs`, `_keyDailyHealthActivities`, `_keyVitalLogs`, and `_keyHealthGoals` and included in `StorageService.exportFullBackupJson` / `restoreFullBackupJson`.
- **Caffeine & Evening Stimulant Cutoff Tracker (`StimulantType`, `CaffeineEntry`, `CaffeineConfig`, `CaffeineCalculator`, `CaffeineProvider`, `CaffeineSummaryCard`, `CaffeineBedtimeBanner`, `CaffeineTrackerSheet`):**
  - **1-Tap Quick-Log Servings & Custom Stimulant Entry:** Instant logging on `CaffeineSummaryCard` (under Seren Wellness in `ExploreHubScreen`) and inside `CaffeineTrackerSheet` for *Espresso* (`63 mg`), *Coffee / Kopi* (`95 mg`), *Matcha* (`70 mg`), *Tea / Teh* (`45 mg`), *Soda* (`35 mg`), plus custom drink names and custom mg dosages (`1`–`1000 mg`). Includes consumption time offsets (`Now`, `-1h`, `-2h`, `-3h`) and an interactive `TimeOfDay` picker to backfill earlier servings.
  - **First-Order ~5-Hour Half-Life Pharmacokinetic Decay (`CaffeineCalculator`):** Computes real-time active systemic caffeine (`residualNow`), individual drink contribution, and projected residual caffeine at tonight's `SleepCycleSheet` target bedtime (`residualAt(targetBedtime)`) using $C(t) = C_0 \cdot 0.5^{\Delta t / h}$ (default `halfLifeHours = 5.0`, user-selectable `4.0h / 5.0h / 6.0h` with 48-hour horizon pruning). Also computes `estimateClearTime` (when residual falls `<= 25 mg`), qualitative `CaffeineSleepImpact` status tiers (*Sleep-Safe*, *Low Residual*, *Moderate Load*, *High Load*), and an hourly 2-hour-step decay curve chart in `CaffeineTrackerSheet`.
  - **Live `SleepCycleSheet` Bedtime Coupling (`CaffeineBedtimeBanner`):** Resolves tonight's target bedtime dynamically via `SleepWellnessProvider.getTargetBedtime` + `AlarmProvider.nextUpcomingAlarm`, displaying residual bedtime mg and sleep-impact badge directly inside `SleepCycleSheet` with 1-tap drill-down into `CaffeineTrackerSheet`.
  - **Customizable Afternoon Curfew Nudges (`CaffeineConfig`, `NotificationService`):** Supports fixed daily cutoff times (`12:00`, `14:00`, `16:00`, or custom `HH:mm`) as well as bedtime-relative cutoffs (`8h Before Bed` synced to `SleepCycleSheet` target bedtime), scheduling offline wellness notifications on `nestin_wellness_channel` (`curfewNotificationId = 7280`) with instant `Test Nudge` preview and automatic next-day rollover when past cutoff.
  - **Dual Language, Adaptive Theme & Full Offline Portability:** Fully bilingual EN/ID via `AppLocalizations` and adaptive Light/Dark surface tokens via `AppColors`; persisted locally under `_keyCaffeineEntries` and `_keyCaffeineConfig` and roundtripped inside `StorageService.exportFullBackupJson` / `restoreFullBackupJson`.

---

### Group 4: Personal Interests (Mascot: Pippin — "The Curious Explorer")

*Pippin is the adventurous explorer dodo bird with a safari helmet, backpack, binoculars, and magnifying glass. Pippin nurtures hobbies, curiosities, reading, and personal growth.*

- **Curiosity & Hobby Tracking:**
  - Personal passion spaces for tracking creative pursuits (drawing, photography, coding, gardening, instruments).
  - Activity logs documenting hobby practice sessions, hours invested, and milestones achieved.
- **Hobby Practice Hour Counter & Milestone Badges Engine (`HobbyItem`, `HobbyPracticeSession`, `HobbyMilestone`, `HobbyProvider`, `HobbyPracticeSheet`):**
  - **Cumulative Deliberate Practice Hour Logging:** Tracks cumulative practice minutes and fractional hours (e.g. 26.0 hrs, 50.0 hrs) invested into creative skills, instruments, coding, and crafts with high precision.
  - **Multi-Tier Milestone Badges (8 Ascending Levels):** Built-in milestone progression thresholds rewarding sustained dedication:
    - *First Spark* (1h • 🌱) — First hour of practice completed.
    - *Curious Seed* (5h • 🌿) — Exploring fundamentals and basic technique.
    - *Dedicated Start* (10h • 🪴) — Building early practice rhythm and momentum.
    - *Quarter Century* (25h • 🥉) — 25 hours of focused habit formation.
    - *Half Century Club* (50h • 🏆) — 50 hours of deliberate practice. Serious dedication shines through.
    - *Centurion* (100h • 🎖️) — 100 hours of deep craftsmanship and skill growth.
    - *Artisan* (250h • 💎) — 250 hours of refined skill, artistry, and creative flow.
    - *Virtuoso* (500h • 👑) — 500 hours of mastery and passionate lifelong pursuit.
  - **Dynamic Milestone Detection & Celebration Dialog:**
    - Real-time comparison between previous and new cumulative practice hours upon session logging.
    - Automatically surfaces a celebratory modal dialog (`🎉 Milestone Unlocked!`) with celebratory badge icon, title, hours required, and Pippin's encouraging mascot quips.
  - **Interactive 1-Tap Quick Practice Logging:**
    - Direct `[+30m]` and `[+60m]` 1-tap quick buttons on every hobby card for frictionless habit entry.
    - Dedicated session logging dialog with duration presets (15m, 30m, 45m, 60m, 90m, 120m), custom minute entry, focus tags (*Technique*, *Repertoire*, *Theory*, *Drills*, *Creative Play*), star rating (1–5), and session notes.
  - **Interactive Explore Hub Companion Card & Modal Sanctuary Sheet (`HobbyPracticeSheet`):**
    - High-visibility card in Explore Hub displaying cumulative practice hours, total session count, active badge count, and real-time progress bar for top active hobby.
    - Dual-tab modal sheet featuring "Hobbies & Milestones" (with horizontal badge carousels, target progress indicators, archive toggles, and new hobby creation) and "Session Logs" (chronological history with focus chips, duration badges, and session rollback deletion).
  - **Full Offline Portability:** Serialized in `_keyHobbies` and `_keyHobbySessions`, fully exported and restored in the local JSON backup and restore engine (`exportFullBackupJson` / `restoreFullBackupJson`).
- **Reading Progress Tracker & Library Sanctuary (`ReadingItem`, `ReadingGoalData`, `ReadingProvider`, `ReadingProgressCard`, `ReadingTrackerSheet`, `ReadingProgressSlider`, `ReadingSparklineHistory`, `ReadingStreakBadge`, `ReadingGoalSettingsSheet`):**
  - **Structured Reading Library Model (`ReadingItem`, `ReadingStatus`, `ReadingFormat`):** Tracks book/media title, author, category, format (*Book*, *E-Book*, *Article*, *Study*), current page, total pages, reading status (*Want to Read*, *Reading*, *Finished*), 1–5 star personal rating, takeaway/quote notes, and `startedAt`/`finishedAt` timestamps with zero-division and page-bounds guards (`safeCurrentPage`, `progressFraction`, `percentageCompletion`, `pagesRemaining`).
  - **Interactive Progress Slider & Quick-Step Controls (`ReadingProgressSlider`):** Real-time continuous slider (`0` to `totalPages`) updates current page, pages remaining, and completion percentage (`0%`–`100%`) smoothly during drag (`persist: false`) before committing to storage on `onChangeEnd` (`persist: true`); paired with quick page step buttons (`-10 p`, `-1 p`, `+1 p`, `+10 p`, `+25 p` in sheet; `-5 p`, `+5 p`, `+10 p` on cards) and a tappable `Page X / Y` dialog (`showSetReadingPageDialog`) for exact page jumps and total-page adjustments.
  - **Daily Reading Page Goal, Sparkline History & Streak Badge (`ReadingGoalData`, `ReadingSparklineHistory`, `ReadingStreakBadge`, `ReadingGoalSettingsSheet`):**
    - Tracks net daily pages read cleanly across persisted page updates (avoiding double-counting during continuous slider drags and protecting daily progress when resetting completed books back to queue) against a configurable daily target (`1–500` pages, default `15 pages / day` with quick `10`, `15`, `25`, `40` presets).
    - Computes current active streak (staying alive throughout the day until midnight when yesterday's goal was met) and longest historical best streak, surfaced via `ReadingStreakBadge` (`🔥 Xd streak` / `Xh beruntun`) across cards, the Reading Sanctuary, and goal settings.
    - Displays an interactive 7-day pages-read sparkline (`ReadingSparklineHistory`) with goal reference line, color-coded goal-met emerald vs partial sky bars, `Today` highlight, and tap-to-inspect daily breakdown.
  - **Optional Evening Pippin Nudge (`NotificationService.scheduleReadingNotification`):** Opt-in (`eveningReminderEnabled` default `false`, configurable presets `19:00–22:00` or custom `showTimePicker`, plus instant preview button) local notification (`readingChannelId`, ID `7310`) with live speech preview (`"Read 15 pages today..."` / remaining count & active streak notice), automatically advancing to tomorrow evening once today's goal is reached, and deep-linking (`pippin_reading_goal` / `nestin://reading`) straight to `ReadingTrackerSheet`.
  - **Automatic Status Sync & Pippin Completion Celebration:** Advancing past page `0` moves *Want to Read* items to *Reading*; reaching `totalPages` (`100%`) marks the book *Finished*, records `finishedAt`, and presents Pippin's `Book Finished!` modal (`showReadingCelebrationDialog`) with 1–5 star rating and takeaway capture; stepping back below `totalPages` reopens the item as *Reading*.
  - **Dashboard, Explore Hub & Search Integration:** Embedded via `ReadingProgressCard` under Pippin's section in `ExploreHubScreen` and customizable/reorderable on `HomeDashboardScreen` (`DashboardConfig.sectionReading` / `DashboardConfig.showReading` / `DashboardProvider.toggleReading`), backed by the 4-tab `ReadingTrackerSheet` (*All*, *Reading*, *Queue*, *Finished*) with collapsible 7-day sparkline drawer, add/edit book modal with live slider preview, `nestin://reading` deep linking, and `UniversalSearchScreen` indexing.
  - **Full Offline Portability:** Persisted under `_keyReadingItems` (`nestin_reading_items_v1`) and `_keyReadingGoalData` (`nestin_reading_goal_v1`) and included in `StorageService.exportFullBackupJson` / `restoreFullBackupJson`.
- **Life Bucket List & Places to Visit:**
  - Aspirational checklist of life experiences, travel destinations, local cafes, and outdoor trails.
  - Priority levels and target completion dates to turn daydreams into achievable journeys.
- **Custom Personal Collections:**
  - Flexible multi-purpose collections (e.g. Favorite Coffee Beans, Board Games, Recipe Ideas, Gift Recommendations).
  - Custom category tagging with dynamic progress tracking.
- **Inspiration & Idea Spark Vault:**
  - Quick-capture repository for sudden creative epiphanies, creative prompts, and topic research ideas.

---

### Group 5: Notes, Personal Organization & Money Management (Mascot: Twill — "The Weaverbird / Little Architect")

*Twill is the organized, resourceful weaver bird with a utility tool vest and woven basket of structured records. Twill specializes in structure, lists, notes, personal organization, and everyday personal money management.*

- **Categorized Notes System:**
  - Note creation with title, markdown-friendly text body, categories, and custom tags.
  - Pinned notes feature keeping critical information at the top of the list.
  - Color-accented note cards with search filtering, tag filters, and `Active` / `Archived` segmented tabs in `NotesListScreen`.
  - **Notes Swipe & Archive/Delete Undo (`SwipeActionCard`):** Swiping right on active notes toggles Pin/Unpin in place, while swiping left moves the note to `Archived` with a 4-second `Undo` snackbar. Inside the `Archived` tab, swiping right restores the note to `Active`, and swiping left (or tapping delete) deletes it with 4-second `NoteProvider.restoreNote` recovery.
- **Markdown Live Preview & Rich Note Cards Engine (`MarkdownContentView` & `NotesListScreen`):**
  - **Native High-Performance Markdown Parsing:** Built-in zero-dependency parser rendering standard markdown syntax with zero performance overhead.
  - **Inline Markdown Styling:**
    - Headers (`# H1`, `## H2`, `### H3`, `#### H4`) rendered with proportional font sizing and bold typography.
    - Bold (`**text**`, `__text__`), Italic (`*text*`, `_text_`), and Bold-Italic (`***text***`) rendering.
    - Inline code spans (`` `code` ``) styled with monospaced font, subtle rounded background chip, and amber accent (`#FBBF24`).
    - Strikethrough (`~~text~~`) with muted text color and clean line-through styling.
  - **Block Markdown Features:**
    - Bullet lists (`- `, `* `, `+ `, `• `) with indented lavender bullet icons.
    - Numbered lists (`1. `, `2. `) with sequence badges.
    - Task lists / Checklists (`- [ ] `, `- [x] `) with interactive checkbox icons and completion styling.
    - Blockquotes (`> quote`) with 3px solid accent left border and soft italic typography.
    - Fenced code blocks (```` ```code``` ````) with dark container, subtle border, and horizontal scroll.
    - Horizontal dividers (`---`).
  - **Live Note Editor Split / Preview Switcher:**
    - Interactive 1-tap switcher (`[Edit Markdown]` vs `[Live Preview]`) in note editor sheet.
    - Real-time instant rendering of note title, category chip, and markdown formatted body before saving.
    - Markdown quick-formatting toolbar (`[H#]`, `[B]`, `[I]`, `[•]`, `[1.]`, `[☐]`, `[`code`]`, `["]`, `[---]`) with auto-selection wrapping.
  - **Rich Card Preview & Compact Mode:** Note list cards feature compact `MarkdownContentView` preserving formatted bold, headers, code chips, and checklists with clean line-clamping and `M↓` markdown indicator badge.
- **Direct Note Checklist Toggle (`MarkdownChecklistHelper`, `NoteProvider` & Interactive Checkboxes):**
  - **1-Tap Card & Live Preview Toggling:** Users can tap `- [ ]`, `* [ ]`, or `+ [ ]` checkboxes directly inside compact note cards (`NotesListScreen`)—as well as inside the editor's `Live Preview` tab—to flip between `- [ ]` and `- [x]` with subtle haptic feedback (`HapticFeedback.selectionClick`) without opening the full note editor, while tapping card titles or non-checkbox text still opens the editor normally.
  - **Lossless Pure Markdown Line Engine (`MarkdownChecklistHelper`):** Shared zero-dependency helper parsing and toggling exact zero-based line indices while preserving indentation (`  - [ ]`), bullet markers (`-`, `*`, `+`), spacing, CRLF line endings, duplicate checklist item labels, markdown links (`- [x](url)` ignored), and fenced code blocks (```` ``` ```` excluded).
  - **Instant Persistence & Live Progress Badge:** `NoteItem.checklistSummary` computes `completed/total` stats and `NoteProvider.toggleChecklistItem(id, lineIndex)` persists updated note content and `updatedAt` timestamps immediately to `StorageService`, updating a compact header progress pill (`1/2`, `2/2` emerald on completion) inside an overflow-safe `Wrap` row alongside `M↓`.
- **Custom Structured Lists & Reusable Packing Templates (`CollectionItem`, `TravelPackingTemplates`, `CollectionProvider`, `CollectionsListScreen`):**
  - Multi-purpose list manager for packing lists, project checklists, and inventory with icon (`CollectionItem.availableIcons`), accent color customization, instant strike-off toggles, per-entry category chips (`CollectionEntry.category`), 1-tap item removal (`removeEntryFromCollection`), and completion progress bars.
  - **4 Pre-Built Travel & Packing Presets (`TravelPackingTemplates`):** Built-in reusable templates for **Weekend Trip** (8 items), **International Flight** (9 items), **Outdoor Camping** (9 items), and **Business** (8 items), organized with category tags (*Documents*, *Tech*, *Clothing*, *Toiletries*, *Shelter*, *Safety*, *Work*, etc.).
  - **1-Tap Instantiate, Preview Sheet & Filter Chips:** `CollectionsListScreen` highlights all 4 presets in a top `Travel & Packing Templates` card with a quick `+` button (`createFromPackingTemplate` with automatic collision numbering such as `Weekend Trip (2)`), a categorized preview bottom sheet with custom trip naming, a preset picker inside the `New List` sheet, and `All Lists` / `Packing & Reusable` filter chips.
  - **1-Tap "Uncheck All / Reuse for Next Trip" & Reuse Tracking:** Reusable lists display a 1-tap `Uncheck All / Reuse for Next Trip` footer button backed by `CollectionItem.resetForNextTrip` and `CollectionProvider.uncheckAllEntries`, clearing all checked items, stamping `lastResetAt`, and incrementing `reuseCount` (`Reused Xx` badge) whenever checked items are reset.
  - **Template Duplication & Card Menu Controls:** Every checklist supports 1-tap duplication (`duplicateCollection` / `CollectionItem.duplicateAsNewTrip`) via modal dialog with custom naming and a `Start all items unchecked` toggle—generating completely independent entry IDs—plus quick `Duplicate List`, `Mark as Reusable` / `Unmark Reusable` (`toggleReusableTemplate`), and `Delete List` options.
  - **Unified Search Indexing & Backup Restoration:** `UniversalSearchScreen` searches `CollectionProvider.collections` across titles, descriptions, entry texts, and entry categories (`Lists & Packing` / `Daftar & Kemas`), and `StorageService.exportFullBackupJson` / `restoreFullBackupJson` cleanly preserves all collections and template metadata across local JSON backups.
- **Curated Wishlists & Intentional Planning:**
  - Track desired acquisitions, gift ideas, tools to explore, and future personal gear.
  - Set item priorities (High, Medium, Low), target dates, notes, and categories.
  - Status indicators for Acquired vs Pending items to foster intentionality and curb impulsive decisions.
  - Helps keep personal wishlists, book lists, and gear checklists organized in one private local space.
  - **Wishlist Swipe & Undo Protection (`SwipeActionCard`):** Swiping right toggles Pending vs Acquired status (`toggleWishlistPurchased`), and swiping left (or tapping delete) deletes items with a 4-second `Undo` snackbar calling `CollectionProvider.restoreWishlistItem` to restore exact original list position.
- **Unified Swipe Actions & 4-Second Undo Snackbar Engine (`SwipeActionCard`, `SwipeActionStyle`, `showUndoSnackBar`):**
  - **Shared Gesture Shell (`lib/ui/widgets/swipe_action_card.dart`):** Standardized horizontal `Dismissible` wrapper powering `TasksScreen`, `RemindersListScreen`, `NotesListScreen`, and `WishlistScreen` with consistent dismiss thresholds (`0.32` right / `0.35` left), adaptive Dark/Light tinted pill backgrounds (`_SwipeBackground`), rounded corners matching card geometry, and tactile `HapticFeedback.mediumImpact()`.
  - **Safe In-Place Right-Swipe Handling:** Swipe-right actions (`Complete`/`Reopen`, `Next Due`, `Pin`/`Unpin`, `Acquired`/`Pending`, `Restore`) run inside `confirmDismiss` returning `false` so in-place re-sorted or unfiltered cards smoothly snap back without triggering Flutter `Dismissible` tree assertions, while filtered moves cleanly unmount on provider rebuild.
  - **Floating 4-Second Non-Persistent Undo Snackbar (`showUndoSnackBar`):** Displays a floating 4-second snackbar (`persist: false`, `Duration(seconds: 4)`) replacing any prior snackbar via `hideCurrentSnackBar()` so consecutive swipes never queue stale prompts.
  - **Idempotent Provider Snapshot Restoration:** Backed by `TaskProvider.restoreTask`, `ReminderProvider.restoreReminder` (reverting recurring date advances and rescheduling notifications), `NoteProvider.restoreNote`, and `CollectionProvider.restoreWishlistItem` to guarantee duplicate-free, position-preserving rollback from both swipe gestures and trash-button deletions.
- **Custom Categorized Collections & Idea Boards:**
  - Build structured boards and checklists for hobbies, books to read, gift ideas, and future gear.
  - Dynamic completion indicators and organized categories without clutter or unwanted online dependencies.

- **Personal Money Management (`MoneyHubScreen`, `MoneySummaryCard`, `MoneyProvider`, `MoneyAmount` — Twill's Offline Money Domain):**
  - **Philosophy & Boundaries:** Strictly offline, manual-only personal money management tool with zero external bank connections, payment gateways, real-money institutional transfers, QRIS, OCR, or speculative AI financial predictions. Built directly on Nestin's local `StorageService` + `Provider` architecture for everyday cash flow clarity and balance accuracy.
  - **Exact Fixed-Point Financial Arithmetic (`MoneyAmount` & `MoneyCurrency`):** All monetary quantities (balances, transactions, transfers, budgets, recurring rules) use exact integer minor units (`int` scaled by `MoneyAmount.scale = 100`, never IEEE-754 `double`) with strict decimal/grouped string parsing (`tryParseToMinor`) and clean multi-currency formatting (`IDR`, `USD`, `EUR`, `GBP`, `SGD`, `JPY`).
  - **6-Section Navigation Hub & App-Wide Integration:** Integrated natively as the 4th tab (`Money`) inside `OrganizeHubScreen` and addressable via `nestin://money` deep link, Home Dashboard `MoneySummaryCard` (`DashboardConfig.sectionMoney`), `ExploreHubScreen` Twill card, `QuickCaptureSheet` `Money` shortcut, `UniversalSearchScreen` cross-module search, and `SettingsScreen` (`Twill Money Preferences`). Features six focused views (`MoneySection`): `Overview`, `Transactions`, `Accounts`, `Budgets`, `Recurring`, and `Reports`.
  - **Money Dashboard & Financial Reports (`MoneyHubScreen`, `MoneyReportsView`):** Current-month default overview with month switcher (`previousPeriodMonth` / `nextPeriodMonth`), combined active wallet balance, selected period Income / Expenses / Net Cash Flow (`MoneyPeriodSummary`), budget utilization bars, recent transactions, monthly income vs. expense comparisons, 6-month cash flow history (`MonthlyCashFlowPoint`), category spending breakdowns (`CategorySpendingBreakdown`), 1-tap shortcuts (`+ Income`, `+ Expense`, `Transfer`), and helpful empty states using Twill's mascot sprites.
  - **Wallets & Accounts (`MoneyAccount`, `MoneyAccountType`, `MoneyAccountsView`):** Supports `Cash`, `Bank Account`, `E-Wallet`, and `Other` wallets with initial balance tracked cleanly apart from transaction income, edit dialogs, per-account detail & ledger history sheets, archive/restore lifecycle preserving historical transaction records while preventing new entries, duplicate name checks, and real-time combined active balance calculation.
  - **Income, Expense & Atomic Internal Transfers (`MoneyTransaction`, `MoneyTransactionType`, `MoneyTransactionsView`):** Full transaction CRUD with positive amount validation (`> 0`), active account & matching category-type validation, soft-archive or hard-delete reversal, historical backdated entries, and multi-criteria filtering (type, account, category, date range, text search). Internal transfers between user accounts (`executeTransfer`) use snapshot rollback via `commitMoneyLedgerAtomically()` and a shared `transferGroupId`, shifting funds atomically without counting toward income, expense, or budget totals, and rejecting same-account or archived-account transfers.
  - **Transaction Categories (`MoneyCategory`, `MoneyCategoryType`):** Auto-seeds 6 income (`Salary`, `Business Income`, `Freelance`, `Investment Returns`, `Gifts`, `Other Income`) and 11 expense (`Food & Drinks`, `Transportation`, `Shopping`, `Housing`, `Utilities`, `Health`, `Entertainment`, `Education`, `Family`, `Subscriptions`, `Other Expenses`) defaults per user (`defaultsForUser`). Supports custom categories with constant-safe icon & color resolution (`resolveCategoryIcon`) while blocking deletion of categories referenced by historical transactions, budgets, or recurring templates.
  - **Monthly Budgets (`MoneyBudget`, `BudgetUtilizationSummary`, `MoneyBudgetsView`):** Overall monthly spending caps and per-category expense caps computed solely from non-archived expense transactions (excluding income and transfers), highlighting healthy, approaching-limit, and exceeded thresholds (`BudgetHealthStatus`) with remaining vs. overspent indicators.
  - **Recurring Transaction Templates (`RecurringTransaction`, `RecurrenceFrequency`, `MoneyRecurringView`):** Supports daily, weekly, bi-weekly, monthly (calendar-clamped via `advanceDate`), and yearly schedules with optional end dates and active/inactive state. Templates never mutate account balances silently; users review due items and confirm execution (`executeRecurringOccurrence`) or skip occurrences, with deterministic `occurrenceKey` indexing (`occurrenceKeyFor`) preventing duplicate transaction generation.
  - **User Isolation, Authorization & Migration Security:** Scopes every record (`MoneyAccount`, `MoneyCategory`, `MoneyTransaction`, `MoneyBudget`, `RecurringTransaction`, `MoneySettings`) by `userId` with `MoneyAuthorizationException` ownership enforcement and O(1) lookup indexes, optional `SecurityPinGateSheet` PIN lock (`requirePinForMoney`), versioned `migrateMoneySchemaIfNeeded()` (`v0 -> v1` ledger reconciliation), and full JSON backup export/restore support.

---

### Group 6: Journal & Memories (Mascot: Echo — "The Thoughtful Observer")

*Echo is the wise, gentle owl with round spectacles and a star-embossed diary. Echo preserves life stories, nostalgic memories, gratitude, and deeply private reflections.*

- **Daily Mindful Diary:**
  - Personal journaling with title, content, date, tags, and private entry toggles.
  - Expressive mood tracking (`😄 Great`, `🙂 Good`, `😐 Neutral`, `😔 Low`, `😫 Tough`) with mood labels.
  - Dedicated Gratitude Note field on every entry to cultivate positive daily reflection.
- **Daily Journal Prompt Carousel (`JournalPromptCarousel` & `JournalPrompt`):**
  - Deck of curated mindful prompts spanning 7 categories: *Morning Intention*, *Daily Gratitude*, *Small Comforts*, *Growth & Resilience*, *Mindful Moment*, *Evening Unwind*, and *Self Discovery*.
  - Horizontal swipeable carousel with progress indicator (`X/7`).
  - Shuffle dice button to randomize prompts.
  - 1-Tap "Answer Prompt" action pre-filling diary context and focusing reflection field.
- **"On This Day" Nostalgic Memory Throwback (`ThrowbackSection` & `JournalProvider`):**
  - Temporal query engine surfacing diary entries and milestone memories from the exact same calendar day in past years (`target.day == date.day && target.month == date.month && target.year != date.year`).
  - Multi-month fallback for newer users (e.g. "1 month ago today", "2 months ago today").
  - Nostalgic hero card with amber gradient border, time-ago badge, mood emoji, quote preview, and gratitude highlight.
  - Privacy enforcement: private throwbacks stay locked behind security gate.
- **Milestone Memories:**
  - Preserve special personal milestones, achievements, anniversaries, and meaningful life events.
  - Milestone star badge highlighting life achievements.
- **Unified Everyday Timeline Feed:**
  - Aggregates diary entries, milestone memories, and major life events into a single chronological vertical timeline.
  - Color-coded badges and icons distinguish memories from journal entries.
- **Biometric App, Auto-Lock & Per-Diary Security Engine (`SecurityPinGateSheet`, `DiaryLockHelper`, `SettingsProvider`, `MainNavigationScreen`):**
  - **4–8 Digit Security PIN & Custom Password Engine:** Supports 4–8 digit numeric PINs for both the Global Diary Lock (`UserPreferences.securityPin`) and per-entry locks, plus flexible text passwords (minimum 4 characters, with show/hide toggle) for individual diary reflections via `DiaryLockHelper` (salted pure-Dart SHA-256 hashing stored per `JournalEntry`).
  - **Per-Diary-Entry Lock Choice:** Inside `DiaryEntriesScreen`'s reflection composer, entries marked `isPrivate: true` can choose between **Global Diary Lock** (uses main 4–8 digit Diary PIN + Biometrics) or **Custom PIN / Password** (entry-specific secret with its own setup flow and per-entry session unlock tracking via `SettingsProvider.isEntryLocked` / `_unlockedEntryIds`; never falls back to Global PIN).
  - **Biometric Quick-Unlock (Global Only):** Fingerprint and face authentication quick-unlock works exclusively on the Global Diary Lock when `isBiometricEnabled` is enabled, and is strictly disabled for custom-locked diary entries.
  - **PIN & Password Memory Clues (`securityPinHint` / `customLockHint`):** Optional clues can be attached during setup or edited per entry for both PINs and passwords. Locked diary cards never expose clue text; clues stay hidden behind an explicit `"Show Clue"` reveal toggle inside `SecurityPinGateSheet`.
  - **Auto-Lock Inactivity Timeout (`DiaryAutoLockDelay`):** Configurable inactivity grace period (`Immediately`, `1 minute`, or `5 minutes`) in `SettingsScreen` that automatically re-locks both Global Diary unlock and all unlocked custom entries after leaving the Journal tab or backgrounding the app (`MainNavigationScreen` tab-change + `AppLifecycleState` tracking via `notifyDiaryLeft` / `notifyDiaryEntered` / `evaluateAutoLock`), without locking unexpectedly during transient system prompts (`AppLifecycleState.inactive`).
  - **Entry-Level Privacy Masking & Quick-Lock Controls:** Private entries mask sensitive body text and clue text across `DiaryEntriesScreen`, `ThrowbackSection`, `TimelineScreen`, and `UniversalSearchScreen`, showing distinct `"Private Reflection"` vs `"Custom PIN Lock"` / `"Custom Password Lock"` lock cards, header Global Quick-Lock toggle, setup action (`setupGlobalPin`), and single-entry instant re-lock buttons on unlocked custom cards.
- **Echo Gratitude Jar & Tough-Day Pebble Picker (`GratitudePebble`, `EchoGratitudeJarVisual`, `GratitudeJarCard`, `GratitudeJarSheet`, `JournalProvider`):**
  - **Automatic Pebble Accumulation (`GratitudePebble` & `JournalProvider.getGratitudePebbles`):** Derives colorful glass pebbles directly from every non-empty `JournalEntry.gratitudeNote` (sorted newest-first with deterministic FNV-1a palette color assignment across 7 soothing colors), while excluding `isPrivate` and `hasCustomLock` entries by default so locked reflections never accidentally appear unless explicitly queried (`includePrivate: true`).
  - **Custom-Painted Animated Jar (`EchoGratitudeJarVisual`, `_EchoGratitudeJarPainter`):** Draws a translucent glass jar with cork stopper, rim reflection, and up to 24 staggered glossy pebbles stacked cleanly inside the jar bounds, featuring a damped sinusoidal tap-to-shake animation and vertical pebble bounce alongside `HapticFeedback.mediumImpact()`.
  - **Anti-Repeat Random Pebble Picker (`JournalProvider.pickRandomGratitudePebble` & `GratitudeJarSheet`):** Reveals a random past gratitude memory with entry title, mood badge, formatted date, `"Pick Another Pebble"` cycling (skipping the currently shown pebble when 2+ eligible entries exist via `excludeEntryId`), 1-tap `"Open"` jump to the source diary entry, cozy empty-jar guidance when no unlocked pebbles exist, and full EN/ID localization (`AppLocalizations`) + Light/Dark adaptive `AppColors` surfaces.
  - **Contextual Low/Tough Mood Auto-Trigger (`JournalProvider.isLowOrToughMood`):** Saving a `Low Energy` (`😔`) or `Tough Day` (`😫`) reflection in `DiaryEntriesScreen` or logging `Low` / `Tough` mood via the 1-tap Quick Mood Check-In on `HomeDashboardScreen` automatically opens `GratitudeJarSheet` (`autoShake: true`) with Echo's Tough-Day comfort banner and immediately draws an uplifting past gratitude memory.

---

### Platform Hardening, System Reliability & Audio Resilience

- **OEM Background Killer Hardening & Foreground Reliability Guard (`NestinKeepAliveService`, `OemHardeningPlugin`, `OemHardeningProvider`, `OemHardeningSheet`, `OemWarningBanner`):**
  - **Aggressive OEM Task Killer Defenses:** Hardened specifically for aggressive Android device skins (Xiaomi / Redmi / POCO MIUI & HyperOS, Samsung OneUI, Huawei / Honor EMUI & HarmonyOS, Oppo / Realme ColorOS, Vivo / iQOO FuntouchOS, and OnePlus OxygenOS) that terminate background alarms, pause countdown timers, and suppress routine notifications during deep sleep.
  - **Native Foreground Service Workaround (`NestinKeepAliveService`):**
    - Declared in `AndroidManifest.xml` with Android 14+ (API 34) compatibility using `android:foregroundServiceType="specialUse"` and `FOREGROUND_SERVICE_SPECIAL_USE` permission.
    - Low-overhead ongoing system notification channel (`nestin_keepalive_channel`, importance LOW, zero sound or vibration) pinning the process in memory so Linux kernel OOM killer and OEM battery daemons never kill the alarm scheduler.
    - User-toggleable from Settings and the OEM Protection sheet; automatically re-attaches on application launch when enabled.
  - **Intelligent Manufacturer Detection & Cascading Intents (`OemHardeningPlugin`):**
    - Real-time querying via `MethodChannel('com.nestin.app/oem_hardening')` inspecting `Build.MANUFACTURER`, `Build.BRAND`, `Build.MODEL`, `Build.VERSION.SDK_INT`, and `PowerManager.isIgnoringBatteryOptimizations()`.
    - Cascading intent dispatchers opening OEM-specific system activities with graceful fallback:
      - *Xiaomi / POCO:* `com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity` and `miui.intent.action.OP_AUTO_START`.
      - *Samsung:* `com.samsung.android.lool/com.samsung.android.sm.ui.battery.BatteryActivity` (Background usage limits / Never sleeping apps).
      - *Huawei:* `com.huawei.systemmanager/com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity` (Manual app launch with Auto-launch, Secondary launch, and Run in background).
      - *Oppo / Realme:* `com.coloros.safecenter` startup manager and unrestricted battery settings.
      - *Vivo / iQOO:* `com.vivo.permissionmanager.activity.PurviewTabActivity` and high background power usage whitelist.
      - *Stock Android:* `Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` with `package:com.nestin.app` (`activity.packageName`) and `Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`.
  - **Contextual Warning & Guidance UI:**
    - *Home Dashboard Alert Banner (`OemWarningBanner`):* Displays a high-contrast amber alert banner on the Today dashboard when on an aggressive OEM with active battery restrictions, featuring an instant 1-tap "Protect" action and dismiss button.
    - *Interactive Device Guidance Sheet (`OemHardeningSheet`):* Displays dynamic risk tier (Critical, High, Moderate, Protected), device model details, 3-step action cards with direct action buttons, and manufacturer-specific pro-tips (e.g., locking in Recents with padlock icon, disabling adaptive battery sleeping).
    - *Settings Integration (`SettingsScreen`):* Enhanced Platform & System Reliability section featuring an interactive OEM shield card and direct Keep-Alive Foreground Service toggle.
  - **Full Offline Portability:** Configuration serialized in `_keyOemHardeningConfig` and preserved across device migrations with the local JSON backup export and restore engine.

---

### Inspiration & Daily Quote Module (Mobile, Backend API, Supabase RLS & Admin CMS)

- **Mobile Experience (`InspirationScreen`, `QuoteCardStudioScreen`, `InspirationExploreCard`, `InspirationNotificationSheet`, `InspirationProvider`, `InspirationService`, `QuoteCardExportService`):**
  - **Offline-First Featured Quote & Browsable Library:** Dedicated Inspiration hub reachable from Explore Hub (`InspirationExploreCard`) and `nestin://inspiration` deep-link / notification routes. Serves backend-scheduled daily featured quotes (`GET /api/v1/inspiration/featured`) with per-locale `SharedPreferences` caching and bundled starter quotes so offline startup renders seamlessly with zero blank states.
  - **Dynamic Filtering & Bilingual Content:** Filter quotes by admin-managed categories (`motivation`, `personal-growth`, `productivity`, `mental-wellness`, `gratitude`, `relationships`, `philosophy`, `financial-mindset`, `life-lessons`), authors, language (`en` / `id`), keyword search, saved favorites, and incremental `Load More` pagination.
  - **Local-First Favorites & Personal Quotes:** Guests and registered users can bookmark favorite quotes locally (`SharedPreferences` + optional `/inspiration/me/favorites` cloud sync), write/edit/delete personal quotes, and optionally submit personal quotes for global moderation with explicit `rightsConfirmed` verification and anonymous or attributed preference.
  - **Explicit Offline vs Confirmed Submission State:** Offline submissions stay marked `OFFLINE DRAFT (NOT SUBMITTED)` (`isConfirmedByServer = false`) locally until confirmed by `/api/v1/inspiration/me/submissions`, and never fake approval or review outcomes. Editing a `PENDING` personal quote resets its submission to `DRAFT` for explicit resubmission.
  - **Local Quote Card & Wallpaper Studio (`QuoteCardStudioScreen`, `QuoteCardExportService`):** Real-time interactive `RepaintBoundary` renderer supporting Square (`1:1`), Portrait (`4:5`), Lock Screen (`9:16` with non-exported clock safe-zone guide preventing overlap), and Home Screen (`9:16`) formats; curated gradient and paper presets; typography (`Serif`, `Sans`, `Mono`), alignment, font size, vertical position controls; author/branding toggles; and collision-safe bundled bird mascot footer badges (`Roo`, `Pippin`, `Seren`, `Echo`, `Twill`, `Scout`). Exports genuine local PNG files under `<appDocs>/nestin_quote_cards/` via `RenderRepaintBoundary.toImage()` and shares via native `MethodChannel('com.nestin.app/share')` with clipboard fallback—requiring zero server image generation.
  - **Calm Opt-In Daily Notifications:** `InspirationNotificationPreferences` defaults `dailyEnabled` to `false` so OS notification permission (`NotificationService.requestPermissions`) is requested only when explicitly enabled. Supports local time (`preferredTime`), frequency (`Daily`, `Weekdays`, `Weekly`), preferred language, category filter, submission status alerts toggle, and instant preview via `NotificationService.scheduleDailyInspirationNotification`.

- **Backend & Database Architecture (`apps/backend/src/modules/inspiration/*`, `infrastructure/supabase/migrations/202611140002_inspiration_module.sql`):**
  - **Supabase Schema & Strict RLS:** Evolves `public.quotes` and `public.media_assets` and provisions 13 modular tables (`inspiration_authors`, `inspiration_categories`, `inspiration_quote_sources`, `inspiration_quote_translations`, `inspiration_featured_quotes`, `inspiration_user_quotes`, `inspiration_quote_submissions`, append-only `inspiration_moderation_logs` protected by database immutability trigger, `inspiration_user_favorites`, `inspiration_assets`, `inspiration_wallpaper_templates`, `inspiration_notification_preferences`, and `inspiration_notification_logs` with `dedupe_key` uniqueness). `public.is_moderator_or_admin()` restricts editorial/moderation writes while regular users can only manage their own drafts/favorites/notification preferences.
  - **NestJS REST API & Granular RBAC (`PermissionsGuard`, `@RequirePermissions`, `@Roles`):** Exposes public read routes (`/api/v1/inspiration/*`), authenticated user routes (`/api/v1/inspiration/me/*` blocking `isAnonymous` guests with `403`), and staff CMS routes (`/api/v1/admin/inspiration/*`) enforcing `moderator` vs `admin` permissions, anti-self-approval (`403` if reviewer equals submitter), duplicate submission rejection (`409 Conflict`), featured date-window conflict checks (`409 Conflict`), mandatory rejection reasons, and timezone-aware `InspirationNotificationService` daily dispatch with retry limits and expired FCM token revocation.

- **Admin CMS (`apps/admin` — React + TypeScript + Vite):**
  - Role-gated web console (`admin` and `moderator` JWT claims) covering Quote Library management + live Card Preview modal, Submissions Moderation Queue (duplicate warnings, self-review disablement, Approve/Reject w/ reason, Audit History modal), Daily Featured Schedule manager, Localized Categories (`en`/`id`), Authors, Wallpapers/Templates, Translations coverage, and Notification Dispatch logs.

---

## Todo List & Recommendations

- [ ] **Group 7: Inspiration & Daily Quote Refinements**
  - [ ] **Native Android/iOS Image Share Sheet Bridge:** Implement `com.nestin.app/share` Kotlin `FileProvider` handler in `apps/mobile/android` (and Swift `UIActivityViewController`) so exported quote card PNGs open directly in OS image share sheets alongside the clipboard text fallback.
  - [ ] **Curated Background Image Pack Sync via Supabase Storage:** Add optional downloadable atmospheric textured backgrounds under `inspiration_assets` so users can layer subtle watercolor paper / dawn textures behind Quote Card Studio templates offline.
  - [ ] **Admin CMS Batch Translation Progress Meter:** Add a filter toggle in `apps/admin` Translations tab highlighting published `en` quotes missing an active `id` translation for quick bilingual parity.

- [ ] **Mascot Flock Visual Integration & App Shell**
  - [ ] **`MascotSpriteRegistry` Typed Asset Index & `precacheImage` Warmup:** Create a strongly typed `(MascotType, MascotPose)` lookup table covering all 84 PNG sprites in `assets/mascots/sprites/` and precache active day-cycle sprites on dashboard init for zero-hitch frame transitions.
  - [ ] **`MascotSpriteView` Dynamic Asset Mapper & Dark-Mode Halo Framing:** Build a unified widget resolving `(MascotType, MascotExpression)` pairs cleanly to individual PNG assets with subtle breathing/bobbing hero animations, plus a subtle category-tinted radial halo backdrop on `AppColors.darkBg` (`#111215`) and `AppColors.darkCard` (`#1A1B20`) surfaces so dark-feathered birds and ink outlines pop cleanly in both Dark and Light (`#FFFFFF`) themes.
  - [ ] **Flutter-Native `MascotSpeechBubble` Overlay:** Render dynamic, theme-aware, localizable speech bubbles (`"3 more glasses today!"`, `"14m until alarm"`) in native Flutter UI next to clean character sprites instead of static baked image text, keeping small 32–64dp avatar slots crisp and clutter-free.
  - [ ] **Re-usable `MascotEmptyState` Component:** Build a warm, friendly empty-state widget featuring the category mascot with encouraging contextual speech bubbles (e.g. Roo `QUIET DAY` when no alarms exist, Scout `FREE TIME!` when agenda is clear, Twill `EMPTY!` when notes list is empty).
  - [ ] **Flock Category Theme Accents:** Assign distinct color signatures to each mascot domain (Roo Flame `#E04A3A`, Scout Slate Blue `#3B82F6`, Seren Lavender `#8B5CF6`, Pippin Explorer Emerald `#10B981`, Twill Amber/Gold `#F59E0B`, Echo Tawny Brown `#D97706`).
  - [ ] **Mascot 6-State Expression Engine:** Visual state renderer supporting `idle`, `celebrate`, `nudge`, `sleepy`, `thinking`, `alert` with smooth micro-transitions.
  - [ ] **Interactive Mascot Tap Haptics & Speech Quips:** Single-tap bounce physics surfacing contextual speech bubbles; double-tap joyful 360° rotation spin with chirp haptics.
  - [ ] **24-Hour Flock Day Cycle Handoff:** Dynamic companion switcher on Home Dashboard transitioning companions automatically from Dawn (Roo & Scout) to Night (Seren).
  - [ ] **Mascot Milestone Celebratory Stamp Animations:** Celebratory stamp overlay animations (e.g. Pippin `STAMPED!` passport on bucket list/reading finish, Roo `ON FIRE!` on 7-day habit streak, Seren `REFRESHED!` crown on hydration goal).
  - [ ] **Mascot Glance Widget Avatars:** Mini mascot companions embedded into Android home screen widgets for alarms, habits, and quick capture.
  - [ ] **Mascot-Led Onboarding Tour:** Introduce first-time users to the 6 bird companions and their specific everyday roles.
  - [ ] **Lossless WebP Mascot Sprite Benchmark:** Benchmark converting 84 PNG sprites to lossless WebP for an additional ~30% storage slimming if decoding performance matches PNG.
  - [ ] **Vector/Rive Hero Mascot Animation Pipeline:** Explore converting primary mascot hero poses into vector SVG/Rive assets for crisp, resolution-independent scaling across tablets and desktops.

- [ ] **Group 1: Time & Planning (Roo Improvements)**
  - [ ] **Habit Streak Freeze & Rest Day Support:** Allow configuring scheduled rest days (e.g. weekends for workouts) so streaks are preserved without artificial breaks.
  - [ ] **Priority & Category NLP Tagging:** Auto-detect priority tags (e.g. `!urgent`, `!high`) and category hashtags (e.g. `#work`, `#health`) from natural language titles.
  - [ ] **Pomodoro Weekly Focus Bar Chart:** Visual 7-day bar chart showing daily focus minutes and pomodoro completion trends.
  - [ ] **Auto-Start Next Pomodoro Cycle Option:** Configurable toggle to automatically start the break or next work session without requiring manual tap.
  - [ ] **Interactive Subtask Drag-and-Drop:** Allow reordering subtasks inside task details screen with smooth drag handles.
  - [ ] **Interactive Week Calendar Strip:** Horizontal scrolling 7-day strip at the top of Tasks and Calendar views for instant day switching.
  - [ ] **Custom Alarm Tone Pitch & Speed Modulator:** Allow adjusting pitch (+/- 3 semitones) or playback speed (0.8x to 1.3x) of built-in alarm tones.
  - [ ] **Multi-Crow Escalation Sequence:** Allow Roo's dawn crow to repeat at intensifying intervals (e.g., 1 crow, pause, 2 crows, pause, continuous morning dawn chorus).

- [ ] **Group 2: Everyday Assistance (Scout Improvements)**
  - [ ] **Geofence Exit Linked to Active BeforeYouGo Preset:** Automatically include active *BeforeYouGo* unchecked essential items inside Home departure geofence reminders.
  - [ ] **Configurable BeforeYouGo Snooze Intervals & Urgent Repeat:** Allow per-departure custom snooze steps (e.g., 3m, 5m, 10m) and optional high-priority escalation cue if essentials remain unchecked close to departure time.
  - [ ] **Weather-Aware BeforeYouGo Item Prompts:** Suggest adding seasonal items (e.g., *Umbrella* or *Light Jacket*) to active departure checklists when `LocalWeatherService` detects rain or cool temperatures.
  - [ ] **Geofence Quiet Hours & Active Day Filters:** Allow location reminders to specify active weekdays and quiet-hour suppression windows so work or store triggers stay muted outside relevant schedules.
  - [ ] **Interactive Place Search & Radius Map Picker:** Visual offline/geocoded address autocomplete and draggable fence radius preview when adding or editing saved places in Scout.
  - [ ] **Interactive Widget Direct Check Toggles:** Add `BroadcastReceiver` action allowing users to check off daily habit steps directly from the home screen widget without launching the app.
  - [ ] **Fuzzy Search & Search History:** Implement recent search chips and typo-tolerant search matching in `UniversalSearchScreen`.
  - [ ] **Automated Weekly Backup Reminder:** Gentle weekly notification suggesting export of full JSON life backup.
  - [ ] **Lock Screen Glance Widgets:** Support compact keyguard/lock screen widget formats for Android 14+ and always-on displays.

- [ ] **Group 3: Personal Wellness (Seren Improvements)**
  - [ ] **Configurable Medication Snooze Durations & Quick "Take":** Offer selectable 10m, 15m, and 30m snooze presets alongside a 1-tap "Mark Taken" notification action next to "Snooze 15m".
  - [ ] **Medication Dose Timing Drift Analytics:** Show average delay between scheduled dose times and actual "Take" timestamps to help fine-tune daily reminders around real routines.
  - [ ] **Prescription Photo Attachment:** Save local photo of medication label/pill bottle in medication details for quick visual identification.
  - [ ] **Seren Hydration Home/Lock Screen Widget Action:** Quick +1 glass action button on Android home screen widget to log water without opening app.
  - [ ] **Customizable Hydration Container Sizes:** Allow quick-logging with custom vessel sizes (e.g. 200ml cup, 330ml can, 500ml water bottle, 750ml tumbler) in addition to the standard 250ml glass.
  - [ ] **Hydration Consistency Streak Celebrations:** Milestone badges and Seren celebratory animations for achieving 7-day or 14-day 100% hydration consistency.
  - [ ] **Hourly Hydration Distribution Heatmap:** 24-hour visual heat bar revealing peak drinking hours and daytime hydration gaps to encourage even intake pacing.
  - [ ] **Sleep Audio Fade-Out Ramping:** Gentle 2-minute exponential volume fade-out before the 30-minute wind-down timer expires to avoid abrupt silence when falling asleep.
  - [ ] **Custom Sleep Timer Duration Selector:** Configurable wind-down ambient timer presets (15m, 30m, 45m, 60m, or 90m full REM cycle duration).
  - [ ] **Binaural Delta Wave & Campfire Audio Presets:** Procedural synthesis algorithms for 2-4 Hz deep sleep delta waves and cozy crackling campfire embers.
  - [ ] **Bedtime Wind-Down Actionable Notifications:** Actionable notification action buttons ("Start Ambient Noise", "Snooze 15m") directly from Android notification shade.
  - [ ] **Wearable Health Auto-Poll:** Background periodic synchronization of step and sleep data from connected health platforms.
  - [ ] **Bedtime Regularity & Circadian Consistency Score:** Analyze bedtime and wake-time variance across 7–14 nights to score sleep schedule regularity alongside duration.
  - [ ] **Custom Stride & Movement Pace Calibration:** Guided stride-length calibration helper (by height or measured walk) to refine step-to-kilometer distance accuracy.
  - [ ] **Overnight HRV & Recovery Readiness Trends:** Track morning heart rate variability trends alongside deep sleep ratio to suggest rest vs active days.

- [ ] **Group 4: Personal Interests (Pippin Improvements)**
  - [ ] **Dedicated Personal Interests Hub Tab / View:** Dedicated UI screen showcasing Reading Lists, Life Bucket Lists, and Creative Hobby logs.
  - [ ] **Personal Skill Progression & Competency Milestones:** Track deliberate skill development (e.g., Coding, Piano, Language, Sketching) with practice hour logs, progression stages (Beginner -> Intermediate -> Advanced -> Master), and milestone celebratory badges.
  - [ ] **Reading Streak Freeze & Rest-Day Tokens:** Optional rest-day pass allowing readers to preserve a long reading streak during busy travel days without breaking momentum.
  - [ ] **Reading Session Timer & Pace Estimator:** Link focus sprints to an active book to estimate reading speed (pages/hour) and projected completion date.
  - [ ] **Pippin Milestone Stamp Animation:** Celebratory stamp animation when checking off a life bucket list goal or finishing a book.
  - [ ] **Hobby Practice Habit Heatmap:** 52-week visual GitHub-style contribution squares showing daily practice density and frequency.
  - [ ] **Audio Metronome & Practice Timer:** Built-in tempo metronome (40-240 BPM) running concurrently during practice sessions with visual pendulum pulse.

- [ ] **Group 5: Notes & Organization (Twill Improvements)**
  - [ ] **Grouped Packing Categories & Custom Preset Saver:** Group packing checklist items under collapsible category headers (`Documents`, `Tech`, `Clothing`) inside `CollectionsListScreen` and allow saving any custom list as a reusable starter preset in the top templates bar.
  - [ ] **Manual Savings Jars Linked to Wishlist Targets (`WishlistItem.targetPrice`):** Optional goal-progress tracking envelopes inside Twill's Money module that visually link manual allocated amounts to existing Wishlist goals or Calendar event budgets (strictly offline allocation, no external payments).
  - [ ] **Monthly Money Ledger CSV Export & Printable Summary:** Export filtered monthly transactions and category totals to clean CSV / shareable Markdown text via `MoneyHubScreen` for personal archiving.
  - [ ] **Optional Monthly Category Budget Rollover:** Configurable per-budget toggle allowing unspent monthly category allowances to carry forward into next month's cap without mutating cash balances.
  - [ ] **Note Markdown Table Rendering:** Support parsing and displaying lightweight markdown tables (`| Header |`) in notes preview.
  - [ ] **Note Checklist Reset & Clear Checked Action:** Add quick card menu or editor shortcut to uncheck all `- [x]` items in reusable lists or move completed checklist items to the bottom cleanly.
  - [ ] **Wishlist Priority Sorting & Category Filtering:** Multi-criteria sorting (priority, date added, title) and category pills to easily navigate curated wishlists and gift ideas.
  - [ ] **Wishlist Item URL & Image Preview Scraping:** Allow pasting a web link into a wishlist item to automatically store reference links with title and local image thumbnail support.
  - [ ] **One-Tap List Sharing / Export:** Export custom packing or shopping lists as cleanly formatted plain text or markdown to device share sheet / clipboard.
  - [ ] **Note Search Keyword Highlighting:** Highlight matching search terms directly in note cards and search results.
  - [ ] **Nested Folder & Tag Organizer:** Support hierarchical folders or nested tags for complex organizational structures.

- [ ] **Group 6: Journal & Memories (Echo Improvements)**
  - [ ] **Local Photo Attachment for Memories:** Allow attaching 1-3 local photos to diary entries and milestone records stored in app sandbox.
  - [ ] **Allow Global PIN Master Fallback for Custom-Locked Diary Entries:** Optional opt-in setting letting the main Global Diary PIN (never biometrics by default) unlock a custom-locked diary entry if the user forgets an entry-specific PIN/password.
  - [ ] **Failed-Attempt Cooldown & Break-In Alert on Diary Lock:** Temporary escalating lockout timer (e.g., 30s after 5 wrong PIN/password attempts) with clear visual countdown inside `SecurityPinGateSheet`.
  - [ ] **Mood Filter & Keyword Search:** Filter reflections by mood emoji and search gratitude notes with matching keyword highlights.
  - [ ] **Memory Voice Audio Memos:** Record short 30-second local voice memos attached to memories and diary entries.
  - [ ] **Echo Life Story PDF/Markdown Export:** Export diary entries and milestones as a styled personal annual memory book.

- [ ] **Platform Hardening, Audio & Offline Reliability**
  - [ ] **Android Boot Completed Alarms Auto-Rescheduler BroadcastReceiver:** Native BroadcastReceiver for `ACTION_BOOT_COMPLETED` and `ACTION_LOCKED_BOOT_COMPLETED` to immediately verify and reschedule alarms after sudden battery discharge or device restart before user unlocks phone.
  - [ ] **Doze Mode & Standby Bucket Live Diagnostics:** Real-time debugging sheet displaying Android App Standby Bucket (`ACTIVE`, `WORKING_SET`, `FREQUENT`, `RARE`, `RESTRICTED`) and battery level changes.
  - [ ] **OEM Quick-Setting Tile for Keep-Alive Guard:** Android 7.0+ Quick Settings QS Tile allowing users to toggle Nestin Foreground Reliability Guard directly from the system notification shade.
  - [ ] **iOS Critical Alerts Entitlement:** Setup entitlement instructions for bypassing Do Not Disturb mode on iOS when authorized.
  - [ ] **In-App Audio Trimming Tool:** Allow trimming imported MP3 files (e.g. starting at chorus/intro) with interactive waveform scrubber.
  - [ ] **Waveform Visualizer:** Visual animated audio equalizer during alarm playback and ringtone preview.

- [ ] **New Menus & Navigation Architecture**
  - [ ] **Weekly & Monthly Life Review Menu (`LifeReviewScreen`):** Unified cross-domain insights screen aggregating wake-up consistency (`WakeUpLog`), task and routine completion rates, Pomodoro focus minutes (`FocusSessionLog`), hydration/sleep/step averages (`HydrationProvider`, `HealthWellnessProvider`), medication adherence, hobby/reading totals, and mood trends into one scannable scorecard with Echo's auto-drafted weekly reflection starter.
  - [ ] **Explore Hub Modular Filter Bar & Domain Sub-Views:** Add sticky category filter chips (`All`, `Wellness • Seren`, `Interests • Pippin`, `Assistant • Scout`) and collapsible summary tiles at the top of `ExploreHubScreen` so users can jump straight to a domain without scrolling through all sections.
  - [ ] **Guided Morning & Evening Ritual Player (`RitualRunnerScreen`):** Full-screen distraction-free step player chaining Roo's `RoutinesScreen` checklists, Seren's breathing/hydration/medication check-ins, and Scout's *BeforeYouGo* departure checklist into timed interactive cards with chime transitions and skip/complete actions.
  - [ ] **Command Palette & Quick Action Launcher (`CommandPaletteSheet`):** Triggered via long-press on the global `+` FAB or top-bar shortcut for instant search-to-launch navigation across screens, sheets, and 1-tap actions (`+250ml Water`, `Start 4-7-8 Breathing`, `Play 30m Rain`, `Open Med Cabinet`, `Export Backup`).
  - [ ] **Recently Deleted & Unified Archive Vault (`TrashAndArchiveScreen`):** 30-day soft-delete recycle bin across Notes, Tasks, Reminders, Calendar Events, Alarms, Collections, and Diary entries with 1-tap restore or purge, unified alongside `NoteProvider.archivedNotes` and archived hobbies.
  - [ ] **Life Bucket List & Places to Visit Menu (`BucketListScreen` — Pippin):** Dedicated dream-goal board turning the conceptual bucket list into visual cards with category tags, target season/year, optional `SavedPlace` links, inspiration notes, and 1-tap promotion into Echo's `MemoryItem` upon completion.
  - [ ] **People, Birthdays & Occasions Countdown Menu (`OccasionsScreen` — Scout & Echo):** Dedicated annual date tracker computing days-until countdowns, turning age or anniversary milestone years, staggered reminder leads (7d, 1d, morning-of), and direct linking to gift ideas inside `WishlistScreen`.

- [ ] **New Cross-Module & Everyday Features**
  - [ ] **Real Backup File Export, Share Sheet & In-App Restore UI (`StorageService.restoreFullBackupJson`):** Upgrade `ExploreHubScreen._handleDataExport` from a truncated 200-char text preview dialog into full `.json` file saving/sharing plus an interactive **Import & Restore Backup** workflow in `SettingsScreen` and `ExploreHubScreen` with pre-restore item count preview and optional passphrase-encrypted `.nestin` archive support.
  - [ ] **Wake-Up & Snooze Analytics View (`WakeUpLog`):** Build the visual history and trend cards backed by the existing `WakeUpLog` model, surfacing morning snooze frequency, challenge solve speed by type (Math/Memory/Typing), and on-time wake streaks.
  - [ ] **Multi-Track Ambient Soundscape Mixer (`AmbientSoundService` Upgrade):** Expand single-track ambient audio into a 4-channel offline mixer layering procedural Rain, Forest Breeze, Coffee Shop, plus new Warm Brown Noise and Crackling Fireplace synthesizers with per-channel volume sliders and custom saved presets (`Deep Study`, `Cozy Sleep`, `Rainy Café`).
  - [ ] **Weekly Caffeine & Sleep Correlation Insights (`CaffeineProvider` + `SleepLog`):** Surface a 7-day average mg/day chart inside `CaffeineTrackerSheet` correlating late-afternoon intake days with `SleepLog` sleep efficiency and next-day subjective energy scores.
  - [ ] **Scheduled Background Time Evaluation for Automations (`WorkManager` / `BGAppRefreshTask`):** Periodically evaluate `AutomationTriggerType.timeSchedule` and active `PhoneModeProfile` end windows automatically even while Nestin UI is closed.
  - [ ] **Optional Android Accessibility App-Shield Opt-In:** Add an explicitly opt-in, disabled-by-default Accessibility foreground app guard screen with prominent OS disclosure for users wanting in-app pause banners over restricted apps.
  - [ ] **iOS `FamilyControls` Entitlement & `DeviceActivityReport` Target:** Provision signed Apple `com.apple.developer.family-controls` capability for full Screen Time telemetry and ManagedSettings app shields on iOS builds.
  - [ ] **Calendar Month Grid, Week Timeline & Offline `.ics` Import/Export:** Add a collapsible month calendar grid with category event dots, a multi-day timeline toggle, and local `.ics` file import/export inside `CalendarScreen`.
  - [ ] **Starter Note Templates & Wishlist Impulse Cooldown Timer (Twill):** Provide 1-tap starter templates (Meeting Notes, Weekly Reset, Book Summary, Recipe, Pros & Cons) in `NotesListScreen` plus an optional 7-day/30-day "Wait-Before-Buying" cooldown countdown on `WishlistItem` entries.
  - [ ] **App-Wide Lock Enforcement on Launch & Resume (`isAppLockEnabled`):** Enforce the existing `UserPreferences.isAppLockEnabled` flag via `SecurityPinGateSheet` on cold launch and `AppLifecycleState.resumed` (with configurable grace timeout and automatic bypass when `AlarmProvider.ringingAlarm != null` so active alarms always ring unimpeded).

- [ ] **Minor UI/UX, Polish & Performance Improvements**
  - [ ] **Deep Localization of Secondary Modal Sheets, Model Enums & Local Notifications:** Extend EN/ID translation coverage into every detail modal sheet (`SleepCycleSheet`, `MedicationTrackerSheet`, `HobbyPracticeSheet`, `HealthWellnessSheet`, `ReadingTrackerSheet`, `LocationRemindersSheet`, `BeforeYouGoSheet`, `MoneyTransactionsAccountsViews`, `MoneyBudgetsRecurringReportsViews`), default money category display labels, and scheduled local notification bodies so secondary workflows and OS alerts also match `UserPreferences.language`.
  - [ ] **Regional Number & Date Grouping Presets (`1.500.000` vs `1,500,000`):** Allow Indonesian/European users in `SettingsScreen` / Twill Money settings to choose dot vs comma thousands separators independently or automatically from `AppLanguage` when formatting currency inputs and display amounts.
  - [ ] **Scope 1-Second Ticker on `HomeDashboardScreen`:** Replace the top-level `Timer.periodic` `setState` (currently rebuilding the entire dashboard tree every second) with an isolated countdown listener/widget inside the Hero Next Alarm card to reduce frame rebuilds and battery draw.
  - [ ] **Responsive Narrow-Viewport Row Wrap & Ellipsis Guard (`<= 390dp`):** Convert unconstrained header/badge `Row` widgets in `ExploreHubScreen` (Wearable Health Sync badge, Hydration meter row, Medication header), `WishlistScreen` card headers, and `HomeDashboardScreen` Weekly Mood strip to `Flexible`/`Wrap` layouts so compact phones and large font scales never clip or trigger `RenderFlex` overflow.
  - [ ] **Theme Accent Studio, OLED True-Black & Card Density Toggle:** Add selectable sanctuary accent palettes (Nestin Crimson, Forest Sage, Seren Lavender, Ocean Slate), optional `#000000` OLED dark surfaces, and Comfortable vs Compact density settings in `SettingsScreen`.
  - [ ] **Settings About Card Dynamic Version Sync:** Read app version and build number dynamically from package/build metadata in `SettingsScreen` About card instead of static `about_version` translation text (`Version 1.0.0`).
  - [ ] **Fix `adaptive_theme_test.dart` `InspirationProvider` Test Wiring:** Provide `InspirationProvider` inside `_TestEnv` in `apps/mobile/test/adaptive_theme_test.dart` so `ExploreHubScreen` Light/Dark surface audit passes cleanly alongside `InspirationExploreCard`.
  - [ ] **Flutter 3.44 Analyzer Deprecation & Hint Cleanup:** Replace deprecated `.withOpacity()`, `DropdownButtonFormField.value`, `Radio.groupValue`, `Switch.activeColor`, and `ReorderableListView.onReorder` calls plus remove unused `oldHours` (`hobby_provider.dart`) and unused import (`hydration_sparkline_widget_test.dart`) for a clean zero-issue `flutter analyze` baseline.
  - [ ] **Manual Shared Expense Splitter Helper (Twill Money — Offline Only):** Add an offline manual bill-split calculator in Twill Money to compute individual shares and log only the user's personal expense or manual note locally (zero external payments or transfers).
  - [ ] **6-Month Cumulative Wallet Balance Trajectory (`MoneyReportsView`):** Add a multi-month net balance trend line chart alongside monthly income vs. expense comparisons inside Twill Money Reports.
  - [ ] **Quick Amount-Range Chips & Sticky Period Summary (`MoneyTransactionsView`):** Add quick filter chips (`< 50k`, `50k–250k`, `> 250k`) and a sticky filtered net total bar while scrolling long transaction histories.
  - [ ] **Alarm Toggle Next-Ring Countdown Toast (`AlarmsListScreen`):** Surface a concise `"Rings in Xh Ym"` snackbar immediately when enabling or saving an alarm.
  - [ ] **Horizontal Day Swipe & "Today" Jump Pill (`CalendarScreen`):** Allow swiping left/right across days and tapping a quick `"Today"` pill whenever viewing another date.
  - [ ] **Pre-Restore Backup Diff Preview (`StorageService` & `SettingsScreen`):** Inspect backup schema version and per-module record counts before committing `restoreFullBackupJson` so users can confirm exactly what will be restored.
  - [ ] **Quick Capture Draft Persistence & Expanded Types (`QuickCaptureSheet`):** Add `Calendar Event` and `Quick Water/Med` modes, auto-preserve unsaved draft input if closed accidentally, remember last-used capture category/type, and add optional clean-title toggle.
  - [ ] **Accessibility, Dynamic Font Scaling & Global Haptics Toggle:** Audit `Semantics` labels on icon-only controls, guard dashboard metric strips against overflow up to 1.3x system font scaling, and add a master haptics toggle in `SettingsScreen`.
  - [ ] **Debounced Storage Serialization & Storage Health Diagnostics:** Debounce high-frequency `StorageService` writes (slider drags, rapid checklist taps) and expose a "Storage Usage & Integrity Check" card in `SettingsScreen` displaying local record counts and JSON size.

- [ ] **Backend, Sync & Ecosystem Extensions (P1 / Future Scope)**
  - [ ] **Supabase Token Auto-Refresh & Password Reset Flow (`BackendGatewayService` + `NestinAccountSheet`):** Automatically refresh expiring Supabase JWTs via `POST /auth/v1/token?grant_type=refresh_token` and add an optional "Forgot Password" recovery flow (`/auth/v1/recover`) while keeping local guest usage completely unblocked when offline.
  - [ ] **Cloud Profile & Registered Device Manager UI (`GET/PATCH /api/v1/users/me` & `/api/v1/devices`):** Allow signed-in users inside `NestinAccountSheet` to update their optional cloud profile display name/timezone, inspect linked devices (`devices`), or soft-delete their cloud profile (`DELETE /api/v1/users/me`) without erasing on-device data.
  - [ ] **P1 Opt-In Encrypted Cloud Backup & Incremental Sync Engine:** Design entity-specific conflict resolution strategies (append-only Money transactions, field-level Notes merge, tombstones ledger + exponential backoff pending-sync queue) and Supabase Storage upload to the private `user-backups` bucket.
  - [ ] **Remote Content Catalog on Explore Hub:** Cache `/api/v1/content` editorial guides locally inside `apps/mobile` for offline browsing alongside Inspiration quotes.
  - [ ] **Expand Admin CMS Beyond Inspiration (`apps/admin`):** Extend the existing React + TypeScript Admin CMS (`apps/admin`) with editorial workflows for general `content_items` and `remote_configs` feature flags on top of `@Roles('admin', 'moderator')` and `public.is_moderator_or_admin()`.
