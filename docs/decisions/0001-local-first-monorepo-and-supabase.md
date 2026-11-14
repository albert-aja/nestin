# ADR-0001: Local-First Monorepo Architecture with NestJS & Supabase

- **Status:** Accepted
- **Date:** 2026-11-14

## Context
Nestin began as a comprehensive local-first Flutter life management application spanning six bird domains (`Roo`, `Echo`, `Seren`, `Pippin`, `Twill`, `Scout`). Expanding toward user accounts, public content, wallpapers, remote configuration, and future optional backup requires server infrastructure without breaking existing local-first guarantees.

## Decision
1. **In-Place Monorepo Restructuring:** Relocate the Flutter application intact into `apps/mobile/`, add the NestJS TypeScript backend in `apps/backend/`, manage SQL migrations and RLS policies under `infrastructure/supabase/`, share cross-layer TypeScript/Dart schemas in `packages/contracts/`, and document architecture in `docs/`.
2. **Local-First & Guest-First Invariant:** Mobile operational data remains on-device (`SharedPreferences` in `StorageService`). Authentication is optional (`AccountAuthMode.guest` with local UUID `guestLocalId`), and signing up never automatically pushes personal data to the cloud.
3. **NestJS Over Raw Client-Side DB Calls:** Protected and orchestrated APIs route through NestJS `/api/v1`, while NestJS constructs user-scoped Supabase clients forwarding the user's JWT so PostgreSQL Row Level Security remains active instead of bypassing RLS with service-role credentials.
4. **Deferred Scope Control:** P1 cloud sync engines and the future administration panel UI are explicitly excluded from P0 implementation, leaving clean contracts (`SyncMetadata`, `sync_tombstones`, `@Roles()`) ready for dedicated design phases.

## Consequences
- Flutter workflows run independently from `apps/mobile/`.
- Backend workflows run independently from `apps/backend/`.
- External credentials (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_JWT_SECRET`) are injected via environment configuration with safe public fallbacks and zero secret exposure to mobile binaries.
