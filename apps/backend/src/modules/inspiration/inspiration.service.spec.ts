import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AuthenticatedUser } from '../../common/decorators/current-user.decorator';
import { SupabaseService } from '../../database/supabase.service';
import {
  InspirationNotificationService,
  PushDeliveryOutcome,
  PushDispatchPayload,
  PushTransportAdapter,
} from './inspiration-notification.service';
import { SEED_CATEGORIES, SEED_QUOTES } from './inspiration.seed';
import { InspirationService } from './inspiration.service';
import { InspirationStore } from './inspiration.store';

function makeUser(overrides: Partial<AuthenticatedUser> = {}): AuthenticatedUser {
  return {
    id: '11111111-1111-4111-8111-111111111111',
    email: 'user@nestin.app',
    role: 'user',
    permissions: [],
    accessToken: 'token-user',
    isAnonymous: false,
    ...overrides,
  };
}

class ControllablePushAdapter implements PushTransportAdapter {
  shouldFailOnce = false;
  failNextAsExpired = false;
  readonly sentPayloads: PushDispatchPayload[] = [];

  async send(payload: PushDispatchPayload): Promise<PushDeliveryOutcome> {
    this.sentPayloads.push(payload);
    if (this.failNextAsExpired) {
      this.failNextAsExpired = false;
      return {
        ok: false,
        expiredToken: true,
        errorMessage: 'Simulated expired FCM registration token',
      };
    }
    if (this.shouldFailOnce) {
      this.shouldFailOnce = false;
      return {
        ok: false,
        errorMessage: 'Transient push gateway timeout',
      };
    }
    return { ok: true };
  }
}

function createHarness(adapter?: PushTransportAdapter) {
  const configService = {
    get: () => '',
  } as unknown as ConfigService;
  const supabaseService = new SupabaseService(configService);
  const notificationService = new InspirationNotificationService(
    supabaseService,
    adapter,
  );
  const store = new InspirationStore(supabaseService, notificationService);
  const service = new InspirationService(store, notificationService);
  return { service, store, notificationService };
}

