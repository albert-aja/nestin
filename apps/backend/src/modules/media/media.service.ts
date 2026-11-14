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
