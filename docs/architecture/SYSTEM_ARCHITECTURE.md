# Nestin Multi-Layer System Architecture

## 1. Overview

Nestin evolves from a standalone Flutter application into a local-first, multi-application monorepo with three active pillars and one deferred pillar:

```text
+-------------------------------------------------------+
|              apps/mobile (Flutter / Dart)             |
|   Primary Source of Truth for Personal Life Records   |
|   - Guest-First Auto-Provisioned UUID                 |
|   - 6 Bird Families (Roo, Echo, Seren, Pippin,        |
|     Twill, Scout) operating 100% offline              |
|   - Optional BackendGatewayService (/api/v1 client)   |
+---------------------------+---------------------------+
                            | HTTPS REST (/api/v1) + Optional Supabase Auth JWT
                            v
+-------------------------------------------------------+
|              apps/backend (NestJS / TS)               |
|   Service Orchestration, Validation & Public APIs     |
|   - SupabaseAuthGuard + RolesGuard + ThrottlerGuard   |
|   - Auth, Users, Devices, Content, Quotes,            |
|     Media, Remote Config, System Modules              |
+---------------------------+---------------------------+
                            | Scoped JWT / Anon RLS Queries
                            v
+-------------------------------------------------------+
|         infrastructure/supabase (PostgreSQL)          |
|   - Supabase Auth (Email/Password, Session Lifecycle) |
|   - PostgreSQL + Row Level Security (RLS)             |
|   - Supabase Storage (public-media / user-backups)    |
+-------------------------------------------------------+
```

*Future Scope (Not Implemented Yet):* Web Administration Panel. Backend guards (`@Roles('admin', 'moderator')`), RLS helper `public.is_admin()`, and content-management service boundaries are prepared without selecting an admin UI framework prematurely.

---

## 2. Core Principle: Local-First & Offline Autonomy

- `apps/mobile` operates **100% offline without authentication or backend connectivity**.
- Personal everyday records — alarms, timers, reminders, calendar events, tasks, routines, notes, collections, wishlists, diary, memories, medication/hydration/sleep/caffeine logs, habits, location reminders, Departure checklists, device rules, automation logs, and **Twill Money Management** ledgers — remain persisted locally inside `StorageService` (`SharedPreferences` JSON snapshots).
- Backend failure or missing `NESTIN_API_BASE_URL` never degrades local create/edit/delete/reminder/sensor workflows. `BackendGatewayService` returns explicit `BackendResult.offline(...)` states and leaves local state untouched.

---

## 3. Authentication & Guest-to-Registered Migration

1. **Guest Mode (Default):** On first launch, `BackendGatewayService.ensureGuestIdentity()` automatically provisions a persistent `guestLocalId` (UUID v4) inside `nestin_guest_identity_v1`. Zero sign-up or login prompts obstruct usage.
2. **Optional Registration (Supabase Auth):** Users may voluntarily register/sign in via Supabase Auth. Mobile receives a Supabase access JWT; `SUPABASE_SERVICE_ROLE_KEY` is strictly confined to server-side secrets and never placed in `apps/mobile`.
3. **Safe Migration (`POST /api/v1/auth/guest-migration/prepare`):** Links `guest_local_id` and `migrated_from_guest_at` in `public.profiles` while keeping `cloud_sync_opt_in = false` and keeping all local records/IDs/relationships/timestamps on-device.

---

## 4. P1 Synchronization Foundation (Extension Points Only)

A complex sync engine is intentionally deferred until P1. However, P0 establishes compatible contracts:
- `packages/contracts/api.types.ts` & `apps/mobile/lib/core/config/api_contracts.dart` define `SyncMetadata` (`id` UUID v4, `createdAt`, `updatedAt`, `deletedAt`, `SyncStatus`: `localOnly`, `pendingPush`, `synced`, `conflict`).
- `infrastructure/supabase/migrations/202611140001_initial_foundation.sql` introduces `deleted_at` columns across tables plus `public.sync_tombstones` for future incremental delta pulls and idempotent soft deletes.
- Future P1 sync strategies will be entity-specific (e.g., append-only ledger validation for Money entries, field-level or user-prompted merge for Notes) rather than blind global last-write-wins, and failed sync attempts will never discard locally saved user records.
