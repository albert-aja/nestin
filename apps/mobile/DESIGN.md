# Nestin Mobile — Design System & Visual Language (`DESIGN.md`)

> **Brand Essence:** A calm, local-first **Everyday Assistant & Personal Improvement Sanctuary** where users feel at home (*"nest in"*). Six bird companions organize daily life under one cohesive roof — purely personal and offline-first (never a banking or payment app).

---

## 1. Brand Identity & Color Tokens (`lib/core/theme/app_colors.dart`)

### Primary Brand Accent — Nestin Leaf Green (`assets/banner.jpg`)
Global navigation highlights, the center raised `+` Quick Capture button, primary switches, focused inputs, and global brand CTAs use **Nestin Leaf Green** sampled directly from the woven-wreath banner artwork:

| Token | Light Mode | Dark Mode | Role |
| :--- | :--- | :--- | :--- |
| `AppColors.primary` / `primaryLight` | `#649330` | `#7CB342` | Global primary CTA, center `+` Quick Capture FAB, active bottom-nav highlight, focused accents |
| `AppColors.primaryDark` | `#4B7022` | `#4B7022` | Deep pressed state & high-contrast ink |
| `AppColors.wordmarkCharcoal` / `wordmarkOffWhite` | `#2D3036` | `#F3F5F7` | Top navbar wordmark **`nest`** segment |
| `AppColors.accent` | `#FF9E1B` | `#FF9E1B` | Warm Sunrise Amber secondary highlight |

### Top Navbar Wordmark (`NestinWordmark`)
Replaces plain `"Nestin"` app-bar text with a lowercase rounded geometric `Text.rich` wordmark matching `assets/banner.jpg` (`FontWeight.w700`, tight `-0.7` letter-spacing):
- **`nest`** → `#2D3036` in Light Mode (`#F3F5F7` off-white in Dark Mode or over dark illustrated sky backdrops)
- **`in`** → `#649330` in Light Mode (`#7CB342` in Dark Mode or over dark illustrated sky backdrops)

