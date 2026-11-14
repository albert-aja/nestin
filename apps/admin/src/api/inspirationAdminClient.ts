import {
  InspirationAuthor,
  InspirationCategory,
  InspirationFeaturedSchedule,
  InspirationModerationLog,
  InspirationNotificationLog,
  InspirationQuote,
  InspirationSubmission,
  InspirationTranslation,
  InspirationWallpaperTemplate,
  NestinLocale,
} from '../types/inspiration';

export class ApiClientError extends Error {
  constructor(
    message: string,
    public readonly statusCode: number,
  ) {
    super(message);
    this.name = 'ApiClientError';
  }
}

export class InspirationAdminClient {
  constructor(
    private readonly baseUrl: string,
    private readonly getToken: () => string,
  ) {}

  private async request<T>(
    path: string,
    init: RequestInit = {},
  ): Promise<T> {
    const cleanBase = this.baseUrl.replace(/\/+$/, '');
    const token = this.getToken();
    const res = await fetch(`${cleanBase}/api/v1/admin/inspiration${path}`, {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(init.headers ?? {}),
      },
    });

    const json = (await res.json().catch(() => ({}))) as {
      data?: T;
      error?: { message?: string };
      message?: string;
    };
    if (!res.ok) {
      throw new ApiClientError(
        json.error?.message ?? json.message ?? `HTTP ${res.status}`,
        res.status,
      );
    }
    return json.data as T;
  }

  // Quotes
  listQuotes(params?: {
    search?: string;
    category?: string;
    locale?: string;
  }): Promise<InspirationQuote[]> {
    const qs = new URLSearchParams({ limit: '50' });
    if (params?.search) qs.set('search', params.search);
    if (params?.category) qs.set('category', params.category);
    if (params?.locale) qs.set('locale', params.locale);
    return this.request<InspirationQuote[]>(`/quotes?${qs.toString()}`);
  }

  createQuote(payload: {
    quoteText: string;
    author: string;
    categoryId?: string;
    locale: NestinLocale;
    mascotDomain?: string;
    publicationStatus: 'DRAFT' | 'PUBLISHED' | 'ARCHIVED';
    sourceReference?: string;
  }): Promise<InspirationQuote> {
    return this.request<InspirationQuote>('/quotes', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  publishQuote(id: string): Promise<InspirationQuote> {
    return this.request<InspirationQuote>(`/quotes/${id}/publish`, {
      method: 'POST',
    });
  }

  unpublishQuote(id: string): Promise<InspirationQuote> {
    return this.request<InspirationQuote>(`/quotes/${id}/unpublish`, {
      method: 'POST',
    });
  }

  archiveQuote(id: string): Promise<InspirationQuote> {
    return this.request<InspirationQuote>(`/quotes/${id}/archive`, {
      method: 'POST',
    });
  }

  deleteQuote(id: string): Promise<{ deleted: true }> {
    return this.request<{ deleted: true }>(`/quotes/${id}`, {
      method: 'DELETE',
    });
  }

  // Authors
  listAuthors(): Promise<InspirationAuthor[]> {
    return this.request<InspirationAuthor[]>('/authors');
  }

  createAuthor(payload: {
    name: string;
    bio?: string;
    isAnonymousOrUnknown?: boolean;
    mascotDomain?: string;
  }): Promise<InspirationAuthor> {
    return this.request<InspirationAuthor>('/authors', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  // Categories
  listCategories(): Promise<InspirationCategory[]> {
    return this.request<InspirationCategory[]>('/categories');
  }

  createCategory(payload: {
    slug: string;
    name: string;
    description?: string;
    translations?: Record<string, { name: string; description?: string }>;
    mascotDomain?: string;
    sortOrder?: number;
  }): Promise<InspirationCategory> {
    return this.request<InspirationCategory>('/categories', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  updateCategory(
    id: string,
    payload: Partial<{
      name: string;
      description: string;
      isActive: boolean;
      sortOrder: number;
    }>,
  ): Promise<InspirationCategory> {
    return this.request<InspirationCategory>(`/categories/${id}`, {
      method: 'PUT',
      body: JSON.stringify(payload),
    });
  }

  // Submissions & Moderation
  listSubmissions(status?: string): Promise<InspirationSubmission[]> {
    const qs = new URLSearchParams({ limit: '50' });
    if (status) qs.set('status', status);
    return this.request<InspirationSubmission[]>(
      `/submissions?${qs.toString()}`,
    );
  }

  approveSubmission(
    id: string,
    remarks?: string,
  ): Promise<InspirationSubmission> {
    return this.request<InspirationSubmission>(`/submissions/${id}/approve`, {
      method: 'POST',
      body: JSON.stringify(remarks ? { remarks } : {}),
    });
  }

  rejectSubmission(
    id: string,
    rejectionReason: string,
    remarks?: string,
  ): Promise<InspirationSubmission> {
    return this.request<InspirationSubmission>(`/submissions/${id}/reject`, {
      method: 'POST',
      body: JSON.stringify({ rejectionReason, remarks }),
    });
  }

  getSubmissionHistory(id: string): Promise<InspirationModerationLog[]> {
    return this.request<InspirationModerationLog[]>(
      `/submissions/${id}/history`,
    );
  }

  // Featured Schedules
  listFeaturedSchedules(): Promise<InspirationFeaturedSchedule[]> {
    return this.request<InspirationFeaturedSchedule[]>('/featured');
  }

  createFeaturedSchedule(payload: {
    quoteId: string;
    locale: NestinLocale;
    publicationDate: string;
    startAt: string;
    endAt: string;
    priority?: number;
  }): Promise<InspirationFeaturedSchedule> {
    return this.request<InspirationFeaturedSchedule>('/featured', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  deleteFeaturedSchedule(id: string): Promise<{ deleted: true }> {
    return this.request<{ deleted: true }>(`/featured/${id}`, {
      method: 'DELETE',
    });
  }

  // Wallpapers & Translations
  listWallpapers(): Promise<InspirationWallpaperTemplate[]> {
    return this.request<InspirationWallpaperTemplate[]>('/wallpapers');
  }

  createWallpaperTemplate(payload: {
    slug: string;
    name: string;
    layoutType:
      | 'quote_card_portrait'
      | 'quote_card_square'
      | 'lock_screen'
      | 'home_screen';
    aspectRatio: string;
    gradientColors?: string[];
    textColor?: string;
    fontFamily?: string;
    mascotIllustration?: string;
  }): Promise<InspirationWallpaperTemplate> {
    return this.request<InspirationWallpaperTemplate>('/wallpapers', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  listTranslations(): Promise<InspirationTranslation[]> {
    return this.request<InspirationTranslation[]>('/translations');
  }

  upsertTranslation(payload: {
    quoteId: string;
    locale: NestinLocale;
    quoteText: string;
    authorDisplay: string;
    publicationStatus: 'DRAFT' | 'PUBLISHED' | 'ARCHIVED';
  }): Promise<InspirationTranslation> {
    return this.request<InspirationTranslation>('/translations', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  listNotificationLogs(): Promise<InspirationNotificationLog[]> {
    return this.request<InspirationNotificationLog[]>('/notifications/logs');
  }

  triggerDailyDispatch(): Promise<{
    evaluatedUsers: number;
    sentCount: number;
    skippedCount: number;
    failedCount: number;
  }> {
    return this.request('/notifications/dispatch-due', { method: 'POST' });
  }
}
