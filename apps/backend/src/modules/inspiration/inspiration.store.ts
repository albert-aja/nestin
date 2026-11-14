import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { SupabaseService } from '../../database/supabase.service';
import { AuthenticatedUser } from '../../common/decorators/current-user.decorator';
import {
  AdminCreateAuthorDto,
  AdminCreateCategoryDto,
  AdminCreateFeaturedScheduleDto,
  AdminCreateQuoteDto,
  AdminCreateWallpaperTemplateDto,
  AdminSubmissionsQueryDto,
  AdminUpdateAuthorDto,
  AdminUpdateCategoryDto,
  AdminUpdateQuoteDto,
  AdminUpsertTranslationDto,
  ApproveSubmissionDto,
  CreateUserQuoteDto,
  InspirationQuotesQueryDto,
  RejectSubmissionDto,
  ReportQuoteDto,
  SubmitQuoteDto,
  UpdateNotificationPreferencesDto,
  UpdateUserQuoteDto,
  WallpapersQueryDto,
} from './dto/inspiration.dto';
import { InspirationNotificationService } from './inspiration-notification.service';
import {
  SEED_AUTHORS,
  SEED_CATEGORIES,
  SEED_FEATURED_SCHEDULES,
  SEED_QUOTES,
  SEED_TRANSLATIONS,
  SEED_WALLPAPER_TEMPLATES,
} from './inspiration.seed';
import {
  InspirationAuthorRecord,
  InspirationCategoryRecord,
  InspirationFavoriteRecord,
  InspirationFeaturedScheduleRecord,
  InspirationModerationLogRecord,
  InspirationNotificationPreferenceRecord,
  InspirationQuoteRecord,
  InspirationQuoteReportRecord,
  InspirationSubmissionRecord,
  InspirationTranslationRecord,
  InspirationUserQuoteRecord,
  InspirationWallpaperTemplateRecord,
  NestinLocale,
} from './inspiration.types';

/**
 * Dual-mode repository for the Inspiration module:
 * - Reads/writes Supabase tables when `SupabaseService.isConfigured` is true.
 * - Uses deterministic seeded in-memory state when running offline/e2e without
 *   a live Supabase project, enforcing identical authorization, moderation, and
 *   scheduling invariants.
 */
@Injectable()
export class InspirationStore {
  private readonly categories: InspirationCategoryRecord[] = SEED_CATEGORIES.map(
    (c) => ({ ...c, translations: { ...c.translations } }),
  );
  private readonly authors: InspirationAuthorRecord[] = SEED_AUTHORS.map(
    (a) => ({ ...a }),
  );
  private readonly quotes: InspirationQuoteRecord[] = SEED_QUOTES.map((q) => ({
    ...q,
  }));
  private readonly featuredSchedules: InspirationFeaturedScheduleRecord[] =
    SEED_FEATURED_SCHEDULES.map((f) => ({ ...f }));
  private readonly translations: InspirationTranslationRecord[] =
    SEED_TRANSLATIONS.map((t) => ({ ...t }));
  private readonly userQuotes: InspirationUserQuoteRecord[] = [];
  private readonly submissions: InspirationSubmissionRecord[] = [];
  private readonly moderationLogs: InspirationModerationLogRecord[] = [];
  private readonly favorites: InspirationFavoriteRecord[] = [];
  private readonly wallpaperTemplates: InspirationWallpaperTemplateRecord[] =
    SEED_WALLPAPER_TEMPLATES.map((w) => ({
      ...w,
      gradientColors: [...w.gradientColors],
    }));
  private readonly notificationPrefs = new Map<
    string,
    InspirationNotificationPreferenceRecord
  >();
  private readonly reports: InspirationQuoteReportRecord[] = [];

  constructor(
    private readonly supabaseService: SupabaseService,
    private readonly notificationService: InspirationNotificationService,
  ) {}

  // ===========================================================================
  // Public Read Endpoints
  // ===========================================================================

  async listPublicQuotes(
    query: InspirationQuotesQueryDto,
  ): Promise<PaginatedResult<InspirationQuoteRecord>> {
    const client = this.supabaseService.getPublicClient();
    if (client) {
      const from = (query.page - 1) * query.limit;
      const to = from + query.limit - 1;
      let builder = client
        .from('quotes')
        .select('*', { count: 'exact' })
        .eq('publication_status', 'PUBLISHED')
        .eq('is_active', true)
        .is('deleted_at', null);

      if (query.locale) builder = builder.eq('locale', query.locale);
      if (query.category) builder = builder.eq('category', query.category);
      if (query.categoryId) {
        builder = builder.eq('category_id', query.categoryId);
      }
      if (query.authorId) builder = builder.eq('author_id', query.authorId);
      if (query.author) builder = builder.ilike('author', `%${query.author}%`);
      if (query.featured !== undefined) {
        builder = builder.eq('is_featured', query.featured);
      }
      if (query.search) {
        builder = builder.or(
          `quote_text.ilike.%${query.search}%,author.ilike.%${query.search}%`,
        );
      }

      const { data, count, error } = await builder
        .order('is_featured', { ascending: false })
        .order('created_at', { ascending: false })
        .range(from, to);

      if (!error && data) {
        return {
          items: data.map((row) => this.mapQuoteRow(row)),
          page: query.page,
          limit: query.limit,
          total: count ?? data.length,
          source: 'supabase',
        };
      }
    }

    const searchLower = query.search?.trim().toLowerCase();
    const authorLower = query.author?.trim().toLowerCase();
    const filtered = this.quotes
      .filter(
        (q) =>
          q.publicationStatus === 'PUBLISHED' &&
          q.isActive &&
          q.deletedAt === null,
      )
      .filter((q) => {
        if (query.locale && q.locale !== query.locale) return false;
        if (query.category && q.category !== query.category) return false;
        if (query.categoryId && q.categoryId !== query.categoryId) return false;
        if (query.authorId && q.authorId !== query.authorId) return false;
        if (authorLower && !q.author.toLowerCase().includes(authorLower)) {
          return false;
        }
        if (query.featured !== undefined && q.isFeatured !== query.featured) {
          return false;
        }
        if (
          searchLower &&
          !q.quoteText.toLowerCase().includes(searchLower) &&
          !q.author.toLowerCase().includes(searchLower) &&
          !q.category.toLowerCase().includes(searchLower)
        ) {
          return false;
        }
        return true;
      });

    const start = (query.page - 1) * query.limit;
    return {
      items: filtered
        .slice(start, start + query.limit)
        .map((q) => this.applyTranslationIfAvailable(q, query.locale)),
      page: query.page,
      limit: query.limit,
      total: filtered.length,
      source: 'memory_store',
    };
  }

