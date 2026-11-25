import { Injectable, NotFoundException } from '@nestjs/common';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { SupabaseService } from '../../database/supabase.service';
import { MediaQueryDto } from './dto/media-query.dto';

export interface MediaAssetView {
  id: string;
  slug: string;
  title: string;
  assetType: string;
  storageBucket: string;
  storagePath: string;
  publicUrl: string | null;
  mimeType: string;
  byteSize: number;
  checksumSha256: string | null;
  locale: string | null;
  mascotDomain: string | null;
  version: number;
}

const STARTER_MEDIA: MediaAssetView[] = [
  {
    id: '30000000-0000-0000-0000-000000000001',
    slug: 'flock-dawn-wallpaper',
    title: 'Nestin Flock Dawn Backdrop',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/flock_dawn_v1.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 245760,
    checksumSha256: null,
    locale: 'en',
    mascotDomain: 'flock',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000002',
    slug: 'seren-night-calm-card',
    title: 'Seren Night Wind-Down Card',
    assetType: 'inspiration_card',
    storageBucket: 'public-media',
    storagePath: 'cards/seren_night_calm_v1.png',
    publicUrl: null,
    mimeType: 'image/png',
    byteSize: 163840,
    checksumSha256: null,
    locale: 'en',
    mascotDomain: 'seren',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000003',
    slug: 'cherry-blossom-picnic',
    title: 'Cherry Blossom Picnic Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/seasonal/cherry_blossom_picnic.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 262144,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'pippin',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000004',
    slug: 'winter-snow-cabin',
    title: 'Winter Snow Cabin Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/seasonal/winter_snow_cabin.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 278528,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'echo',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000005',
    slug: 'sunset-seaside-lighthouse',
    title: 'Sunset Seaside Lighthouse Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/seasonal/sunset_seaside_lighthouse.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 253952,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'scout',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000006',
    slug: 'tropical-bamboo-mist',
    title: 'Tropical Bamboo Mist Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/seasonal/tropical_bamboo_mist.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 249856,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'seren',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000007',
    slug: 'botanical-greenhouse',
    title: 'Botanical Greenhouse Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/everyday/everyday_botanical_greenhouse.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 258048,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'pippin',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000008',
    slug: 'cozy-library-rain',
    title: 'Rainy Library Reading Nook Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/everyday/everyday_cozy_library_rain.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 266240,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'echo',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000009',
    slug: 'morning-bakery-veranda',
    title: 'Morning Bakery Veranda Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/everyday/everyday_morning_bakery_veranda.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 247808,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'twill',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000010',
    slug: 'hilltop-stargazing',
    title: 'Hilltop Stargazing Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/everyday/everyday_hilltop_stargazing.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 241664,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'echo',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000011',
    slug: 'mountain-camp-morning',
    title: 'Mountain Camp Morning Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/everyday/everyday_mountain_camp.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 256000,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'scout',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000012',
    slug: 'flock-sky-huddle',
    title: 'Flock Open Sky Huddle Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/everyday/everyday_flock_huddle_sky.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 237568,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'roo',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000013',
    slug: 'roo-morning-wakeup',
    title: 'Roo Morning Wake-Up Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/everyday/everyday_roo_morning_wakeup.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 251904,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'roo',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000014',
    slug: 'scout-departure-brief',
    title: 'Scout Morning Briefing Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/everyday/everyday_scout_departure_brief.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 249856,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'scout',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000015',
    slug: 'seren-calm-circle',
    title: 'Seren Calm Circle Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/everyday/everyday_seren_calm_circle.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 245760,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'seren',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000016',
    slug: 'pippin-hobby-studio',
    title: 'Pippin Hobby Studio Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/everyday/everyday_pippin_hobby_studio.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 260096,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'pippin',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000017',
    slug: 'twill-packing-ledger',
    title: 'Twill Organizer Desk Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/everyday/everyday_twill_packing_ledger.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 253952,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'twill',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000018',
    slug: 'echo-gratitude-jar',
    title: 'Echo Gratitude Jar Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/everyday/everyday_echo_gratitude_jar.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 247808,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'echo',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000019',
    slug: 'flock-overhead-circle',
    title: 'Flock Overhead Circle Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/everyday/everyday_flock_overhead_circle.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 243712,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'flock',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000020',
    slug: 'flock-overhead-circle-close',
    title: 'Flock Close-Up Circle Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/everyday/everyday_flock_overhead_circle_close.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 241664,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'flock',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000021',
    slug: 'flock-side-stack',
    title: 'Flock Side Stack Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/everyday/everyday_flock_side_stack.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 239616,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'flock',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000022',
    slug: 'flock-stacked-totem',
    title: 'Flock Cozy Totem Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/everyday/everyday_flock_stacked_totem.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 237568,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'flock',
    version: 1,
  },
  {
    id: '30000000-0000-0000-0000-000000000023',
    slug: 'flock-tiered-pyramid',
    title: 'Flock Tiered Pyramid Pack',
    assetType: 'wallpaper',
    storageBucket: 'public-media',
    storagePath: 'wallpapers/everyday/everyday_flock_tiered_pyramid.jpg',
    publicUrl: null,
    mimeType: 'image/jpeg',
    byteSize: 241664,
    checksumSha256: null,
    locale: null,
    mascotDomain: 'flock',
    version: 1,
  },
];

