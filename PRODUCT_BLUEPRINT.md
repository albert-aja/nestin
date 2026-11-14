# Nestin Product Blueprint

## 1. Product Identity

- **Name:** **nestin** (Nesting — a comfortable, welcoming personal space; Nest in — everyday activities, information, and responsibilities united in one companion).
- **Evolution Principle:** Direct expansion of Nestin's core smart alarm foundation. All existing wake-up alarms, challenges, custom sound isolation, OEM hardening, keep-alive protection, timers, and Android widgets remain preserved.

## 2. Core Philosophy

1. **Everyday usefulness over bloat:** Frequent actions (`QuickCaptureSheet`, `HomeDashboardScreen`) require minimal taps.
2. **Connected, not duplicated:** `EntityLink` (`CrossModuleLinkProvider`) connects Calendar Events, Tasks, Notes, Reminders, Journal Entries, Memories, Hobbies, Reading Books, Medications, BeforeYouGo checklists, and Automation Rules via bidirectional references.
3. **Offline & privacy-respecting first:** All core storage resides locally on-device via `StorageService` (`SharedPreferences`) with full JSON export/restore (`exportFullBackupJson` / `restoreFullBackupJson`) and zero mandatory cloud accounts.
4. **Honest device boundaries:** `DeviceCapabilityRegistry` classifies platform control actions honestly (`directlySupported`, `permissionRequired`, `delegatedToSystemSettings`, `unsupported`) rather than faking OS locks or bypassing platform security.
5. **Strictly 6 Bird Families:** No 7th family and no Penny character.

---

## 3. The Six Bird Families & Safety Boundaries

| Family | Bird | Focus Domain | Explicit Product Boundaries |
| :--- | :--- | :--- | :--- |
| **Roo** | Rooster | Time & Planning (Alarms, Timers, Pomodoro, Calendar, Reminders, Tasks, Routines) | Alarms retain higher reliability (`USE_EXACT_ALARM`, `fullScreenIntent`, `OemHardeningService`) than normal reminders. |
| **Echo** | Owl | Journal & Memories (Diary, Memories scrapbook, Timeline, Prompts, Throwbacks, PIN lock) | Reflective companion; avoids guilt-inducing mandatory daily streak enforcement. |
| **Seren** | Dove | Personal Wellness (Dose Medications, Hydration, Sleep Cycles, Caffeine, Vitals) | Practical organizer only. Never prescribes dosages, alters medical instructions, or claims symptom correlations. |
| **Pippin** | Dodo | Personal Interests (Reading tracker, Hobbies, Practice hours & milestones) | Pluggable activity tracking without building monolithic sub-apps per hobby. |
| **Twill** | Weaverbird | Notes & Organization (Markdown Notes, Quick Capture, Collections, Wishlist, Money) | Basic manual personal finance only (`MoneyProvider`). Never connects to banks, moves money, or gives financial/investment advice. |
| **Scout** | Carrier Pigeon | Everyday Assistance (Today, BeforeYouGo, Geofences, Digital Wellbeing, Phone Modes, Permissions, Automations) | Respects Android OEM quirks and iOS `FamilyControls`/Focus sandboxes transparently. |

---

## 4. Navigation & Visual System

- **5 Primary Bottom Tabs (`MainNavigationScreen`):**
  1. `Today` (`HomeDashboardScreen`): Daily briefing, next alarm hero, active Phone Mode / pending automation banner, quick capture, agenda, tasks, and customizable mascot summary cards.
  2. `Time` (`TimeHubScreen`): Sub-tabs for Alarms, Reminders, Timers/Pomodoro, Tasks, Calendar, and Routines.
  3. `Organize` (`OrganizeHubScreen`): Notes, Collections, Wishlist, and Twill Money Management.
  4. `Journal` (`JournalHubScreen`): Diary entries, Memories scrapbook, and Unified Timeline (protected when Diary Lock is enabled).
  5. `Explore` (`ExploreHubScreen`): Seren Wellness, Pippin Interests, Scout Geofencing, Digital Wellbeing & Phone Modes, Automation Engine, Permission Center, and Local JSON Backup.
- **Theme & Localization:** Adaptive Material 3 Light & Dark themes (`AppColors`, `AppTheme`) plus full offline English (`en_US`) and Bahasa Indonesia (`id_ID`) switching (`AppLocalizations`, `SettingsProvider`).