  async getPublicQuoteById(
    id: string,
    locale?: NestinLocale,
  ): Promise<InspirationQuoteRecord> {
    const found = this.quotes.find(
      (q) =>
        q.id === id &&
        q.publicationStatus === 'PUBLISHED' &&
        q.isActive &&
        q.deletedAt === null,
    );
    if (!found) {
      throw new NotFoundException(`Published quote ${id} not found`);
    }
    return this.applyTranslationIfAvailable(found, locale);
  }

  async getDailyFeaturedQuote(
    locale: NestinLocale = 'en',
    now = new Date(),
  ): Promise<InspirationFeaturedScheduleRecord | null> {
    const nowIso = now.toISOString();
    const todayDate = nowIso.slice(0, 10);

    // 1. Exact active schedule window for requested locale
    const activeWindow = this.featuredSchedules
      .filter(
        (s) =>
          s.isActive &&
          s.locale === locale &&
          (s.publicationDate === todayDate ||
            (s.startAt <= nowIso && s.endAt >= nowIso)),
      )
      .sort((a, b) => b.priority - a.priority);

    for (const schedule of activeWindow) {
      const quote = this.quotes.find(
        (q) =>
          q.id === schedule.quoteId &&
          q.publicationStatus === 'PUBLISHED' &&
          q.isActive &&
          q.deletedAt === null,
      );
      if (quote) {
        return {
          ...schedule,
          quote: this.applyTranslationIfAvailable(quote, locale),
        };
      }
    }

    // 2. Fallback to most recent active featured schedule for locale
    const fallbackSchedule = this.featuredSchedules
      .filter((s) => s.isActive && s.locale === locale)
      .sort((a, b) => b.publicationDate.localeCompare(a.publicationDate))[0];

    if (fallbackSchedule) {
      const quote = this.quotes.find(
        (q) =>
          q.id === fallbackSchedule.quoteId &&
          q.publicationStatus === 'PUBLISHED' &&
          q.isActive &&
          q.deletedAt === null,
      );
      if (quote) {
        return {
          ...fallbackSchedule,
          quote: this.applyTranslationIfAvailable(quote, locale),
        };
      }
    }

    // 3. Fallback to deterministic published featured quote for locale or default 'en'
    const featuredQuote =
      this.quotes.find(
        (q) =>
          q.publicationStatus === 'PUBLISHED' &&
          q.isActive &&
          q.isFeatured &&
          q.locale === locale &&
          q.deletedAt === null,
      ) ??
      this.quotes.find(
        (q) =>
          q.publicationStatus === 'PUBLISHED' &&
          q.isActive &&
          q.deletedAt === null,
      );

    if (!featuredQuote) return null;

    return {
      id: `auto-${featuredQuote.id}`,
      quoteId: featuredQuote.id,
      locale,
      publicationDate: todayDate,
      startAt: `${todayDate}T00:00:00.000Z`,
      endAt: `${todayDate}T23:59:59.999Z`,
      priority: 0,
      isActive: true,
      quote: this.applyTranslationIfAvailable(featuredQuote, locale),
      createdAt: featuredQuote.createdAt,
      updatedAt: featuredQuote.updatedAt,
    };
  }

  listPublicCategories(locale?: NestinLocale): InspirationCategoryRecord[] {
    return this.categories
      .filter((c) => c.isActive && c.deletedAt === null)
      .sort((a, b) => a.sortOrder - b.sortOrder)
      .map((c) => {
        const localized = locale ? c.translations[locale] : undefined;
        return {
          ...c,
          name: localized?.name ?? c.name,
          description: localized?.description ?? c.description,
        };
      });
  }

  listPublicAuthors(search?: string): InspirationAuthorRecord[] {
    const q = search?.trim().toLowerCase();
    return this.authors
      .filter((a) => a.isActive && a.deletedAt === null)
      .filter((a) =>
        q
          ? a.name.toLowerCase().includes(q) || a.bio.toLowerCase().includes(q)
          : true,
      );
  }

  listPublicWallpapers(
    query: WallpapersQueryDto,
  ): InspirationWallpaperTemplateRecord[] {
    return this.wallpaperTemplates
      .filter((w) => w.isPublished && w.deletedAt === null)
      .filter((w) => {
        if (query.layoutType && w.layoutType !== query.layoutType) return false;
        if (
          query.mascotDomain &&
          w.mascotIllustration !== query.mascotDomain
        ) {
          return false;
        }
        if (query.locale && w.locale && w.locale !== query.locale) {
          return false;
        }
        return true;
      })
      .sort((a, b) => a.sortOrder - b.sortOrder);
  }

  // ===========================================================================
  // Authenticated User Personal Quotes, Submissions, Favorites & Notifications
  // ===========================================================================

  listUserQuotes(user: AuthenticatedUser): InspirationUserQuoteRecord[] {
    return this.userQuotes.filter(
      (q) => q.userId === user.id && q.deletedAt === null,
    );
  }

