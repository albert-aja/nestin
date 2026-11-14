-- =============================================================================
-- Nestin — Seed Data for Public Content, Quotes, Media Metadata & Remote Config
-- =============================================================================

insert into public.quotes (
  id, quote_text, author, category, locale, mascot_domain, is_featured, status
) values
  (
    '10000000-0000-0000-0000-000000000001',
    'Start small, keep the rhythm steady, and let your mornings belong to you.',
    'Roo • Time & Planning',
    'morning',
    'en',
    'roo',
    true,
    'published'
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    'Mulai dari langkah kecil, jaga ritmemu tetap stabil, dan miliki pagimu dengan tenang.',
    'Roo • Waktu & Perencanaan',
    'morning',
    'id',
    'roo',
    true,
    'published'
  ),
  (
    '10000000-0000-0000-0000-000000000003',
    'Rest is part of the craft. Lower the lights and protect your deepest sleep.',
    'Seren • Personal Wellness',
    'sleep',
    'en',
    'seren',
    false,
    'published'
  ),
  (
    '10000000-0000-0000-0000-000000000004',
    'Simplicity in your budget buys peace of mind for every ordinary day.',
    'Twill • Notes & Organization',
    'finance',
    'en',
    'twill',
    false,
    'published'
  )
on conflict (id) do nothing;

insert into public.content_items (
  id, slug, title, summary, body_markdown, category, tags, locale, mascot_domain, status, version, published_at
) values
  (
    '20000000-0000-0000-0000-000000000001',
    'seren-5h-caffeine-guide-en',
    'Why a 5-Hour Caffeine Cutoff Protects Deep Sleep',
    'Understanding how afternoon espresso or matcha lingers until bedtime.',
    E'# Afternoon Caffeine & Sleep Cycles\n\nCaffeine has an average half-life of roughly **5 hours**. A 95mg cup at 15:00 leaves nearly 35–45mg circulating at 22:00.\n\n- Keep an 8-hour buffer before target bedtime.\n- Switch to water or herbal tea after your afternoon cutoff.',
    'wellness',
    array['caffeine', 'sleep', 'seren'],
    'en',
    'seren',
    'published',
    1,
    timezone('utc', now())
  ),
  (
    '20000000-0000-0000-0000-000000000002',
    'seren-5h-caffeine-guide-id',
    'Mengapa Batas Kafein Sore Melindungi Tidur Nyenyak',
    'Memahami bagaimana kopi atau matcha sore masih tersisa saat jam tidur.',
    E'# Kafein Sore & Siklus Tidur\n\nKafein memiliki waktu paruh rata-rata sekitar **5 jam**. Segelas kopi 95mg pukul 15:00 masih menyisakan sekitar 35–45mg pada pukul 22:00.\n\n- Beri jeda 8 jam sebelum target jam tidur.\n- Beralihlah ke air putih atau teh herbal setelah batas sore.',
    'wellness',
    array['kafein', 'tidur', 'seren'],
    'id',
    'seren',
    'published',
    1,
    timezone('utc', now())
  ),
  (
    '20000000-0000-0000-0000-000000000003',
    'twill-simple-envelope-budget-en',
    'Everyday Money Clarity with Four Simple Wallets',
    'Organize cash, bank accounts, and e-wallets without complex spreadsheets.',
    E'# Keep Everyday Budgeting Practical\n\nTrack only what matters daily:\n1. Separate initial balances from new income.\n2. Record internal transfers cleanly without inflating expenses.\n3. Review monthly category limits weekly.',
    'money_basics',
    array['budget', 'twill', 'wallets'],
    'en',
    'twill',
    'published',
    1,
    timezone('utc', now())
  )
on conflict (slug) do nothing;

insert into public.media_assets (
  id, slug, title, asset_type, storage_bucket, storage_path, mime_type, byte_size, locale, mascot_domain, version, status
) values
  (
    '30000000-0000-0000-0000-000000000001',
    'flock-dawn-wallpaper',
    'Nestin Flock Dawn Backdrop',
    'wallpaper',
    'public-media',
    'wallpapers/flock_dawn_v1.jpg',
    'image/jpeg',
    245760,
    'en',
    'flock',
    1,
    'published'
  ),
  (
    '30000000-0000-0000-0000-000000000002',
    'seren-night-calm-card',
    'Seren Night Wind-Down Card',
    'inspiration_card',
    'public-media',
    'cards/seren_night_calm_v1.png',
    'image/png',
    163840,
    'en',
    'seren',
    1,
    'published'
  )
