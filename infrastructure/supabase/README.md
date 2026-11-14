# Nestin Supabase Infrastructure

This directory defines Nestin's managed PostgreSQL schema, Row Level Security (RLS) policies, seed data, and local Supabase CLI configuration.

## Architectural Boundary (Local-First)

- **Supabase stores ONLY account metadata, device registrations, public content, quotes, media metadata, remote config, and P1 sync tombstones.**
- **Personal everyday data** (alarms, calendar events, tasks, notes, money ledger, journal, wellness logs) remains local-first on the user's device inside `apps/mobile` until user-controlled optional cloud backup/sync is introduced in P1.
- Never place the `SUPABASE_SERVICE_ROLE_KEY` inside `apps/mobile`.

## Migrations & Seed Files

- `migrations/202611140001_initial_foundation.sql`: Creates tables (`profiles`, `devices`, `content_items`, `quotes`, `media_assets`, `remote_configs`, `sync_tombstones`), `updated_at` triggers, `on_auth_user_created` profile provisioning trigger, indexes, and least-privilege RLS policies.
- `seed.sql`: Idempotent starter quotes (EN/ID), wellness & budget articles, media asset metadata, and active remote configuration flags.
- `config.toml`: Local Supabase CLI configuration (`port 54321`, `db 54322`, deep link redirect `nestin://auth-callback`).

## Local Setup Commands

```bash
# From infrastructure/supabase (requires Supabase CLI + Docker Desktop)
supabase start
supabase db reset   # Applies all migrations/ and executes seed.sql
supabase status     # Prints local API URL and anon/service_role keys
```

For hosted projects:

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```
