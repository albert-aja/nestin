import { Injectable } from '@nestjs/common';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { SupabaseService } from '../../database/supabase.service';
import { QuotesQueryDto } from './dto/quotes-query.dto';

export interface QuoteView {
  id: string;
  quoteText: string;
  author: string;
  category: string;
  locale: string;
  mascotDomain: string | null;
  isFeatured: boolean;
  scheduledFor: string | null;
}

const STARTER_QUOTES: QuoteView[] = [
  {
    id: '10000000-0000-0000-0000-000000000001',
    quoteText:
      'Start small, keep the rhythm steady, and let your mornings belong to you.',
    author: 'Roo • Time & Planning',
    category: 'morning',
    locale: 'en',
    mascotDomain: 'roo',
    isFeatured: true,
    scheduledFor: null,
  },
  {
    id: '10000000-0000-0000-0000-000000000002',
    quoteText:
      'Mulai dari langkah kecil, jaga ritmemu tetap stabil, dan miliki pagimu dengan tenang.',
    author: 'Roo • Waktu & Perencanaan',
    category: 'morning',
    locale: 'id',
    mascotDomain: 'roo',
    isFeatured: true,
    scheduledFor: null,
  },
  {
    id: '10000000-0000-0000-0000-000000000003',
    quoteText:
      'Rest is part of the craft. Lower the lights and protect your deepest sleep.',
    author: 'Seren • Personal Wellness',
    category: 'sleep',
    locale: 'en',
    mascotDomain: 'seren',
    isFeatured: false,
    scheduledFor: null,
  },
];

@Injectable()
export class QuotesService {
  constructor(private readonly supabaseService: SupabaseService) {}

  async listQuotes(
    query: QuotesQueryDto,
  ): Promise<PaginatedResult<QuoteView>> {
    const client = this.supabaseService.getPublicClient();
    if (!client) {
      return this.filterStarter(query);
    }

    const from = (query.page - 1) * query.limit;
    const to = from + query.limit - 1;

    let builder = client
      .from('quotes')
      .select(
        'id,quote_text,author,category,locale,mascot_domain,is_featured,scheduled_for',
        { count: 'exact' },
      )
      .eq('status', 'published')
      .is('deleted_at', null);

    if (query.locale) builder = builder.eq('locale', query.locale);
    if (query.category) builder = builder.eq('category', query.category);
    if (query.mascotDomain) {
      builder = builder.eq('mascot_domain', query.mascotDomain);
    }
    if (query.featured !== undefined) {
      builder = builder.eq('is_featured', query.featured);
    }

    const { data, count, error } = await builder
      .order('is_featured', { ascending: false })
      .order('created_at', { ascending: false })
      .range(from, to);

    if (error || !data) {
      return this.filterStarter(query);
    }

    return {
      items: data.map((row) => ({
        id: row.id as string,
        quoteText: row.quote_text as string,
        author: row.author as string,
        category: row.category as string,
        locale: row.locale as string,
        mascotDomain: (row.mascot_domain as string | null) ?? null,
        isFeatured: Boolean(row.is_featured),
        scheduledFor: (row.scheduled_for as string | null) ?? null,
      })),
      page: query.page,
      limit: query.limit,
      total: count ?? data.length,
      source: 'supabase',
    };
  }

  async getQuoteOfTheDay(locale: 'en' | 'id' = 'en'): Promise<QuoteView> {
    const res = await this.listQuotes({
      page: 1,
      limit: 1,
      locale,
      featured: true,
    });
    if (res.items.length > 0) {
      return res.items[0];
    }
    return (
      STARTER_QUOTES.find((q) => q.locale === locale) ?? STARTER_QUOTES[0]
    );
  }

  private filterStarter(query: QuotesQueryDto): PaginatedResult<QuoteView> {
    const filtered = STARTER_QUOTES.filter((q) => {
      if (query.locale && q.locale !== query.locale) return false;
      if (query.category && q.category !== query.category) return false;
      if (query.mascotDomain && q.mascotDomain !== query.mascotDomain) {
        return false;
      }
      if (query.featured !== undefined && q.isFeatured !== query.featured) {
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
