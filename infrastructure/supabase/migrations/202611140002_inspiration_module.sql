-- =============================================================================
-- Nestin — Inspiration & Daily Quote Module Schema (Migration 0002)
-- Evolves existing public.quotes & public.media_assets cleanly and adds
-- normalized CMS categories, authors, translations, sources, featured schedules,
-- user quotes, global submission workflow, immutable moderation audit logs,
-- user favorites, wallpaper templates, and notification scheduling logs.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. RBAC Helper for Moderators & Administrators
-- -----------------------------------------------------------------------------
create or replace function public.is_moderator_or_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and role in ('admin', 'moderator')
      and deleted_at is null
  );
$$;

-- -----------------------------------------------------------------------------
-- 1. Authors, Categories & Sources
-- -----------------------------------------------------------------------------
create table if not exists public.inspiration_authors (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  bio text not null default '',
  is_anonymous_or_unknown boolean not null default false,
  mascot_domain text null check (mascot_domain is null or mascot_domain in ('roo', 'echo', 'seren', 'pippin', 'twill', 'scout', 'flock')),
  is_active boolean not null default true,
  created_by uuid null references auth.users(id) on delete set null,
  updated_by uuid null references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz null
);

create index if not exists idx_inspiration_authors_active
  on public.inspiration_authors(is_active, name)
  where deleted_at is null;

drop trigger if exists trg_inspiration_authors_updated_at on public.inspiration_authors;
create trigger trg_inspiration_authors_updated_at
  before update on public.inspiration_authors
  for each row execute function public.set_updated_at();

create table if not exists public.inspiration_categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  default_locale text not null default 'en' check (default_locale in ('en', 'id')),
  name text not null,
  description text not null default '',
  translations jsonb not null default '{}'::jsonb,
  mascot_domain text null check (mascot_domain is null or mascot_domain in ('roo', 'echo', 'seren', 'pippin', 'twill', 'scout', 'flock')),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_by uuid null references auth.users(id) on delete set null,
  updated_by uuid null references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz null
);

create index if not exists idx_inspiration_categories_active
  on public.inspiration_categories(sort_order, slug)
  where is_active = true and deleted_at is null;

drop trigger if exists trg_inspiration_categories_updated_at on public.inspiration_categories;
create trigger trg_inspiration_categories_updated_at
  before update on public.inspiration_categories
  for each row execute function public.set_updated_at();

create table if not exists public.inspiration_quote_sources (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  source_type text not null default 'other' check (source_type in ('book', 'speech', 'essay', 'community', 'original', 'other')),
  url text null,
  notes text null,
  created_by uuid null references auth.users(id) on delete set null,
  updated_by uuid null references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz null
);