### 6 Mascot Domain Accents
Each companion keeps a distinct domain color. **Crimson (`#E04A3A`) belongs strictly to Roo** (Roo's room, alarms, streak badges, and digital discipline) and is no longer the global app primary:

| Mascot | Domain | Accent Hex | Token |
| :--- | :--- | :--- | :--- |
| **Roo** *(Rooster)* | Time, Alarms, Habits & Digital Discipline | `#E04A3A` | `AppColors.rooCrimson` / `RooHouseScreen.rooColor` |
| **Scout** *(Carrier Pigeon)* | Everyday Assistance, Weather & Utilities | `#3B82F6` | `ScoutHouseScreen.scoutColor` |
| **Seren** *(Dove)* | Personal Wellness, Hydration & Relaxation | `#8B5CF6` | `SerenHouseScreen.serenColor` |
| **Pippin** *(Explorer Dodo)* | Reading, Hobbies, Bucket List & Inspiration | `#10B981` | `PippinHouseScreen.pippinColor` |
| **Twill** *(Weaver Bird)* | Notes, Packing, Wishlists & Personal Money | `#F59E0B` | `TwillHouseScreen.twillColor` |
| **Echo** *(Wise Owl)* | Diary, Mood, Gratitude Jar & Memories | `#D97706` | `EchoHouseScreen.echoColor` |

### Adaptive Surface Hierarchy
- **Light Mode:** Scaffold `#F4F6F9` (`lightBg`), crisp `#FFFFFF` cards (`lightCard`) with soft elevation shadows (`Colors.black @ 5%`, `blurRadius: 12`, `offset: (0, 4)`), borderless full-pill status chips (`BorderRadius.circular(999)`).
- **Dark Mode:** Obsidian scaffold `#111215` (`darkBg`), charcoal surfaces `#1A1B20` (`darkCard`), translucent dark glass `#1A1B20` overlays with subtle hairline borders (`Colors.white @ 10%`).
- **Card Corner Radius:** Standardized `18dp` (`BorderRadius.circular(18)`) across the Nest top banner card and all 6 Bird Room cards in 2×3 Grid Mode.

---

## 2. Shell & Floating Pill Bottom Navigation (`MainNavigationScreen`)

- **Undocked Floating Pill Dock:** Replaces full-width docked chrome with a floating capsule (`BorderRadius.circular(30)`, height `60dp`, horizontal margin `18dp`, floating `14dp` above bottom safe-area inset) over `Scaffold(extendBody: true)`.
- **Adaptive Dock Surface:**
  - **Light Mode:** Pure `#FFFFFF` surface with soft floating elevation shadow (`blurRadius: 24`, `offset: (0, 8)`) and hairline border.
  - **Dark Mode:** Translucent blurred dark glass (`#1A1B20` @ `88%` + `BackdropFilter` blur) with subtle hairline border (`Colors.white @ 10%`).
- **3-Slot Layout (`>= 48dp` Touch Targets):**
  1. **Left — Dashboard:** Active highlight in Nestin Leaf Green (`#649330` Light / `#7CB342` Dark) with tonal icon pill.
  2. **Center — Raised `+` Quick Capture Button:** `58×58dp` circular Leaf Green button protruding `16dp` above the pill with crisp surface cutout ring; tap opens `QuickCaptureSheet`, long-press opens `UniversalSearchScreen`.
  3. **Right — Nest:** Routes to the hybrid 2×3 Rooms Grid / Living Animated Treehouse view.
- **Clearance:** Passes full floating-dock clearance (`bottomInset + 116dp`) to `NestTreehouseScreen` and `HomeDashboardScreen` so scroll tails, phase scrubber chips, and the Treehouse hint pill sit comfortably (`>= 24dp`) above the raised `+` button.

---

## 3. 2×3 Rooms Grid View (`NestTreehouseScreen`)

- **Top Time-of-Day Banner (`nest_time_banner`):**
  - **Light Mode:** Wrapped in a pure `#FFFFFF` card (`18dp` radius + matching soft shadow) so `"Quiet Night in the Treehouse"` / `"Morning in the Treehouse"` separates crisply from the `#F4F6F9` scaffold instead of blending in.
  - **Dark Mode:** Soft time-of-day gradient (`Dawn`, `Day`, `Sunset`, `Night`) at `18dp` radius.
- **Living Grid Flock:** Reuses `AnimatedMascotSprite` across all 6 room cards with staggered `7.5–11.0s` pose switching (`450ms` smooth `AnimatedSwitcher` fade) and calm breathing anchored inside each bird's soft radial halo (`13–16%` accent opacity).
- **Animated Moving Glow Border:** Custom `SweepGradient` border painter (`_AnimatedGlowBorderPainter`) tinted with each bird's domain accent and staggered phase — crisp & restrained in Light Mode, softly luminous in Dark Mode. Pauses cleanly via `TickerMode` off-tab and renders statically when reduced motion (`MediaQuery.maybeDisableAnimationsOf`) is enabled.

---

## 4. Living Animated Treehouse Scene (`NestTreehouseSceneView`, `treehouse_painters.dart`)

### Bird Animation & Organic Room Pacing (`AnimatedMascotSprite`)
- **Calm Pose Switching:** Slow, staggered `7.5–11.0s` interval per bird (`Roo 7.5s`, `Scout 8.5s`, `Pippin 9.0s`, `Twill 9.5s`, `Echo 10.5s`, `Seren 11.0s`) with `450ms` `AnimatedSwitcher` fade — zero rapid flickering.
- **Horizontal Room Pacing (Treehouse Scene):** Gentle left–right floor pacing (`Transform.translate` on X + tiny walk bob + `Transform.flip(flipX: ...)`) within calibrated room-floor bounds with natural idle pauses (~52% resting, ~48% strolling) driven by the single shared `AnimationController`.

### Living Room Prop Effects — All 6 Rooms (`TreehouseRoomEffectsPainter`)
Driven from one shared `12s` harmonic `AnimationController` inside `RepaintBoundary` + `TickerMode`:
1. **Roo's Clockwork Room (Upper-Left):** High-contrast rotating antique brass/gold wall gears with crisp teeth & warm specular highlight, live real-time grandfather clock hands (always painted even under reduced motion), and swinging brass pendulum.
2. **Echo's Attic Observatory (Top):** Twinkling skylight stars + subtle brass telescope lens glint & cozy attic lantern shimmer.
3. **Scout's Balcony (Mid-Left):** Gently swaying branch lantern & fluttering balcony map corner + weather-reactive particles from `LocalWeatherService` (diagonal rain streaks when rainy, sweeping breeze lines when cool/breezy, soft golden sun motes when clear/warm).
4. **Seren's Tea Room (Mid-Right):** Rising translucent sine-wave steam wisps from both teacups + breathing hanging lamp & soft lavender bouquet glow.
5. **Pippin's Explorer Library (Lower-Left):** Floating warm dust motes drifting inside the hanging Edison bulb beam + subtle pulsing lightbulb & explorer map/compass glow.
6. **Twill's Organizer Workshop (Lower-Right):** Subtle staggered metallic sway shimmer on the hanging keys & workshop tools + warm dome workshop lamp glow.

---

## 5. Accessibility & Performance Guardrails
- Minimum `48×48dp` interactive tap targets on all navbar icons, floating dock slots, status links, checkboxes, and room hotspots.
- Zero `RenderFlex` overflows verified across `360dp` and `390dp` viewports in both Light and Dark themes, in English (`en`) and Bahasa Indonesia (`id`).
- `FontFeature.tabularFigures()` on clocks, countdowns, and counters.
- Full `TickerMode` gating off-tab / backgrounded + `MediaQuery.maybeDisableAnimationsOf(context)` reduced-motion compliance.