on conflict (slug) do nothing;

insert into public.remote_configs (
  id,
  environment,
  min_supported_version,
  latest_version,
  maintenance_mode,
  maintenance_message_en,
  maintenance_message_id,
  feature_flags,
  config_version,
  is_active
) values
  (
    '40000000-0000-0000-0000-000000000001',
    'production',
    '1.0.0',
    '1.0.0',
    false,
    null,
    null,
    '{"publicQuotesEnabled": true, "publicContentEnabled": true, "mediaDownloadsEnabled": true, "cloudBackupEnabled": false, "cloudSyncEnabled": false}'::jsonb,
    1,
    true
  ),
  (
    '40000000-0000-0000-0000-000000000002',
    'development',
    '1.0.0',
    '1.0.0',
    false,
    null,
    null,
    '{"publicQuotesEnabled": true, "publicContentEnabled": true, "mediaDownloadsEnabled": true, "cloudBackupEnabled": false, "cloudSyncEnabled": false}'::jsonb,
    1,
    true
  )
on conflict (id) do nothing;

-- =============================================================================
-- Inspiration Module Starter Categories, Authors, Translations & Templates
-- =============================================================================

insert into public.inspiration_categories (
  id, slug, default_locale, name, description, translations, mascot_domain, sort_order, is_active
) values
  (
    '51000000-0000-0000-0000-000000000001',
    'motivation',
    'en',
    'Motivation',
    'Steady encouragement for everyday momentum.',
    '{"en": {"name": "Motivation", "description": "Steady encouragement for everyday momentum."}, "id": {"name": "Motivasi", "description": "Semangat tenang untuk menjaga momentum harian."}}'::jsonb,
    'roo',
    1,
    true
  ),
  (
    '51000000-0000-0000-0000-000000000002',
    'personal-growth',
    'en',
    'Personal Growth',
    'Small consistent habits and thoughtful self-development.',
    '{"en": {"name": "Personal Growth", "description": "Small consistent habits and thoughtful self-development."}, "id": {"name": "Pengembangan Diri", "description": "Kebiasaan kecil yang konsisten dan refleksi diri."}}'::jsonb,
    'pippin',
    2,
    true
  ),
  (
    '51000000-0000-0000-0000-000000000003',
    'productivity',
    'en',
    'Productivity',
    'Clarity over urgency and calm daily focus.',
    '{"en": {"name": "Productivity", "description": "Clarity over urgency and calm daily focus."}, "id": {"name": "Produktivitas", "description": "Kejernihan fokus tanpa terburu-buru."}}'::jsonb,
    'roo',
    3,
    true
  ),
  (
    '51000000-0000-0000-0000-000000000004',
    'mental-wellness',
    'en',
    'Mental Wellness',
    'Gentle pauses, rest, and emotional balance.',
    '{"en": {"name": "Mental Wellness", "description": "Gentle pauses, rest, and emotional balance."}, "id": {"name": "Kesehatan Mental", "description": "Jeda lembut, istirahat, dan keseimbangan batin."}}'::jsonb,
    'seren',
    4,
    true
  ),
  (
    '51000000-0000-0000-0000-000000000005',
    'gratitude',
    'en',
    'Gratitude',
    'Noticing quiet goodness in ordinary moments.',
    '{"en": {"name": "Gratitude", "description": "Noticing quiet goodness in ordinary moments."}, "id": {"name": "Rasa Syukur", "description": "Menyadari kebaikan sederhana dalam keseharian."}}'::jsonb,
    'echo',
    5,
    true
  ),
  (
    '51000000-0000-0000-0000-000000000006',
    'relationships',
    'en',
    'Relationships',
    'Presence, kindness, and patience with others.',
    '{"en": {"name": "Relationships", "description": "Presence, kindness, and patience with others."}, "id": {"name": "Hubungan", "description": "Kehadiran, kebaikan hati, dan kesabaran bersama sesama."}}'::jsonb,
    'scout',
    6,
    true
  ),
  (
    '51000000-0000-0000-0000-000000000007',
    'philosophy',
    'en',
    'Philosophy',
    'Timeless perspectives on peace and attention.',
    '{"en": {"name": "Philosophy", "description": "Timeless perspectives on peace and attention."}, "id": {"name": "Filsafat", "description": "Perspektif klasik tentang ketenangan dan makna."}}'::jsonb,
    'echo',
    7,
    true
  ),
  (
    '51000000-0000-0000-0000-000000000008',
    'financial-mindset',
    'en',
    'Financial Mindset',
    'Calm sufficiency, intentional spending, and clarity.',
    '{"en": {"name": "Financial Mindset", "description": "Calm sufficiency, intentional spending, and clarity."}, "id": {"name": "Pola Pikir Keuangan", "description": "Kecukupan yang tenang dan perencanaan yang sadar."}}'::jsonb,
    'twill',
    8,
    true
  ),
  (
    '51000000-0000-0000-0000-000000000009',
    'life-lessons',
    'en',
    'Life Lessons',
    'Practical wisdom gathered from everyday experience.',
    '{"en": {"name": "Life Lessons", "description": "Practical wisdom gathered from everyday experience."}, "id": {"name": "Pelajaran Hidup", "description": "Kebijaksanaan praktis dari pengalaman sehari-hari."}}'::jsonb,
    'flock',
    9,
    true
  )