  createUserQuote(
    user: AuthenticatedUser,
    dto: CreateUserQuoteDto,
  ): InspirationUserQuoteRecord {
    const category = this.categories.find(
      (c) => c.id === dto.categoryId && c.deletedAt === null,
    );
    if (!category) {
      throw new NotFoundException(`Category ${dto.categoryId} not found`);
    }

    const nowIso = new Date().toISOString();
    const record: InspirationUserQuoteRecord = {
      id: randomUUID(),
      userId: user.id,
      quoteText: dto.quoteText.trim(),
      authorName: dto.authorName?.trim() || null,
      categoryId: category.id,
      categorySlug: category.slug,
      locale: dto.locale ?? 'en',
      sourceReference: dto.sourceReference?.trim() || null,
      displayPreference: dto.displayPreference ?? 'anonymous',
      rightsConfirmed: Boolean(dto.rightsConfirmed),
      isPersonalOnly: dto.isPersonalOnly ?? true,
      createdAt: nowIso,
      updatedAt: nowIso,
      deletedAt: null,
    };
    this.userQuotes.unshift(record);
    return { ...record };
  }

  updateUserQuote(
    user: AuthenticatedUser,
    quoteId: string,
    dto: UpdateUserQuoteDto,
  ): InspirationUserQuoteRecord {
    const existing = this.userQuotes.find(
      (q) => q.id === quoteId && q.deletedAt === null,
    );
    if (!existing) {
      throw new NotFoundException(`Personal quote ${quoteId} not found`);
    }
    if (existing.userId !== user.id) {
      throw new ForbiddenException('You can only edit your own quotes');
    }

    if (dto.categoryId) {
      const cat = this.categories.find(
        (c) => c.id === dto.categoryId && c.deletedAt === null,
      );
      if (!cat) {
        throw new NotFoundException(`Category ${dto.categoryId} not found`);
      }
      existing.categoryId = cat.id;
      existing.categorySlug = cat.slug;
    }

    if (dto.quoteText !== undefined) existing.quoteText = dto.quoteText.trim();
    if (dto.authorName !== undefined) {
      existing.authorName = dto.authorName?.trim() || null;
    }
    if (dto.locale !== undefined) existing.locale = dto.locale;
    if (dto.sourceReference !== undefined) {
      existing.sourceReference = dto.sourceReference?.trim() || null;
    }
    if (dto.displayPreference !== undefined) {
      existing.displayPreference = dto.displayPreference;
    }
    if (dto.rightsConfirmed !== undefined) {
      existing.rightsConfirmed = dto.rightsConfirmed;
    }

    const nowIso = new Date().toISOString();
    existing.updatedAt = nowIso;

    // Security invariant: editing a quote that has a PENDING submission requires resubmission.
    for (const sub of this.submissions) {
      if (sub.userQuoteId === existing.id && sub.status === 'PENDING') {
        const prevStatus = sub.status;
        sub.status = 'DRAFT';
        sub.submittedAt = null;
        sub.updatedAt = nowIso;
        sub.quoteText = existing.quoteText;
        sub.authorName = existing.authorName;
        sub.categoryId = existing.categoryId;
        sub.categorySlug = existing.categorySlug;
        sub.locale = existing.locale;
        sub.sourceReference = existing.sourceReference;
        sub.contentFingerprint = this.normalizeFingerprint(existing.quoteText);
        this.moderationLogs.unshift({
          id: randomUUID(),
          submissionId: sub.id,
          actorUserId: user.id,
          previousStatus: prevStatus,
          newStatus: 'DRAFT',
          action: 'RESUBMIT_REQUIRED',
          remarks: 'Creator edited quote text while pending; resubmission required.',
          createdAt: nowIso,
        });
      }
    }

    return { ...existing };
  }

  deleteUserQuote(user: AuthenticatedUser, quoteId: string): { deleted: true } {
    const existing = this.userQuotes.find(
      (q) => q.id === quoteId && q.deletedAt === null,
    );
    if (!existing) {
      throw new NotFoundException(`Personal quote ${quoteId} not found`);
    }
    if (existing.userId !== user.id) {
      throw new ForbiddenException('You can only delete your own quotes');
    }

    const nowIso = new Date().toISOString();
    existing.deletedAt = nowIso;
    existing.updatedAt = nowIso;

    for (const sub of this.submissions) {
      if (sub.userQuoteId === quoteId && sub.status === 'PENDING') {
        sub.status = 'WITHDRAWN';
        sub.updatedAt = nowIso;
        this.moderationLogs.unshift({
          id: randomUUID(),
          submissionId: sub.id,
          actorUserId: user.id,
          previousStatus: 'PENDING',
          newStatus: 'WITHDRAWN',
          action: 'WITHDRAW',
          remarks: 'Automatically withdrawn upon personal quote deletion.',
          createdAt: nowIso,
        });
      }
    }
    return { deleted: true };
  }

  listMySubmissions(user: AuthenticatedUser): InspirationSubmissionRecord[] {
    return this.submissions
      .filter((s) => s.userId === user.id)
      .map((s) => ({ ...s }));
  }

