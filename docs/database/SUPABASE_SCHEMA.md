# Supabase Database & Security Schema

**Migration Root:** `infrastructure/supabase/migrations/`  
**Migrations:** `202611140001_initial_foundation.sql`, `202611140002_inspiration_module.sql`  
**Seed File:** `infrastructure/supabase/seed.sql`

## 1. Tables & Responsibilities

| Table | Owner / Scope | Purpose | Key Columns & Conventions |
| :--- | :--- | :--- | :--- |
| `public.profiles` | User (`auth.users.id`) | Account metadata, optional guest migration link, future sync opt-in flag (`cloud_sync_opt_in = false` default) | `id (uuid PK)`, `guest_local_id`, `display_name`, `preferred_language (en/id)`, `timezone`, `role (user/moderator/admin)`, `cloud_sync_opt_in`, `preferences_snapshot`, `migrated_from_guest_at`, timestamps |
| `public.devices` | User (`user_id`) | Device identification & push notification token registration | `id (uuid PK)`, `user_id`, `device_identifier`, `platform`, `push_token`, `push_provider (fcm/apns/none)`, `last_seen_at`, `revoked_at`, `UNIQUE(user_id, device_identifier)` |
| `public.content_items` | Public read / Admin write | Guides, articles, public educational content | `id (uuid PK)`, `slug (unique)`, `title`, `summary`, `body_markdown`, `category`, `tags (text[])`, `locale (en/id)`, `mascot_domain`, `status`, `version`, `published_at` |
| `public.quotes` | Public read / Admin write | Motivation quote library with featured & scheduled support | `id (uuid PK)`, `quote_text`, `author`, `category`, `locale (en/id)`, `mascot_domain`, `is_featured`, `scheduled_for`, `status` |
| `public.media_assets` | Public read / Admin write | Wallpapers, inspiration cards, downloadable asset metadata | `id (uuid PK)`, `slug (unique)`, `asset_type`, `storage_bucket`, `storage_path`, `mime_type`, `byte_size`, `checksum_sha256`, `version`, `status` |
| `public.remote_configs` | Public read | Feature flags, maintenance mode messages (`en`/`id`), min supported app version | `id (uuid PK)`, `environment`, `min_supported_version`, `latest_version`, `maintenance_mode`, `feature_flags (jsonb)`, `config_version`, `is_active` |
| `public.sync_tombstones` | User (`user_id`) | P1 extension point for incremental deletion sync | `id (uuid PK)`, `user_id`, `entity_type`, `entity_id`, `deleted_at`, `source_device_id` |

All core tables include `created_at`, `updated_at` (maintained by `trg_*_updated_at` trigger), and nullable `deleted_at` (soft-delete convention).

## 2. Row Level Security (RLS) Posture

- **RLS is enabled on all 7 tables.**
- `profiles`: Authenticated users can only `SELECT` and `UPDATE` their own row (`auth.uid() = id and deleted_at is null`) and cannot self-escalate `role`.
- `devices` & `sync_tombstones`: Strictly scoped to `auth.uid() = user_id`.
- `content_items`, `quotes`, `media_assets`, `remote_configs`: Publicly readable (`SELECT`) only when `status = 'published'` / `is_active = true` and `deleted_at is null`; write policies restricted via `public.is_admin()`.

## 3. Migration & Seed Strategy
1. Apply schema updates exclusively via forward SQL migrations in `infrastructure/supabase/migrations/`.
2. Keep `seed.sql` idempotent using `ON CONFLICT DO NOTHING` so `supabase db reset` safely provisions starter EN/ID quotes, caffeine/budget guides, media metadata, 9 Inspiration categories, 4 authors, 4 wallpaper presets, and default active remote config rows.

---

## 4. Inspiration & Daily Quote Schema (`202611140002_inspiration_module.sql`)

- Evolved `public.quotes` (`author_id`, `category_id`, `source_id`, `origin_type`, `publication_status`, `is_active`, `anonymous_attribution`, `created_by_user_id`) and `public.media_assets` (`width`, `height`, `aspect_ratio`) plus read view `public.inspiration_quotes`.
- Added 13 dedicated tables with indexes, `updated_at` triggers, and RLS policies:
  - `public.inspiration_authors`, `public.inspiration_categories`, `public.inspiration_quote_sources`, `public.inspiration_quote_translations`, `public.inspiration_featured_quotes`, `public.inspiration_assets`, `public.inspiration_wallpaper_templates`
  - `public.inspiration_user_quotes`, `public.inspiration_quote_submissions` (including `content_fingerprint` and partial unique index preventing duplicate active pending/approved text), `public.inspiration_moderation_logs` (append-only enforced via database trigger rejecting `UPDATE`/`DELETE`), `public.inspiration_user_favorites`, `public.inspiration_notification_preferences` (`daily_enabled = false` default), and `public.inspiration_notification_logs` (`dedupe_key` unique index preventing double same-day sends).
- Helper `public.is_moderator_or_admin()` restricts moderation queues and editorial writes; RLS allows public reads strictly on `PUBLISHED` + active + non-deleted rows while scoping personal quotes, favorites, and notification preferences to `auth.uid() = user_id`.
