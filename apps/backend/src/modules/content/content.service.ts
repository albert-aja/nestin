import { Injectable, NotFoundException } from '@nestjs/common';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { SupabaseService } from '../../database/supabase.service';
import { ContentQueryDto } from './dto/content-query.dto';

export interface ContentItemView {
  id: string;
  slug: string;
  title: string;
  summary: string;
  bodyMarkdown: string;
  category: string;
  tags: string[];
  locale: string;
  mascotDomain: string | null;
  version: number;
  publishedAt: string | null;
}

const STARTER_CONTENT: ContentItemView[] = [
  {
    id: '20000000-0000-0000-0000-000000000001',
    slug: 'seren-5h-caffeine-guide-en',
    title: 'Why a 5-Hour Caffeine Cutoff Protects Deep Sleep',
    summary:
      'Understanding how afternoon espresso or matcha lingers until bedtime.',
    bodyMarkdown:
      '# Afternoon Caffeine & Sleep Cycles\n\nCaffeine has an average half-life of roughly **5 hours**. Switch to water or herbal tea after your afternoon cutoff.',
    category: 'wellness',
    tags: ['caffeine', 'sleep', 'seren'],
    locale: 'en',
    mascotDomain: 'seren',
    version: 1,
    publishedAt: '2026-11-14T00:00:00.000Z',
  },
  {
    id: '20000000-0000-0000-0000-000000000002',
    slug: 'seren-5h-caffeine-guide-id',
    title: 'Mengapa Batas Kafein Sore Melindungi Tidur Nyenyak',
    summary:
      'Memahami bagaimana kopi atau matcha sore masih tersisa saat jam tidur.',
    bodyMarkdown:
      '# Kafein Sore & Siklus Tidur\n\nKafein memiliki waktu paruh rata-rata sekitar **5 jam**. Beralihlah ke air putih atau teh herbal setelah batas sore.',
    category: 'wellness',
    tags: ['kafein', 'tidur', 'seren'],
    locale: 'id',
    mascotDomain: 'seren',
    version: 1,
    publishedAt: '2026-11-14T00:00:00.000Z',
  },
];

@Injectable()
export class ContentService {
  constructor(private readonly supabaseService: SupabaseService) {}

  async listPublished(
    query: ContentQueryDto,
  ): Promise<PaginatedResult<ContentItemView>> {
    const client = this.supabaseService.getPublicClient();
    if (!client) {
      return this.filterStarter(query);
    }

    const from = (query.page - 1) * query.limit;
    const to = from + query.limit - 1;

    let builder = client
      .from('content_items')
      .select(
        'id,slug,title,summary,body_markdown,category,tags,locale,mascot_domain,version,published_at',
        { count: 'exact' },
      )
      .eq('status', 'published')
      .is('deleted_at', null);

    if (query.locale) builder = builder.eq('locale', query.locale);
    if (query.category) builder = builder.eq('category', query.category);
    if (query.mascotDomain) {
      builder = builder.eq('mascot_domain', query.mascotDomain);
    }
    if (query.tag) builder = builder.contains('tags', [query.tag]);

    const { data, count, error } = await builder
      .order('published_at', { ascending: false })
      .range(from, to);

    if (error || !data) {
      return this.filterStarter(query);
    }

    return {
      items: data.map((row) => ({
        id: row.id as string,
        slug: row.slug as string,
        title: row.title as string,
        summary: row.summary as string,
        bodyMarkdown: row.body_markdown as string,
        category: row.category as string,
        tags: (row.tags as string[]) ?? [],
        locale: row.locale as string,
        mascotDomain: (row.mascot_domain as string | null) ?? null,
        version: row.version as number,
        publishedAt: (row.published_at as string | null) ?? null,
      })),
      page: query.page,
      limit: query.limit,
      total: count ?? data.length,
      source: 'supabase',
    };
  }

  async findBySlug(slug: string): Promise<ContentItemView> {
    const client = this.supabaseService.getPublicClient();
    if (client) {
      const { data } = await client
        .from('content_items')
        .select(
          'id,slug,title,summary,body_markdown,category,tags,locale,mascot_domain,version,published_at',
        )
        .eq('slug', slug)
        .eq('status', 'published')
        .is('deleted_at', null)
        .maybeSingle();

      if (data) {
        return {
          id: data.id as string,
          slug: data.slug as string,
          title: data.title as string,
          summary: data.summary as string,
          bodyMarkdown: data.body_markdown as string,
          category: data.category as string,
          tags: (data.tags as string[]) ?? [],
          locale: data.locale as string,
          mascotDomain: (data.mascot_domain as string | null) ?? null,
          version: data.version as number,
          publishedAt: (data.published_at as string | null) ?? null,
        };
      }
    }

    const fallback = STARTER_CONTENT.find((item) => item.slug === slug);
    if (!fallback) {
      throw new NotFoundException(`Published content "${slug}" not found`);
    }
    return fallback;
  }

  private filterStarter(
    query: ContentQueryDto,
  ): PaginatedResult<ContentItemView> {
    const filtered = STARTER_CONTENT.filter((item) => {
      if (query.locale && item.locale !== query.locale) return false;
      if (query.category && item.category !== query.category) return false;
      if (query.mascotDomain && item.mascotDomain !== query.mascotDomain) {
        return false;
      }
      if (query.tag && !item.tags.includes(query.tag)) return false;
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