  submitUserQuoteForModeration(
    user: AuthenticatedUser,
    dto: SubmitQuoteDto,
  ): InspirationSubmissionRecord {
    if (!dto.rightsConfirmed) {
      throw new BadRequestException(
        'Submission rights confirmation is required before submitting globally.',
      );
    }

    const userQuote = this.userQuotes.find(
      (q) => q.id === dto.userQuoteId && q.deletedAt === null,
    );
    if (!userQuote) {
      throw new NotFoundException(`Personal quote ${dto.userQuoteId} not found`);
    }
    if (userQuote.userId !== user.id) {
      throw new ForbiddenException('You can only submit your own quotes');
    }

    const fingerprint = this.normalizeFingerprint(userQuote.quoteText);
    const conflictingSubmission = this.submissions.find(
      (s) =>
        s.contentFingerprint === fingerprint &&
        (s.status === 'PENDING' || s.status === 'APPROVED'),
    );
    if (conflictingSubmission) {
      throw new ConflictException(
        'A duplicate submission with this quote text is already pending review or approved.',
      );
    }

    const potentialDuplicates = this.findPotentialDuplicateQuoteIds(
      userQuote.quoteText,
    );

    const nowIso = new Date().toISOString();
    userQuote.rightsConfirmed = true;
    userQuote.isPersonalOnly = false;
    userQuote.updatedAt = nowIso;

    // Re-use withdrawn/rejected/draft submission for the same userQuoteId if present
    let submission = this.submissions.find(
      (s) =>
        s.userQuoteId === userQuote.id &&
        (s.status === 'DRAFT' ||
          s.status === 'WITHDRAWN' ||
          s.status === 'REJECTED'),
    );

    if (submission) {
      const prevStatus = submission.status;
      submission.status = 'PENDING';
      submission.anonymousPublication =
        dto.anonymousPublication ??
        userQuote.displayPreference === 'anonymous';
      submission.contentFingerprint = fingerprint;
      submission.submittedAt = nowIso;
      submission.reviewedAt = null;
      submission.reviewedBy = null;
      submission.rejectionReason = null;
      submission.quoteText = userQuote.quoteText;
      submission.authorName = userQuote.authorName;
      submission.categoryId = userQuote.categoryId;
      submission.categorySlug = userQuote.categorySlug;
      submission.locale = userQuote.locale;
      submission.sourceReference = userQuote.sourceReference;
      submission.potentialDuplicateIds = potentialDuplicates;
      submission.updatedAt = nowIso;

      this.moderationLogs.unshift({
        id: randomUUID(),
        submissionId: submission.id,
        actorUserId: user.id,
        previousStatus: prevStatus,
        newStatus: 'PENDING',
        action: 'SUBMIT',
        remarks: 'Resubmitted for moderation review.',
        createdAt: nowIso,
      });
      return { ...submission };
    }

    submission = {
      id: randomUUID(),
      userQuoteId: userQuote.id,
      userId: user.id,
      status: 'PENDING',
      anonymousPublication:
        dto.anonymousPublication ?? userQuote.displayPreference === 'anonymous',
      contentFingerprint: fingerprint,
      submittedAt: nowIso,
      reviewedAt: null,
      reviewedBy: null,
      rejectionReason: null,
      publishedQuoteId: null,
      quoteText: userQuote.quoteText,
      authorName: userQuote.authorName,
      categoryId: userQuote.categoryId,
      categorySlug: userQuote.categorySlug,
      locale: userQuote.locale,
      sourceReference: userQuote.sourceReference,
      potentialDuplicateIds: potentialDuplicates,
      createdAt: nowIso,
      updatedAt: nowIso,
    };
    this.submissions.unshift(submission);
    this.moderationLogs.unshift({
      id: randomUUID(),
      submissionId: submission.id,
      actorUserId: user.id,
      previousStatus: 'DRAFT',
      newStatus: 'PENDING',
      action: 'SUBMIT',
      remarks: 'Submitted by creator for moderator review.',
      createdAt: nowIso,
    });

    return { ...submission };
  }

  withdrawSubmission(
    user: AuthenticatedUser,
    submissionId: string,
  ): InspirationSubmissionRecord {
    const submission = this.submissions.find((s) => s.id === submissionId);
    if (!submission) {
      throw new NotFoundException(`Submission ${submissionId} not found`);
    }
    if (submission.userId !== user.id) {
      throw new ForbiddenException(
        'You can only withdraw your own quote submissions',
      );
    }
    if (submission.status !== 'PENDING') {
      throw new BadRequestException(
        `Only PENDING submissions can be withdrawn (current: ${submission.status})`,
      );
    }

    const nowIso = new Date().toISOString();
    submission.status = 'WITHDRAWN';
    submission.updatedAt = nowIso;

    this.moderationLogs.unshift({
      id: randomUUID(),
      submissionId: submission.id,
      actorUserId: user.id,
      previousStatus: 'PENDING',
      newStatus: 'WITHDRAWN',
      action: 'WITHDRAW',
      remarks: 'Withdrawn by submitter.',
      createdAt: nowIso,
    });
    return { ...submission };
  }

  listFavorites(user: AuthenticatedUser): InspirationQuoteRecord[] {
    const quoteIds = new Set(
      this.favorites.filter((f) => f.userId === user.id).map((f) => f.quoteId),
    );
    return this.quotes.filter(
      (q) =>
        quoteIds.has(q.id) &&
        q.publicationStatus === 'PUBLISHED' &&
        q.isActive &&
        q.deletedAt === null,
    );
  }

  addFavorite(user: AuthenticatedUser, quoteId: string): InspirationFavoriteRecord {
    const quote = this.quotes.find(
      (q) =>
        q.id === quoteId &&
        q.publicationStatus === 'PUBLISHED' &&
        q.isActive &&
        q.deletedAt === null,
    );
    if (!quote) {
      throw new NotFoundException(`Published quote ${quoteId} not found`);
    }

    const existing = this.favorites.find(
      (f) => f.userId === user.id && f.quoteId === quoteId,
    );
    if (existing) return existing;

    const record: InspirationFavoriteRecord = {
      id: randomUUID(),
      userId: user.id,
      quoteId,
      createdAt: new Date().toISOString(),
    };
    this.favorites.unshift(record);
    return record;
  }

  removeFavorite(
    user: AuthenticatedUser,
    quoteId: string,
  ): { removed: true } {
    const idx = this.favorites.findIndex(
      (f) => f.userId === user.id && f.quoteId === quoteId,
    );
    if (idx !== -1) {
      this.favorites.splice(idx, 1);
    }
    return { removed: true };
  }