drop trigger if exists trg_inspiration_quote_sources_updated_at on public.inspiration_quote_sources;
create trigger trg_inspiration_quote_sources_updated_at
  before update on public.inspiration_quote_sources
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 2. Evolve Existing public.quotes & Alias View public.inspiration_quotes
-- -----------------------------------------------------------------------------
alter table public.quotes
  add column if not exists author_id uuid null references public.inspiration_authors(id) on delete set null,
  add column if not exists category_id uuid null references public.inspiration_categories(id) on delete set null,
  add column if not exists source_id uuid null references public.inspiration_quote_sources(id) on delete set null,
  add column if not exists source_reference text null,
  add column if not exists origin_type text not null default 'SYSTEM' check (origin_type in ('SYSTEM', 'USER')),
  add column if not exists created_by_user_id uuid null references auth.users(id) on delete set null,
  add column if not exists updated_by_user_id uuid null references auth.users(id) on delete set null,
  add column if not exists publication_status text not null default 'PUBLISHED' check (publication_status in ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
  add column if not exists is_active boolean not null default true,
  add column if not exists background_asset_id uuid null references public.media_assets(id) on delete set null,
  add column if not exists anonymous_attribution boolean not null default false;

create index if not exists idx_quotes_inspiration_browse
  on public.quotes(publication_status, is_active, locale, category_id, author_id)
  where deleted_at is null;

create or replace view public.inspiration_quotes as
select * from public.quotes;

-- Sync existing status <-> publication_status for backwards compatibility
update public.quotes
set publication_status = upper(status),
    is_active = (status = 'published')
where publication_status is distinct from upper(status);

-- -----------------------------------------------------------------------------
-- 3. Quote Translations & Backend Featured Quote Scheduling
-- -----------------------------------------------------------------------------
create table if not exists public.inspiration_quote_translations (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes(id) on delete cascade,
  locale text not null check (locale in ('en', 'id')),
  quote_text text not null,
  author_display text not null default '',
  publication_status text not null default 'DRAFT' check (publication_status in ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
  is_active boolean not null default true,
  created_by uuid null references auth.users(id) on delete set null,
  updated_by uuid null references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint uq_inspiration_quote_translation unique (quote_id, locale)
);

drop trigger if exists trg_inspiration_quote_translations_updated_at on public.inspiration_quote_translations;
create trigger trg_inspiration_quote_translations_updated_at
  before update on public.inspiration_quote_translations
  for each row execute function public.set_updated_at();

create table if not exists public.inspiration_featured_quotes (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes(id) on delete cascade,
  locale text not null check (locale in ('en', 'id')),
  publication_date date not null,
  start_at timestamptz not null,
  end_at timestamptz not null,
  priority integer not null default 0,
  is_active boolean not null default true,
  created_by uuid null references auth.users(id) on delete set null,
  updated_by uuid null references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint chk_featured_schedule_window check (end_at > start_at)
);

-- Enforce single active featured entry per date & locale
create unique index if not exists uq_inspiration_featured_date_locale
  on public.inspiration_featured_quotes(publication_date, locale)
  where is_active = true;

drop trigger if exists trg_inspiration_featured_quotes_updated_at on public.inspiration_featured_quotes;
create trigger trg_inspiration_featured_quotes_updated_at
  before update on public.inspiration_featured_quotes
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 4. User Personal Quotes, Global Submissions, Audit Logs & Favorites
-- -----------------------------------------------------------------------------
create table if not exists public.inspiration_user_quotes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  quote_text text not null,
  author_name text null,
  category_id uuid not null references public.inspiration_categories(id) on delete restrict,
  locale text not null default 'en' check (locale in ('en', 'id')),
  source_reference text null,
  display_preference text not null default 'anonymous' check (display_preference in ('username', 'anonymous')),
  rights_confirmed boolean not null default false,
  is_personal_only boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz null
);

create index if not exists idx_inspiration_user_quotes_owner
  on public.inspiration_user_quotes(user_id, created_at desc)
  where deleted_at is null;

drop trigger if exists trg_inspiration_user_quotes_updated_at on public.inspiration_user_quotes;
create trigger trg_inspiration_user_quotes_updated_at
  before update on public.inspiration_user_quotes
  for each row execute function public.set_updated_at();

create table if not exists public.inspiration_quote_submissions (
  id uuid primary key default gen_random_uuid(),
  user_quote_id uuid not null references public.inspiration_user_quotes(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'DRAFT' check (status in ('DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'WITHDRAWN')),
  anonymous_publication boolean not null default true,
  content_fingerprint text not null,
  submitted_at timestamptz null,
  reviewed_at timestamptz null,
  reviewed_by uuid null references auth.users(id) on delete set null,
  rejection_reason text null,
  published_quote_id uuid null references public.quotes(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

-- Prevent duplicate active/pending submissions per fingerprint while pending/approved
create unique index if not exists uq_inspiration_submission_active_fingerprint
  on public.inspiration_quote_submissions(content_fingerprint)
  where status in ('PENDING', 'APPROVED');

create index if not exists idx_inspiration_submissions_status
  on public.inspiration_quote_submissions(status, submitted_at desc);

drop trigger if exists trg_inspiration_quote_submissions_updated_at on public.inspiration_quote_submissions;
create trigger trg_inspiration_quote_submissions_updated_at
  before update on public.inspiration_quote_submissions
  for each row execute function public.set_updated_at();

-- Immutable Moderation Audit Log (append-only)
create table if not exists public.inspiration_moderation_logs (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.inspiration_quote_submissions(id) on delete cascade,
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  previous_status text not null check (previous_status in ('DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'WITHDRAWN')),
  new_status text not null check (new_status in ('DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'WITHDRAWN')),
  action text not null check (action in ('SUBMIT', 'APPROVE', 'REJECT', 'WITHDRAW', 'RESUBMIT_REQUIRED')),
  remarks text null,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_inspiration_moderation_logs_submission
  on public.inspiration_moderation_logs(submission_id, created_at desc);

create or replace function public.prevent_moderation_log_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'Moderation audit logs are immutable and cannot be updated or deleted.';
end;
$$;

drop trigger if exists trg_inspiration_moderation_logs_immutable on public.inspiration_moderation_logs;
create trigger trg_inspiration_moderation_logs_immutable
  before update or delete on public.inspiration_moderation_logs
  for each row execute function public.prevent_moderation_log_mutation();

create table if not exists public.inspiration_user_favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  quote_id uuid not null references public.quotes(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  constraint uq_inspiration_user_favorite unique (user_id, quote_id)
);

-- -----------------------------------------------------------------------------
-- 5. Visual Assets & Wallpaper Templates (Reuses public.media_assets & public-media)
-- -----------------------------------------------------------------------------
alter table public.media_assets
  add column if not exists width integer null,
  add column if not exists height integer null,
  add column if not exists aspect_ratio text null;

create table if not exists public.inspiration_assets (
  id uuid primary key default gen_random_uuid(),
  media_asset_id uuid not null references public.media_assets(id) on delete cascade,
  asset_role text not null default 'wallpaper_bg' check (asset_role in ('wallpaper_bg', 'illustration', 'card_frame')),
  aspect_ratio text not null default '9:16',
  width integer not null default 1080,
  height integer not null default 1920,
  is_published boolean not null default true,
  created_by uuid null references auth.users(id) on delete set null,
  updated_by uuid null references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz null
);

drop trigger if exists trg_inspiration_assets_updated_at on public.inspiration_assets;
create trigger trg_inspiration_assets_updated_at
  before update on public.inspiration_assets
  for each row execute function public.set_updated_at();

create table if not exists public.inspiration_wallpaper_templates (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  layout_type text not null check (layout_type in ('quote_card_portrait', 'quote_card_square', 'lock_screen', 'home_screen')),
  aspect_ratio text not null default '9:16',
  asset_id uuid null references public.media_assets(id) on delete set null,
  background_type text not null default 'gradient' check (background_type in ('gradient', 'solid', 'image')),
  gradient_colors jsonb not null default '["#1A1B20", "#2B2D36"]'::jsonb,
  text_color text not null default '#F1F3F5',
  font_family text not null default 'serif',
  text_alignment text not null default 'center' check (text_alignment in ('left', 'center', 'right')),
  show_branding boolean not null default true,
  mascot_illustration text null check (mascot_illustration is null or mascot_illustration in ('roo', 'echo', 'seren', 'pippin', 'twill', 'scout', 'flock')),
  locale text null check (locale is null or locale in ('en', 'id')),
  is_published boolean not null default true,
  sort_order integer not null default 0,
  created_by uuid null references auth.users(id) on delete set null,
  updated_by uuid null references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz null
);

drop trigger if exists trg_inspiration_wallpaper_templates_updated_at on public.inspiration_wallpaper_templates;
create trigger trg_inspiration_wallpaper_templates_updated_at
  before update on public.inspiration_wallpaper_templates
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 6. Daily Inspiration Notification Preferences & Delivery Logs (Reusable)
-- -----------------------------------------------------------------------------
create table if not exists public.inspiration_notification_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  daily_enabled boolean not null default false,
  submission_updates_enabled boolean not null default true,
  preferred_time text not null default '08:00',
  timezone text not null default 'UTC',
  frequency text not null default 'DAILY' check (frequency in ('DAILY', 'WEEKDAYS', 'WEEKLY')),
  preferred_locale text not null default 'en' check (preferred_locale in ('en', 'id')),
  preferred_category_ids jsonb not null default '[]'::jsonb,
  last_dispatched_local_date text null,
  last_sent_quote_id uuid null references public.quotes(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

drop trigger if exists trg_inspiration_notification_preferences_updated_at on public.inspiration_notification_preferences;
create trigger trg_inspiration_notification_preferences_updated_at
  before update on public.inspiration_notification_preferences
  for each row execute function public.set_updated_at();

create table if not exists public.inspiration_notification_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid null references public.devices(id) on delete set null,
  notification_type text not null check (notification_type in ('DAILY_INSPIRATION', 'SUBMISSION_APPROVED', 'SUBMISSION_REJECTED')),
  quote_id uuid null references public.quotes(id) on delete set null,
  submission_id uuid null references public.inspiration_quote_submissions(id) on delete set null,
  scheduled_date_local text not null,
  status text not null default 'QUEUED' check (status in ('QUEUED', 'SENT', 'FAILED', 'SKIPPED')),
  attempt_count integer not null default 1 check (attempt_count >= 1),
  dedupe_key text not null unique,
  error_message text null,
  sent_at timestamptz null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_inspiration_notification_logs_user_status
  on public.inspiration_notification_logs(user_id, status, scheduled_date_local);

drop trigger if exists trg_inspiration_notification_logs_updated_at on public.inspiration_notification_logs;
create trigger trg_inspiration_notification_logs_updated_at
  before update on public.inspiration_notification_logs
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 7. Strict Row Level Security (RLS) Policies
-- -----------------------------------------------------------------------------
alter table public.inspiration_authors enable row level security;
alter table public.inspiration_categories enable row level security;
alter table public.inspiration_quote_sources enable row level security;
alter table public.inspiration_quote_translations enable row level security;
alter table public.inspiration_featured_quotes enable row level security;
alter table public.inspiration_user_quotes enable row level security;
alter table public.inspiration_quote_submissions enable row level security;
alter table public.inspiration_moderation_logs enable row level security;
alter table public.inspiration_user_favorites enable row level security;
alter table public.inspiration_assets enable row level security;
alter table public.inspiration_wallpaper_templates enable row level security;
alter table public.inspiration_notification_preferences enable row level security;
alter table public.inspiration_notification_logs enable row level security;

-- Update public quote read policy so unpublished/inactive quotes are hidden
drop policy if exists "quotes_public_read" on public.quotes;
create policy "quotes_public_read"
  on public.quotes for select
  using (
    publication_status = 'PUBLISHED'
    and is_active = true
    and deleted_at is null
  );

drop policy if exists "authors_public_read" on public.inspiration_authors;
create policy "authors_public_read"
  on public.inspiration_authors for select
  using (is_active = true and deleted_at is null);

drop policy if exists "categories_public_read" on public.inspiration_categories;
create policy "categories_public_read"
  on public.inspiration_categories for select
  using (is_active = true and deleted_at is null);

drop policy if exists "sources_public_read" on public.inspiration_quote_sources;
create policy "sources_public_read"
  on public.inspiration_quote_sources for select
  using (deleted_at is null);

drop policy if exists "translations_public_read" on public.inspiration_quote_translations;
create policy "translations_public_read"
  on public.inspiration_quote_translations for select
  using (publication_status = 'PUBLISHED' and is_active = true);

drop policy if exists "featured_public_read" on public.inspiration_featured_quotes;
create policy "featured_public_read"
  on public.inspiration_featured_quotes for select
  using (is_active = true);

drop policy if exists "assets_public_read" on public.inspiration_assets;
create policy "assets_public_read"
  on public.inspiration_assets for select
  using (is_published = true and deleted_at is null);

drop policy if exists "templates_public_read" on public.inspiration_wallpaper_templates;
create policy "templates_public_read"
  on public.inspiration_wallpaper_templates for select
  using (is_published = true and deleted_at is null);

-- User-owned private quotes & favorites & notification prefs
drop policy if exists "user_quotes_own" on public.inspiration_user_quotes;
create policy "user_quotes_own"
  on public.inspiration_user_quotes for all
  using (auth.uid() = user_id and deleted_at is null)
  with check (auth.uid() = user_id);

drop policy if exists "favorites_own" on public.inspiration_user_favorites;
create policy "favorites_own"
  on public.inspiration_user_favorites for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "notif_prefs_own" on public.inspiration_notification_preferences;
create policy "notif_prefs_own"
  on public.inspiration_notification_preferences for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "notif_logs_select_own" on public.inspiration_notification_logs;
create policy "notif_logs_select_own"
  on public.inspiration_notification_logs for select
  using (auth.uid() = user_id);

-- Submissions: users can view/create own non-approved rows & withdraw pending -> withdrawn, NEVER self-approve
drop policy if exists "submissions_select_own" on public.inspiration_quote_submissions;
create policy "submissions_select_own"
  on public.inspiration_quote_submissions for select
  using (auth.uid() = user_id or public.is_moderator_or_admin());

drop policy if exists "submissions_insert_own" on public.inspiration_quote_submissions;
create policy "submissions_insert_own"
  on public.inspiration_quote_submissions for insert
  with check (
    auth.uid() = user_id
    and status in ('DRAFT', 'PENDING')
  );

drop policy if exists "submissions_update_own_withdraw" on public.inspiration_quote_submissions;
create policy "submissions_update_own_withdraw"
  on public.inspiration_quote_submissions for update
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and status in ('DRAFT', 'PENDING', 'WITHDRAWN')
  );

-- Moderator / Admin policies across CMS & Moderation
drop policy if exists "authors_admin_all" on public.inspiration_authors;
create policy "authors_admin_all"
  on public.inspiration_authors for all
  using (public.is_moderator_or_admin())
  with check (public.is_moderator_or_admin());

drop policy if exists "categories_admin_all" on public.inspiration_categories;
create policy "categories_admin_all"
  on public.inspiration_categories for all
  using (public.is_moderator_or_admin())
  with check (public.is_moderator_or_admin());

drop policy if exists "sources_admin_all" on public.inspiration_quote_sources;
create policy "sources_admin_all"
  on public.inspiration_quote_sources for all
  using (public.is_moderator_or_admin())
  with check (public.is_moderator_or_admin());

drop policy if exists "translations_admin_all" on public.inspiration_quote_translations;
create policy "translations_admin_all"
  on public.inspiration_quote_translations for all
  using (public.is_moderator_or_admin())
  with check (public.is_moderator_or_admin());

drop policy if exists "featured_admin_all" on public.inspiration_featured_quotes;
create policy "featured_admin_all"
  on public.inspiration_featured_quotes for all
  using (public.is_moderator_or_admin())
  with check (public.is_moderator_or_admin());

drop policy if exists "submissions_admin_update" on public.inspiration_quote_submissions;
create policy "submissions_admin_update"
  on public.inspiration_quote_submissions for update
  using (public.is_moderator_or_admin() and user_id <> auth.uid())
  with check (public.is_moderator_or_admin() and user_id <> auth.uid());

drop policy if exists "moderation_logs_admin_all" on public.inspiration_moderation_logs;
create policy "moderation_logs_admin_all"
  on public.inspiration_moderation_logs for all
  using (public.is_moderator_or_admin())
  with check (public.is_moderator_or_admin());

drop policy if exists "assets_admin_all" on public.inspiration_assets;
create policy "assets_admin_all"
  on public.inspiration_assets for all
  using (public.is_moderator_or_admin())
  with check (public.is_moderator_or_admin());

drop policy if exists "templates_admin_all" on public.inspiration_wallpaper_templates;
create policy "templates_admin_all"
  on public.inspiration_wallpaper_templates for all
  using (public.is_moderator_or_admin())
  with check (public.is_moderator_or_admin());
