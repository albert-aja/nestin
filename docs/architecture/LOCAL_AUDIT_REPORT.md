# Step 1 Audit Report — Existing Flutter Application (`apps/mobile`)

**Audit Date:** 2026-11-14  
**Original Location:** Repository root (`C:\D\Project\Nestin`)  
**Restructured Location:** `apps/mobile/`

## 1. Technology & Tooling Audited
- **Framework / SDK:** Flutter `3.44.0` (stable channel), Dart SDK `^3.12.0`
- **Node.js / npm:** Node `v24.15.0`, npm `11.13.0` (used for `apps/backend`)
- **Supabase CLI:** Not installed locally in PATH during audit (`supabase` command unavailable locally)
- **Package Name:** `nestin` (`version: 1.0.0+1`, `publish_to: 'none'`)
- **Core Dependencies (`apps/mobile/pubspec.yaml`):** `provider`, `uuid`, `intl`, `shared_preferences`, `audioplayers`, `flutter_local_notifications`, `timezone`, `file_picker`, `path_provider`, `flutter_localizations`, `flutter_lints`.

## 2. Preserved Mobile Application Footprint
- **`lib/` (172 Dart files pre-prep):** Organized cleanly across `core/` (`l10n` EN/ID, `theme` adaptive Dark/Light `AppColors`), `data/` (`models/`, `services/`), `domain/` (money ledger engine, caffeine decay calculator, security PIN, NLP date parser, sleep cycle math), `providers/` (ChangeNotifiers across all 6 bird families), and `ui/` (`screens/`, `widgets/`).
- **Platform Native Integrations:**
  - Android Kotlin plugins (`MainActivity.kt`, `DeviceControlPlugin.kt`, `GeofencingPlugin.kt`, `OemHardeningPlugin.kt`, Android home-screen widgets `NextAlarmWidgetProvider`, `HabitChecklistWidgetProvider`, `QuickCaptureWidgetProvider`).
  - iOS Swift handlers (`AppDelegate.swift`, `DeviceControlManager`, `GeofenceManager`).
- **Assets & Source Art (`test/bundle_slimming_asset_test.dart` dependency):**
  - `assets/mascots/` (84 PNG sliced sprites across 6 mascots < 2 MB + banner/logo)
  - `assets/sounds/` (custom alarm tones)
  - `source_art/mascots/sheets/` (14 raw `.jpg` sheets archived outside APK bundle; verified in `bundle_slimming_asset_test.dart` relative to Flutter app root — moved together into `apps/mobile/`).
- **Local Database (`StorageService`):** `SharedPreferences` JSON persistence across `nestin_*` keys (with legacy key migration) covering alarms, planning, wellness, interests, notes, money, location, departure, wellbeing, modes, automations, cross-module links, and caffeine, with full v3 backup JSON export/import and atomic rollback guard for Money ledger writes.

## 3. Restructuring Verification
Immediately after relocating the Flutter project into `apps/mobile/`, `flutter pub get`, `flutter analyze --no-pub`, and `flutter test --no-pub` passed **291/291 tests** before introducing any backend code or mobile preparation additions.