  getNotificationPreferences(
    user: AuthenticatedUser,
  ): InspirationNotificationPreferenceRecord {
    let pref = this.notificationPrefs.get(user.id);
    if (!pref) {
      const nowIso = new Date().toISOString();
      pref = {
        id: randomUUID(),
        userId: user.id,
        dailyEnabled: false, // Default opt-in posture: disabled until enabled by user
        submissionUpdatesEnabled: true,
        preferredTime: '08:00',
        timezone: 'UTC',
        frequency: 'DAILY',
        preferredLocale: 'en',
        preferredCategoryIds: [],
        lastDispatchedLocalDate: null,
        lastSentQuoteId: null,
        createdAt: nowIso,
        updatedAt: nowIso,
      };
      this.notificationPrefs.set(user.id, pref);
    }
    return { ...pref };
  }

  updateNotificationPreferences(
    user: AuthenticatedUser,
    dto: UpdateNotificationPreferencesDto,
  ): InspirationNotificationPreferenceRecord {
    const current = this.getNotificationPreferences(user);
    const updated: InspirationNotificationPreferenceRecord = {
      ...current,
      dailyEnabled: dto.dailyEnabled ?? current.dailyEnabled,
      submissionUpdatesEnabled:
        dto.submissionUpdatesEnabled ?? current.submissionUpdatesEnabled,
      preferredTime: dto.preferredTime ?? current.preferredTime,
      timezone: dto.timezone ?? current.timezone,
      frequency: dto.frequency ?? current.frequency,
      preferredLocale: dto.preferredLocale ?? current.preferredLocale,
      preferredCategoryIds:
        dto.preferredCategoryIds ?? current.preferredCategoryIds,
      updatedAt: new Date().toISOString(),
    };
    this.notificationPrefs.set(user.id, updated);
    return { ...updated };
  }

  getAllNotificationPreferences(): InspirationNotificationPreferenceRecord[] {
    return Array.from(this.notificationPrefs.values());
  }

  getAllPublishedQuotes(): InspirationQuoteRecord[] {
    return this.quotes.filter(
      (q) =>
        q.publicationStatus === 'PUBLISHED' &&
        q.isActive &&
        q.deletedAt === null,
    );
  }

  reportQuote(
    user: AuthenticatedUser,
    quoteId: string,
    dto: ReportQuoteDto,
  ): InspirationQuoteReportRecord {
    const quote = this.quotes.find(
      (q) => q.id === quoteId && q.deletedAt === null,
    );
    if (!quote) {
      throw new NotFoundException(`Quote ${quoteId} not found`);
    }
    const report: InspirationQuoteReportRecord = {
      id: randomUUID(),
      quoteId,
      reporterUserId: user.id,
      reason: dto.reason.trim(),
      details: dto.details?.trim() || null,
      status: 'OPEN',
      createdAt: new Date().toISOString(),
    };
    this.reports.unshift(report);
    return report;
  }

  // ===========================================================================
  // Admin & Moderator CMS Operations
  // ===========================================================================

