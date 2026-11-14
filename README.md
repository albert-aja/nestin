# Nestin — Personal Everyday Space

**Tagline:** Every moment, right on time.  
**Architecture:** Local-First Monorepo — Flutter Mobile (`apps/mobile`) + Node.js/NestJS Backend (`apps/backend`) + React/TypeScript Admin CMS (`apps/admin`) + Supabase PostgreSQL/Auth/Storage (`infrastructure/supabase`)

Nestin is a local-first **Personal Everyday Space** organized around **six bird families** (`Roo`, `Echo`, `Seren`, `Pippin`, `Twill`, `Scout`), combining high-reliability smart alarms with everyday planning, wellness, interests, notes/money organization, and optional backend & Supabase support for public content, Inspiration & Daily Quotes, auth/device identity, and remote config **without making the mobile app depend on internet access**.

---

## Monorepo Structure

```text
nestin/
├── apps/
│   ├── mobile/                  # Existing Flutter app (100% local-first everyday features + Inspiration)
│   ├── backend/                 # Node.js / TypeScript / NestJS API v1 (/api/v1 & /api/docs)
│   └── admin/                   # React + TypeScript + Vite Inspiration & Moderation Admin CMS
├── infrastructure/
│   └── supabase/                # PostgreSQL migrations, RLS policies, seed.sql, config.toml
├── packages/
│   └── contracts/               # Shared API envelopes & P1 sync metadata types
├── docs/
│   ├── architecture/            # System architecture & local audit report
│   ├── api/                     # Backend REST API specification
│   ├── database/                # Supabase schema & RLS documentation
│   └── decisions/               # ADRs
└── scripts/                     # Local verification scripts (dev-check.ps1)
```

---

## The Six Bird Families (Strictly 6 Domains)

1. **Roo (Rooster) — Time & Planning:** Alarms, wake-up challenges, timers, Pomodoro sprints, calendar events, reminders, tasks, daily routines & streaks, Android glance widgets.
2. **Echo (Owl) — Journal & Memories:** Diary entries, memories scrapbook, timeline feed, prompts, nostalgic throwbacks, PIN/biometric privacy lock.
3. **Seren (Dove) — Personal Wellness:** Medication schedule & dose adherence/refills, daily hydration intake & sparkline, REM sleep cycle & bedtime wind-down audio, caffeine half-life cutoff tracker, health/vitals tracking, wearable bridge.
4. **Pippin (Dodo) — Personal Interests:** Reading progress tracker, hobby practice hours & milestones.
5. **Twill (Weaverbird) — Notes & Organization:** Markdown/checklist notes, collections, wishlists, quick capture, local-first Basic Money Management.
6. **Scout (Carrier Pigeon) — Everyday Assistance & Smart Context:** Today dashboard, BeforeYouGo departure checklists & heads-up alerts, native geofencing & location reminders, Digital Wellbeing controls, Phone Mode Orchestrator, Permission Center, Shared Automation Engine, Universal Search, Cross-Module Entity Linking.

---

## Development & Running Locally

### 1. Flutter Mobile App (`apps/mobile`)
Operates standalone and offline by default (`local_offline` posture):

```bash
cd apps/mobile
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
```

Optional backend/Supabase compile-time configuration (never pass `SUPABASE_SERVICE_ROLE_KEY` to mobile):

```bash
flutter run --dart-define=NESTIN_API_BASE_URL=http://10.0.2.2:3000 \
  --dart-define=NESTIN_SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=NESTIN_SUPABASE_ANON_KEY=<anon-key>
```

### 2. NestJS Backend (`apps/backend`)
```bash
cd apps/backend
cp .env.example .env
npm install
npm run typecheck
npm run build
npm test
npm run test:e2e
npm run start:dev
```
Swagger OpenAPI docs are served at `http://localhost:3000/api/docs`.

### 3. React + TypeScript Admin CMS (`apps/admin`)
```bash
cd apps/admin
npm install
npm run typecheck
npm test
npm run dev
npm run build
```

### 4. Supabase Infrastructure (`infrastructure/supabase`)
```bash
cd infrastructure/supabase
supabase start
supabase db reset
```

---

## Documentation Index

- [docs/architecture/SYSTEM_ARCHITECTURE.md](docs/architecture/SYSTEM_ARCHITECTURE.md) — Multi-layer architecture, local-first boundaries, guest-to-registered flow, P1 sync points.
- [docs/architecture/LOCAL_AUDIT_REPORT.md](docs/architecture/LOCAL_AUDIT_REPORT.md) — Step 1 audit of the relocated Flutter app.
- [docs/database/SUPABASE_SCHEMA.md](docs/database/SUPABASE_SCHEMA.md) — PostgreSQL tables, indexes, triggers, and RLS policies.
- [docs/api/BACKEND_API.md](docs/api/BACKEND_API.md) — `/api/v1` endpoint conventions and Swagger reference.
- [docs/decisions/0001-local-first-monorepo-and-supabase.md](docs/decisions/0001-local-first-monorepo-and-supabase.md) — Architecture decision record.
- Existing mobile docs preserved at root: [PRODUCT_BLUEPRINT.md](PRODUCT_BLUEPRINT.md), [ARCHITECTURE.md](ARCHITECTURE.md), [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md), [FEATURE_MATRIX.md](FEATURE_MATRIX.md), [DEVICE_INTEGRATION.md](DEVICE_INTEGRATION.md), [AUTOMATION_ENGINE.md](AUTOMATION_ENGINE.md), [API_DOCUMENTATION.md](API_DOCUMENTATION.md), [DEVELOPMENT_ROADMAP.md](DEVELOPMENT_ROADMAP.md), [CHANGELOG.md](CHANGELOG.md), and [about_project.md](about_project.md).
