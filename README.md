![Nestin Banner](assets/banner.jpg)

# Nestin — Personal Everyday Space & Universal Alarm Platform

> **Every moment, right on time.**  
> A private, local-first personal everyday space combining high-reliability alarms, intelligent wake-up gates, daily planning, habit routines, personal money management, reflective journaling, and everyday wellness tools in Flutter.

---

## 🌟 Key Features

### ⏰ 1. Universal Alarms & Wake-Up Intelligence
- **Rock-Solid Scheduling:** High-reliability alarms with full-screen wake-up alerts and background lock-screen support.
- **Gradual Volume Ramp:** Smooth audio volume ramping from 10% to 100% over 30s–120s for natural wake-ups.
- **Wake-Up Challenge Gates:**
  - **Math Challenges:** Solve dynamic arithmetic equations (Easy, Medium, Hard).
  - **Memory Sequences:** Interactive color tile pattern recall game.
  - **Typing Challenges:** Precision motivational sentence validation.
- **Audio Sandbox Isolation:** Import custom audio files (MP3, WAV, M4A, OGG, AAC) into the app's sandboxed storage.
- **Challenge Inheritance:** Global default challenge profiles with per-alarm override protection.

### 🌅 2. Centralized Today Dashboard
- **Contextual Morning Briefing:** Greeting with current weather, outfit advice, and task counts.
- **Hero Next Alarm Card:** Live countdown badge, large digital clock, category tag, and instant test ring.
- **Dynamic Card Reordering:** Drag-and-drop customization of dashboard card ordering with visibility toggles.
- **Pull-to-Refresh & Haptics:** Pull to refresh dashboard with tactile vibration feedback.
- **7-Day Mood Trend Sparkline:** Visual breakdown of weekly reflection consistency.

### 📅 3. Time & Daily Planning
- **Smart Reminders:** Context-aware task alerts with recurring schedules (Daily, Weekdays, Weekly, Monthly).
- **Calendar & Daily Agenda:** Chronological view of events, appointments, and reminders.
- **Tasks & Checklists:** Prioritized tasks (Urgent, High, Medium, Low) with interactive subtasks and progress bars.
- **Habits & Routines:** Morning, evening, and custom routines with streak tracking.
- **Independent Concurrent Timers:** Multiple timers running simultaneously with audio chime alerts.

### 📋 4. Organization & Personal Money Management
- **Categorized Notes:** Markdown-friendly notes with category tags, pinning, and archive support.
- **Custom Lists & Collections:** Packing lists, reading lists, and bucket checklists with progress bars.
- **Wishlist & Savings Goals (Money Management Tracker):**
  > **Note:** Nestin is strictly a **money management and personal budgeting** space. It is **not** a banking app and does not handle payments, bank accounts, or financial transactions.
  - Track intended purchases, savings targets, and personal goals.
  - Set target prices, priorities, and estimated purchase dates.
  - Visual savings progress tracker with calculated budget shortfall.

### 📔 5. Reflective Journal & Memory Preservation
- **Daily Diary:** Mood logging (`😊 Great`, `🙂 Good`, `😐 Neutral`, `😔 Low`, `😫 Tough`), tags, and private reflections.
- **Daily Gratitude:** Cultivate positive habits with dedicated gratitude journaling.
- **Unified Life Timeline:** Chronological vertical feed uniting diary entries and milestone achievements.
- **Milestone Memories:** Commemorate special life events, promotions, and achievements with star badges.

### 🧭 6. Everyday Wellness & Departure Utilities
- **Sleep Cycle Calculator:** Computes optimal 90-minute REM sleep cycles and 14-minute sleep latency to recommend restorative wake-up targets.
- **Hydration Tracker:** 250ml increment counter with daily goal tracking.
- **BeforeYouGo Checklist:** Quick interactive checklist (Keys, Wallet, Phone, Charger, Lock Doors) with 1-tap reset.
- **Universal Search:** Instant cross-module indexing across notes, tasks, events, diary entries, and alarms.
- **100% Local-First JSON Backup:** Export full encrypted or plain JSON backup to device storage or clipboard; restore anytime with zero internet dependency.

---

## 🛠️ Architecture & Technology Stack

- **Framework:** Flutter 3.44+ / Dart 3.12+
- **State Architecture:** Multi-Provider pattern (`ChangeNotifier`) with single-responsibility providers:
  - `AlarmProvider`, `ReminderProvider`, `TimerProvider`, `SettingsProvider`, `SoundProvider`
  - `CalendarProvider`, `TaskProvider`, `RoutineProvider`, `NoteProvider`, `CollectionProvider`
  - `JournalProvider`, `DashboardProvider`
- **Persistence:** Local JSON document storage via `SharedPreferences` (`StorageService`). Zero network latency and privacy-guaranteed offline operation.
- **Audio & Alerts:** `audioplayers`, `flutter_local_notifications`, and `timezone`.

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (v3.24.0 or newer)
- Dart SDK (v3.5.0 or newer)

### Installation

```bash
# Clone the repository
git clone https://github.com/your-username/Nestin.git
cd Nestin

# Install dependencies
flutter pub get

# Run tests
flutter test

# Launch the app
flutter run
```

---

## 🔒 Privacy & Local-First Philosophy

Nestin operates **100% offline and local-first**. Your alarms, notes, calendar events, personal finances/wishlist, and private journal entries never leave your device. All data can be exported and imported as an open JSON file at any time via the Explore hub.

---

## 📄 License

This project is licensed under the MIT License.