  adminListQuotes(
    query: InspirationQuotesQueryDto,
  ): PaginatedResult<InspirationQuoteRecord> {
    const searchLower = query.search?.trim().toLowerCase();
    const filtered = this.quotes
      .filter((q) => q.deletedAt === null)
      .filter((q) => {
        if (query.locale && q.locale !== query.locale) return false;
        if (query.category && q.category !== query.category) return false;
        if (query.categoryId && q.categoryId !== query.categoryId) return false;
        if (
          searchLower &&
          !q.quoteText.toLowerCase().includes(searchLower) &&
          !q.author.toLowerCase().includes(searchLower)
        ) {
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
      source: 'admin_store',
    };
  }

  adminCreateQuote(dto: AdminCreateQuoteDto, admin: AuthenticatedUser) {
    const cat = dto.categoryId
      ? this.categories.find((c) => c.id === dto.categoryId)
      : this.categories.find((c) => c.slug === (dto.category ?? 'motivation'));
    const nowIso = new Date().toISOString();
    const quote: InspirationQuoteRecord = {
      id: randomUUID(),
      quoteText: dto.quoteText.trim(),
      author: dto.author.trim(),
      authorId: dto.authorId ?? null,
      category: cat?.slug ?? dto.category ?? 'motivation',
      categoryId: cat?.id ?? dto.categoryId ?? null,
      locale: dto.locale ?? 'en',
      mascotDomain: dto.mascotDomain ?? cat?.mascotDomain ?? 'flock',
      originType: 'SYSTEM',
      createdByUserId: admin.id,
      publicationStatus: dto.publicationStatus ?? 'DRAFT',
      isActive: dto.isActive ?? true,
      isFeatured: false,
      scheduledFor: null,
      sourceReference: dto.sourceReference?.trim() || null,
      backgroundAssetUrl: null,
      createdAt: nowIso,
      updatedAt: nowIso,
      deletedAt: null,
    };
    this.quotes.unshift(quote);
    return quote;
  }

  adminUpdateQuote(id: string, dto: AdminUpdateQuoteDto) {
    const quote = this.quotes.find((q) => q.id === id && q.deletedAt === null);
    if (!quote) throw new NotFoundException(`Quote ${id} not found`);

    if (dto.quoteText !== undefined) quote.quoteText = dto.quoteText.trim();
    if (dto.author !== undefined) quote.author = dto.author.trim();
    if (dto.authorId !== undefined) quote.authorId = dto.authorId;
    if (dto.categoryId !== undefined) {
      const cat = this.categories.find((c) => c.id === dto.categoryId);
      if (cat) {
        quote.categoryId = cat.id;
        quote.category = cat.slug;
      }
    } else if (dto.category !== undefined) {
      quote.category = dto.category;
    }
    if (dto.locale !== undefined) quote.locale = dto.locale;
    if (dto.mascotDomain !== undefined) quote.mascotDomain = dto.mascotDomain;
    if (dto.publicationStatus !== undefined) {
      quote.publicationStatus = dto.publicationStatus;
    }
    if (dto.isActive !== undefined) quote.isActive = dto.isActive;
    if (dto.sourceReference !== undefined) {
      quote.sourceReference = dto.sourceReference?.trim() || null;
    }
    quote.updatedAt = new Date().toISOString();
    return quote;
  }

  adminSetQuotePublicationStatus(
    id: string,
    status: 'PUBLISHED' | 'DRAFT' | 'ARCHIVED',
  ) {
    const quote = this.quotes.find((q) => q.id === id && q.deletedAt === null);
    if (!quote) throw new NotFoundException(`Quote ${id} not found`);
    quote.publicationStatus = status;
    quote.isActive = status === 'PUBLISHED';
    quote.updatedAt = new Date().toISOString();
    return quote;
  }

  adminDeleteQuote(id: string) {
    const quote = this.quotes.find((q) => q.id === id && q.deletedAt === null);
    if (!quote) throw new NotFoundException(`Quote ${id} not found`);
    const nowIso = new Date().toISOString();
    quote.deletedAt = nowIso;
    quote.isActive = false;
    quote.publicationStatus = 'ARCHIVED';
    quote.updatedAt = nowIso;
    return { deleted: true };
  }

  adminListAuthors(): InspirationAuthorRecord[] {
    return this.authors.filter((a) => a.deletedAt === null);
  }

  adminCreateAuthor(dto: AdminCreateAuthorDto): InspirationAuthorRecord {
    const nowIso = new Date().toISOString();
    const author: InspirationAuthorRecord = {
      id: randomUUID(),
      name: dto.name.trim(),
      slug:
        dto.slug?.trim() ||
        dto.name
          .trim()
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '-'),
      bio: dto.bio ?? '',
      isAnonymousOrUnknown: dto.isAnonymousOrUnknown ?? false,
      mascotDomain: dto.mascotDomain ?? null,
      isActive: dto.isActive ?? true,
      createdAt: nowIso,
      updatedAt: nowIso,
      deletedAt: null,
    };
    this.authors.push(author);
    return author;
  }

  adminUpdateAuthor(id: string, dto: AdminUpdateAuthorDto) {
    const author = this.authors.find(
      (a) => a.id === id && a.deletedAt === null,
    );
    if (!author) throw new NotFoundException(`Author ${id} not found`);
    if (dto.name !== undefined) author.name = dto.name.trim();
    if (dto.bio !== undefined) author.bio = dto.bio;
    if (dto.isAnonymousOrUnknown !== undefined) {
      author.isAnonymousOrUnknown = dto.isAnonymousOrUnknown;
    }
    if (dto.mascotDomain !== undefined) author.mascotDomain = dto.mascotDomain;
    if (dto.isActive !== undefined) author.isActive = dto.isActive;
    author.updatedAt = new Date().toISOString();
    return author;
  }

  adminListCategories(): InspirationCategoryRecord[] {
    return this.categories
      .filter((c) => c.deletedAt === null)
      .sort((a, b) => a.sortOrder - b.sortOrder);
  }

  adminCreateCategory(dto: AdminCreateCategoryDto): InspirationCategoryRecord {
    if (this.categories.some((c) => c.slug === dto.slug && !c.deletedAt)) {
      throw new ConflictException(`Category slug '${dto.slug}' already exists`);
    }
    const nowIso = new Date().toISOString();
    const category: InspirationCategoryRecord = {
      id: randomUUID(),
      slug: dto.slug.trim(),
      defaultLocale: dto.defaultLocale ?? 'en',
      name: dto.name.trim(),
      description: dto.description ?? '',
      translations: dto.translations ?? {
        [dto.defaultLocale ?? 'en']: {
          name: dto.name.trim(),
          description: dto.description ?? '',
        },
      },
      mascotDomain: dto.mascotDomain ?? null,
      sortOrder: dto.sortOrder ?? 10,
      isActive: dto.isActive ?? true,
      createdAt: nowIso,
      updatedAt: nowIso,
      deletedAt: null,
    };
    this.categories.push(category);
    return category;
  }

  adminUpdateCategory(id: string, dto: AdminUpdateCategoryDto) {
    const category = this.categories.find(
      (c) => c.id === id && c.deletedAt === null,
    );
    if (!category) throw new NotFoundException(`Category ${id} not found`);
    if (dto.name !== undefined) category.name = dto.name.trim();
    if (dto.description !== undefined) category.description = dto.description;
    if (dto.translations !== undefined) category.translations = dto.translations;
    if (dto.mascotDomain !== undefined) category.mascotDomain = dto.mascotDomain;
    if (dto.sortOrder !== undefined) category.sortOrder = dto.sortOrder;
    if (dto.isActive !== undefined) category.isActive = dto.isActive;
    category.updatedAt = new Date().toISOString();
    return category;
  }

  adminListSubmissions(
    query: AdminSubmissionsQueryDto,
  ): PaginatedResult<InspirationSubmissionRecord> {
    const filtered = this.submissions.filter((s) =>
      query.status ? s.status === query.status : true,
    );
    const start = (query.page - 1) * query.limit;
    return {
      items: filtered.slice(start, start + query.limit),
      page: query.page,
      limit: query.limit,
      total: filtered.length,
      source: 'admin_store',
    };
  }

  async adminApproveSubmission(
    admin: AuthenticatedUser,
    submissionId: string,
    dto: ApproveSubmissionDto,
  ): Promise<InspirationSubmissionRecord> {
    const submission = this.submissions.find((s) => s.id === submissionId);
    if (!submission) {
      throw new NotFoundException(`Submission ${submissionId} not found`);
    }
    // Security invariant: nobody can approve their own submission.
    if (submission.userId === admin.id) {
      throw new ForbiddenException(
        'Moderators and administrators cannot approve their own quote submissions.',
      );
    }
    if (submission.status !== 'PENDING') {
      throw new BadRequestException(
        `Only PENDING submissions can be approved (current: ${submission.status})`,
      );
    }

    const cat = this.categories.find(
      (c) => c.id === (dto.overrideCategoryId ?? submission.categoryId),
    );
    const nowIso = new Date().toISOString();
    const authorDisplay = submission.anonymousPublication
      ? 'Anonymous Contributor'
      : submission.authorName?.trim() || 'Community Contributor';

    const publishedQuote: InspirationQuoteRecord = {
      id: randomUUID(),
      quoteText: submission.quoteText,
      author: authorDisplay,
      authorId: submission.anonymousPublication ? SEED_AUTHORS[3].id : null,
      category: cat?.slug ?? submission.categorySlug,
      categoryId: cat?.id ?? submission.categoryId,
      locale: submission.locale,
      mascotDomain: cat?.mascotDomain ?? 'flock',
      originType: 'USER',
      createdByUserId: submission.userId,
      publicationStatus: 'PUBLISHED',
      isActive: true,
      isFeatured: false,
      scheduledFor: null,
      sourceReference: submission.sourceReference,
      backgroundAssetUrl: null,
      createdAt: nowIso,
      updatedAt: nowIso,
      deletedAt: null,
    };
    this.quotes.unshift(publishedQuote);

    submission.status = 'APPROVED';
    submission.reviewedAt = nowIso;
    submission.reviewedBy = admin.id;
    submission.publishedQuoteId = publishedQuote.id;
    submission.updatedAt = nowIso;

    this.moderationLogs.unshift({
      id: randomUUID(),
      submissionId: submission.id,
      actorUserId: admin.id,
      previousStatus: 'PENDING',
      newStatus: 'APPROVED',
      action: 'APPROVE',
      remarks: dto.remarks ?? 'Approved and published to Inspiration library.',
      createdAt: nowIso,
    });

    const prefs = this.notificationPrefs.get(submission.userId);
    await this.notificationService.dispatchSubmissionStatusNotification({
      userId: submission.userId,
      submissionId: submission.id,
      quoteId: publishedQuote.id,
      approved: true,
      prefs,
    });

    return { ...submission };
  }

  async adminRejectSubmission(
    admin: AuthenticatedUser,
    submissionId: string,
    dto: RejectSubmissionDto,
  ): Promise<InspirationSubmissionRecord> {
    const submission = this.submissions.find((s) => s.id === submissionId);
    if (!submission) {
      throw new NotFoundException(`Submission ${submissionId} not found`);
    }
    if (submission.userId === admin.id) {
      throw new ForbiddenException(
        'Moderators and administrators cannot moderate their own quote submissions.',
      );
    }
    if (submission.status !== 'PENDING') {
      throw new BadRequestException(
        `Only PENDING submissions can be rejected (current: ${submission.status})`,
      );
    }

    const nowIso = new Date().toISOString();
    submission.status = 'REJECTED';
    submission.reviewedAt = nowIso;
    submission.reviewedBy = admin.id;
    submission.rejectionReason = dto.rejectionReason.trim();
    submission.updatedAt = nowIso;

    this.moderationLogs.unshift({
      id: randomUUID(),
      submissionId: submission.id,
      actorUserId: admin.id,
      previousStatus: 'PENDING',
      newStatus: 'REJECTED',
      action: 'REJECT',
      remarks: dto.remarks ?? dto.rejectionReason.trim(),
      createdAt: nowIso,
    });

    const prefs = this.notificationPrefs.get(submission.userId);
    await this.notificationService.dispatchSubmissionStatusNotification({
      userId: submission.userId,
      submissionId: submission.id,
      quoteId: null,
      approved: false,
      rejectionReason: submission.rejectionReason,
      prefs,
    });

    return { ...submission };
  }

  adminGetSubmissionHistory(
    submissionId: string,
  ): InspirationModerationLogRecord[] {
    const submission = this.submissions.find((s) => s.id === submissionId);
    if (!submission) {
      throw new NotFoundException(`Submission ${submissionId} not found`);
    }
    return this.moderationLogs.filter((l) => l.submissionId === submissionId);
  }

  adminListFeaturedSchedules(): InspirationFeaturedScheduleRecord[] {
    return this.featuredSchedules.map((s) => ({
      ...s,
      quote: this.quotes.find((q) => q.id === s.quoteId),
    }));
  }

  adminCreateFeaturedSchedule(
    dto: AdminCreateFeaturedScheduleDto,
  ): InspirationFeaturedScheduleRecord {
    const quote = this.quotes.find(
      (q) =>
        q.id === dto.quoteId &&
        q.publicationStatus === 'PUBLISHED' &&
        q.isActive &&
        q.deletedAt === null,
    );
    if (!quote) {
      throw new NotFoundException(
        `Published quote ${dto.quoteId} not found for featured scheduling`,
      );
    }

    if (new Date(dto.endAt) <= new Date(dto.startAt)) {
      throw new BadRequestException('Featured schedule endAt must be after startAt');
    }

    // Prevent overlapping active featured entries for the same locale & date window
    const conflict = this.featuredSchedules.find(
      (existing) =>
        existing.isActive &&
        existing.locale === dto.locale &&
        (existing.publicationDate === dto.publicationDate ||
          (existing.startAt < dto.endAt && existing.endAt > dto.startAt)),
    );
    if (conflict) {
      throw new ConflictException(
        `Conflicting featured quote already scheduled for ${dto.locale} on ${dto.publicationDate}`,
      );
    }

    const nowIso = new Date().toISOString();
    const record: InspirationFeaturedScheduleRecord = {
      id: randomUUID(),
      quoteId: dto.quoteId,
      locale: dto.locale,
      publicationDate: dto.publicationDate,
      startAt: dto.startAt,
      endAt: dto.endAt,
      priority: dto.priority ?? 1,
      isActive: true,
      quote,
      createdAt: nowIso,
      updatedAt: nowIso,
    };
    this.featuredSchedules.unshift(record);
    return record;
  }

  adminDeleteFeaturedSchedule(id: string) {
    const schedule = this.featuredSchedules.find((s) => s.id === id);
    if (!schedule) {
      throw new NotFoundException(`Featured schedule ${id} not found`);
    }
    schedule.isActive = false;
    schedule.updatedAt = new Date().toISOString();
    return { deleted: true };
  }

  adminListWallpapers(): InspirationWallpaperTemplateRecord[] {
    return this.wallpaperTemplates
      .filter((w) => w.deletedAt === null)
      .sort((a, b) => a.sortOrder - b.sortOrder);
  }

  adminCreateWallpaperTemplate(
    dto: AdminCreateWallpaperTemplateDto,
  ): InspirationWallpaperTemplateRecord {
    const nowIso = new Date().toISOString();
    const tpl: InspirationWallpaperTemplateRecord = {
      id: randomUUID(),
      slug: dto.slug.trim(),
      name: dto.name.trim(),
      layoutType: dto.layoutType,
      aspectRatio: dto.aspectRatio,
      assetId: null,
      assetUrl: dto.assetUrl ?? null,
      backgroundType: dto.backgroundType ?? 'gradient',
      gradientColors: dto.gradientColors ?? ['#1A1B20', '#2B2D36'],
      textColor: dto.textColor ?? '#FFFFFF',
      fontFamily: dto.fontFamily ?? 'serif',
      textAlignment: dto.textAlignment ?? 'center',
      showBranding: dto.showBranding ?? true,
      mascotIllustration: dto.mascotIllustration ?? null,
      locale: null,
      isPublished: dto.isPublished ?? true,
      sortOrder: this.wallpaperTemplates.length + 1,
      createdAt: nowIso,
      updatedAt: nowIso,
      deletedAt: null,
    };
    this.wallpaperTemplates.push(tpl);
    return tpl;
  }

  adminListTranslations(): InspirationTranslationRecord[] {
    return [...this.translations];
  }

  adminUpsertTranslation(
    dto: AdminUpsertTranslationDto,
  ): InspirationTranslationRecord {
    const quote = this.quotes.find(
      (q) => q.id === dto.quoteId && q.deletedAt === null,
    );
    if (!quote) throw new NotFoundException(`Quote ${dto.quoteId} not found`);

    const nowIso = new Date().toISOString();
    const existing = this.translations.find(
      (t) => t.quoteId === dto.quoteId && t.locale === dto.locale,
    );
    if (existing) {
      existing.quoteText = dto.quoteText.trim();
      existing.authorDisplay = dto.authorDisplay.trim();
      existing.publicationStatus = dto.publicationStatus ?? 'PUBLISHED';
      existing.isActive = dto.isActive ?? true;
      existing.updatedAt = nowIso;
      return existing;
    }

    const created: InspirationTranslationRecord = {
      id: randomUUID(),
      quoteId: dto.quoteId,
      locale: dto.locale,
      quoteText: dto.quoteText.trim(),
      authorDisplay: dto.authorDisplay.trim(),
      publicationStatus: dto.publicationStatus ?? 'PUBLISHED',
      isActive: dto.isActive ?? true,
      createdAt: nowIso,
      updatedAt: nowIso,
    };
    this.translations.unshift(created);
    return created;
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  private applyTranslationIfAvailable(
    quote: InspirationQuoteRecord,
    requestedLocale?: NestinLocale,
  ): InspirationQuoteRecord {
    if (!requestedLocale || quote.locale === requestedLocale) {
      return { ...quote };
    }
    const tr = this.translations.find(
      (t) =>
        t.quoteId === quote.id &&
        t.locale === requestedLocale &&
        t.publicationStatus === 'PUBLISHED' &&
        t.isActive,
    );
    if (!tr) {
      return { ...quote };
    }
    return {
      ...quote,
      quoteText: tr.quoteText,
      author: tr.authorDisplay || quote.author,
      locale: requestedLocale,
    };
  }

  private normalizeFingerprint(text: string): string {
    return text
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private findPotentialDuplicateQuoteIds(quoteText: string): string[] {
    const normalized = this.normalizeFingerprint(quoteText);
    const ids: string[] = [];
    for (const q of this.quotes) {
      if (this.normalizeFingerprint(q.quoteText) === normalized) {
        ids.push(q.id);
      }
    }
    return ids;
  }

  private mapQuoteRow(row: Record<string, unknown>): InspirationQuoteRecord {
    return {
      id: row.id as string,
      quoteText: row.quote_text as string,
      author: (row.author as string) ?? 'Nestin Flock',
      authorId: (row.author_id as string | null) ?? null,
      category: (row.category as string) ?? 'motivation',
      categoryId: (row.category_id as string | null) ?? null,
      locale: (row.locale as NestinLocale) ?? 'en',
      mascotDomain:
        (row.mascot_domain as InspirationQuoteRecord['mascotDomain']) ?? null,
      originType:
        (row.origin_type as InspirationQuoteRecord['originType']) ?? 'SYSTEM',
      createdByUserId: (row.created_by_user_id as string | null) ?? null,
      publicationStatus:
        (row.publication_status as InspirationQuoteRecord['publicationStatus']) ??
        'PUBLISHED',
      isActive: row.is_active !== false,
      isFeatured: Boolean(row.is_featured),
      scheduledFor: (row.scheduled_for as string | null) ?? null,
      sourceReference: (row.source_reference as string | null) ?? null,
      backgroundAssetUrl: null,
      createdAt: (row.created_at as string) ?? new Date().toISOString(),
      updatedAt: (row.updated_at as string) ?? new Date().toISOString(),
      deletedAt: (row.deleted_at as string | null) ?? null,
    };
  }
}
