-- =============================================================================
-- Nestin — Initial Supabase Foundation Schema (P0 + P1 Sync Extension Points)
-- Preserves local-first mobile operation: personal operational records remain
-- on-device unless a user explicitly signs up and opts into future sync.
-- =============================================================================

create extension if not exists "pgcrypto";

-- -----------------------------------------------------------------------------
-- Shared timestamp & soft-delete conventions
-- -----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 1. User Profiles (extends auth.users; never stores operational local data by default)
-- -----------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  guest_local_id uuid null,
  display_name text not null default '',
  preferred_language text not null default 'en' check (preferred_language in ('en', 'id')),
  timezone text not null default 'UTC',
  role text not null default 'user' check (role in ('user', 'moderator', 'admin')),
  cloud_sync_opt_in boolean not null default false,
  preferences_snapshot jsonb not null default '{}'::jsonb,
  migrated_from_guest_at timestamptz null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz null
);

create index if not exists idx_profiles_guest_local_id
  on public.profiles(guest_local_id)
  where guest_local_id is not null;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Automatically provision a minimal profile row when a user signs up via Supabase Auth
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, preferred_language)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', ''),
    coalesce(
      case
        when new.raw_user_meta_data ->> 'preferred_language' in ('en', 'id')
          then new.raw_user_meta_data ->> 'preferred_language'
        else 'en'
      end,
      'en'
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- 2. Registered Devices & Push Token Registration
-- -----------------------------------------------------------------------------
create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  device_identifier text not null,
  platform text not null check (platform in ('android', 'ios', 'web', 'desktop', 'other')),
  device_name text null,
  os_version text null,
  app_version text null,
  push_token text null,
  push_provider text null check (push_provider in ('fcm', 'apns', 'none')),
  last_seen_at timestamptz not null default timezone('utc', now()),
  revoked_at timestamptz null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz null,
  constraint uq_devices_user_identifier unique (user_id, device_identifier)
);

create index if not exists idx_devices_user_active
  on public.devices(user_id)
  where deleted_at is null and revoked_at is null;

drop trigger if exists trg_devices_updated_at on public.devices;
create trigger trg_devices_updated_at
  before update on public.devices
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 3. Public Content Library (Guides, Tips, Public Templates)
-- -----------------------------------------------------------------------------
create table if not exists public.content_items (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  summary text not null default '',
  body_markdown text not null default '',
  category text not null,
  tags text[] not null default '{}',
  locale text not null default 'en' check (locale in ('en', 'id')),
  mascot_domain text null check (mascot_domain in ('roo', 'echo', 'seren', 'pippin', 'twill', 'scout', 'flock')),
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  version integer not null default 1 check (version >= 1),
  published_at timestamptz null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz null
);

create index if not exists idx_content_items_published
  on public.content_items(locale, category, published_at desc)
  where status = 'published' and deleted_at is null;

create index if not exists idx_content_items_tags
  on public.content_items using gin(tags);