on conflict (slug) do nothing;

insert into public.inspiration_authors (
  id, name, slug, bio, is_anonymous_or_unknown, mascot_domain, is_active
) values
  (
    '52000000-0000-0000-0000-000000000001',
    'Roo • Time & Planning',
    'roo-time-planning',
    'Nestin morning companion for steady starts.',
    false,
    'roo',
    true
  ),
  (
    '52000000-0000-0000-0000-000000000002',
    'Seren • Personal Wellness',
    'seren-wellness',
    'Nestin dove guiding calm rest and hydration.',
    false,
    'seren',
    true
  ),
  (
    '52000000-0000-0000-0000-000000000003',
    'Twill • Notes & Organization',
    'twill-organization',
    'Nestin weaverbird for clarity in notes and everyday money.',
    false,
    'twill',
    true
  ),
  (
    '52000000-0000-0000-0000-000000000004',
    'Anonymous Contributor',
    'anonymous',
    'Shared quietly without public attribution.',
    true,
    null,
    true
  )
on conflict (slug) do nothing;

insert into public.inspiration_wallpaper_templates (
  id, slug, name, layout_type, aspect_ratio, background_type, gradient_colors, text_color, font_family, text_alignment, show_branding, mascot_illustration, is_published, sort_order
) values
  (
    '53000000-0000-0000-0000-000000000001',
    'sunrise-warmth-portrait',
    'Sunrise Warmth Portrait',
    'quote_card_portrait',
    '4:5',
    'gradient',
    '["#1F1722", "#6A2B2D", "#D97736"]'::jsonb,
    '#FFF7ED',
    'serif',
    'center',
    true,
    'roo',
    true,
    1
  ),
  (
    '53000000-0000-0000-0000-000000000002',
    'seren-mist-lockscreen',
    'Seren Mist Lock Screen',
    'lock_screen',
    '9:16',
    'gradient',
    '["#0F172A", "#1E3A3A", "#335C67"]'::jsonb,
    '#F8FAFC',
    'sans',
    'center',
    true,
    'seren',
    true,
    2
  ),
  (
    '53000000-0000-0000-0000-000000000003',
    'paper-linen-square',
    'Paper Linen Square',
    'quote_card_square',
    '1:1',
    'solid',
    '["#F6F1E9", "#F6F1E9"]'::jsonb,
    '#1F2430',
    'serif',
    'left',
    true,
    'echo',
    true,
    3
  ),
  (
    '53000000-0000-0000-0000-000000000004',
    'obsidian-calm-homescreen',
    'Obsidian Calm Home Screen',
    'home_screen',
    '9:16',
    'gradient',
    '["#111215", "#1E2028", "#252834"]'::jsonb,
    '#F1F3F5',
    'display',
    'center',
    false,
    null,
    true,
    4
  )
on conflict (slug) do nothing;