@Injectable()
export class MediaService {
  constructor(private readonly supabaseService: SupabaseService) {}

  async listAssets(
    query: MediaQueryDto,
  ): Promise<PaginatedResult<MediaAssetView>> {
    const client = this.supabaseService.getPublicClient();
    if (!client) {
      return this.filterStarter(query);
    }

    const from = (query.page - 1) * query.limit;
    const to = from + query.limit - 1;

    let builder = client
      .from('media_assets')
      .select(
        'id,slug,title,asset_type,storage_bucket,storage_path,mime_type,byte_size,checksum_sha256,locale,mascot_domain,version',
        { count: 'exact' },
      )
      .eq('status', 'published')
      .is('deleted_at', null);

    if (query.assetType) builder = builder.eq('asset_type', query.assetType);
    if (query.locale) builder = builder.eq('locale', query.locale);
    if (query.mascotDomain) {
      builder = builder.eq('mascot_domain', query.mascotDomain);
    }

    const { data, count, error } = await builder
      .order('created_at', { ascending: false })
      .range(from, to);

    if (error || !data) {
      return this.filterStarter(query);
    }

    return {
      items: data.map((row) => this.mapRow(row)),
      page: query.page,
      limit: query.limit,
      total: count ?? data.length,
      source: 'supabase',
    };
  }

  async findBySlug(slug: string): Promise<MediaAssetView> {
    const client = this.supabaseService.getPublicClient();
    if (client) {
      const { data } = await client
        .from('media_assets')
        .select(
          'id,slug,title,asset_type,storage_bucket,storage_path,mime_type,byte_size,checksum_sha256,locale,mascot_domain,version',
        )
        .eq('slug', slug)
        .eq('status', 'published')
        .is('deleted_at', null)
        .maybeSingle();

      if (data) {
        return this.mapRow(data);
      }
    }

    const fallback = STARTER_MEDIA.find((item) => item.slug === slug);
    if (!fallback) {
      throw new NotFoundException(`Published media asset "${slug}" not found`);
    }
    return fallback;
  }

  private mapRow(row: Record<string, unknown>): MediaAssetView {
    const bucket = row.storage_bucket as string;
    const path = row.storage_path as string;
    const base = this.supabaseService.storagePublicBaseUrl;
    return {
      id: row.id as string,
      slug: row.slug as string,
      title: row.title as string,
      assetType: row.asset_type as string,
      storageBucket: bucket,
      storagePath: path,
      publicUrl: base ? `${base}/${bucket}/${path}` : null,
      mimeType: row.mime_type as string,
      byteSize: Number(row.byte_size ?? 0),
      checksumSha256: (row.checksum_sha256 as string | null) ?? null,
      locale: (row.locale as string | null) ?? null,
      mascotDomain: (row.mascot_domain as string | null) ?? null,
      version: Number(row.version ?? 1),
    };
  }

  private filterStarter(query: MediaQueryDto): PaginatedResult<MediaAssetView> {
    const filtered = STARTER_MEDIA.filter((item) => {
      if (query.assetType && item.assetType !== query.assetType) return false;
      if (query.locale && item.locale && item.locale !== query.locale) {
        return false;
      }
      if (query.mascotDomain && item.mascotDomain !== query.mascotDomain) {
        return false;
      }
      return true;
    });
    const start = (query.page - 1) * query.limit;
    return {
      items: filtered.slice(start, start + query.limit),
      page: query.page,
      limit: query.limit,
      total: filtered.length,
      source: 'starter_fallback',
    };
  }
}