drop trigger if exists trg_content_items_updated_at on public.content_items;
create trigger trg_content_items_updated_at
  before update on public.content_items
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 4. Motivation Quotes Library
-- -----------------------------------------------------------------------------
create table if not exists public.quotes (
  id uuid primary key default gen_random_uuid(),
  quote_text text not null,
  author text not null default 'Nestin Flock',
  category text not null default 'motivation',
  locale text not null default 'en' check (locale in ('en', 'id')),
  mascot_domain text null check (mascot_domain in ('roo', 'echo', 'seren', 'pippin', 'twill', 'scout', 'flock')),
  is_featured boolean not null default false,
  scheduled_for date null,
  status text not null default 'published' check (status in ('draft', 'published', 'archived')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz null
);

create index if not exists idx_quotes_published
  on public.quotes(locale, category, scheduled_for)
  where status = 'published' and deleted_at is null;

drop trigger if exists trg_quotes_updated_at on public.quotes;
create trigger trg_quotes_updated_at
  before update on public.quotes
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 5. Public Media Assets & Wallpapers Metadata
-- -----------------------------------------------------------------------------
create table if not exists public.media_assets (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  asset_type text not null check (asset_type in ('wallpaper', 'inspiration_card', 'template_pack', 'audio_pack', 'other')),
  storage_bucket text not null default 'public-media',
  storage_path text not null,
  mime_type text not null default 'image/jpeg',
  byte_size bigint not null default 0 check (byte_size >= 0),
  checksum_sha256 text null,
  locale text null check (locale is null or locale in ('en', 'id')),
  mascot_domain text null check (mascot_domain in ('roo', 'echo', 'seren', 'pippin', 'twill', 'scout', 'flock')),
  version integer not null default 1 check (version >= 1),
  status text not null default 'published' check (status in ('draft', 'published', 'archived')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz null
);

create index if not exists idx_media_assets_published
  on public.media_assets(asset_type, mascot_domain)
  where status = 'published' and deleted_at is null;

drop trigger if exists trg_media_assets_updated_at on public.media_assets;
create trigger trg_media_assets_updated_at
  before update on public.media_assets
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 6. Remote Application Configuration & Feature Availability
-- -----------------------------------------------------------------------------
create table if not exists public.remote_configs (
  id uuid primary key default gen_random_uuid(),
  environment text not null default 'production' check (environment in ('development', 'staging', 'production')),
  min_supported_version text not null default '1.0.0',
  latest_version text not null default '1.0.0',
  maintenance_mode boolean not null default false,
  maintenance_message_en text null,
  maintenance_message_id text null,
  feature_flags jsonb not null default '{}'::jsonb,
  config_version integer not null default 1 check (config_version >= 1),
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz null
);

create unique index if not exists uq_remote_configs_active_env
  on public.remote_configs(environment)
  where is_active = true and deleted_at is null;

drop trigger if exists trg_remote_configs_updated_at on public.remote_configs;
create trigger trg_remote_configs_updated_at
  before update on public.remote_configs
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 7. P1 Future Sync Extension Point: Deletion Tombstones Ledger
-- -----------------------------------------------------------------------------
create table if not exists public.sync_tombstones (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  entity_type text not null,
  entity_id uuid not null,
  deleted_at timestamptz not null default timezone('utc', now()),
  source_device_id uuid null references public.devices(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_sync_tombstones_user_since
  on public.sync_tombstones(user_id, deleted_at desc);

-- =============================================================================
-- Row Level Security (RLS) Policies — Least Privilege by Default
-- =============================================================================
alter table public.profiles enable row level security;
alter table public.devices enable row level security;
alter table public.content_items enable row level security;
alter table public.quotes enable row level security;
alter table public.media_assets enable row level security;
alter table public.remote_configs enable row level security;
alter table public.sync_tombstones enable row level security;

-- Helper for RLS role checks
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and role = 'admin'
      and deleted_at is null
  );
$$;

-- Profiles: users can view and update only their own non-deleted profile; role self-escalation prevented via column checks in API
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id and deleted_at is null);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id and deleted_at is null)
  with check (
    auth.uid() = id
    and role = (select role from public.profiles where id = auth.uid())
  );

-- Devices: users strictly manage their own devices
drop policy if exists "devices_all_own" on public.devices;
create policy "devices_all_own"
  on public.devices for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Public Read Policies (Guests + Registered Users can read published/active records)
drop policy if exists "content_public_read" on public.content_items;
create policy "content_public_read"
  on public.content_items for select
  using (status = 'published' and deleted_at is null);

drop policy if exists "quotes_public_read" on public.quotes;
create policy "quotes_public_read"
  on public.quotes for select
  using (status = 'published' and deleted_at is null);

drop policy if exists "media_public_read" on public.media_assets;
create policy "media_public_read"
  on public.media_assets for select
  using (status = 'published' and deleted_at is null);

drop policy if exists "remote_configs_public_read" on public.remote_configs;
create policy "remote_configs_public_read"
  on public.remote_configs for select
  using (is_active = true and deleted_at is null);

-- Admin write extension policies (reserved for future admin panel workflows)
drop policy if exists "content_admin_write" on public.content_items;
create policy "content_admin_write"
  on public.content_items for all
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "quotes_admin_write" on public.quotes;
create policy "quotes_admin_write"
  on public.quotes for all
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "media_admin_write" on public.media_assets;
create policy "media_admin_write"
  on public.media_assets for all
  using (public.is_admin())
  with check (public.is_admin());

-- Sync tombstones: owner only
drop policy if exists "tombstones_own" on public.sync_tombstones;
create policy "tombstones_own"
  on public.sync_tombstones for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