describe('InspirationService & InspirationNotificationService', () => {
  it('filters quotes by category, author, locale, and keyword and serves translations', async () => {
    const { service } = createHarness();

    const idQuotes = await service.listPublicQuotes({
      page: 1,
      limit: 20,
      locale: 'id',
    });
    expect(idQuotes.items.length).toBeGreaterThan(0);
    expect(idQuotes.items.every((q) => q.locale === 'id')).toBe(true);

    const motivation = await service.listPublicQuotes({
      page: 1,
      limit: 20,
      category: 'motivation',
    });
    expect(motivation.items.length).toBeGreaterThan(0);
    expect(motivation.items.every((q) => q.category === 'motivation')).toBe(true);

    const searchResult = await service.listPublicQuotes({
      page: 1,
      limit: 20,
      search: 'Simplicity',
    });
    expect(searchResult.items.some((q) => q.quoteText.includes('Simplicity'))).toBe(true);

    const firstId = SEED_QUOTES[0].id;
    const translated = await service.getPublicQuoteById(firstId, 'id');
    expect(translated.quoteText).toContain('Kemajuan kecil');
  });

  it('prevents overlapping featured quote schedules in the same locale window', () => {
    const { service } = createHarness();
    const admin = makeUser({
      id: '99999999-9999-4999-8999-999999999999',
      role: 'admin',
    });
    const createdQuote = service.adminCreateQuote(
      {
        quoteText: 'Gentle focus builds calm days that outlast frantic sprints.',
        author: 'Nestin Editorial',
        categoryId: SEED_CATEGORIES[0].id,
        locale: 'en',
        publicationStatus: 'PUBLISHED',
      },
      admin,
    );

    const schedule = service.adminCreateFeaturedSchedule({
      quoteId: createdQuote.id,
      locale: 'en',
      publicationDate: '2026-12-20',
      startAt: '2026-12-20T00:00:00.000Z',
      endAt: '2026-12-20T23:59:59.000Z',
      priority: 1,
    });
    expect(schedule.quoteId).toBe(createdQuote.id);

    expect(() =>
      service.adminCreateFeaturedSchedule({
        quoteId: SEED_QUOTES[0].id,
        locale: 'en',
        publicationDate: '2026-12-20',
        startAt: '2026-12-20T06:00:00.000Z',
        endAt: '2026-12-20T18:00:00.000Z',
        priority: 2,
      }),
    ).toThrow(ConflictException);

    expect(() =>
      service.adminCreateFeaturedSchedule({
        quoteId: SEED_QUOTES[0].id,
        locale: 'id',
        publicationDate: '2026-12-21',
        startAt: '2026-12-21T10:00:00.000Z',
        endAt: '2026-12-21T09:00:00.000Z',
      }),
    ).toThrow(BadRequestException);
  });

  it('manages personal quotes, pending-edit resubmission reset, duplicates, withdrawal, and blocks self-approval', async () => {
    const { service } = createHarness();
    const authorUser = makeUser({
      id: '22222222-2222-4222-8222-222222222222',
      role: 'moderator',
    });
    const reviewerAdmin = makeUser({
      id: '99999999-9999-4999-8999-999999999999',
      role: 'admin',
    });

    // Guest users blocked from personal/submission cloud features
    const guest = makeUser({ isAnonymous: true });
    expect(() =>
      service.createUserQuote(guest, {
        quoteText: 'Guest attempt should stay local only.',
        categoryId: SEED_CATEGORIES[0].id,
      }),
    ).toThrow(ForbiddenException);

    const personal = service.createUserQuote(authorUser, {
      quoteText: 'Protect your quiet mornings before opening the noise.',
      authorName: 'Alya',
      categoryId: SEED_CATEGORIES[0].id,
      locale: 'en',
      displayPreference: 'username',
      rightsConfirmed: true,
    });

    // Submitting requires rightsConfirmed
    expect(() =>
      service.submitUserQuoteForModeration(authorUser, {
        userQuoteId: personal.id,
        rightsConfirmed: false,
      }),
    ).toThrow(BadRequestException);

    const submitted = service.submitUserQuoteForModeration(authorUser, {
      userQuoteId: personal.id,
      rightsConfirmed: true,
      anonymousPublication: false,
    });
    expect(submitted.status).toBe('PENDING');

    // Duplicate quote cannot be submitted twice globally
    const secondQuote = service.createUserQuote(reviewerAdmin, {
      quoteText: '  protect   your QUIET mornings before opening the noise! ',
      categoryId: SEED_CATEGORIES[0].id,
      rightsConfirmed: true,
    });
    expect(() =>
      service.submitUserQuoteForModeration(reviewerAdmin, {
        userQuoteId: secondQuote.id,
        rightsConfirmed: true,
      }),
    ).toThrow(ConflictException);

    // Self-approval MUST fail even for moderator/admin author
    await expect(
      service.adminApproveSubmission(authorUser, submitted.id, {}),
    ).rejects.toThrow(ForbiddenException);

    // Editing a PENDING quote resets submission back to DRAFT for resubmission
    service.updateUserQuote(authorUser, personal.id, {
      quoteText: 'Protect quiet mornings before the world asks for your focus.',
    });
    const subsAfterEdit = service.listMySubmissions(authorUser);
    expect(subsAfterEdit[0].status).toBe('DRAFT');

    // Re-submit & withdraw
    const resubmitted = service.submitUserQuoteForModeration(authorUser, {
      userQuoteId: personal.id,
      rightsConfirmed: true,
      anonymousPublication: true,
    });
    expect(resubmitted.status).toBe('PENDING');

    const withdrawn = service.withdrawSubmission(authorUser, resubmitted.id);
    expect(withdrawn.status).toBe('WITHDRAWN');

    // Re-submit and reject with reason, verify audit history
    const rePending = service.submitUserQuoteForModeration(authorUser, {
      userQuoteId: personal.id,
      rightsConfirmed: true,
      anonymousPublication: true,
    });
    const rejected = await service.adminRejectSubmission(
      reviewerAdmin,
      rePending.id,
      { rejectionReason: 'Needs clearer punctuation for featured card readability.' },
    );
    expect(rejected.status).toBe('REJECTED');
    expect(rejected.rejectionReason).toContain('clearer punctuation');

    // Re-submit and approve by reviewerAdmin -> becomes PUBLISHED quote
    const finalPending = service.submitUserQuoteForModeration(authorUser, {
      userQuoteId: personal.id,
      rightsConfirmed: true,
      anonymousPublication: true,
    });
    const approved = await service.adminApproveSubmission(
      reviewerAdmin,
      finalPending.id,
      { remarks: 'Looks warm and ready.' },
    );
    expect(approved.status).toBe('APPROVED');
    expect(approved.publishedQuoteId).toBeTruthy();

    const history = service.adminGetSubmissionHistory(approved.id);
    const actions = history.map((h) => h.action);
    expect(actions).toContain('SUBMIT');
    expect(actions).toContain('RESUBMIT_REQUIRED');
    expect(actions).toContain('WITHDRAW');
    expect(actions).toContain('REJECT');
    expect(actions).toContain('APPROVE');
  });

  it('defaults notifications to opt-out, prevents same-day duplicates, handles expired tokens and retries', async () => {
    const adapter = new ControllablePushAdapter();
    const { service, notificationService } = createHarness(adapter);

    const user = makeUser({ id: '44444444-4444-4444-8444-444444444444' });
    const defaults = service.getNotificationPreferences(user);
    expect(defaults.dailyEnabled).toBe(false);
    expect(defaults.submissionUpdatesEnabled).toBe(true);

    // No dispatch while opted out
    const skippedRun = await service.triggerDueDailyDispatch(
      new Date('2026-11-16T01:00:00.000Z'), // 08:00 WIB Monday
    );
    expect(skippedRun.sentCount).toBe(0);
    expect(skippedRun.skippedCount).toBe(1);

    // Opt in to 08:00 Asia/Jakarta on WEEKDAYS
    service.updateNotificationPreferences(user, {
      dailyEnabled: true,
      preferredTime: '08:00',
      timezone: 'Asia/Jakarta',
      frequency: 'WEEKDAYS',
      preferredLocale: 'en',
      preferredCategoryIds: [SEED_CATEGORIES[0].id],
    });
    notificationService.setUserDeviceTargets(user.id, [
      {
        id: 'device-1',
        userId: user.id,
        pushProvider: 'fcm',
        pushToken: 'valid-fcm-token-1',
        revokedAt: null,
      },
    ]);

    // Sunday 2026-11-15 08:15 WIB (01:15 UTC) should skip under WEEKDAYS
    const sundaySkip = await service.triggerDueDailyDispatch(
      new Date('2026-11-15T01:15:00.000Z'),
    );
    expect(sundaySkip.sentCount).toBe(0);
    expect(sundaySkip.skippedCount).toBe(1);

    // Monday 2026-11-16 08:05 WIB (01:05 UTC) dispatches once
    const mondayFirst = await service.triggerDueDailyDispatch(
      new Date('2026-11-16T01:05:00.000Z'),
    );
    expect(mondayFirst.sentCount).toBe(1);

    // Same local day rerun prevents duplicate
    const mondaySecond = await service.triggerDueDailyDispatch(
      new Date('2026-11-16T03:00:00.000Z'),
    );
    expect(mondaySecond.sentCount).toBe(0);
    expect(mondaySecond.duplicatePreventedCount).toBe(1);

    // Simulate transient failure on Tuesday then retry success
    adapter.shouldFailOnce = true;
    const tuesdayFail = await service.triggerDueDailyDispatch(
      new Date('2026-11-17T01:05:00.000Z'),
    );
    expect(tuesdayFail.failedCount).toBe(1);

    const retried = await service.retryFailedNotifications(3);
    expect(retried.retried).toBe(1);
    expect(retried.succeeded).toBe(1);

    // Simulate expired token on Wednesday -> device revoked
    adapter.failNextAsExpired = true;
    const wednesdayExpired = await service.triggerDueDailyDispatch(
      new Date('2026-11-18T01:05:00.000Z'),
    );
    expect(wednesdayExpired.failedCount).toBe(1);

    const logs = service.listNotificationLogs(user.id);
    expect(logs.length).toBeGreaterThanOrEqual(3);
  });
});
